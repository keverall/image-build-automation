#
# Public/Start-PhysicalServerBuild.ps1 - End-to-end physical server build orchestrator
#
# Orchestrates the full runbook workflow:
#   1. Pre-build validation  (Test-PreBuildValidation)
#   2. Build ConfigMgr bootable ISO  (New-IsoBuild)
#   3. Publish ISO to HTTPS  (Publish-BootIso)
#   4. Resolve iLO via OneView  (Get-OneViewServerTarget)
#   5. Mount ISO + force one-time boot via iLO Redfish  (Invoke-IloRedfish)
#   6. Monitor installation  (Start-InstallMonitor)
#   7. Post-build validation  (Test-PostBuildValidation)
#   8. Audit log entry
#
# All parameters are runtime - server identifier, OneView host, ConfigMgr
# endpoints, etc. - supplied by the operator at invocation.
#

function Start-PhysicalServerBuild {
    <#
    .SYNOPSIS
        Run the full end-to-end physical server build via ConfigMgr + OneView + iLO Redfish.
        Callable from the module Router.

    .DESCRIPTION
        One-call orchestrator for new HPE ProLiant server deployments.  Each step's
        parameters are exposed individually with sensible defaults; skip switches
        allow re-running individual phases (e.g. -SkipIsoBuild to retry the deploy
        against an already-built ISO).

    .PARAMETER ServerIdentifier
        Target server identifier (name, serial, OneView name, iLO IP, bay). Required.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server.

    .PARAMETER ExpectedHostname
        Expected post-build hostname. Defaults to ServerIdentifier.

    .PARAMETER Domain
        AD domain to verify in post-build validation.

    .PARAMETER SiteCode
        ConfigMgr site code (e.g. P01).

    .PARAMETER ManagementPoint
        FQDN of the ConfigMgr Management Point.

    .PARAMETER DistributionPoint
        FQDN of the ConfigMgr Distribution Point.

    .PARAMETER SiteServer
        FQDN of the ConfigMgr site server (for PSRemoting fallback).

    .PARAMETER BootImageName
        Name of the boot image to embed (e.g. 'WinPE x64 - HPE').

    .PARAMETER TaskSequenceName
        Optional task sequence name.

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository (used by Publish-BootIso).

    .PARAMETER RepoLocalPath
        Local filesystem path mirrored to RepoBaseUrl.

    .PARAMETER MonitorTimeoutSeconds
        Install monitor timeout (default 7200).

    .PARAMETER MonitorPollSeconds
        Install monitor poll interval (default 30).

    .PARAMETER SkipPreBuild
    .PARAMETER SkipIsoBuild
    .PARAMETER SkipPublish
    .PARAMETER SkipOneView
    .PARAMETER SkipMount
    .PARAMETER SkipMonitor
    .PARAMETER SkipPostBuild

    .PARAMETER Mock
        Run with mocked calls - no network calls are made; useful for CI smoke tests.
        When -Mock is set, all downstream steps run as if -DryRun was also set.

    .PARAMETER DryRun
        Validate inputs and print plan without performing any destructive action.

    .PARAMETER Force
        Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish.
        Refuses to proceed without this switch when the server's iLO reports power state On.

    .PARAMETER InMaintenanceWindow
        Acknowledge that the target server is in an approved maintenance window. Required
        when -Force is not supplied and the server is currently On.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL during pre-build validation (use only
        when the build pipeline runs offline).

    .RETURNS
        [hashtable] with Success, Steps (ordered list of step results), AuditFile.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' `
            -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [string] $OneViewHost,
        [string] $IloIp,
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
        [int]    $MonitorTimeoutSeconds = 7200,
        [int]    $MonitorPollSeconds = 30,
        [switch] $SkipPreBuild,
        [switch] $SkipIsoBuild,
        [switch] $SkipPublish,
        [switch] $SkipOneView,
        [switch] $SkipMount,
        [switch] $SkipMonitor,
        [switch] $SkipPostBuild,
        [switch] $Mock,
        [switch] $DryRun,
        [switch] $Force,
        [switch] $InMaintenanceWindow,
        [switch] $AllowUnknownIsoUrl
    )

    if ($Mock -and -not $DryRun) {
        Write-Verbose "-Mock supplied - forcing DryRun behaviour for all downstream steps"
        $DryRun = $true
    }

    if (-not $OneViewHost -and -not $SkipOneView) {
        $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
        if (-not $isAutomated) {
            Write-Host "Enter OneView appliance hostname/IP (or press Enter to skip OneView step):" -ForegroundColor Yellow
            $OneViewHost = Read-Host
        }
    }

    if (-not $ExpectedHostname) { $ExpectedHostname = $ServerIdentifier }

    $overall = [ordered]@{}
    $overall['server'] = $ServerIdentifier
    $overall['start_time'] = Get-UtcTimestamp
    $overall['steps'] = [ordered]@{}

    function _Step([string]$name, [hashtable]$r) {
        $script:overall['steps'][$name] = $r
        $ok = if ($r) { [bool]$r.Success } else { $false }
        Write-Host "[$(if($ok){'OK'}else{'FAIL'})] $name"
        if (-not $ok) { $script:overall['success'] = $false }
    }

    $overall['success'] = $true
    $isoMounted = $false

    try {
        $isoPath = $null
        $isoUrl  = $null
        if (-not $SkipIsoBuild) {
            $r = New-IsoBuild -SiteCode $SiteCode -ManagementPoint $ManagementPoint `
                -DistributionPoint $DistributionPoint -BootImageName $BootImageName `
                -TaskSequenceName $TaskSequenceName -SiteServer $SiteServer `
                -DryRun:$DryRun
            _Step 'iso_build' $r
            $isoPath = $r.IsoPath
            if (-not $r.Success -and -not $DryRun) { return $overall }
        }

        if (-not $SkipPublish -and $isoPath -and $RepoBaseUrl) {
            $r = Publish-BootIso -IsoPath $isoPath -RepoBaseUrl $RepoBaseUrl `
                -RepoLocalPath $RepoLocalPath -DryRun:$DryRun
            _Step 'publish_iso' $r
            if ($r.Success) { $isoUrl = $r.PublicUrl }
        }

        if (-not $SkipPreBuild) {
            $r = Test-PreBuildValidation -ServerIdentifier $ServerIdentifier `
                -OneViewHost $OneViewHost -IloIp $IloIp `
                -IsoUrl $isoUrl `
                -ManagementPoint $ManagementPoint -DistributionPoint $DistributionPoint `
                -BootImageName $BootImageName -TaskSequenceName $TaskSequenceName `
                -SkipIsoUrl:([string]::IsNullOrEmpty($isoUrl) -or $AllowUnknownIsoUrl) `
                -DryRun:$DryRun
            _Step 'pre_build_validation' $r
            if (-not $r.Success -and -not $DryRun) { return $overall }
        }

        $oneview = $null
        if (-not $SkipOneView -and $OneViewHost) {
            $r = Get-OneViewServerTarget -OneViewHost $OneViewHost `
                -ServerIdentifier $ServerIdentifier -DryRun:$DryRun
            _Step 'oneview_target' $r
            $oneview = $r
            if ($r.Details -and $r.Details.ilo_ip -and -not $IloIp) {
                $IloIp = $r.Details.ilo_ip
            }
        }

        if (-not $SkipMount -and $IloIp -and $isoUrl) {
            if (-not $DryRun) {
                $status = Invoke-IloRedfish -Action Status -IloIp $IloIp -DryRun:$DryRun
                $powerState = $status.Details.system.PowerState
                if ($powerState -eq 'On' -and -not $Force -and -not $InMaintenanceWindow) {
                    _Step 'ilo_maintenance_guard' @{
                        Success = $false
                        Error   = "Server power state is On - refusing to ForceRestart without -Force or -InMaintenanceWindow"
                        PowerState = $powerState
                    }
                    $overall['success'] = $false
                    return $overall
                }
                _Step 'ilo_maintenance_guard' @{
                    Success = $true; PowerState = $powerState
                    Acknowledged = ($Force -or $InMaintenanceWindow)
                }
            }

            $r = Invoke-IloRedfish -Action MountAndBoot -IloIp $IloIp -IsoUrl $isoUrl `
                -DryRun:$DryRun -Force:($Force -or $DryRun)
            _Step 'ilo_mount_and_boot' $r
            if ($r.Success -and -not $DryRun) { $isoMounted = $true }
            if (-not $r.Success -and -not $DryRun) { return $overall }
        }

        if (-not $SkipMonitor) {
            $r = Start-InstallMonitor -Server $ExpectedHostname `
                -TimeoutSeconds $MonitorTimeoutSeconds `
                -PollIntervalSeconds $MonitorPollSeconds `
                -ErrorAction SilentlyContinue
            _Step 'install_monitor' $r
        }

        if (-not $SkipPostBuild) {
            $r = Test-PostBuildValidation -Hostname $ExpectedHostname -Domain $Domain `
                -DryRun:$DryRun
            _Step 'post_build_validation' $r
        }

        return $overall
    }
    finally {
        $overall['end_time'] = Get-UtcTimestamp
        if ($isoMounted -and $IloIp -and -not $DryRun) {
            try {
                $eject = Invoke-IloRedfish -Action Eject -IloIp $IloIp
                $overall['iso_ejected'] = $eject.Success
            } catch {
                $overall['iso_ejected'] = $false
                $overall['iso_eject_error'] = $_.Exception.Message
            }
        }
        try {
            $auditDir = Join-Path (Get-ProjectRoot) 'generated/logs/audit'
            Ensure-DirectoryExists -Path $auditDir
            $overall['audit_file'] = Join-Path $auditDir "build_$($ServerIdentifier)_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
            Save-Json -Data $overall -Path $overall['audit_file']
        } catch { Write-Warning "Audit log write failed: $($_.Exception.Message)" }
    }
}

# vim: ts=4 sw=4 et
