#
# Invoke-IsoDeploy.ps1 - Bulk ISO deployment orchestrator (consumes Invoke-IloRedfish)
#
# Equivalent of reference implementation cli/deploy_to_server.py
#
# Bulk-deploys bootable ISOs to multiple HPE ProLiant servers via iLO Redfish.
# Delegates the actual virtual-media + boot logic to Invoke-IloRedfish - this
# file owns the orchestration loop only.
#

param(
    [Parameter(Mandatory = $false)][ValidateSet('redfish')][string] $Method = 'redfish',
    [Parameter(Mandatory = $false)][string] $Server = $null,
    [Parameter(Mandatory = $false)][string] $SerialNumber = $null,
    [Parameter(Mandatory = $false)][string] $OneViewHost = $null,
    [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
    [Parameter(Mandatory = $false)][string] $IsoDir = 'output\bootable_media',
    [Parameter(Mandatory = $false)][string] $IsoUrl = $null,
    [Parameter(Mandatory = $false)][string] $ExternalIsoPath = $null,
    [Parameter(Mandatory = $false)][string] $RepoBaseUrl = $null,
    [Parameter(Mandatory = $false)][string] $RepoLocalPath = $null,
    [Parameter(Mandatory = $false)][switch] $DryRun,
    [Parameter(Mandatory = $false)][switch] $SkipConfirmation
)

function Invoke-IsoDeploy {
    <#
    .SYNOPSIS
        Deploy a bootable ISO to HPE ProLiant servers via iLO Redfish.
        Callable from the module Router.

    .DESCRIPTION
        Bulk deployment orchestrator.  Looks up each server's iLO IP from
        server_list.txt, resolves the bootable ISO under -IsoDir, and delegates
        the actual virtual-media mount + boot to Invoke-IloRedfish.

    .PARAMETER Method
        Deployment method (only 'redfish' supported).

    .PARAMETER Server
        Deploy to a single named server only. Mutually exclusive with -SerialNumber.

    .PARAMETER SerialNumber
        Deploy to a server identified by its HPE serial number. Resolved to the
        server hostname (and iLO IP) via OneView; requires -OneViewHost.

    .PARAMETER OneViewHost
        OneView appliance hostname/IP used to resolve -SerialNumber.

    .PARAMETER ServerList
        Path to server_list.txt. Only used for -DryRun mock targeting.

    .PARAMETER IsoDir
        Directory containing bootable ISO packages.

    .PARAMETER IsoUrl
        Override the ISO URL (otherwise derived from bootable_iso in deployment_metadata.json
        joined with -RepoBaseUrl).

    .PARAMETER ExternalIsoPath
        Path to a client-supplied ISO for deployment (skip package resolution).
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
        
        When supplied, -IsoUrl is ignored and package resolution is skipped.
        For non-Administrator users, obtain the SMB path from your IT admin:
          - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone'
          - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso'

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository. Combined with the bootable_iso filename
        from deployment_metadata.json to construct the full URL when -IsoUrl is not given.
        Also used when -ExternalIsoPath is a local file that needs to be copied.

    .PARAMETER RepoLocalPath
        Local filesystem path of the ISO repository. Required when -ExternalIsoPath
        is a local file that needs to be copied to make it network-accessible.

    .PARAMETER DryRun
        Simulate - no actual deployment.

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt before deployment.

    .RETURNS
        [hashtable] with Success, Server, Summary.

    .EXAMPLE
        Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'

    .EXAMPLE
        Invoke-IsoDeploy -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.example.com' -ExternalIsoPath 'H:\windows.iso' -RepoLocalPath 'C:\osdrepo' -RepoBaseUrl 'https://artifacts/isos'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)][ValidateSet('redfish')][string] $Method = 'redfish',
        [Parameter(Mandatory = $false)][string] $Server = $null,
        [Parameter(Mandatory = $false)][string] $SerialNumber = $null,
        [Parameter(Mandatory = $false)][string] $OneViewHost = $null,
        [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][string] $IsoDir = 'output\bootable_media',
        [Parameter(Mandatory = $false)][string] $IsoUrl = $null,
        [Parameter(Mandatory = $false)][string] $ExternalIsoPath = $null,
        [Parameter(Mandatory = $false)][string] $RepoBaseUrl = $null,
        [Parameter(Mandatory = $false)][string] $RepoLocalPath = $null,
        [Parameter(Mandatory = $false)][switch] $DryRun,
        [Parameter(Mandatory = $false)][switch] $SkipConfirmation
    )
    if ($SerialNumber) {
        $resolved = Resolve-OneViewTarget -SerialNumber $SerialNumber -OneViewHost $OneViewHost -DryRun:$DryRun
        if (-not $resolved.Success) { return @{ Success = $false; Error = $resolved.Error } }
        $Server = $resolved.Identifier
        if ($resolved.IloIp) { Write-Verbose "Resolved serial '$SerialNumber' -> $Server (iLO $($resolved.IloIp))" }
        else { Write-Verbose "Resolved serial '$SerialNumber' -> $Server" }
    }
    if (-not $DryRun -and -not $Server) {
        throw "Server or SerialNumber is required for non-dryrun ISO deployment"
    }

    # ── Handle External ISO Path ──────────────────────────────────────────────
    if ($ExternalIsoPath) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  External ISO Deployment Mode" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "ISO Source: $ExternalIsoPath" -ForegroundColor Yellow

        # Resolve the ISO path to an accessible URL
        $resolvedIsoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
        if (-not $resolvedIsoUrl) {
            return @{ Success = $false; Error = "Failed to resolve external ISO path to accessible URL" }
        }

        $IsoUrl = $resolvedIsoUrl
        Write-Host "ISO URL for iLO: $IsoUrl" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Cyan
    }

    try {
        $serverInfo = $null
        $deployer = [ISODeployer]::new($ServerList, $IsoDir, $IsoUrl, $RepoBaseUrl, $DryRun, $serverInfo)
        if ($Server) {
            if ($DryRun) {
                $serverInfo = ($deployer.ServerDetails | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
                if (-not $serverInfo) { return @{ Success = $false; Error = "Server not found: $Server" } }
            } else {
                $serverInfo = [ServerInfo]::new($Server, '', '', 0)
            }
            $ok = $deployer.Deploy($serverInfo, $Method, [bool]$DryRun)
            return @{ Success = $ok; Server = $Server; Method = $Method }
        }
        else {
            $summary = $deployer.DeployAll($Method, [bool]$DryRun)
            return @{ Success = ($summary['successful'] -eq $summary['total']); Summary = $summary }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

class ISODeployer {
    [string]           $ServerListPath
    [string]           $IsoDir
    [string]           $DefaultIsoUrl
    [string]           $RepoBaseUrl
    [ServerInfo[]]     $ServerDetails
    [System.Collections.ArrayList] $DeployLog

    ISODeployer([string]$ServerList, [string]$IsoDir, [string]$DefaultIsoUrl, [string]$RepoBaseUrl, [bool]$DryRun = $false, [ServerInfo]$ServerInfo = $null) {
        $this.ServerListPath = $ServerList
        $this.IsoDir         = $IsoDir
        $this.DefaultIsoUrl  = $DefaultIsoUrl
        $this.RepoBaseUrl    = $RepoBaseUrl
        $this.DeployLog      = [System.Collections.ArrayList]::new()
        if ($DryRun) {
            $this.ServerDetails = Load-ServerList -Path $ServerList -IncludeDetails
        } elseif ($ServerInfo) {
            $this.ServerDetails = @($ServerInfo)
        } else {
            $this.ServerDetails = @()
        }
    }

    [string] _FindServerPackage([string]$ServerName) {
        $variants = @($ServerName, $ServerName.ToLower(),
                      $ServerName.Replace('.', '_'),
                      ($ServerName.Split('.')[0]))
        foreach ($v in $variants) {
            $d = Join-Path $this.IsoDir $v
            if (Test-Path $d -PathType Container) { return $d }
        }
        Get-ChildItem $this.IsoDir -Directory | ForEach-Object {
            $meta = Join-Path $_.FullName 'deployment_metadata.json'
            if (Test-Path $meta) {
                $mData = Import-JsonConfig -Path $meta -Required:$false
                if ($mData.Get_Item('server_name') -eq $ServerName) { return $_.FullName }
            }
        }
        Write-Error "No deployment package found for $ServerName"
        return $null
    }

    [string] _ResolveIsoUrl([string]$PackageDir) {
        if ($this.DefaultIsoUrl) { return $this.DefaultIsoUrl }
        $metaFile = Join-Path $PackageDir 'deployment_metadata.json'
        if (-not (Test-Path $metaFile)) {
            Write-Warning "Metadata not found: $metaFile - caller should supply -IsoUrl"
            return $null
        }
        $meta = Import-JsonConfig -Path $metaFile
        $name = $meta.Get_Item('bootable_iso') ?? $meta.Get_Item('generated_patched_iso')
        if (-not $name) {
            Write-Warning "deployment_metadata.json missing 'bootable_iso' key"
            return $null
        }
        $localIso = Join-Path $PackageDir $name
        if (Test-Path $localIso) {
            Write-Output "Resolved ISO locally: $localIso"
        }
        if ($this.RepoBaseUrl) {
            $base = $this.RepoBaseUrl.TrimEnd('/')
            return "$base/$name"
        }
        if ($name.StartsWith('http')) { return $name }
        Write-Warning "Metadata contains filename '$name' but no -RepoBaseUrl supplied; pass -RepoBaseUrl to construct the URL."
        return $null
    }

    [void] _Log([string]$Action, [string]$ServerName, [string]$Status, [string]$Details = '') {
        $null = $this.DeployLog.Add(@{
            timestamp = Get-UtcTimestamp; action = $Action; server = $ServerName
            status    = $Status; details = $Details
        })
        Write-Output "[$Status] $Action | $ServerName | $Details"
    }

    [hashtable] _DeployViaRedfish([ServerInfo]$Server, [string]$PackageDir, [bool]$DryRun, [bool]$Force = $false) {
        $hn    = $Server.Hostname
        $iloIp = $Server.ILO_IP
        $this._Log('deploy_redfish', $hn, 'START', "iLO: $(if($iloIp) { $iloIp } else { 'N/A' })")

        if (-not $iloIp) {
            $this._Log('deploy_redfish', $hn, 'SKIP', 'No iLO IP')
            return @{ Success = $false; Msg = 'No iLO IP' }
        }

        $isoUrl = $this._ResolveIsoUrl($PackageDir)
        if (-not $isoUrl) {
            $this._Log('deploy_redfish', $hn, 'FAILED', 'No ISO URL resolvable')
            return @{ Success = $false; Msg = 'No ISO URL' }
        }

        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp $iloIp `
            -IsoUrl $isoUrl -DryRun:$DryRun -Force:($Force -or $DryRun)

        $this._Log('deploy_redfish', $hn, $(if ($r.Success) {'SUCCESS'} else {'FAILED'}), $r.Details)
        return $r
    }

    [bool] Deploy([ServerInfo]$Server, [string]$Method, [bool]$DryRun, [bool]$Force = $false) {
        $hn  = $Server.Hostname
        $pkg = $this._FindServerPackage($hn)
        if (-not $pkg) {
            $this._Log('deploy', $hn, 'FAILED', 'Package not found')
            return $false
        }
        $result = switch ($Method.ToLowerInvariant()) {
            'redfish' { $this._DeployViaRedfish($Server, $pkg, $DryRun, $Force) }
            default   { Write-Error "Unknown method $Method"; $null }
        }
        $ok = if ($result) { $result.Success } else { $false }
        $statusKey = if ($ok) { 'SUCCESS' } else { 'FAILED' }
        $this._Log('deploy', $hn, $statusKey, "Method: $Method; Success=$ok")
        return $ok
    }

    [hashtable] DeployAll([string]$Method, [bool]$DryRun, [bool]$Force = $false) {
        Write-Output "`nDeploying to $($this.ServerDetails.Count) servers via $Method"
        Write-Output $('=' * 60)
        $results = @()
        foreach ($s in $this.ServerDetails) {
            Write-Output "`nDeploying to: $($s.Hostname)"
            $ok = $this.Deploy($s, $Method, $DryRun, $Force)
            $results += @{ server = $s.Hostname; success = $ok; method = $Method }
            Write-Output "$(if($ok){'✓'}else{'✗'}) $($s.Hostname)"
        }
        $okCount = ($results | Where-Object { $_.success }).Count
        $summary = @{
            timestamp  = Get-UtcTimestamp; method = $Method
            total      = $results.Count; successful = $okCount; failed = ($results.Count - $okCount)
            results    = $results
        }
        $logDirLog = Join-Path $PSScriptRoot '..\..\..\..\generated\logs\deployment'
        Ensure-DirectoryExists -Path $logDirLog
        $logFile = Join-Path $logDirLog "deploy_log_$(Get-UtcFileTimestamp).json"
        Save-Json -Data @{ summary = $summary; log = $this.DeployLog } -Path $logFile
        Write-Output "`nDeployment Summary: $okCount/$($results.Count) successful"
        Write-Output "Log saved: $logFile"
        return $summary
    }
}

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

# ---- Main (script mode only) ----
if ($MyInvocation.InvocationName -ne '.' -and $null -ne $MyInvocation.PSScriptRoot) {
    try {
        if ($SerialNumber) {
            $resolved = Resolve-OneViewTarget -SerialNumber $SerialNumber -OneViewHost $OneViewHost -DryRun:$DryRun
            if (-not $resolved.Success) { Write-Error $resolved.Error; exit 1 }
            $Server = $resolved.Identifier
            Write-Output "Resolved serial '$SerialNumber' -> $Server"
        }

        # Handle External ISO Path in script mode
        if ($ExternalIsoPath) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "  External ISO Deployment Mode" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "ISO Source: $ExternalIsoPath" -ForegroundColor Yellow

            $resolvedIsoUrl = Resolve-ExternalIsoPath -IsoPath $ExternalIsoPath -RepoLocalPath $RepoLocalPath -RepoBaseUrl $RepoBaseUrl
            if (-not $resolvedIsoUrl) {
                Write-Error "Failed to resolve external ISO path to accessible URL"
                exit 1
            }

            $IsoUrl = $resolvedIsoUrl
            Write-Host "ISO URL for iLO: $IsoUrl" -ForegroundColor Green
            Write-Host "========================================`n" -ForegroundColor Cyan
        }

        $serverInfo = $null
        if ($Server -and $DryRun) {
            $tempDeployer = [ISODeployer]::new($ServerList, $IsoDir, $IsoUrl, $null, $true)
            $serverInfo = ($tempDeployer.ServerDetails | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $serverInfo) { Write-Error "Server not found: $Server"; exit 1 }
        } elseif ($Server) {
            $serverInfo = [ServerInfo]::new($Server, '', '', 0)
        }
        $deployer = [ISODeployer]::new($ServerList, $IsoDir, $IsoUrl, $null, [bool]$DryRun, $serverInfo)
        if ($Server) {
            $ok = $deployer.Deploy($serverInfo, $Method, [bool]$DryRun)
            exit (if ($ok) { 0 } else { 1 })
        }
        else {
            $summary = $deployer.DeployAll($Method, [bool]$DryRun)
            exit (if ($summary['successful'] -eq $summary['total']) { 0 } else { 1 })
        }
    }
    catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        exit 1
    }
}

# vim: ts=4 sw=4 et
