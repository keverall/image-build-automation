#
# Invoke-GitLabMaintenanceTrigger.ps1 — Router handler for GitLab CI/CD maintenance trigger
# Called via Invoke-RoutedRequest -RequestType 'gitlab_maintenance'
#
# This is a router handler function that wraps Send-GitLabMaintenanceRequest.

function Invoke-GitLabMaintenanceTrigger {
    <#
    .SYNOPSIS
        Trigger GitLab CI/CD pipeline for cluster maintenance.

    .DESCRIPTION
        Router handler that initiates GitLab CI/CD pipeline for maintenance operations.
        Wraps Send-GitLabMaintenanceRequest to enable, disable, or validate maintenance mode
        via GitLab pipelines instead of direct execution.

    .PARAMETER TargetId
        Cluster ID or target identifier for maintenance

    .PARAMETER Action
        Maintenance action: enable, disable, or validate

    .PARAMETER Start
        Maintenance window start time (ISO 8601 format)

    .PARAMETER End
        Maintenance window end time (ISO 8601 format)

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs')

    .PARAMETER DryRun
        Perform validation without executing changes

    .PARAMETER GitLabUrl
        GitLab instance URL (from GITLAB_URL environment variable)

    .PARAMETER ProjectId
        GitLab project ID (from GITLAB_PROJECT_ID environment variable)

    .PARAMETER TriggerToken
        GitLab CI trigger token (from GITLAB_TRIGGER_TOKEN environment variable)

    .PARAMETER GitRef
        Git reference/branch to trigger pipeline on (default: 'main')

    .PARAMETER CallbackUrl
        URL to send completion callback to (from MAINTENANCE_CALLBACK_URL)

    .PARAMETER CallbackApiKey
        API key for callback authentication (from MAINTENANCE_API_KEY)

    .PARAMETER TimeoutSeconds
        Timeout for waiting on pipeline completion (default: 600)

    .PARAMETER JobToken
        GitLab job token for API access (from GITLAB_JOB_TOKEN)

    .EXAMPLE
        Invoke-GitLabMaintenanceTrigger -TargetId 'CLUSTER01' -Action 'enable' -Start '2024-01-01T00:00:00Z' -End '2024-01-01T06:00:00Z'

    .EXAMPLE
        Invoke-GitLabMaintenanceTrigger -TargetId 'CLUSTER01' -Action 'disable' -DryRun
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $TargetId,
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
        $result = Send-GitLabMaintenanceRequest -Action $Action -TargetId $TargetId -Start $Start -End $End `
            -ConfigDir $ConfigDir -DryRun:$DryRun -GitLabUrl $GitLabUrl -ProjectId $ProjectId `
            -TriggerToken $TriggerToken -GitRef $GitRef -CallbackUrl $CallbackUrl -CallbackApiKey $CallbackApiKey `
            -TimeoutSeconds $TimeoutSeconds -JobToken $JobToken

        return @{
            Success      = $result.success
            PipelineId   = $result.pipeline_id
            TargetId     = $TargetId
            Action       = $Action
            GitLabUrl    = $result.gitlab_url
            WebUrl       = $result.web_url
            Message      = "GitLab pipeline triggered for target $TargetId"
        }
    } catch {
        return @{
            Success   = $false
            Error     = $_.Exception.Message
            TargetId  = $TargetId
            Action    = $Action
        }
    }
}

# vim: ts=4 sw=4 et