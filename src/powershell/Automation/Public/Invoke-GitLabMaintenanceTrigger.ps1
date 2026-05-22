#
# Invoke-GitLabMaintenanceTrigger.ps1 — Router handler for GitLab CI/CD maintenance trigger
# Called via Invoke-RoutedRequest -RequestType 'gitlab_maintenance'
#
# This is a router handler function that wraps Send-GitLabMaintenanceRequest.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Function definition - this is what gets exported and called by the router
function Invoke-GitLabMaintenanceTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $ClusterId,
        [ValidateSet('enable', 'disable', 'validate')][string] $Action = 'enable',
        [string] $Start,
        [string] $End,
        [string] $ConfigDir = 'configs',
        [switch] $DryRun,
        [string] $GitLabUrl = $env:GITLAB_URL,
        [string] $ProjectId = $env:GITLAB_PROJECT_ID,
        [string] $TriggerToken = $env:GITLAB_TRIGGER_TOKEN,
        [string] $GitRef = 'main',
        [string] $CallbackUrl = $env:MAINTENANCE_CALLBACK_URL,
        [string] $CallbackApiKey = $env:MAINTENANCE_API_KEY,
        [int] $TimeoutSeconds = 600,
        [string] $JobToken = $env:GITLAB_JOB_TOKEN
    )

    # Import the Send-GitLabMaintenanceRequest function if not already loaded
    $scriptsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' 'scripts' 'gitlab')).ProviderPath
    $triggerScript = Join-Path $scriptsRoot 'Send-GitLabMaintenanceRequest.ps1'

    if (-not (Get-Command Send-GitLabMaintenanceRequest -ErrorAction SilentlyContinue)) {
        if (Test-Path $triggerScript) {
            . $triggerScript
        } else {
            Write-Error "Send-GitLabMaintenanceRequest.ps1 not found at $triggerScript"
            return @{ Success = $false; Error = "Trigger script not found" }
        }
    }

    try {
        $result = Send-GitLabMaintenanceRequest -Action $Action -ClusterId $ClusterId -Start $Start -End $End `
            -ConfigDir $ConfigDir -DryRun:$DryRun -GitLabUrl $GitLabUrl -ProjectId $ProjectId `
            -TriggerToken $TriggerToken -GitRef $GitRef -CallbackUrl $CallbackUrl -CallbackApiKey $CallbackApiKey `
            -TimeoutSeconds $TimeoutSeconds -JobToken $JobToken

        return @{
            Success      = $result.success
            PipelineId   = $result.pipeline_id
            ClusterId    = $ClusterId
            Action       = $Action
            GitLabUrl    = $result.gitlab_url
            WebUrl       = $result.web_url
            Message      = "GitLab pipeline triggered for cluster $ClusterId"
        }
    } catch {
        return @{
            Success   = $false
            Error     = $_.Exception.Message
            ClusterId = $ClusterId
            Action    = $Action
        }
    }
}

# vim: ts=4 sw=4 et