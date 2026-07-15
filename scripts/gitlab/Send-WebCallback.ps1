#
# Send-WebCallback.ps1 - Shared HTTP callback utility
# Used by Invoke-GitLabMaintenance.ps1 and Send-GitLabMaintenanceRequest.ps1
#

function Send-WebCallback {
    <#
    .SYNOPSIS
        POST JSON data to a webhook/callback URL.

    .PARAMETER Url
        Callback endpoint URL. Must use HTTPS for secure transmission.

    .PARAMETER Data
        Hashtable or string to send as the request body.

    .PARAMETER ApiKey
        Optional API key added as X-API-Key header. Not logged for security.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)]$Data,
        [string]$ApiKey
    )

    # Validate HTTPS for secure callback transmission
    if ($Url -notmatch '^https://') {
        Write-Error "Callback URL must use HTTPS for secure transmission: $Url"
        return
    }

    try {
        $body = if ($Data -is [string]) { $Data } else { $Data | ConvertTo-Json -Depth 10 }
        $headers = @{ "Content-Type" = "application/json" }
        if ($ApiKey) { $headers["X-API-Key"] = $ApiKey }

        Write-Output "Sending callback to $Url"
        Invoke-RestMethod -Uri $Url -Method Post -Body $body -Headers $headers -TimeoutSec 30
        Write-Output "Callback sent successfully"
    } catch {
        Write-Warning "Failed to send callback: $($_.Exception.Message)"
    }
}
