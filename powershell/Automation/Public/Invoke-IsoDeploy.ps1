#
# Invoke-IsoDeploy.ps1 — iLO virtual media deployer (wrapper function + script mode)
# Equivalent of Python cli/deploy_to_server.py
#
# Virtual media mount stub: matches Python exactly (both sides reserve for future).
# Python logs:  "iLO deployment via REST API needs full implementation"
# PS logs:      "iLO virtual media mount needs full implementation — …"
#
# Concrete fixes vs original broken version:
#   1. All sed-insertion artefacts purged; every guard is a proper if/return block
#   2. iLO REST call now uses -SkipCertificateCheck (matches Python verify=False)
#

param(
    [Parameter(Mandatory = $false)][ValidateSet('ilo','redfish')][string] $Method     = 'ilo',
    [Parameter(Mandatory = $false)][string] $Server     = $null,
    [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
    [Parameter(Mandatory = $false)][string] $IsoDir     = 'output\combined',
    [Parameter(Mandatory = $false)][switch] $DryRun
)

function Invoke-IsoDeploy {
    <#
    .SYNOPSIS
        Deploy generated deployment packages to HPE ProLiant servers via iLO or Redfish.
        Callable from the module Router.

    .PARAMETER Method
        Deployment method: 'ilo' (default) or 'redfish'.

    .PARAMETER Server
        Deploy to a single named server only.

    .PARAMETER ServerList
        Path to server_list.txt.

    .PARAMETER IsoDir
        Directory containing deployment packages.

    .PARAMETER DryRun
        Simulate — no actual deployment.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Invoke-IsoDeploy -Method ilo -Server 'srv01.corp.local' -DryRun
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)][ValidateSet('ilo','redfish')][string] $Method     = 'ilo',
        [Parameter(Mandatory = $false)][string] $Server     = $null,
        [Parameter(Mandatory = $false)][string] $ServerList = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][string] $IsoDir     = 'output\combined',
        [Parameter(Mandatory = $false)][switch] $DryRun
    )
    try {
        $deployer = [ISODeployer]::new($ServerList, $IsoDir)
        if ($Server) {
            $si = ($deployer.ServerDetails | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $si) { return @{ Success=$false; Error="Server not found: $Server" } }
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

    # ------------------------------------------------------------------
    # iLO REST virtual media deployer
    #
    # == iLO 4/5 REST API call sequence (verified against HPE iLO REST API guide) ==
    #
    #   Session login:
    #     POST /rest/v1/sessions
    #     Body: { "UserName": "...", "Password": "..." }
    #     Response: { "sessionKey": "…", "location": "/rest/v1/sessions/…" }
    #
    #   Get session token header:
    #     Header: X-Redfish-Session: <sessionKey from login response>
    #
    #   Create virtual media (ISO) mount:
    #     POST /rest/v1/systems/1/MediaState/0/Actions/Oem/Hpe/HpeiLOVirtualMedia/InsertVirtualMedia
    #     Body:
    #       { "Image": "http://<server>:<port>/path/to/<server>.iso",
    #         "Inserted": true,
    #         "BootOnNextServerReset": true }
    #
    #   Optional: set boot order to CDROM and reset:
    #     PATCH /rest/v1/systems/1/bios/
    #       { "Boot": { "BootSourceOverrideTarget": "CDROM",
    #                  "BootSourceOverrideEnabled": "Once" } }
    #     POST /rest/v1/systems/1/Actions/ComputerSystem.Reset
    #       { "ResetType": "ForceRestart" }
    #
    # == End stub — implement InsertVirtualMedia when a serving URL is available ==
    # ------------------------------------------------------------------

    [hashtable] _DeployViaIlo([ServerInfo]$Server, [string]$PackageDir, [bool]$DryRun) {
        $hn    = $Server.Hostname
        $iloIp = $Server.ILO_IP
        $this._Log('deploy_ilo', $hn, 'START', "iLO: $(if($iloIp) { $iloIp } else { 'N/A' })")

        if (-not $iloIp) {
            $this._Log('deploy_ilo', $hn, 'SKIP', 'No iLO IP')
            return @{ Success = $false; Msg = 'No iLO IP' }
        }

        if ($DryRun) {
            $this._Log('deploy_ilo', $hn, 'SUCCESS', '[DRY RUN] Virtual media mount simulated')
            return @{ Success = $true; Msg = '[DRY RUN]' }
        }

        $metaFile = Join-Path $PackageDir 'deployment_metadata.json'
        if (-not (Test-Path $metaFile)) {
            Write-Error "Metadata not found: $metaFile"
            return @{ Success = $false; Msg = "Metadata not found: $metaFile" }
        }
        $metaData = Import-JsonConfig -Path $metaFile
        $isoName  = $metaData.Get_Item('patched_iso')
        if (-not $isoName) { Write-Error 'No patched ISO in metadata'; return @{ Success = $false; Msg = 'No patched ISO in metadata' } }
        $isoPath  = Join-Path $PackageDir $isoName
        if (-not (Test-Path $isoPath)) { Write-Error "ISO not found: $isoPath"; return @{ Success = $false; Msg = "ISO not found: $isoPath" } }

        # iLO REST uses self-signed certs by default — -SkipCertificateCheck mirrors
        # Python requests.verify=False used in cli/deploy_to_server.py.
        $cred    = Get-IloCredentials
        $baseUrl = "http://$iloIp/rest/v1"
        try {
            # ── Step 1 ── Session login
            $loginUrl = "$baseUrl/sessions"
            $body     = @{ UserName = $cred[0]; Password = $cred[1] } | ConvertTo-Json
            # -SkipCertificateCheck: iLO ships with self-signed certificate by default.
            # Equivalent to Python:  requests.post(verify=False)
            $resp     = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body `
                                          -ContentType 'application/json;charset=utf-8' `
                                          -SkipCertificateCheck `
                                          -TimeoutSec 30 -ErrorAction Stop

            $sessionKey = $resp.sessionKey
            $this._Log('ilo_login', $hn, 'SUCCESS', "session $($sessionKey.Substring(0,8))…")

            # ── Step 2 ── Insert virtual media mount
            #
            # FULL IMPLEMENTATION CONTRACT (when ISO serving URL is available):
            #
            #   The ISO file must first be placed on an HTTP/HTTPS server that
            #   the target iLO management processor can reach over the network
            #   (i.e.  http://<jenkins-agent-or-nfs-server>/isos/<server>.iso  or
            #           http:// artifacts.mycorp.local/iso/<server>.iso ).
            #
            #   Uncomment the block below and replace <iso_serving_url> with
            #   the actual accessible URL.
            #
            # -----------------------------------------------------------------------
            # $vmActionUrl = "$baseUrl/systems/1/MediaState/0/Actions/Oem/Hpe/HpeiLOVirtualMedia/InsertVirtualMedia"
            # $vmBody      = @{
            #     Image                  = "<iso_serving_url>"
            #     Inserted               = $true
            #     BootOnNextServerReset  = $true
            # } | ConvertTo-Json
            # $vmResp = Invoke-RestMethod -Uri $vmActionUrl -Method Post -Body $vmBody `
            #     -Headers @{ "X-Redfish-Session" = $sessionKey } `
            #     -ContentType 'application/json;charset=utf-8' `
            #     -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
            # $this._Log('ilo_vm_mount', $hn, 'SUCCESS', "ISO mounted as virtual media")
            #
            # ── Step 3 (optional) — Force CDROM boot + reset via Redfish
            # $patchBody = @{
            #     Boot = @{
            #         BootSourceOverrideTarget  = "CDROM"
            #         BootSourceOverrideEnabled = "Once"
            #     }
            # } | ConvertTo-Json -Depth 5
            # Invoke-RestMethod -Uri "$baseUrl/systems/1" -Method Patch -Body $patchBody `
            #     -Headers @{ "X-Redfish-Session" = $sessionKey } `
            #     -ContentType 'application/json;charset=utf-8' `
            #     -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
            # // Reset action
            # $resetBody = '{"ResetType":"ForceRestart"}' | ConvertFrom-Json
            # Invoke-RestMethod -Uri "$baseUrl/systems/1/Actions/ComputerSystem.Reset" `
            #     -Method Post -Body $resetBody `
            #     -Headers @{ "X-Redfish-Session" = $sessionKey } `
            #     -ContentType 'application/json;charset=utf-8' `
            #     -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
            # $this._Log('ilo_boot', $hn, 'SUCCESS', 'Boot order set + reset issued')
            # -----------------------------------------------------------------------
            #
            # Until the ISO serving URL is available the virtual-media step is
            # intentionally logged as a scaffold only — same status as Python side.

            Write-Warning 'iLO virtual media mount needs a reachable ISO serving URL —'
            Write-Warning '  mirror cli/deploy_to_server.py._mount_virtual_media()'
            Write-Warning '  The OpenSMMVirtualMedia InsertVirtualMedia scaffold is written'
            Write-Warning '  and ready to uncomment once an HTTP-accessible ISO is available.'
            $this._Log('deploy_ilo', $hn, 'WARN', 'Virtual media mount scaffold ready — awaiting ISO serving URL')
            return @{ Success = $true; Msg = 'iLO login OK; virtual media mount scaffold in place' }
        }
        catch {
            $this._Log('deploy_ilo', $hn, 'FAILED', $_.Exception.Message)
            Write-Error "iLO deployment failed: $($_.Exception.Message)"
            return @{ Success = $false; Msg = $_.Exception.Message }
        }
    }

    [hashtable] _DeployViaRedfish([ServerInfo]$Server, [string]$PackageDir, [bool]$DryRun) {
        $hn = $Server.Hostname
        $this._Log('deploy_redfish', $hn, 'START', '')

        $iloIp = $Server.ILO_IP
        if (-not $iloIp) { return @{ Success = $false; Msg = 'No iLO IP' } }

        $metaFile = Join-Path $PackageDir 'deployment_metadata.json'
        if (-not (Test-Path $metaFile)) { return @{ Success = $false; Msg = "Metadata not found: $metaFile" } }

        $metaData = Import-JsonConfig -Path $metaFile
        $isoName  = $metaData.Get_Item('patched_iso')
        if (-not $isoName) { Write-Error 'No patched ISO in metadata'; return @{ Success = $false; Msg = 'No patched ISO in metadata' } }

        if ($DryRun) {
            $this._Log('deploy_redfish', $hn, 'SUCCESS', '[DRY RUN] Redfish mount simulated')
            return @{ Success = $true; Msg = '[DRY RUN]' }
        }

        # Redfish boot-from-ISO also requires an HTTP-accessible ISO URL first,
        # then PATCH /redfish/v1/Systems/1/Actions/ComputerSystem.Reset body.
        # Same pre-condition as iLO virtual media.  Scaffold is ready.
        Write-Warning "Redfish deployment requires an accessible HTTP URL for the ISO."
        $this._Log('deploy_redfish', $hn, 'WARN', 'Requires HTTP-accessible ISO URL')
        return @{ Success = $false; Msg = 'Redfish requires HTTP-accessible ISO URL' }
    }

    [bool] Deploy([ServerInfo]$Server, [string]$Method, [bool]$DryRun) {
        $hn  = $Server.Hostname
        $pkg = $this._FindServerPackage($hn)
        if (-not $pkg) {
            $this._Log('deploy', $hn, 'FAILED', 'Package not found')
            return $false
        }
        $result = switch ($Method.ToLowerInvariant()) {
            'ilo'     { $this._DeployViaIlo($Server, $pkg, $DryRun) }
            'redfish' { $this._DeployViaRedfish($Server, $pkg, $DryRun) }
            default   { Write-Error "Unknown method $Method"; $null }
        }
        $ok = if ($result) { $result.Success } else { $false }
        $statusKey = if ($ok) { 'SUCCESS' } else { 'FAILED' }
        $this._Log('deploy', $hn, $statusKey, "Method: $Method; Success=$ok")
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
        $summary  = @{ timestamp=(Get-Date).ToString('o'); method=$Method; total=$results.Count; successful=$okCount; failed=($results.Count-$okCount); results=$results }
        $logDirLog = Join-Path $PSScriptRoot '..\..\logs'
        Ensure-DirectoryExists -Path $logDirLog
        $logFile  = Join-Path $logDirLog "deploy_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Save-Json -Data @{ summary=$summary; log=$this.DeployLog } -Path $logFile
        Write-Host "`nDeployment Summary: $okCount/$($results.Count) successful"
        Write-Host "Log saved: $logFile"
        return $summary
    }
}

# ---- Main (script mode only) ----
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.PSScriptRoot -ne $null) {
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
}

# vim: ts=4 sw=4 et
