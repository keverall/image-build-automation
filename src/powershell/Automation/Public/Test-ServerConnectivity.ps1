#
# Test-ServerConnectivity.ps1 - OneView-only network ping + authentication
# connectivity test.  Safe to run during a change freeze (read-only).
#

function Test-ServerConnectivity {
    <#
    .SYNOPSIS
        OneView-only network ping + authentication connectivity STATUS CHECK.
        Read-only - safe during a change freeze.

    .DESCRIPTION
        This command reports the connectivity of an HPE OneView appliance. It is
        a STATUS CHECK, not a connect command - it NEVER prompts for a host or
        credentials.

          * Run with NO parameters: reports the ACTIVE OneView connection
            (established by Connect-OneView). If nothing is connected it reports
            "not connected" and returns - no prompt.
          * Run with -OneViewHost <host>: checks THAT specific appliance only.

        Phase 1: Network Ping
          - DNS resolution of the OneView appliance
          - TCP port probe (HTTPS 443)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - If reusing the active session (no -OneViewHost, or -OneViewHost
            matches the connected appliance) the existing session is reused - no
            credentials are needed.
          - Otherwise credentials come from -Credential, ONEVIEW_USER /
            ONEVIEW_PASSWORD, or CyberArk. If none are available the auth phase is
            skipped with a clear message (no prompt).
          - Loads the HPE OneView PowerShell module and performs Connect-OVMgmt.
          - Session persists for subsequent OneView commands.
          - No objects are modified.

        To actually CONNECT to an appliance, use Connect-OneView -OneViewHost
        <host> (which prompts for credentials and establishes the session this
        command then reports on).

        SAFETY / COMPLIANCE (regulated EMIR environment):
          - On a live run, config files are NEVER read. The appliance host is
            taken verbatim from -OneViewHost (when supplied) and only that
            appliance is contacted. Credentials are never read from config.
          - Config files (connection_hosts.json, oneview_config.json) are read
            ONLY with -DryRun, for dry-run validation.

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER OneViewHost
        OneView appliance to check (server name or serial). Optional.

        When OMITTED, the command reports the ACTIVE OneView connection
        (established by Connect-OneView) and never prompts. When supplied it is
        used verbatim - no config/env fallback - so only the host you specify is
        ever contacted. Credentials are not prompted for: the active session is
        reused when it matches, otherwise supply -Credential or configure
        ONEVIEW_USER / ONEVIEW_PASSWORD.

    .PARAMETER DryRun
        Simulate connectivity without actual network calls. Returns mock data to
        verify configuration resolution. Config files may be read for validation.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Test-ServerConnectivity -PassThru`, for scripting.

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys:
          Available        [bool]   - overall pass/fail
          Mode             [string] - always 'oneview'
          OneViewHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] - DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] - Connected, ModuleLoaded, Error
          Timestamp        [string]   - UTC ISO 8601
        With -Json, a JSON [string] representation of the same data.

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
        [Alias('Env')]
        [ValidateSet('Test', 'Prod')][string] $Environment,
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('Cred')]
        [System.Management.Automation.PSCredential] $Credential,
        [Alias('CfgDir')]
        [string] $ConfigDir = 'configs',
        [Alias('PingMs')]
        [int] $PingTimeoutMs = 3000,
        [int] $Port = 443,
        [Alias('JsonCfg')]
        [switch] $JsonConfig,
        [Alias('Dry')]
        [switch] $DryRun,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )

    $ErrorActionPreference = 'Continue'
    $Mode = 'oneview'
    $reuseActiveSession = $false
    Initialize-Logging -LogFile 'connectivity.log' -CommandName 'Test-ServerConnectivity' -LogName "Test-ServerConnectivity-OneViewHost-$OneViewHost"
    $logger = Get-Logger 'Connectivity'
    # ── Resolve config directory ──────────────────────────────────────────────
    $EffectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
        -MarkerFile 'connection_hosts.json' `
        -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')

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
    # no data loss).  -OneViewHost is therefore required and used VERBATIM.
    if (-not $DryRun) {
        if ($JsonConfig) {
            Write-Warning "-JsonConfig is ignored for live tests. Config files are only read with -DryRun."
        }
        $resolvedHost = $null
        if ($PSBoundParameters.ContainsKey('OneViewHost') -and $OneViewHost) {
            # Host is taken verbatim from the command line - no config/env fallback.
            $resolvedHost = $OneViewHost.Trim()
        } else {
            # No host supplied: this command is a STATUS CHECK of the active
            # OneView connection established by Connect-OneView. It must NEVER
            # prompt - it either reuses the active session or reports that there
            # is no connection. To connect to an appliance, use
            # Connect-OneView -OneViewHost <host> (server name or serial).
            $active = Get-OneViewActiveSession
            if ($active) {
                $resolvedHost = $active.Name
                $reuseActiveSession = $true
            } else {
                $result = @{
                    Available      = $false
                    Mode           = $Mode
                    OneViewHost = $null
                    Environment    = $effectiveEnv
                    NetworkPing    = @{
                        DnsResolved = $false
                        Error       = "No active OneView connection. Connect first with Connect-OneView -OneViewHost <host> (server name or serial), or supply -OneViewHost to test a specific appliance."
                    }
                    AuthConnect    = @{ Connected = $false; Error = "Skipped - no active connection" }
                    Timestamp      = Get-UtcTimestamp
                }
                return (_Emit-ConnectivityResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
        }

        # Guard: never drop the live OneView session by connecting to a different
        # appliance. If an active session exists for a DIFFERENT host, refuse and
        # inform the operator - reconnecting may cause incidents. (Reuse of the
        # same appliance is handled downstream by Connect-OneViewSession.)
        if ($PSBoundParameters.ContainsKey('OneViewHost') -and $OneViewHost) {
            $active = Get-OneViewActiveSession
            if ($active) {
                if ($active.Name -ne $resolvedHost) {
                    # A live session exists for a DIFFERENT appliance - refuse to
                    # switch (reconnecting may cause incidents). Operator must
                    # Disconnect-OneView first.
                    $result = @{
                        Available      = $false
                        Mode           = $Mode
                        OneViewHost = $resolvedHost
                        Environment    = $effectiveEnv
                        NetworkPing    = @{
                            DnsResolved = $false
                            Error       = "Already connected to OneView appliance '$($active.Name)'. Cannot reconnect to '$resolvedHost'."
                        }
                        AuthConnect    = @{
                            Connected = $false
                            Error     = "Skipped - already connected to '$($active.Name)'. Run Disconnect-OneView first to switch to '$resolvedHost'."
                        }
                        Timestamp      = Get-UtcTimestamp
                    }
                    return (_Emit-ConnectivityResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
                } else {
                    # The supplied host matches the active session - reuse it (no
                    # credentials needed). Without this, the live host path below
                    # would force a fresh credential lookup and wrongly report
                    # "no connection" even when already authenticated.
                    $reuseActiveSession = $true
                }
            }
        }

        # Sensible defaults for the live connection (no config file is read).
        $modeCfg = @{ module_name = 'HPEOneView.1000'; use_winrm = $false }
        $useWinRM = $false
        $userEnv  = $null
        $passEnv  = $null
    } else {
        # ── DryRun: config is permitted for validation only ────────────────────
        $resolvedHost = $null

        # 1. Explicit -OneViewHost parameter (verbatim, highest priority)
        if ($PSBoundParameters.ContainsKey('OneViewHost') -and $OneViewHost) {
            $resolvedHost = $OneViewHost.Trim()
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
                    OneViewHost = $null
                    Environment    = $effectiveEnv
                    NetworkPing    = @{ DnsResolved = $false; Error = $errorMsg }
                    AuthConnect    = @{ Connected = $false; Error = "Skipped - no management host" }
                        Timestamp      = Get-UtcTimestamp
                        DryRun         = $true
                    }
                    return (_Emit-ConnectivityResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
                }
        }

        # 3. Reuse the active connection when no host/config supplied. This
        #    command never prompts - it only reports status.
        if (-not $resolvedHost) {
            $active = Get-OneViewActiveSession
            if ($active) {
                $resolvedHost = $active.Name
                $reuseActiveSession = $true
            }
        }

        if (-not $resolvedHost) {
            $errorMsg = "No OneView appliance provided. Use -OneViewHost, -JsonConfig (DryRun), or connect with Connect-OneView -OneViewHost <host>."
            $result = @{
                Available      = $false
                Mode           = $Mode
                OneViewHost = $null
                Environment    = $effectiveEnv
                NetworkPing    = @{ DnsResolved = $false; Error = $errorMsg }
                AuthConnect    = @{ Connected = $false; Error = "Skipped - no management host" }
                Timestamp      = Get-UtcTimestamp
                DryRun         = $true
            }
            return (_Emit-ConnectivityResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
    # LIVE run: credentials are NEVER read from config.  Resolution order mirrors
    # the help text and the bare (no-host) path, so the two are consistent:
    #   1. -Credential (explicit, highest priority)
    #   2. reusing the active OneView session when -OneViewHost matches it
    #   3. ONEVIEW_USER / ONEVIEW_PASSWORD env, then CyberArk (Get-OneViewCredentials)
    #   4. otherwise auth is skipped with a clear message - this command NEVER prompts.
    # DRYRUN: mock credentials - no real secret is required.
    $resolvedUser = $null
    $resolvedSecurePass = $null
    if (-not $DryRun) {
        if ($PSBoundParameters.ContainsKey('Credential') -and $Credential) {
            $resolvedUser = $Credential.UserName
            $resolvedSecurePass = $Credential.Password
        } elseif (-not $reuseActiveSession) {
            # No explicit -Credential and not reusing the active session: resolve the
            # credential from ONEVIEW_USER / ONEVIEW_PASSWORD env or CyberArk. If none
            # are available, leave them empty - Phase 2 then skips auth with a clear
            # message instead of failing the whole connectivity check. The network
            # probe (Phase 1) below ALWAYS runs, so DNS/TCP results are accurate even
            # when authentication cannot be attempted.
            $ovCred = Get-OneViewCredentials
            $resolvedUser = $ovCred[0]
            $resolvedSecurePass = if ($ovCred[1]) {
                ConvertTo-SecureString $ovCred[1] -AsPlainText -Force
            } else { $null }
        }
        # No early return here: a missing credential must not fabricate a failed
        # network result. Phase 1 (DNS/TCP) runs regardless, and Phase 2 skips auth
        # gracefully when no session or credential is available.
    }

    # ── Determine TCP ports to probe (OneView = HTTPS port, default 443) ─────────
    $tcpPorts = @($Port)

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
            OneViewHost = $resolvedHost
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

        $logger.Info("Connectivity test for '$resolvedHost' completed (DryRun): Available=$($mockResult.Available), Mode=$($mockResult.Mode)")
        return (_Emit-ConnectivityResult -Result $mockResult -Json:$Json -PassThru:$PassThru)
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
            $tcpClient = [System.Net.Sockets.TcpClient]::new()
            try {
                $connectTask = $tcpClient.ConnectAsync($resolvedHost, $port)
                $connected = $connectTask.Wait($PingTimeoutMs)
                $sw.Stop()
                if ($connected -and $tcpClient.Connected) {
                    $pingResult.TcpPortOpen = $true
                    $pingResult.Port = $port
                    $pingResult.LatencyMs = [int]$sw.ElapsedMilliseconds
                    break
                }
            } catch {
                $sw.Stop()
            } finally {
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
    if (-not $Credential -and $resolvedUser -and $resolvedSecurePass) {
        $Credential = [System.Management.Automation.PSCredential]::new(
            $resolvedUser,
            $resolvedSecurePass)
    }

    # ══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Authentication Connect (OneView)
    # ══════════════════════════════════════════════════════════════════════════
    $authResult = @{
        Connected        = $false
        Disconnected     = $false
        ModuleLoaded     = $false
        ModuleName       = $null
        ModuleVersion    = $null
        ApplianceVersion = $null
        Error            = $null
    }

    if (-not $pingResult.TcpPortOpen) {
        $authResult.Error = "Skipped - network ping failed"
    } elseif ((-not $resolvedUser -or -not $resolvedSecurePass) -and -not $reuseActiveSession) {
        if ($DryRun) {
            $authResult.Error = "Skipped - credentials not configured (set $userEnv / $passEnv)"
        } else {
            $authResult.Error = "Skipped - credentials not supplied"
        }
    } else {
        $moduleName = Resolve-PinnedOneViewModule

        $connResult = Connect-OneViewSession -Appliance $resolvedHost -Credential $Credential
        $authResult.ModuleLoaded     = $true
        $authResult.ModuleName       = $connResult.ModuleName
        $authResult.ModuleVersion    = $connResult.ModuleVersion
        $authResult.ApplianceVersion = $connResult.ApplianceVersion
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
        OneViewHost = $resolvedHost
        Environment    = $effectiveEnv
        NetworkPing    = $pingResult
        AuthConnect    = $authResult
        Timestamp      = Get-UtcTimestamp
    }

    $logger.Info("Connectivity test for '$resolvedHost' completed: Available=$available " +
        "(DNS=$($pingResult.DnsResolved), TCP=$($pingResult.TcpPortOpen), Auth=$($authResult.Connected))")

    return (_Emit-ConnectivityResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}

# ── Result emission ───────────────────────────────────────────────────────────
function _Emit-ConnectivityResult {
    <#
    .SYNOPSIS
        Emits the connectivity result via the shared, DRY _Publish-Result helper.

    .DESCRIPTION
        Delegates to _Publish-Result so behaviour is identical across all
        commands: a human-readable report by default (no truncated hashtable
        dump on the terminal / in logs), with -Json / -PassThru for data
        consumers. The rich, command-specific _Format-ConnectivityResult view
        is supplied as the -CustomView so the connectivity report keeps its
        familiar layout. Pass -Quiet to suppress the report when the caller
        will handle display itself.
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-ConnectivityResult -Result $r
    }
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
    Write-Host "  Host:       $($Result.OneViewHost)"
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
    if ($ac.ModuleName) {
        $modVer = if ($ac.ModuleVersion) { "  v$($ac.ModuleVersion)" } else { '' }
        Write-Host "    OneView PS module: $($ac.ModuleName)$modVer (module used for all OneView calls on this server)"
    }
    if ($null -ne $ac.ApplianceVersion) {
        Write-Host "    Appliance OneView version: $($ac.ApplianceVersion)"
    }
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

