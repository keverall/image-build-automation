#
# Public/Get-OneViewVersion.ps1 - Report OneView library + appliance versions
#
# Terminal-friendly diagnostic that answers two distinct questions that are
# easy to conflate:
#   1. Which HPEOneView PowerShell LIBRARY is loaded/installed on THIS machine?
#      (Policy: only HPEOneView.1000 is supported.)
#   2. Which version does the OneView APPLIANCE report?
#      (GET /rest/version currentVersion - an appliance/REST value, NOT the
#      PowerShell module version.)
#

function Get-OneViewVersion {
    <#
    .SYNOPSIS
        Show the HPEOneView PowerShell module version(s) on this machine and,
        when reachable, the version reported by the OneView appliance.

    .DESCRIPTION
        Local checks (always performed):
          * Loaded HPEOneView.*/HPOneView.* modules in this session (name,
            version, path).
          * Installed HPEOneView.*/HPOneView.* modules on PSModulePath.
          * Compliance with the HPEOneView.1000-only policy, including the
            exact remediation command when a stray version (e.g. HPEOneView.860)
            is found.

        Appliance check (best effort):
          * If -OneViewHost is supplied, or an active session exists, queries
            GET /rest/version (unauthenticated) and reports currentVersion.
            This value comes from the appliance and is unrelated to the local
            module version.

    .PARAMETER OneViewHost
        Optional appliance hostname/IP. Defaults to the active session's
        appliance when one exists. Skips the appliance probe when unresolved.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER TimeoutSec
        Appliance probe timeout (default 15 s).

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself). By default the command writes the report
        to the host and returns nothing on the success stream.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream. By
        default the command writes only the report and returns nothing, so the
        terminal/log never receives a truncated hashtable dump. Capture the
        result into a variable, e.g. `$r = Get-OneViewVersion -PassThru`, for
        scripting.

    .OUTPUTS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys Success, RequiredModule, Compliant, LoadedModules,
        InstalledModules, NonCompliantLoaded, NonCompliantInstalled, Appliance,
        ApplianceVersion, ApplianceReachable, Error. With -Json, a JSON [string]
        representation of the same data.

    .EXAMPLE
        Get-OneViewVersion

        Reports local module state and, if a session is active, the appliance version.

    .EXAMPLE
        Get-OneViewVersion -OneViewHost oneview.example.com
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('OVHost')]
        [string] $OneViewHost,
        [int]    $Port = 443,
        [Alias('SkipCert')]
        [bool]   $SkipCertificateCheck = $true,
        [Alias('Timeout')]
        [int]    $TimeoutSec = 15,
        [Alias('Q')]
        [switch] $Quiet,
        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru
    )

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewVersion/.
    Initialize-Logging -CommandName 'Get-OneViewVersion' -LogName "Get-OneViewVersion-Host-$($OneViewHost ?? 'unspecified')"
    $logger = Get-Logger 'Get-OneViewVersion'

    $moduleStatus = Get-OneViewModuleStatus

    $result = @{
        Success               = $true
        RequiredModule        = $moduleStatus.RequiredModule
        Compliant             = $moduleStatus.Compliant
        LoadedModules         = $moduleStatus.LoadedModules
        InstalledModules      = $moduleStatus.InstalledModules
        NonCompliantLoaded    = $moduleStatus.NonCompliantLoaded
        NonCompliantInstalled = $moduleStatus.NonCompliantInstalled
        Appliance             = $null
        ApplianceVersion      = $null
        ApplianceReachable    = $null
        Error                 = $null
    }

    # Resolve appliance host: explicit parameter wins, else active session.
    if (-not $OneViewHost) {
        $activeSession = Get-OneViewActiveSession
        if ($activeSession) { $OneViewHost = $activeSession.Name }
    }

    if ($DryRun) {
        $msg = "[DRY RUN] Get-OneViewVersion Host=$OneViewHost"
        $logger.Info($msg); Write-Host $msg
        $result.Appliance = $OneViewHost
        $result.DryRun    = $true
        return (_Emit-GetOneViewVersionResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    if ($OneViewHost) {
        $result.Appliance = $OneViewHost
        try {
            $ver = Invoke-RestMethod -Uri "https://$OneViewHost`:$Port/rest/version" -Method Get `
                -SkipCertificateCheck:$SkipCertificateCheck -TimeoutSec $TimeoutSec -ErrorAction Stop
            $result.ApplianceReachable = $true
            if ($ver -and $ver.currentVersion) { $result.ApplianceVersion = $ver.currentVersion }
        } catch {
            $result.ApplianceReachable = $false
            $result.Error = "Appliance '$OneViewHost' version probe failed: $($_.Exception.Message)"
        }
    }

    if (-not $moduleStatus.Compliant) {
        $result.Success = $false
        $names = $moduleStatus.NonCompliantLoaded -join ', '
        $result.Error = (@($result.Error, "Unsupported HPE OneView module(s) loaded: $names. Only $($moduleStatus.RequiredModule) is supported. Run: Remove-Module $names -Force, then uninstall/delete the module folder.") | Where-Object { $_ }) -join ' | '
    }

    $logger.Info("Get-OneViewVersion result: Success=$($result.Success) Appliance='$($result.Appliance)' Reachable=$($result.ApplianceReachable) Version='$($result.ApplianceVersion)'")
    return (_Emit-GetOneViewVersionResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}

# ── Result emission ───────────────────────────────────────────────────────────
function _Emit-GetOneViewVersionResult {
    <#
    .SYNOPSIS
        Emits the OneView version result via the shared, DRY _Publish-Result
        helper (consistent with every other automation command).
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-GetOneViewVersionResult -Result $r
    }
}

# ── Output formatting ─────────────────────────────────────────────────────────
function _Format-GetOneViewVersionResult {
    <#
    .SYNOPSIS
        Formats the OneView version result as a clean, readable report.
    #>
    param([hashtable] $Result)

    Write-Host ""
    Write-Host "=============================================="
    Write-Host "  OneView Version Report"
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "  Required module: $($Result.RequiredModule)"
    Write-Host "  Policy compliant: $(if ($Result.Compliant) { 'Yes' } else { 'NO - unsupported module loaded' })"
    Write-Host ""
    Write-Host "  --- Loaded HPEOneView modules (this session) ---"
    if ($Result.LoadedModules.Count -eq 0) {
        Write-Host "    (none loaded)"
    } else {
        foreach ($m in $Result.LoadedModules) {
            Write-Host "    $($m.Name)  v$($m.Version)"
            Write-Host "      $($m.Path)"
        }
    }
    Write-Host ""
    Write-Host "  --- Installed HPEOneView modules (PSModulePath) ---"
    if ($Result.InstalledModules.Count -eq 0) {
        Write-Host "    (none found)"
    } else {
        foreach ($m in $Result.InstalledModules) {
            $flag = if ($m.Name -ne $Result.RequiredModule) { '  <-- UNSUPPORTED, remove' } else { '' }
            Write-Host "    $($m.Name)  v$($m.Version)$flag"
            Write-Host "      $($m.Path)"
        }
    }
    Write-Host ""
    Write-Host "  --- Appliance ---"
    if ($Result.Appliance) {
        Write-Host "    Host:              $($Result.Appliance)"
        Write-Host "    Reachable:         $(if ($Result.ApplianceReachable) { 'Yes' } else { 'No' })"
        Write-Host "    /rest/version:     $($Result.ApplianceVersion) (appliance REST value - NOT the PS module version)"
    } else {
        Write-Host "    (no -OneViewHost supplied and no active session - appliance probe skipped)"
    }
    if ($Result.Error) {
        Write-Host ""
        Write-Host "  Error: $($Result.Error)"
    }
    Write-Host ""
    Write-Host "=============================================="
}

# vim: ts=4 sw=4 et
