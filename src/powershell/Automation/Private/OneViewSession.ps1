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

function Connect-OneViewSession {
    <#
    .SYNOPSIS
        Establish or reuse an HPE OneView management session.

    .DESCRIPTION
        Shared connection helper used by all OneView automation commands.
        1. Reuses an existing active session (same appliance) when present.
        2. Applies proxy bypass for the appliance (WinHTTP + .NET + NO_PROXY).
        3. Imports the HPEOneView PowerShell module.
        4. Calls Connect-OVMgmt to establish a persistent session.
        The session remains active for subsequent commands.

    .PARAMETER Appliance
        OneView appliance hostname or IP.

    .PARAMETER Credential
        PSCredential for authentication. If omitted, resolves from
        $env:ONEVIEW_USER / $env:ONEVIEW_PASSWORD or CyberArk.

    .PARAMETER ModuleName
        HPEOneView module name (default: HPEOneView.1000).

    .PARAMETER Port
        HTTPS port (default: 443).

    .OUTPUTS
        [hashtable] Connected, ReusedSession, Appliance, SessionId, ModuleName, Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Required to build PSCredential from runtime-resolved credentials for Connect-OVMgmt; password is never persisted or logged.')]
    param(
        [Parameter(Mandatory)][string] $Appliance,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $ModuleName = 'HPEOneView.1000',
        [int] $Port = 443
    )

    $result = @{
        Connected       = $false
        ReusedSession   = $false
        Appliance       = $Appliance
        SessionId       = $null
        ModuleName      = $ModuleName
        Error           = $null
    }

    $existing = Get-OneViewActiveSession
    if ($existing -and $existing.Name -eq $Appliance) {
        $result.Connected = $true
        $result.ReusedSession = $true
        $result.SessionId = $existing.SessionID
        return $result
    }

    if (-not $Credential) {
        $ovCred = Get-OneViewCredentials
        $user = $ovCred[0]
        $pass = $ovCred[1]
        if (-not $user -or -not $pass) {
            $result.Error = 'No credentials supplied and ONEVIEW_USER/ONEVIEW_PASSWORD not configured'
            return $result
        }
        $Credential = [System.Management.Automation.PSCredential]::new(
            $user,
            (ConvertTo-SecureString $pass -AsPlainText -Force))
    }

    try {
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy
        [System.Net.WebRequest]::DefaultWebProxy.BypassProxyOnLocal = $true
        $noProxy = [System.Environment]::GetEnvironmentVariable('NO_PROXY')
        if ($noProxy) {
            if ($noProxy -notmatch [regex]::Escape($Appliance)) {
                [System.Environment]::SetEnvironmentVariable('NO_PROXY', "$noProxy,$Appliance")
            }
        } else {
            [System.Environment]::SetEnvironmentVariable('NO_PROXY', $Appliance)
        }
    } catch { }

    try {
        Import-Module $ModuleName -ErrorAction Stop
    } catch {
        $result.Error = "Failed to import $ModuleName`: $($_.Exception.Message)"
        return $result
    }

    try {
        Connect-OVMgmt -Appliance $Appliance -Credential $Credential -ErrorAction Stop
        $session = Get-OneViewActiveSession
        if ($session) {
            $result.Connected = $true
            $result.SessionId = $session.SessionID
        } else {
            $result.Error = 'Connect-OVMgmt succeeded but no active session found'
        }
    } catch {
        $result.Error = "Connect-OVMgmt failed: $($_.Exception.Message)"
    }

    return $result
}
