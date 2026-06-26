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
    [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
    [Parameter(Mandatory = $false)][string] $IsoDir = 'output\bootable_media',
    [Parameter(Mandatory = $false)][string] $IsoUrl = $null,
    [Parameter(Mandatory = $false)][switch] $DryRun
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
        Deploy to a single named server only.

    .PARAMETER ServerList
        Path to server_list.txt.

    .PARAMETER IsoDir
        Directory containing bootable ISO packages.

    .PARAMETER IsoUrl
        Override the ISO URL (otherwise derived from bootable_iso in deployment_metadata.json
        joined with -RepoBaseUrl).

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository. Combined with the bootable_iso filename
        from deployment_metadata.json to construct the full URL when -IsoUrl is not given.

    .PARAMETER DryRun
        Simulate - no actual deployment.

    .RETURNS
        [hashtable] with Success, Server, Summary.

    .EXAMPLE
        Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)][ValidateSet('redfish')][string] $Method = 'redfish',
        [Parameter(Mandatory = $false)][string] $Server = $null,
        [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][string] $IsoDir = 'output\bootable_media',
        [Parameter(Mandatory = $false)][string] $IsoUrl = $null,
        [Parameter(Mandatory = $false)][string] $RepoBaseUrl = $null,
        [Parameter(Mandatory = $false)][switch] $DryRun
    )
    try {
        $deployer = [ISODeployer]::new($ServerList, $IsoDir, $IsoUrl, $RepoBaseUrl)
        if ($Server) {
            $si = ($deployer.ServerDetails | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $si) { return @{ Success = $false; Error = "Server not found: $Server" } }
            $ok = $deployer.Deploy($si, $Method, [bool]$DryRun)
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

    ISODeployer([string]$ServerList, [string]$IsoDir, [string]$DefaultIsoUrl, [string]$RepoBaseUrl) {
        $this.ServerListPath = $ServerList
        $this.IsoDir         = $IsoDir
        $this.DefaultIsoUrl  = $DefaultIsoUrl
        $this.RepoBaseUrl    = $RepoBaseUrl
        $this.ServerDetails  = Load-ServerList -Path $ServerList -IncludeDetails
        $this.DeployLog      = [System.Collections.ArrayList]::new()
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
            Write-Host "Resolved ISO locally: $localIso"
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
        Write-Host "[$Status] $Action | $ServerName | $Details"
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
        Write-Host "`nDeploying to $($this.ServerDetails.Count) servers via $Method"
        Write-Host $('=' * 60)
        $results = @()
        foreach ($s in $this.ServerDetails) {
            Write-Host "`nDeploying to: $($s.Hostname)"
            $ok = $this.Deploy($s, $Method, $DryRun, $Force)
            $results += @{ server = $s.Hostname; success = $ok; method = $Method }
            Write-Host "$(if($ok){'✓'}else{'✗'}) $($s.Hostname)"
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
        Write-Host "`nDeployment Summary: $okCount/$($results.Count) successful"
        Write-Host "Log saved: $logFile"
        return $summary
    }
}

# ---- Main (script mode only) ----
if ($MyInvocation.InvocationName -ne '.' -and $null -ne $MyInvocation.PSScriptRoot) {
    try {
        $deployer = [ISODeployer]::new($ServerList, $IsoDir, $IsoUrl)
        if ($Server) {
            $si = ($deployer.ServerDetails | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $si) { Write-Error "Server not found: $Server"; exit 1 }
            $ok = $deployer.Deploy($si, $Method, [bool]$DryRun)
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
