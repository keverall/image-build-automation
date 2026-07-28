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
$script:ONEVIEW_NO_SESSION_MSG = "No active OneView session. Use Test-ServerConnectivity -ManagementHost <oneview-appliance-host> to connect, or supply -OneViewHost."

# Module-scoped mirror of the active OneView session. The HPEOneView module holds
# the connection itself (and may report "already connected"), but its session object
# does not always expose a $_.Connected flag our strict filter recognises (observed
# with HPEOneView.1000). Capturing the object Connect-OVMgmt returns lets us detect
# and reuse the session reliably regardless of how the module exposes its state.
$script:ActiveOneViewSession = $null

# The ONLY HPE OneView PowerShell library version supported by this automation.
# All other HPEOneView.* / legacy HPOneView.* versions are rejected at import time.
$script:REQUIRED_ONEVIEW_MODULE = 'HPEOneView.1000'

function Get-OneViewModuleStatus {
    <#
    .SYNOPSIS
        Report which HPEOneView PowerShell library versions are loaded and installed.

    .DESCRIPTION
        Inspects the current session (Get-Module) and PSModulePath
        (Get-Module -ListAvailable) for HPEOneView.* and legacy HPOneView.*
        libraries. Used to enforce the HPEOneView.1000-only policy and to power
        Get-OneViewVersion diagnostics.

    .OUTPUTS
        [hashtable] RequiredModule, LoadedModules, InstalledModules (name/version/path),
        Compliant (bool: no non-1000 module loaded), NonCompliantLoaded, NonCompliantInstalled.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $loaded = @(Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue)
    $installed = @(Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue)

    $describe = { param($m) @{ Name = $m.Name; Version = "$($m.Version)"; Path = $m.Path } }

    $nonCompliantLoaded    = @($loaded    | Where-Object { $_.Name -ne $script:REQUIRED_ONEVIEW_MODULE })
    $nonCompliantInstalled = @($installed | Where-Object { $_.Name -ne $script:REQUIRED_ONEVIEW_MODULE })

    return @{
        RequiredModule        = $script:REQUIRED_ONEVIEW_MODULE
        LoadedModules         = @($loaded    | ForEach-Object { & $describe $_ })
        InstalledModules      = @($installed | ForEach-Object { & $describe $_ })
        Compliant             = ($nonCompliantLoaded.Count -eq 0)
        NonCompliantLoaded    = @($nonCompliantLoaded    | ForEach-Object { $_.Name })
        NonCompliantInstalled = @($nonCompliantInstalled | ForEach-Object { $_.Name } | Sort-Object -Unique)
    }
}

function Assert-OneViewModuleCompliance {
    <#
    .SYNOPSIS
        Enforce that only HPEOneView.1000 is (or will be) used in this session.

    .DESCRIPTION
        Returns a hashtable with Ok=$true when no other HPEOneView.*/HPOneView.*
        module is loaded. When a non-compliant module is already loaded, returns
        Ok=$false with a remediation message (the offending module holds cmdlet
        names like Connect-OVMgmt, so importing HPEOneView.1000 alongside it is
        unsafe). Also warns (non-fatal) when other versions are merely installed
        on PSModulePath so operators can uninstall them.

    .PARAMETER ModuleName
        The module the caller intends to import. Anything other than
        HPEOneView.1000 fails the check.

    .OUTPUTS
        [hashtable] Ok, Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $ModuleName = $script:REQUIRED_ONEVIEW_MODULE
    )

    if ($ModuleName -ne $script:REQUIRED_ONEVIEW_MODULE) {
        return @{
            Ok    = $false
            Error = "OneView module '$ModuleName' is not permitted. Only '$($script:REQUIRED_ONEVIEW_MODULE)' (OneView 10.x library) is supported by this automation. Update oneview_config.json / the -ModuleName argument."
        }
    }

    $status = Get-OneViewModuleStatus

    if ($status.NonCompliantLoaded.Count -gt 0) {
        $names = $status.NonCompliantLoaded -join ', '
        return @{
            Ok    = $false
            Error = "Unsupported HPE OneView module(s) already loaded in this session: $names. Only '$($script:REQUIRED_ONEVIEW_MODULE)' is supported. Run: Remove-Module $names -Force; then Uninstall-Module (or delete the module folder) so it cannot auto-load, and retry."
        }
    }

    if ($status.NonCompliantInstalled.Count -gt 0) {
        $names = $status.NonCompliantInstalled -join ', '
        Write-Warning "Unsupported HPE OneView module version(s) found on PSModulePath: $names. Only '$($script:REQUIRED_ONEVIEW_MODULE)' is supported - uninstall/delete the others to avoid accidental auto-loading (see Get-OneViewVersion for their paths)."
    }

    return @{ Ok = $true; Error = $null }
}

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

    $candidates = @()
    if ($global:ConnectedSessions) {
        $candidates += $global:ConnectedSessions
    }
    if ($script:ActiveOneViewSession) {
        $candidates += $script:ActiveOneViewSession
    }
    if ($candidates.Count -eq 0) {
        return $null
    }

    # Prefer a session the module reports as connected.
    $connected = $candidates |
        Where-Object { $_.Connected -eq $true -or $_.Connected -eq 'True' } |
        Select-Object -First 1
    if ($connected) {
        return $connected
    }

    # Fallback: a session we captured directly from Connect-OVMgmt that carries a
    # SessionID, even when the module's Connected flag is not set the way we expect
    # (e.g. HPEOneView.1000 holds the session but a strict $_.Connected -eq $true
    # filter misses it). We still require a SessionID so we never return a stale,
    # empty connection placeholder.
    $bySessionId = $candidates |
        Where-Object { $null -ne $_.SessionID } |
        Select-Object -First 1
    return $bySessionId
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
        2. Connects directly to the appliance (no proxy handling).
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
        [string] $ModuleName = 'HPEOneView.1000'
    )

    $result = @{
        Connected       = $false
        ReusedSession   = $false
        Appliance       = $Appliance
        SessionId       = $null
        ModuleName      = $ModuleName
        Error           = $null
    }

    # HPEOneView.1000-only policy: reject any other library version before we
    # touch the session or import anything.
    $moduleCheck = Assert-OneViewModuleCompliance -ModuleName $ModuleName
    if (-not $moduleCheck.Ok) {
        $result.Error = $moduleCheck.Error
        return $result
    }

    $existing = Get-OneViewActiveSession
    if ($existing -and $existing.Name -eq $Appliance) {
        $result.Connected = $true
        $result.ReusedSession = $true
        $result.SessionId = $existing.SessionID
        $script:ActiveOneViewSession = $existing
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
        Import-Module $ModuleName -ErrorAction Stop
    } catch {
        $result.Error = "Failed to import $ModuleName`: $($_.Exception.Message)"
        return $result
    }

    try {
        $ovSession = Connect-OVMgmt -Appliance $Appliance -Credential $Credential -ErrorAction Stop
        # Capture the session object Connect-OVMgmt returns and fall back to the
        # module's global collection. This is the reliable source of truth when the
        # module's Connected flag is not set the way Get-OneViewActiveSession expects.
        $session = if ($ovSession) { @($ovSession)[0] } else { Get-OneViewActiveSession }
        if ($session) {
            $result.Connected = $true
            $result.SessionId = $session.SessionID
            $script:ActiveOneViewSession = $session
        } else {
            $result.Error = 'Connect-OVMgmt succeeded but no active session found'
        }
    } catch {
        $result.Error = "Connect-OVMgmt failed: $($_.Exception.Message)"
    }

    return $result
}

function Resolve-OneViewSession {
    <#
    .SYNOPSIS
        Shared entry point that guarantees an active HPE OneView session for the
        OneView data commands, reusing one when present and otherwise connecting
        via Connect-OneViewSession. Prompts interactively for the appliance host
        and credentials, exactly like Test-ServerConnectivity, when they are not
        supplied. NEVER disconnects - only Disconnect-OneView does that.

    .DESCRIPTION
        Resolution order:
          0. Existing connection ALWAYS wins:
             - If any OneView session is already connected it is reused and the
               function NEVER reconnects - dropping a live session could cause
               incidents. This takes priority even over an explicitly supplied
               -OneViewHost; when the requested host differs from the connected
               appliance the operator is warned to Disconnect-OneView first if they
               want to switch. The connected appliance name is returned in Message.
          1. Host resolution (only when nothing is connected):
             - If -OneViewHost is supplied it is used verbatim; otherwise the
               operator is prompted. If no host is supplied and nothing is
               connected, a descriptive error is returned.
          2. Credential resolution (only when connecting):
             - -Credential, then -OneViewUser/-OneViewPassword, then an interactive
               prompt, then the env/CyberArk resolver for non-interactive automation.
          3. Connect:
             - Connect-OneViewSession (the sole caller of Connect-OVMgmt)
               establishes a persistent session that later commands reuse.

        The session persists until it times out, the PowerShell session closes,
        or Disconnect-OneView is called.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP. Ignored while a session is already
        connected. If omitted and nothing is connected, the operator is prompted.

    .PARAMETER Credential
        PSCredential for authentication. Preferred, non-interactive entry point.

    .PARAMETER OneViewUser
        OneView username (used with -OneViewPassword when -Credential is absent).

    .PARAMETER OneViewPassword
        OneView password (used with -OneViewUser when -Credential is absent).

    .PARAMETER ModuleName
        HPEOneView module name (default: HPEOneView.1000).

    .OUTPUTS
        [hashtable] Success, OneViewHost, SessionToken, ReusedSession, Message, Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Builds a PSCredential from explicitly supplied user/password for Connect-OneViewSession; password is never persisted or logged.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'Backwards-compatible fallback shared with sibling OneView commands; -Credential is the preferred entry point.')]
    param(
        [string] $OneViewHost,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $OneViewUser,
        [string] $OneViewPassword,
        [string] $ModuleName = 'HPEOneView.1000'
    )

    $result = @{
        Success       = $false
        OneViewHost   = $OneViewHost
        SessionToken  = $null
        ReusedSession = $false
        Message       = $null
        Error         = $null
    }

    $isAutomated   = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
    $canPrompt     = -not $isAutomated -and [Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected
    $activeSession = Get-OneViewActiveSession

    # ── 0. Existing connection ALWAYS wins ─────────────────────────────────────
    # If a session is already connected, reuse it and NEVER reconnect - dropping a
    # live OneView session could cause incidents. This takes priority even over an
    # explicitly supplied -OneViewHost: we tell the operator which appliance they
    # are on and that they must Disconnect-OneView before switching appliances.
    if ($activeSession) {
        $result.Success       = $true
        $result.OneViewHost   = $activeSession.Name
        $result.SessionToken  = $activeSession.SessionID
        $result.ReusedSession = $true

        if ($OneViewHost -and $OneViewHost -ne $activeSession.Name) {
            $result.Message = "Already connected to OneView appliance '$($activeSession.Name)'. Reusing that session instead of connecting to '$OneViewHost' (not reconnecting, to avoid dropping the live session). Run Disconnect-OneView first if you need to switch to '$OneViewHost'."
            Write-Warning $result.Message
        } else {
            $result.Message = "Reusing existing OneView session to '$($activeSession.Name)'. Use Disconnect-OneView to close it."
            Write-Verbose $result.Message
        }
        return $result
    }

    # ── 1. No active session: resolve appliance host ───────────────────────────
    if (-not $OneViewHost) {
        if ($canPrompt) {
            Write-Host "Enter OneView appliance host to connect to: " -ForegroundColor Yellow -NoNewline
            $promptedHost = Read-Host
            if ($promptedHost) { $OneViewHost = $promptedHost.Trim() }
        }

        if (-not $OneViewHost) {
            $result.Error = "No OneViewHost supplied and no active OneView session to reuse. $script:ONEVIEW_NO_SESSION_MSG"
            return $result
        }
    }

    # ── 2. Resolve credentials ─────────────────────────────────────────────────
    # TERMINAL COMMANDS: credentials come ONLY from -Credential, -OneViewUser/
    # -OneViewPassword, or direct interactive input. They are NEVER read from
    # config, environment variables, or CyberArk - that path is reserved for
    # GitLab pipeline runs (out of scope for this release).
    if (-not $Credential) {
        if ($OneViewUser -and $OneViewPassword) {
            $Credential = [System.Management.Automation.PSCredential]::new(
                $OneViewUser,
                (ConvertTo-SecureString $OneViewPassword -AsPlainText -Force))
        } elseif ($canPrompt) {
            Write-Host "Enter OneView username for '$OneViewHost': " -ForegroundColor Yellow -NoNewline
            $u = Read-Host
            if (-not $u) {
                $result.Error = "No username supplied - aborting OneView connection to '$OneViewHost'."
                return $result
            }
            $securePass = Read-Host "Enter OneView password for '$OneViewHost': " -AsSecureString
            $Credential = [System.Management.Automation.PSCredential]::new($u, $securePass)
        } else {
            $result.Error = "OneView credentials required to connect to '$OneViewHost'. Supply -Credential (or -OneViewUser/-OneViewPassword), or run interactively. Terminal commands never read credentials from config, environment, or CyberArk."
            return $result
        }
    }

    # ── 3. Connect via the shared helper (persistent session) ──────────────────
    $conn = Connect-OneViewSession -Appliance $OneViewHost -Credential $Credential -ModuleName $ModuleName
    if (-not $conn.Connected) {
        $result.Error = if ($conn.Error) { $conn.Error } else { "Failed to connect to OneView appliance '$OneViewHost'." }
        return $result
    }

    $result.Success       = $true
    $result.OneViewHost   = $OneViewHost
    $result.SessionToken  = $conn.SessionId
    $result.ReusedSession = $conn.ReusedSession
    return $result
}
