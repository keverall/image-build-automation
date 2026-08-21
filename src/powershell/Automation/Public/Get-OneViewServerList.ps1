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
        Supports an optional -Filter to narrow the result by health, power state, or
        name (substring/wildcard match).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).
        If omitted, the command checks for an existing HPEOneView module
        session (Connect-OVMgmt); when one is active it is reused, otherwise a
        clean "not connected" status is returned instead of prompting for a host.

    .PARAMETER Credential
        PSCredential for authentication. Preferred, non-interactive entry point
        (sourced from a secret store). Falls back to -OneViewUser/-OneViewPassword
        or an interactive prompt when omitted. Never read from config or environment.

    .PARAMETER OneViewUser
        OneView username (used with -OneViewPassword). Never read from config or environment.

    .PARAMETER OneViewPassword
        OneView password (used with -OneViewUser). Never read from config or environment.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate verification for the REST calls that fetch the list.
        Most OneView appliances in lab/test use a self-signed or internal-CA
        certificate, so the default is $true. Only relevant while a NEW connection
        is being established - when an active session is reused it has no effect.
        Set to $false only against an appliance presenting a fully trusted cert.

    .PARAMETER TimeoutSec
        Per-call timeout (default 30 s) for each paginated REST request. Only
        relevant while a NEW connection is established or when fetching very
        large fleets over a slow link; the default is fine for normal use.

    .PARAMETER PageSize
        Servers fetched per page (default 100, max 1000).

    .PARAMETER Filter
        Optional client-side filter. Matching is case-insensitive and, by default,
        a SUBSTRING match, so partial values still match (health:Critical matches
        "Critical", name:PROD matches "PROD-SRV-01"). The name/power/health values
        also accept PowerShell-style wildcards:
          health:<value>   e.g. health:Critical, health:*Warning*
          power:<value>     e.g. power:On, power:Off
          name:<value>     e.g. name:PROD (substring), name:PROD-* (wildcard),
                            name:srv-0? (single-char wildcard)

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print the query without performing it.

    .PARAMETER PassThru
        By default the command only prints a human-readable table to the terminal
        and emits NO object to the pipeline (so the console is not cluttered with a
        raw hashtable/json dump). Pass -PassThru to also return the structured
        [hashtable] (Success, Count, Servers, Error) for use by scripts or the
        module Router.

    .RETURNS
        Nothing by default (table printed to host). With -PassThru, a [hashtable]
        with Success, Count, Servers (array of hashtables), Error.

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
        [switch] $DryRun,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Json,
        [switch] $Quiet
    )

    # Common logging: each command writes to its own isolated log under
    # generated/logs/commands/Get-OneViewServerList/.
    Initialize-Logging -CommandName 'Get-OneViewServerList' -LogName "Get-OneViewServerList-Host-$($OneViewHost ?? 'unspecified')"
    $logger = Get-Logger 'OneViewServerList'

    if ($MockResult) {
        $logger.Info("Get-OneViewServerList returning MockResult (filter=$Filter)")
        return (_Emit-OneViewServerListResult -Result $MockResult -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # Parse -Filter into predicate regexes (validate before connecting).
    # Matching is case-insensitive; substring-by-default with PowerShell-style
    # wildcards (*, ?) supported via the shared converter.
    $healthRegex = $null; $powerRegex = $null; $nameRegex = $null
    if ($Filter) {
        if ($Filter -match '^health:(.+)$')     { $healthRegex = [regex]::new((_ConvertToWildcardRegex $Matches[1].Trim()), 'IgnoreCase') }
        elseif ($Filter -match '^power:(.+)$')   { $powerRegex  = [regex]::new((_ConvertToWildcardRegex $Matches[1].Trim()), 'IgnoreCase') }
        elseif ($Filter -match '^name:(.+)$')    { $nameRegex   = [regex]::new((_ConvertToWildcardRegex $Matches[1].Trim()), 'IgnoreCase') }
        else {
            $errMap = @{ Success = $false; Count = 0; Servers = @(); Error = "Unsupported -Filter '$Filter'. Use health:<status>, power:<state> or name:<value>." }
            return (_Emit-OneViewServerListResult -Result $errMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
        }
    }

    if ($DryRun) {
        $msg = "[DRY RUN] Get-OneViewServerList Host=$OneViewHost Filter=$Filter"
        $logger.Info($msg); Write-Host $msg
        $dryMap = @{ Success = $true; Count = 0; Servers = @(); DryRun = $true }
        return (_Emit-OneViewServerListResult -Result $dryMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
        $errMap = @{ Success = $false; Count = 0; Servers = @(); Error = $script:ONEVIEW_NO_SESSION_MSG }
        return (_Emit-OneViewServerListResult -Result $errMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # Reuse the active session directly when we derived the host from it; otherwise
    # let Resolve-OneViewSession connect (or reuse) via the shared helper.
    if (-not $sessionToken) {
        $sess = Resolve-OneViewSession -OneViewHost $OneViewHost -Credential $Credential `
            -OneViewUser $OneViewUser -OneViewPassword $OneViewPassword
        if (-not $sess.Success) {
            $logger.Info("Get-OneViewServerList: session resolution failed. Error='$($sess.Error)'")
            $errMap = @{ Success = $false; Count = 0; Servers = @(); Error = $sess.Error }
            return (_Emit-OneViewServerListResult -Result $errMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
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
                    ilo_ip         = (_ConvertTo-IloIpAddressList $srv) -join ', '
                    enclosure_name = $srv.enclosureName
                    enclosure_bay  = $srv.position
                    oneview_uri    = $srv.uri
                    rom_version    = $srv.romVersion
                }
                if ($healthRegex -and -not $healthRegex.IsMatch($entry.health_status)) { continue }
                if ($powerRegex  -and -not $powerRegex.IsMatch($entry.power_state))    { continue }
                if ($nameRegex   -and -not $nameRegex.IsMatch($entry.name))           { continue }
                $servers.Add($entry)
            }

            $start += $PageSize
        } while ($start -lt $total -and $resp.members.Count -gt 0)

        $result = @{
            Success   = $true
            Count     = $servers.Count
            Appliance = $OneViewHost
            Servers   = $servers.ToArray()
            Error     = $null
        }
        return (_Emit-OneViewServerListResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    catch {
        $err = "OneView server list failed: $($_.Exception.Message)"
        $logger.Error($err)
        $errMap = @{
            Success = $false
            Count   = 0
            Servers = @()
            Error   = $err
        }
        return (_Emit-OneViewServerListResult -Result $errMap -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
}

function _ConvertToWildcardRegex {
    <#
    .SYNOPSIS
        Convert a PowerShell-style wildcard pattern to an anchored, case-insensitive
        regex that matches the pattern ANYWHERE in the target (substring-by-default).

    .DESCRIPTION
        '*' becomes '.*' (any run of chars) and '?' becomes '.' (a single char);
        every other character is regex-escaped. The result is wrapped with '.*' on
        both sides so a bare substring (e.g. 'PROD') still matches, while explicit
        wildcards (e.g. 'PROD-*', 'srv-0?') are honoured.
    #>
    param([string] $Pattern)

    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Pattern.ToCharArray()) {
        if ($ch -eq '*')      { $sb.Append('.*') | Out-Null }
        elseif ($ch -eq '?')  { $sb.Append('.')  | Out-Null }
        else                  { $sb.Append([regex]::Escape([string]$ch)) | Out-Null }
    }
    return ".*$($sb.ToString()).*"
}

function _Emit-OneViewServerListResult {
    <#
    .SYNOPSIS
        Emits the server-list result via the shared, DRY _Publish-Result helper
        (consistent with every other automation command).
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-OneViewServerListResult -Result $r
    }
}

function _Format-OneViewServerListResult {
    param([hashtable]$Result)

    if (-not $Result.Success) {
        if ($Result.Error) {
            Write-Host ""
            Write-Host "  Error:   $($Result.Error)" -ForegroundColor Red
            Write-Host ""
        }
        return
    }

    if ($Result.DryRun) {
        Write-Host ""
        Write-Host "DRY RUN - no servers queried." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    if ($Result.Count -eq 0) {
        Write-Host ""
        Write-Host "No servers matched the request." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  OneView Server List ($($Result.Count) servers)" -ForegroundColor Cyan
    if ($Result.Appliance) {
        Write-Host "  Appliance: $($Result.Appliance)" -ForegroundColor Cyan
    }
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    $nameW   = [math]::Max(10, [math]::Min(50, ($Result.Servers | ForEach-Object { "$($_.name)".Length } | Measure-Object -Maximum).Maximum))
    $serialW = 15
    $modelW  = [math]::Max(8,  [math]::Min(22, ($Result.Servers | ForEach-Object { "$($_.model)".Length } | Measure-Object -Maximum).Maximum))
    $powerW  = 8
    $healthW = 10
    $iloW    = [math]::Max(15, [math]::Min(40, ($Result.Servers | ForEach-Object { "$($_.ilo_ip)".Length } | Measure-Object -Maximum).Maximum))
    $encW    = [math]::Max(10, [math]::Min(20, ($Result.Servers | ForEach-Object { "$($_.enclosure_name)".Length } | Measure-Object -Maximum).Maximum))
    $bayW    = [math]::Max(6,  [math]::Min(12, ($Result.Servers | ForEach-Object { "$($_.enclosure_bay)".Length } | Measure-Object -Maximum).Maximum))
    $romW    = [math]::Max(6,  [math]::Min(12, ($Result.Servers | ForEach-Object { "$($_.rom_version)".Length } | Measure-Object -Maximum).Maximum))

    $header = "{0,-$nameW}  {1,-$serialW}  {2,-$modelW}  {3,-$powerW}  {4,-$healthW}  {5,-$iloW}  {6,-$encW}  {7,-$bayW}  {8,-$romW}" -f `
        'Server Name', 'Serial', 'Model', 'Power', 'Health', 'iLO IP', 'Enclosure', 'Bay', 'ROM'
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

        $line = "{0,-$nameW}  {1,-$serialW}  {2,-$modelW}  {3,-$powerW}  {4,-$healthW}  {5,-$iloW}  {6,-$encW}  {7,-$bayW}  {8,-$romW}" -f `
            $name, $srv.serial_number, $srv.model, $srv.power_state, $srv.health_status, $srv.ilo_ip, $srv.enclosure_name, $srv.enclosure_bay, $srv.rom_version
        Write-Host $line -ForegroundColor $healthColor
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# vim: ts=4 sw=4 et
