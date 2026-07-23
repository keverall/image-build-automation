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

# =============================================================================
# Proxy bypass for the internal OneView appliance.
#
# The corporate web proxy (e.g. webcorp.prd.aib.pri:8082) intercepts traffic to
# the internal OneView appliance and breaks both Connect-OVMgmt (HPE module, which
# uses WinHTTP) and the raw Invoke-RestMethod calls made by Get-OneViewServerList /
# Get-OneViewConnectionStatus. To reach the appliance directly we:
#   1. reset the WinHTTP proxy and add the appliance to its bypass list (netsh),
#   2. set NO_PROXY / no_proxy so .NET / Invoke-RestMethod skip the proxy too.
# The session is left connected afterwards so other OneView commands can reuse it.
# =============================================================================

function Set-OneViewProxyBypass {
    <#
    .SYNOPSIS
        Route OneView appliance traffic directly, bypassing the corporate proxy.

    .DESCRIPTION
        Applies a proxy bypass for the named appliance in the CURRENT process/session
        so that both the HPEOneView module (WinHTTP) and raw Invoke-RestMethod calls
        reach the appliance directly instead of through the corporate web proxy.

        Steps:
          - netsh winhttp reset proxy + a bypass list containing the appliance
            (covers Connect-OVMgmt, which honours WinHTTP proxy settings).
          - Set NO_PROXY / no_proxy environment variables (covers .NET /
            Invoke-RestMethod used by Get-OneViewServerList / Get-OneViewConnectionStatus).

        Best-effort: failures (e.g. netsh needs elevation) are logged but non-fatal.

    .PARAMETER ApplianceHost
        The OneView appliance host (short name, FQDN or IP) to exclude from the proxy.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal proxy-bypass helper; best-effort and non-interactive by design.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'Each bypass attempt is independent and best-effort; failures are logged via Write-Verbose and must not abort the connection.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ApplianceHost
    )

    $hosts = [System.Collections.Generic.List[string]]@($ApplianceHost)
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ApplianceHost)
        if ($entry.HostName -and $entry.HostName -ne $ApplianceHost) { $hosts.Add($entry.HostName) }
        foreach ($addr in $entry.AddressList) {
            if (-not $hosts.Contains($addr.IPAddressToString)) { $hosts.Add($addr.IPAddressToString) }
        }
    } catch {
        # DNS failures are non-fatal - the raw host is still added.
    }

        # 1. WinHTTP proxy + bypass list (used by the HPEOneView module / Connect-OVMgmt).
        #    Best-effort: requires elevation on some hosts; failures are non-fatal.
        try {
            if (Get-Command 'netsh.exe' -ErrorAction SilentlyContinue) {
                $bypassArg = '<local>;"' + ($hosts -join ';') + '"'
                $null = & netsh.exe winhttp set proxy proxy-server="<local>" bypass-list=$bypassArg 2>$null
                Write-Verbose "Set-OneViewProxyBypass: configured WinHTTP bypass for $($hosts -join ', ')"
            }
        } catch {
            Write-Verbose "Set-OneViewProxyBypass: could not set WinHTTP proxy: $_"
        }

        # 1b. .NET Framework / Windows PowerShell web proxy (also honoured by some
        #     module code paths). Build an explicit proxy so the bypass applies even
        #     when DefaultWebProxy is auto-detected (null).
        try {
            $proxyAddress = $null
            $current = [System.Net.WebRequest]::DefaultWebProxy
            if ($null -ne $current) {
                $probe = $current.GetProxy([uri]'https://outlook.office365.com')
                if ($probe -and $probe.AbsoluteUri -notmatch 'office365\.com') {
                    $proxyAddress = $probe.AbsoluteUri
                }
            }
            if (-not $proxyAddress) {
                $envProxy = [System.Environment]::GetEnvironmentVariable('HTTPS_PROXY') ??
                            [System.Environment]::GetEnvironmentVariable('https_proxy') ??
                            [System.Environment]::GetEnvironmentVariable('HTTP_PROXY')  ??
                            [System.Environment]::GetEnvironmentVariable('http_proxy')
                $proxyAddress = $envProxy
            }
            if ($proxyAddress) {
                $proxy = [System.Net.WebProxy]::new($proxyAddress, $true)
            } else {
                $proxy = [System.Net.WebProxy]::new()
                $proxy.UseDefaultCredentials = $true
            }
            $proxy.BypassProxyOnLocal = $true
            $proxy.BypassList = $hosts.ToArray()
            [System.Net.WebRequest]::DefaultWebProxy = $proxy

            # .NET Core / PowerShell 7 HttpClient proxy (used by raw Invoke-RestMethod).
            if ($proxyAddress) {
                $p7Address = if ($proxyAddress -match '^https?://') { $proxyAddress } else { "http://$proxyAddress" }
                $p7 = [System.Net.WebProxy]::new($p7Address, $true)
            } else {
                $p7 = [System.Net.WebProxy]::new()
                $p7.UseDefaultCredentials = $true
            }
            $p7.BypassProxyOnLocal = $true
            foreach ($h in $hosts) {
                if (-not $p7.BypassList.Contains($h)) { $p7.BypassList.Add($h) }
            }
            [System.Net.Http.HttpClient]::DefaultProxy = $p7
        } catch {
            Write-Verbose "Set-OneViewProxyBypass: could not configure .NET proxy: $_"
        }

    # 2. NO_PROXY / no_proxy (used by .NET / Invoke-RestMethod).
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

function Connect-OneViewSession {
    <#
    .SYNOPSIS
        Establish (and keep) a OneView session, bypassing the corporate proxy.

    .DESCRIPTION
        Applies the appliance proxy bypass (Set-OneViewProxyBypass) in the current
        session, reuses an existing active session when present, otherwise performs
        Connect-OVMgmt. The session is intentionally left connected afterwards so
        that subsequent OneView commands (Get-OneViewServerList, etc.) can reuse it.

    .PARAMETER Appliance
        The OneView appliance host (short name, FQDN or IP).

    .PARAMETER Credential
        PSCredential used to authenticate to the appliance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Appliance,
        [Parameter(Mandatory)][System.Management.Automation.PSCredential] $Credential
    )

    $active = Get-OneViewActiveSession
    if ($null -ne $active) {
        return $active
    }

    Set-OneViewProxyBypass -ApplianceHost $Appliance
    return (Connect-OVMgmt -Hostname $Appliance -Credential $Credential -ErrorAction Stop)
}
