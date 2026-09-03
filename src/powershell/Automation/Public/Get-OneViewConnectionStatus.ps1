#
# Public/Get-OneViewConnectionStatus.ps1 - Quick OneView connection + server status check
#
# Reports whether the HPE OneView appliance is reachable and authenticated, and
# (optionally) the connection/health status of a single target server.  Designed
# for a fast "is it connected?" check without entering maintenance flows.
#
# Reuses the same REST credential pattern as Get-OneViewServerTarget so behaviour
# stays consistent across OneView commands.
#

function Get-OneViewConnectionStatus {
    <#
    .SYNOPSIS
        Quickly check OneView appliance connectivity and (optionally) a server's
        connection status.  Callable from the module Router.

    .DESCRIPTION
        Performs two read-only checks against the OneView REST API:
           1. Reachability - GET /rest/version (no auth) to confirm the appliance
              is online and responding.
           2. Authentication - GET /rest/server-hardware (authenticated) to confirm
              the supplied credentials are valid.
        If -ServerIdentifier is supplied, the target server is also resolved and
        its power/health reported so you can see at a glance whether it is "connected".

        This command is a STATUS CHECK and NEVER prompts. Run with no parameters to
        report the ACTIVE OneView connection established by Connect-OneView
        (Get-OneViewActiveSession). Supply -OneViewHost to check a SPECIFIC appliance
        instead. To actually connect, use Connect-OneView -OneViewHost <host>.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).
        If omitted, the command checks for an existing HPEOneView module
        session (Connect-OVMgmt) and uses that appliance automatically.

    .PARAMETER ServerIdentifier
        Optional server name, serial number, iLO IP or bay position to look up.

    .PARAMETER IdentifierType
        Hint for the server search filter: Name, Serial, OneViewName, IloIp,
        EnclosureBay, Auto. Default Auto attempts each in turn.

    .PARAMETER OneViewUser
        OneView username (used with -OneViewPassword). Never read from config or environment.

    .PARAMETER OneViewPassword
        OneView password (used with -OneViewUser). Never read from config or environment.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER TimeoutSec
        Per-call timeout (default 30 s).

    .PARAMETER IncludeServerCount
        Include the total number of servers managed by OneView.

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print the checks without performing them.

    .PARAMETER PassThru
        By default the command only prints a human-readable status summary to the
        terminal and emits NO object to the pipeline (so the console is not cluttered
        with a raw hashtable/json dump). Pass -PassThru to also return the structured
        [hashtable] for use by scripts or the module Router.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable status summary.

    .PARAMETER Quiet
        Suppress the human-readable status summary (use with -PassThru / -Json when
        the caller handles display itself).

    .RETURNS
        Nothing by default (summary printed to host). With -PassThru, a [hashtable]
        with Success, Connected, Reachable, Authenticated, Appliance, Version
        (appliance OneView version, e.g. 8200 = 8.20), ServerCount (optional),
        Server (optional), SessionSource ('HPEOneViewModule' when reusing an active
        session, 'Explicit' otherwise), ModuleName (the HPEOneView PowerShell library
        that serves the call), ModuleVersion, ModuleSource, VersionCompliant (bool) and
        VersionWarning (optional, present only on a mismatch). With -Json, a JSON
        [string] representation of the same data.

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com'

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial

    .EXAMPLE
        Get-OneViewConnectionStatus

        Uses an existing HPEOneView module session if available. Returns
        Connected=$false if no session is active.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    # Credentials are runtime-resolved (env / CyberArk) and only ever materialised
    # into a System.Management.Automation.PSCredential at the network layer. The
    # -AsPlainText conversion below is unavoidable for REST Basic auth and is scoped
    # to the fallback path; callers SHOULD prefer -Credential (a PSCredential sourced
    # from a secret store) to avoid passing plaintext entirely.
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Required to build a PSCredential from runtime-resolved (env/CyberArk) credentials for OneView REST Basic auth; password is never persisted or logged.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'Backwards-compatible fallback with sibling OneView commands; -Credential (PSCredential) is the preferred, secure entry point.')]
    param(
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('SrvrId')]
        [string] $ServerIdentifier = $null,
        [Alias('IdTyp')]
        [ValidateSet('Auto','Name','Serial','OneViewName','IloIp','EnclosureBay')][string] $IdentifierType = 'Auto',
        [Alias('Cred')]
        [System.Management.Automation.PSCredential] $Credential,
        [Alias('OVUser')]
        [string] $OneViewUser = $null,
        [Alias('OVPwd')]
        [string] $OneViewPassword = $null,
        [int]    $Port = 443,
        [Alias('SkipCert')]
        [bool]   $SkipCertificateCheck = $true,
        [Alias('Timeout')]
        [int]    $TimeoutSec = 30,
        [Alias('SrvrCount')]
        [switch] $IncludeServerCount,
        [Alias('Mock')]
        [hashtable] $MockResult = $null,
        [Alias('Dry')]
        [switch] $DryRun,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Json,
        [switch] $Quiet
    )

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewConnectionStatus/. Stored at script
    # scope so the sibling helper _Test-OneViewVersionCompliance can share it
    # (its `if ($logger)` already expects that).
    Initialize-Logging -CommandName 'Get-OneViewConnectionStatus' -LogName "Get-OneViewConnectionStatus-Host-$($OneViewHost ?? 'unspecified')"
    $script:logger = Get-Logger 'OneViewConnectivity'

    if ($MockResult) {
        $logger.Info("Get-OneViewConnectionStatus returning MockResult")
        return (_Emit-ConnectionStatusResult -Result $MockResult -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    $sessionToken = $null
    $apiVersion   = $null

    # Reuse any live OneView session instead of reconnecting. Reconnecting an already
    # active session can drop in-flight work and, with no credential on hand, produces a
    # 401 because the auth header is built with no token/credential. This mirrors the
    # "existing connection always wins" guard used by Resolve-OneViewSession /
    # Connect-OneViewSession: when a session is active we reuse it and NEVER attempt a
    # fresh connect. Supplying -OneViewHost for the same appliance is a no-op that simply
    # reports the live session; supplying it for a different appliance also reuses the
    # active session (run Disconnect-OneView first to switch appliances).
    $activeSession = Get-OneViewActiveSession
    if ($activeSession) {
        if (-not $OneViewHost) {
            $OneViewHost = $activeSession.Name
        } elseif ($OneViewHost -ne $activeSession.Name) {
            Write-Warning "Active OneView session is to '$($activeSession.Name)'; reusing it instead of reconnecting to '$OneViewHost'."
            $OneViewHost = $activeSession.Name
        }
        $sessionToken = $activeSession.SessionID
    } elseif (-not $OneViewHost) {
        $logger.Info("Get-OneViewConnectionStatus: no host and no active session - graceful failure")
        $noConn = @{ Success = $false; Connected = $false; Reachable = $false; Authenticated = $false; Appliance = $null; Error = $script:ONEVIEW_NO_SESSION_MSG }
        return (_Emit-ConnectionStatusResult -Result $noConn -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # TERMINAL COMMAND: credentials come ONLY from -Credential or
    # -OneViewUser/-OneViewPassword. Never from config, environment, or CyberArk.
    if (-not $sessionToken -and -not $Credential -and $OneViewUser -and $OneViewPassword) {
        $Credential = [System.Management.Automation.PSCredential]::new(
            $OneViewUser,
            (ConvertTo-SecureString $OneViewPassword -AsPlainText -Force))
    }

    if ($DryRun) {
        $msg = "[DRY RUN] Get-OneViewConnectionStatus Host=$OneViewHost Id=$ServerIdentifier Type=$IdentifierType"
        $logger.Info($msg); Write-Host $msg
        $dryMap = @{
            Success = $true; Connected = $true; Reachable = $true; Authenticated = $true
            Appliance = $OneViewHost; Version = $null; ServerCount = $null
            Server = $null; SessionSource = $(if ($sessionToken) { 'HPEOneViewModule' } else { 'Explicit' })
            DryRun = $true
        }
        return (_Emit-ConnectionStatusResult -Result $dryMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    $baseUrl = "https://$OneViewHost`:$Port"
    $apiBase = "$baseUrl/rest"

    $result = @{
        Success        = $false
        Connected      = $false
        Reachable      = $false
        Authenticated  = $false
        Appliance      = $OneViewHost
        Version        = $null   # appliance OneView version (e.g. 8200 = 8.20)
        VersionCompliant = $null
        ModuleName     = $null   # HPEOneView PowerShell library that serves the call
        ModuleVersion  = $null
        ModuleSource   = $null   # 'LoadedSession' | 'Resolved' | $null
        SessionSource  = $(if ($sessionToken) { 'HPEOneViewModule' } else { 'Explicit' })
    }

    try {
        # 1. Reachability - unauthenticated version probe
        try {
            $ver = Invoke-RestMethod -Uri "$apiBase/version" -Method Get `
                -SkipCertificateCheck:$SkipCertificateCheck `
                -TimeoutSec $TimeoutSec -ErrorAction Stop
            $result.Reachable = $true
            if ($ver -and $ver.currentVersion) {
                $result.Version = $ver.currentVersion
                $apiVersion = _Get-OneViewApiVersion -Version $ver.currentVersion
                _Test-OneViewVersionCompliance -Result $result -Version $ver.currentVersion -Appliance $OneViewHost
            }
            # Report exactly which HPEOneView PowerShell library serves the call so the
            # operator can tell appliance version apart from module version.
            $ovMod = @(Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($ovMod) {
                $result.ModuleName    = $ovMod.Name
                $result.ModuleVersion = "$($ovMod.Version)"
                $result.ModuleSource  = 'LoadedSession'
            } else {
                # Read-only status check: do NOT scan/import HPEOneView.* modules here
                # (that is done only by Connect-OneViewSession). Just report the intended
                # library from the env override / default.
                $result.ModuleName   = Get-ExpectedOneViewModuleName
                $result.ModuleSource = 'Expected (library not yet imported in this session)'
            }
        } catch {
            $result.Reachable = $false
            $result.Error = "OneView appliance '$OneViewHost' is not reachable: $($_.Exception.Message)"
        }

        # 2. Authentication - authenticated server-hardware probe
        #    The active-session token (or the explicit -Credential) is passed as the
        #    auth header on EVERY authenticated call, together with the mandatory
        #    X-API-Version header (OneView rejects /rest/server-hardware without it).
        if ($result.Reachable) {
            try {
                $probeParams = @{
                    Uri                  = "$apiBase/server-hardware?start=0&count=1"
                    Method               = 'Get'
                    SkipCertificateCheck = $SkipCertificateCheck
                    TimeoutSec           = $TimeoutSec
                    ErrorAction          = 'Stop'
                }
                if ($sessionToken) {
                    $probeParams['Headers'] = _Get-OneViewRestHeaders -ApiVersion $apiVersion -AuthToken $sessionToken
                } else {
                    $probeParams['Headers'] = _Get-OneViewRestHeaders -ApiVersion $apiVersion -Credential $Credential
                }
                $probe = Invoke-RestMethod @probeParams
                $result.Authenticated = $true
                if ($IncludeServerCount) {
                    if ($null -ne $probe.total)      { $result.ServerCount = $probe.total }
                    elseif ($null -ne $probe.count)  { $result.ServerCount = $probe.count }
                }
            } catch {
                $result.Authenticated = $false
                $errMsg = if ($sessionToken) {
                    "OneView session authentication failed"
                } elseif ($Credential) {
                    "OneView authentication failed for '$($Credential.UserName)'"
                } else {
                    "OneView authentication failed (no active session and no credentials supplied)"
                }
                $result.Error = "$errMsg`: $($_.Exception.Message)"
            }
        }

        $result.Connected = ($result.Reachable -and $result.Authenticated)

        # 3. Optional single-server lookup (reuses the same endpoint shape)
        if ($result.Connected -and $ServerIdentifier) {
            $typesToTry = if ($IdentifierType -eq 'Auto') {
                @('Serial','IloIp','EnclosureBay','Name')
            } else { @($IdentifierType) }

            foreach ($t in $typesToTry) {
                $filter = switch ($t) {
                    'Name'         { "name='$ServerIdentifier'" }
                    'OneViewName'  { "name='$ServerIdentifier'" }
                    'Serial'       { "serialNumber='$ServerIdentifier'" }
                    'IloIp'        { "mpIpAddresses='$ServerIdentifier'" }
                    'EnclosureBay' { "position='$ServerIdentifier'" }
                }
                $url = "$apiBase/server-hardware?filter=`"$filter`""
                try {
                    $srvParams = @{
                        Uri                  = $url
                        Method               = 'Get'
                        SkipCertificateCheck = $SkipCertificateCheck
                        TimeoutSec           = $TimeoutSec
                        ErrorAction          = 'Stop'
                    }
                    if ($sessionToken) {
                        $srvParams['Headers'] = _Get-OneViewRestHeaders -ApiVersion $apiVersion -AuthToken $sessionToken
                    } else {
                        $srvParams['Headers'] = _Get-OneViewRestHeaders -ApiVersion $apiVersion -Credential $Credential
                    }
                    $resp = Invoke-RestMethod @srvParams
                    if ($resp.count -gt 0 -and $resp.members.Count -gt 0) {
                        if ($resp.members.Count -gt 1) {
                            Write-Warning "Multiple servers match '$ServerIdentifier' via $t ($($resp.members.Count) matches). Using first; supply a more specific identifier to disambiguate."
                        }
                        $srv = $resp.members[0]
                        $result.Server = @{
                            name           = $srv.name
                            serial_number  = $srv.serialNumber
                            model          = $srv.model
                            power_state    = $srv.powerState
                        health_status  = $srv.status
                        ilo_ip         = (_ConvertTo-IloIpAddressList $srv) -join ', '
                        enclosure_name = $srv.enclosureName
                            enclosure_bay  = $srv.position
                            connected      = ($srv.status -ne 'Disabled')
                            resolved_by    = $t
                        }
                        break
                    }
                } catch {
                    # try next identifier type
                }
            }
            if (-not $result.Server) {
                $result.Server = @{ identifier = $ServerIdentifier; connected = $false; error = "Server '$ServerIdentifier' not found in OneView" }
            }
        }

        $result.Success = $result.Connected
        return (_Emit-ConnectionStatusResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    catch {
        $result.Error = "OneView connection status failed: $($_.Exception.Message)"
        $logger.Error($result.Error)
        return (_Emit-ConnectionStatusResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
}

function _Emit-ConnectionStatusResult {
    <#
    .SYNOPSIS
        Emits the connection-status result via the shared, DRY _Publish-Result
        helper (consistent with every other automation command).
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-ConnectionStatusResult -Result $r
    }
}

function _Format-ConnectionStatusResult {
    <#
    .SYNOPSIS
        Render a concise, human-readable OneView connection status summary.
        Blank/empty fields are suppressed so the terminal is never cluttered with
        placeholder rows.
    #>
    param([hashtable]$Result)

    if ($null -eq $Result) { return }

    $header = if ($Result.Success) { 'CONNECTED' } else { 'NOT CONNECTED' }
    $statusColor = if ($Result.Success) { 'Green' } else { 'Red' }
    $dryTag = if ($Result.DryRun) { ' [DRY-RUN]' } else { '' }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Connection Status" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Status:    ${header}${dryTag}" -ForegroundColor $statusColor
    if ($Result.Appliance) {
        Write-Host "  Appliance: $($Result.Appliance)"
    }
    if ($null -ne $Result.Reachable) {
        Write-Host "  Reachable: $($Result.Reachable)" -ForegroundColor $(if ($Result.Reachable) { 'Green' } else { 'Red' })
    }
    if ($null -ne $Result.Authenticated) {
        Write-Host "  Auth:      $($Result.Authenticated)" -ForegroundColor $(if ($Result.Authenticated) { 'Green' } else { 'Red' })
    }
    if ($null -ne $Result.Version) {
        Write-Host "  Version:   $($Result.Version)"
    }
    if ($Result.ModuleName) {
        $modVer = if ($Result.ModuleVersion) { "  v$($Result.ModuleVersion)" } else { '' }
        Write-Host "  Module:    $($Result.ModuleName)$modVer"
        if ($Result.ModuleSource) { Write-Host "    Source:  $($Result.ModuleSource)" }
    }
    if ($null -ne $Result.VersionCompliant) {
        $vc = if ($Result.VersionCompliant) { 'Compatible' } else { 'MISMATCH' }
        $vcColor = if ($Result.VersionCompliant) { 'Green' } else { 'Red' }
        Write-Host "  Mod Compat: $vc" -ForegroundColor $vcColor
    }
    if ($null -ne $Result.ServerCount) {
        Write-Host "  Servers:   $($Result.ServerCount)"
    }
    if ($Result.SessionSource) {
        Write-Host "  Session:   $($Result.SessionSource)"
    }

    if ($Result.Server) {
        $s = $Result.Server
        Write-Host ""
        Write-Host "  --- Server ---" -ForegroundColor Yellow
        if ($s.name)          { Write-Host "    Name:    $($s.name)" }
        if ($s.serial_number) { Write-Host "    Serial:  $($s.serial_number)" }
        if ($s.power_state)   {
            Write-Host "    Power:   $($s.power_state)" -ForegroundColor $(if ($s.power_state -eq 'On') { 'Green' } else { 'Red' })
        }
        if ($s.health_status) {
            Write-Host "    Health:  $($s.health_status)" -ForegroundColor $(switch -Wildcard ($s.health_status) {
                '*OK*' { 'Green' }; '*Warning*' { 'Yellow' }; '*Critical*' { 'Red' }; default { 'Gray' } })
        }
        if ($s.ilo_ip)        { Write-Host "    iLO IP:  $($s.ilo_ip)" }
        if ($s.error)         { Write-Host "    Error:   $($s.error)" -ForegroundColor Red }
    }

    if ($Result.VersionWarning) {
        Write-Host ""
        Write-Host "  WARNING: $($Result.VersionWarning)" -ForegroundColor Yellow
    }
    if ($Result.Error) {
        Write-Host ""
        Write-Host "  Error:   $($Result.Error)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

function _Get-OneViewApiVersion {
    <#
    .SYNOPSIS
        Map an HPE OneView appliance version to its REST API version.
    .DESCRIPTION
        OneView's /rest/server-hardware (and most other) endpoints REQUIRE the
        X-API-Version header. The value tracks the appliance major generation, so we
        map the normalised major version to a safe minimum API version the appliance
        will accept (OneView is backward-compatible, so sending the generation minimum
        is accepted even when the appliance supports a newer API).
    #>
    param($Version)
    $major = _Get-OneViewMajorVersion -Version $Version
    if ($null -eq $major) { return $null }
    switch ($major) {
        10 { return 2400 }
        9  { return 2000 }
        8  { return 1000 }
        7  { return 200 }
        6  { return 120 }
        default { return $null }
    }
}

function _Get-OneViewRestHeaders {
    <#
    .SYNOPSIS
        Build the header set for OneView REST calls, including the mandatory
        X-API-Version header plus authentication (session token or Basic credential).
    .DESCRIPTION
        Raw Invoke-RestMethod calls against OneView must carry the X-API-Version header
        (and Accept/Content-Type); omitting it causes the authenticated probe to fail so
        the connection is reported as not connected and the server is never resolved.
        Auth is supplied either as the active session token (auth header) or, for the
        explicit -Credential path, as an HTTP Basic Authorization header.
    #>
    [CmdletBinding()]
    param(
        $ApiVersion,
        $AuthToken,
        [System.Management.Automation.PSCredential] $Credential
    )
    $h = @{ 'Accept' = 'application/json'; 'Content-Type' = 'application/json' }
    if ($ApiVersion) { $h['X-API-Version'] = [string]$ApiVersion }
    if ($AuthToken) {
        $h['auth'] = $AuthToken
    } elseif ($Credential) {
        $pwd = $Credential.GetNetworkCredential().Password
        $h['Authorization'] = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credential.UserName):$pwd"))
    }
    return $h
}

function _Get-OneViewMajorVersion {
    <#
    .SYNOPSIS
        Normalise an HPE OneView version (string or number) to its major version.
    .DESCRIPTION
        Handles the representations seen across OneView generations:
          * Dotted strings: "10.00.0000" / "8.20" -> leading segment (10 / 8)
          * Integers from /rest/version currentVersion (encoded Major*1000 + Minor*10,
            e.g. 8200 -> 8.20, 10000 -> 10.00) -> major via integer division by 1000
          * Legacy 3-digit integers (e.g. 820 -> 8.20) -> major via division by 100
        Returns $null when the value cannot be parsed.
    #>
    param($Version)
    if ($null -eq $Version -or [string]::IsNullOrWhiteSpace("$Version")) { return $null }
    $s = "$Version".Trim()
    if ($s -match '\.') {
        $seg = ($s -split '\.')[0]
        [int]$m = 0
        if ([int]::TryParse($seg, [ref]$m)) { return $m }
        return $null
    }
    [long]$n = 0
    if ([long]::TryParse($s, [ref]$n)) {
        if ($n -ge 1000) { return [int]($n / 1000) }   # 8200 -> 8 ; 10000 -> 10
        if ($n -ge 100)  { return [int]($n / 100) }    # 820  -> 8 (legacy 3-digit)
        return [int]$n                                  # e.g. 9 -> 9
    }
    return $null
}

function _Test-OneViewVersionCompliance {
    <#
    .SYNOPSIS
        Record the appliance-vs-module version relationship (informational).
    .DESCRIPTION
        Populates $Result.VersionCompliant and $Result.VersionWarning. The newest
        HPEOneView module is backward-compatible with older appliances, so a module whose
        major version is >= the appliance major version is compatible (VersionCompliant =
        $true). Only a module OLDER than the appliance (module major < appliance major) is
        a genuine risk and is flagged. Because automation pins the latest module installed
        on the server, the module is virtually always newer than or equal to the appliance.
    #>
    param(
        [hashtable] $Result,
        $Version,
        [string]    $Appliance
    )
    $major = _Get-OneViewMajorVersion -Version $Version
    if ($null -eq $major) {
        $Result.VersionCompliant = $null
        return
    }
    $lockedModule = Get-ExpectedOneViewModuleName
    $reqMajor = Get-OneViewModuleMajorVersion -ModuleName $lockedModule
    if ($reqMajor -ge $major) {
        $Result.VersionCompliant = $true
        return
    }
    $Result.VersionCompliant = $false
    $msg = "OneView module '$lockedModule' (major $reqMajor) is OLDER than appliance '$Appliance' (major $major). Upgrade HPEOneView on this server to a version >= the appliance generation before connecting."
    $Result.VersionWarning = $msg
    Write-Warning $msg
    if ($logger) { $logger.Warning($msg) }
}

# vim: ts=4 sw=4 et
