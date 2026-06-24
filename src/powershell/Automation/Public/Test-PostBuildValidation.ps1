#
# Public/Test-PostBuildValidation.ps1 — Post-build validation checklist
#
# Implements the post-build checks from the runbook:
#   1. Expected hostname assigned (WinRM)
#   2. Domain join successful (computer object)
#   3. Operating system version + edition verified
#   4. HPE device drivers present
#   5. ConfigMgr client healthy and assigned to site
#   6. RDP / PowerShell / management agents operational
#   7. Build outcome recorded in audit log
#
# All connection details are runtime parameters.
#

function Test-PostBuildValidation {
    <#
    .SYNOPSIS
        Run post-build validation checks for a physical server build.
        Callable from the module Router.

    .DESCRIPTION
        Connects over WinRM to the freshly-built server and verifies the
        post-build state.  Returns a hashtable of named checks.

    .PARAMETER Hostname
        Target server hostname (FQDN or short).

    .PARAMETER ExpectedHostname
        Expected hostname for cross-check. Defaults to -Hostname.

    .PARAMETER Domain
        AD domain to verify join (e.g. ad.example.com).

    .PARAMETER ExpectedOsVersion
        Expected OS version string (e.g. '10.0.20348' for Server 2022).

    .PARAMETER SkipCmClient
        Skip ConfigMgr client check.

    .PARAMETER SkipDrivers
        Skip driver presence check.

    .PARAMETER SkipRemote
        Skip all WinRM-dependent checks (only do local / metadata validation).

    .PARAMETER DryRun
        Skip WinRM probes — assume checks pass.

    .RETURNS
        [hashtable] with Success (bool), Checks, AuditFile.

    .EXAMPLE
        Test-PostBuildValidation -Hostname 'srv01.ad.example.com' -Domain 'ad.example.com' -ExpectedOsVersion '10.0.20348'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string] $Hostname,
        [string] $ExpectedHostname = $null,
        [string] $Domain,
        [string] $ExpectedOsVersion,
        [switch] $SkipCmClient,
        [switch] $SkipDrivers,
        [switch] $SkipRemote,
        [switch] $DryRun
    )

    $checks  = [ordered]@{}
    $overall = $true
    if (-not $ExpectedHostname) { $ExpectedHostname = $Hostname }

    $Script:checks    = $checks
    $Script:overall   = $overall

    function _Set([string]$name, [bool]$ok, [string]$details) {
        $script:checks[$name] = @{ status = $(if ($ok) { 'PASS' } else { 'FAIL' }); details = $details }
        if (-not $ok) { $script:overall = $false }
    }

    if ($SkipRemote) {
        _Set 'remote_checks_skipped' $true 'Skipped by parameter'
        return @{ Success = $true; Hostname = $Hostname; Checks = $checks }
    }

    $winrmReachable = $false
    if (-not $DryRun) {
        try {
            $r = Invoke-PowerShellScript -Script "Test-WSMan -ComputerName $Hostname -ErrorAction SilentlyContinue" -TimeoutSeconds 10
            $winrmReachable = [bool]$r.Success
        } catch { $winrmReachable = $false }
    } else {
        $winrmReachable = $true
    }
    _Set 'winrm_reachable' $winrmReachable $(if ($DryRun) { 'DryRun' } else { "WinRM to $Hostname" })

    if ($winrmReachable -and -not $DryRun) {
        $probe = @'
$hn   = $env:COMPUTERNAME
$os   = (Get-CimInstance Win32_OperatingSystem).Version
$ed   = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
$dom  = (Get-CimInstance Win32_ComputerSystem).Domain
$cm   = Get-Service -Name CcmExec -ErrorAction SilentlyContinue
$cmSite = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\CCM\CcmExec' -Name 'SiteCode' -ErrorAction SilentlyContinue).SiteCode
$pnputil = & pnputil /enum-drivers 2>$null | Select-String -Pattern 'HPE' -SimpleMatch
$rdp  = Get-Service -Name TermService -ErrorAction SilentlyContinue
"HOSTNAME=$hn"
"OS_VERSION=$os"
"OS_EDITION=$ed"
"DOMAIN=$dom"
"CM_SERVICE=$($cm.Status)"
"CM_SITE=$cmSite"
"HPE_DRIVERS=$($pnputil.Count)"
"RDP_SERVICE=$($rdp.Status)"
'@
        try {
            $r = Invoke-PowerShellWinRM -Script $probe -Server $Hostname -Username $null -Password $null
            if ($r.Success) {
                $parsed = @{}
                foreach ($line in ($r.Output -split "`n" | Where-Object { $_.Trim() })) {
                    $kv = $line.Split('=', 2)
                    if ($kv.Count -eq 2) { $parsed[$kv[0].Trim()] = $kv[1].Trim() }
                }
                _Set 'hostname_match' ($parsed['HOSTNAME'] -and $parsed['HOSTNAME'].ToLower() -eq ($ExpectedHostname.Split('.')[0]).ToLower()) "actual=$($parsed['HOSTNAME']) expected=$ExpectedHostname"
                _Set 'os_version' ((-not $ExpectedOsVersion) -or ($parsed['OS_VERSION'] -eq $ExpectedOsVersion)) "actual=$($parsed['OS_VERSION']) expected=$ExpectedOsVersion"
                _Set 'os_edition' (-not [string]::IsNullOrEmpty($parsed['OS_EDITION'])) "edition=$($parsed['OS_EDITION'])"
                _Set 'domain_join' ($Domain -and ($parsed['DOMAIN'] -and $parsed['DOMAIN'].ToLower() -eq $Domain.ToLower())) "actual=$($parsed['DOMAIN']) expected=$Domain"
                if (-not $SkipDrivers) {
                    _Set 'hpe_drivers_present' ([int]$parsed['HPE_DRIVERS'] -gt 0) "hpe driver refs: $($parsed['HPE_DRIVERS'])"
                }
                if (-not $SkipCmClient) {
                    _Set 'cm_service_running' ($parsed['CM_SERVICE'] -eq 'Running') "CcmExec=$($parsed['CM_SERVICE'])"
                    _Set 'cm_site_assigned'   (-not [string]::IsNullOrEmpty($parsed['CM_SITE'])) "site=$($parsed['CM_SITE'])"
                }
                _Set 'rdp_running' ($parsed['RDP_SERVICE'] -eq 'Running') "TermService=$($parsed['RDP_SERVICE'])"
                _Set 'winrm_post'   $true 'PowerShell remoting operational'
            } else {
                _Set 'winrm_post_query' $false $r.Output
            }
        } catch { _Set 'winrm_post_query' $false $_.Exception.Message }
    } elseif ($DryRun) {
        _Set 'hostname_match'   $true 'DryRun'
        _Set 'os_version'       $true 'DryRun'
        _Set 'os_edition'       $true 'DryRun'
        _Set 'domain_join'      $(if ($Domain) { $true } else { $true }) 'DryRun'
        if (-not $SkipDrivers) { _Set 'hpe_drivers_present' $true 'DryRun' }
        if (-not $SkipCmClient) {
            _Set 'cm_service_running' $true 'DryRun'
            _Set 'cm_site_assigned'   $true 'DryRun'
        }
        _Set 'rdp_running'      $true 'DryRun'
        _Set 'winrm_post'       $true 'DryRun'
    }

    $auditFile = $null
    try {
        $auditDir = Join-Path (Get-ProjectRoot) 'generated/logs/audit'
        Ensure-DirectoryExists -Path $auditDir
        $entry = @{
            timestamp = Get-UtcTimestamp
            server    = $Hostname
            event     = 'postbuild_validation'
            success   = $overall
            checks    = $checks
        }
        $auditFile = Join-Path $auditDir "postbuild_$($Hostname)_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
        Save-Json -Data $entry -Path $auditFile
        _Set 'audit_recorded' $true "postbuild_$Hostname logged"
    } catch { _Set 'audit_recorded' $false $_.Exception.Message }

    return @{
        Success   = $overall
        Hostname  = $Hostname
        Timestamp = Get-UtcTimestamp
        Checks    = $checks
        AuditFile = $auditFile
    }
}

# vim: ts=4 sw=4 et
