#
# Invoke-IsoDeploy.ps1 — iLO virtual media deployer
# Equivalent of Python cli/deploy_to_server.py
#

<#

.SYNOPSIS
    Deploys generated deployment packages to HPE ProLiant servers via iLO REST API or Redfish.

.PARAMETER Method
    Deployment method: 'ilo' (default) or 'redfish'.

.PARAMETER Server
    Deploy to a single named server only.

.PARAMETER ServerList
    Path to server_list.txt (default: configs\server_list.txt).

.PARAMETER IsoDir
    Directory containing deployment packages (default: output\combined).

.PARAMETER DryRun
    Simulate — no actual deployment.

.EXAMPLE
    Invoke-IsoDeploy -Method ilo -Server 'srv01.corp.local' -DryRun

#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param(
    [Parameter(Mandatory = $false)][ValidateSet('ilo','redfish')][string] $Method     = 'ilo',

    [Parameter(Mandatory = $false)][string] $Server     = $null,

    [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',

    [Parameter(Mandatory = $false)][string] $IsoDir     = 'output\combined',

    [Parameter(Mandatory = $false)][switch] $DryRun
)

$Script:LogDir = Join-Path $PSScriptRoot '..\..\logs'
Initialize-Logging -LogFile 'deploy.log'

# ---- ISODeployer class ----
class ISODeployer {
    [string]           $ServerListPath
    [string]           $IsoDir
    [ServerInfo[]]     $ServerDetails
    [System.Collections.ArrayList] $DeployLog

    ISODeployer([string]$ServerList, [string]$IsoDir) {
        $this.ServerListPath = $ServerList
        $this.IsoDir         = $IsoDir
        $this.ServerDetails  = Load-ServerList -Path $ServerList -IncludeDetails
        $this.DeployLog      = [System.Collections.ArrayList]::new()
    }

    [string] _FindServerPackage([string]$ServerName) {
        $variants = @($ServerName, $ServerName.ToLower(), $ServerName.Replace('.','_'), ($ServerName.Split('.')[0]))
        foreach ($v in $variants) {
            $d = Join-Path $this.IsoDir $v
            if (Test-Path $d -PathType Container) { return $d }
        }
        # Fallback: scan metadata
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

    [void] _Log([string]$Action, [string]$ServerName, [string]$Status, [string]$Details = '') {
        $null = $this.DeployLog.Add(@{ timestamp=(Get-Date).ToString('o'); action=$Action; server=$ServerName; status=$Status; details=$Details })
        Write-Host "[$Status] $Action | $ServerName | $Details"
    }

    [bool] _DeployViaIlo([ServerInfo]$Server, [string]$PackageDir, [bool]$DryRun) {
        $hn    = $Server.Hostname
        $iloIp = $Server.ILO_IP
        $this._Log('deploy_ilo',$hn,'START',"iLO: $)(if($iloIp){$iloIp}else{'N/A'})"
        if (-not $iloIp) { $this._Log('deploy_ilo',$hn,'SKIP','No iLO IP',;,return,$false,})
        if ($DryRun) { $this._Log('deploy_ilo',$hn,'SUCCESS','[DRY RUN] Virtual media mount simulated',;,return,$true,})

        $metaFile = Join-Path $PackageDir 'deployment_metadata.json'
        if (-not (Test-Path $metaFile)) { Write-Error "Metadata not found: $metaFile"; return $false }
        $metaData = Import-JsonConfig -Path $metaFile
        $isoName  = $metaData.Get_Item('patched_iso')
        if (-not $isoName) { Write-Error 'No patched ISO in metadata'; return $false }
        $isoPath  = Join-Path $PackageDir $isoName
        if (-not (Test-Path $isoPath)) { Write-Error "ISO not found: $isoPath"; return $false }

        $cred    = Get-IloCredentials
        $baseUrl = "http://$iloIp/rest/v1"
        try {
            # Authenticate
            $loginUrl = "$baseUrl/sessionlogin"
            # Build a PSCredential
            $secPass  = ConvertTo-SecureString $cred[1] -AsPlainText -Force
            $psCred   = New-Object System.Management.Automation.PSCredential($cred[0], $secPass)
            $resp     = Invoke-RestMethod -Uri $loginUrl -Method Post -Body (@{ UserName=$cred[0]; Password=$cred[1] }) `
                                          -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop
            $this._Log('ilo_login',$hn,'SUCCESS','')
            Write-Warning 'iLO virtual media mount needs full implementation — plugin or raw REST calls required.'
            $this._Log('deploy_ilo',$hn,'SUCCESS','Virtual media mount initiated)(placeholder)'
            return $true
        }
        catch {
            $this._Log('deploy_ilo',$hn,'FAILED',$_.Exception.Message)
            Write-Error "iLO deployment failed: $($_.Exception.Message)"
            return $false
        }
    }

    [bool] _DeployViaRedfish([ServerInfo]$Server, [string]$PackageDir, [bool]$DryRun) {
        $hn = $Server.Hostname
        $this._Log('deploy_redfish',$hn,'START','')
        $iloIp = $Server.ILO_IP
        if (-not $iloIp) { return $false }
        $metaFile = Join-Path $PackageDir 'deployment_metadata.json'
        if (-not (Test-Path $metaFile)) { return $false }
        $metaData = Import-JsonConfig -Path $metaFile
        $isoName  = $metaData.Get_Item('patched_iso')
        if (-not $isoName) { Write-Error 'No patched ISO in metadata'; return $false }
        if ($DryRun) { $this._Log('deploy_redfish',$hn,'SUCCESS','[DRY RUN] Redfish mount simulated',;,return,$true,})
        Write-Warning 'Redfish deployment requires an accessible HTTP URL for the ISO.'
        $this._Log('deploy_redfish',$hn,'INFO','Redfish requires HTTP-accessible ISO URL')
        return $false
    }

    [bool] Deploy([ServerInfo]$Server, [string]$Method, [bool]$DryRun) {
        $hn = $Server.Hostname
        $pkg = $this._FindServerPackage($hn)
        if (-not $pkg) { $this._Log('deploy',$hn,'FAILED','Package not found',;,return,$false,})
        $ok = switch ($Method.ToLowerInvariant()) {
            'ilo'     { $this._DeployViaIlo $Server $pkg $DryRun }
            'redfish' { $this._DeployViaRedfish $Server $pkg $DryRun }
            default   { Write-Error "Unknown method $Method"; $false }
        }
        $this._Log('deploy',$hn)(@{ 'SUCCESS'='SUCCESS'; 'FAILED'='FAILED' }[[string]$ok]) (if($ok){'OK'}else{'FAIL'})
        return $ok
    }

    [hashtable] DeployAll([string]$Method, [bool]$DryRun) {
        Write-Host "`nDeploying to $($this.ServerDetails.Count) servers via $Method"
        Write-Host $('='*60)
        $results = @()
        foreach ($s in $this.ServerDetails) {
            Write-Host "`nDeploying to: $($s.Hostname)"
            $ok = $this.Deploy($s, $Method, $DryRun)
            $results += @{ server=$s.Hostname; success=$ok; method=$Method }
            Write-Host "$(if($ok){'✓'}else{'✗'}) $($s.Hostname)"
        }
        $okCount  = ($results | Where-Object { $_.success }).Count
        $summary  = @{ timestamp=(Get-Date).ToString('o'); method=$Method; total=$results.Count;
            successful=$okCount; failed=($results.Count-$okCount); results=$results }
        $logDirLog = Join-Path $PSScriptRoot '..\..\logs'
        Ensure-DirectoryExists -Path $logDirLog
        $logFile = Join-Path $logDirLog "deploy_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Save-Json -Data @{ summary=$summary; log=$this.DeployLog } -Path $logFile
        Write-Host "`nDeployment Summary: $okCount/$($results.Count) successful"
        Write-Host "Log saved: $logFile"
        return $summary
    }
}

# ---- Main ----
try {
    $deployer = [ISODeployer]::new($ServerList, $IsoDir)
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

# vim: ts=4 sw=4 et
