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

# The HPE OneView PowerShell library locked for this automation. Resolved at
# runtime by Resolve-PinnedOneViewModule(): ONEVIEW_MODULE_NAME env override, else the
# LATEST HPEOneView.* module installed on the server running this code (the newest module
# is backward-compatible with older appliances, so this is the safe default), else default
# HPEOneView.1000. ALL OneView calls (especially destructive ones) use exactly this module
# and no other HPEOneView.* / HPOneView.* version, even when stray versions are installed.
$script:REQUIRED_ONEVIEW_MODULE = 'HPEOneView.1000'
$script:ActiveOneViewModuleName  = $null

function Get-OneViewModuleMajorVersion {
    <#
    .SYNOPSIS
        Parse the major OneView version implied by a module name (HPEOneView.8200 -> 8).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([string] $ModuleName)
    if ($ModuleName -match '(HPEOneView|HPOneView)\.(\d+)') {
        [long]$n = 0
        if ([long]::TryParse($matches[2], [ref]$n)) {
            # Module number encodes major*100 + minor (HPEOneView.820 = 8.20,
            # HPEOneView.1000 = 10.00). Major is the leading 1-2 digits.
            if ($n -ge 100) { return [int]($n / 100) }
            if ($n -ge 10)  { return [int]($n / 10) }
            return [int]$n
        }
    }
    return 0
}

function Get-OneViewApplianceMajorVersion {
    <#
    .SYNOPSIS
        Read the appliance's OneView major version from /rest/version (no auth).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string] $Appliance,
        [int] $Port = 443,
        [bool] $SkipCertificateCheck = $true,
        [int] $TimeoutSec = 30
    )
    try {
        $ver = Invoke-RestMethod -Uri "https://${Appliance}:${Port}/rest/version" -Method Get `
            -SkipCertificateCheck:$SkipCertificateCheck -TimeoutSec $TimeoutSec -ErrorAction Stop
        if ($null -ne $ver -and $null -ne $ver.currentVersion) {
            $s = "$($ver.currentVersion)".Trim()
            # Dotted string (e.g. "10.00") -> take the leading segment.
            if ($s -match '\.') {
                $seg = ($s -split '\.')[0]
                [int]$m = 0
                if ([int]::TryParse($seg, [ref]$m)) { return $m }
                return 0
            }
            [long]$n = 0
            if ([long]::TryParse($s, [ref]$n)) {
                # Encoded currentVersion (e.g. 10000 = 10.00, 8200 = 8.20).
                if ($n -ge 1000) { return [int]($n / 1000) }
                if ($n -ge 100)  { return [int]($n / 100) }
                return [int]$n
            }
        }
    } catch {
        Write-Verbose "Get-OneViewApplianceMajorVersion: probe failed: $($_.Exception.Message)"
    }
    return 0
}

function Resolve-PinnedOneViewModule {
    <#
    .SYNOPSIS
        Resolve the HPEOneView module to use for OneView calls on THIS server.
    .DESCRIPTION
        1. ONEVIEW_MODULE_NAME env var (valid module name) - explicit override.
        2. Otherwise the latest HPEOneView.* module installed on this server (sorted by
            version; the newest is backward-compatible with older appliances), else default.
        NOTE: The HPEOneView.* libraries are Windows-only. On non-Windows hosts (Linux/
        macOS) enumerating/importing them crashes the native PowerShell layer, so the
        availability checks below are SKIPPED off-Windows and resolution is by name only
        (the actual Connect-OVMgmt import is a Windows-only operation; unit tests mock it).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $isWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows

    # 1. Explicit env override
    $envVal = [System.Environment]::GetEnvironmentVariable('ONEVIEW_MODULE_NAME')
    if ($envVal -and $envVal -match '^(HPEOneView|HPOneView)\.\d+$') {
        if (-not $isWindows -or (Get-Module -ListAvailable -Name $envVal -ErrorAction SilentlyContinue)) {
            return $envVal
        }
        Write-Warning "ONEVIEW_MODULE_NAME '$envVal' is not installed; detecting from appliance instead."
    } elseif ($envVal) {
        Write-Warning "ONEVIEW_MODULE_NAME '$envVal' is not a valid OneView module name; ignoring."
    }

    # 2. Latest HPEOneView.* module installed on THIS automation server. The newest module
    #    is backward-compatible with older appliances, so this is the safe default.
    if ($isWindows) {
        $latest = @(Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue |
            Sort-Object { if ($_ -match '(HPEOneView|HPOneView)\.(\d+)') { [int]$matches[2] } else { 0 } } -Descending |
            Select-Object -ExpandProperty Name -First 1)
        if ($latest) {
            Write-Verbose "Resolved OneView module '$latest' as the latest installed on this server."
            return $latest
        }
    }

    return 'HPEOneView.1000'
}

function Get-ExpectedOneViewModuleName {
    <#
    .SYNOPSIS
        Pure resolution of the intended HPEOneView module name (no probing, no module scanning).
    .DESCRIPTION
        Returns $env:ONEVIEW_MODULE_NAME when set to a valid module name, otherwise the
        project default 'HPEOneView.1000'. Used by read-only status checks that must not
        import or scan HPEOneView.* modules (which can be costly/unsafe on hosts where the
        full library is installed). The authoritative, appliance-probing resolution lives in
        Resolve-PinnedOneViewModule (used only when actually connecting).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $envVal = [System.Environment]::GetEnvironmentVariable('ONEVIEW_MODULE_NAME')
    if ($envVal -and $envVal -match '^(HPEOneView|HPOneView)\.\d+$') {
        return $envVal
    }
    return 'HPEOneView.1000'
}

function Remove-OtherOneViewModules {
    <#
    .SYNOPSIS
        Remove any loaded HPEOneView.*/HPOneView.* module other than the pinned one.
    .DESCRIPTION
        Guarantees only the pinned module's cmdlets (Connect-OVMgmt, etc.) are in scope,
        so a stray install (e.g. HPEOneView.840/.820) cannot be used instead of the locked
        version. Also drops sessions established by removed modules.
    #>
    [CmdletBinding()]
    param([string] $KeepModule)
    $others = @(Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $KeepModule })
    foreach ($m in $others) {
        Write-Warning "Removing loaded OneView module '$($m.Name)' to enforce pinned '$KeepModule'."
        Remove-Module -Name $m.Name -Force -ErrorAction SilentlyContinue
    }
    if ($others.Count -gt 0) {
        $global:ConnectedSessions = @()
        $script:ActiveOneViewSession = $null
        $script:ActiveOneViewModuleName = $null
    }
}

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
    # On non-Windows hosts, enumerating HPEOneView.* via Get-Module -ListAvailable crashes
    # the native PowerShell layer (the libraries are Windows-only), so skip the scan.
    $isWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
    $installed = if ($isWindows) {
        @(Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue)
    } else {
        @()
    }

    $describe = { param($m) @{ Name = $m.Name; Version = "$($m.Version)"; Path = $m.Path } }

        $nonCompliantLoaded    = @($loaded    | Where-Object { $_.Name -ne (Resolve-PinnedOneViewModule) })
    $nonCompliantInstalled = @($installed | Where-Object { $_.Name -ne (Resolve-PinnedOneViewModule) })

    return @{
        RequiredModule        = (Resolve-PinnedOneViewModule)
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
        Enforce that only the locked HPEOneView module is (or will be) used in this session.

    .DESCRIPTION
        Returns Ok=$true when no other HPEOneView.*/HPOneView.* module is loaded and the
        intended $ModuleName matches the locked module (Resolve-PinnedOneViewModule). A
        non-compliant/loaded module holds cmdlets like Connect-OVMgmt, so importing the
        locked module alongside it is unsafe - Remove-OtherOneViewModules must run first.

    .PARAMETER ModuleName
        The module the caller intends to import. Omit to just validate the session against
        the locked module.

    .OUTPUTS
        [hashtable] Ok, Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $ModuleName
    )

    $required = Resolve-PinnedOneViewModule
    if ($ModuleName -and $ModuleName -ne $required) {
        return @{
            Ok    = $false
            Error = "OneView module '$ModuleName' is not the locked module '$required'. Set ONEVIEW_MODULE_NAME to override, or target an appliance whose version maps to '$required'."
        }
    }

    $status = Get-OneViewModuleStatus

    if ($status.NonCompliantLoaded.Count -gt 0) {
        $names = $status.NonCompliantLoaded -join ', '
        return @{
            Ok    = $false
            Error = "Unsupported HPE OneView module(s) already loaded in this session: $names. Only '$required' is permitted. Run: Remove-Module $names -Force, then retry (Connect-OneViewSession removes stray modules automatically)."
        }
    }

    if ($status.NonCompliantInstalled.Count -gt 0) {
        $names = $status.NonCompliantInstalled -join ', '
        Write-Warning "Unsupported HPE OneView module version(s) found on PSModulePath: $names. Only '$required' is permitted - uninstall/delete the others to avoid accidental auto-loading (see Get-OneViewVersion for their paths)."
    }

    return @{ Ok = $true; Error = $null }
}

function Get-OneViewActiveSession {
    <#
    .SYNOPSIS
        Return the active HPE OneView module session, if established by the locked module.

    .DESCRIPTION
        Inspects the global $global:ConnectedSessions collection and the module-tracked
        $script:ActiveOneViewSession. Only returns a session established by the locked
        module (Resolve-PinnedOneViewModule); a session from a stray install
        (e.g. HPEOneView.840/.820) is never reused, so OneView calls cannot run against
        the wrong library.

    .OUTPUTS
        [PSObject] The active session object, or $null.
    #>
    [CmdletBinding()]
    param()

    # Only trust a session established by the locked module. If no pin is tracked we
    # cannot guarantee the library, so do not reuse. An env override that changed
    # mid-session is also rejected (the tracked module must match the locked one).
    # If a pin is tracked, it must match an env override (reject a mid-session change).
    # When no pin is tracked (legacy/external session, or Pester tests) we still allow
    # reuse - Connect-OneViewSession strips stray modules on (re)connect for destructive ops.
    if ($script:ActiveOneViewModuleName) {
        $envVal = [System.Environment]::GetEnvironmentVariable('ONEVIEW_MODULE_NAME')
        if ($envVal -and $envVal -ne $script:ActiveOneViewModuleName) {
            return $null
        }
    }

    $candidates = @()
    # Prefer the session THIS module most recently established. Connect-OVMgmt
    # appends every connection to the module-global $global:ConnectedSessions, so
    # a stale session (e.g. from an earlier connection to a different appliance)
    # would otherwise win over the host the operator just connected to and get
    # reported back by Get-OneViewConnectionStatus. The module-tracked session is
    # always the intended/most-recent one, so it must take priority.
    if ($script:ActiveOneViewSession) {
        $candidates += $script:ActiveOneViewSession
    }
    if ($global:ConnectedSessions) {
        $candidates += $global:ConnectedSessions
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
        Establish or reuse an HPE OneView management session using the locked module.

    .DESCRIPTION
        Shared connection helper used by all OneView automation commands.
        Resolves the locked HPEOneView module (ONEVIEW_MODULE_NAME env, or the appliance's
        OneView version), removes any other loaded HPEOneView.* modules so only the locked
        library's cmdlets (Connect-OVMgmt, etc.) are in scope, imports it, then connects.

    .PARAMETER Appliance
        OneView appliance hostname or IP.

    .PARAMETER Credential
        PSCredential for authentication. If omitted, resolves from
        $env:ONEVIEW_USER / $env:ONEVIEW_PASSWORD or CyberArk.

    .PARAMETER ModuleName
        Deprecated/ignored for resolution. The locked module is resolved automatically.
        Kept for backwards compatibility; if supplied and it is not the locked module the
        call fails.

    .PARAMETER Destructive
        When $true, destructive calls are additionally guarded before mutating server
        state. NOTE: using an HPEOneView module OLDER than the appliance is ALWAYS rejected
        (hard error) regardless of this switch, because it causes 502 / corrupted-state
        failures; only a newer-or-equal module (backward-compatible) is permitted.

    .PARAMETER Port
        HTTPS port for the appliance version probe (default 443).

    .OUTPUTS
        [hashtable] Connected, ReusedSession, Appliance, SessionId, ModuleName, ModuleVersion, ApplianceVersion, Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Required to build PSCredential from runtime-resolved credentials for Connect-OVMgmt; password is never persisted or logged.')]
    param(
        [Parameter(Mandatory)][string] $Appliance,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $ModuleName,
        [switch] $Destructive,
        [int]    $Port = 443
    )

    # Lock the module to the latest installed on this server (or the ONEVIEW_MODULE_NAME override).
    $pinned = Resolve-PinnedOneViewModule

    $result = @{
        Connected        = $false
        ReusedSession    = $false
        Appliance        = $Appliance
        SessionId        = $null
        ModuleName       = $pinned
        ModuleVersion    = $null
        ApplianceVersion = $null
        Error            = $null
    }

    # Guard: NEVER use a module OLDER than the appliance. An older HPEOneView PowerShell
    # library against a newer appliance is unsupported by HPE and is the root cause of 502 /
    # corrupted-state failures. The opposite (newer module vs older appliance) is fine - the
    # newest module is backward-compatible - so only the older-than case blocks. If the
    # appliance version cannot be probed we cannot compare, so we proceed (the connection
    # attempt itself surfaces any real reachability problem).
    try {
        $applMajor = Get-OneViewApplianceMajorVersion -Appliance $Appliance -Port $Port
    } catch {
        $applMajor = 0
    }
    if ($applMajor -gt 0) {
        $modMajor = Get-OneViewModuleMajorVersion -ModuleName $pinned
        if ($modMajor -gt 0 -and $modMajor -lt $applMajor) {
            $result.Error = "OneView module '$pinned' (major $modMajor) is OLDER than appliance '$Appliance' (major $applMajor). Using an older module against a newer appliance is not supported - it causes 502 / corrupted-state failures. Install or select a module with major >= $applMajor (e.g. set ONEVIEW_MODULE_NAME to a newer HPEOneView.* library, or upgrade HPEOneView on this server)."
            return $result
        }
    }

    # Guarantee only the locked module is in scope: remove any stray HPEOneView.* that
    # another engineer installed/loaded (e.g. .840/.820) so Connect-OVMgmt resolves to
    # the correct library.
    Remove-OtherOneViewModules -KeepModule $pinned

    # Reject an explicitly requested module that is not the locked one.
    if ($ModuleName -and $ModuleName -ne $pinned) {
        $result.Error = "Requested module '$ModuleName' is not the locked module '$pinned'. Set ONEVIEW_MODULE_NAME to override."
        return $result
    }

    $existing = Get-OneViewActiveSession
    if ($existing -and $existing.Name -eq $Appliance) {
        $result.Connected = $true
        $result.ReusedSession = $true
        $result.SessionId = $existing.SessionID
        $script:ActiveOneViewSession = $existing
        $script:ActiveOneViewModuleName = $pinned
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

    # Import the exact locked module. On non-Windows the HPEOneView.* libraries cannot load
    # and enumerating them via Get-Module crashes the native layer, so skip the
    # RequiredVersion lookup (the import path is mocked in unit tests anyway).
    $isWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
    $mod = $null
    if ($isWindows) {
        $mod = Get-Module -ListAvailable -Name $pinned -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    try {
        if ($mod -and $mod.Version) {
            Import-Module $pinned -RequiredVersion $mod.Version -ErrorAction Stop
        } else {
            Import-Module $pinned -ErrorAction Stop
        }
    } catch {
        $result.Error = "Failed to import $pinned`: $($_.Exception.Message)"
        return $result
    }

    $imp = Get-Module -Name $pinned -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($imp) { $result.ModuleVersion = "$($imp.Version)" }

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
            $script:ActiveOneViewModuleName = $pinned
        } else {
            $result.Error = 'Connect-OVMgmt succeeded but no active session found'
        }
    } catch {
        $result.Error = "Connect-OVMgmt failed: $($_.Exception.Message)"
    }

    # Capture the appliance's OneView version for display. The module used is the latest
    # installed on this server and is backward-compatible with older appliances, so the
    # module and appliance versions are intentionally distinct - a major mismatch is
    # expected and is NOT an error.
    if ($result.Connected) {
        try {
            $av = Invoke-RestMethod -Uri "https://${Appliance}:${Port}/rest/version" -Method Get `
                -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
            if ($av -and $null -ne $av.currentVersion) { $result.ApplianceVersion = $av.currentVersion }
        } catch {
            Write-Verbose "Connect-OneViewSession: appliance version probe failed: $($_.Exception.Message)"
        }
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
        [string] $OneViewPassword
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
    $conn = Connect-OneViewSession -Appliance $OneViewHost -Credential $Credential
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
