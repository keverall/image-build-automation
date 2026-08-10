#
# Invoke-IsoDeploy.ps1 - Bulk ISO deployment orchestrator (consumes Invoke-IloRedfish)
#
# Equivalent of reference implementation cli/deploy_to_server.py
#
# Bulk-deploys bootable ISOs to multiple HPE ProLiant servers via iLO Redfish.
# Delegates the actual virtual-media + boot logic to Invoke-IloRedfish - this
# file owns the orchestration loop only.
#


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
          - Local path: NOT supported — iLO cannot access local drives. Supply
            an SMB/UNC or HTTPS path instead. This module never creates SMB
            shares or requires Administrator privileges (regulated banking env).

        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives on the automation host. This
          module does NOT auto-create SMB shares and does NOT require
          Administrator privileges. Supply an already-shared path instead.

        When supplied, -IsoUrl is ignored and package resolution is skipped.

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

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        deployment. If it is OMITTED the command fails early with an expressive,
        logged error and performs no deployment. If it does NOT match the target,
        the deployment is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun
        are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'.

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
        [Alias('Srvr')]
        [Parameter(Mandatory = $false)][string] $Server = $null,
        [Alias('Srl')]
        [Parameter(Mandatory = $false)][string] $SerialNumber = $null,
        [Alias('OVHost')]
        [Parameter(Mandatory = $false)][string] $OneViewHost = $null,
        [Alias('Ilo')]
        [Parameter(Mandatory = $false)][string] $IloIp = $null,
        [Alias('SrvrList')]
        [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][string] $IsoDir = 'output\bootable_media',
        [Alias('Iso')]
        [Parameter(Mandatory = $false)][string] $IsoUrl = $null,
        [Alias('ExtIso')]
        [Parameter(Mandatory = $false)][string] $ExternalIsoPath = $null,
        [Alias('RepoUrl')]
        [Parameter(Mandatory = $false)][string] $RepoBaseUrl = $null,
        [Alias('RepoPath')]
        [Parameter(Mandatory = $false)][string] $RepoLocalPath = $null,
        [Alias('Dry')]
        [Parameter(Mandatory = $false)][switch] $DryRun,
        [Alias('SkipConf')]
        [Parameter(Mandatory = $false)][switch] $SkipConfirmation,
        [string] $GuardRail = $null
    )

    # ── Guard rail is MANDATORY on build/deploy commands ──────────────────────
    # Fail early (graceful, logged) when omitted so we never deploy to an
    # unapproved server on a shared/production network.
    $grCheck = Assert-GuardRailRequired -GuardRail $GuardRail `
        -CommandName 'Invoke-IsoDeploy' -ActionDescription 'ISO deployment'
    if ($grCheck) { return $grCheck }

    # TERMINAL COMMAND: when the target is not supplied, prompt for it (interactive
    # runs only - suppressed under AUTOMATED_MODE, see AGENTS.md). The documented
    # behaviour for every command in automation_commands.md is to prompt for host
    # and credential inputs that were not provided.
    if (-not $Server -and -not $SerialNumber) {
        if ([System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true') {
            return @{ Success = $false; Error = "Server or SerialNumber is required (neither was supplied and AUTOMATED_MODE is set)." }
        }
        Write-Host "No target supplied. Identify the server by:" -ForegroundColor Cyan
        $choice = Read-Host "Enter '1' for server name/FQDN, '2' for serial number"
        if ($choice -eq '2') {
            $SerialNumber = Read-Host "Serial number"
        } else {
            $Server = Read-Host "Server name or FQDN"
        }
    }

    # TERMINAL COMMAND: resolve the target through OneView. A name or serial must
    # be confirmed against OneView (so destructive deploys hit the CORRECT server),
    # which requires the OneView host. Prompt for the host when it was not supplied
    # on an interactive run (suppressed under AUTOMATED_MODE).
    if (-not $OneViewHost -and [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -ne 'true') {
        $OneViewHost = Read-Host "OneView appliance host (used to confirm the target server)"
    }

    if ($SerialNumber) {
        if (-not $OneViewHost -and [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -ne 'true') {
            $OneViewHost = Read-Host "OneView appliance host (used to resolve serial '$SerialNumber')"
        }
        $resolved = Resolve-OneViewTarget -SerialNumber $SerialNumber -OneViewHost $OneViewHost -DryRun:$DryRun
        if (-not $resolved.Success) { return @{ Success = $false; Error = $resolved.Error } }
        $Server = $resolved.Identifier
        # Carry the OneView-resolved iLO IP so the live Redfish deploy can reach iLO.
        if ($resolved.IloIp) { $IloIp = $resolved.IloIp }
        if ($resolved.IloIp) { Write-Verbose "Resolved serial '$SerialNumber' -> $Server (iLO $($resolved.IloIp))" }
        else { Write-Verbose "Resolved serial '$SerialNumber' -> $Server" }
    }

    # ── Guard rail (build/deploy safety gate) ──────────────────────────────────
    # When -GuardRail is supplied, the resolved target server name MUST match the
    # pattern before any deployment. Applies to the single-server (or serial-
    # resolved) path; bulk DeployAll has no single known target up front.
    if ($GuardRail -and $Server) {
        $guardOk = Assert-GuardRail -GuardRail $GuardRail -ResolvedServerName $Server `
            -SerialNumber $SerialNumber -ApplianceName $OneViewHost `
            -ActionDescription 'ISO deployment' -DryRun:$DryRun -SkipConfirmation:$SkipConfirmation
        if (-not $guardOk) {
            return @{ Success = $false; Error = "Guard rail rejected target '$Server' (guard: '$GuardRail'). No deployment performed." }
        }
    }

    if (-not $DryRun -and -not $Server) {
        return @{ Success = $false; Error = "Server or SerialNumber is required for non-dryrun ISO deployment" }
    }

    # TERMINAL COMMAND: a live run must be driven entirely by parameters.
    # deployment_metadata.json / package-dir resolution is a -DryRun helper only
    # (see AGENTS.md). Require an explicit ISO source for live deployments.
    if (-not $DryRun -and -not $IsoUrl -and -not $ExternalIsoPath) {
        return @{ Success = $false; Error = "An explicit ISO source is required for a live deployment. Supply -IsoUrl <https-url> or -ExternalIsoPath <path>. Config/metadata resolution (deployment_metadata.json) is only used with -DryRun." }
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
                # Live run: carry the iLO IP (from -IloIp, or OneView-resolved via serial)
                # so Redfish deployment can reach the iLO.
                $serverInfo = [ServerInfo]::new($Server, '', $IloIp, 0)
            }
            $ok = $deployer.Deploy($serverInfo, $Method, [bool]$DryRun)
            return @{ Success = $ok; Server = $Server; Method = $Method }
        }
        else {
            $summary = $deployer.DeployAll($Method, [bool]$DryRun)
            $result = @{ Success = ($summary['successful'] -eq $summary['total']); Summary = $summary }
            _Format-IsoDeploySummary -Result $result
            return $result
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
        # With an explicit ISO URL (live runs), no package/metadata lookup is
        # needed - package scanning is a -DryRun convenience only.
        $pkg = $null
        if (-not $this.DefaultIsoUrl) {
            $pkg = $this._FindServerPackage($hn)
            if (-not $pkg) {
                $this._Log('deploy', $hn, 'FAILED', 'Package not found')
                return $false
            }
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

function _Format-IsoDeploySummary {
    param([hashtable]$Result)

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  ISO Deployment Summary" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Result.Summary) {
        $s = $Result.Summary
        $overallColor = if ($Result.Success) { 'Green' } else { 'Red' }
        
        Write-Host "  Method:     $($s.method)" -ForegroundColor White
        Write-Host "  Total:      $($s.total)" -ForegroundColor White
        Write-Host "  Successful: $($s.successful)" -ForegroundColor Green
        Write-Host "  Failed:     $($s.failed)" -ForegroundColor $(if ($s.failed -gt 0) { 'Red' } else { 'Gray' })
        Write-Host "  Overall:    $(if ($Result.Success) { 'PASS' } else { 'FAIL' })" -ForegroundColor $overallColor

        if ($s.results -and $s.results.Count -gt 0) {
            Write-Host ""
            Write-Host "  --- Server Results ---" -ForegroundColor Yellow
            $nameWidth = ($s.results | ForEach-Object { $_.server.Length } | Measure-Object -Maximum).Maximum
            if ($nameWidth -lt 15) { $nameWidth = 15 }
            if ($nameWidth -gt 40) { $nameWidth = 40 }

            $header = "{0,-$nameWidth}  {1,-10}  {2}" -f 'Server', 'Status', 'Method'
            Write-Host $header -ForegroundColor Yellow
            Write-Host ("-" * $header.Length) -ForegroundColor Gray

            foreach ($srv in $s.results) {
                $statusColor = if ($srv.success) { 'Green' } else { 'Red' }
                $status = if ($srv.success) { 'SUCCESS' } else { 'FAILED' }
                $method = if ($srv.method) { $srv.method } else { '-' }
                $line = "{0,-$nameWidth}  {1,-10}  {2}" -f $srv.server, $status, $method
                Write-Host $line -ForegroundColor $statusColor
            }
        }
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
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
        Write-Host "  iLO cannot access local drives. This module does not create SMB" -ForegroundColor Yellow
        Write-Host "  shares or require Administrator privileges (regulated banking" -ForegroundColor Yellow
        Write-Host "  environment)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Supply the ISO via an already-shared path:" -ForegroundColor Cyan
        Write-Host "    -ExternalIsoPath '\\fileserver\share\win2019.iso'" -ForegroundColor Gray
        Write-Host "    -ExternalIsoPath 'https://fileserver/isos/win2019.iso'" -ForegroundColor Gray
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
          - Local file path: NOT supported — iLO cannot reach local drives.
            Supply an SMB/UNC or HTTPS path instead. This module never creates
            SMB shares or requires Administrator privileges.

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

        # It's a local drive - not supported (iLO cannot access local drives,
        # and this environment does not permit Administrator privileges)
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  ERROR: Local Drive Path Not Supported                           ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Path: $IsoPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  The iLO BMC is a separate physical controller on the server." -ForegroundColor Yellow
        Write-Host "  It CANNOT access local drives (H:\, C:\, etc.) on this machine." -ForegroundColor Yellow
        Write-Host "  This module does not create SMB shares or require Administrator" -ForegroundColor Yellow
        Write-Host "  privileges (regulated banking environment)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Supply an already-shared ISO path instead:" -ForegroundColor Cyan
        Write-Host "    -ExternalIsoPath '\\fileserver\share\win2019.iso'" -ForegroundColor Gray
        Write-Host "    -ExternalIsoPath 'https://fileserver/isos/win2019.iso'" -ForegroundColor Gray
        Write-Host ""

        if (-not (Test-Path $IsoPath)) {
            throw "ISO file not found: $IsoPath"
        }

        throw "Local drive path '$IsoPath' is not supported. Supply -ExternalIsoPath as an SMB/UNC (\\server\share\file.iso) or HTTPS URL instead. This module does not auto-create shares or require Administrator privileges."
    }

    # Unknown format
    throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB path (\\server\share\file.iso)."
}
# vim: ts=4 sw=4 et
