#
# Public/Start-PhysicalServerBuild.ps1 — End-to-end physical server build orchestrator
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
# All parameters are runtime — server identifier, OneView host, ConfigMgr
# endpoints, etc. — supplied by the operator at invocation.
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
        Run with mocked calls — no network calls are made; useful for CI smoke tests.

    .PARAMETER DryRun
        Validate inputs and print plan without performing any destructive action.

    .RETURNS
        [hashtable] with Success, Steps (ordered list of step results), AuditFile.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.aib.pri' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.aib.pri' -DistributionPoint 'dp01.ad.aib.pri' `
            -SiteServer 'cm01.ad.aib.pri' -BootImageName 'WinPE x64 - HPE' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.aib.pri'
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
        [switch] $DryRun
    )

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

    try {
        if (-not $SkipPreBuild) {
            $r = Test-PreBuildValidation -ServerIdentifier $ServerIdentifier `
                -OneViewHost $OneViewHost -IloIp $IloIp `
                -IsoUrl $null `
                -ManagementPoint $ManagementPoint -DistributionPoint $DistributionPoint `
                -BootImageName $BootImageName -TaskSequenceName $TaskSequenceName `
                -DryRun:($DryRun -or $Mock)
            _Step 'pre_build_validation' $r
            if (-not $r.Success -and -not $DryRun -and -not $Mock) { return $overall }
        }

        $isoPath = $null
        $isoUrl  = $null
        if (-not $SkipIsoBuild) {
            $r = New-IsoBuild -SiteCode $SiteCode -ManagementPoint $ManagementPoint `
                -DistributionPoint $DistributionPoint -BootImageName $BootImageName `
                -TaskSequenceName $TaskSequenceName -SiteServer $SiteServer `
                -DryRun:($DryRun -and -not $Mock)
            _Step 'iso_build' $r
            $isoPath = $r.IsoPath
            if (-not $r.Success -and -not $Mock) { return $overall }
        }

        if (-not $SkipPublish -and $isoPath -and $RepoBaseUrl) {
            $r = Publish-BootIso -IsoPath $isoPath -RepoBaseUrl $RepoBaseUrl `
                -RepoLocalPath $RepoLocalPath -DryRun:($DryRun -and -not $Mock)
            _Step 'publish_iso' $r
            if ($r.Success) { $isoUrl = $r.PublicUrl }
        }

        $oneview = $null
        if (-not $SkipOneView -and $OneViewHost) {
            $r = Get-OneViewServerTarget -OneViewHost $OneViewHost `
                -ServerIdentifier $ServerIdentifier -DryRun:($DryRun -and -not $Mock)
            _Step 'oneview_target' $r
            $oneview = $r
            if ($r.Details -and $r.Details.ilo_ip -and -not $IloIp) {
                $IloIp = $r.Details.ilo_ip
            }
        }

        if (-not $SkipMount -and $IloIp -and $isoUrl) {
            $r = Invoke-IloRedfish -Action MountAndBoot -IloIp $IloIp -IsoUrl $isoUrl `
                -DryRun:($DryRun -and -not $Mock)
            _Step 'ilo_mount_and_boot' $r
            if (-not $r.Success -and -not $Mock) { return $overall }
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
                -DryRun:($DryRun -and -not $Mock)
            _Step 'post_build_validation' $r
        }

        return $overall
    }
    finally {
        $overall['end_time'] = Get-UtcTimestamp
        try {
            $auditDir = Join-Path (Get-ProjectRoot) 'generated/logs/audit'
            Ensure-DirectoryExists -Path $auditDir
            $overall['audit_file'] = Join-Path $auditDir "build_$($ServerIdentifier)_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
            Save-Json -Data $overall -Path $overall['audit_file']
        } catch { Write-Warning "Audit log write failed: $($_.Exception.Message)" }
    }
}

# vim: ts=4 sw=4 et
