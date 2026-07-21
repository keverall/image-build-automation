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
        Version, ServerCount (optional) and Server (optional).

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com'

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
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

    if (-not $OneViewHost) {
        $isAutomated = [System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true'
        if (-not $isAutomated) {
            Write-Host "Enter OneView appliance hostname/IP:" -ForegroundColor Yellow
            $OneViewHost = Read-Host
        }
        if (-not $OneViewHost) {
            return @{ Success = $false; Connected = $false; Reachable = $false; Authenticated = $false; Appliance = $null; Error = "OneViewHost parameter is required" }
        }
    }

    if (-not $Credential) {
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
            Server = $null; DryRun = $true
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
                $probe = Invoke-RestMethod -Uri "$apiBase/server-hardware?start=0&count=1" -Method Get `
                    -Credential $Credential `
                    -SkipCertificateCheck:$SkipCertificateCheck `
                    -TimeoutSec $TimeoutSec -ErrorAction Stop
                $result.Authenticated = $true
                if ($IncludeServerCount) {
                    if ($null -ne $probe.total)      { $result.ServerCount = $probe.total }
                    elseif ($null -ne $probe.count)  { $result.ServerCount = $probe.count }
                }
            } catch {
                $result.Authenticated = $false
                $result.Error = "OneView authentication failed for '$OneViewUser': $($_.Exception.Message)"
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
                    $resp = Invoke-RestMethod -Uri $url -Method Get `
                        -Credential $Credential `
                        -SkipCertificateCheck:$SkipCertificateCheck `
                        -TimeoutSec $TimeoutSec -ErrorAction Stop
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
