#
# Public/Get-OneViewServerTarget.ps1 - Identify / validate a target server via HPE OneView
#
# Resolves a target server from one of several identifier forms:
#   * Server hostname
#   * iLO IP
#   * Serial number
#   * OneView resource name
#   * Bay/Enclosure position
#
# All connection details are runtime parameters - no JSON config required.
#

function Get-OneViewServerTarget {
    <#
    .SYNOPSIS
        Query HPE OneView to identify and validate a target server by various identifiers.
        Callable from the module Router.

    .DESCRIPTION
        Sends a query against the OneView /rest/server-hardware endpoint and returns
        a normalized hashtable describing the server.  Validates health (must be OK)
        and tolerates power state Off or On.

        Reports the server's maintenance-mode state (Yes/No) in
        `Details.maintenance_mode`. The HPEOneView module's Get-OVServer is the
        preferred source because the REST endpoints do not reliably expose
        maintenance state; the REST payload's own maintenance fields are used as a
        fallback when the module is unavailable.

        STRICT SINGLE-SERVER: this command must resolve to exactly one server. A
        query that matches more than one server is a hard failure (Success=$false)
        rather than a warning - it never silently picks the first match, because it
        underpins destructive operations (ISO attach/deploy, reboot, OS build).
        Connection to the appliance is handled by the shared Resolve-OneViewSession
        helper (prompts for the host/credentials when needed) and the session
        persists; this command never disconnects.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).

    .PARAMETER ServerIdentifier
        Server name, serial number, OneView resource name, iLO IP, or bay/enclosure
        positional id (e.g. "Enclosure1, Bay 3").

    .PARAMETER IdentifierType
        Hint for the search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto.
        Default Auto attempts each in turn.

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

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print query without performing it.

    .RETURNS
        [hashtable] with Success, Server, Details, Error.

    .EXAMPLE
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'PROD-SERVER-01'

    .EXAMPLE
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('SrvrId')]
        [Parameter(Mandatory, ParameterSetName = 'Run')][string] $ServerIdentifier,
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
        [Alias('Mock')]
        [hashtable] $MockResult = $null,
        [Alias('Dry')]
        [switch] $DryRun,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Json,
        [switch] $Quiet,
        [Parameter(ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Get-OneViewServerTarget'; return }

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewServerTarget/.
    Initialize-Logging -CommandName 'Get-OneViewServerTarget' -LogName "Get-OneViewServerTarget-Host-$($OneViewHost ?? 'unspecified')-Id-$ServerIdentifier"
    $logger = Get-Logger 'Get-OneViewServerTarget'

    if ($MockResult) {
        $logger.Info("Get-OneViewServerTarget returning MockResult for Id=$ServerIdentifier")
        return (_Emit-ServerTargetResult -Result $MockResult -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    if ($DryRun) {
        $msg = "[DRY RUN] Get-OneViewServerTarget Host=$OneViewHost Id=$ServerIdentifier Type=$IdentifierType"
        $logger.Info($msg); Write-Host $msg
        return (_Emit-ServerTargetResult -Result @{
            Success = $true; Server = $ServerIdentifier; DryRun = $true
            Details = @{ oneview_host = $OneViewHost; identifier = $ServerIdentifier; type = $IdentifierType }
        } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # Graceful no-session handling, mirroring the sibling read-only commands
    # (Get-OneViewConnectionStatus / Get-OneViewServerList / Get-OneViewVersion):
    # when no host is supplied AND no OneView session is active, fail gracefully
    # instead of prompting interactively (which would hang automated / test runs
    # and violate the no-interactive-input rule). When an active session exists we
    # still reuse it below via Resolve-OneViewSession.
    if (-not $OneViewHost) {
        $activeSession = Get-OneViewActiveSession
        if (-not $activeSession) {
            return (_Emit-ServerTargetResult -Result @{ Success = $false; Server = $ServerIdentifier; Error = $script:ONEVIEW_NO_SESSION_MSG } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
        }
    }

    # Resolve (or establish) a persistent OneView session via the shared helper.
    # Supplying -OneViewHost connects and prompts for credentials when needed;
    # omitting it reuses the current session. This command never disconnects.
    $sess = Resolve-OneViewSession -OneViewHost $OneViewHost -Credential $Credential `
        -OneViewUser $OneViewUser -OneViewPassword $OneViewPassword
    if (-not $sess.Success) {
        $logger.Info("Get-OneViewServerTarget failed: no session. Error='$($sess.Error)'")
        return (_Emit-ServerTargetResult -Result @{ Success = $false; Server = $ServerIdentifier; Error = $sess.Error } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    $OneViewHost  = $sess.OneViewHost
    $sessionToken = $sess.SessionToken

    $baseUrl = "https://$OneViewHost`:$Port"
    $apiBase = "$baseUrl/rest"

    # Maintenance-mode detection: the REST GET /rest/server-hardware FILTERED
    # endpoint (used to resolve this single target) does not reliably expose the
    # maintenanceMode field, so a server already in maintenance mode renders as
    # "No". The HPEOneView module's Get-OVServer cmdlet fetches the individual
    # server object and DOES carry the accurate maintenance state, so it is the
    # preferred source. Falls back to the REST payload when the module is
    # unavailable (e.g. off-Windows test hosts).
    $maintLookup = _Get-OneViewServerMaintenanceLookup

    $typesToTry = if ($IdentifierType -eq 'Auto') {
        @('Serial','IloIp','Name')
    } else { @($IdentifierType) }

    $lastRequestError = $null
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
            $resp = Invoke-RestMethod -Uri $url -Method Get `
                -Headers @{ auth = $sessionToken } `
                -SkipCertificateCheck:$SkipCertificateCheck `
                -TimeoutSec $TimeoutSec -ErrorAction Stop
        }
        catch {
            $classified = _Classify-OneViewRequestError -Exception $_.Exception -OneViewHost $OneViewHost
            $lastRequestError = $classified
            if ($classified.IsConnectionFailure) {
                # Genuine transport failure: there is no working connection to OneView.
                # Say so plainly rather than leaking a confusing raw exception message.
                return (_Emit-ServerTargetResult -Result @{
                    Success = $false
                    Server  = $ServerIdentifier
                    Error   = "No connection to OneView at '$OneViewHost'. $($classified.Message)."
                } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
            # A real HTTP response (e.g. 400 from a rejected filter) means OneView IS
            # reachable - just this identifier form did not match. Try the next type
            # instead of aborting the whole resolution (important for -IdentifierType Auto).
            # For a 400 this is expected for non-applicable identifier types - record
            # via the logger's Info method (Debug-level diagnostics are noisy for tests).
            if ($classified.StatusCode -eq 400) {
                $logger.Info("Get-OneViewServerTarget: '$t' filter rejected by OneView (HTTP 400); trying next identifier type")
            } else {
                $logger.Warning("Get-OneViewServerTarget: '$t' query returned $($classified.Message); trying next identifier type")
            }
            continue
        }
        if ($resp.count -gt 0 -and $resp.members.Count -gt 0) {
            # Single-server operations (attach/deploy/reboot/build) MUST target
            # exactly one server. An ambiguous match is a hard failure - never
            # silently pick the first, which could build the wrong machine.
            if ($resp.members.Count -gt 1) {
                $matchedNames = ($resp.members | ForEach-Object { $_.name }) -join ', '
                return (_Emit-ServerTargetResult -Result @{
                    Success = $false
                    Server  = $ServerIdentifier
                    Error   = "Ambiguous target: '$ServerIdentifier' matched $($resp.members.Count) servers via $t ($matchedNames). Refusing to proceed - single-server operations require exactly one match. Supply a more specific identifier (e.g. serial number)."
                } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
            $srv = $resp.members[0]
            # Maintenance mode: prefer the HPEOneView module's Get-OVServer lookup
            # (keyed by serial number) because the REST filtered list endpoint does
            # not reliably expose maintenance state; fall back to the REST payload's
            # own maintenance fields when the module is unavailable.
            $details = @{
                name              = $srv.name
                serial_number     = $srv.serialNumber
                model             = $srv.model
                power_state       = $srv.powerState
                health_status     = $srv.status
                ilo_ip            = (_ConvertTo-IloIpAddressList $srv) -join ', '
                enclosure_name    = $srv.enclosureName
                enclosure_bay     = $srv.position
                oneview_uri       = $srv.uri
                rom_version       = $srv.romVersion
                maintenance_mode  = (_Get-OneViewMaintenanceMode -Server $srv -Lookup $maintLookup)
            }
            if ($details.health_status -and $details.health_status -ne 'OK' -and $details.health_status -ne 'Normal') {
                return (_Emit-ServerTargetResult -Result @{
                    Success = $false
                    Server  = $ServerIdentifier
                    Error   = "Server health is $($details.health_status) - refusing to proceed"
                    Details = $details
                } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
            }
            $result = @{
                Success = $true
                Server  = $ServerIdentifier
                ResolvedBy = $t
                Details = $details
            }
            $logger.Info("Get-OneViewServerTarget resolved Id=$ServerIdentifier (ResolvedBy=$($result.ResolvedBy))")
            return (_Emit-ServerTargetResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
        }
    }
    if ($lastRequestError) {
        return (_Emit-ServerTargetResult -Result @{
            Success = $false
            Server  = $ServerIdentifier
            Error   = "OneView returned an error ($($lastRequestError.Message)); could not resolve '$ServerIdentifier' via any of: $($typesToTry -join ', ')"
        } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    return (_Emit-ServerTargetResult -Result @{
        Success = $false
        Server  = $ServerIdentifier
        Error   = "Server '$ServerIdentifier' not found in OneView (tried: $($typesToTry -join ','))"
    } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}

function _Classify-OneViewRequestError {
    <#
    .SYNOPSIS
        Classifies a OneView REST exception into an honest, operator-readable result.

    .DESCRIPTION
        Distinguishes a genuine transport/connection failure (no working path to the
        appliance) from an HTTP status response that OneView actually returned. This
        keeps error messages truthful: a missing connection says "no connection"
        rather than dumping a raw, hyperbolic exception string.
    #>
    [CmdletBinding()]
    param(
        [System.Exception] $Exception,
        [string] $OneViewHost
    )

    $ex = $Exception
    $isHttp     = $false
    $statusCode = $null

    if ($ex -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
        $isHttp = $true
        if ($ex.Response -and $ex.Response.StatusCode) {
            $statusCode = [int]$ex.Response.StatusCode
        }
    }
    if (-not $statusCode -and $ex.Message -match 'status code does not indicate success:\s*(\d+)') {
        $isHttp     = $true
        $statusCode = [int]$Matches[1]
    }

    if ($isHttp) {
        $reason = switch ($statusCode) {
            400     { 'Bad Request (the identifier/filter was rejected by OneView)' }
            401     { 'Unauthorized (session expired or invalid credentials)' }
            403     { 'Forbidden (insufficient permissions)' }
            404     { 'Not Found (endpoint or resource missing)' }
            500     { 'Internal Server Error' }
            502     { 'Bad Gateway' }
            503     { 'Service Unavailable' }
            504     { 'Gateway Timeout' }
            default { 'HTTP error' }
        }
        return [hashtable]@{
            IsConnectionFailure = $false
            Message             = "OneView returned HTTP $statusCode - $reason"
            StatusCode          = $statusCode
        }
    }

    return [hashtable]@{
        IsConnectionFailure = $true
        Message             = 'could not reach the appliance (check host, network/VPN, and that OneView is online)'
        StatusCode          = $null
    }
}

function _Emit-ServerTargetResult {
    <#
    .SYNOPSIS
        Emits the server-target result via the shared, DRY _Publish-Result helper
        (consistent with every other automation command). By default it prints a
        clean, human-readable block and returns NOTHING on the success stream, so
        the operator never sees the raw 'Details { [...] }' hashtable dump in the
        terminal. Use -PassThru to also return the structured [hashtable] for scripts.
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )
    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-ServerTargetResult -Result $r
    }
}

function _Format-ServerTargetResult {
    param([hashtable]$Result)

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Server Target" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan

    if (-not $Result.Success) {
        if ($Result.DryRun) {
            Write-Host ""
            Write-Host "DRY RUN - no server queried." -ForegroundColor Yellow
        }
        if ($Result.Error) {
            Write-Host ""
            Write-Host "  Error:   $($Result.Error)" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $d = $Result.Details
    if (-not $d) {
        Write-Host ""
        Write-Host "  (no details available)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $powerColor = switch ($d.power_state) { 'On' { 'Green' } 'Off' { 'Red' } default { 'Yellow' } }
    $healthColor = switch -Wildcard ($d.health_status) { '*OK*' { 'Green' } '*Warning*' { 'Yellow' } '*Critical*' { 'Red' } default { 'Gray' } }
    # Maintenance mode is the one field where the "wrong" state suppresses
    # alerting, so it gets its own colour: Red = IN maintenance (zero alerting -
    # should not be left), Green = NOT in maintenance (normal).
    $maintColor = if ($d.maintenance_mode -eq 'Yes') { 'Red' } else { 'Green' }

    # Compact, comma-separated sentence of the key details on a single line (it is
    # allowed to wrap to a second line on narrow terminals rather than being dumped
    # as a raw '{ [...] }' hashtable). The maint cell is coloured individually so
    # the zero-alerting state is unmistakable regardless of the server's health.
    $preMaint  = "name=$($d.name), serial=$($d.serial_number), model=$($d.model), power=$($d.power_state), health=$($d.health_status)"
    $postMaint = "ilo=$($d.ilo_ip), enclosure=$($d.enclosure_name)/$($d.enclosure_bay), rom=$($d.rom_version)"
    Write-Host ""
    Write-Host "  Details:   $preMaint" -ForegroundColor White
    Write-Host "             maint=" -NoNewline -ForegroundColor White
    Write-Host "$($d.maintenance_mode)" -NoNewline -ForegroundColor $maintColor
    Write-Host ", $postMaint" -ForegroundColor White
    Write-Host ""
    Write-Host "  Resolved By:  $($Result.ResolvedBy)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

function _Get-OneViewServerMaintenanceLookup {
    <#
    .SYNOPSIS
        Build a lookup table of OneView maintenance mode keyed by server serial number.

    .DESCRIPTION
        The REST GET /rest/server-hardware endpoints (list and filtered) do not
        reliably expose the maintenanceMode field, so servers already in
        maintenance mode render as "No". The HPEOneView module's Get-OVServer
        cmdlet fetches the individual server object and DOES carry the accurate
        maintenance state, so it is the preferred source. This helper queries the
        module once and returns a hashtable keyed by serialNumber -> 'Yes'/'No'.

        Falls back to an empty hashtable when the HPEOneView module is unavailable
        (e.g. off-Windows test hosts, or no active session) - in that case the REST
        payload's own maintenance fields are used per-server instead.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $lookup = [System.Collections.Generic.Dictionary[string,string]]::new()

    try {
        $isWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
        if (-not $isWindows) { return $lookup }

        $mod = Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $mod) { return $lookup }

        $servers = Get-OVServer -ErrorAction SilentlyContinue
        if (-not $servers) { return $lookup }

        foreach ($s in $servers) {
            if (-not $s.serialNumber) { continue }
            $lookup[$s.serialNumber] = if (
                ($s.state -match 'MaintenanceMode') -or
                ($s.maintenanceModeEnabled -eq $true) -or
                ($s.maintenanceMode -and $s.maintenanceMode -notin @('Off', 'False', $false, $null, 0))
            ) { 'Yes' } else { 'No' }
        }
    } catch {
        Write-Verbose "_Get-OneViewServerMaintenanceLookup: module query failed: $($_.Exception.Message)"
    }

    return $lookup
}

function _Get-OneViewMaintenanceMode {
    <#
    .SYNOPSIS
        Resolve the maintenance mode (Yes/No) for a single server-hardware object.

    .DESCRIPTION
        Prefers the HPEOneView module's Get-OVServer lookup (keyed by serial number,
        fetched once by _Get-OneViewServerMaintenanceLookup) because the REST
        endpoints do not reliably expose maintenance mode. Falls back to the REST
        payload's own maintenance fields when the module lookup is unavailable.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object] $Server,
        [hashtable] $Lookup = @{}
    )

    # Prefer the module lookup (keyed by serial number) when available.
    if ($Lookup -and $Server.serialNumber -and $Lookup.ContainsKey($Server.serialNumber)) {
        return $Lookup[$Server.serialNumber]
    }

    # Fallback: the REST payload's own maintenance fields.
    if (
        ($Server.maintenanceState -and $Server.maintenanceState.Trim() -eq 'Maintenance') -or
        ($Server.maintenanceWindow -and $Server.maintenanceWindow.maintenanceState -and $Server.maintenanceWindow.maintenanceState.Trim() -eq 'Maintenance') -or
        ($Server.state -eq 'MaintenanceMode') -or
        ($Server.maintenanceModeEnabled -eq $true) -or
        ($Server.maintenanceMode -notin @('Off', 'False', $false, $null, 0))
    ) { return 'Yes' }

    return 'No'
}

# vim: ts=4 sw=4 et
