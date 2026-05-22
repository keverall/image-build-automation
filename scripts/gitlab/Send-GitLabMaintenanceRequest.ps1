#
# Send-GitLabMaintenanceRequest.ps1 — Trigger GitLab pipeline for maintenance
# Called from iRequest to initiate maintenance via GitLab CI/CD
#
# Usage:
#   Dot-sourced: . Send-GitLabMaintenanceRequest.ps1  # defines Send-GitLabMaintenanceRequest function
#   Direct: pwsh -File Send-GitLabMaintenanceRequest.ps1  # runs with param block
#

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][ValidateSet('enable', 'disable', 'validate')][string] $Action,
    [Parameter(Mandatory = $false)][string] $ClusterId,
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
    [string] $JobToken = $env:GITLAB_JOB_TOKEN,
    [switch] $SkipValidation
)

$ErrorActionPreference = 'Stop'

function _Trigger-Pipeline {
    param(
        [string] $GitLabUrl,
        [string] $ProjectId,
        [string] $TriggerToken,
        [string] $GitRef,
        [string] $Action,
        [string] $ClusterId,
        [string] $ConfigDir,
        [bool] $DryRun,
        [string] $Start,
        [string] $End
    )

    $payload = @{
        token    = $TriggerToken
        ref      = $GitRef
        variables = @{
            ACTION     = $Action
            CLUSTER_ID = $ClusterId
            CONFIG_DIR = $ConfigDir
            DRY_RUN    = if ($DryRun) { 'true' } else { 'false' }
        }
    }

    if ($Start) { $payload.variables.START = $Start }
    if ($End) { $payload.variables.END = $End }

    $uri = "$GitLabUrl/api/v4/projects/$ProjectId/trigger/pipeline"

    Write-Host "Triggering GitLab pipeline for cluster: $ClusterId, action: $Action"
    Write-Host "GitLab URL: $GitLabUrl, Project ID: $ProjectId"

    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $payload -ContentType 'application/x-www-form-urlencoded'

    return @{
        success      = $true
        pipeline_id  = $response.pipeline_id
        project_id   = $ProjectId
        gitsha       = $response.sha
        gitlab_url   = $GitLabUrl
        web_url      = $response.web_url
        created_at   = (Get-Date).ToString('o')
        cluster_id   = $ClusterId
        action       = $Action
    }
}

function Wait-GitLabMaintenanceResult {
    param(
        [Parameter(Mandatory = $true)][string] $GitLabUrl,
        [Parameter(Mandatory = $true)][string] $ProjectId,
        [Parameter(Mandatory = $true)][string] $PipelineId,
        [Parameter(Mandatory = $true)][string] $JobToken,
        [int] $TimeoutSeconds = 600,
        [int] $PollInterval = 10
    )

    $headers = @{ "JOB-TOKEN" = $JobToken }
    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)

    Write-Host "Waiting for GitLab pipeline $PipelineId to complete (timeout: ${TimeoutSeconds}s)..."

    while ((Get-Date) -lt $timeout) {
        try {
            $pipeline = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$ProjectId/pipelines/$PipelineId" -Headers $headers -Method Get

            if ($pipeline.status -eq 'success') {
                Write-Host "Pipeline completed successfully"
                break
            } elseif ($pipeline.status -in @('failed', 'canceled', 'skipped')) {
                Write-Error "Pipeline ended with status: $($pipeline.status)"
                return $null
            }

            Start-Sleep -Seconds $PollInterval
        } catch {
            Write-Warning "Failed to check pipeline status: $($_.Exception.Message)"
            Start-Sleep -Seconds $PollInterval
        }
    }

    try {
        $jobs = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$ProjectId/pipelines/$PipelineId/jobs" -Headers $headers -Method Get
        return @{ pipeline = $pipeline; jobs = $jobs }
    } catch {
        Write-Error "Failed to get job details: $($_.Exception.Message)"
        return $null
    }
}

function Send-MaintenanceCallback {
    param(
        [Parameter(Mandatory = $true)][string] $CallbackUrl,
        [Parameter(Mandatory = $true)][hashtable] $Result,
        [string] $ApiKey
    )

    if (-not $CallbackUrl) {
        Write-Warning "No callback URL configured"
        return $false
    }

    $body = $Result | ConvertTo-Json -Depth 10
    $headers = @{ "Content-Type" = "application/json" }
    if ($ApiKey) { $headers["X-API-Key"] = $ApiKey }

    try {
        Invoke-RestMethod -Uri $CallbackUrl -Method Post -Body $body -Headers $headers -TimeoutSec 30
        Write-Host "Callback sent successfully to $CallbackUrl"
        return $true
    } catch {
        Write-Error "Failed to send callback: $($_.Exception.Message)"
        return $false
    }
}

# Define the main function for when this script is dot-sourced
function Send-GitLabMaintenanceRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('enable', 'disable', 'validate')][string] $Action,
        [Parameter(Mandatory = $true)][string] $ClusterId,
        [string] $Start,
        [string] $End,
        [string] $ConfigDir = 'configs',
        [switch] $DryRun,
        [string] $GitLabUrl = $env:GITLAB_URL,
        [Parameter(Mandatory = $true)][string] $ProjectId,
        [Parameter(Mandatory = $true)][string] $TriggerToken,
        [string] $GitRef = 'main',
        [string] $CallbackUrl = $env:MAINTENANCE_CALLBACK_URL,
        [string] $CallbackApiKey = $env:MAINTENANCE_API_KEY,
        [int] $TimeoutSeconds = 600,
        [string] $JobToken = $env:GITLAB_JOB_TOKEN
    )

    if (-not $GitLabUrl) {
        Write-Error "GitLab URL not provided. Set GITLAB_URL environment variable or pass -GitLabUrl"
        return @{ success = $false; error = "GitLab URL not provided" }
    }

    try {
        $result = _Trigger-Pipeline -GitLabUrl $GitLabUrl -ProjectId $ProjectId -TriggerToken $TriggerToken -GitRef $GitRef `
                    -Action $Action -ClusterId $ClusterId -ConfigDir $ConfigDir -DryRun $DryRun -Start $Start -End $End

        Write-Host "Pipeline triggered successfully. Pipeline ID: $($result.pipeline_id)"
        Write-Host "Monitor at: $($result.web_url)"

        # Wait for completion and send callback if URL provided
        if ($CallbackUrl -and $JobToken) {
            $finalResult = Wait-GitLabMaintenanceResult -GitLabUrl $GitLabUrl -ProjectId $ProjectId -PipelineId $result.pipeline_id -JobToken $JobToken -TimeoutSeconds $TimeoutSeconds

            if ($finalResult) {
                $callbackPayload = @{
                    pipeline_id    = $result.pipeline_id
                    cluster_id     = $ClusterId
                    action         = $Action
                    success        = $finalResult.pipeline.status -eq 'success'
                    status         = $finalResult.pipeline.status
                    completed_at   = (Get-Date).ToString('o')
                    job_details    = $finalResult.jobs
                }

                Send-MaintenanceCallback -CallbackUrl $CallbackUrl -Result $callbackPayload -ApiKey $CallbackApiKey
                $result.status = $finalResult.pipeline.status
            }
        }

        return $result

    } catch {
        $errorResult = @{
            success     = $false
            error       = $_.Exception.Message
            gitlab_url  = $GitLabUrl
            project_id  = $ProjectId
            cluster_id  = $ClusterId
            action      = $Action
        }

        Write-Error "Failed to trigger GitLab pipeline: $($_.Exception.Message)"
        return $errorResult
    }
}

# Main execution - only run if executed directly with required params
if (-not $SkipValidation -and $Action -and $ClusterId -and $GitLabUrl -and $ProjectId -and $TriggerToken) {
    $result = Send-GitLabMaintenanceRequest -Action $Action -ClusterId $ClusterId -Start $Start -End $End `
        -ConfigDir $ConfigDir -DryRun:$DryRun -GitLabUrl $GitLabUrl -ProjectId $ProjectId `
        -TriggerToken $TriggerToken -GitRef $GitRef -CallbackUrl $CallbackUrl -CallbackApiKey $CallbackApiKey `
        -TimeoutSeconds $TimeoutSeconds -JobToken $JobToken

    if ($result.success) {
        exit 0
    } else {
        exit 1
    }
}

# vim: ts=4 sw=4 et