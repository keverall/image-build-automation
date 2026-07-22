#
# Private/OneViewSession.ps1 - Shared HPE OneView session helpers
#
# Centralises the logic for detecting and describing an active HPE OneView
# module session (Connect-OVMgmt => $global:ConnectedSessions). Previously
# duplicated across Get-OneViewConnectionStatus, Get-OneViewServerList and
# Disconnect-OneView. Keeping it in one place guarantees all OneView commands
# agree on what "connected" means and use the same user-facing messages.
#

# Standard message returned when no active OneView session exists and no
# explicit -OneViewHost was supplied. Shared so callers stay consistent.
$script:ONEVIEW_NO_SESSION_MSG = "No active OneView session. Use Connect-OVMgmt to connect, or supply -OneViewHost."

function Get-OneViewActiveSession {
    <#
    .SYNOPSIS
        Return the first active HPE OneView module session, if present.

    .DESCRIPTION
        Inspects the global $global:ConnectedSessions collection populated by the
        HPEOneView module's Connect-OVMgmt. Returns the first session whose
        Connected flag is true, or $null when none is active. This is the single
        source of truth used by all OneView commands that reuse an existing
        session instead of re-authenticating.

    .OUTPUTS
        [PSObject] The active session object, or $null.
    #>
    [CmdletBinding()]
    param()

    if (-not $global:ConnectedSessions) {
        return $null
    }

    return $global:ConnectedSessions |
        Where-Object { $_.Connected -eq $true } |
        Select-Object -First 1
}

function Test-OneViewSessionActive {
    <#
    .SYNOPSIS
        Boolean test for an active HPE OneView module session.

    .DESCRIPTION
        Thin wrapper around Get-OneViewActiveSession that returns $true when a
        connected session exists. Useful for guard clauses and messaging.

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    param()

    return ($null -ne (Get-OneViewActiveSession))
}

function Set-OneViewProxyBypass {
    <#
    .SYNOPSIS
        Ensure a OneView appliance is reached directly, bypassing any web proxy.

    .DESCRIPTION
        Internal appliances must be contacted directly, never through the
        corporate web proxy. When a proxy is configured (e.g. via WinHTTP/IE
        or HTTP_PROXY), Connect-OVMgmt and the downstream OneView REST calls
        are tunnelled through it and fail with proxy errors (e.g. HTTP 504).

        This adds the appliance host - and its resolved FQDN / IP addresses -
        to the .NET web-proxy bypass list and to the no_proxy environment
        variable, so connections to that appliance go straight through while
        all other (external) traffic still uses the proxy.

        Safe to call repeatedly; existing bypass entries are preserved.

    .PARAMETER ApplianceHost
        The OneView appliance host (short name, FQDN or IP) to exclude from
        the proxy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ApplianceHost
    )

    $hosts = [System.Collections.Generic.List[string]]@($ApplianceHost)

    # Resolve the host to its FQDN and IP addresses so the bypass matches
    # however Connect-OVMgmt ultimately addresses the appliance.
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ApplianceHost)
        if ($entry.HostName -and $entry.HostName -ne $Host) { $hosts.Add($entry.HostName) }
        foreach ($addr in $entry.AddressList) {
            if (-not $hosts.Contains($addr.IPAddressToString)) { $hosts.Add($addr.IPAddressToString) }
        }
    } catch {
        # DNS failures are non-fatal - the raw host is still added.
    }

    # .NET Framework / Windows PowerShell web proxy (used by Connect-OVMgmt).
    try {
        $proxy = [System.Net.WebRequest]::DefaultWebProxy
        if ($null -ne $proxy) {
            $proxy.BypassProxyOnLocal = $true
            $bypass = [System.Collections.Generic.List[string]]@()
            if ($proxy.BypassList) {
                foreach ($b in $proxy.BypassList) { if ($b) { $bypass.Add($b) } }
            }
            foreach ($h in $hosts) {
                if (-not $bypass.Contains($h)) { $bypass.Add($h) }
            }
            $proxy.BypassList = $bypass.ToArray()
            [System.Net.WebRequest]::DefaultWebProxy = $proxy
        }
    } catch {
        Write-Verbose "Set-OneViewProxyBypass: could not configure WebRequest proxy: $_"
    }

    # .NET Core / PowerShell 7 HttpClient proxy (where applicable).
    try {
        $p7 = [System.Net.Http.HttpClient]::DefaultProxy
        if ($null -ne $p7) {
            $p7.BypassProxyOnLocal = $true
            foreach ($h in $hosts) {
                if (-not $p7.BypassList.Contains($h)) { $p7.BypassList.Add($h) }
            }
        }
    } catch {
        Write-Verbose "Set-OneViewProxyBypass: could not configure HttpClient proxy: $_"
    }

    # no_proxy / NO_PROXY environment variables (honoured by some modules).
    try {
        $existing = [System.Environment]::GetEnvironmentVariable('no_proxy')
        $set = [System.Collections.Generic.List[string]]@()
        if ($existing) {
            foreach ($e in ($existing -split ',')) { if ($e) { $set.Add($e) } }
        }
        foreach ($h in $hosts) {
            if (-not $set.Contains($h)) { $set.Add($h) }
        }
        $joined = $set -join ','
        [System.Environment]::SetEnvironmentVariable('no_proxy', $joined)
        [System.Environment]::SetEnvironmentVariable('NO_PROXY', $joined)
    } catch {
        Write-Verbose "Set-OneViewProxyBypass: could not set no_proxy: $_"
    }
}
