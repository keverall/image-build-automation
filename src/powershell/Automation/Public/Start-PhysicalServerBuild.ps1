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

function Get-SmbPathFromDriveLetter {
    <#
    .SYNOPSIS
        Resolve a Windows drive letter to its UNC/SMB path (if it's a mapped network drive).

    .DESCRIPTION
        Helper function to find the SMB address of a mapped drive. Useful when you have
        a file on a mapped drive (e.g. H:\windows.iso) and need to find the UNC path
        for iLO virtual media.

    .PARAMETER DriveLetter
        The drive letter to resolve (e.g. 'H', 'Z').

    .EXAMPLE
        Get-SmbPathFromDriveLetter -DriveLetter 'H'
        # Returns: \\fileserver\isos

    .EXAMPLE
        # Find the full UNC path for a file on H:\
        $uncBase = Get-SmbPathFromDriveLetter -DriveLetter 'H'
        $fullUnc = Join-Path $uncBase 'windows.iso'
        # Returns: \\fileserver\isos\windows.iso
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $DriveLetter
    )

    $DriveLetter = $DriveLetter.TrimEnd(':', '\').ToUpper()

    if ($DriveLetter.Length -ne 1) {
        throw "Invalid drive letter: '$DriveLetter'. Expected a single letter (e.g. 'H')."
    }

    $psDrive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue

    if (-not $psDrive) {
        throw "Drive $DriveLetter`: does not exist."
    }

    if (-not $psDrive.DisplayRoot) {
        Write-Host "Drive $DriveLetter`: is a local drive, not a mapped network drive." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To find the SMB address, you have two options:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. If the drive is already shared on the network:" -ForegroundColor Gray
        Write-Host "   Run: Get-SmbShare | Where-Object { \$_.Path -eq '$($psDrive.Root)' }" -ForegroundColor Gray
        Write-Host "   Then use: -ExternalIsoPath '\\$env:COMPUTERNAME\ShareName\file.iso'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Create a new SMB share for this drive:" -ForegroundColor Gray
        Write-Host "   Run (as Administrator):" -ForegroundColor Gray
        Write-Host "   New-SmbShare -Name 'isos' -Path '$($psDrive.Root)' -ReadAccess 'Everyone'" -ForegroundColor Gray
        Write-Host "   Then use: -ExternalIsoPath '\\$env:COMPUTERNAME\isos\file.iso'" -ForegroundColor Gray
        return $null
    }

    if ($psDrive.DisplayRoot -match '^\\\\') {
        Write-Host "Drive $DriveLetter`: maps to: $($psDrive.DisplayRoot)" -ForegroundColor Green
        return $psDrive.DisplayRoot
    }

    throw "Drive $DriveLetter`: is not a UNC/SMB mapped drive (root: $($psDrive.DisplayRoot))."
}

function Resolve-ExternalIsoPath {
    <#
    .SYNOPSIS
        Resolve an external ISO path to a URL accessible by the iLO BMC.

    .DESCRIPTION
        The iLO virtual media controller requires network-accessible ISO sources.
        Supported formats:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - Local file path: MUST be copied to a network share first

        iLO does NOT support local filesystem paths (e.g. 'H:\windows.iso' or
        'C:\isos\win.iso'). The iLO BMC is a separate management controller on
        the physical server and cannot access local drives on your workstation.

    .PARAMETER IsoPath
        Path to the ISO file (UNC/SMB, NFS, or HTTP/HTTPS URL).

    .PARAMETER RepoLocalPath
        Local filesystem path of the ISO repository (for copying local files).

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository (for constructing the accessible URL).

    .RETURNS
        [string] URL accessible by iLO BMC.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $IsoPath,
        [string] $RepoLocalPath,
        [string] $RepoBaseUrl
    )

    # HTTP/HTTPS URL - use directly
    if ($IsoPath -match '^https?://') {
        Write-Verbose "ISO is an HTTP/HTTPS URL: $IsoPath"
        Write-Host "  [OK] HTTP/HTTPS URL - iLO will download directly" -ForegroundColor Green
        return $IsoPath
    }

    # NFS path - use directly
    if ($IsoPath -match '^nfs://') {
        Write-Verbose "ISO is an NFS path: $IsoPath"
        Write-Host "  [OK] NFS path - iLO will mount directly" -ForegroundColor Green
        return $IsoPath
    }

    # UNC/SMB path - convert to CIFS URL for iLO
    if ($IsoPath -match '^\\\\') {
        Write-Verbose "ISO is a UNC/SMB path: $IsoPath"
        # Convert \\server\share\file.iso -> cifs://server/share/file.iso
        $cifsUrl = $IsoPath -replace '\\\\', 'cifs://' -replace '\\', '/'
        Write-Host "  [OK] UNC/SMB path converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # Check if it's a mapped network drive (e.g. H:\ that maps to \\server\share)
    if ($IsoPath -match '^[A-Z]:\\' -or $IsoPath -match '^[a-z]:\\') {
        $driveLetter = $IsoPath.Substring(0, 1)
        $psDrive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue

        if ($psDrive -and $psDrive.DisplayRoot -and $psDrive.DisplayRoot -match '^\\\\') {
            # It's a mapped network drive - construct the UNC path
            $relativePath = $IsoPath.Substring(3) # Remove "H:\"
            $uncPath = Join-Path $psDrive.DisplayRoot $relativePath
            Write-Host "  [INFO] Detected mapped drive: $driveLetter`: -> $($psDrive.DisplayRoot)" -ForegroundColor Yellow
            Write-Host "  [INFO] Resolved UNC path: $uncPath" -ForegroundColor Yellow

            $cifsUrl = $uncPath -replace '\\\\', 'cifs://' -replace '\\', '/'
            Write-Host "  [OK] Mapped drive converted to CIFS URL: $cifsUrl" -ForegroundColor Green
            return $cifsUrl
        }

        # It's a local drive - requires Administrator to create SMB share
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  WARNING: Local Drive Path Detected                              ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Path: $IsoPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  The iLO BMC is a separate physical controller on the server." -ForegroundColor Yellow
        Write-Host "  It CANNOT access local drives (H:\, C:\, etc.) on this machine." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To use this ISO, you need an SMB (network share) path." -ForegroundColor Cyan
        Write-Host ""
        
        if (-not (Test-Path $IsoPath)) {
            throw "ISO file not found: $IsoPath"
        }
        
        $fileInfo = Get-Item $IsoPath
        $isoDirectory = Split-Path $IsoPath -Parent
        $isoFileName = $fileInfo.Name
        $computerName = $env:COMPUTERNAME
        
        # Check if running as Administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            # Auto-create SMB share
            $shareName = "isos_" + ($isoDirectory -replace '[^a-zA-Z0-9]', '_').Substring(0, [Math]::Min(20, ($isoDirectory -replace '[^a-zA-Z0-9]', '_').Length))
            
            Write-Host "  [OK] Running as Administrator - creating SMB share automatically..." -ForegroundColor Green
            Write-Host ""
            Write-Host "  Share name:   $shareName" -ForegroundColor Gray
            Write-Host "  Share path:   $isoDirectory" -ForegroundColor Gray
            Write-Host "  Computer:     $computerName" -ForegroundColor Gray
            
            try {
                $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
                
                if ($existingShare) {
                    Write-Host "  [OK] Share already exists" -ForegroundColor Green
                } else {
                    New-SmbShare -Name $shareName -Path $isoDirectory -ReadAccess 'Everyone' -ErrorAction Stop | Out-Null
                    Write-Host "  [OK] Share created successfully" -ForegroundColor Green
                }
                
                $uncPath = "\\$computerName\$shareName\$isoFileName"
                Write-Host "  [OK] UNC path: $uncPath" -ForegroundColor Green
                
                $cifsUrl = $uncPath -replace '\\\\', 'cifs://' -replace '\\', '/'
                Write-Host "  [OK] CIFS URL for iLO: $cifsUrl" -ForegroundColor Green
                
                return $cifsUrl
                
            } catch {
                throw "Failed to create SMB share: $($_.Exception.Message)"
            }
        } else {
            # Not running as Administrator - show instructions
            Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "  ║  Administrator Privileges Required                               ║" -ForegroundColor Yellow
            Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  You are NOT running PowerShell as Administrator." -ForegroundColor Red
            Write-Host "  Creating an SMB share requires Administrator privileges." -ForegroundColor Red
            Write-Host ""
            Write-Host "  OPTION 1: Run as Administrator (if you have access)" -ForegroundColor Cyan
            Write-Host "    1. Close this PowerShell window" -ForegroundColor Gray
            Write-Host "    2. Right-click PowerShell → Run as Administrator" -ForegroundColor Gray
            Write-Host "    3. Re-run your command with the same local path" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  OPTION 2: Ask your Administrator to create the share" -ForegroundColor Cyan
            Write-Host "    Ask your IT admin to run this command on $computerName`:" -ForegroundColor Gray
            Write-Host ""
            Write-Host "    New-SmbShare -Name 'isos' -Path '$isoDirectory' -ReadAccess 'Everyone'" -ForegroundColor White
            Write-Host ""
            Write-Host "    Then use this SMB path in your command:" -ForegroundColor Gray
            Write-Host "    -ExternalIsoPath '\\$computerName\isos\$isoFileName'" -ForegroundColor White
            Write-Host ""
            Write-Host "  OPTION 3: Use an existing SMB/HTTP path" -ForegroundColor Cyan
            Write-Host "    If the ISO is already on a network share or web server, use that path:" -ForegroundColor Gray
            Write-Host "    -ExternalIsoPath '\\fileserver\share\$isoFileName'" -ForegroundColor White
            Write-Host "    -ExternalIsoPath 'https://webserver/isos/$isoFileName'" -ForegroundColor White
            Write-Host ""
            
            throw "Local drive path '$IsoPath' requires Administrator privileges to create SMB share, or an existing SMB/HTTP path must be provided."
        }
    }

    # Unknown format
    throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTTPS URL, NFS path, UNC/SMB path (\\server\share\file.iso), or local path with -RepoLocalPath/-RepoBaseUrl."
}

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
        Accepts the following formats:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso')
          - Local path: REQUIRES ADMINISTRATOR PRIVILEGES - automatically creates SMB share
        
        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives. When a local path is supplied:
            - If running as Administrator: Creates SMB share automatically
            - If NOT running as Administrator: Command will FAIL with instructions
              to either run as Administrator or obtain an SMB path from your admin
        
        When supplied, -SkipIsoBuild and -SkipPublish are implied.
        For non-Administrator users, obtain the SMB path from your IT admin:
          - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone'
          - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso'

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

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt before deployment. By default, the
        operator must type 'YES' to confirm the deployment plan (server details, ISO,
        and actions). Use -SkipConfirmation for automated/unattended deployments.

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
        [switch] $DryRun,
        [switch] $Force,
        [switch] $InMaintenanceWindow,
        [switch] $AllowUnknownIsoUrl,
        [switch] $SkipConfirmation
    )

    if ($Mock -and -not $DryRun) {
        Write-Verbose "-Mock supplied - forcing DryRun behaviour for all downstream steps"
        $DryRun = $true
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

        if (-not $SkipMount -and $IloIp -and $isoUrl) {
            # ── Confirmation Prompt ─────────────────────────────────────────────
            if (-not $SkipConfirmation -and -not $DryRun) {
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
