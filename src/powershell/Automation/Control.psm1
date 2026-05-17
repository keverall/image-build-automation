#
# Control.psm1 — Central Control Module.
#
# Mirrors Python automation/control.py exactly.
# Single entry point for all automation request surfaces:
#
#   Surface          Invocation
#   ────────────────  ──────────────────────────────────────────────────────────
#   Jenkins pipeline  Run-Jenkins  -Params <hashtable>   (maps BUILD_STAGE → request)
#   iRequest/ISAPI    Run-IRequest  -FormData <hashtable>  (cluster maintenance)
#   Scheduled task    Run-Scheduler -TaskParams <hashtable> (schtasks / cron calls)
#   Direct API        Start-AutomationOrchestrator -RequestType ... (PS cmdlets)
#
# After mirroring the Python file exactly:
#   Run-Jenkins()   ≡  run_jenkins()
#   Run-IRequest()  ≡  run_irequest()
#   Run-Scheduler() ≡  run_scheduler()
#

# ─────────────────────────────────────────────────────────────────────────────
# Error actions used in the whole control surface
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# Auto-import the Automation module so callers never have to Import-Module first
# ─────────────────────────────────────────────────────────────────────────────
$modRoot = Join-Path $PSScriptRoot '..\\\\Automation'
if (-not (Get-Module Automation -ErrorAction SilentlyContinue)) {
    try   { Import-Module $modRoot -Force -ErrorAction Stop }
    catch { Write-Warning "Control: Could not auto-import Automation module from $modRoot : $_" }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build JENKINS_PARAMS map equivalent to control.py stage_map
# ─────────────────────────────────────────────────────────────────────────────
function _Build-JenkinsParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $RawParams
    )
    $stage = $RawParams.Get_Item('BUILD_STAGE')
    $dryRun = [bool]($RawParams.Get_Item('DRY_RUN'))

    # Map Jenkins stage to PS orchestrator request type  ← mirrors stage_map in control.py
    $stageMap = @{
        firmware       = 'update_firmware'
        windows        = 'patch_windows'
        deploy         = 'deploy'
        scan           = 'opsramp_report'
        all            = 'build_iso'
    }
    $requestType = $stageMap[$stage]
    if (-not $requestType) { $requestType = 'build_iso' }

    return @{
        RequestType   = $requestType
        Params        = @{
            BaseIsoPath   = $RawParams.Get_Item('BASE_ISO_PATH')
            ServerFilter  = $RawParams.Get_Item('SERVER_FILTER')
            DeployMethod  = $RawParams.Get_Item('DEPLOY_METHOD')
            SkipDownload  = [bool]($RawParams.Get_Item('SKIP_DOWNLOAD'))
            DryRun        = $dryRun
        }
        Source        = 'jenkins'
        DryRun        = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build IREQUEST_PARAMS map equivalent to control.py from_irequest()
# ─────────────────────────────────────────────────────────────────────────────
function _Build-IRequestParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $FormData
    )
    $clusterId = $FormData.Get_Item('cluster_id')
    $action    = $FormData.Get_Item('action')
    if (-not $action) { $action = 'enable' }
    $dryRun = [bool]($FormData.Get_Item('dry_run'))

    return @{
        RequestType   = "maintenance_$action"
        Params        = @{
            ClusterId  = $clusterId
            Start      = $FormData.Get_Item('start')
            End        = $FormData.Get_Item('end')
            DryRun     = $dryRun
            Comment    = "iRequest $action - $clusterId"
        }
        Source        = 'irequest'
        DryRun        = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper — build SCHEDULER_PARAMS map equivalent to control.py from_scheduler()
# ─────────────────────────────────────────────────────────────────────────────
function _Build-SchedulerParams {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable] $TaskParams
    )
    $task   = $TaskParams.Get_Item('task')
    $dryRun = [bool]($TaskParams.Get_Item('dry_run'))

    # Map scheduler task to request type  ← mirrors task_map in control.py
    $taskMap = @{
        maintenance_disable = 'maintenance_disable'
        build_firmware      = 'update_firmware'
        build_windows       = 'patch_windows'
    }
    $requestType = $taskMap[$task]
    if (-not $requestType) { $requestType = $task }

    return @{
        RequestType   = $requestType
        Params        = @{
            ClusterId = $TaskParams.Get_Item('cluster_id')
            DryRun    = $dryRun
        }
        Source        = 'scheduler'
        DryRun        = $dryRun
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# New-JenkinsCtrl  — factory; mirrors Control.from_jenkins()
# Used externally before .Run() if you need the object
# ─────────────────────────────────────────────────────────────────────────────
function New-JenkinsCtrl {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][hashtable] $Params
    )
    $ctrl = _Build-JenkinsParams -RawParams $Params
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
            Errors      = ,$errors
            Source      = $Source
            RequestType = $RequestType
            Timestamp   = (Get-Date).ToString('o')
        }
    }
    $result = Start-AutomationOrchestrator -RequestType $RequestType -Params $Params
    $result['Source']      = $Source
    $result['RequestType'] = $RequestType
    $result['Timestamp']   = (Get-Date).ToString('o')
    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-Jenkins  — convenience; mirrors run_jenkins()
# Entry-point used by the Jenkins pipeline phase "Orchestration"
# ─────────────────────────────────────────────────────────────────────────────
function Run-Jenkins {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $Params
    )
    $ctrl = _Build-JenkinsParams -RawParams $Params
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'jenkins'
}

# ─────────────────────────────────────────────────────────────────────────────
# Run-IRequest  — convenience; mirrors run_irequest()
# Entry-point used by the iRequest ISAPI closure
# ─────────────────────────────────────────────────────────────────────────────
function Run-IRequest {
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
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)][hashtable] $TaskParams
    )
    $ctrl = _Build-SchedulerParams -TaskParams $TaskParams
    return _Execute -RequestType $ctrl.RequestType -Params $ctrl.Params -Source 'scheduler'
}

# ─────────────────────────────────────────────────────────────────────────────
# Export — strictly mirrors the control.py public API
# ─────────────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    # Factory  ← Control class alternative
    'New-JenkinsCtrl'
    'New-IRequestCtrl'
    'New-SchedulerCtrl'

    # Convenience singletons  ← run_* functions
    'Run-Jenkins'
    'Run-IRequest'
    'Run-Scheduler'
)

# vim: ts=4 sw=4 et
