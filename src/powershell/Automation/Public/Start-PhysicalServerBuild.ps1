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
# Supports two ISO source modes:
#   - Build mode (default): Builds a ConfigMgr bootable ISO, publishes it, deploys
#   - External ISO mode (-ExternalIsoPath): Deploys a client-supplied ISO directly
#     (local path, UNC/SMB share, or HTTP/HTTPS URL)
#


function Confirm-IsoDeployment {
    <#
    .SYNOPSIS
        Display deployment plan and require operator confirmation before proceeding.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string] $ServerIdentifier,
        [string] $IloIp,
        [string] $IsoUrl,
        [hashtable] $OneViewDetails,
        [switch] $DryRun
    )

    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  DEPLOYMENT CONFIRMATION REQUIRED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow

    Write-Host "`nTarget Server Details:" -ForegroundColor Cyan
    if ($OneViewDetails) {
        Write-Host "  Name:        $($OneViewDetails.name)" -ForegroundColor White
        Write-Host "  Serial:      $($OneViewDetails.serial_number)" -ForegroundColor White
        Write-Host "  Model:       $($OneViewDetails.model)" -ForegroundColor White
        Write-Host "  Power State: $($OneViewDetails.power_state)" -ForegroundColor White
        Write-Host "  Health:      $($OneViewDetails.health_status)" -ForegroundColor White
        Write-Host "  iLO IP:      $IloIp" -ForegroundColor White
        if ($OneViewDetails.enclosure_name) {
            Write-Host "  Enclosure:   $($OneViewDetails.enclosure_name) Bay $($OneViewDetails.enclosure_bay)" -ForegroundColor White
        }
    } else {
        Write-Host "  Identifier: $ServerIdentifier" -ForegroundColor White
        Write-Host "  iLO IP:     $IloIp" -ForegroundColor White
    }

    Write-Host "`nDeployment Details:" -ForegroundColor Cyan
    Write-Host "  ISO:    $IsoUrl" -ForegroundColor White
    Write-Host "  Action: Mount ISO via virtual media, set one-time boot to CD, force restart" -ForegroundColor White

    Write-Host "`nWARNING: This will reboot the server!" -ForegroundColor Red
    Write-Host "The server will boot from the ISO and begin OS installation.`n" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "[DRY RUN] Skipping confirmation prompt." -ForegroundColor DarkYellow
        return $true
    }

    $confirmation = Read-Host "Type 'YES' to proceed with deployment"
    if ($confirmation -ne 'YES') {
        Write-Host "Deployment cancelled by user." -ForegroundColor Red
        return $false
    }

    return $true
}

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

    .PARAMETER ExternalIsoPath
        Path to a client-supplied ISO for deployment (skip build/publish).
        Resolved by the single shared Resolve-ExternalIsoPath helper. Accepts:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - UNC/SMB path (backslash): Converted to CIFS URL (e.g. '\\server\share\win.iso')
          - UNC/SMB path (forward slash): Same as above (e.g. '//server/share/win.iso')
          - CIFS/SMB URL: Used directly, round-trips the emitted URL (e.g. 'cifs://server/share/win.iso')
          - SMB URL alias: Normalised to cifs:// (e.g. 'smb://server/share/win.iso')
          - Mapped drive: Auto-resolved to its UNC share if mapped to a network drive (e.g. 'H:\win.iso')
          - Local path: NOT supported — iLO cannot access local drives. Supply
            an SMB/UNC, CIFS/SMB URL, or HTTPS path instead. This module never creates SMB
            shares or requires Administrator privileges (regulated banking env).

        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives on the automation host. This
          module does NOT auto-create SMB shares and does NOT require
          Administrator privileges. Supply an already-shared path instead.

        When supplied, -SkipIsoBuild and -SkipPublish are implied.

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
    .PARAMETER SkipFirmware
        Skip the post-OS firmware update step. By default, if -FirmwareFolders
        are supplied (or -FirmwareConfig is provided), Update-Firmware is invoked
        after post-build validation.

    .PARAMETER FirmwareFolders
        Additional firmware component source directories (string array) passed
        to Update-Firmware for post-OS firmware updates via HPE SUT.
        Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER FirmwareConfig
        Path to a firmware manifest JSON passed to Update-Firmware.
        Example: -FirmwareConfig 'configs\hpe_firmware_drivers_nov2025.json'

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

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt before deployment. By default, the
        operator must type 'YES' to confirm the deployment plan (server details, ISO,
        and actions). Use -SkipConfirmation for automated/unattended deployments.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        destructive action. If it is OMITTED the command fails early with an
        expressive, logged error and performs no action. If it does NOT match the
        target, the build is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun
        are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'. This prevents accidentally overwriting a production
        server when the client's test server lives on the production network.

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
        [Alias('SrvrId')]
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('Ilo')]
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
        [Alias('ExtIso')]
        [string] $ExternalIsoPath,
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
        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Force,
        [switch] $InMaintenanceWindow,
        [switch] $AllowUnknownIsoUrl,
        [Alias('SkipConf')]
        [switch] $SkipConfirmation,
        [string[]] $FirmwareFolders = @(),
        [string] $FirmwareConfig = $null,
        [switch] $SkipFirmware,
        [string] $GuardRail = $null
    )

    if ($Mock -and -not $DryRun) {
        Write-Verbose "-Mock supplied - forcing DryRun behaviour for all downstream steps"
        $DryRun = $true
    }

    # ── Guard rail is MANDATORY on build/deploy commands ──────────────────────
    # Fail early (graceful, logged) when omitted so we never overwrite an
    # unapproved server on a shared/production network.
    $grCheck = Assert-GuardRailRequired -GuardRail $GuardRail `
        -CommandName 'Start-PhysicalServerBuild' -ActionDescription 'physical server build'
    if ($grCheck) {
        $grCheck['server']      = $ServerIdentifier
        $grCheck['start_time']  = Get-UtcTimestamp
        $grCheck['end_time']    = Get-UtcTimestamp
        $grCheck['steps']       = @{}
        return $grCheck
    }

    # ── Parameter validation with actionable error messages ───────────────────
    # Build mode (no -ExternalIsoPath) needs ConfigMgr endpoints to build/publish
    # the bootable ISO. External ISO mode skips those steps entirely.
    if (-not $ExternalIsoPath) {
        $needsConfigMgr = -not $SkipIsoBuild -or -not $SkipPreBuild
        if ($needsConfigMgr) {
            $missing = @()
            if (-not $SiteCode)          { $missing += '-SiteCode (ConfigMgr site code, e.g. P01)' }
            if (-not $ManagementPoint)   { $missing += '-ManagementPoint (ConfigMgr MP FQDN, e.g. mp01.corp.local)' }
            if (-not $DistributionPoint) { $missing += '-DistributionPoint (ConfigMgr DP FQDN, e.g. dp01.corp.local)' }
            if (-not $SkipIsoBuild -and -not $BootImageName) {
                $missing += '-BootImageName (ConfigMgr boot image name, e.g. "WinPE x64 - HPE")'
            }
            if ($missing.Count -gt 0) {
                $msg = "BUILD MODE requires ConfigMgr parameters. Missing: $($missing -join '; '). " +
                       "Either supply these parameters, or use -ExternalIsoPath 'https://...' to " +
                       "deploy a client-supplied ISO directly (skipping ConfigMgr build/publish)."
                $logger = Get-Logger 'Start-PhysicalServerBuild'
                $logger.Error($msg)
                Write-Host "`n  [ERROR] $msg" -ForegroundColor Red
                return @{ Success = $false; Error = $msg; Server = $ServerIdentifier }
            }
        }
    }

    # ── Handle External ISO Path ──────────────────────────────────────────────
    if ($ExternalIsoPath) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  External ISO Deployment Mode" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "ISO Source: $ExternalIsoPath" -ForegroundColor Yellow
        
        # Resolve the ISO path to an accessible URL
        $isoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
        if (-not $isoUrl) {
            throw "Failed to resolve external ISO path to accessible URL"
        }
        
        Write-Host "ISO URL for iLO: $isoUrl" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        # Skip ISO build and publish when using external ISO
        $SkipIsoBuild = $true
        $SkipPublish = $true
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
        Write-Output "[$(if($ok){'OK'}else{'FAIL'})] $name"
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

        # ── Guard rail (build/deploy safety gate) ──────────────────────────────
        # When -GuardRail is supplied, the resolved target server name MUST match
        # the pattern before any destructive action. Resolved name prefers the
        # OneView-resolved server name (incl. for serial lookups); falls back to
        # the supplied identifier otherwise.
        if ($GuardRail) {
            $guardName   = if ($oneview -and $oneview.Details -and $oneview.Details.name) { $oneview.Details.name } else { $ServerIdentifier }
            $guardSerial = if ($oneview -and $oneview.Details -and $oneview.Details.serial_number) { $oneview.Details.serial_number } else { $null }
            $guardOk = Assert-GuardRail -GuardRail $GuardRail -ResolvedServerName $guardName `
                -SerialNumber $guardSerial -ApplianceName $OneViewHost `
                -ActionDescription 'physical server build' -DryRun:$DryRun -SkipConfirmation:$SkipConfirmation
            if (-not $guardOk) {
                $overall['success'] = $false
                $overall['guard_rail_blocked'] = $true
                return $overall
            }
        }

        if (-not $SkipMount -and $IloIp -and $isoUrl) {
            # ── Confirmation Prompt ─────────────────────────────────────────────
            # When a -GuardRail was supplied it already performed the destructive
            # confirmation inside Assert-GuardRail, so we skip the generic prompt.
            if (-not $SkipConfirmation -and -not $DryRun -and -not $GuardRail) {
                $confirmed = Confirm-IsoDeployment -ServerIdentifier $ServerIdentifier `
                    -IloIp $IloIp -IsoUrl $isoUrl -OneViewDetails $oneview.Details -DryRun:$DryRun
                if (-not $confirmed) {
                    $overall['success'] = $false
                    $overall['cancelled_by_user'] = $true
                    return $overall
                }
            }

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

        if (-not $SkipFirmware -and ($FirmwareFolders.Count -gt 0 -or $FirmwareConfig)) {
            $fwParams = @{
                Server   = $ExpectedHostname
                OutputDir = 'output\firmware'
                DryRun   = $DryRun
            }
            if ($FirmwareConfig)        { $fwParams.Config = $FirmwareConfig }
            if ($FirmwareFolders.Count) { $fwParams.FirmwareFolders = $FirmwareFolders }
            Write-Host "`n  Starting post-OS firmware update..." -ForegroundColor Cyan
            $r = Update-Firmware @fwParams
            _Step 'firmware_update' $r
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
            $overall['audit_file'] = Join-Path $auditDir "build_$($ServerIdentifier)_$(Get-UtcFileTimestamp).json"
            Save-Json -Data $overall -Path $overall['audit_file']
        } catch { Write-Warning "Audit log write failed: $($_.Exception.Message)" }
    }
}

# vim: ts=4 sw=4 et
