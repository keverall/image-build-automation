#
# OpsRampClient.psm1 — OpsRamp REST API client equivalent of Python cli/opsramp_integration.py
#

<#

.SYNOPSIS
    OpsRamp REST API client: OAuth2 token management, metrics, alerts, and events.

#>

function Invoke-OpsRampClient {
    <#
    .SYNOPSIS
        Factory function: creates a new OpsRampClient class instance from a config path.

    .PARAMETER ConfigPath
        Path to opsramp_config.json.

    .EXAMPLE
        $client = Invoke-OpsRampClient -ConfigPath 'configs\opsramp_config.json'
    #>
    [CmdletBinding()]
    [OutputType([OpsRamp_Client])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ConfigPath
    )
    return [OpsRamp_Client]::new($ConfigPath)
}

function Invoke-OpsRamp {
    <#
    .SYNOPSIS
        Quick CLI test of the OpsRamp API connection.

    .PARAMETER ConfigPath
        Path to opsramp_config.json.

    .EXAMPLE
        Invoke-OpsRamp -ConfigPath 'configs\opsramp_config.json'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$ConfigPath = 'configs\opsramp_config.json')
    $client = [OpsRamp_Client]::new($ConfigPath)
    return $client.EnsureToken()
}

class OpsRamp_Client {
    <#
    .SYNOPSIS
        OpsRamp API client — mirrors OpsRampClient Python class.
    #>
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
        # Override credentials from env vars
        if ($cfg.ContainsKey('credentials')) {
            foreach ($envName in @('OPSRAMP_CLIENT_ID','OPSRAMP_CLIENT_SECRET','OPSRAMP_TENANT_ID')) {
                $envVal = [System.Environment]::GetEnvironmentVariable($envName)
                if ($envVal) {
                    $cfg['credentials'][$envName] = $envVal
                }
            }
        }
        return $cfg
    }

    [string] _GetTokenUrl() {
        return "$($this.BaseUrl.TrimEnd('/'))/$($this.ApiVersion.TrimStart('/'))$([OpsRamp_Client]::TokenUrlSuffix)"
    }

    [bool] EnsureToken() {
        if ($this.AccessToken -and $this.TokenExpiry -gt (Get-Date)) { return $true }
        $creds  = $this.Config.Get_Item('credentials')  ?? @{}
        $cid    = $creds.Get_Item('client_id')
        $csec   = $creds.Get_Item('client_secret')
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
            $json   = $resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json | _ConvertTo-Hashtable
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

# vim: ts=4 sw=4 et
