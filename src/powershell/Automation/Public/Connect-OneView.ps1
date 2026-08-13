#
# Connect-OneView.ps1 - Establish a persistent HPE OneView appliance session
#

function Connect-OneView {
    <#
    .SYNOPSIS
        Connect to an HPE OneView appliance and establish a persistent session.

    .DESCRIPTION
        This is a connection-focused alias for Test-ServerConnectivity.  It
        validates network reachability and performs authentication in a single
        step, leaving an active OneView session available for subsequent
        commands (Get-OneViewServerList, Get-OneViewConnectionStatus, etc.).

        On a live run the appliance host is taken verbatim from -OneViewHost
        and credentials are entered interactively at the prompt.  Config files
        are never read during a live run.

        The OneView session persists for the remainder of the PowerShell
        session.  Use Disconnect-OneView to explicitly close it.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP address to connect to (server name
        or serial).  Required for a live (non-DryRun) connection.  Used
        verbatim - no config/env fallback.

    .PARAMETER DryRun
        Validate host resolution only - no authentication is attempted and
        no real connection is made.  Host is resolved from
        connection_hosts.json (Test environment by default).  Safe for
        testing code without touching an appliance.  Remove -DryRun when you
        are ready to connect and make changes.

    .EXAMPLE
        Connect-OneView -OneViewHost oneview.example.com

        Connect to the OneView appliance oneview.example.com.  Credentials are
        prompted for interactively.

    .EXAMPLE
        Connect-OneView -DryRun

        Validate host resolution from config without connecting or making
        any changes.  Use this to test code safely.

    .OUTPUTS
        [hashtable] - a connection result with keys:
            Available        [bool]   - connectivity and auth both succeeded
            OneViewHost   [string] - the appliance contacted
            AuthConnect      [hashtable] - authentication details
            NetworkPing      [hashtable] - network probe results
            Message          [string] - human-readable status

    .NOTES
        This command is the counterpart to Disconnect-OneView.  Internally it
        delegates to Test-ServerConnectivity, so all network validation and
        session-establishment logic is shared.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('OVHost','MgmtHost')]
        [string] $OneViewHost,

    [Alias('Dry')]
    [switch] $DryRun
)

# Guard against a stray double-dash flag (e.g. `--DryRun`) being swallowed as
# the management host. In PowerShell `--` means "end of parameters", so
# `Connect-OneView --DryRun` binds "DryRun" to -OneViewHost and never sets
# the actual -DryRun switch - which then prompts for credentials against a
# bogus host. Reuse the shared helper (single source of truth) instead of
# inlining the check in every command.
Assert-ParameterNotFlag -Parameters $PSBoundParameters

# Common logging: each command writes to its own isolated log under
# generated/logs/commands/Connect-OneView/, consistent with the other commands.
Initialize-Logging -CommandName 'Connect-OneView' -LogName "Connect-OneView-Host-$($OneViewHost ?? 'unspecified')"
$logger = Get-Logger 'Connect-OneView'
$logger.Info("Connect-OneView invoked: OneViewHost='$OneViewHost' DryRun=$DryRun")
# ── -DryRun is a CRITICAL-priority, first-checked guard ─────────────────────
# Per project convention, -DryRun is ALWAYS mocking: it never connects and must
# IGNORE every other parameter's live behaviour (no host prompt, no credential
# prompt, no session touch). Check it first, before any host/credential handling,
# so a -DryRun invocation can never reach an interactive prompt regardless of
# parameter binding order (-OneViewHost/-Credential have no live effect).
if ($DryRun) {
    $targetForMsg = if ($OneViewHost) { " to '$OneViewHost'" } else { '' }
    Write-Host ""; $logger.Info('')
    $n1 = "NOTE: -DryRun was supplied. No real connection will be made$targetForMsg."
    $logger.Info($n1); Write-Host $n1 -ForegroundColor Cyan
    $n2 = "      Host reachability is validated against mock/config data only (HPE OneView module mocked)."
    $logger.Info($n2); Write-Host $n2 -ForegroundColor Cyan
    $n3 = "      Remove -DryRun to connect for real (you will be prompted for credentials)."
    $logger.Info($n3); Write-Host $n3 -ForegroundColor Cyan
}

# Connect-OneView is THE connect command: it establishes (and persists) an
# authenticated OneView session. Test-ServerConnectivity is now a STATUS CHECK
# that never prompts, so the connect-time prompting for the appliance host and
# credentials lives here.
$params = @{
    DryRun        = $DryRun
    PingTimeoutMs = 3000
}

if ($OneViewHost) {
    $params['OneViewHost'] = $OneViewHost
} elseif ($DryRun) {
    # DryRun without an explicit host: resolve the default appliance from
    # connection_hosts.json so validation is non-interactive. Test-ServerConnectivity
    # reads config only with -DryRun, so this stays safe and compliant.
    $params['JsonConfig'] = $true
} else {
    # Live connect with no host named: prompt for the appliance (interactive
    # only - in automated mode / non-TTY this must fail fast rather than hang).
    $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
    $isInteractive = [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected -and -not $isAutomated
    if ($isInteractive) {
        Write-Host "Enter OneView appliance host to connect to (or press Enter to cancel): " -ForegroundColor Yellow -NoNewline
        $hostInput = Read-Host
        if ($hostInput) { $OneViewHost = $hostInput.Trim(); $params['OneViewHost'] = $OneViewHost }
    }
    if (-not $OneViewHost) {
        Write-Warning "Connect-OneView requires -OneViewHost (or run with -DryRun for config validation). No connection made."
        return
    }
}

# ── Guard: never drop/replace an existing live OneView session ──────────────
# Reconnecting (to the same or a different appliance) may disrupt in-flight
# operations on the live session. If we are already connected we reuse the
# active session and report it. A connection to a DIFFERENT appliance is
# refused - run Disconnect-OneView first to switch. (-DryRun is exempt: it
# performs no real connection and so cannot drop the live session.)
$active = Get-OneViewActiveSession
if ($active -and -not $DryRun) {
    if ($OneViewHost -and $active.Name -ne $OneViewHost) {
        Write-Warning "Already connected to OneView appliance '$($active.Name)'. Cannot reconnect to '$OneViewHost' - this would drop the live session. Run Disconnect-OneView first to switch appliances."
        return @{
            Available      = $false
            Mode           = 'oneview'
            OneViewHost = $OneViewHost
            Environment    = $(if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } else { 'Prod' })
            NetworkPing    = @{ DnsResolved = $false; Error = "Already connected to OneView appliance '$($active.Name)'. Cannot reconnect to '$OneViewHost'." }
            AuthConnect    = @{ Connected = $false; Error = "Skipped - already connected to '$($active.Name)'. Run Disconnect-OneView first to switch to '$OneViewHost'." }
            Timestamp      = Get-UtcTimestamp
            Message        = "Already connected to OneView appliance '$($active.Name)'. Cannot reconnect to '$OneViewHost'."
        }
    }
    # Same appliance (or no host supplied): reuse the live session, do not reconnect.
    Write-Verbose "Already connected to OneView appliance '$($active.Name)'. Reusing the existing session (not reconnecting)."
    $statusParams = @{ PingTimeoutMs = 3000 }
    if ($OneViewHost) { $statusParams['OneViewHost'] = $OneViewHost }
    $result = Test-ServerConnectivity @statusParams
    $result.Message = "Already connected to OneView appliance '$($active.Name)'."
    return $result
}

# ── -DryRun is a CRITICAL-priority, first-checked guard ─────────────────────
# Per project convention, -DryRun is ALWAYS mocking: it never connects and must
# IGNORE every other parameter's live behaviour (no host prompt, no credential
# prompt, no session touch). Check it first, before any host/credential handling,
# so a -DryRun invocation can never reach an interactive prompt regardless of
# parameter binding order (-OneViewHost/-Live/-Credential have no effect).
if ($DryRun) {
    $params['DryRun'] = $true
    # (host resolution above already fed -OneViewHost through verbatim, or
    #  enabled JsonConfig for the no-host case - both are read-only/mock-safe.)
} else {
    # Resolve credentials for the live connection. Connect-OneView is the connect
    # command, so prompting for the password here is expected and is the
    # operator's explicit authorisation to connect to the named appliance. It
    # only prompts when interactive and no credential was supplied; in automated
    # mode a -Credential or ONEVIEW_USER / ONEVIEW_PASSWORD must be provided.
    if ($OneViewHost -and -not ($PSBoundParameters.ContainsKey('Credential') -and $Credential)) {
        $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
        $isInteractive = [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected -and -not $isAutomated
        if ($isInteractive) {
            Write-Host "Enter OneView username for '$OneViewHost': " -ForegroundColor Yellow -NoNewline
            $u = Read-Host
            if ($u) {
                $sp = Read-Host "Enter OneView password for '$OneViewHost': " -AsSecureString
                $Credential = [System.Management.Automation.PSCredential]::new($u, $sp)
                $params['Credential'] = $Credential
            }
        }
        # If no credential is available after the interactive attempt (or in
        # automated mode), Test-ServerConnectivity simply skips auth with a clear
        # message.
    } elseif ($Credential) {
        $params['Credential'] = $Credential
    }
}

$result = Test-ServerConnectivity @params

    # Surface a clean message for the connection-focused use case.
    if ($result.Available) {
        $result.Message = "Connected to OneView appliance '$OneViewHost'."
    } elseif ($DryRun) {
        $result.Message = "Dry-run validation completed (no live connection made)."
    } else {
        $detail = if ($result.AuthConnect.Error) {
            $result.AuthConnect.Error
        } elseif ($result.NetworkPing.Error) {
            $result.NetworkPing.Error
        } else {
            'Unknown failure'
        }
        $result.Message = "Connection to '$OneViewHost' failed: $detail"
    }

    $logger.Info("Connect-OneView result: Available=$($result.Available) Message='$($result.Message)'")
    return $result
}

