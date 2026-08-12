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
        session (Connect-OVMgmt); when one is active it is reused, otherwise a
        clean "not connected" status is returned instead of prompting for a host.

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

        Runs without parameters: reuses an active OneView session if one exists
        (Connect-OneView), otherwise returns Success=$false with a "not connected"
        message instead of prompting for a host.
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
        [Alias('Page')]
        [int]    $PageSize = 100,
        [string] $Filter = $null,
        [Alias('Mock')]
        [hashtable] $MockResult = $null,
        [Alias('Dry')]
        [switch] $DryRun
    )

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewServerList/.
    Initialize-Logging -CommandName 'Get-OneViewServerList' -LogName "Get-OneViewServerList-Host-$($OneViewHost ?? 'unspecified')"
    $logger = Get-Logger 'OneViewServerList'

    if ($MockResult) {
        $logger.Info("Get-OneViewServerList returning MockResult (filter=$Filter)")
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
        $msg = "[DRY RUN] Get-OneViewServerList Host=$OneViewHost Filter=$Filter"
        $logger.Info($msg); Write-Host $msg
        return @{ Success = $true; Count = 0; Servers = @(); DryRun = $true }
    }

    # ── Resolve the OneView session ──────────────────────────────────────────
    # A bare invocation (no -OneViewHost) first checks the active connection. If a
    # session established by Connect-OneView exists it is reused directly (no prompt);
    # otherwise a clean "not connected" status is returned rather than prompting for a
    # host/credentials (this mirrors Get-OneViewConnectionStatus / Get-OneViewVersion).
    # When a host IS supplied it is connected (or an existing same-host session reused)
    # via the shared helper. This command never disconnects.
    $sessionToken = $null
    if (-not $OneViewHost) {
        $activeSession = Get-OneViewActiveSession
        if ($activeSession) {
            $OneViewHost  = $activeSession.Name
            $sessionToken = $activeSession.SessionID
        }
    }

    if (-not $OneViewHost) {
        $logger.Info("Get-OneViewServerList: no host and no active session - graceful failure")
        return @{ Success = $false; Count = 0; Servers = @(); Error = $script:ONEVIEW_NO_SESSION_MSG }
    }

    # Reuse the active session directly when we derived the host from it; otherwise
    # let Resolve-OneViewSession connect (or reuse) via the shared helper.
    if (-not $sessionToken) {
        $sess = Resolve-OneViewSession -OneViewHost $OneViewHost -Credential $Credential `
            -OneViewUser $OneViewUser -OneViewPassword $OneViewPassword
        if (-not $sess.Success) {
            $logger.Info("Get-OneViewServerList: session resolution failed. Error='$($sess.Error)'")
            return @{ Success = $false; Count = 0; Servers = @(); Error = $sess.Error }
        }
        $OneViewHost  = $sess.OneViewHost
        $sessionToken = $sess.SessionToken
    }

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
        $logger.Info("Get-OneViewServerList result: Success=$($result.Success) Count=$($result.Count)")
        return $result
    }
    catch {
        $err = "OneView server list failed: $($_.Exception.Message)"
        $logger.Error($err)
        return @{
            Success = $false
            Count   = 0
            Servers = @()
            Error   = $err
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
