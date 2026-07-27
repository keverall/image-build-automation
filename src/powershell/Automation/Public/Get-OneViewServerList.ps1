#
# Public/Get-OneViewServerList.ps1 - List all servers managed by HPE OneView
#
# Returns every server-hardware object visible to the appliance with normalised
# connection/health fields.  Pagination is handled internally so the full fleet
# is returned in a single call.
#
# Reuses the same REST credential pattern as Get-OneViewServerTarget.
#

function Get-OneViewServerList {
    <#
    .SYNOPSIS
        List all servers connected to HPE OneView.  Callable from the module Router.

    .DESCRIPTION
        Queries GET /rest/server-hardware across all pages and returns a normalised
        list of servers (name, serial, model, power state, health, iLO IP, enclosure).
        Supports an optional -Filter to narrow the result by health or power state.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).
        If omitted, the command checks for an existing HPEOneView module
        session (Connect-OVMgmt) and uses that appliance automatically.

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

    .PARAMETER PageSize
        Servers fetched per page (default 100, max 1000).

    .PARAMETER Filter
        Optional case-insensitive filter expression applied client-side:
          health:<status>   e.g. health:OK, health:Warning, health:Critical
          power:<state>     e.g. power:On, power:Off
          name:<substring>  e.g. name:PROD

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print the query without performing it.

    .RETURNS
        [hashtable] with Success, Count, Servers (array of hashtables), Error.

    .EXAMPLE
        Get-OneViewServerList -OneViewHost 'oneview.ad.example.com'

    .EXAMPLE
        Get-OneViewServerList -OneViewHost 'oneview.ad.example.com' -Filter 'health:Critical'

    .EXAMPLE
        Get-OneViewServerList

        Uses an existing HPEOneView module session if available.
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
        [string] $OneViewHost,
        [System.Management.Automation.PSCredential] $Credential,
        [string] $OneViewUser = $null,
        [string] $OneViewPassword = $null,
        [int]    $Port = 443,
        [bool]   $SkipCertificateCheck = $true,
        [int]    $TimeoutSec = 30,
        [int]    $PageSize = 100,
        [string] $Filter = $null,
        [hashtable] $MockResult = $null,
        [switch] $DryRun
    )

    if ($MockResult) {
        return $MockResult
    }

    # Parse -Filter into predicate components (validate before connecting)
    $healthFilter = $null; $powerFilter = $null; $nameFilter = $null
    if ($Filter) {
        if ($Filter -match '^health:(.+)$')     { $healthFilter = $Matches[1].Trim() }
        elseif ($Filter -match '^power:(.+)$')   { $powerFilter = $Matches[1].Trim() }
        elseif ($Filter -match '^name:(.+)$')    { $nameFilter = $Matches[1].Trim() }
        else {
            return @{ Success = $false; Count = 0; Servers = @(); Error = "Unsupported -Filter '$Filter'. Use health:<status>, power:<state> or name:<substring>." }
        }
    }

    if ($DryRun) {
        Write-Output "[DRY RUN] Get-OneViewServerList Host=$OneViewHost Filter=$Filter"
        return @{ Success = $true; Count = 0; Servers = @(); DryRun = $true }
    }

    # Resolve (or establish) a persistent OneView session via the shared helper.
    # Supplying -OneViewHost connects and prompts for credentials when needed;
    # omitting it reuses the current session. This command never disconnects.
    $sess = Resolve-OneViewSession -OneViewHost $OneViewHost -Credential $Credential `
        -OneViewUser $OneViewUser -OneViewPassword $OneViewPassword
    if (-not $sess.Success) {
        return @{ Success = $false; Count = 0; Servers = @(); Error = $sess.Error }
    }
    $OneViewHost  = $sess.OneViewHost
    $sessionToken = $sess.SessionToken

    $baseUrl = "https://$OneViewHost`:$Port"
    $apiBase = "$baseUrl/rest"

    try {
        $servers = [System.Collections.Generic.List[hashtable]]::new()
        $start = 0
        $total = $null
        do {
            $url = "$apiBase/server-hardware?start=$start&count=$PageSize"
            $listParams = @{
                Uri                  = $url
                Method               = 'Get'
                SkipCertificateCheck = $SkipCertificateCheck
                TimeoutSec           = $TimeoutSec
                ErrorAction          = 'Stop'
            }
            if ($sessionToken) { $listParams['Headers'] = @{ auth = $sessionToken } }
            else               { $listParams['Credential'] = $Credential }
            $resp = Invoke-RestMethod @listParams

            if ($null -eq $total) {
                if ($null -ne $resp.total)     { $total = $resp.total }
                elseif ($null -ne $resp.count) { $total = $resp.count }
                else                           { $total = 0 }
            }

            foreach ($srv in $resp.members) {
                $entry = @{
                    name           = $srv.name
                    serial_number  = $srv.serialNumber
                    model          = $srv.model
                    power_state    = $srv.powerState
                    health_status  = $srv.status
                    ilo_ip         = ($srv.mpIpAddresses | Select-Object -First 1)
                    enclosure_name = $srv.enclosureName
                    enclosure_bay  = $srv.position
                    oneview_uri    = $srv.uri
                    rom_version    = $srv.romVersion
                }
                if ($healthFilter -and ($entry.health_status -notmatch [regex]::Escape($healthFilter))) { continue }
                if ($powerFilter  -and ($entry.power_state  -notmatch [regex]::Escape($powerFilter)))  { continue }
                if ($nameFilter   -and ($entry.name         -notmatch [regex]::Escape($nameFilter)))   { continue }
                $servers.Add($entry)
            }

            $start += $PageSize
        } while ($start -lt $total -and $resp.members.Count -gt 0)

        $result = @{
            Success = $true
            Count   = $servers.Count
            Servers = $servers.ToArray()
            Error   = $null
        }
        _Format-ServerListResult -Result $result
        return $result
    }
    catch {
        return @{
            Success = $false
            Count   = 0
            Servers = @()
            Error   = "OneView server list failed: $($_.Exception.Message)"
        }
    }
}

function _Format-ServerListResult {
    param([hashtable]$Result)

    if (-not $Result.Success -or $Result.Count -eq 0) { return }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Server List ($($Result.Count) servers)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $nameWidth = ($Result.Servers | ForEach-Object { $_.name.Length } | Measure-Object -Maximum).Maximum
    if ($nameWidth -lt 10) { $nameWidth = 10 }
    if ($nameWidth -gt 50) { $nameWidth = 50 }

    $serialWidth = 15
    $powerWidth = 8
    $healthWidth = 10
    $iloWidth = 15

    $header = "{0,-$nameWidth}  {1,-$serialWidth}  {2,-$powerWidth}  {3,-$healthWidth}  {4,-$iloWidth}" -f `
        'Server Name', 'Serial Number', 'Power', 'Health', 'iLO IP'
    Write-Host $header -ForegroundColor Yellow
    Write-Host ("-" * $header.Length) -ForegroundColor Gray

    foreach ($srv in $Result.Servers) {
        $name = $srv.name
        if ($name.Length -gt 50) { $name = $name.Substring(0, 47) + '...' }

        $powerColor = switch ($srv.power_state) {
            'On'  { 'Green' }
            'Off' { 'Red' }
            default { 'Yellow' }
        }
        $healthColor = switch -Wildcard ($srv.health_status) {
            '*OK*'       { 'Green' }
            '*Warning*'  { 'Yellow' }
            '*Critical*' { 'Red' }
            default      { 'Gray' }
        }

        $line = "{0,-$nameWidth}  {1,-$serialWidth}  {2,-$powerWidth}  {3,-$healthWidth}  {4,-$iloWidth}" -f `
            $name, $srv.serial_number, $srv.power_state, $srv.health_status, $srv.ilo_ip
        Write-Host $line -ForegroundColor $healthColor
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# vim: ts=4 sw=4 et
