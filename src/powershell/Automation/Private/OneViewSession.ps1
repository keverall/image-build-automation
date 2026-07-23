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
# Get-OneViewConnectionStatus. To reach the appliance directly we apply an
# in-process bypass (no elevation required):
#   1. WinHTTP default proxy config (WINHTTP_PROXY_INFO) via the WinHTTP API - this
#      is what the HPEOneView module honours for Connect-OVMgmt. Set per-process, so
#      it does not require admin and does not touch machine-wide settings.
#   2. .NET WebRequest / HttpClient proxy bypass lists.
#   3. NO_PROXY / no_proxy environment variables (extra safety for Invoke-RestMethod).
# The session is left connected afterwards so other OneView commands can reuse it.
# =============================================================================

function Set-OneViewProxyBypass {
    <#
    .SYNOPSIS
        Route OneView appliance traffic directly, bypassing the corporate proxy.

    .DESCRIPTION
        Applies a proxy bypass for the named appliance in the CURRENT process so that
        both the HPEOneView module (WinHTTP) and raw Invoke-RestMethod calls reach the
        appliance directly instead of through the corporate web proxy.

        All changes are per-process and require NO elevation:
          - WinHTTP default proxy configuration via the WinHTTP API (WINHTTP_PROXY_INFO),
            which is what Connect-OVMgmt honours.
          - .NET WebRequest / HttpClient proxy bypass lists.
          - NO_PROXY / no_proxy environment variables.

        Best-effort: individual failures are logged via Write-Verbose and are non-fatal.

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

    # 1. WinHTTP default proxy configuration via the WinHTTP API. This is read by the
    #    HPEOneView module for Connect-OVMgmt. Setting it per-process does NOT require
    #    elevation (unlike a system-wide proxy change), and overrides any profile
    #    proxy that is tunnelling the appliance through the corporate proxy.
    try {
        $winHttpType = Add-Type -Namespace 'OneView' -Name 'WinHttpBypass' -MemberDefinition @'
            [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
            public struct WINHTTP_PROXY_INFO {
                public int dwAccessType;
                public string lpszProxy;
                public string lpszProxyBypass;
            }
            [DllImport("winhttp.dll", SetLastError = true, CharSet = CharSet.Auto)]
            public static extern bool WinHttpSetDefaultProxyConfiguration(ref WINHTTP_PROXY_INFO pInfo);
'@ -PassThru -ErrorAction Stop

        # dwAccessType 2 = WINHTTP_ACCESS_TYPE_NAMED_PROXY.
        # lpszProxy "<local>" => no proxy; lpszProxyBypass forces the appliance direct.
        $bypassList = '<local>;' + ($hosts -join ';')
        $info = New-Object 'OneView.WinHttpBypass+WINHTTP_PROXY_INFO'
        $info.dwAccessType = 2
        $info.lpszProxy = '<local>'
        $info.lpszProxyBypass = $bypassList
        $ok = $winHttpType::WinHttpSetDefaultProxyConfiguration([ref] $info)
        if ($ok) {
            Write-Verbose "Set-OneViewProxyBypass: WinHTTP bypass applied (bypass=$bypassList)"
        } else {
            Write-Verbose "Set-OneViewProxyBypass: WinHttpSetDefaultProxyConfiguration returned false (last error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
        }
    } catch {
        Write-Verbose "Set-OneViewProxyBypass: could not configure WinHTTP via API: $_"
    }

    # 2. .NET Framework / Windows PowerShell web proxy and .NET Core HttpClient proxy.
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

    # 3. NO_PROXY / no_proxy (extra safety for .NET / Invoke-RestMethod).
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
        session, reuses an existing healthy active session when present, otherwise
        clears any stale/broken session and performs Connect-OVMgmt. The session is
        intentionally left connected afterwards so that subsequent OneView commands
        (Get-OneViewServerList, etc.) can reuse it.

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
    if ($null -ne $active -and $active.Connected -eq $true) {
        return $active
    }

    # Clear any stale/failed session so a fresh Connect-OVMgmt is attempted.
    if ($global:ConnectedSessions) {
        try { Disconnect-OVMgmt -ErrorAction SilentlyContinue } catch { }
    }

    Set-OneViewProxyBypass -ApplianceHost $Appliance
    return (Connect-OVMgmt -Hostname $Appliance -Credential $Credential -ErrorAction Stop)
}
