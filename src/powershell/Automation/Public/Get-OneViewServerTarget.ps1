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
        [Parameter(Mandatory)][string] $ServerIdentifier,
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
        [switch] $Quiet
    )

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

    $typesToTry = if ($IdentifierType -eq 'Auto') {
        @('Serial','IloIp','EnclosureBay','Name')
    } else { @($IdentifierType) }

    try {
        foreach ($t in $typesToTry) {
            $filter = switch ($t) {
                'Name'         { "name='$ServerIdentifier'" }
                'OneViewName'  { "name='$ServerIdentifier'" }
                'Serial'       { "serialNumber='$ServerIdentifier'" }
                'IloIp'        { "mpIpAddresses='$ServerIdentifier'" }
                'EnclosureBay' { "position='$ServerIdentifier'" }
            }
            $url = "$apiBase/server-hardware?filter=`"$filter`""
            $resp = Invoke-RestMethod -Uri $url -Method Get `
                -Headers @{ auth = $sessionToken } `
                -SkipCertificateCheck:$SkipCertificateCheck `
                -TimeoutSec $TimeoutSec -ErrorAction Stop
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
        return (_Emit-ServerTargetResult -Result @{
            Success = $false
            Server  = $ServerIdentifier
            Error   = "Server '$ServerIdentifier' not found in OneView (tried: $($typesToTry -join ','))"
        } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    catch {
        return (_Emit-ServerTargetResult -Result @{
            Success = $false
            Server  = $ServerIdentifier
            Error   = "OneView query failed: $($_.Exception.Message)"
        } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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

    # Compact, comma-separated sentence of the key details on a single line (it is
    # allowed to wrap to a second line on narrow terminals rather than being dumped
    # as a raw '{ [...] }' hashtable).
    $summaryParts = @(
        "name=$($d.name)",
        "serial=$($d.serial_number)",
        "model=$($d.model)",
        "power=$($d.power_state)",
        "health=$($d.health_status)",
        "ilo=$($d.ilo_ip)",
        "enclosure=$($d.enclosure_name)/$($d.enclosure_bay)",
        "rom=$($d.rom_version)"
    )
    Write-Host ""
    Write-Host "  Details:   $($summaryParts -join ', ')" -ForegroundColor White
    Write-Host ""
    Write-Host "  Resolved By:  $($Result.ResolvedBy)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# vim: ts=4 sw=4 et
