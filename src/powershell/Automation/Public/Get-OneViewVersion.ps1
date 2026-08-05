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
        Suppress the formatted console report; return only the hashtable.

    .OUTPUTS
        [hashtable] Success, RequiredModule, Compliant, LoadedModules,
        InstalledModules, NonCompliantLoaded, NonCompliantInstalled,
        Appliance, ApplianceVersion, ApplianceReachable, Error.

    .EXAMPLE
        Get-OneViewVersion

        Reports local module state and, if a session is active, the appliance version.

    .EXAMPLE
        Get-OneViewVersion -OneViewHost va-oneviewt-01
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
        [switch] $Quiet
    )

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

    if (-not $Quiet) {
        Write-Output "=============================================="
        Write-Output "  OneView Version Report"
        Write-Output "=============================================="
        Write-Output ""
        Write-Output "  Required module: $($result.RequiredModule)"
        Write-Output "  Policy compliant: $(if ($result.Compliant) { 'Yes' } else { 'NO - unsupported module loaded' })"
        Write-Output ""
        Write-Output "  --- Loaded HPEOneView modules (this session) ---"
        if ($result.LoadedModules.Count -eq 0) {
            Write-Output "    (none loaded)"
        } else {
            foreach ($m in $result.LoadedModules) {
                Write-Output "    $($m.Name)  v$($m.Version)"
                Write-Output "      $($m.Path)"
            }
        }
        Write-Output ""
        Write-Output "  --- Installed HPEOneView modules (PSModulePath) ---"
        if ($result.InstalledModules.Count -eq 0) {
            Write-Output "    (none found)"
        } else {
            foreach ($m in $result.InstalledModules) {
                $flag = if ($m.Name -ne $result.RequiredModule) { '  <-- UNSUPPORTED, remove' } else { '' }
                Write-Output "    $($m.Name)  v$($m.Version)$flag"
                Write-Output "      $($m.Path)"
            }
        }
        Write-Output ""
        Write-Output "  --- Appliance ---"
        if ($result.Appliance) {
            Write-Output "    Host:              $($result.Appliance)"
            Write-Output "    Reachable:         $(if ($result.ApplianceReachable) { 'Yes' } else { 'No' })"
            Write-Output "    /rest/version:     $($result.ApplianceVersion) (appliance REST value - NOT the PS module version)"
        } else {
            Write-Output "    (no -OneViewHost supplied and no active session - appliance probe skipped)"
        }
        if ($result.Error) {
            Write-Output ""
            Write-Output "  Error: $($result.Error)"
        }
        Write-Output ""
        Write-Output "=============================================="
    }

    return $result
}

# vim: ts=4 sw=4 et
