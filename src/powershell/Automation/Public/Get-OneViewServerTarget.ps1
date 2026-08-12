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

    .PARAMETER SrvrId
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
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -SrvrId 'PROD-SERVER-01'

    .EXAMPLE
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -SrvrId 'MXQ1234567' -IdentifierType Serial
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('OVHost')]
        [string] $OneViewHost,
        [Alias('ServerIdentifier')]
        [Parameter(Mandatory)][string] $SrvrId,
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
        [switch] $DryRun
    )

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewServerTarget/.
    Initialize-Logging -CommandName 'Get-OneViewServerTarget' -LogName "Get-OneViewServerTarget-Host-$($OneViewHost ?? 'unspecified')-Id-$SrvrId"
    $logger = Get-Logger 'Get-OneViewServerTarget'

    if ($MockResult) {
        $logger.Info("Get-OneViewServerTarget returning MockResult for Id=$SrvrId")
        return $MockResult
    }

    if ($DryRun) {
        $msg = "[DRY RUN] Get-OneViewServerTarget Host=$OneViewHost Id=$SrvrId Type=$IdentifierType"
        $logger.Info($msg); Write-Host $msg
        return @{
            Success = $true; Server = $SrvrId; DryRun = $true
            Details = @{ oneview_host = $OneViewHost; identifier = $SrvrId; type = $IdentifierType }
        }
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
            return @{ Success = $false; Server = $SrvrId; Error = $script:ONEVIEW_NO_SESSION_MSG }
        }
    }

    # Resolve (or establish) a persistent OneView session via the shared helper.
    # Supplying -OneViewHost connects and prompts for credentials when needed;
    # omitting it reuses the current session. This command never disconnects.
    $sess = Resolve-OneViewSession -OneViewHost $OneViewHost -Credential $Credential `
        -OneViewUser $OneViewUser -OneViewPassword $OneViewPassword
    if (-not $sess.Success) {
        $logger.Info("Get-OneViewServerTarget failed: no session. Error='$($sess.Error)'")
        return @{ Success = $false; Server = $SrvrId; Error = $sess.Error }
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
                'Name'         { "name='$SrvrId'" }
                'OneViewName'  { "name='$SrvrId'" }
                'Serial'       { "serialNumber='$SrvrId'" }
                'IloIp'        { "mpIpAddresses='$SrvrId'" }
                'EnclosureBay' { "position='$SrvrId'" }
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
                    return @{
                        Success = $false
                        Server  = $SrvrId
                        Error   = "Ambiguous target: '$SrvrId' matched $($resp.members.Count) servers via $t ($matchedNames). Refusing to proceed - single-server operations require exactly one match. Supply a more specific identifier (e.g. serial number)."
                    }
                }
                $srv = $resp.members[0]
                $details = @{
                    name              = $srv.name
                    serial_number     = $srv.serialNumber
                    model             = $srv.model
                    power_state       = $srv.powerState
                    health_status     = $srv.status
                    ilo_ip            = ($srv.mpIpAddresses | Select-Object -First 1)
                    enclosure_name    = $srv.enclosureName
                    enclosure_bay     = $srv.position
                    oneview_uri       = $srv.uri
                    rom_version       = $srv.romVersion
                }
                if ($details.health_status -and $details.health_status -ne 'OK' -and $details.health_status -ne 'Normal') {
                    return @{
                        Success = $false
                        Server  = $SrvrId
                        Error   = "Server health is $($details.health_status) - refusing to proceed"
                        Details = $details
                    }
                }
                $result = @{
                    Success = $true
                    Server  = $SrvrId
                    ResolvedBy = $t
                    Details = $details
                }
                _Format-ServerTargetResult -Result $result
                $logger.Info("Get-OneViewServerTarget resolved Id=$SrvrId (ResolvedBy=$($result.ResolvedBy))")
                return $result
            }
        }
        return @{
            Success = $false
            Server  = $SrvrId
            Error   = "Server '$SrvrId' not found in OneView (tried: $($typesToTry -join ','))"
        }
    }
    catch {
        return @{
            Success = $false
            Server  = $SrvrId
            Error   = "OneView query failed: $($_.Exception.Message)"
        }
    }
}

function _Format-ServerTargetResult {
    param([hashtable]$Result)

    if (-not $Result.Success -or -not $Result.Details) { return }

    $d = $Result.Details
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Server Target" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $powerColor = switch ($d.power_state) { 'On' { 'Green' } 'Off' { 'Red' } default { 'Yellow' } }
    $healthColor = switch -Wildcard ($d.health_status) { '*OK*' { 'Green' } '*Warning*' { 'Yellow' } '*Critical*' { 'Red' } default { 'Gray' } }

    Write-Host "  Server:       $($d.name)" -ForegroundColor White
    Write-Host "  Serial:       $($d.serial_number)"
    Write-Host "  Model:        $($d.model)"
    Write-Host "  Power:        $($d.power_state)" -ForegroundColor $powerColor
    Write-Host "  Health:       $($d.health_status)" -ForegroundColor $healthColor
    Write-Host "  iLO IP:       $($d.ilo_ip)"
    Write-Host "  Enclosure:    $($d.enclosure_name) / $($d.enclosure_bay)"
    Write-Host "  ROM Version:  $($d.rom_version)"
    Write-Host "  Resolved By:  $($Result.ResolvedBy)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# vim: ts=4 sw=4 et
