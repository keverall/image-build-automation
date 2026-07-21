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
        OneView username. Defaults to $env:ONEVIEW_USER.

    .PARAMETER OneViewPassword
        OneView password. Defaults to $env:ONEVIEW_PASSWORD.

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

    .RETURNS
        [hashtable] with Success, Connected, Reachable, Authenticated, Appliance,
        Version, ServerCount (optional), Server (optional) and SessionSource
        ('HPEOneViewModule' when reusing an active session, 'Explicit' otherwise).

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
        [string] $OneViewHost,
        [string] $ServerIdentifier = $null,
        [ValidateSet('Auto','Name','Serial','OneViewName','IloIp','EnclosureBay')][string] $IdentifierType = 'Auto',
        [System.Management.Automation.PSCredential] $Credential,
        [string] $OneViewUser = $null,
        [string] $OneViewPassword = $null,
        [int]    $Port = 443,
        [bool]   $SkipCertificateCheck = $true,
        [int]    $TimeoutSec = 30,
        [switch] $IncludeServerCount,
        [hashtable] $MockResult = $null,
        [switch] $DryRun
    )

    if ($MockResult) {
        return $MockResult
    }

    $sessionToken = $null

    if (-not $OneViewHost) {
        if ($global:ConnectedSessions) {
            $activeSession = $global:ConnectedSessions | Where-Object { $_.Connected -eq $true } | Select-Object -First 1
            if ($activeSession) {
                $OneViewHost = $activeSession.Name
                $sessionToken = $activeSession.SessionID
            }
        }

        if (-not $OneViewHost) {
            return @{ Success = $false; Connected = $false; Reachable = $false; Authenticated = $false; Appliance = $null; Error = "No active OneView session. Use Connect-OVMgmt to connect, or supply -OneViewHost." }
        }
    }

    if (-not $sessionToken -and -not $Credential) {
        if (-not $OneViewUser -or -not $OneViewPassword) {
            $ovCred = Get-OneViewCredentials
            if (-not $OneViewUser)     { $OneViewUser     = $ovCred[0] }
            if (-not $OneViewPassword) { $OneViewPassword = $ovCred[1] }
        }
        $Credential = [System.Management.Automation.PSCredential]::new(
            $OneViewUser,
            (ConvertTo-SecureString $OneViewPassword -AsPlainText -Force))
    }

    if ($DryRun) {
        Write-Output "[DRY RUN] Get-OneViewConnectionStatus Host=$OneViewHost Id=$ServerIdentifier Type=$IdentifierType"
        return @{
            Success = $true; Connected = $true; Reachable = $true; Authenticated = $true
            Appliance = $OneViewHost; Version = $null; ServerCount = $null
            Server = $null; SessionSource = $(if ($sessionToken) { 'HPEOneViewModule' } else { 'Explicit' })
            DryRun = $true
        }
    }

    $baseUrl = "https://$OneViewHost`:$Port"
    $apiBase = "$baseUrl/rest"

    $result = @{
        Success        = $false
        Connected      = $false
        Reachable      = $false
        Authenticated  = $false
        Appliance      = $OneViewHost
        Version        = $null
        ServerCount    = $null
        Server         = $null
        SessionSource  = $(if ($sessionToken) { 'HPEOneViewModule' } else { 'Explicit' })
        Error          = $null
    }

    try {
        # 1. Reachability - unauthenticated version probe
        try {
            $ver = Invoke-RestMethod -Uri "$apiBase/version" -Method Get `
                -SkipCertificateCheck:$SkipCertificateCheck `
                -TimeoutSec $TimeoutSec -ErrorAction Stop
            $result.Reachable = $true
            if ($ver -and $ver.currentVersion) { $result.Version = $ver.currentVersion }
        } catch {
            $result.Reachable = $false
            $result.Error = "OneView appliance '$OneViewHost' is not reachable: $($_.Exception.Message)"
        }

        # 2. Authentication - authenticated server-hardware probe
        if ($result.Reachable) {
            try {
                $probeParams = @{
                    Uri                  = "$apiBase/server-hardware?start=0&count=1"
                    Method               = 'Get'
                    SkipCertificateCheck = $SkipCertificateCheck
                    TimeoutSec           = $TimeoutSec
                    ErrorAction          = 'Stop'
                }
                if ($sessionToken) { $probeParams['Headers'] = @{ auth = $sessionToken } }
                else               { $probeParams['Credential'] = $Credential }
                $probe = Invoke-RestMethod @probeParams
                $result.Authenticated = $true
                if ($IncludeServerCount) {
                    if ($null -ne $probe.total)      { $result.ServerCount = $probe.total }
                    elseif ($null -ne $probe.count)  { $result.ServerCount = $probe.count }
                }
            } catch {
                $result.Authenticated = $false
                $errMsg = if ($sessionToken) { "OneView session authentication failed" } else { "OneView authentication failed for '$OneViewUser'" }
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
                    if ($sessionToken) { $srvParams['Headers'] = @{ auth = $sessionToken } }
                    else               { $srvParams['Credential'] = $Credential }
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
                            ilo_ip         = ($srv.mpIpAddresses | Select-Object -First 1)
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
        return $result
    }
    catch {
        $result.Error = "OneView connection status failed: $($_.Exception.Message)"
        return $result
    }
}

# vim: ts=4 sw=4 et
