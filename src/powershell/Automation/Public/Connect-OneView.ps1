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

        On a live run the appliance host is taken verbatim from -ManagementHost
        and credentials are entered interactively at the prompt.  Config files
        are never read during a live run.

        The OneView session persists for the remainder of the PowerShell
        session.  Use Disconnect-OneView to explicitly close it.

    .PARAMETER ManagementHost
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
        Connect-OneView -ManagementHost va-oneviewt-01

        Connect to the OneView appliance va-oneviewt-01.  Credentials are
        prompted for interactively.

    .EXAMPLE
        Connect-OneView -DryRun

        Validate host resolution from config without connecting or making
        any changes.  Use this to test code safely.

    .OUTPUTS
        [hashtable] - a connection result with keys:
            Available        [bool]   - connectivity and auth both succeeded
            ManagementHost   [string] - the appliance contacted
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
        [Alias('MgmtHost')]
        [string] $ManagementHost,

    [Alias('Dry')]
    [switch] $DryRun
)

# Guard against a stray double-dash flag (e.g. `--DryRun`) being swallowed as
# the management host. In PowerShell `--` means "end of parameters", so
# `Connect-OneView --DryRun` binds "DryRun" to -ManagementHost and never sets
# the actual -DryRun switch - which then prompts for credentials against a
# bogus host. Reuse the shared helper (single source of truth) instead of
# inlining the check in every command.
Assert-ParameterNotFlag -Parameters $PSBoundParameters

# Delegate to Test-ServerConnectivity, forwarding only the parameters
# Connect-OneView exposes.  All network validation, credential resolution,
# and session establishment happens inside Test-ServerConnectivity.
$params = @{
    DryRun         = $DryRun
    PingTimeoutMs  = 3000
}
if ($ManagementHost) {
    $params['ManagementHost'] = $ManagementHost
} elseif ($DryRun) {
    # DryRun without an explicit host: resolve the default appliance from
    # connection_hosts.json so validation is non-interactive. This matches the
    # command's documented behaviour. Test-ServerConnectivity reads config only
    # with -DryRun, so this stays safe and compliant.
    $params['JsonConfig'] = $true
}

$result = Test-ServerConnectivity @params

    # Surface a clean message for the connection-focused use case.
    if ($result.Available) {
        $result.Message = "Connected to OneView appliance '$ManagementHost'."
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
        $result.Message = "Connection to '$ManagementHost' failed: $detail"
    }

    return $result
}
