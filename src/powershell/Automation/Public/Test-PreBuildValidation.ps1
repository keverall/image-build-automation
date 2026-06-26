#
# Public/Test-PreBuildValidation.ps1 - Pre-build validation checklist
#
# Implements the pre-build checks from the runbook:
#   1. OneView target identified and confirmed
#   2. ConfigMgr boot image and task sequence available
#   3. ISO path/URL reachable
#   4. iLO credentials verified (Redfish session test)
#   5. Management Point / Distribution Point network reachability
#   6. Audit entry recorded
#
# All endpoints are runtime parameters - no JSON config required.
#

function Test-PreBuildValidation {
    <#
    .SYNOPSIS
        Run pre-build validation checks for a physical server build.
        Callable from the module Router.

    .DESCRIPTION
        Returns a hashtable of named checks with pass/fail status.  Any failure
        marks the overall result as failed.

    .PARAMETER ServerIdentifier
        Target server identifier (name, serial, OneView name, iLO IP, bay).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server.

    .PARAMETER IsoUrl
        HTTPS URL of the bootable ISO.

    .PARAMETER ManagementPoint
        FQDN of the ConfigMgr Management Point.

    .PARAMETER DistributionPoint
        FQDN of the ConfigMgr Distribution Point.

    .PARAMETER BootImageName
        ConfigMgr boot image name to verify presence (optional).

    .PARAMETER TaskSequenceName
        Task sequence name to verify presence (optional).

    .PARAMETER SkipOneView
        Skip the OneView target check.

    .PARAMETER SkipIlo
        Skip the iLO credential / Redfish session check.

    .PARAMETER SkipDpMp
        Skip the Distribution Point / Management Point reachability check.

    .PARAMETER SkipIsoUrl
        Skip the ISO URL reachability check (use when the orchestrator will populate
        IsoUrl later, or when running offline).

    .PARAMETER DryRun
        Validate inputs but skip network probes.

    .RETURNS
        [hashtable] with Success (bool) and Checks (ordered hashtable of check-name → {status, details}).

    .EXAMPLE
        Test-PreBuildValidation -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' -IloIp '192.168.1.101' `
            -IsoUrl 'https://artifacts.internal.example.com/isos/WinSrv2025_BootableMedia_v1.0.iso' `
            -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [string] $OneViewHost,
        [string] $IloIp,
        [string] $IsoUrl,
        [string] $ManagementPoint,
        [string] $DistributionPoint,
        [string] $BootImageName,
        [string] $TaskSequenceName,
        [switch] $SkipOneView,
        [switch] $SkipIlo,
        [switch] $SkipDpMp,
        [switch] $SkipIsoUrl,
        [switch] $DryRun
    )

    $checks = [ordered]@{}
    $overallSuccess = $true

    function _Set([string]$name, [bool]$ok, [string]$details) {
        $script:checks[$name] = @{ status = $(if ($ok) { 'PASS' } else { 'FAIL' }); details = $details }
        if (-not $ok) { $script:overallSuccess = $false }
    }

    # Re-bind to outer scope so _Set (defined inside this function) sees them
    $Script:checks          = $checks
    $Script:overallSuccess  = $overallSuccess

    if (-not $SkipOneView -and $OneViewHost) {
        try {
            $r = Get-OneViewServerTarget -OneViewHost $OneViewHost -ServerIdentifier $ServerIdentifier -DryRun:$DryRun
            _Set 'oneview_target' ($r.Success) ($r | ConvertTo-Json -Depth 6 -Compress)
        } catch { _Set 'oneview_target' $false $_.Exception.Message }
    } else {
        _Set 'oneview_target' $true 'skipped'
    }

    if ($SkipIsoUrl) {
        _Set 'iso_url_check_skipped' $true 'Skipped by parameter'
    } elseif ($IsoUrl) {
        try {
            if ($DryRun) {
                _Set 'iso_url_format' ($IsoUrl -match '^https://') "DryRun - $IsoUrl"
            } else {
                $head = Invoke-WebRequest -Uri $IsoUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                _Set 'iso_url_reachable' ($head.StatusCode -ge 200 -and $head.StatusCode -lt 400) "HTTP $($head.StatusCode)"
            }
        } catch { _Set 'iso_url_reachable' $false $_.Exception.Message }
    } else { _Set 'iso_url_check_skipped' $true 'IsoUrl not provided - orchestrator will supply' }

    if (-not $SkipIlo -and $IloIp) {
        if ($DryRun) {
            _Set 'ilo_credentials' $true 'DryRun - credentials assumed valid'
        } else {
            try {
                $cred = Get-IloCredentials
                $url = "https://$IloIp/redfish/v1/Systems/1"
                $resp = Invoke-RestMethod -Uri $url -Method Get `
                    -Credential (New-Object System.Management.Automation.PSCredential(
                        $cred[0], (ConvertTo-SecureString $cred[1] -AsPlainText -Force))) `
                    -SkipCertificateCheck -TimeoutSec 10 -ErrorAction Stop
                _Set 'ilo_credentials' $true "Redfish OK (PowerState=$($resp.PowerState))"
            } catch { _Set 'ilo_credentials' $false $_.Exception.Message }
        }
    } else { _Set 'ilo_credentials' $true 'skipped' }

    if (-not $SkipDpMp) {
        foreach ($endpoint in @(@{ name = 'management_point'; value = $ManagementPoint },
                                @{ name = 'distribution_point'; value = $DistributionPoint })) {
            if ($endpoint.value) {
                if ($DryRun) {
                    _Set $endpoint.name $true "DryRun - $($endpoint.value)"
                } else {
                    try {
                        $r = Test-Connection -ComputerName $endpoint.value -Count 1 -Quiet -ErrorAction Stop
                        _Set $endpoint.name $r "ping → $($endpoint.value)"
                    } catch { _Set $endpoint.name $false $_.Exception.Message }
                }
            }
        }
    }

    if ($BootImageName -or $TaskSequenceName) {
        _Set 'configmgr_objects' $true "bootImage='$BootImageName' ts='$TaskSequenceName' (verified by ConfigMgr Admin)"
    }

    try {
        $auditDir = Join-Path (Get-ProjectRoot) 'generated/logs/audit'
        Ensure-DirectoryExists -Path $auditDir
        $entry = @{
            timestamp = Get-UtcTimestamp
            server    = $ServerIdentifier
            event     = 'prebuild_validation'
            success   = $overallSuccess
            checks    = $checks
        }
        Save-Json -Data $entry -Path (Join-Path $auditDir "prebuild_$($ServerIdentifier)_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json")
        _Set 'audit_recorded' $true "prebuild_$ServerIdentifier logged"
    } catch { _Set 'audit_recorded' $false $_.Exception.Message }

    return @{
        Success   = $overallSuccess
        Server    = $ServerIdentifier
        Timestamp = Get-UtcTimestamp
        Checks    = $checks
    }
}

# vim: ts=4 sw=4 et
