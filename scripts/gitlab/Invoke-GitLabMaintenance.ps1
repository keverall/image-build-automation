#
# Invoke-GitLabMaintenance.ps1 — GitLab CI/CD entry point for Set-MaintenanceMode
# Called via GitLab pipeline trigger API from iRequest
#
# NOTE: This is a standalone script for GitLab CI execution, not a module function.
# The module loader skips it (no function definition). Use -File parameter in pwsh.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('enable', 'disable', 'validate')][string] $ACTION,
    [Parameter(Mandatory = $true)][string] $CLUSTER_ID,
    [string] $START = $null,
    [string] $END = $null,
    [string] $CONFIG_DIR = 'configs',
    [switch] $DRY_RUN,
    [switch] $NO_SCHEDULE,
    [string] $GITLAB_TOKEN = $env:GITLAB_JOB_TOKEN,
    [string] $CI_PROJECT_ID = $env:CI_PROJECT_ID,
    [string] $CI_PIPELINE_ID = $env:CI_PIPELINE_ID,
    [string] $CI_JOB_ID = $env:CI_JOB_ID,
    [string] $CALLBACK_URL = $env:MAINTENANCE_CALLBACK_URL,
    [string] $CALLBACK_API_KEY = $env:MAINTENANCE_API_KEY
)

$ErrorActionPreference = 'Stop'

# Check if being dot-sourced (don't run main code)
$isDotSourced = $MyInvocation.InvocationName -eq '.' -or $MyInvocation.InvocationName -eq ''

# ==============================================================================
# Callback Helper (defined first so it's available in main execution)
# ==============================================================================

function _Send-Callback {
    param(
        [string] $Url,
        [object] $Data,
        [string] $ApiKey
    )

    try {
        if ($Data -is [string]) {
            $body = $Data
        } elseif ($Data -is [hashtable]) {
            $body = $Data | ConvertTo-Json -Depth 10
        } else {
            $body = $Data | ConvertTo-Json -Depth 10
        }
        $headers = @{ "Content-Type" = "application/json" }
        if ($ApiKey) { $headers["X-API-Key"] = $ApiKey }

        Write-Host "Sending callback to $Url"
        Invoke-RestMethod -Uri $Url -Method Post -Body $body -Headers $headers -TimeoutSec 30
        Write-Host "Callback sent successfully"
    } catch {
        Write-Warning "Failed to send callback: $($_.Exception.Message)"
    }
}

# If dot-sourced, just exit (function definitions done below for future use)
if ($isDotSourced) { return }

# ==============================================================================
# Main Execution
# ==============================================================================

# Initialize GitLab context BEFORE sourcing module (script-level for audit)
$Script:GitlabContext = @{
    pipeline_id  = $CI_PIPELINE_ID
    job_id       = $CI_JOB_ID
    project_id   = $CI_PROJECT_ID
    triggered_by = 'GitLab CI/CD Pipeline Trigger'
}

# Import the main module
$modulePath = Join-Path $PSScriptRoot 'Set-MaintenanceMode.ps1'
if (Test-Path $modulePath) {
    . $modulePath
} else {
    Write-Error "Set-MaintenanceMode.ps1 not found at $modulePath"
    exit 1
}

# Initialize logging for GitLab CI environment
$logDir = Join-Path $PSScriptRoot '..\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

Write-Host "GitLab CI Maintenance Call - Pipeline: $CI_PIPELINE_ID, Job: $CI_JOB_ID"
Write-Host "Action: $ACTION, Cluster: $CLUSTER_ID"

# Build parameters for Set-MaintenanceMode
$params = @{
    Action     = $ACTION
    ClusterId  = $CLUSTER_ID
    ConfigDir  = $CONFIG_DIR
    DryRun     = [bool]$DRY_RUN
    NoSchedule = [bool]$NO_SCHEDULE
}

if ($START) { $params.Start = $START }
if ($END) { $params.End = $END }

# Execute maintenance operation
try {
    $result = Set-MaintenanceMode @params

    # Output result as JSON for GitLab CI job API consumption
    $output = @{
        pipeline_id    = $CI_PIPELINE_ID
        job_id         = $CI_JOB_ID
        cluster_id     = $CLUSTER_ID
        action         = $ACTION
        success        = $result.Success
        message        = $result.Message
        timestamp      = (Get-Date).ToString('o')
        dry_run        = [bool]$DRY_RUN
    }

    $outputJson = $output | ConvertTo-Json -Depth 10
    Write-Host "RESULT: $outputJson"

    # Write to artifact file for GitLab CI job API
    $artifactPath = Join-Path $logDir "maintenance_${CI_JOB_ID}_result.json"
    $outputJson | Set-Content -Path $artifactPath -Encoding UTF8

    if ($result.Success) {
        # Send callback on success
        if ($CALLBACK_URL) {
            _Send-Callback -Url $CALLBACK_URL -Data $output -ApiKey $CALLBACK_API_KEY
        }
        exit 0
    } else {
        # Send callback on failure
        if ($CALLBACK_URL) {
            $failOutput = @{
                pipeline_id = $CI_PIPELINE_ID
                job_id      = $CI_JOB_ID
                cluster_id  = $CLUSTER_ID
                action      = $ACTION
                success     = $false
                message     = "Maintenance $ACTION finished with errors"
                timestamp   = (Get-Date).ToString('o')
            }
            _Send-Callback -Url $CALLBACK_URL -Data $failOutput -ApiKey $CALLBACK_API_KEY
        }
        exit 1
    }
} catch {
    $errorOutput = @{
        pipeline_id = $CI_PIPELINE_ID
        job_id      = $CI_JOB_ID
        cluster_id  = $CLUSTER_ID
        action      = $ACTION
        success     = $false
        error       = $_.Exception.Message
        timestamp   = (Get-Date).ToString('o')
    }

    Write-Error "Maintenance operation failed: $($_.Exception.Message)"
    $errorOutput | ConvertTo-Json | Write-Host "ERROR_RESULT:"

    # Write error artifact
    $artifactPath = Join-Path $logDir "maintenance_${CI_JOB_ID}_error.json"
    $errorOutput | ConvertTo-Json | Set-Content -Path $artifactPath -Encoding UTF8

    # Send callback on error
    if ($CALLBACK_URL) {
        _Send-Callback -Url $CALLBACK_URL -Data $errorOutput -ApiKey $CALLBACK_API_KEY
    }

    exit 1
}

# vim: ts=4 sw=4 et