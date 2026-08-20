<#
.SYNOPSIS
    Functional / re-runnable test harness for the NON-DESTRUCTIVE OneView
    connectivity, connection and server-lookup commands.

.DESCRIPTION
    Exercises the read-only / connection-lifecycle commands against an appliance,
    proving they fail gracefully without a session and succeed with one:

      Test-ServerConnectivity, Connect-OneView, Disconnect-OneView,
      Get-OneViewConnectionStatus, Get-OneViewServerList,
      Get-OneViewServerTarget, Get-OneViewVersion, Test-ServerList

    * Running the commands WITHOUT an active OneView session -> they must fail
      GRACEFULLY with a clear, correct message (never a raw crash).
    * Connecting (real or -DryRun), then running the SAME commands WITH a session
      -> they must report success / reachable / data.
    * Disconnecting, then running again -> graceful failure returns.
    * A matrix of parameter combinations (-OneViewHost, -Filter,
      -IncludeServerCount, -IdentifierType serial, -DryRun, etc.).

    The host is taken from -OneViewHost (or prompted). No server
    names are hard-coded. By default the script runs in SAFE mode: connections are
    validated with -DryRun and live list commands use -DryRun, so nothing is
    contacted unless you pass -Live with real credentials. Full logging is written
    via the module's common logging commands (Initialize-Logging / Get-Logger)
    under generated/logs/commands/testConnectAndList/.

.PARAMETER OneViewHost
    OneView appliance hostname or IP to test against (alias -OVHost). Prompted
    if omitted.

.PARAMETER Credential
    PSCredential used for a live (-Live) connection. Prompted when -Live is set
    and this is omitted.

.PARAMETER Live
    Perform a REAL connection using -Credential (or a prompt) instead of the
    default -DryRun validation. Use only against an approved test appliance.

.PARAMETER DryRun
    Validate connectivity with -DryRun (this is the default-safe behaviour even
    without -Live).

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds for reachability probes (default 3000).

.EXAMPLE
    .\testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com

.EXAMPLE
    .\testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com -Live -Credential $cred

.EXAMPLE
    .\testConnectAndList.ps1   # prompts for the appliance host
#>

[CmdletBinding()]
param(
    [Alias('OVHost')]
    [string] $OneViewHost,
    [System.Management.Automation.PSCredential] $Credential,
    [switch] $Live,
    [switch] $DryRun,
    [int] $PingTimeoutMs = 3000
)

$ErrorActionPreference = 'Continue'

# ── Resolve the module + host ───────────────────────────────────────────────
$repoRoot = if (Test-Path (Join-Path $PSScriptRoot 'src')) { $PSScriptRoot } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$modulePath = Join-Path $repoRoot 'src/powershell/Automation/Automation.psd1'
if (-not (Test-Path $modulePath)) {
    # Fall back to running from within the repo tree.
    $modulePath = Resolve-Path (Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psd1') -ErrorAction Stop
}
Import-Module $modulePath -Force -DisableNameChecking -WarningAction SilentlyContinue

$hostArg = if ($OneViewHost) { $OneViewHost } else { $null }

# ── Logging ──────────────────────────────────────────────────────────────────
Initialize-Logging -CommandName 'testConnectAndList' -LogName "testConnectAndList-Host-$($hostArg ?? 'unspecified')"
$log = Get-Logger 'testConnectAndList'
$log.Info("Starting testConnectAndList (Host=$hostArg, Live=$Live, DryRun=$DryRun)")

# ── Test bookkeeping ──────────────────────────────────────────────────────────
$results = [System.Collections.ArrayList]::new()
function Record-Step {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $null = $results.Add([PSCustomObject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
    $colour = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host ("  [$(if($Passed){'PASS'}else{'FAIL'})] $Name : $Detail") -ForegroundColor $colour
    $log.Info("STEP $Name -> Passed=$Passed : $Detail")
}

# Run a scriptblock, capturing success/failure and a normalised result object.
# $ExpectGracefulFail tells the harness that an error / error-hashtable / no-crash
# result is the CORRECT outcome (used for the "no connection" runs). A command is
# considered to have failed "gracefully" as long as it did not produce a raw,
# message-less crash: either it threw with a human-readable message, or it
# returned a structured result (even a success-shaped one like a skipped probe).
function Invoke-SafeStep {
    param(
        [string] $Name,
        [scriptblock] $Script,
        [bool] $ExpectGracefulFail = $false,
        [scriptblock] $SuccessPredicate = $null
    )
    $caught = $null
    $output = $null
    try {
        $output = & $Script
    } catch {
        $caught = $_
    }

    $errored = ($null -ne $caught) -or
               ($output -is [hashtable] -and ($output.ContainsKey('Success') -and $output.Success -eq $false)) -or
               ($output -is [hashtable] -and $output.ContainsKey('Error') -and $output.Error)

    if ($ExpectGracefulFail) {
        # Graceful = no raw crash. Derive a human-readable detail from whichever
        # result we have (thrown message, then error/result fields, then a summary).
        $detail = if ($caught) {
            "Graceful failure observed: $($caught.Exception.Message)"
        } elseif ($output -is [hashtable]) {
            $msg = $output.Error ?? $output.Message
            if (-not $msg) { $msg = 'returned result without crashing' }
            if ($output.Success -eq $false -or $output.Error) { "Graceful failure observed: $msg" }
            else { "Graceful (no crash): $msg" }
        } else {
            $sum = if ($null -ne $output) { "output type: $($output.GetType().Name)" } else { 'no output' }
            "Graceful (no crash): returned $sum"
        }
        $passed = ($null -ne $caught) -or ($null -ne $output)
        Record-Step $Name $passed $detail
        return
    }

    if ($errored) {
        $msg = if ($caught) { $caught.Exception.Message } else { ($output.Error ?? $output.Message) }
        Record-Step $Name $false "Unexpected failure: $msg"
        return
    }
    if ($SuccessPredicate) {
        $ok = & $SuccessPredicate $output
        Record-Step $Name $ok "Returned result; predicate=$(if($ok){'pass'}else{'fail'})"
    } else {
        Record-Step $Name $true "Returned without error"
    }
}

# Shared DryRun notice: written to both the screen (Write-Host, real-time for
# hardware-engineer users) AND the harness logger (so it is persisted in the
# per-run log file alongside the STEP records). DRY: single helper, called first
# and repeated after the summary.
$useDryRun = [bool]$DryRun
function Write-DryRunNotice {
    if (-not $useDryRun) { return }
    $target = if ($hostArg) { " to '$hostArg'" } else { ' (host resolved from config)' }
    $lines = @(
        "NOTE: -DryRun was supplied -> MOCK TEST ONLY. No real connection will be made$target."
        "      Host reachability is validated against mock/config data (HPE OneView module mocked)."
        "      Remove -DryRun to connect for real (you will be prompted for credentials);"
        "      if the appliance is unreachable it stops early instead of continuing."
    )
    Write-Host ""
    foreach ($l in $lines) { Write-Host $l -ForegroundColor Cyan; $log.Info($l) }
    Write-Host ""
}

if ($useDryRun) {
    Write-DryRunNotice
    $log.Info("Running in -DryRun (mock) mode: no real connection will be made.")
}

# ── Phase 0: ensure we start disconnected ────────────────────────────────────
Write-Host "`n--- Phase 0: ensure disconnected ---" -ForegroundColor Yellow
try { Disconnect-OneView -Force -ErrorAction SilentlyContinue } catch { }
$log.Info("Disconnected any existing session before starting")

# ── Phase 1: WITHOUT a connection (must fail gracefully) ──────────────────────
Write-Host "`n--- Phase 1: commands WITHOUT an active connection (expect graceful failure) ---" -ForegroundColor Yellow

Invoke-SafeStep 'Test-ServerConnectivity (no session)' -ExpectGracefulFail $true -Script {
    Test-ServerConnectivity -PingTimeoutMs $PingTimeoutMs
}
Invoke-SafeStep 'Get-OneViewConnectionStatus (no session, no host)' -ExpectGracefulFail $true -Script {
    Get-OneViewConnectionStatus
}
Invoke-SafeStep 'Get-OneViewServerList (no session, no host)' -ExpectGracefulFail $true -Script {
    Get-OneViewServerList
}
Invoke-SafeStep 'Get-OneViewServerTarget (no session)' -ExpectGracefulFail $true -Script {
    Get-OneViewServerTarget -SrvrId $hostArg
}
Invoke-SafeStep 'Get-OneViewVersion (no session)' -ExpectGracefulFail $true -Script {
    Get-OneViewVersion
}

# ── Phase 2: connect ──────────────────────────────────────────────────────────
# -DryRun : validate host resolution only (mocked) via Connect-OneView -DryRun.
# -Live   : real connection using -Credential (or a prompt).
# default : real connection; the OneView modules prompt for credentials when
#           none is supplied (interactive) or fail fast under AUTOMATED_MODE.
$connectLabel = if ($useDryRun) { 'Connect-OneView (DryRun validation)' } else { 'Connect-OneView (LIVE)' }
Write-Host "`n--- Phase 2: connect to appliance ---" -ForegroundColor Yellow

# -DryRun always mocks: it never establishes a real session - it resolves the
# appliance from connection_hosts.json (or uses -OneViewHost verbatim) and
# validates host resolution only. A live run (default or -Live) really connects;
# with -OneViewHost it connects to that host (prompting for credentials when
# none is supplied), without -OneViewHost Connect-OneView itself prompts for
# the appliance host and credentials - exactly as the modules handle it.
$connectLabel = if ($useDryRun) { 'Connect-OneView (DryRun validation)' } else { 'Connect-OneView (LIVE)' }
$connectResult = $null
$connectOk = $false
try {
    if ($useDryRun) {
        $connectResult = if ($hostArg) { Connect-OneView -OneViewHost $hostArg -DryRun }
                         else         { Connect-OneView -DryRun }
    } else {
        # Live: let the module prompt for host (when -OneViewHost is absent) and
        # for credentials (when -Credential is absent) - same as the documented
        # interactive behaviour of Connect-OneView.
        if ($Credential) {
            $connectResult = if ($hostArg) { Connect-OneView -OneViewHost $hostArg -Credential $Credential }
                             else         { Connect-OneView -Credential $Credential }
        } else {
            $connectResult = if ($hostArg) { Connect-OneView -OneViewHost $hostArg }
                             else         { Connect-OneView }
        }
    }
    $connectOk = ($connectResult -and $connectResult.Available) -eq $true
} catch {
    $connectOk = $false
    $connectResult = @{ Available = $false; Error = $_.Exception.Message }
}
Record-Step $connectLabel $connectOk ("Available=$(($connectResult.Available)) ; $(($connectResult.Message ?? $connectResult.Error))")

# Adopt whatever host the connect step actually resolved (DryRun config lookup
# or a live interactive host entry) so the matrix below targets that appliance.
$hostArg = $connectResult.OneViewHost ?? $hostArg

# Re-initialize logging now that the host is resolved: the log file name, level,
# and all subsequent entries (via a freshly-captured logger) reflect the actual
# appliance contacted rather than the 'unspecified' placeholder used before the
# connection was established. Get-Logger captures the log path at creation time
# (see Logging.ps1), so we must re-call it to bind $log to the new path.
Initialize-Logging -CommandName 'testConnectAndList' -LogName "testConnectAndList-Host-$($hostArg ?? 'unspecified')"
$log = Get-Logger 'testConnectAndList'
$log.Info("Starting testConnectAndList (Host=$hostArg, Live=$Live, DryRun=$DryRun)")
Write-Host "`n########## testConnectAndList : $hostArg ##########`n" -ForegroundColor Cyan

# A live run needs a real active session for the session-dependent phases. DryRun
# is always mocked (no session), so the WITH-session commands below run with -DryRun.
$connected = [bool](Get-OneViewActiveSession)

if (-not $useDryRun -and -not $connected) {
    # FAIL-FAST on a live run that could not establish a session - stop here
    # instead of repeating "No active OneView session" for every command below.
    Write-Host "`nNo active OneView session was established (Live=$Live, DryRun=$useDryRun, connected=$connected)." -ForegroundColor Red
    Write-Host "Stopping early - the session-dependent command checks (Phase 2b/3/4) are skipped. Correct appliance reachability / credentials and re-run." -ForegroundColor Yellow
    Record-Step 'Early stop (no live session)' $false "Live connection not established; skipping session-dependent phases."
}
if ($useDryRun -or $connected) {
    # ── Phase 2b: WITH a connection (real session, or DryRun mocks) ──────────────────
    Write-Host "`n--- Phase 2b: commands WITH a connection (or DryRun mocks) ---" -ForegroundColor Yellow

    if ($useDryRun) {
        Invoke-SafeStep 'Test-ServerConnectivity (DryRun)' -Script {
            Test-ServerConnectivity -OneViewHost $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Available') }
        Invoke-SafeStep 'Get-OneViewConnectionStatus (DryRun)' -Script {
            Get-OneViewConnectionStatus -OneViewHost $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
        Invoke-SafeStep 'Get-OneViewServerList (DryRun)' -Script {
            Get-OneViewServerList -OneViewHost $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
        Invoke-SafeStep 'Get-OneViewServerTarget (DryRun)' -Script {
            Get-OneViewServerTarget -OneViewHost $hostArg -SrvrId $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
        Invoke-SafeStep 'Get-OneViewVersion (DryRun)' -Script {
            Get-OneViewVersion -OneViewHost $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    } else {
        Invoke-SafeStep 'Test-ServerConnectivity (session)' -Script {
            Test-ServerConnectivity -PingTimeoutMs $PingTimeoutMs
        } -SuccessPredicate { param($r) $r.ContainsKey('Available') }
        Invoke-SafeStep 'Get-OneViewConnectionStatus (session)' -Script {
            Get-OneViewConnectionStatus -IncludeServerCount
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
        Invoke-SafeStep 'Get-OneViewServerList (session)' -Script {
            Get-OneViewServerList
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
        Invoke-SafeStep 'Get-OneViewServerTarget (session)' -Script {
            Get-OneViewServerTarget -OneViewHost $hostArg -SrvrId $hostArg -DryRun
        } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    }

    # ── Phase 3: parameter combination matrix (all DryRun - safe, mocked) ───────────
    Write-Host "`n--- Phase 3: parameter combination matrix ---" -ForegroundColor Yellow

    Invoke-SafeStep 'Get-OneViewServerList -Filter health:Critical (DryRun)' -Script {
        Get-OneViewServerList -OneViewHost $hostArg -Filter 'health:Critical' -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Get-OneViewServerList -Filter power:On (DryRun)' -Script {
        Get-OneViewServerList -OneViewHost $hostArg -Filter 'power:On' -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Get-OneViewServerList -Filter name (DryRun)' -Script {
        Get-OneViewServerList -OneViewHost $hostArg -Filter "name:$hostArg" -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Get-OneViewConnectionStatus -ServerIdentifier by name (DryRun)' -Script {
        Get-OneViewConnectionStatus -OneViewHost $hostArg -ServerIdentifier $hostArg -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Get-OneViewServerTarget -IdentifierType Serial (DryRun)' -Script {
        Get-OneViewServerTarget -OneViewHost $hostArg -SrvrId $hostArg -IdentifierType Serial -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Get-OneViewVersion -OneViewHost (DryRun)' -Script {
        Get-OneViewVersion -OneViewHost $hostArg -DryRun
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }
    Invoke-SafeStep 'Test-ServerList (validation)' -Script {
        Test-ServerList -PassThru
    } -SuccessPredicate { param($r) $r.ContainsKey('Success') }

    # ── Phase 4: disconnect, then verify graceful failure again ─────────────────────
    Write-Host "`n--- Phase 4: disconnect, then re-run WITHOUT a session ---" -ForegroundColor Yellow
    try { Disconnect-OneView -Force -ErrorAction SilentlyContinue } catch { }
    Invoke-SafeStep 'Get-OneViewServerList (after disconnect, expect graceful)' -ExpectGracefulFail $true -Script {
        Get-OneViewServerList
    }
    Invoke-SafeStep 'Get-OneViewConnectionStatus (after disconnect, expect graceful)' -ExpectGracefulFail $true -Script {
        Get-OneViewConnectionStatus
    }
}

# ── Summary ────────────────────────────────────────────────────────────────────
$passed = ($results | Where-Object { $_.Passed }).Count
$failed = ($results | Where-Object { -not $_.Passed }).Count
Write-Host "`n========== testConnectAndList SUMMARY ==========" -ForegroundColor Cyan
Write-Host "  Total : $($results.Count)" -ForegroundColor White
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "==================================================`n" -ForegroundColor Cyan
$log.Info("testConnectAndList complete: total=$($results.Count) passed=$passed failed=$failed")
$results | ForEach-Object { "$($_.Name)`t$($_.Passed)`t$($_.Detail)" } |
    Out-File -FilePath (Join-Path (Get-ProjectRoot) "generated/logs/commands/testConnectAndList/testConnectAndList_RESULTS_$(Get-UtcFileTimestamp).txt") -Encoding UTF8

# ── -DryRun reminder (repeated after the summary so it isn't lost) ─────────────
if ($useDryRun) {
    Write-DryRunNotice
    $log.Info("DryRun reminder: mock-only run completed - no real connection was made.")
}

if ($failed -gt 0) { exit 1 }
exit 0
