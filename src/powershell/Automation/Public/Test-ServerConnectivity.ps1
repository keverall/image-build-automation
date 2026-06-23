#
# Test-ServerConnectivity.ps1 — Combined network ping + authentication connectivity test
# for SCOM and OneView management servers.  Safe to run during a change freeze (read-only).
#

# ---- Script-mode param block ----
param(
    [Parameter(Position = 0)][ValidateSet('scom', 'oneview')][string] $Mode,
    [ValidateSet('Test', 'Prod')][string] $Environment,
    [string] $ManagementHost,
    [string] $ConfigDir = 'configs',
    [int] $PingTimeoutMs = 3000,
    [switch] $Json,
    [Alias('h', 'help', '?')][switch] $ShowHelp
)

if ($ShowHelp) {
    Write-Output ""
    Write-Output "NAME"
    Write-Output "    Test-ServerConnectivity"
    Write-Output ""
    Write-Output "SYNOPSIS"
    Write-Output "    Combined network ping + authentication check for SCOM or OneView servers."
    Write-Output ""
    Write-Output "SYNTAX"
    Write-Output "    Test-ServerConnectivity -Mode <scom|oneview>"
    Write-Output "        [-Environment <Test|Prod>] [-ManagementHost <string>]"
    Write-Output "        [-PingTimeoutMs <int>] [-Json]"
    Write-Output ""
    Write-Output "DESCRIPTION"
    Write-Output "    Performs read-only connectivity checks against SCOM or OneView management"
    Write-Output "    infrastructure.  Two phases are executed:"
    Write-Output ""
    Write-Output "      1. Network Ping  — DNS resolution + TCP port probe (no credentials needed)"
    Write-Output "      2. Auth Connect  — full authentication using the configured module,"
    Write-Output "                         followed by immediate disconnect"
    Write-Output ""
    Write-Output "    All operations are read-only.  No maintenance windows are created, no"
    Write-Output "    objects are modified.  Safe to run during a change freeze."
    Write-Output ""
    Write-Output "PARAMETERS"
    Write-Output ""
    Write-Output "  -Mode <scom|oneview> [REQUIRED]"
    Write-Output "    Which management platform to test."
    Write-Output ""
    Write-Output "  -Environment <Test|Prod>"
    Write-Output "    Select environment for host resolution from connection_hosts.json."
    Write-Output "    Default: $env:ENVIRONMENT, then Prod."
    Write-Output ""
    Write-Output "  -ManagementHost <string>"
    Write-Output "    Override management server/appliance (takes precedence over config)."
    Write-Output ""
    Write-Output "  -PingTimeoutMs <int>"
    Write-Output "    TCP connect timeout in milliseconds (default: 3000)."
    Write-Output ""
    Write-Output "  -Json"
    Write-Output "    Output as JSON for API integration."
    Write-Output ""
    Write-Output "  -DryRun"
    Write-Output "    Simulate without making changes. Returns mock connectivity data"
    Write-Output "    to verify configuration resolves correctly."
    Write-Output ""
    Write-Output "EXAMPLES"
    Write-Output ""
    Write-Output "    # Test SCOM Test environment"
    Write-Output "    Test-ServerConnectivity -Mode scom -Environment Test"
    Write-Output ""
    Write-Output "    # Test OneView Prod with JSON output"
    Write-Output "    Test-ServerConnectivity -Mode oneview -Environment Prod -Json"
    Write-Output ""
    Write-Output "    # Override management host"
    Write-Output "    Test-ServerConnectivity -Mode scom -ManagementHost 'scom-test.local'"
    Write-Output ""
    exit 0
}

# ---- Module import for script mode ----
if (-not (Get-Module -Name 'Automation' -ErrorAction SilentlyContinue) -and $MyInvocation.InvocationName -ne '.') {
    if ($MyInvocation.InvocationName -match '\.ps1$') {
        $modulePath = Join-Path $PSScriptRoot '..\Automation.psd1'
        Import-Module $modulePath -Force -WarningAction SilentlyContinue
    }
}

function Test-ServerConnectivity {
    <#
    .SYNOPSIS
        Combined network ping + authentication connectivity test for SCOM or OneView.
        Read-only — safe during a change freeze.

    .DESCRIPTION
        Phase 1: Network Ping
          - DNS resolution of the management host
          - TCP port probe (WinRM 5985/5986 for SCOM, HTTPS 443 for OneView)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - Resolves credentials from environment variables / CyberArk
          - Loads the relevant PowerShell module
          - Performs a full authentication (New-SCOMManagementGroupConnection or Connect-OVMgmt)
          - Immediately disconnects
          - No objects are modified

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER Mode
        'scom' or 'oneview'.

    .PARAMETER Environment
        'Test' or 'Prod'.  Resolves host from connection_hosts.json.

    .PARAMETER ManagementHost
        Direct override for the management server/appliance hostname.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs').

    .PARAMETER PingTimeoutMs
        TCP connect timeout in milliseconds (default: 3000).

    .PARAMETER Json
        If set, outputs the result as a JSON string instead of formatted text.

    .RETURNS
        [hashtable] with keys:
          Available        [bool]   — overall pass/fail
          Mode             [string]
          ManagementHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] — DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] — Connected, Disconnected, ModuleLoaded, Error
          Timestamp        [string]   — UTC ISO 8601
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateSet('scom', 'oneview')][string] $Mode,
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [string] $ManagementHost,
        [string] $ConfigDir = 'configs',
        [int] $PingTimeoutMs = 3000,
        [switch] $Json
    )

    $ErrorActionPreference = 'Continue'
    $Mode = $Mode.ToLower()

    # ── Resolve config directory ──────────────────────────────────────────────
    $projRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
    $EffectiveConfigDir = if ($PSBoundParameters.ContainsKey('ConfigDir')) {
        if (Split-Path $ConfigDir -IsAbsolute) { $ConfigDir }
        else { Join-Path (Get-Location) $ConfigDir }
    } else {
        Join-Path $projRoot 'configs'
    }

    if (-not (Test-Path (Join-Path $EffectiveConfigDir 'connection_hosts.json'))) {
        if (-not (Split-Path $ConfigDir -IsAbsolute)) {
            $fallback = Join-Path $projRoot $ConfigDir
            if (Test-Path (Join-Path $fallback 'connection_hosts.json')) {
                $EffectiveConfigDir = $fallback
            }
        }
    }

    # ── Resolve environment ───────────────────────────────────────────────────
    $effectiveEnv = if ($PSBoundParameters.ContainsKey('Environment')) {
        $Environment
    } elseif ([System.Environment]::GetEnvironmentVariable('ENVIRONMENT')) {
        [System.Environment]::GetEnvironmentVariable('ENVIRONMENT')
    } else {
        'Prod'
    }

    # ── Resolve management host ───────────────────────────────────────────────
    $hostsCfgPath = Join-Path $EffectiveConfigDir 'connection_hosts.json'
    $hostsCfg = if (Test-Path $hostsCfgPath) {
        Import-JsonConfig -Path $hostsCfgPath -Required:$false
    } else { @{} }

    $envConfig = $hostsCfg.Get_Item('environments') ?? @{}
    $selectedEnv = $envConfig.Get_Item($effectiveEnv) ?? @{}

    $resolvedHost = if ($PSBoundParameters.ContainsKey('ManagementHost')) {
        $ManagementHost
    } elseif ([System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')) {
        [System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')
    } else {
        if ($Mode -eq 'scom') {
            ($selectedEnv.Get_Item('scom') ?? @{}).Get_Item('management_server')
        } else {
            ($selectedEnv.Get_Item('oneview') ?? @{}).Get_Item('appliance')
        }
    }

    if (-not $resolvedHost) {
        $result = @{
            Available      = $false
            Mode           = $Mode
            ManagementHost = $null
            Environment    = $effectiveEnv
            NetworkPing    = @{ DnsResolved = $false; Error = "Management host not configured for environment '$effectiveEnv'" }
            AuthConnect    = @{ Connected = $false; Error = "Skipped — no management host" }
            Timestamp      = Get-UtcTimestamp
        }
        return $result
    }

    # ── Load mode-specific config ─────────────────────────────────────────────
    $modeCfg = @{}
    if ($Mode -eq 'scom') {
        $scomCfgPath = Join-Path $EffectiveConfigDir 'scom_config.json'
        $scomCfg = if (Test-Path $scomCfgPath) {
            Import-JsonConfig -Path $scomCfgPath -Required:$false
        } else { @{} }
        $modeCfg = $scomCfg.Get_Item('scom') ?? @{}
    } else {
        $ovCfgPath = Join-Path $EffectiveConfigDir 'oneview_config.json'
        $ovCfg = if (Test-Path $ovCfgPath) {
            Import-JsonConfig -Path $ovCfgPath -Required:$false
        } else { @{} }
        $modeCfg = $ovCfg.Get_Item('oneview') ?? @{}
    }

    $useWinRM = [bool]($modeCfg.Get_Item('use_winrm') ?? $false)

    # ── Resolve credentials ───────────────────────────────────────────────────
    $credCfg = $modeCfg.Get_Item('credentials') ?? @{}
    $userEnv = $credCfg.Get_Item('username_env')
    $passEnv = $credCfg.Get_Item('password_env')
    $resolvedUser = $null
    $resolvedPass = $null

    if ($userEnv -and $passEnv) {
        try {
            $resolvedUser = Get-EnvCredential -EnvVarName $userEnv
            $resolvedPass = Get-EnvCredential -EnvVarName $passEnv
        } catch {
            Write-Warning "Credential resolution failed: $($_.Exception.Message)"
        }
    }

    # ── Determine TCP ports to probe ──────────────────────────────────────────
    $tcpPorts = @()
    if ($Mode -eq 'scom') {
        if ($useWinRM) {
            $tcpPorts = @(5985, 5986)
        } else {
            $tcpPorts = @(5985, 135)
        }
    } else {
        $tcpPorts = @(443)
    }

    # ══════════════════════════════════════════════════════════════════════════
    # PHASE 1: Network Ping
    # ══════════════════════════════════════════════════════════════════════════
    $pingResult = @{
        DnsResolved = $false
        IpAddress   = $null
        TcpPortOpen = $false
        Port        = $null
        LatencyMs   = -1
        Error       = $null
    }

    # DNS resolution
    try {
        $dnsResult = [System.Net.Dns]::GetHostEntry($resolvedHost)
        $pingResult.DnsResolved = $true
        if ($dnsResult.AddressList.Count -gt 0) {
            $pingResult.IpAddress = $dnsResult.AddressList[0].IPAddressToString
        }
    } catch [System.Net.Sockets.SocketException] {
        $pingResult.Error = "DNS resolution failed for '$resolvedHost': $($_.Exception.Message)"
    } catch {
        $pingResult.Error = "DNS resolution failed: $($_.Exception.Message)"
    }

    # TCP port probe
    if ($pingResult.DnsResolved) {
        foreach ($port in $tcpPorts) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $tcpClient = [System.Net.Sockets.TcpClient]::new()
                $connectTask = $tcpClient.ConnectAsync($resolvedHost, $port)
                $connected = $connectTask.Wait($PingTimeoutMs)
                $sw.Stop()
                if ($connected -and $tcpClient.Connected) {
                    $pingResult.TcpPortOpen = $true
                    $pingResult.Port = $port
                    $pingResult.LatencyMs = [int]$sw.ElapsedMilliseconds
                    $tcpClient.Close()
                    break
                } else {
                    $tcpClient.Dispose()
                }
            } catch {
                $sw.Stop()
                $tcpClient.Dispose()
            }
        }
        if (-not $pingResult.TcpPortOpen) {
            $portList = ($tcpPorts -join ', ')
            $pingResult.Error = "TCP connection failed — no open port found ($portList) on '$resolvedHost' within ${PingTimeoutMs}ms"
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Authentication Connect
    # ══════════════════════════════════════════════════════════════════════════
    $authResult = @{
        Connected    = $false
        Disconnected = $false
        ModuleLoaded = $false
        Error        = $null
    }

    if (-not $pingResult.TcpPortOpen) {
        $authResult.Error = "Skipped — network ping failed"
    } elseif (-not $resolvedUser -or -not $resolvedPass) {
        $authResult.Error = "Skipped — credentials not configured (set $userEnv / $passEnv)"
    } else {
        if ($Mode -eq 'scom') {
            $moduleName = $modeCfg.Get_Item('powershell_module') ?? 'OperationsManager'
            $winrmServer = if ($useWinRM) { $resolvedHost } else { $null }

            $scriptContent = @"
Import-Module $moduleName -ErrorAction Stop
Write-Output "MODULE_LOADED"
`$securePass = ConvertTo-SecureString '$resolvedPass' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$resolvedUser', `$securePass)
`$conn = New-SCOMManagementGroupConnection -ComputerName '$resolvedHost' -Credential `$cred -ErrorAction Stop
Write-Output "CONNECTED"
Remove-SCOMManagementGroupConnection -ComputerName '$resolvedHost' -ErrorAction SilentlyContinue
Write-Output "DISCONNECTED"
"@
            try {
                if ($useWinRM) {
                    $secPass = ConvertTo-SecureString $resolvedPass -AsPlainText -Force
                    $scriptResult = Invoke-PowerShellWinRM -Script $scriptContent `
                        -Server $resolvedHost -Username $resolvedUser -Password $secPass
                } else {
                    $scriptResult = Invoke-PowerShellScript -Script $scriptContent
                }
                $output = $scriptResult.Output
                if ($output -match 'MODULE_LOADED') { $authResult.ModuleLoaded = $true }
                if ($output -match 'CONNECTED')     { $authResult.Connected = $true }
                if ($output -match 'DISCONNECTED')  { $authResult.Disconnected = $true }
                if (-not $scriptResult.Success -and -not $authResult.Connected) {
                    $authResult.Error = "Connection script failed: $output"
                }
            } catch {
                $authResult.Error = "Auth error: $($_.Exception.Message)"
            }
        } else {
            $moduleName = $modeCfg.Get_Item('module_name') ?? 'HPEOneView.860'
            $ovAppliance = $resolvedHost

            $winrmServer = if ($useWinRM) {
                ($modeCfg.Get_Item('winrm') ?? @{}).Get_Item('server') ?? $resolvedHost
            } else { $null }

            $scriptContent = @"
Import-Module $moduleName -ErrorAction Stop
Write-Output "MODULE_LOADED"
`$securePass = ConvertTo-SecureString '$resolvedPass' -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential('$resolvedUser', `$securePass)
Connect-OVMgmt -Hostname '$ovAppliance' -Credential `$cred -ErrorAction Stop
Write-Output "CONNECTED"
Disconnect-OVMgmt -ErrorAction SilentlyContinue
Write-Output "DISCONNECTED"
"@
            try {
                if ($useWinRM) {
                    $secPass = ConvertTo-SecureString $resolvedPass -AsPlainText -Force
                    $scriptResult = Invoke-PowerShellWinRM -Script $scriptContent `
                        -Server $winrmServer -Username $resolvedUser -Password $secPass
                } else {
                    $scriptResult = Invoke-PowerShellScript -Script $scriptContent
                }
                $output = $scriptResult.Output
                if ($output -match 'MODULE_LOADED') { $authResult.ModuleLoaded = $true }
                if ($output -match 'CONNECTED')     { $authResult.Connected = $true }
                if ($output -match 'DISCONNECTED')  { $authResult.Disconnected = $true }
                if (-not $scriptResult.Success -and -not $authResult.Connected) {
                    $authResult.Error = "Connection script failed: $output"
                }
            } catch {
                $authResult.Error = "Auth error: $($_.Exception.Message)"
            }
        }
    }

    # ── Assemble result ───────────────────────────────────────────────────────
    $available = $pingResult.TcpPortOpen -and $authResult.Connected

    $result = @{
        Available      = $available
        Mode           = $Mode
        ManagementHost = $resolvedHost
        Environment    = $effectiveEnv
        NetworkPing    = $pingResult
        AuthConnect    = $authResult
        Timestamp      = Get-UtcTimestamp
    }

    return $result
}

# ── Output formatting ─────────────────────────────────────────────────────────
function _Format-ConnectivityResult {
    param([hashtable]$Result)

    $available = $Result.Available
    $header = if ($available) {
        "AVAILABLE"
    } else {
        "UNAVAILABLE"
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  Server Connectivity Test" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $statusColor = if ($available) { 'Green' } else { 'Red' }
    Write-Host "  Status:     $header" -ForegroundColor $statusColor
    Write-Host "  Mode:       $($Result.Mode)"
    Write-Host "  Host:       $($Result.ManagementHost)"
    Write-Host "  Environment:$($Result.Environment)"
    Write-Host "  Timestamp:  $($Result.Timestamp)"
    Write-Host ""

    Write-Host "  --- Phase 1: Network Ping ---" -ForegroundColor Yellow
    $np = $Result.NetworkPing
    Write-Host "    DNS:       $(if ($np.DnsResolved) { 'Resolved' } else { 'FAILED' })" `
        -ForegroundColor $(if ($np.DnsResolved) { 'Green' } else { 'Red' })
    if ($np.IpAddress) {
        Write-Host "    IP:        $($np.IpAddress)"
    }
    Write-Host "    TCP:       $(if ($np.TcpPortOpen) { "Open (port $($np.Port), $($np.LatencyMs)ms)" } else { 'FAILED' })" `
        -ForegroundColor $(if ($np.TcpPortOpen) { 'Green' } else { 'Red' })
    if ($np.Error) {
        Write-Host "    Error:     $($np.Error)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "  --- Phase 2: Auth Connect ---" -ForegroundColor Yellow
    $ac = $Result.AuthConnect
    $authColor = if ($ac.Connected) { 'Green' } elseif ($ac.Error -match 'Skipped') { 'Yellow' } else { 'Red' }
    Write-Host "    Module:    $(if ($ac.ModuleLoaded) { 'Loaded' } else { 'Not loaded' })" `
        -ForegroundColor $(if ($ac.ModuleLoaded) { 'Green' } else { 'Red' })
    Write-Host "    Connected: $(if ($ac.Connected) { 'Yes' } else { 'No' })" -ForegroundColor $authColor
    Write-Host "    Clean up:  $(if ($ac.Disconnected) { 'Disconnected' } elseif ($ac.Connected) { 'WARNING - still connected' } else { 'N/A' })" `
        -ForegroundColor $(if ($ac.Disconnected) { 'Green' } elseif ($ac.Connected) { 'Yellow' } else { 'Gray' })
    if ($ac.Error) {
        Write-Host "    Error:     $($ac.Error)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# ── Script-mode entry point ───────────────────────────────────────────────────
if ($MyInvocation.InvocationName -ne '.' -and $PSCommandPath -eq $MyInvocation.ScriptName) {
    if ($Mode) {
        $connParams = @{ Mode = $Mode; PingTimeoutMs = $PingTimeoutMs }
        if ($PSBoundParameters.ContainsKey('Environment'))    { $connParams['Environment'] = $Environment }
        if ($PSBoundParameters.ContainsKey('ManagementHost')) { $connParams['ManagementHost'] = $ManagementHost }
        if ($PSBoundParameters.ContainsKey('ConfigDir'))      { $connParams['ConfigDir'] = $ConfigDir }

        $result = Test-ServerConnectivity @connParams

        if ($Json) {
            $result | ConvertTo-Json -Depth 10
        } else {
            _Format-ConnectivityResult -Result $result
        }

        if (-not $result.Available) { exit 1 }
    }
}
