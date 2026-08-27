#
# Public/Start-PhysicalServerBuild.ps1 - End-to-end physical server build orchestrator
#
# Orchestrates the full runbook workflow:
#   1. Pre-build validation  (Test-PreBuildValidation)
#   2. Resolve iLO via OneView  (Get-OneViewServerTarget)
#   3. Mount ISO + force one-time boot via iLO Redfish  (Invoke-IloRedfish)
#   4. Monitor installation  (Start-InstallMonitor)
#   5. Post-build validation  (Test-PostBuildValidation)
#   6. Audit log entry
#
# All parameters are runtime - server identifier, OneView host, ISO path,
# etc. - supplied by the operator at invocation.
#
# Supported ISO source mode:
#   - External ISO mode (-ExternalIsoPath): Deploys a client-supplied ISO directly
#     (UNC/SMB share, cifs://, smb://, HTTPS, NFS, or mapped network drive).
#     ISO build/publish is no longer supported; supply -ExternalIsoPath.
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
        One-call orchestrator for new HPE ProLiant server deployments. Deploys a
        client-supplied ISO directly from a network share or HTTPS URL. Each step
        can be skipped with the -Skip* switches for re-running individual phases.

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
        HTTPS base URL of the ISO repository (only used when hosting ISOs on an HTTPS repo;
        otherwise supply the ISO directly from a network share via -ExternalIsoPath).

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

        When supplied, the ISO build/publish steps are skipped entirely.
        See ../PathParameterFormats.md for the full list of accepted formats.

    .PARAMETER MonitorTimeoutSeconds
        Install monitor timeout (default 7200).

    .PARAMETER MonitorPollSeconds
        Install monitor poll interval (default 30).

    .PARAMETER SkipPreBuild
    .PARAMETER SkipOneView
    .PARAMETER SkipMount
    .PARAMETER SkipMonitor
    .PARAMETER SkipPostBuild

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

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        destructive action. If it is OMITTED the command fails early with an
        expressive, logged error and performs no action. If it does NOT match the
        target, the build is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -DryRun is supplied.
        Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'. This prevents accidentally overwriting a production
        server when the client's test server lives on the production network.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Start-PhysicalServerBuild -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with Success (bool), Steps (ordered list of step
        results), and AuditFile (string). With -Json, a JSON [string]
        representation of the same data.

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
        [switch] $SkipOneView,
        [switch] $SkipMount,
        [switch] $SkipMonitor,
        [switch] $SkipPostBuild,
        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Force,
        [switch] $InMaintenanceWindow,
        [switch] $AllowUnknownIsoUrl,
        [Alias('SkipConf')]
        [switch] $SkipConfirmation,
        [string] $GuardRail = $null,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )

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
        return (_Publish-Result -Result $grCheck -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
                return (_Publish-Result -Result @{ Success = $false; Error = $msg; Server = $ServerIdentifier } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
        try {
            $isoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
        } catch {
            return (_Publish-Result -Result @{ Success = $false; Server = $ServerIdentifier; Error = "Failed to resolve -ExternalIsoPath '$ExternalIsoPath': $($_.Exception.Message)" } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
        }
        if (-not $isoUrl) {
            return (_Publish-Result -Result @{ Success = $false; Server = $ServerIdentifier; Error = "Failed to resolve external ISO path to accessible URL" } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
        $overall['steps'][$name] = $r
        $ok = if ($r) { [bool]$r.Success } else { $false }
        Write-Output "[$(if($ok){'OK'}else{'FAIL'})] $name"
        if (-not $ok) { $overall['success'] = $false }
    }

    $overall['success'] = $true
    $isoMounted = $false

    try {
        $isoPath = $null
        $isoUrl  = $null
        if ($ExternalIsoPath) {
            # No repository: deploy the client-supplied CIFS/SMB/HTTPS ISO directly.
            $isoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
            $isoPath = $ExternalIsoPath
            _Step 'resolve_iso' @{ Success = $true; IsoUrl = $isoUrl }
        } else {
            _Step 'resolve_iso' @{ Success = $false; Error = 'No -ExternalIsoPath supplied. The build pipeline now deploys a client-supplied CIFS/SMB/HTTPS ISO directly (ISO build/publish removed).' }
            $overall['success'] = $false
            return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
            if (-not $r.Success -and -not $DryRun) { return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet) }
        }

        $oneview = $null
        if (-not $SkipOneView -and $OneViewHost) {
            $r = Get-OneViewServerTarget -OneViewHost $OneViewHost `
                -ServerIdentifier $ServerIdentifier -DryRun:$DryRun -PassThru
            _Step 'oneview_target' $r
            $oneview = $r
            if (-not $r.Success -and -not $DryRun) {
                # A failed OneView resolution is fatal - we cannot target a server we
                # could not resolve, so stop instead of carrying on to the guard rail
                # or any destructive iLO steps.
                $overall['success'] = $false
                $overall['error'] = "OneView resolution failed: $($r.Error)"
                return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
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
                return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
        }

        if (-not $SkipMount -and $IloIp -and $isoUrl) {
            # ── Confirmation Prompt ─────────────────────────────────────────────
            # When a -GuardRail was supplied it already performed the destructive
            # confirmation inside Assert-GuardRail, so we skip the generic prompt.
            if (-not $DryRun -and -not $GuardRail) {
                $confirmed = Confirm-IsoDeployment -ServerIdentifier $ServerIdentifier `
                    -IloIp $IloIp -IsoUrl $isoUrl -OneViewDetails $oneview.Details -DryRun:$DryRun
                if (-not $confirmed) {
                    $overall['success'] = $false
                    $overall['cancelled_by_user'] = $true
                    return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
                    return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
            if (-not $r.Success -and -not $DryRun) { return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet) }
        }

        if (-not $SkipMonitor) {
            $r = Start-InstallMonitor -Server $ExpectedHostname `
                -TimeoutSeconds $MonitorTimeoutSeconds `
                -PollIntervalSeconds $MonitorPollSeconds `
                -PassThru `
                -ErrorAction SilentlyContinue
            _Step 'install_monitor' $r
        }

        if (-not $SkipPostBuild) {
            $r = Test-PostBuildValidation -Hostname $ExpectedHostname -Domain $Domain `
                -DryRun:$DryRun -PassThru
            _Step 'post_build_validation' $r
        }

        return (_Publish-Result -Result $overall -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
