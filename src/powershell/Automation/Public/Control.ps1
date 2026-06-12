#
# Control.ps1 — Central Control Module.
#
# Single entry point for all automation request surfaces:
#
#   Surface          Invocation
#   ────────────────  ──────────────────────────────────────────────────────────
#   CI pipeline      Run-CIPipeline  -Params <hashtable>   (maps BUILD_STAGE → request)
#   iRequest/ISAPI    Run-IRequest  -FormData <hashtable>  (cluster maintenance)
#   Scheduled task    Run-Scheduler -TaskParams <hashtable> (schtasks / cron calls)
#   Direct API        Start-AutomationOrchestrator -RequestType ... (PS cmdlets)
#
# After mirroring the reference implementation exactly:
#   Run-CIPipeline() ≡  run_ci_pipeline()
#   Run-IRequest()  ≡  run_irequest()
#   Run-Scheduler() ≡  run_scheduler()
#

# ─────────────────────────────────────────────────────────────────────────────
# Error actions used in the whole control surface
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build CI_PARAMS map
# ─────────────────────────────────────────────────────────────────────────────
function _Build-CIParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $RawParams
    )
    $stage = $RawParams.Get_Item('BUILD_STAGE')
    $dryRun = [bool]($RawParams.Get_Item('DRY_RUN'))

    # Map CI stage to PS orchestrator request type
    $stageMap = @{
        firmware = 'update_firmware'
        windows  = 'patch_windows'
        deploy   = 'deploy'
        scan     = 'opsramp_report'
        all      = 'build_iso'
    }
    $requestType = $stageMap[$stage]
    if (-not $requestType) { $requestType = 'build_iso' }

    return @{
        RequestType = $requestType
        Params      = @{
            BaseIsoPath  = $RawParams.Get_Item('BASE_ISO_PATH')
            ServerFilter = $RawParams.Get_Item('SERVER_FILTER')
            DeployMethod = $RawParams.Get_Item('DEPLOY_METHOD')
            SkipDownload = [bool]($RawParams.Get_Item('SKIP_DOWNLOAD'))
            DryRun       = $dryRun
        }
        Source      = 'ci'
        DryRun      = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build IREQUEST_PARAMS map
# ─────────────────────────────────────────────────────────────────────────────
function _Build-IRequestParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $FormData
    )
    $clusterId = $FormData.Get_Item('cluster_id')
    $action = $FormData.Get_Item('action')
    if (-not $action) { $action = 'enable' }
    $dryRun = [bool]($FormData.Get_Item('dry_run'))

    return @{
        RequestType = "maintenance_$action"
        Params      = @{
            TargetId  = $clusterId
            Start     = $FormData.Get_Item('start')
            End       = $FormData.Get_Item('end')
            DryRun    = $dryRun
            Comment   = "iRequest $action - $clusterId"
        }
        Source      = 'irequest'
        DryRun      = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build SCHEDULER_PARAMS map
# ─────────────────────────────────────────────────────────────────────────────
function _Build-SchedulerParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $TaskParams
    )
    $task = $TaskParams.Get_Item('task')
    $dryRun = [bool]($TaskParams.Get_Item('dry_run'))

    # Map scheduler task to request type
    $taskMap = @{
        maintenance_disable = 'maintenance_disable'
        build_firmware      = 'update_firmware'
        build_windows       = 'patch_windows'
    }
    $requestType = $taskMap[$task]
    if (-not $requestType) { $requestType = $task }

    return @{
        RequestType = $requestType
        Params      = @{
            TargetId  = $TaskParams.Get_Item('target_id')
            DryRun    = $dryRun
        }
        Source      = 'scheduler'
        DryRun      = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# New-CIPipelineCtrl  — factory; mirrors Control.from_ci()
# Used externally before .Run() if you need the object
# ─────────────────────────────────────────────────────────────────────────────
function New-CIPipelineCtrl {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][hashtable] $Params
    )
    $ctrl = _Build-CIParams -RawParams $Params
    return [pscustomobject]$ctrl
}

# ─────────────────────────────────────────────────────────────────────────────
# New-IRequestCtrl  — factory; mirrors Control.from_irequest()
# ─────────────────────────────────────────────────────────────────────────────
function New-IRequestCtrl {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][hashtable] $FormData
    )
    $ctrl = _Build-IRequestParams -FormData $FormData
    return [pscustomobject]$ctrl
}

# ─────────────────────────────────────────────────────────────────────────────
# New-SchedulerCtrl  — factory; mirrors Control.from_scheduler()
# ─────────────────────────────────────────────────────────────────────────────
function New-SchedulerCtrl {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][hashtable] $TaskParams
    )
    $ctrl = _Build-SchedulerParams -TaskParams $TaskParams
    return [pscustomobject]$ctrl
}

# ─────────────────────────────────────────────────────────────────────────────
# _Execute  — internal helper: route to orchestrator, add metadata
# ─────────────────────────────────────────────────────────────────────────────
function _Execute {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]  $RequestType,
        [Parameter(Mandatory)][hashtable] $Params,
        [Parameter(Mandatory)][string]  $Source
    )
    $errors = _Validate-Request $RequestType $Params
    if ($errors) {
        return @{
            Success     = $false
            Errors      = , $errors
            Source      = $Source
            RequestType = $RequestType
            Timestamp   = Get-UtcTimestamp
        }
    }
    $result = Start-AutomationOrchestrator -RequestType $RequestType -Params $Params
    $result['Source'] = $Source
    $result['RequestType'] = $RequestType
    $result['Timestamp'] = Get-UtcTimestamp
    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-CIPipeline  — convenience; mirrors run_ci()
# Entry-point used by the CI pipeline phase "Orchestration"
# ─────────────────────────────────────────────────────────────────────────────
function Run-CIPipeline {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $Params
    )
    $ctrl = _Build-CIParams -RawParams $Params
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'ci'
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-IRequest  — convenience; mirrors run_irequest()
# Entry-point used by the iRequest ISAPI closure
# ─────────────────────────────────────────────────────────────────────────────
function Run-IRequest {
    <#
    .SYNOPSIS
        Execute iRequest maintenance mode operation.

    .DESCRIPTION
        Processes iRequest form data to enable or disable cluster maintenance mode.
        Maps cluster_id and action to orchestrator request types.

    .EXAMPLE
        Run-IRequest -FormData @{ cluster_id = 'CLUSTER01'; action = 'enable' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $FormData
    )
    $ctrl = _Build-IRequestParams -FormData $FormData
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'irequest'
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-Scheduler  — convenience; mirrors run_scheduler()
# Entry-point used by cron and Windows Scheduled Tasks
# ─────────────────────────────────────────────────────────────────────────────
function Run-Scheduler {
    <#
    .SYNOPSIS
        Execute scheduled task automation request.

    .DESCRIPTION
        Processes scheduled task parameters to execute automated maintenance operations.
        Maps task names to orchestrator request types for cron/scheduled task execution.

    .EXAMPLE
        Run-Scheduler -TaskParams @{ task = 'maintenance_disable'; dry_run = $false }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $TaskParams
    )
    $ctrl = _Build-SchedulerParams -TaskParams $TaskParams
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'scheduler'
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build GITLAB_PARAMS map for GitLab CI/CD maintenance trigger
# ─────────────────────────────────────────────────────────────────────────────
function _Build-GitLabParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $Params
    )
    return @{
        RequestType = "gitlab_maintenance"
        Params      = $Params
        Source      = 'gitlab'
        DryRun      = [bool]($Params.Get_Item('dry_run'))
 
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# New-GitLabCtrl  — factory; mirrors Control.from_gitlab()
# Used for GitLab CI/CD triggered maintenance operations
# ─────────────────────────────────────────────────────────────────────────────
function New-GitLabCtrl {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][hashtable] $Params
    )
    $ctrl = _Build-GitLabParams -Params $Params
    return [pscustomobject]$ctrl
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-GitLab  — convenience; triggers GitLab CI pipeline for maintenance
# Entry-point used by iRequest to trigger GitLab CI/CD instead of direct execution
# ─────────────────────────────────────────────────────────────────────────────
function Run-GitLab {
    <#
    .SYNOPSIS
        Trigger GitLab CI/CD pipeline for maintenance operations.

    .DESCRIPTION
        Initiates GitLab CI/CD pipeline for cluster maintenance instead of direct execution.
        Used by iRequest to delegate maintenance to GitLab pipelines.

    .EXAMPLE
        Run-GitLab -Params @{ cluster_id = 'CLUSTER01'; action = 'enable' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $Params
    )
    $ctrl = _Build-GitLabParams -Params $Params
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'gitlab'
}

# vim: ts=4 sw=4 et
