#
# Public/Configure-PhysicalBuild.ps1 - Pre-deployment configuration review & 4-eye validation
#
# This command gathers all server identity and deployment information, runs
# pre-build validation, and presents a comprehensive summary for a second
# operator to review before the destructive build is authorized.
#
# It is the read-only counterpart to Start-PhysicalBuild: it performs no
# iLO mount, no ISO attach, no reboot, and no firmware update.
#
# Workflow:
#   1. Resolve target server via OneView (serial, iLO IP, model, rack location)
#   2. Resolve ISO URL (from build or external path)
#   3. Run Test-PreBuildValidation (OneView, iLO, ConfigMgr, network, ISO reachability)
#   4. Present full summary including:
#      - Server identity block (hostname, serial, iLO IP, OneView URI, model, rack)
#      - ISO details (source, URL, what it contains)
#      - Destructive actions that WILL be performed (disk wipe, reboot, firmware)
#      - Firmware folders that will be applied post-OS-install
#      - Confirmation prompt (type 'DEPLOY' to proceed to Start-PhysicalBuild)
#

function Configure-PhysicalBuild {
    <#
    .SYNOPSIS
        Review and validate a physical server build plan before deployment.
        4-eye validation gate for production imaging.

    .DESCRIPTION
        Gathers full server identity from OneView, resolves the ISO URL, runs
        pre-build validation, and prints a comprehensive summary of all
        destructive actions that will be performed. Designed for a second
        operator to review and approve before Start-PhysicalBuild is run.

        This command performs NO destructive actions — no ISO attach, no
        reboot, no firmware update. It is read-only / dry-run only.

    .PARAMETER ServerIdentifier
        Target server identifier (hostname, serial, OneView name, iLO IP, bay).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server (if known).

    .PARAMETER IloCredential
        PSCredential for the iLO Redfish check. If omitted, prompted interactively.

    .PARAMETER ExpectedHostname
        Hostname that should result from the build (defaults to SrvrId).

    .PARAMETER Domain
        AD domain to verify in post-build validation.

    .PARAMETER SiteCode
        ConfigMgr site code (for ISO build / pre-build validation).

    .PARAMETER ManagementPoint
        ConfigMgr Management Point FQDN.

    .PARAMETER DistributionPoint
        ConfigMgr Distribution Point FQDN.

    .PARAMETER SiteServer
        ConfigMgr site server FQDN.

    .PARAMETER BootImageName
        ConfigMgr boot image name to verify.

    .PARAMETER TaskSequenceName
        ConfigMgr task sequence name to verify.

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository.

    .PARAMETER RepoLocalPath
        Local filesystem path mirrored to RepoBaseUrl.

    .PARAMETER ExternalIsoPath
        Use a client-supplied ISO instead of building one. Resolved by the single
        shared Resolve-ExternalIsoPath helper. Accepts an UNC/SMB path
        (incl. '//server/share'), a 'cifs://'/'smb://' URL, an HTTPS/NFS URL, or a
        mapped network drive. Local paths are not supported.

    .PARAMETER FirmwareFolders
        Firmware component source directories that will be applied post-OS-install.
        Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER FirmwareConfig
        Firmware manifest JSON for Update-Firmware.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL (offline scenarios).

    .PARAMETER InMaintenanceWindow
        Acknowledge the target server is in an approved maintenance window.

    .PARAMETER SkipPreBuild
        Skip pre-build validation checks.

    .PARAMETER SkipOneView
        Skip OneView target resolution.

    .PARAMETER SkipIlo
        Skip iLO credential / Redfish check.

    .PARAMETER SkipDpMp
        Skip Management Point / Distribution Point reachability check.

    .PARAMETER SkipIsoUrl
        Skip ISO URL reachability check.

    .PARAMETER Force
        Acknowledge server power state is On (informational only — this command
        does not perform any reboot; included for parity with Start-PhysicalBuild).

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt. When set, the function returns
        the plan hashtable without waiting for operator input.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before the
        build plan is even produced. If it is OMITTED the review is aborted early
        with an expressive, logged error. If it does NOT match, the review is
        aborted. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'.

    .RETURNS
        [hashtable] with Success, ServerIdentity, IsoDetails, FirmwareDetails,
        DestructiveActions, ValidationChecks, and Plan (for piping to Start-PhysicalBuild).

    .EXAMPLE
        Configure-PhysicalBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' `
            -ManagementPoint 'mp01.ad.example.com' `
            -DistributionPoint 'dp01.ad.example.com' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -Domain 'ad.example.com' `
            -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .EXAMPLE
        Configure-PhysicalBuild -ServerIdentifier 'srv01' -OneViewHost 'oneview.ad.example.com' -ExternalIsoPath 'https://artifacts/isos/Win2025.iso' -SkipConfirmation
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('SrvrId')]
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('Ilo')]
        [string] $IloIp,
        [System.Management.Automation.PSCredential] $IloCredential,
        [string] $ExpectedHostname = $null,
        [string] $Domain,
        [string] $SiteCode,
        [string] $ManagementPoint,
        [string] $DistributionPoint,
        [string] $SiteServer,
        [string] $BootImageName,
        [string] $TaskSequenceName,
        [string] $RepoBaseUrl,
        [string] $RepoLocalPath,
        [Alias('ExtIso')]
        [string] $ExternalIsoPath,
        [string[]] $FirmwareFolders = @(),
        [string] $FirmwareConfig = $null,
        [switch] $AllowUnknownIsoUrl,
        [switch] $InMaintenanceWindow,
        [switch] $SkipPreBuild,
        [switch] $SkipOneView,
        [switch] $SkipIlo,
        [switch] $SkipDpMp,
        [switch] $SkipIsoUrl,
        [switch] $Force,
        [Alias('SkipConf')]
        [switch] $SkipConfirmation,
        [string] $GuardRail = $null
    )

    if (-not $ExpectedHostname) { $ExpectedHostname = $ServerIdentifier }

    # ── Guard rail is MANDATORY on build/deploy commands ──────────────────────
    # Fail early (graceful, logged) when omitted so we never even produce a plan
    # for an unapproved server on a shared/production network.
    $grCheck = Assert-GuardRailRequired -GuardRail $GuardRail `
        -CommandName 'Configure-PhysicalBuild' -ActionDescription 'build plan review'
    if ($grCheck) { return $grCheck }

    # ── Parameter validation with actionable error messages ───────────────────
    # Build mode (no -ExternalIsoPath) needs ConfigMgr endpoints to build the
    # bootable ISO. External ISO mode and fully-skipped review mode don't.
    if (-not $ExternalIsoPath -and -not $SkipPreBuild) {
        $missing = @()
        if (-not $SiteCode)          { $missing += '-SiteCode (ConfigMgr site code, e.g. P01)' }
        if (-not $ManagementPoint)   { $missing += '-ManagementPoint (ConfigMgr MP FQDN, e.g. mp01.corp.local)' }
        if (-not $DistributionPoint) { $missing += '-DistributionPoint (ConfigMgr DP FQDN, e.g. dp01.corp.local)' }
        if (-not $BootImageName) {
            $missing += '-BootImageName (ConfigMgr boot image name, e.g. "WinPE x64 - HPE")'
        }
        if ($missing.Count -gt 0) {
            $msg = "PRE-BUILD VALIDATION requires ConfigMgr parameters. Missing: $($missing -join '; '). " +
                   "Either supply these parameters, use -SkipPreBuild to skip validation, " +
                   "or use -ExternalIsoPath 'https://...' to deploy a client-supplied ISO."
            $logger = Get-Logger 'Configure-PhysicalBuild'
            $logger.Error($msg)
            Write-Host "`n  [ERROR] $msg" -ForegroundColor Red
            return @{ Success = $false; Error = $msg; Server = $ServerIdentifier }
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Physical Build Configuration Review" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # ── 1. Resolve server identity from OneView ──────────────────────────────
    $serverIdentity = $null
    if (-not $SkipOneView -and $OneViewHost) {
        Write-Host "`n[1/4] Resolving server identity from OneView..." -ForegroundColor Yellow
        $ov = Get-OneViewServerTarget -OneViewHost $OneViewHost -ServerIdentifier $ServerIdentifier -DryRun:$true -PassThru
        if ($ov.Success) {
            $serverIdentity = $ov.Details
            Write-Host "  [OK] Server resolved" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] OneView resolution failed: $($ov.Error)" -ForegroundColor Yellow
        }
    } elseif ($IloIp) {
        Write-Host "`n[1/4] OneView skipped — using iLO IP directly" -ForegroundColor Yellow
        $serverIdentity = @{ ilo_ip = $IloIp; name = $ExpectedHostname; identifier = $ServerIdentifier }
    } else {
        Write-Host "`n[1/4] No OneViewHost or IloIp supplied" -ForegroundColor Yellow
        $serverIdentity = @{ name = $ExpectedHostname; identifier = $ServerIdentifier }
    }

    # ── Guard rail (build/deploy safety gate, review-only) ────────────────────
    # When -GuardRail is supplied, the resolved target name MUST match before we
    # even show the deployment plan. -NonDestructive suppresses the destructive
    # confirmation prompt (this command only reviews; Start-PhysicalServerBuild
    # performs the actual overwrite).
    if ($GuardRail) {
        $guardName   = if ($serverIdentity -and $serverIdentity.name) { $serverIdentity.name } else { $ExpectedHostname }
        $guardSerial = if ($serverIdentity -and $serverIdentity.serial_number) { $serverIdentity.serial_number } else { $null }
        $guardOk = Assert-GuardRail -GuardRail $GuardRail -ResolvedServerName $guardName `
            -SerialNumber $guardSerial -ApplianceName $OneViewHost `
            -ActionDescription 'build plan review' -SkipConfirmation:$SkipConfirmation -NonDestructive
        if (-not $guardOk) {
            return @{
                Success    = $false
                Cancelled  = $true
                Server     = $guardName
                Reason     = "Guard rail mismatch: '$guardName' does not match guard pattern '$GuardRail'. No plan produced."
            }
        }
    }

    # ── 2. Resolve ISO URL ───────────────────────────────────────────────────
    Write-Host "`n[2/4] Resolving ISO..." -ForegroundColor Yellow
    $isoPath = $null
    $isoUrl  = $null
    $isoSource = 'Not specified'

    if ($ExternalIsoPath) {
        $isoSource = "External ISO: $ExternalIsoPath"
        $isoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
        Write-Host "  [OK] Resolved to: $isoUrl" -ForegroundColor Green
    } else {
        $isoSource = "Build from ConfigMgr (SiteCode=$SiteCode)"
        if ($RepoBaseUrl) {
            $isoUrl = "$RepoBaseUrl/WinSrv2025_HPE_BootableMedia_v1.0.iso"
            $isoSource = "ConfigMgr build → $isoUrl"
        }
        Write-Host "  [INFO] ISO will be built and published to: $isoUrl" -ForegroundColor Yellow
    }

    # ── 3. Run pre-build validation ──────────────────────────────────────────
    Write-Host "`n[3/4] Running pre-build validation..." -ForegroundColor Yellow
    $preBuildResult = $null
    if (-not $SkipPreBuild) {
        $preBuildResult = Test-PreBuildValidation -ServerIdentifier $ServerIdentifier `
            -OneViewHost $OneViewHost -IloIp $IloIp `
            -IloCredential $IloCredential `
            -IsoUrl $isoUrl `
            -ManagementPoint $ManagementPoint -DistributionPoint $DistributionPoint `
            -BootImageName $BootImageName -TaskSequenceName $TaskSequenceName `
            -SkipOneView:([bool]$SkipOneView) `
            -SkipIlo:([bool]$SkipIlo) `
            -SkipDpMp:([bool]$SkipDpMp) `
            -SkipIsoUrl:([bool]$SkipIsoUrl -or [string]::IsNullOrEmpty($isoUrl) -or [bool]$AllowUnknownIsoUrl) `
            -DryRun:$true
        if ($preBuildResult.Success) {
            Write-Host "  [OK] All pre-build checks passed" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Some pre-build checks failed (review below)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [SKIP] Pre-build validation skipped" -ForegroundColor Gray
    }

    # ── 4. Present comprehensive summary ─────────────────────────────────────
    Write-Host "`n[4/4] Deployment Summary" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Server identity block
    Write-Host "`n  ─ SERVER IDENTITY ─" -ForegroundColor Yellow
    Write-Host "  Target:          $($ExpectedHostname)" -ForegroundColor White
    Write-Host "  Identifier:      $($ServerIdentifier)" -ForegroundColor Gray
    if ($serverIdentity) {
        Write-Host "  Serial:          $($serverIdentity.serial_number    ?? 'unknown')" -ForegroundColor White
        Write-Host "  Model:           $($serverIdentity.model          ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  iLO IP:          $($serverIdentity.ilo_ip         ?? $IloIp ?? 'unknown')" -ForegroundColor White
        Write-Host "  OneView URI:     $($serverIdentity.uri             ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  Rack/Position:   $($serverIdentity.rack           ?? 'unknown')" -ForegroundColor White
        Write-Host "  Server Group:    $($serverIdentity.server_group   ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  Maintenance Mode:$($serverIdentity.maintenance_mode ?? 'unknown')" -ForegroundColor White
    }

    # ISO details
    Write-Host "`n  ─ ISO DETAILS ─" -ForegroundColor Yellow
    Write-Host "  Source:          $isoSource" -ForegroundColor White
    if ($isoUrl) {
        Write-Host "  URL:             $isoUrl" -ForegroundColor Gray
    }
    Write-Host "  Contents:        Windows Server boot media + ConfigMgr task sequence" -ForegroundColor Gray

    # Firmware details
    Write-Host "`n  ─ FIRMWARE UPDATE (post-OS-install) ─" -ForegroundColor Yellow
    if ($FirmwareFolders.Count -gt 0) {
        Write-Host "  Component folders:" -ForegroundColor White
        foreach ($f in $FirmwareFolders) {
            Write-Host "    - $f" -ForegroundColor Gray
        }
        Write-Host "  Manifest:         $($FirmwareConfig ?? 'default manifest (DryRun only)')" -ForegroundColor Gray
    } else {
        Write-Host "  No additional firmware folders specified." -ForegroundColor Gray
        Write-Host "  Manifest:         $($FirmwareConfig ?? 'default')" -ForegroundColor Gray
    }

    # Destructive actions
    Write-Host "`n  ─ DESTRUCTIVE ACTIONS (will be executed by Start-PhysicalBuild) ─" -ForegroundColor Red
    Write-Host "  1. Disk partitioning & formatting (ALL data will be erased)" -ForegroundColor Red
    Write-Host "  2. Windows OS installation from ISO" -ForegroundColor Red
    Write-Host "  3. Server reboot into installed OS" -ForegroundColor Red
    Write-Host "  4. Post-build validation (hostname, domain join, drivers)" -ForegroundColor Red
    if ($FirmwareFolders.Count -gt 0 -or $FirmwareConfig) {
        Write-Host "  5. Firmware update via HPE SUT (reboots during apply)" -ForegroundColor Red
    }

    # Validation results
    if ($preBuildResult) {
        Write-Host "`n  ─ PRE-BUILD VALIDATION RESULTS ─" -ForegroundColor Yellow
        foreach ($key in $preBuildResult.Checks.Keys) {
            $check = $preBuildResult.Checks[$key]
            $statusColor = if ($check.status -eq 'PASS') { 'Green' } else { 'Yellow' }
            Write-Host "  [$($check.status)] $key : $($check.details)" -ForegroundColor $statusColor
        }
    }

    # Power state warning
    if ($InMaintenanceWindow) {
        Write-Host "`n  Maintenance window: ACKNOWLEDGED" -ForegroundColor Green
    } else {
        Write-Host "`n  Maintenance window: NOT acknowledged (-InMaintenanceWindow not set)" -ForegroundColor Yellow
        Write-Host "  This build will reboot a running server if it is On." -ForegroundColor Red
    }

    Write-Host "`n══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

    # ── Confirmation prompt ─────────────────────────────────────────────────
    if (-not $SkipConfirmation) {
        # Never block on interactive input in automated / non-interactive runs
        # (CI, `make test`, Pester). Auto-cancel with a clear reason instead.
        $isAutomated = ($env:AUTOMATED_MODE -eq 'true') -or ($env:CI -eq 'true')
        $isInteractive = ([Console]::IsInputRedirected -eq $false) -and ($Host.UI.RawUI -ne $null)
        if ($isAutomated -or -not $isInteractive) {
            Write-Host "`n  Non-interactive / automated mode detected - deployment confirmation skipped (auto-cancelled)." -ForegroundColor Yellow
            return @{
                Success          = $false
                Cancelled        = $true
                Server           = $ExpectedHostname
                Reason           = "Non-interactive mode: operator confirmation required but input is not available"
                ServerIdentity   = $serverIdentity
                IsoUrl           = $isoUrl
                ValidationChecks = if ($preBuildResult) { $preBuildResult.Checks } else { $null }
            }
        }

        Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  ⚠  DESTRUCTIVE ACTION WARNING                       ║" -ForegroundColor Red
        Write-Host "  ║  This will ERASE ALL DATA on the target server and    ║" -ForegroundColor Red
        Write-Host "  ║  install a fresh Windows Server OS + firmware.        ║" -ForegroundColor Red
        Write-Host "  ║                                                      ║" -ForegroundColor Red
        Write-Host "  ║  Type 'DEPLOY' (without quotes) to proceed.           ║" -ForegroundColor Red
        Write-Host "  ║  Anything else cancels this build.                    ║" -ForegroundColor Red
        Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        $response = Read-Host "  Confirm deployment for '$ExpectedHostname'"
        if ($response -ne 'DEPLOY') {
            Write-Host "  Build CANCELLED by operator." -ForegroundColor Yellow
            return @{
                Success             = $false
                Cancelled           = $true
                Server              = $ExpectedHostname
                Reason              = "Operator did not confirm with 'DEPLOY'"
                ServerIdentity      = $serverIdentity
                IsoUrl              = $isoUrl
                ValidationChecks    = if ($preBuildResult) { $preBuildResult.Checks } else { $null }
            }
        }
        Write-Host "`n  ✓ CONFIRMED — proceed with Start-PhysicalBuild" -ForegroundColor Green
    }

    # Return a structured plan that can be piped to Start-PhysicalBuild
    return @{
        Success             = $true
        Server              = $ExpectedHostname
        ServerIdentifier    = $ServerIdentifier
        ServerIdentity      = $serverIdentity
        IsoUrl              = $isoUrl
        ExternalIsoPath     = $ExternalIsoPath
        FirmwareFolders     = $FirmwareFolders
        FirmwareConfig      = $FirmwareConfig
        OneViewHost         = $OneViewHost
        IloIp               = if ($serverIdentity -and $serverIdentity.ilo_ip) { $serverIdentity.ilo_ip } else { $IloIp }
        OneViewDetails      = $serverIdentity
        ExpectedHostname    = $ExpectedHostname
        Domain              = $Domain
        SiteCode            = $SiteCode
        ManagementPoint     = $ManagementPoint
        DistributionPoint   = $DistributionPoint
        SiteServer          = $SiteServer
        BootImageName       = $BootImageName
        TaskSequenceName    = $TaskSequenceName
        RepoBaseUrl         = $RepoBaseUrl
        RepoLocalPath       = $RepoLocalPath
        AllowUnknownIsoUrl  = [bool]$AllowUnknownIsoUrl
        InMaintenanceWindow = [bool]$InMaintenanceWindow
        ValidationChecks    = if ($preBuildResult) { $preBuildResult.Checks } else { $null }
        PreBuildSuccess     = if ($preBuildResult) { $preBuildResult.Success } else { $null }
        Timestamp           = Get-UtcTimestamp
    }
}
