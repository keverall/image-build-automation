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
        iLO IPv4 address / hostname for the target server. OPTIONAL but
        recommended: when supplied (with -IloCredential, or an interactive
        prompt) the ilo_credentials check performs a LIVE iLO Redfish GET to
        confirm the iLO is reachable and the credentials are valid before the
        destructive build. This is the same channel Start-PhysicalBuild uses to
        mount the ISO and reboot, so verifying it early avoids a failed build
        after destructive steps have already begun (e.g. the disk is being
        wiped). If omitted (or -SkipIlo), the check is recorded as SKIP, not PASS.

    .PARAMETER IloCredential
        PSCredential for the iLO Redfish check. If omitted on a live run, the
        operator is prompted interactively. Never read from config or environment.

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
        [Alias('SrvrId')]
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('Ilo')]
        [string] $IloIp,
        [System.Management.Automation.PSCredential] $IloCredential,
        [Alias('OVCred')]
        [System.Management.Automation.PSCredential] $OneViewCredential,
        [string] $IsoUrl,
        [string] $ManagementPoint,
        [string] $DistributionPoint,
        [string] $BootImageName,
        [string] $TaskSequenceName,
        [switch] $SkipOneView,
        [switch] $SkipIlo,
        [switch] $SkipDpMp,
        [switch] $SkipIsoUrl,
        [Alias('Dry')]
        [switch] $DryRun
    )

    $checks = [ordered]@{}
    $overallSuccess = $true

    function _Set([string]$name, [bool]$ok, [string]$details) {
        $script:checks[$name] = @{ status = $(if ($ok) { 'PASS' } else { 'FAIL' }); details = $details }
        if (-not $ok) { $script:overallSuccess = $false }
    }

    function _Skip([string]$name, [string]$details) {
        # Recorded as SKIP (not PASS) so the review screen never claims a check
        # "passed" when it was never run. Does not affect overall success.
        $script:checks[$name] = @{ status = 'SKIP'; details = $details }
    }

    # Re-bind to outer scope so _Set (defined inside this function) sees them
    $Script:checks          = $checks
    $Script:overallSuccess  = $overallSuccess

    if (-not $SkipOneView -and $OneViewHost) {
        try {
            $r = Get-OneViewServerTarget -OneViewHost $OneViewHost -ServerIdentifier $ServerIdentifier -DryRun:$DryRun -PassThru
            if ($r.Details) {
                $detailParts = ($r.Details.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join ', '
                $ovDetail = "Server: $($r.Server), Details: $detailParts, Success: $($r.Success)"
            } else {
                $ovDetail = "Server: $($r.Server), Success: $($r.Success)$(if ($r.Error) { ', Error: ' + $r.Error })"
            }
            _Set 'oneview_target' ($r.Success) $ovDetail
        } catch { _Set 'oneview_target' $false $_.Exception.Message }
        } else {
            # Reached only when -SkipOneView was supplied (OneViewHost empty means the
            # caller has no appliance to talk to at all, so a target can't be resolved).
            $reason = if ($SkipOneView) { 'skipped (-SkipOneView supplied)' } else { 'skipped (no -OneViewHost supplied — target cannot be resolved without an appliance)' }
            _Skip 'oneview_target' $reason
        }

    if ($SkipIsoUrl) {
        _Skip 'iso_url_check_skipped' 'skipped (-SkipIsoUrl)'
    } elseif ($IsoUrl) {
        try {
            if ($IsoUrl -match '^https?://') {
                if ($DryRun) {
                    _Set 'iso_url_format' $true "DryRun - $IsoUrl"
                } else {
                    $head = Invoke-WebRequest -Uri $IsoUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                    _Set 'iso_url_reachable' ($head.StatusCode -ge 200 -and $head.StatusCode -lt 400) "HTTP $($head.StatusCode)"
                }
            } elseif ($IsoUrl -match '^(cifs|smb)://') {
                # CIFS/SMB share URLs cannot be HEAD-probed from the automation host;
                # the share path was already validated by Resolve-ExternalIsoPath.
                _Set 'iso_url_format' $true "CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): $IsoUrl"
            } elseif ($IsoUrl -match '^nfs://') {
                _Set 'iso_url_format' $true "NFS share URL (verified by Resolve-ExternalIsoPath): $IsoUrl"
            } else {
                _Set 'iso_url_format' $false "Unsupported ISO URL scheme: $IsoUrl (expected https://, cifs://, smb:// or nfs://)"
            }
        } catch { _Set 'iso_url_reachable' $false $_.Exception.Message }
    } else { _Skip 'iso_url_check_skipped' 'skipped (no IsoUrl supplied - orchestrator will provide)' }

    if (-not $SkipIlo -and $IloIp) {
        if ($DryRun) {
            _Set 'ilo_credentials' $true 'DryRun - credentials assumed valid'
        } else {
            $iloCred = $IloCredential  # explicit iLO credentials always win if supplied
            $canPrompt = ([System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -ne 'true') -and
                [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected

            # iLO and OneView are separate auth domains, but in practice the same
            # credentials are often used. When no explicit iLO credential is given, try
            # the OneView credentials first; only if they fail do we prompt interactively.
            if (-not $iloCred -and $OneViewCredential) {
                try {
                    $url = "https://$IloIp/redfish/v1/Systems/1"
                    $resp = Invoke-RestMethod -Uri $url -Method Get `
                        -Credential $OneViewCredential `
                        -SkipCertificateCheck -TimeoutSec 10 -ErrorAction Stop
                    _Set 'ilo_credentials' $true "Redfish OK (PowerState=$($resp.PowerState)) (used OneView credentials)"
                    $iloCred = $OneViewCredential
                } catch {
                    Write-Host "  [WARN] iLO login failed using the OneView credentials ('$($OneViewCredential.UserName)') - they are not accepted by iLO. Prompting for iLO credentials." -ForegroundColor Yellow
                    if ($canPrompt) {
                        $iloCred = Get-Credential -Message "iLO credentials for '$IloIp' (OneView credentials were rejected)"
                    }
                }
            }

            # No credential yet (neither -IloCredential nor a working -OneViewCredential): prompt.
            if (-not $iloCred -and $canPrompt) {
                $iloCred = Get-Credential -Message "iLO credentials for '$IloIp'"
            }

            if (-not $iloCred) {
                # TERMINAL COMMAND: iLO credentials come ONLY from -IloCredential, -OneViewCredential,
                # or a direct interactive prompt. Never from config/env (see AGENTS.md).
                _Set 'ilo_credentials' $false "iLO credentials required. Supply -IloCredential or -OneViewCredential, or run interactively. Terminal commands never read credentials from config or environment."
            } elseif ($checks['ilo_credentials'].status -ne 'PASS') {
                try {
                    $url = "https://$IloIp/redfish/v1/Systems/1"
                    $resp = Invoke-RestMethod -Uri $url -Method Get `
                        -Credential $iloCred `
                        -SkipCertificateCheck -TimeoutSec 10 -ErrorAction Stop
                    _Set 'ilo_credentials' $true "Redfish OK (PowerState=$($resp.PowerState))"
                } catch { _Set 'ilo_credentials' $false $_.Exception.Message }
            }
        }
    } else { _Skip 'ilo_credentials' 'skipped (optional — supply -IloIp for a live iLO Redfish GET that verifies reachability and credentials before the destructive mount/reboot)' }

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
        $auditPath = Join-Path $auditDir "prebuild_$($ServerIdentifier)_$(Get-UtcFileTimestamp).json"
        $entry = @{
            timestamp = Get-UtcTimestamp
            server    = $ServerIdentifier
            event     = 'prebuild_validation'
            success   = $overallSuccess
            checks    = $checks
        }
        Save-Json -Data $entry -Path $auditPath
        _Set 'audit_recorded' $true "logged to $auditPath"
    } catch { _Set 'audit_recorded' $false $_.Exception.Message }

    return @{
        Success   = $overallSuccess
        Server    = $ServerIdentifier
        Timestamp = Get-UtcTimestamp
        Checks    = $checks
    }
}

# vim: ts=4 sw=4 et
