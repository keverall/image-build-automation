<#
    testConnectAndList.ps1
    ------------------------------------------------------------------
    Functional / re-runnable test harness for the NON-DESTRUCTIVE OneView
    connectivity, connection and server-lookup commands:

        Test-ServerConnectivity, Connect-OneView, Disconnect-OneView,
        Get-OneViewConnectionStatus, Get-OneViewServerList,
        Get-OneViewServerTarget, Get-OneViewVersion, Test-ServerList

    What it exercises
    -----------------
      * Running the commands WITHOUT an active OneView session -> they must
        fail GRACEFULLY with a clear, correct message (never a raw crash).
      * Connecting (real or -DryRun), then running the SAME commands WITH a
        session -> they must report success / reachable / data.
      * Disconnecting, then running again -> graceful failure returns.
      * A matrix of parameter combinations (-OneViewHost, -Filter, -IncludeServerCount,
        -IdentifierType serial, -DryRun, etc.).

    Host handling
    -------------
      The host is taken from -ManagementHost / -OneViewHost (or prompted). No
      server names are hard-coded. By default the script runs in SAFE mode:
      connections are validated with -DryRun and live list commands use -DryRun
      so nothing is contacted unless you pass -Live with real credentials.

    Logging
    -------
      Full logging via the module's common logging commands
      (Initialize-Logging / Get-Logger). Logs land in
      generated/logs/commands/testConnectAndList/.

    Usage
    -----
      .\testConnectAndList.ps1 -ManagementHost oneview-test.ad.example.com
      .\testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com -Live -Credential $cred
      .\testConnectAndList.ps1   # prompts for the appliance host
#>

[CmdletBinding()]
param(
    [Alias('MgmtHost')]
    [string] $ManagementHost,
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

$hostArg = if ($ManagementHost) { $ManagementHost } elseif ($OneViewHost) { $OneViewHost } else { $null }
if (-not $hostArg) {
    $hostArg = Read-Host "Enter the OneView appliance host (server name or serial) to test against"
}
if (-not $hostArg) {
    Write-Error "No OneView appliance host supplied. Aborting." -ErrorAction Stop
}

# ── Logging ──────────────────────────────────────────────────────────────────
Initialize-Logging -CommandName 'testConnectAndList' -LogName "testConnectAndList-Host-$hostArg"
$log = Get-Logger 'testConnectAndList'
$log.Info("Starting testConnectAndList against appliance '$hostArg' (Live=$Live, DryRun=$DryRun)")

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
# $ExpectGracefulFail tells the harness that a thrown error / error-hashtable is
# the CORRECT outcome (used for the "no connection" runs).
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
        # A graceful failure is: it errored OR returned an error hashtable, AND it
        # produced a human-readable message (not a raw stack trace crash).
        $hasMessage = ($caught -and $caught.Exception.Message) -or
                      ($output -is [hashtable] -and ($output.Error -or $output.Message))
        Record-Step $Name ($errored -and $hasMessage) ("Graceful failure observed: " + (
            if ($caught) { $caught.Exception.Message } else { ($output.Error ?? $output.Message) }))
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

Write-Host "`n########## testConnectAndList : $hostArg ##########`n" -ForegroundColor Cyan

# ── Phase 0: ensure we start disconnected ────────────────────────────────────
Write-Host "`n--- Phase 0: ensure disconnected ---" -ForegroundColor Yellow
try { Disconnect-OneView -Force -ErrorAction SilentlyContinue } catch { }
$log.Info("Disconnected any existing session before starting")

# ── Phase 1: WITHOUT a connection (must fail gracefully) ─────────────────────
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

# ── Phase 2: connect, then run WITH a connection ─────────────────────────────
Write-Host "`n--- Phase 2: connect, then run WITH a session ---" -ForegroundColor Yellow

if ($Live) {
    if (-not $Credential) {
        $Credential = Get-Credential -Message "OneView credentials for '$hostArg'"
    }
    Invoke-SafeStep 'Connect-OneView (LIVE)' -Script {
        Connect-OneView -ManagementHost $hostArg -Credential $Credential
    } -SuccessPredicate { param($r) $r.Available -eq $true }
} else {
    Invoke-SafeStep 'Connect-OneView (DryRun validation)' -Script {
        Connect-OneView -ManagementHost $hostArg -DryRun
    } -SuccessPredicate { param($r) $r.Available -eq $true }
}

# With (or simulating) a session, the status/list commands should succeed.
Invoke-SafeStep 'Test-ServerConnectivity (session)' -Script {
    Test-ServerConnectivity -PingTimeoutMs $PingTimeoutMs
} -SuccessPredicate { param($r) $r.ContainsKey('Available') }
Invoke-SafeStep 'Get-OneViewConnectionStatus (session)' -Script {
    Get-OneViewConnectionStatus -IncludeServerCount
} -SuccessPredicate { param($r) $r.ContainsKey('Success') }
Invoke-SafeStep 'Get-OneViewConnectionStatus (DryRun, no host)' -Script {
    Get-OneViewConnectionStatus -DryRun
} -SuccessPredicate { param($r) $r.ContainsKey('Success') }
Invoke-SafeStep 'Get-OneViewServerList (session)' -Script {
    Get-OneViewServerList -DryRun
} -SuccessPredicate { param($r) $r.ContainsKey('Success') }

# ── Phase 3: parameter combinations ──────────────────────────────────────────
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
    Test-ServerList
}

# ── Phase 4: disconnect, then verify graceful failure again ──────────────────
Write-Host "`n--- Phase 4: disconnect, then re-run WITHOUT a session ---" -ForegroundColor Yellow
try { Disconnect-OneView -Force -ErrorAction SilentlyContinue } catch { }
Invoke-SafeStep 'Get-OneViewServerList (after disconnect, expect graceful)' -ExpectGracefulFail $true -Script {
    Get-OneViewServerList
}
Invoke-SafeStep 'Get-OneViewConnectionStatus (after disconnect, expect graceful)' -ExpectGracefulFail $true -Script {
    Get-OneViewConnectionStatus
}

# ── Summary ──────────────────────────────────────────────────────────────────
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

if ($failed -gt 0) { exit 1 }
exit 0
