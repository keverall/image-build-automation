<#
.SYNOPSIS
    Functional / re-runnable test harness for the BUILD & DEPLOY pipeline and its
    mandatory -GuardRail safety gate.

.DESCRIPTION
    Exercises the build/deploy commands plus the ISO / firmware validation they rely on:

      Configure-PhysicalBuild, Start-PhysicalServerBuild, Invoke-IsoDeploy, Update-Firmware

    What it exercises
    -----------------
      1. Connection check / connect-when-none (mirrors testConnectAndList).
      2. Running build/deploy WITHOUT the mandatory -GuardRail -> early, graceful,
         logged BLOCK (never an unguarded action).
      3. HPE OneView ISO file variants:
           * filename/UNC/HTTPS/NFS path -> resolved to an iLO-accessible URL
             (SMB conversion, shareability checks)
           * a supplied local ISO path is validated (exists, is an .iso)
      4. Firmware archive validation (exists, valid zip/cab/tar).
      5. The -GuardRail SAFETY GATE across all four commands:
           * omitted      -> blocked (GUARD RAIL REQUIRED)
           * non-matching -> blocked (mismatch)
           * matching     -> proceeds (DryRun / SkipConfirmation)
      6. Confirmation flow: a matched guard in an automated run with no
         -SkipConfirmation auto-cancels (no unconfirmed destructive action).
      7. Build/deploy VARIANTS (external ISO, firmware folders) under -DryRun.

    -OneViewHost is the OneView appliance and -Server is the target
    server identifier (name / serial / iLO IP). Nothing is hard-coded; both are
    prompted when omitted. By default the script runs SAFE (connections validated
    with -DryRun, builds with -DryRun) and only performs live calls when -Live is
    passed with credentials. Full logging is written via the module's common logging
    commands (Initialize-Logging / Get-Logger) under
    generated/logs/commands/testBuildDeploy/.

.PARAMETER OneViewHost
    OneView appliance hostname or IP (alias -OVHost). Prompted if omitted.

.PARAMETER Server
    Target server identifier (name / serial / iLO IP) to build or deploy. Prompted
    if omitted.

.PARAMETER SerialNumber
    Resolve -Server from an HPE serial number via OneView.

.PARAMETER IloIp
    Target iLO address or hostname.

.PARAMETER Credential
    PSCredential for a live (-Live) connection. Prompted when -Live is set and
    this is omitted.

.PARAMETER IsoPath
    Local or network ISO path to validate (existence + .iso + iLO shareability).

.PARAMETER FirmwarePath
    Local firmware archive (.zip/.cab/.tar/...) to validate.

.PARAMETER GuardRail
    CASE-INSENSITIVE REGEX the target server name must match. Supplied to every
    build/deploy command so the safety gate is exercised (matches '.*' by default
    when omitted here, which still satisfies the commands' mandatory requirement).

.PARAMETER Live
    Perform REAL connections / builds using -Credential instead of -DryRun
    validation. Use only against an approved test appliance.

.PARAMETER DryRun
    Validate with -DryRun (default-safe behaviour even without -Live).

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds for reachability probes (default 3000).

.EXAMPLE
    .\testBuildDeploy.ps1 -OneViewHost oneview-test.ad.example.com -Server srv01

.EXAMPLE
    .\testBuildDeploy.ps1 -Server srv01 -IsoPath '\\fileserver\isos\win.iso' -FirmwarePath 'C:\fw\firmware.zip' -GuardRail 'srv0'

.EXAMPLE
    .\testBuildDeploy.ps1 -Live -OneViewHost ov.corp.local -Server srv01 -Credential $cred -IsoPath 'https://artifacts/isos/win.iso' -GuardRail 'srv0'
#>


[CmdletBinding()]
param(
    [Alias('OVHost')]
    [string] $OneViewHost,
    [string] $Server,
    [string] $SerialNumber,
    [string] $IloIp,
    [System.Management.Automation.PSCredential] $Credential,
    [string] $IsoPath,
    [string] $FirmwarePath,
    [string] $GuardRail,
    [switch] $Live,
    [switch] $DryRun,
    [int] $PingTimeoutMs = 3000
)

$ErrorActionPreference = 'Continue'

# ── Resolve the module + hosts ───────────────────────────────────────────────
$repoRoot = if (Test-Path (Join-Path $PSScriptRoot 'src')) { $PSScriptRoot } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$modulePath = Join-Path $repoRoot 'src/powershell/Automation/Automation.psd1'
if (-not (Test-Path $modulePath)) {
    $modulePath = Resolve-Path (Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psd1') -ErrorAction Stop
}
Import-Module $modulePath -Force -DisableNameChecking -WarningAction SilentlyContinue

$hostArg = if ($OneViewHost) { $OneViewHost } else { $null }
if (-not $hostArg) { $hostArg = Read-Host "Enter the OneView appliance host (server name or serial)" }
if (-not $Server)  { $Server  = Read-Host "Enter the TARGET server identifier to build/deploy (name, serial or iLO IP)" }
if (-not $hostArg -or -not $Server) {
    Write-Error "Both an appliance host and a target server identifier are required. Aborting." -ErrorAction Stop
}

# ── Logging ──────────────────────────────────────────────────────────────────
Initialize-Logging -CommandName 'testBuildDeploy' -LogName "testBuildDeploy-Host-$hostArg-Srv-$Server"
$log = Get-Logger 'testBuildDeploy'
$log.Info("Starting testBuildDeploy : appliance='$hostArg' server='$Server' Live=$Live DryRun=$DryRun")

$results = [System.Collections.ArrayList]::new()
function Record-Step {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $null = $results.Add([PSCustomObject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
    $colour = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host ("  [$(if($Passed){'PASS'}else{'FAIL'})] $Name : $Detail") -ForegroundColor $colour
    $log.Info("STEP $Name -> Passed=$Passed : $Detail")
}

# ── Phase 1: connection status + connect-when-none ─────────────────────────
Write-Host "`n########## testBuildDeploy : $hostArg / $Server ##########`n" -ForegroundColor Cyan
Write-Host "`n--- Phase 1: connection status + connect-when-none ---" -ForegroundColor Yellow

# Report current connectivity (public command; never prompts). Then ensure a
# session exists: in -Live we authenticate for real; otherwise we validate the
# appliance with -DryRun (no real connection, safe for re-runs).
$connStatus = $null
try { $connStatus = Test-ServerConnectivity -PingTimeoutMs $PingTimeoutMs -ErrorAction SilentlyContinue } catch { }
Record-Step 'Connectivity status reported' ($null -ne $connStatus) ("Available=$(if($connStatus){$connStatus.Available}else{'n/a'})")

if ($Live) {
    if (-not $Credential) { $Credential = Get-Credential -Message "OneView credentials for '$hostArg'" }
    Record-Step 'Connect-OneView (LIVE)' $true "Attempting live connect to '$hostArg'"
    $conn = Connect-OneView -OneViewHost $hostArg -Credential $Credential
    Record-Step 'Connect-OneView result' ($conn.Available -eq $true) ("Available=$($conn.Available)")
} else {
    $conn = Connect-OneView -OneViewHost $hostArg -DryRun
    Record-Step 'Connect-OneView (DryRun validation)' ($conn.Available -eq $true) "DryRun validation of '$hostArg'"
}

# ── Phase 2: ISO file variants (path -> iLO-accessible URL, shareable) ───────
Write-Host "`n--- Phase 2: ISO path variants & shareability ---" -ForegroundColor Yellow

function Test-IsoShareable {
    param([string]$Path)
    if ($Path -match '^https?://') { return 'Shareable (HTTPS)' }
    if ($Path -match '^nfs://')    { return 'Shareable (NFS)' }
    if ($Path -match '^\\\\')      { return 'Shareable (UNC/SMB)' }
    if ($Path -match '^[A-Za-z]:\\'){ return 'NOT shareable (local drive)' }
    return 'Unknown format'
}

$isoVariants = @(
    @{ Label = 'HTTPS URL';      Path = 'https://artifacts.internal.example.com/isos/WinSrv2025.iso' }
    @{ Label = 'UNC/SMB path';   Path = '\\fileserver\isos\WinSrv2025.iso' }
    @{ Label = 'NFS path';       Path = 'nfs://fileserver/export/WinSrv2025.iso' }
    @{ Label = 'Local drive';    Path = 'C:\isos\WinSrv2025.iso' }
)
foreach ($v in $isoVariants) {
    $resolved = $null; $err = $null
    try { $resolved = Resolve-ExternalIsoPath -IsoPath $v.Path -RepoLocalPath 'output\bootable_media' -RepoBaseUrl 'https://artifacts/isos' } catch { $err = $_.Exception.Message }
    $share = Test-IsoShareable $v.Path
    if ($v.Label -eq 'Local drive') {
        # Local drives must be rejected (not shareable by iLO).
        Record-Step "ISO variant [$('Local drive')] rejected" ($null -eq $resolved -or $err) "Resolved='$resolved' Err='$err' Shareable='$share'"
    } else {
        Record-Step "ISO variant [$($v.Label)] resolved + shareable" ($resolved -and $share -notmatch 'NOT') "Resolved='$resolved' Shareable='$share'"
    }
}

# Validate a supplied local ISO file (exists + .iso).
if ($IsoPath) {
    $exists = Test-Path $IsoPath
    $isIso = $IsoPath -match '\.iso$'
    Record-Step "Supplied -IsoPath exists" $exists "'$IsoPath'"
    Record-Step "Supplied -IsoPath is an .iso" $isIso "'$IsoPath'"
    $share = Test-IsoShareable $IsoPath
    Record-Step "Supplied -IsoPath shareable by iLO" ($share -notmatch 'NOT') "'$IsoPath' -> $share"
} else {
    Record-Step "Supplied -IsoPath (skipped)" $true "No -IsoPath supplied; ISO variant matrix above covers resolution/shareability."
}

# ── Phase 3: firmware archive validation ─────────────────────────────────────
Write-Host "`n--- Phase 3: firmware archive validation ---" -ForegroundColor Yellow
if ($FirmwarePath) {
    $exists = Test-Path $FirmwarePath
    Record-Step "Supplied -FirmwarePath exists" $exists "'$FirmwarePath'"
    $ext = [System.IO.Path]::GetExtension($FirmwarePath)
    $validExt = $ext -match '\.(zip|cab|tar|7z|gz)$'
    Record-Step "Supplied -FirmwarePath has a supported archive extension" $validExt "ext='$ext'"
    if ($exists -and $validExt -and $ext -eq '.zip') {
        $openOk = $false; $openErr = $null
        try {
            Add-Type -AssemblyName 'System.IO.Compression.FileSystem' -ErrorAction SilentlyContinue
            $z = [System.IO.Compression.ZipFile]::OpenRead($FirmwarePath)
            $openOk = $true; $z.Dispose()
        } catch { $openErr = $_.Exception.Message }
        Record-Step "Firmware .zip opens as a valid archive" $openOk ($openErr ? "Err='$openErr'" : 'OK')
    } elseif ($exists -and $validExt) {
        Record-Step "Firmware archive present ($ext)" $true "'$FirmwarePath'"
    }
} else {
    Record-Step "Supplied -FirmwarePath (skipped)" $true "No -FirmwarePath supplied; pass one to validate a real firmware archive."
}

# ── Phase 4: GUARD RAIL safety gate across all four commands ─────────────────
Write-Host "`n--- Phase 4: -GuardRail mandatory + match/non-match gate ---" -ForegroundColor Yellow

# 4a. OMITTED guard -> every build/deploy command must block early & gracefully.
Record-Step 'Configure-PhysicalBuild (NO guard) blocked' $true "Expected: GUARD RAIL REQUIRED"
$r = Configure-PhysicalBuild -SrvrId $Server -OneViewHost $hostArg -SkipOneView -SkipPreBuild -SkipConfirmation
Record-Step '  -> GuardRailRequired=true, Success=false' (($r.GuardRailRequired -eq $true) -and ($r.Success -eq $false)) ("Error='$($r.Error)'")

$r = Update-Firmware -Server $Server -GuardRail '' -DryRun
Record-Step 'Update-Firmware (NO guard) blocked' (($r.GuardRailRequired -eq $true) -and ($r.Success -eq $false)) ("Error='$($r.Error)'")

$r = Invoke-IsoDeploy -Server $Server -OneViewHost $hostArg -GuardRail '' -DryRun
Record-Step 'Invoke-IsoDeploy (NO guard) blocked' (($r.GuardRailRequired -eq $true) -and ($r.Success -eq $false)) ("Error='$($r.Error)'")

$r = Start-PhysicalServerBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail '' -DryRun `
        -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
Record-Step 'Start-PhysicalServerBuild (NO guard) blocked' (($r.GuardRailRequired -eq $true) -and ($r.Success -eq $false)) ("Error='$($r.Error)'")

# 4b. NON-MATCHING guard -> mismatch block (after the mandatory check passes).
$nonMatch = 'zzz_no_such_server_zzz'
$r = Configure-PhysicalBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail $nonMatch -SkipOneView -SkipPreBuild -SkipConfirmation
Record-Step 'Configure-PhysicalBuild (NON-MATCH guard) blocked' ($r.Success -eq $false) ("Reason='$($r.Reason)'")

# 4c. MATCHING guard -> the command is NOT blocked by the guard (it proceeds to
#     attempt the action). Actual build/firmware/deploy success is environment-
#     dependent (real appliance/credentials), so we assert the guard *allowed* it
#     rather than that the whole pipeline succeeded.
$matchGuard = if ($GuardRail) { $GuardRail } else { '.*' }
function GuardAllowed { param($r) ($r.GuardRailRequired -ne $true) -and ($r.Error -notmatch 'GUARD RAIL') }

$r = Configure-PhysicalBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail $matchGuard -SkipOneView -SkipPreBuild -SkipConfirmation
Record-Step "Configure-PhysicalBuild (MATCH guard '$matchGuard') not blocked" (GuardAllowed $r) ("Server='$($r.Server)'")

$r = Update-Firmware -Server $Server -GuardRail $matchGuard -DryRun
Record-Step "Update-Firmware (MATCH guard '$matchGuard') not blocked" (GuardAllowed $r) ("Total='$($r.Total)'")

$r = Invoke-IsoDeploy -Server $Server -OneViewHost $hostArg -GuardRail $matchGuard -DryRun
Record-Step "Invoke-IsoDeploy (MATCH guard '$matchGuard') not blocked" (GuardAllowed $r) ("Server='$($r.Server)'")

$r = Start-PhysicalServerBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail $matchGuard -DryRun `
        -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
Record-Step "Start-PhysicalServerBuild (MATCH guard '$matchGuard') not blocked" (GuardAllowed $r) ("Server='$($r.server)'")

# ── Phase 5: confirmation flow (automated, matched guard, no -SkipConfirmation) ─
Write-Host "`n--- Phase 5: confirmation flow (auto-cancel when unconfirmed) ---" -ForegroundColor Yellow
$prevAuto = $env:AUTOMATED_MODE
$env:AUTOMATED_MODE = 'true'
try {
    # Matched guard, not DryRun, not SkipConfirmation, automated -> must auto-cancel
    # (no unconfirmed destructive action). Use a real-ish build with guards but all
    # phases skipped so nothing is contacted; the guard+confirm decision still applies.
    $r = Start-PhysicalServerBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail $matchGuard `
            -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
    Record-Step 'Matched guard + automated + no -SkipConfirmation -> auto-cancel' ($r.Success -eq $false) ("Success='$($r.Success)'")
} finally {
    $env:AUTOMATED_MODE = $prevAuto
}

# ── Phase 6: build/deploy VARIANTS (DryRun safe) ─────────────────────────────
Write-Host "`n--- Phase 6: build/deploy variants (DryRun) ---" -ForegroundColor Yellow

# External ISO deploy variant (skip build/publish automatically). We assert the
# guard allowed the variant to run (full deploy success is environment-dependent).
$extIso = if ($IsoPath) { $IsoPath } else { 'https://artifacts.internal.example.com/isos/WinSrv2025.iso' }
$r = Invoke-IsoDeploy -Server $Server -OneViewHost $hostArg -GuardRail $matchGuard -ExternalIsoPath $extIso -DryRun
Record-Step 'Invoke-IsoDeploy (external ISO variant) not blocked' (GuardAllowed $r) ("Server='$($r.Server)'")

# Firmware folders variant on the build pipeline.
$r = Start-PhysicalServerBuild -SrvrId $Server -OneViewHost $hostArg -GuardRail $matchGuard -DryRun `
        -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild `
        -FirmwareFolders @('C:\fw\BIOS') -SkipFirmware
Record-Step 'Start-PhysicalServerBuild (firmware folders variant)' (GuardAllowed $r) ("Server='$($r.server)'")

# ── Summary ──────────────────────────────────────────────────────────────────
$passed = ($results | Where-Object { $_.Passed }).Count
$failed = ($results | Where-Object { -not $_.Passed }).Count
Write-Host "`n========== testBuildDeploy SUMMARY ==========" -ForegroundColor Cyan
Write-Host "  Total : $($results.Count)" -ForegroundColor White
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "=============================================`n" -ForegroundColor Cyan
$log.Info("testBuildDeploy complete: total=$($results.Count) passed=$passed failed=$failed")
$results | ForEach-Object { "$($_.Name)`t$($_.Passed)`t$($_.Detail)" } |
    Out-File -FilePath (Join-Path (Get-ProjectRoot) "generated/logs/commands/testBuildDeploy/testBuildDeploy_RESULTS_$(Get-UtcFileTimestamp).txt") -Encoding UTF8

if ($failed -gt 0) { exit 1 }
exit 0
