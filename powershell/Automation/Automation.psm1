#
# Automation.psm1 — Root module for HPE ProLiant Windows Server ISO Automation
#
# All class definitions live here so they are resolved before any dot-sourced
# script in Private/ or Public/ is parsed. PowerShell resolves [TypeName]
# annotations at parse time.
#
# Private/ and Public/ contain one function per .ps1 file, dot-sourced in
# explicit order below.
#

Set-StrictMode -Off   # allow $null comparisons, unset variables in classes

# ──────────────────────────────────────────────────────────────────────────────
# Shared value type: CommandResult  (mirrors Python executor.CommandResult)
# ──────────────────────────────────────────────────────────────────────────────
class CommandResult {
    [int]    $ReturnCode
    [string] $StandardOutput
    [string] $StandardError
    [bool]   $Success

    CommandResult([int]$rc, [string]$stdout, [string]$stderr) {
        $this.ReturnCode     = $rc
        $this.StandardOutput = $stdout
        $this.StandardError  = $stderr
        $this.Success        = ($rc -eq 0)
    }

    [string] Output() { return $this.StandardOutput + $this.StandardError }
}

# ──────────────────────────────────────────────────────────────────────────────
# Shared reference type: AuditLogger  (mirrors Python AuditLogger)
# ──────────────────────────────────────────────────────────────────────────────
class AuditLogger {
    [string]  $Category
    [string]  $LogDir
    [string]  $MasterLogPath
    [System.Collections.ArrayList] $Entries

    AuditLogger([string]$Category, [string]$LogDir, [string]$MasterLogName) {
        $this.Category      = $Category
        $this.LogDir        = $LogDir
        $this.MasterLogPath = [System.IO.Path]::Combine($LogDir, $MasterLogName)
        $this.Entries       = [System.Collections.ArrayList]::new()
        if (-not (Test-Path $this.LogDir)) {
            New-Item -ItemType Directory -Path $this.LogDir -Force | Out-Null
        }
    }

    [hashtable] Log([string]$Action, [string]$Status, [string]$Server,
                    [string]$Details, [hashtable]$Extra) {
        $entry = @{
            timestamp = (Get-Date -Format o)
            category  = $this.Category
            action    = $Action
            status    = $Status
            server    = $Server
            details   = $Details
        }
        if ($Extra) { foreach ($k in $Extra.Keys) { $entry[$k] = $Extra[$k] } }
        $null = $this.Entries.Add($entry)
        Write-Host "[$Status] $Action | $Server | $Details"
        return $entry
    }

    [string] Save([string]$Filename) {
        if (-not $Filename) {
            $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $Filename = "$($this.Category)_$ts.json"
        }
        $fp = [System.IO.Path]::Combine($this.LogDir, $Filename)
        @{ category = $this.Category; generatedAt = (Get-Date -Format o); entries = $this.Entries } |
            ConvertTo-Json -Depth 64 | Set-Content -Path $fp -Encoding UTF8
        return $fp
    }

    [void] AppendToMaster() {
        foreach ($e in $this.Entries) {
            ($e | ConvertTo-Json -Depth 10 -Compress) | Add-Content -Path $this.MasterLogPath -Encoding UTF8
        }
    }

    [void] Clear() { $this.Entries.Clear() }
}

# ──────────────────────────────────────────────────────────────────────────────
# Shared value type: ServerInfo  (mirrors Python ServerInfo dataclass)
# ──────────────────────────────────────────────────────────────────────────────
class ServerInfo {
    [string] $Hostname
    [string] $IPMI_IP
    [string] $ILO_IP
    [int]    $LineNumber

    ServerInfo([string]$Hostname, [string]$IPMI_IP, [string]$ILO_IP, [int]$LineNumber) {
        $this.Hostname   = $Hostname
        $this.IPMI_IP    = $IPMI_IP
        $this.ILO_IP     = $ILO_IP
        $this.LineNumber = $LineNumber
    }

    [string] ShortName() {
        $idx = $this.Hostname.IndexOf('.')
        if ($idx -ge 0) { return $this.Hostname.Substring(0, $idx) }
        return $this.Hostname
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# OpsRamp REST API client  (moved from Public/OpsRampClient.psm1)
# ──────────────────────────────────────────────────────────────────────────────
class OpsRamp_Client {
    [string] $ConfigPath
    [hashtable] $Config
    [string] $BaseUrl
    [string] $ApiVersion
    [string] $AccessToken
    [datetime] $TokenExpiry
    [System.Net.Http.HttpClient] $HttpClient

    static [string] $TokenUrlSuffix    = '/oauth/token'
    static [string] $MetricsUrlSuffix  = '/metrics'
    static [string] $AlertsUrlSuffix   = '/alerts'
    static [string] $EventsUrlSuffix   = '/events'

    OpsRamp_Client([string] $ConfigPath) {
        $this.ConfigPath = $ConfigPath
        $this.Config     = $this._LoadConfig()
        $opsr            = $this.Config.Get_Item('opsramp_api')  ?? @{}
        $this.BaseUrl    = $opsr.Get_Item('base_url')  ?? ''
        $this.ApiVersion = $opsr.Get_Item('version')    ?? 'v2'
        $this.AccessToken   = $null
        $this.TokenExpiry   = [DateTime]::MinValue
        $this.HttpClient    = [System.Net.Http.HttpClient]::new()
    }

    [hashtable] _LoadConfig() {
        if (-not (Test-Path $this.ConfigPath)) { return @{} }
        $cfg = Import-JsonConfig -Path $this.ConfigPath -Required:$false
        if ($cfg.ContainsKey('credentials')) {
            foreach ($envName in @('OPSRAMP_CLIENT_ID','OPSRAMP_CLIENT_SECRET','OPSRAMP_TENANT_ID')) {
                $envVal = [System.Environment]::GetEnvironmentVariable($envName)
                if ($envVal) { $cfg['credentials'][$envName] = $envVal }
            }
        }
        return $cfg
    }

    [string] _GetTokenUrl() {
        return "$($this.BaseUrl.TrimEnd('/'))/$($this.ApiVersion.TrimStart('/'))$([OpsRamp_Client]::TokenUrlSuffix)"
    }

    [bool] EnsureToken() {
        if ($this.AccessToken -and $this.TokenExpiry -gt (Get-Date)) { return $true }
        $creds = $this.Config.Get_Item('credentials') ?? @{}
        $cid   = $creds.Get_Item('client_id')
        $csec  = $creds.Get_Item('client_secret')
        if (-not $cid -or -not $csec) { Write-Error 'OpsRamp client_id and client_secret required.'; return $false }
        $tokenUrl = $this._GetTokenUrl()
        $pair     = "$($cid):$($csec)"
        $bytes    = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $b64      = [Convert]::ToBase64String($bytes)
        $this.HttpClient.DefaultRequestHeaders.Authorization =
            New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Basic', $b64)
        $body = New-Object System.Net.Http.FormUrlEncodedContent(@(
            'grant_type=client_credentials'
        ))
        try {
            $resp = $this.HttpClient.PostAsync($tokenUrl, $body).Result
            $resp.EnsureSuccessStatusCode() | Out-Null
            $json          = $resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json | _ConvertTo-Hashtable
            $this.AccessToken  = $json.Get_Item('access_token')
            $expiresIn         = ($json.Get_Item('expires_in')) ?? 3600
            $this.TokenExpiry  = (Get-Date).AddSeconds($expiresIn * 0.9)
            $this.HttpClient.DefaultRequestHeaders.Authorization =
                New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $this.AccessToken)
            Write-Verbose 'OpsRamp access token obtained successfully.'
            return $true
        } catch {
            Write-Error "Failed OpsRamp token request: $($_.Exception.Message)"
            return $false
        }
    }

    [hashtable] _MakeRequest([string] $Method, [string] $Endpoint, [hashtable] $Data = $null, [hashtable] $QueryParams = $null) {
        if (-not $this.EnsureToken()) { return $null }
        [string]$url = "$($this.BaseUrl.TrimEnd('/'))/$($this.ApiVersion.TrimStart('/'))$($Endpoint.TrimStart('/'))"
        if ($QueryParams) {
            [string]$qs = ($QueryParams.Keys | ForEach-Object { "$_=$([Uri]::EscapeDataString($QueryParams[$_]))" }) -join '&'
            $url = "$url`?$qs"
        }
        try {
            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $url)
            if ($Data) {
                $json = ($Data | ConvertTo-Json -Depth 64)
                $req.Content = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, 'application/json')
            }
            $resp = $this.HttpClient.SendAsync($req).Result
            if ($resp.IsSuccessStatusCode) {
                if ($resp.Content.Headers.ContentLength -gt 0) {
                    $body = $resp.Content.ReadAsStringAsync().Result
                    return ($body | ConvertFrom-Json | _ConvertTo-Hashtable)
                }
                return @{}
            } else {
                $err = $resp.Content.ReadAsStringAsync().Result
                Write-Error "OpsRamp API $Method $Endpoint failed: $($resp.StatusCode) $err"
                return $null
            }
        } catch {
            Write-Error "OpsRamp API error: $($_.Exception.Message)"
            return $null
        }
    }

    [bool] SendMetric([string]$ResourceId, [string]$MetricName, [double]$Value,
                      [datetime]$Timestamp = [DateTime]::MinValue, [hashtable]$Tags = $null) {
        $metric = @{
            resourceId = $ResourceId
            metric     = @{
                name      = $MetricName
                value     = $Value
                timestamp = if ($Timestamp -eq [DateTime]::MinValue) { (Get-Date).ToString('o') } else { $Timestamp.ToString('o') }
                type      = 'gauge'
            }
        }
        if ($Tags) { $metric['metric']['tags'] = $Tags }
        $url  = [OpsRamp_Client]::MetricsUrlSuffix
        $resp = $this._MakeRequest('POST', $url, @($metric))
        return ($null -ne $resp)
    }

    [bool] SendAlert([string]$ResourceId, [string]$AlertType, [string]$Severity,
                     [string]$Message, [hashtable]$Details = $null) {
        $alert = @{
            resourceId = $ResourceId
            type       = $AlertType
            severity   = $Severity
            message    = $Message
            timestamp  = (Get-Date).ToString('o')
        }
        if ($Details) { $alert['details'] = $Details }
        $resp = $this._MakeRequest('POST', [OpsRamp_Client]::AlertsUrlSuffix, $alert)
        return ($null -ne $resp)
    }

    [bool] SendEvent([string]$ResourceId, [string]$EventType, [string]$Message,
                     [hashtable]$Properties = $null) {
        $evt = @{
            resourceId = $ResourceId
            type       = $EventType
            message    = $Message
            timestamp  = (Get-Date).ToString('o')
        }
        if ($Properties) { $evt['properties'] = $Properties }
        $resp = $this._MakeRequest('POST', [OpsRamp_Client]::EventsUrlSuffix, $evt)
        return ($null -ne $resp)
    }

    [bool] BatchSendMetrics([hashtable[]]$Metrics) {
        $resp = $this._MakeRequest('POST', [OpsRamp_Client]::MetricsUrlSuffix, $Metrics)
        return ($null -ne $resp)
    }

    [bool] ReportBuildStatus([string]$ServerName, [hashtable]$BuildData) {
        $uuid = $BuildData.Get_Item('uuid') ?? $ServerName
        $ok   = [int]($BuildData.Get_Item('success') ?? $false)
        $this.SendMetric($uuid, 'build.status', $ok, @{ server = $ServerName; type = 'hpe_iso_build' })
        $this.SendMetric($uuid, 'build.timestamp', [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), @{ server = $ServerName })
        if (-not $BuildData.Get_Item('success')) {
            $this.SendAlert($uuid, 'build.failure', 'CRITICAL',
                "Build failed for $ServerName : $($BuildData.Get_Item('error'))", $BuildData)
        }
        return $true
    }

    [bool] ReportDeploymentStatus([string]$ServerName, [hashtable]$DeployData) {
        $uuid = $DeployData.Get_Item('uuid') ?? $ServerName
        $ok   = [int]($DeployData.Get_Item('success') ?? $false)
        $this.SendMetric($uuid, 'deployment.status', $ok,
            @{ server = $ServerName; method = $DeployData.Get_Item('method') })
        if (-not $DeployData.Get_Item('success')) {
            $this.SendAlert($uuid, 'deployment.failure', 'WARNING',
                "Deployment failed for $ServerName", $DeployData)
        }
        return $true
    }

    [bool] ReportInstallationProgress([string]$ServerName, [string]$Uuid, [int]$ProgressPercent,
                                      [string]$Phase, [int]$ElapsedSeconds) {
        $rid = if ($Uuid) { $Uuid } else { $ServerName }
        $tags = @{ server = $ServerName; phase = $Phase }
        $this.SendMetric($rid, 'install.progress.percent', $ProgressPercent, $tags)
        $this.SendMetric($rid, 'install.elapsed_seconds', $ElapsedSeconds, $tags)
        return $true
    }

    [bool] ReportVulnerabilityScan([string]$ServerName, [string]$Uuid, [hashtable]$ScanResults) {
        $rid        = if ($Uuid) { $Uuid } else { $ServerName }
        $vulnCount  = $ScanResults.Get_Item('vulnerability_count') ?? 0
        $critCount  = $ScanResults.Get_Item('critical_count')     ?? 0
        $this.SendMetric($rid, 'security.vulnerabilities.total',  $vulnCount, @{ server = $ServerName })
        $this.SendMetric($rid, 'security.vulnerabilities.critical', $critCount, @{ server = $ServerName })
        if ($critCount -gt 0) {
            $sev = if ($critCount -gt 0) { 'CRITICAL' } else { 'WARNING' }
            $this.SendAlert($rid, 'security.vulnerability', $sev,
                "$critCount critical vulnerabilities found on $ServerName", $ScanResults)
        }
        return $true
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Base class: AutomationBase  (moved from Private/Base.psm1)
# ──────────────────────────────────────────────────────────────────────────────
class AutomationBase {
    [string]      $ConfigDir
    [string]      $OutputDir
    [bool]        $DryRun
    [object]      $Logger
    [AuditLogger] $Audit

    AutomationBase([string]$ConfigDir, [string]$OutputDir, [bool]$DryRun) {
        $this.ConfigDir = $ConfigDir
        $this.OutputDir = $OutputDir
        $this.DryRun    = $DryRun

        Ensure-DirectoryExists -Path $OutputDir
        $logDir = Join-Path ([System.IO.Path]::GetFullPath('.')) 'logs'
        Ensure-DirectoryExists -Path $logDir

        $this.Logger = $null
        $this.Audit  = [AuditLogger]::new($this.GetType().Name.ToLower(), $logDir, 'audit.log')
        $this.Audit.Log('initialization', 'INFO',
            '', "ConfigDir=$ConfigDir OutputDir=$OutputDir DryRun=$DryRun", $null)
    }

    [hashtable] LoadConfig([string]$FileName, [bool]$Required) {
        $path = [System.IO.Path]::Combine($this.ConfigDir, $FileName)
        return Import-JsonConfig -Path $path -Required $Required
    }

    [object[]] LoadServers([string]$FileName) {
        $path = [System.IO.Path]::Combine($this.ConfigDir, $FileName)
        return Load-ServerList -Path $path -IncludeDetails
    }

    [string] SaveResult([hashtable]$Data, [string]$BaseName, [string]$Category) {
        return Save-JsonResult -Data $Data -BaseName $BaseName -OutputDir $this.OutputDir -Category $Category
    }

    [void] LogAndAudit([string]$Action, [string]$Status, [string]$Server, [string]$Details) {
        Write-Host "[$Status] $Action | $Server | $Details"
        $this.Audit.Log($Action, $Status, $Server, $Details, $null)
    }

    [string] SaveAudit([string]$Filename) {
        $fp = $this.Audit.Save($Filename)
        $this.Audit.AppendToMaster()
        return $fp
    }

    [CommandResult] RunCommand([string[]]$CmdArgs) {
        return Invoke-NativeCommand -Command $CmdArgs
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Load Private scripts (dot-sourced in dependency order)
# ──────────────────────────────────────────────────────────────────────────────
$_moduleBase  = $PSScriptRoot
$_privateRoot = Join-Path $_moduleBase 'Private'
$_publicRoot  = Join-Path $_moduleBase 'Public'

# Private — dependency-ordered load
$_privateOrder = @(
    'Audit.ps1',        # New-AuditLogger
    'Config.ps1',       # Import-JsonConfig, Import-YamlConfig, _PS_* helpers
    'Credentials.ps1',  # Get-EnvCredential, Get-IloCredentials, …
    'Executor.ps1',     # Invoke-NativeCommand, Invoke-NativeCommandWithRetry, New-CommandResult
    'FileIO.ps1',       # Ensure-DirectoryExists, Save-Json, Load-Json, Save-JsonResult, Test-PathEx
    'Inventory.ps1',    # Load-ServerList, Load-ClusterCatalogue, Test-ClusterDefinition, New-ServerInfo
    'Logging.ps1',      # Initialize-Logging, Get-Logger
    '_RouteMap.ps1',    # $script:RouteMap data
    'Router.ps1',       # Invoke-RoutedRequest (uses $script:RouteMap)
    'Base.ps1'          # AutomationBase class + New-AutomationBase factory
)

foreach ($_f in $_privateOrder) {
    $_fp = Join-Path $_privateRoot $_f
    if (Test-Path $_fp) {
        try   { . $_fp }
        catch { Write-Warning "Failed to load private script $($_f): $_" }
    }
}

# Public — alphabetical, self-contained
if (Test-Path $_publicRoot) {
    Get-ChildItem $_publicRoot -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        try   { . $_.FullName }
        catch { Write-Warning "Failed to load public script $($_.Name): $_" }
    }
}

# Export only the functions that are part of the public API surface.
# Private helpers (leading underscore) and internal factories are intentionally excluded.
Export-ModuleMember -Function @(
    # Orchestrator
    'Start-AutomationOrchestrator'
    # Entry-point handlers (called by Invoke-RoutedRequest)
    'Invoke-IsoDeploy'
    'Invoke-WindowsSecurityUpdate'
    'New-IsoBuild'
    'Set-MaintenanceMode'
    'Start-InstallMonitor'
    'Test-Uuid'
    'Update-Firmware'
    # OpsRamp
    'Invoke-OpsRamp'
    'Invoke-OpsRampClient'
    # PowerShell execution
    'Invoke-PowerShellScript'
    'Invoke-PowerShellWinRM'
    'New-ScomConnection'
    'New-ScomMaintenanceScript'
    # Validators
    'Test-BuildParams'
    'Test-ClusterId'
    'Test-ServerList'
    # Config / credential helpers
    'Import-JsonConfig'
    'Import-YamlConfig'
    'Get-EnvCredential'
    'Get-IloCredentials'
    'Get-OpenViewCredentials'
    'Get-ScomCredentials'
    'Get-SmtpCredentials'
    # Process execution
    'Invoke-NativeCommand'
    'Invoke-NativeCommandWithRetry'
    'New-CommandResult'
    # File I/O
    'Ensure-DirectoryExists'
    'Save-Json'
    'Load-Json'
    'Save-JsonResult'
    'Test-PathEx'
    # Inventory
    'Load-ServerList'
    'Load-ClusterCatalogue'
    'Test-ClusterDefinition'
    'New-ServerInfo'
    # Logging / audit
    'Initialize-Logging'
    'Get-Logger'
    'New-AuditLogger'
    # Routing
    'Invoke-RoutedRequest'
    # Base / factories
    'New-AutomationBase'
)

# vim: ts=4 sw=4 et
