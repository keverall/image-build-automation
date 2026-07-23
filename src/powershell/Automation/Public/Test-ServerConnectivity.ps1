#
# Test-ServerConnectivity.ps1 - OneView-only network ping + authentication
# connectivity test.  Safe to run during a change freeze (read-only).
#

function Test-ServerConnectivity {
    <#
    .SYNOPSIS
        OneView-only network ping + authentication connectivity test.
        Read-only - safe during a change freeze.

    .DESCRIPTION
        Phase 1: Network Ping
          - DNS resolution of the OneView appliance
          - TCP port probe (HTTPS 443)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - Prompts for username/password (or uses -Credential)
          - Loads the HPE OneView PowerShell module
          - Performs a full authentication (Connect-OVMgmt)
          - Session persists for subsequent OneView commands
          - No objects are modified

        SAFETY / COMPLIANCE (regulated EMIR environment):
          - On a live run, config files are NEVER read. The appliance host is
            taken verbatim from -ManagementHost and only that appliance is
            contacted. Credentials are never taken from config - they are supplied
            via -Credential or entered interactively.
          - Config files (connection_hosts.json, oneview_config.json) are read
            ONLY with -DryRun, for dry-run validation.

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER Environment
        'Test' or 'Prod'. Informational for live runs. Host resolution from
        connection_hosts.json only happens with -JsonConfig AND -DryRun.

    .PARAMETER ManagementHost
        OneView appliance to connect to (server name or serial).
        REQUIRED for a live run. Used verbatim - no config/env fallback - so only
        the host you specify is ever contacted.

    .PARAMETER Credential
        PSCredential for the live connection (e.g. -Credential (Get-Credential)).
        If omitted on a live run, the command prompts interactively for username
        and password. Never read from config.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs'). Only used
        with -DryRun.

    .PARAMETER PingTimeoutMs
        TCP connect timeout in milliseconds (default: 3000).

    .PARAMETER Json
        If set, outputs the result as a JSON string instead of formatted text.

    .PARAMETER JsonConfig
        Reads the OneView appliance from configs/connection_hosts.json. ONLY
        honoured together with -DryRun (config is for dry-run testing, never
        live runs).

    .PARAMETER DryRun
        Simulate connectivity without actual network calls. Returns mock data to
        verify configuration resolution. Config files may be read for validation.

    .RETURNS
        [hashtable] with keys:
          Available        [bool]   - overall pass/fail
          Mode             [string] - always 'oneview'
          ManagementHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] - DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] - Connected, ModuleLoaded, Error
          Timestamp        [string]   - UTC ISO 8601

    .NOTES
        The OneView session established by this command persists in the current
        session and can be reused by subsequent OneView commands (Get-OneViewServerList,
        Get-OneViewConnectionStatus, etc.). Use Disconnect-OneView to explicitly
        close the session when finished.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Interactive prompt builds PSCredential from operator-entered password for Connect-OVMgmt; password is never persisted or logged.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [string] $ManagementHost,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $ConfigDir = 'configs',
        [int] $PingTimeoutMs = 3000,
        [switch] $Json,
        [switch] $JsonConfig,
        [switch] $DryRun
    )

    $ErrorActionPreference = 'Continue'
    $Mode = 'oneview'
    Initialize-Logging -LogFile 'connectivity.log' -CommandName 'Test-ServerConnectivity' -LogName "Test-ServerConnectivity-ManagementHost-$ManagementHost"
    $logger = Get-Logger 'Connectivity'
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
    # 'Environment' is informational for live tests. It is ONLY used to select a
    # host from connection_hosts.json, and that file is read ONLY in -DryRun mode.
    $effectiveEnv = if ($PSBoundParameters.ContainsKey('Environment')) {
        $Environment
    } elseif ([System.Environment]::GetEnvironmentVariable('ENVIRONMENT')) {
        [System.Environment]::GetEnvironmentVariable('ENVIRONMENT')
    } else {
        'Prod'
    }

    # ── Config is ONLY used in DryRun mode ─────────────────────────────────────
    # A live (non-DryRun) connectivity test MUST be driven entirely by parameters
    # the operator supplies on the command line.  Reading host/credential config
    # during a live run would risk silently connecting to an appliance the
    # operator did not intend (regulated EMIR environment - no silent fallbacks,
    # no data loss).  -ManagementHost is therefore required and used VERBATIM.
    if (-not $DryRun) {
        if ($JsonConfig) {
            Write-Warning "-JsonConfig is ignored for live tests. Config files are only read with -DryRun."
        }
        if (-not $PSBoundParameters.ContainsKey('ManagementHost') -or -not $ManagementHost) {
            $result = @{
                Available      = $false
                Mode           = $Mode
                ManagementHost = $null
                Environment    = $effectiveEnv
                NetworkPing    = @{
                    DnsResolved = $false
                    Error       = "ManagementHost is required for a live connectivity test. Supply -ManagementHost <host> (server name or serial) or use -DryRun for config-based validation."
                }
                AuthConnect    = @{ Connected = $false; Error = "Skipped - no management host" }
                Timestamp      = Get-UtcTimestamp
            }
            if (-not $Json) { _Format-ConnectivityResult -Result $result }
            return $result
        }

        # Host is taken verbatim from the command line - no config/env fallback.
        $resolvedHost = $ManagementHost.Trim()

        # Sensible defaults for the live connection (no config file is read).
        $modeCfg = @{ module_name = 'HPEOneView.1000'; use_winrm = $false }
        $useWinRM = $false
        $userEnv  = $null
        $passEnv  = $null
    } else {
        # ── DryRun: config is permitted for validation only ────────────────────
        $resolvedHost = $null

        # 1. Explicit -ManagementHost parameter (verbatim, highest priority)
        if ($PSBoundParameters.ContainsKey('ManagementHost') -and $ManagementHost) {
            $resolvedHost = $ManagementHost.Trim()
        }

        # 2. Config file lookup (only with -JsonConfig switch, only in DryRun)
        if (-not $resolvedHost -and $JsonConfig) {
            $hostsCfgPath = Join-Path $EffectiveConfigDir 'connection_hosts.json'
            $hostsCfg = if (Test-Path $hostsCfgPath) {
                Import-JsonConfig -Path $hostsCfgPath -Required:$false
            } else { @{} }

            $envConfig   = $hostsCfg.Get_Item('environments') ?? @{}
            $selectedEnv = $envConfig.Get_Item($effectiveEnv) ?? @{}

            $oneviewCfg  = $selectedEnv.Get_Item('oneview') ?? @{}
            $resolvedHost = $oneviewCfg.Get_Item('appliance')

            if (-not $resolvedHost) {
                $errorMsg = "OneView appliance not configured in connection_hosts.json for environment '$effectiveEnv'."
                $result = @{
                    Available      = $false
                    Mode           = $Mode
                    ManagementHost = $null
                    Environment    = $effectiveEnv
                    NetworkPing    = @{ DnsResolved = $false; Error = $errorMsg }
                    AuthConnect    = @{ Connected = $false; Error = "Skipped - no management host" }
                    Timestamp      = Get-UtcTimestamp
                    DryRun         = $true
                }
                if (-not $Json) { _Format-ConnectivityResult -Result $result }
                return $result
            }
        }

        # 3. Interactive prompt (DryRun without explicit host / config)
        if (-not $resolvedHost) {
            $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
            if (-not $isAutomated) {
                Write-Host "Enter OneView appliance host (or press Enter to cancel): " -ForegroundColor Yellow -NoNewline
                $promptedHost = Read-Host
                if ($promptedHost) { $resolvedHost = $promptedHost.Trim() }
            }
        }

        if (-not $resolvedHost) {
            $errorMsg = "No OneView appliance provided. Use -ManagementHost, -JsonConfig (DryRun), or set `$env:MAINTENANCE_HOST."
            $result = @{
                Available      = $false
                Mode           = $Mode
                ManagementHost = $null
                Environment    = $effectiveEnv
                NetworkPing    = @{ DnsResolved = $false; Error = $errorMsg }
                AuthConnect    = @{ Connected = $false; Error = "Skipped - no management host" }
                Timestamp      = Get-UtcTimestamp
                DryRun         = $true
            }
            if (-not $Json) { _Format-ConnectivityResult -Result $result }
            return $result
        }

        # Load OneView config (DryRun only).
        $ovCfgPath = Join-Path $EffectiveConfigDir 'oneview_config.json'
        $ovCfg = if (Test-Path $ovCfgPath) {
            Import-JsonConfig -Path $ovCfgPath -Required:$false
        } else { @{} }
        $modeCfg = $ovCfg.Get_Item('oneview') ?? @{}

        $useWinRM = [bool]($modeCfg.Get_Item('use_winrm') ?? $false)
        $credCfg  = $modeCfg.Get_Item('credentials') ?? @{}
        $userEnv  = $credCfg.Get_Item('username_env')
        $passEnv  = $credCfg.Get_Item('password_env')
    }

    # ── Resolve credentials ───────────────────────────────────────────────────
    # LIVE run: credentials are NEVER read from config.  They must be supplied
    # via -Credential or entered interactively, so the operator explicitly
    # authorises the connection to the exact host they named.
    # DRYRUN: mock credentials - no real secret is required.
    $resolvedUser = $null
    $resolvedPass = $null
    if (-not $DryRun) {
        if ($PSBoundParameters.ContainsKey('Credential') -and $Credential) {
            $resolvedUser = $Credential.UserName
            $resolvedPass = $Credential.GetNetworkCredential().Password
        } else {
            $isInteractive = [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected
            if ($isInteractive) {
                Write-Host "Enter OneView username for '$resolvedHost': " -ForegroundColor Yellow -NoNewline
                $u = Read-Host
                $securePass = Read-Host "Enter OneView password for '$resolvedHost': " -AsSecureString
                if (-not $u) {
                    $result = @{
                        Available      = $false
                        Mode           = $Mode
                        ManagementHost = $resolvedHost
                        Environment    = $effectiveEnv
                        NetworkPing    = @{ DnsResolved = $false; Error = "No username supplied - aborting connectivity test." }
                        AuthConnect    = @{ Connected = $false; Error = "Skipped - no credentials" }
                        Timestamp      = Get-UtcTimestamp
                    }
                    if (-not $Json) { _Format-ConnectivityResult -Result $result }
                    return $result
                }
                $resolvedUser = $u
                $resolvedPass = $securePass | ConvertFrom-SecureString -AsPlainText
            } else {
                $result = @{
                    Available      = $false
                    Mode           = $Mode
                    ManagementHost = $resolvedHost
                    Environment    = $effectiveEnv
                    NetworkPing    = @{ DnsResolved = $false; Error = "Credentials required for a live test. Supply -Credential or run interactively." }
                    AuthConnect    = @{ Connected = $false; Error = "Skipped - no credentials" }
                    Timestamp      = Get-UtcTimestamp
                }
                if (-not $Json) { _Format-ConnectivityResult -Result $result }
                return $result
            }
        }
    }

    # ── Determine TCP ports to probe (OneView = HTTPS 443) ────────────────────
    $tcpPorts = @(443)

    # ══════════════════════════════════════════════════════════════════════════
    # DRYRUN MODE: Return mock data without real network calls
    # ══════════════════════════════════════════════════════════════════════════
    if ($DryRun) {
        Write-Verbose "DryRun mode enabled - returning mock connectivity data"

        $moduleName = $modeCfg.Get_Item('module_name') ?? 'HPEOneView.1000'

        $mockPingResult = @{
            DnsResolved = $true
            IpAddress   = '10.254.254.254'
            TcpPortOpen = $true
            Port        = $tcpPorts[0]
            LatencyMs   = 1
            Error       = $null
        }

        $mockAuthResult = @{
            Connected    = $true
            ModuleLoaded = $true
            Error        = $null
        }

        $mockResult = @{
            Available      = $true
            Mode           = $Mode
            ManagementHost = $resolvedHost
            Environment    = $effectiveEnv
            NetworkPing    = $mockPingResult
            AuthConnect    = $mockAuthResult
            Timestamp      = Get-UtcTimestamp
            DryRun         = $true
            MockData       = @{
                TargetPorts        = $tcpPorts
                PowerShellModule   = $moduleName
                WinRM              = $useWinRM
                CredentialUserEnv  = $(if ($userEnv) { $userEnv } else { 'not configured' })
                CredentialPassEnv  = $(if ($passEnv) { $passEnv } else { 'not configured' })
                Note               = "Mock data - no actual connectivity test performed"
            }
        }

        if (-not $Json) {
            _Format-ConnectivityResult -Result $mockResult
        }
        $logger.Info("Connectivity test for '$resolvedHost' completed (DryRun): Available=$($mockResult.Available), Mode=$($mockResult.Mode)")
        return $mockResult
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
    $logger.Info("DNS resolution for '$resolvedHost': $(if ($pingResult.DnsResolved) { "Resolved -> $($pingResult.IpAddress)" } else { "FAILED - $($pingResult.Error)" })")

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
            $pingResult.Error = "TCP connection failed - no open port found ($portList) on '$resolvedHost' within ${PingTimeoutMs}ms"
        }
    }

    $logger.Info("TCP probe for '$resolvedHost': $(if ($pingResult.TcpPortOpen) { "Open (port $($pingResult.Port), $($pingResult.LatencyMs)ms)" } else { "FAILED - $($pingResult.Error)" })")

    # If credentials were resolved interactively (but -Credential was not supplied),
    # build a PSCredential so Connect-OneViewSession receives them.
    if (-not $Credential -and $resolvedUser -and $resolvedPass) {
        $Credential = [System.Management.Automation.PSCredential]::new(
            $resolvedUser,
            (ConvertTo-SecureString $resolvedPass -AsPlainText -Force))
    }

    # ══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Authentication Connect (OneView)
    # ══════════════════════════════════════════════════════════════════════════
    $authResult = @{
        Connected    = $false
        Disconnected = $false
        ModuleLoaded = $false
        Error        = $null
    }

    if (-not $pingResult.TcpPortOpen) {
        $authResult.Error = "Skipped - network ping failed"
    } elseif (-not $resolvedUser -or -not $resolvedPass) {
        if ($DryRun) {
            $authResult.Error = "Skipped - credentials not configured (set $userEnv / $passEnv)"
        } else {
            $authResult.Error = "Skipped - credentials not supplied"
        }
    } else {
        $moduleName = $modeCfg.Get_Item('module_name') ?? 'HPEOneView.1000'

        $connResult = Connect-OneViewSession -Appliance $resolvedHost -Credential $Credential -ModuleName $moduleName
        $authResult.ModuleLoaded = $true
        $authResult.Connected = $connResult.Connected
        if ($connResult.Error) {
            $authResult.Error = $connResult.Error
            $logger.Error("Authentication to '$resolvedHost' failed: $($connResult.Error)")
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

    if (-not $Json) {
        _Format-ConnectivityResult -Result $result
    }

    $logger.Info("Connectivity test for '$resolvedHost' completed: Available=$available " +
        "(DNS=$($pingResult.DnsResolved), TCP=$($pingResult.TcpPortOpen), Auth=$($authResult.Connected))")

    return $result
}

# ── Output formatting ─────────────────────────────────────────────────────────
function _Format-ConnectivityResult {
    <#
    .SYNOPSIS
        Formats connectivity result.
    #>

    param([hashtable]$Result)

    $available = $Result.Available
    $header = if ($available) {
        "AVAILABLE"
    } else {
        "UNAVAILABLE"
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Connectivity Test" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $statusColor = if ($available) { 'Green' } else { 'Red' }
    $dryRunTag = if ($Result.DryRun) { ' [DRY-RUN]' } else { '' }
    Write-Host "  Status:     ${header}${dryRunTag}" -ForegroundColor $statusColor
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
    Write-Host "    Connected: $(if ($ac.Connected) { 'Yes (session active)' } else { 'No' })" -ForegroundColor $authColor
    if ($ac.Error) {
        Write-Host "    Error:     $($ac.Error)" -ForegroundColor Red
    }

    if ($Result.DryRun -and $Result.MockData) {
        Write-Host ""
        Write-Host "  --- Dry-Run Configuration Summary ---" -ForegroundColor Yellow
        $mock = $Result.MockData
        Write-Host "    Module:       $($mock.PowerShellModule)"
        Write-Host "    Target ports: $($mock.TargetPorts -join ', ')"
        Write-Host "    WinRM:        $($mock.WinRM)"
        Write-Host "    Cred user:    $($mock.CredentialUserEnv)"
        Write-Host "    Cred pass:    $($mock.CredentialPassEnv)"
        Write-Host "    Note:         $($mock.Note)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}
