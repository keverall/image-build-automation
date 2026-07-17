#
# Public/New-ScomConnection.ps1 - Returns PowerShell command strings for SCOM management-group connections,
# including SCOM version detection.
#
# After PSRemoting in (via Invoke-PowerShellWinRM), the caller string:
#   1. Imports the OperationsManager module
#   2. Creates a New-SCOMManagementGroupConnection
#   3. Detects the SCOM server version and echoes it as a JSON marker line
#
# The SCOMManager._GetScomVersion() method parses the output to determine
# whether to use PowerShell cmdlets (2012/2016) or REST API (2019+ / 2025).

function New-ScomConnection {
    <#
    .SYNOPSIS
        Returns a PowerShell command string that creates an SCOM management-group connection
        and emits the SCOM server version for downstream routing.

    .PARAMETER ManagementServer
        SCOM management server hostname / IP.

    .EXAMPLE
        $script = New-ScomConnection -ManagementServer 'scom01.corp.local'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ManagementServer
    )
    return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$ManagementServer" -ErrorAction Stop
# ── Detect SCOM server version ──
`$verLine = (Get-SCOMManagementServer | Select-Object -First 1).Version
`$ver  = if (`$verLine) { `$verLine.Trim() } else { 'unknown' }
# ── Detect whether REST API endpoint is reachable ──
`$restReady = `$false
try {
    `$base  = "http://`$(`$env:COMPUTERNAME)/OperationsManager"
    `$null = Invoke-WebRequest -Uri "`$base/authenticate" -Method Head `
        -TimeoutSec 5 -UseDefaultCredentials -ErrorAction Stop
    `$restReady = `$true
} catch {
    `$restReady = `$false
}
# Emit version marker as first line so caller can parse simply
Write-Output "SCOM_VERSION: `$ver"
Write-Output "SCOM_REST_READY: `$restReady"
"@
}

function New-ScomRestConnection {
    <#
    .SYNOPSIS
        Creates scom rest connection (SCOM mode).
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ManagementServer,
        [Parameter(Mandatory, Position = 1)][System.Management.Automation.PSCredential] $Credential
    )
    $UserName = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password
    return @"
Import-Module OperationsManager -ErrorAction Stop
`$baseUrl  = "http://$ManagementServer/OperationsManager"
`$authMode = "Network"
`$headers  = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
`$headers.Add('Content-Type','application/json; charset=utf-8')
`$bodyRaw  = "(`$authMode):$UserName`:$Password"
`$bytes    = [System.Text.Encoding]::UTF8.GetBytes(`$bodyRaw)
`$encoded  = [Convert]::ToBase64String(`$bytes)
`$jsonBody = `$encoded | ConvertTo-Json
`$session  = `$null
try {
    `$resp = Invoke-WebRequest -Method POST -Uri "`$baseUrl/authenticate" `
        -Headers `$headers -Body `$jsonBody -UseDefaultCredentials `
        -SessionVariable session -ErrorAction Stop
    `$csrfToken = `$session.Cookies.GetCookies(`$baseUrl) `
        | Where-Object { `$_.Name -eq 'SCOM-CSRF-TOKEN' }
    if (`$csrfToken) {
        `$headers.Add('SCOM-CSRF-TOKEN', [System.Web.HttpUtility]::UrlDecode(`$csrfToken.Value))
    }
    Write-Output "SCOM_REST_CONNECTED: true"
} catch {
    Write-Error "SCOM REST authentication failed: `$(`$_.Exception.Message)"
    Write-Output "SCOM_REST_CONNECTED: false"
}
# Expose session and headers for downstream calls
Export-SCOMManagementSession -Headers `$headers -Session `$session
"@
}
