#
# Send-WebCallback.ps1 — Shared HTTP callback utility
# Used by Invoke-GitLabMaintenance.ps1 and Send-GitLabMaintenanceRequest.ps1
#

function Send-WebCallback {
    <#
    .SYNOPSIS
        POST JSON data to a webhook/callback URL.

    .PARAMETER Url
        Callback endpoint URL.

    .PARAMETER Data
        Hashtable or string to send as the request body.

    .PARAMETER ApiKey
        Optional API key added as X-API-Key header.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)]$Data,
        [string]$ApiKey
    )

    try {
        $body = if ($Data -is [string]) { $Data } else { $Data | ConvertTo-Json -Depth 10 }
        $headers = @{ "Content-Type" = "application/json" }
        if ($ApiKey) { $headers["X-API-Key"] = $ApiKey }

        Write-Host "Sending callback to $Url"
        Invoke-RestMethod -Uri $Url -Method Post -Body $body -Headers $headers -TimeoutSec 30
        Write-Host "Callback sent successfully"
    } catch {
        Write-Warning "Failed to send callback: $($_.Exception.Message)"
    }
}
