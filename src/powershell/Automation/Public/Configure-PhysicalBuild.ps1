#
# Public/Configure-PhysicalBuild.ps1 - Pre-deployment configuration review & 4-eye validation
#
# This command gathers all server identity and deployment information, runs
# pre-build validation, and presents a comprehensive summary for a second
# operator to review before the destructive build is authorized.
#
# It is the read-only counterpart to Start-PhysicalBuild: it performs no
# iLO mount, no ISO attach, no reboot, and no firmware update.
#
# Workflow:
#   1. Resolve target server via OneView (serial, iLO IP, model, rack location)
#   2. Resolve ISO URL (from build or external path)
#   3. Run Test-PreBuildValidation (OneView, iLO, ConfigMgr, network, ISO reachability)
#   4. Present full summary including:
#      - Server identity block (hostname, serial, iLO IP, OneView URI, model, rack)
#      - ISO details (source, URL, what it contains)
#      - Destructive actions that WILL be performed (disk wipe, reboot, firmware)
#      - Firmware folders that will be applied post-OS-install
#      - Confirmation prompt (type 'DEPLOY' to proceed to Start-PhysicalBuild)
#

function Configure-PhysicalBuild {
    <#
    .SYNOPSIS
        Review and validate a physical server build plan before deployment.
        4-eye validation gate for production imaging.

    .DESCRIPTION
        Gathers full server identity from OneView, resolves the ISO URL, runs
        pre-build validation, and prints a comprehensive summary of all
        destructive actions that will be performed. Designed for a second
        operator to review and approve before Start-PhysicalBuild is run.

        This command performs NO destructive actions — no ISO attach, no
        reboot, no firmware update. It is read-only / dry-run only.

    .PARAMETER ServerIdentifier
        Target server identifier (hostname, serial, OneView name, iLO IP, bay).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server. OPTIONAL but strongly
        recommended as a pre-flight: when supplied (with -IloCredential, or an
        interactive prompt), the pre-build validation performs a LIVE iLO Redfish
        GET that confirms the iLO is reachable and the credentials are valid
        BEFORE any destructive step. This matters because Start-PhysicalBuild
        mounts the Windows ISO and reboots the server through this exact iLO
        channel — verifying it first prevents a failed/partial build (e.g. after
        the disk is already being wiped) caused by a wrong or unreachable iLO.
        DISTINCT ROLES: -ServerIdentifier (name/serial) is the IDENTITY unique
        constraint OneView uses to select the single target; -IloIp is the
        separate CONNECTIVITY/CREDENTIAL pre-flight for the mount/reboot path.
        If omitted (or -SkipIlo), ilo_credentials is recorded as SKIP, not PASS.

    .PARAMETER IloCredential
        PSCredential for the iLO Redfish check. If omitted, prompted interactively.

    .PARAMETER ExpectedHostname
        Hostname that should result from the build (defaults to SrvrId).

    .PARAMETER Domain
        AD domain to verify in post-build validation.

    .PARAMETER SiteCode
        ConfigMgr site code (for ISO build / pre-build validation).

    .PARAMETER ManagementPoint
        ConfigMgr Management Point FQDN.

    .PARAMETER DistributionPoint
        ConfigMgr Distribution Point FQDN.

    .PARAMETER SiteServer
        ConfigMgr site server FQDN.

    .PARAMETER BootImageName
        ConfigMgr boot image name to verify.

    .PARAMETER TaskSequenceName
        ConfigMgr task sequence name to verify.

    .PARAMETER ExternalIsoPath
        Use a client-supplied ISO instead of building one. Resolved by the single
        shared Resolve-ExternalIsoPath helper. Accepts an UNC/SMB path
        (incl. '//server/share'), a 'cifs://'/'smb://' URL, an HTTPS/NFS URL, or a
        mapped network drive. Local paths are not supported. See
        ../PathParameterFormats.md for the full list of accepted formats.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL (offline scenarios).

    .PARAMETER InMaintenanceWindow
        Acknowledge the target server is in an approved maintenance window.

    .PARAMETER OneViewMaintenanceMode
        Enable HPE OneView maintenance mode before destructive operations (ISO mount,
        reboot) and disable it after the build completes. Set to $false to skip
        maintenance mode orchestration (e.g. when OneView is unavailable or the server
        is not managed by OneView). Default is $true. Use -NoMaintenanceMode to disable.

    .PARAMETER NoMaintenanceMode
        Convenience switch to disable OneView maintenance mode. Equivalent to
        -OneViewMaintenanceMode:$false. Use this when OneView is unavailable or the
        server is not managed by OneView.

    .PARAMETER SkipPreBuild
        Skip pre-build validation checks.

    .PARAMETER SkipOneView
        Skip OneView target resolution.

    .PARAMETER SkipIlo
        Skip iLO credential / Redfish check.

    .PARAMETER SkipDpMp
        Skip Management Point / Distribution Point reachability check.

    .PARAMETER SkipIsoUrl
        Skip ISO URL reachability check.

    .PARAMETER Force
        Acknowledge server power state is On (informational only — this command
        does not perform any reboot; included for parity with Invoke-PhysicalServerBuild).

    .PARAMETER DryRun
        Validate inputs and print the plan without performing any destructive action.
        Skips network probes and the confirmation prompt.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before the
        build plan is even produced. If it is OMITTED the review is aborted early
        with an expressive, logged error. If it does NOT match, the review is
        aborted. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'.

    .RETURNS
        [hashtable] with Success, ServerIdentity, IsoDetails, ValidationChecks,
        and Server. On -Deploy / -Execute or APPROVE, Invoke-PhysicalServerBuild
        is executed internally and the build result is returned.

    .EXAMPLE
        Configure-PhysicalBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' `
            -ManagementPoint 'mp01.ad.example.com' `
            -DistributionPoint 'dp01.ad.example.com' `
            -Domain 'ad.example.com'

    .EXAMPLE
        Configure-PhysicalBuild -ServerIdentifier 'srv01' -OneViewHost 'oneview.ad.example.com' -ExternalIsoPath 'https://artifacts/isos/Win2025.iso' -Deploy -GuardRail 'srv01'
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
        [string] $ExpectedHostname = $null,
        [string] $Domain,
        [string] $SiteCode,
        [string] $ManagementPoint,
        [string] $DistributionPoint,
        [string] $RepoBaseUrl,
        [string] $SiteServer,
        [string] $BootImageName,
        [string] $TaskSequenceName,
        [Alias('ExtIso')]
        [string] $ExternalIsoPath,
        [switch] $AllowUnknownIsoUrl,
        [switch] $InMaintenanceWindow,
        [switch] $OneViewMaintenanceMode = $true,
        [switch] $NoMaintenanceMode,
        [switch] $SkipPreBuild,
        [switch] $SkipOneView,
        [switch] $SkipIlo,
        [switch] $SkipDpMp,
        [switch] $SkipIsoUrl,
        [switch] $Force,
        [Alias('Dry')]
        [switch] $DryRun,
        [string] $GuardRail = $null,
        [switch] $PassThru,
        [switch] $Json,
        [Alias('Execute')]
        [switch] $Deploy
    )

    if (-not $ExpectedHostname) {
        $ExpectedHostname = $ServerIdentifier 
    }

    # ── Handle -NoMaintenanceMode convenience switch ──────────────────────────
    # -NoMaintenanceMode is equivalent to -OneViewMaintenanceMode:$false
    if ($NoMaintenanceMode) {
        $OneViewMaintenanceMode = $false
    }

    # Emit results through the shared _Publish-Result helper so the operator never
    # sees a raw hashtable/JSON dump in the terminal. By default nothing is returned
    # on the success stream (clean report only). -PassThru returns the structured
    # object for scripting/piping; -Json emits a JSON string.
    $resultView = {
        param($r)
        $label = if ($r.Success) {
            'SUCCESS' 
        } elseif ($r.Cancelled) {
            'CANCELLED' 
        } else {
            'FAILED' 
        }
        $color = if ($r.Success) {
            'Green' 
        } elseif ($r.Cancelled) {
            'Yellow' 
        } else {
            'Red' 
        }
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor $color
        Write-Host "  RESULT: $label" -ForegroundColor $color
        Write-Host "  ============================================" -ForegroundColor $color
        Write-Host "  Server : $($r.Server)" -ForegroundColor White
        if ($r.Reason) {
            Write-Host "  Reason : $($r.Reason)" -ForegroundColor Yellow 
        }
        if ($r.Error) {
            Write-Host "  Error  : $($r.Error)" -ForegroundColor Red 
        }
        if (-not $PassThru -and -not $Json) {
            Write-Host "  (structured plan available via -PassThru; JSON via -Json)" -ForegroundColor Gray
        }
    }
    function _Emit([hashtable]$result) {
        _Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -CustomView $resultView
    }

    function _InvokeBuild {
        # Reuse the parameters already supplied to Configure-PhysicalBuild so the
        # operator never re-types them. Start-PhysicalServerBuild performs the actual
        # mount/reboot/install; approval was already given here (interactive APPROVE
        # or explicit -Deploy), so we pass -SkipConfirmation to bypass the guard-rail
        # confirmation inside Start-PhysicalServerBuild.
        Start-PhysicalServerBuild -ServerIdentifier $ServerIdentifier -OneViewHost $OneViewHost `
            -IloIp $IloIp -ExpectedHostname $ExpectedHostname `
            -Domain $Domain -SiteCode $SiteCode -ManagementPoint $ManagementPoint `
            -DistributionPoint $DistributionPoint -SiteServer $SiteServer `
            -BootImageName $BootImageName -TaskSequenceName $TaskSequenceName `
            -ExternalIsoPath $ExternalIsoPath `
            -SkipPreBuild:$SkipPreBuild -SkipOneView:$SkipOneView -SkipMount:$SkipIlo -SkipMonitor -SkipPostBuild `
            -InMaintenanceWindow:$InMaintenanceWindow -AllowUnknownIsoUrl:$AllowUnknownIsoUrl `
            -OneViewMaintenanceMode:$OneViewMaintenanceMode `
            -GuardRail $GuardRail -Force:$Force -SkipConfirmation -PassThru:$PassThru
    }

    # ── Guard rail is MANDATORY on build/deploy commands ──────────────────────
    # Fail early (graceful, logged) when omitted so we never even produce a plan
    # for an unapproved server on a shared/production network.
    $grCheck = Assert-GuardRailRequired -GuardRail $GuardRail `
        -CommandName 'Configure-PhysicalBuild' -ActionDescription 'build plan review'
    if ($grCheck) {
        return (_Emit $grCheck) 
    }

    # ── Parameter validation with actionable error messages ───────────────────
    # Build mode (no -ExternalIsoPath) needs ConfigMgr endpoints to build the
    # bootable ISO. External ISO mode and fully-skipped review mode don't.
    if (-not $ExternalIsoPath -and -not $SkipPreBuild) {
        $missing = @()
        if (-not $SiteCode) {
            $missing += '-SiteCode (ConfigMgr site code, e.g. P01)' 
        }
        if (-not $ManagementPoint) {
            $missing += '-ManagementPoint (ConfigMgr MP FQDN, e.g. mp01.corp.local)' 
        }
        if (-not $DistributionPoint) {
            $missing += '-DistributionPoint (ConfigMgr DP FQDN, e.g. dp01.corp.local)' 
        }
        if (-not $BootImageName) {
            $missing += '-BootImageName (ConfigMgr boot image name, e.g. "WinPE x64 - HPE")'
        }
        if ($missing.Count -gt 0) {
            $msg = "PRE-BUILD VALIDATION requires ConfigMgr parameters. Missing: $($missing -join '; '). " +
            "Either supply these parameters, use -SkipPreBuild to skip validation, " +
            "or use -ExternalIsoPath 'https://...' to deploy a client-supplied ISO."
            $logger = Get-Logger 'Configure-PhysicalBuild'
            $logger.Error($msg)
            Write-Host "`n  [ERROR] $msg" -ForegroundColor Red
            return (_Emit @{ Success = $false; Error = $msg; Server = $ServerIdentifier })
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Physical Build Configuration Review" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # ── 1. Resolve server identity from OneView ──────────────────────────────
    $serverIdentity = $null
    if (-not $SkipOneView -and $OneViewHost) {
        Write-Host "`n[1/4] Resolving server identity from OneView..." -ForegroundColor Yellow
        # NOTE: this is a read-only GET — deliberately NOT -DryRun, so the review
        # screen shows the REAL serial/model/iLO IP/URI. Start-PhysicalBuild owns
        # the destructive work; reviewing accurate identity here is required.
        $ov = Get-OneViewServerTarget -OneViewHost $OneViewHost -ServerIdentifier $ServerIdentifier `
            -Credential $OneViewCredential -PassThru
        if ($ov.Success) {
            $serverIdentity = $ov.Details
            Write-Host "  [OK] Server resolved" -ForegroundColor Green
        } else {
            # A failed OneView resolution is fatal for a build plan: without a
            # confirmed target server (and its iLO IP) we cannot safely produce a
            # plan, so stop here instead of carrying on to the guard rail / ISO steps.
            $msg = "OneView resolution failed: $($ov.Error)"
            $logger.Error($msg)
            Write-Host "`n  [ERROR] $msg" -ForegroundColor Red
            return (_Emit @{
                    Success        = $false
                    Server         = $ServerIdentifier
                    Error          = $ov.Error
                    ServerIdentity = if ($ov.Details) {
                        $ov.Details 
                    } else {
                        $null 
                    }
                })
        }
    } elseif ($IloIp) {
        Write-Host "`n[1/4] OneView skipped — using iLO IP directly" -ForegroundColor Yellow
        $serverIdentity = @{ ilo_ip = $IloIp; name = $ExpectedHostname; identifier = $ServerIdentifier }
    } else {
        Write-Host "`n[1/4] No OneViewHost or IloIp supplied" -ForegroundColor Yellow
        $serverIdentity = @{ name = $ExpectedHostname; identifier = $ServerIdentifier }
    }

    # ── Guard rail (build/deploy safety gate, review-only) ────────────────────
    # When -GuardRail is supplied, the resolved target name MUST match before we
    # even show the deployment plan. -NonDestructive suppresses the destructive
    # confirmation prompt (this command only reviews; Invoke-PhysicalServerBuild
    # performs the actual overwrite).
    if ($GuardRail) {
        $guardName = if ($serverIdentity -and $serverIdentity.name) {
            $serverIdentity.name 
        } else {
            $ExpectedHostname 
        }
        $guardSerial = if ($serverIdentity -and $serverIdentity.serial_number) {
            $serverIdentity.serial_number 
        } else {
            $null 
        }
        $guardOk = Assert-GuardRail -GuardRail $GuardRail -ResolvedServerName $guardName `
            -SerialNumber $guardSerial -ApplianceName $OneViewHost `
            -ActionDescription 'build plan review' -SkipConfirmation:$true -NonDestructive
        if (-not $guardOk) {
            return (_Emit @{
                    Success   = $false
                    Cancelled = $true
                    Server    = $guardName
                    Reason    = "Guard rail mismatch: '$guardName' does not match guard pattern '$GuardRail'. No plan produced."
                })
        }
    }

    # ── 2. Resolve ISO URL ───────────────────────────────────────────────────
    Write-Host "`n[2/4] Resolving ISO..." -ForegroundColor Yellow
    $isoPath = $null
    $isoUrl = $null
    $isoSource = 'Not specified'

    if ($ExternalIsoPath) {
        $isoSource = "External ISO: $ExternalIsoPath"
        try {
            $isoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath
            Write-Host "  [OK] Resolved to: $isoUrl" -ForegroundColor Green
        } catch {
            $isoErr = "Failed to resolve -ExternalIsoPath '$ExternalIsoPath': $($_.Exception.Message)"
            Write-Host "  [ERROR] $isoErr" -ForegroundColor Red
            return (_Emit @{
                    Success         = $false
                    Server          = $ExpectedHostname
                    Reason          = $isoErr
                    ServerIdentity  = $serverIdentity
                    ExternalIsoPath = $ExternalIsoPath
                })
        }
    } else {
        $isoSource = "Build from ConfigMgr (SiteCode=$SiteCode)"
        Write-Host "  [INFO] ISO will be built from ConfigMgr" -ForegroundColor Yellow
    }

    # ── 3. Run pre-build validation ──────────────────────────────────────────
    Write-Host "`n[3/4] Running pre-build validation..." -ForegroundColor Yellow
    $preBuildResult = $null
    if (-not $SkipPreBuild) {
        $preBuildResult = Test-PreBuildValidation -ServerIdentifier $ServerIdentifier `
            -OneViewHost $OneViewHost -IloIp $IloIp `
            -IloCredential $IloCredential `
            -OneViewCredential $OneViewCredential `
            -IsoUrl $isoUrl `
            -ManagementPoint $ManagementPoint -DistributionPoint $DistributionPoint `
            -BootImageName $BootImageName -TaskSequenceName $TaskSequenceName `
            -SkipOneView:([bool]$SkipOneView) `
            -SkipIlo:([bool]$SkipIlo) `
            -SkipDpMp:([bool]$SkipDpMp) `
            -SkipIsoUrl:([bool]$SkipIsoUrl -or [string]::IsNullOrEmpty($isoUrl) -or [bool]$AllowUnknownIsoUrl)
        if ($preBuildResult.Success) {
            Write-Host "  [OK] All pre-build checks passed" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Some pre-build checks failed (review below)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [SKIP] Pre-build validation skipped" -ForegroundColor Gray
    }

    # ── 4. Present comprehensive summary ─────────────────────────────────────
    Write-Host "`n[4/4] Deployment Summary" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Server identity block
    Write-Host "`n  ─ SERVER IDENTITY ─" -ForegroundColor Yellow
    Write-Host "  Target:          $($ExpectedHostname)" -ForegroundColor White
    Write-Host "  Identifier:      $($ServerIdentifier)" -ForegroundColor Gray
    if ($serverIdentity) {
        $rack = if ($serverIdentity.enclosure_name -or $serverIdentity.enclosure_bay) {
            "$($serverIdentity.enclosure_name) Bay $($serverIdentity.enclosure_bay)".Trim()
        } else {
            $null 
        }
        Write-Host "  Serial:          $($serverIdentity.serial_number       ?? 'unknown')" -ForegroundColor White
        Write-Host "  Model:           $($serverIdentity.model             ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  iLO IP:          $($serverIdentity.ilo_ip            ?? $IloIp ?? 'unknown')" -ForegroundColor White
        Write-Host "  OneView URI:     $($serverIdentity.oneview_uri        ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  Rack/Position:   $($rack                             ?? 'unknown')" -ForegroundColor White
        Write-Host "  Server Group:    $($serverIdentity.server_group       ?? 'unknown')" -ForegroundColor Gray
        Write-Host "  Maintenance Mode:$($serverIdentity.maintenance_mode  ?? 'unknown')" -ForegroundColor White
        if ($serverIdentity.power_state) {
            Write-Host "  Power State:     $($serverIdentity.power_state)" -ForegroundColor White 
        }
        if ($serverIdentity.health_status) {
            Write-Host "  Health:          $($serverIdentity.health_status)" -ForegroundColor White 
        }
    }

    # ISO details
    Write-Host "`n  ─ ISO DETAILS ─" -ForegroundColor Yellow
    Write-Host "  Source:          $isoSource" -ForegroundColor White
    if ($isoUrl) {
        Write-Host "  URL:             $isoUrl" -ForegroundColor Gray
    }
    Write-Host "  Contents:        Windows Server boot media + ConfigMgr task sequence" -ForegroundColor Gray

    # Destructive actions
    Write-Host "`n  ─ DESTRUCTIVE ACTIONS (will be executed by Start-PhysicalBuild) ─" -ForegroundColor Red
    Write-Host "  1. Disk partitioning & formatting (ALL data will be erased)" -ForegroundColor Red
    Write-Host "  2. Windows OS installation from ISO" -ForegroundColor Red
    Write-Host "  3. Server reboot into installed OS" -ForegroundColor Red
    Write-Host "  4. Post-build validation (hostname, domain join, drivers)" -ForegroundColor Red

    # OneView maintenance mode notice
    if ($OneViewMaintenanceMode) {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║  🔇  ONEVIEW MAINTENANCE MODE (automatic)                            ║" -ForegroundColor Cyan
        Write-Host "  ╠══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
        Write-Host "  ║  This server will be put into HPE OneView maintenance mode           ║" -ForegroundColor White
        Write-Host "  ║  BEFORE the build starts. This stops unnecessary alerting            ║" -ForegroundColor White
        Write-Host "  ║  and avoids on-call callouts during the deployment.                  ║" -ForegroundColor White
        Write-Host "  ║                                                                      ║" - ForegroundColor White
        Write-Host "  ║  Maintenance mode will be automatically removed when the             ║" - ForegroundColor White
        Write-Host "  ║  build completes (or if it fails).                                   ║" - ForegroundColor White
        Write-Host "  ║                                                                      ║" - ForegroundColor White
        Write-Host "  ║  To skip this, use -NoMaintenanceMode.                               ║" - ForegroundColor Yellow
        Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "  ║  ⚠  ONEVIEW MAINTENANCE MODE (disabled)                              ║" -ForegroundColor Yellow
        Write-Host "  ╠══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host "  ║  OneView maintenance mode is DISABLED for this build.                ║" -ForegroundColor White
        Write-Host "  ║  Alerts and callouts may be triggered during deployment.             ║" - ForegroundColor White
        Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    }

    # Validation results
    if ($preBuildResult) {
        Write-Host "`n  ─ PRE-BUILD VALIDATION RESULTS ─" -ForegroundColor Yellow
        foreach ($key in $preBuildResult.Checks.Keys) {
            $check = $preBuildResult.Checks[$key]
            $statusColor = switch ($check.status) {
                'PASS' {
                    'Green' 
                }
                'SKIP' {
                    'Gray' 
                }
                'FAIL' {
                    'Red' 
                }
                default {
                    'Yellow' 
                }
            }
            Write-Host "  [$($check.status)] $key : $($check.details)" -ForegroundColor $statusColor
        }
    }

    # Power state warning
    if ($InMaintenanceWindow) {
        Write-Host "`n  Maintenance window: ACKNOWLEDGED" -ForegroundColor Green
    } else {
        Write-Host "`n  Maintenance window: NOT acknowledged (-InMaintenanceWindow not set)" -ForegroundColor Yellow
        Write-Host "  This build will reboot a running server if it is On." -ForegroundColor Red
    }

    Write-Host "`n══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

    # ── Hard stop: a real validation failure must never reach the APPROVE prompt ─
    if ($preBuildResult -and -not $preBuildResult.Success) {
        Write-Host "`n  ✗ PRE-BUILD VALIDATION FAILED — deployment is BLOCKED." -ForegroundColor Red
        Write-Host "    Resolve the failing check(s) above, then re-run the review." -ForegroundColor Yellow
        return (_Emit @{
                Success          = $false
                Cancelled        = $false
                Server           = $ExpectedHostname
                Reason           = "Pre-build validation failed: deployment blocked"
                ServerIdentity   = $serverIdentity
                IsoUrl           = $isoUrl
                ValidationChecks = $preBuildResult.Checks
            })
    }

    # ── Authorization (APPROVE) and optional deploy ────────────────────────────
    # APPROVE (interactive) or -Deploy (automation) runs the build via the
    # Invoke-PhysicalServerBuild code, reusing the parameters already supplied here —
    # the operator never re-types them. Without explicit approval the command only
    # reviews and returns the plan; it never deploys.
    $doDeploy = [bool]$Deploy
    if (-not $doDeploy -and -not $DryRun) {
        $isAutomated = ($env:AUTOMATED_MODE -eq 'true') -or ($env:CI -eq 'true')
        $isInteractive = ([Console]::IsInputRedirected -eq $false) -and ($Host.UI.RawUI -ne $null)
        if ($isAutomated -or -not $isInteractive) {
            Write-Host "`n  Non-interactive / automated mode detected - explicit -Deploy authorization required to proceed." -ForegroundColor Yellow
            return (_Emit @{
                    Success          = $false
                    Cancelled        = $true
                    Server           = $ExpectedHostname
                    Reason           = "Non-interactive mode: explicit -Deploy authorization required to proceed"
                    ServerIdentity   = $serverIdentity
                    IsoUrl           = $isoUrl
                    ValidationChecks = if ($preBuildResult) {
                        $preBuildResult.Checks 
                    } else {
                        $null 
                    }
                })
        }

        Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  ⚠  DESTRUCTIVE ACTION WARNING                       ║" -ForegroundColor Red
        Write-Host "  ║  You are authorizing a destructive deploy to this     ║" -ForegroundColor Red
        Write-Host "  ║  server. It will be REFORMATTED / REPARTITIONED per    ║" -ForegroundColor Red
        Write-Host "  ║  the ISO, firmware REINSTALLED, and hostname/serial    ║" -ForegroundColor Red
        Write-Host "  ║  allocated as confirmed above. Re-check, then type     ║" -ForegroundColor Red
        Write-Host "  ║  APPROVE to proceed. Anything else cancels.            ║" -ForegroundColor Red
        Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        $response = Read-Host "  Type APPROVE to authorize the ISO + firmware deploy to '$ExpectedHostname', or anything else to cancel"
        if ($response -ne 'APPROVE') {
            Write-Host "  Build CANCELLED by operator." -ForegroundColor Yellow
            return (_Emit @{
                    Success          = $false
                    Cancelled        = $true
                    Server           = $ExpectedHostname
                    Reason           = "Operator did not confirm with 'APPROVE'"
                    ServerIdentity   = $serverIdentity
                    IsoUrl           = $isoUrl
                    ValidationChecks = if ($preBuildResult) {
                        $preBuildResult.Checks 
                    } else {
                        $null 
                    }
                })
        }
        Write-Host "`n  ✓ APPROVED — deploying ISO + firmware to '$ExpectedHostname' (via Invoke-PhysicalServerBuild)." -ForegroundColor Green
        $doDeploy = $true
    }

    # Approved (or -Deploy): execute the build with the already-supplied parameters.
    if ($doDeploy) {
        return (_InvokeBuild)
    }

    # Return a structured plan that can be piped to Start-PhysicalBuild (use -PassThru).
    return (_Emit @{
            Success             = $true
            Server              = $ExpectedHostname
            ServerIdentifier    = $ServerIdentifier
            ServerIdentity      = $serverIdentity
            IsoUrl              = $isoUrl
            ExternalIsoPath     = $ExternalIsoPath
            OneViewHost         = $OneViewHost
            IloIp               = if ($serverIdentity -and $serverIdentity.ilo_ip) {
                $serverIdentity.ilo_ip 
            } else {
                $IloIp 
            }
            OneViewDetails      = $serverIdentity
            ExpectedHostname    = $ExpectedHostname
            Domain              = $Domain
            SiteCode            = $SiteCode
            ManagementPoint     = $ManagementPoint
            DistributionPoint   = $DistributionPoint
            SiteServer          = $SiteServer
            BootImageName       = $BootImageName
            TaskSequenceName    = $TaskSequenceName
            AllowUnknownIsoUrl  = [bool]$AllowUnknownIsoUrl
            InMaintenanceWindow = [bool]$InMaintenanceWindow
            ValidationChecks    = if ($preBuildResult) {
                $preBuildResult.Checks 
            } else {
                $null 
            }
            PreBuildSuccess     = if ($preBuildResult) {
                $preBuildResult.Success 
            } else {
                $null 
            }
            Timestamp           = Get-UtcTimestamp
        })
}
