#
# Public/Get-OneViewServerTarget.ps1 — Identify / validate a target server via HPE OneView
#
# Resolves a target server from one of several identifier forms:
#   * Server hostname
#   * iLO IP
#   * Serial number
#   * OneView resource name
#   * Bay/Enclosure position
#
# All connection details are runtime parameters — no JSON config required.
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

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).

    .PARAMETER ServerIdentifier
        Server name, serial number, OneView resource name, iLO IP, or bay/enclosure
        positional id (e.g. "Enclosure1, Bay 3").

    .PARAMETER IdentifierType
        Hint for the search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto.
        Default Auto attempts each in turn.

    .PARAMETER OneViewUser
        OneView username. Defaults to $env:ONEVIEW_USER.

    .PARAMETER OneViewPassword
        OneView password. Defaults to $env:ONEVIEW_PASSWORD.

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
        [string] $OneViewHost,
        [Parameter(Mandatory)][string] $ServerIdentifier,
        [ValidateSet('Auto','Name','Serial','OneViewName','IloIp','EnclosureBay')][string] $IdentifierType = 'Auto',
        [string] $OneViewUser = $null,
        [string] $OneViewPassword = $null,
        [int]    $Port = 443,
        [bool]   $SkipCertificateCheck = $true,
        [int]    $TimeoutSec = 30,
        [hashtable] $MockResult = $null,
        [switch] $DryRun
    )

    if ($MockResult) {
        return $MockResult
    }

    if (-not $OneViewHost) {
        return @{ Success = $false; Error = "OneViewHost parameter is required" }
    }

    if (-not $OneViewUser -or -not $OneViewPassword) {
        $cred = Get-OneViewCredentials
        if (-not $OneViewUser)     { $OneViewUser     = $cred[0] }
        if (-not $OneViewPassword) { $OneViewPassword = $cred[1] }
    }

    $baseUrl = "https://$OneViewHost`:$Port"
    $apiBase = "$baseUrl/rest"

    $typesToTry = if ($IdentifierType -eq 'Auto') {
        @('Serial','IloIp','EnclosureBay','Name')
    } else { @($IdentifierType) }

    try {
        if ($DryRun) {
            Write-Host "[DRY RUN] Get-OneViewServerTarget Host=$OneViewHost Id=$ServerIdentifier Type=$IdentifierType"
            return @{
                Success = $true; Server = $ServerIdentifier; DryRun = $true
                Details = @{ oneview_host = $OneViewHost; identifier = $ServerIdentifier; type = $IdentifierType }
            }
        }

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
                -Credential (New-Object System.Management.Automation.PSCredential(
                    $OneViewUser,
                    (ConvertTo-SecureString $OneViewPassword -AsPlainText -Force))) `
                -SkipCertificateCheck:$SkipCertificateCheck `
                -TimeoutSec $TimeoutSec -ErrorAction Stop
            if ($resp.count -gt 0 -and $resp.members.Count -gt 0) {
                if ($resp.members.Count -gt 1) {
                    Write-Warning "Multiple servers match '$ServerIdentifier' via $t ($($resp.members.Count) matches). Using first; supply a more specific identifier to disambiguate."
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
                        Server  = $ServerIdentifier
                        Error   = "Server health is $($details.health_status) — refusing to proceed"
                        Details = $details
                    }
                }
                return @{
                    Success = $true
                    Server  = $ServerIdentifier
                    ResolvedBy = $t
                    Details = $details
                }
            }
        }
        return @{
            Success = $false
            Server  = $ServerIdentifier
            Error   = "Server '$ServerIdentifier' not found in OneView (tried: $($typesToTry -join ','))"
        }
    }
    catch {
        return @{
            Success = $false
            Server  = $ServerIdentifier
            Error   = "OneView query failed: $($_.Exception.Message)"
        }
    }
}

# vim: ts=4 sw=4 et
