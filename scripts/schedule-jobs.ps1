#
# scripts/schedule-jobs.ps1
# ────────────────────────────────────────────────────────────────────────────
# Scheduled-task runner and registration helper for the PowerShell automation module.
#
# Wraps three surfaces — each has a PS-native AND a Python equivalent:
#
#   Surface           PS entry point                   Python entry point
#   ─────────────────  ──────────────────────────────  ───────────────────────────────────
#   Cron reporting    Run-Jenkins -OpsrampReport      python -m automation.control run_jenkins
#   Cron monitoring   Run-Jenkins -Monitor             same as above (ps BUILDSTAGE=deploy)
#   Direct / iRequest Run-IRequest -FormData <hTable>   from automation.control import run_irequest
#
# Only functions listed in Export-ModuleMember above are callable from outside.
# ────────────────────────────────────────────────────────────────────────────

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    # ── Parameter set: Run a named job ─────────────────────────────────────────
    [Parameter(ParameterSetName = 'Run', Mandatory = $true)]
    [ValidateSet('reporting','monitoring','firmware','windows','maintenance_enable','maintenance_disable','deploy','irequest','all')]
    [string] $Job,

    # ── Parameter set: Register a Windows Scheduled Task ───────────────────────
    [Parameter(ParameterSetName = 'Register', Mandatory = $true)]
    [switch] $Register,

    # ── Add / remove a maintenance task ────────────────────────────────────────
    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [switch] $Add,

    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [switch] $Remove,

    # ── Task options ───────────────────────────────────────────────────────────
    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [string] $TaskName,

    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [string] $TaskUser = 'SYSTEM',

    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [string] $RunTime = '02:00',      # Daily at 02:00 by default

    [Parameter(ParameterSetName = 'Register', Mandatory = $false)]
    [int]    $RepeatMinutes = 0,      # 0 = run once; >0 = repeat every N minutes

    # ── iRequest form passthrough ───────────────────────────────────────────────
    [Parameter(ParameterSetName = 'Run', Mandatory = $false)]
    [hashtable] $FormData,

    [Parameter(ParameterSetName = 'Run', Mandatory = $false)]
    [bool] $DryRun = $false,

    [Parameter(ParameterSetName = 'Run', Mandatory = $false)]
    [hashtable] $SchedulerParams,

    # ── Logging ────────────────────────────────────────────────────────────────
    [Parameter(Mandatory = $false)]
    [string] $LogDir = 'logs\\\\scheduled_jobs'
)

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-JobLog {
    [CmdletBinding()]
    param([string]$Message, [string]$Level = 'INFO')
    $ts   = Get-Date -Format o
    $line = "[$ts] [$Level] $Message"
    Write-Host $line

    $logDir = $using:LogDir   # PS 3+ scoping
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# ─── Job implementations ──────────────────────────────────────────────────────

function Invoke-JobReporting {
    <#
    .SYNOPSIS
        Scheduled OpsRamp + audit reporting job.
        Triggered daily (or hourly) by schtasks / cron.
        Equates to: python -m automation.control run_jenkins | stage=scan or stage=all
    #>
    [CmdletBinding()]
    param([bool]$DryRun)

    Write-JobLog '── Reporting job START ──'

    # Option A: use the orchestrator directly (equivalent to Python orchestrator.execute())
    $result = Start-AutomationOrchestrator -RequestType 'opsramp_report' -Params @{ DryRun = $DryRun }
    if ($result.Success) {
        Write-JobLog 'OpsRamp report completed.'
    } else {
        Write-JobLog "OpsRamp report failed: $($result.Error)", 'WARNING'
    }

    # Option B: full build pipeline via Control pattern (equivalent to Python run_jenkins with BUILD_STAGE=all)
    $ctrl = New-JenkinsCtrl -Params @{
        BUILD_STAGE  = 'all'
        DRY_RUN      = $DryRun
        SERVER_FILTER = ''
        DEPLOY_METHOD = 'ilo'
    }
    $ctrlResult = $ctrl | Run-Jenkins
    if ($ctrlResult.Success) {
        Write-JobLog "Reporting build pipeline succeeded."
    } else {
        Write-JobLog "Reporting build pipeline failed: $($ctrlResult.Error)", 'WARNING'
    }
    Write-JobLog '── Reporting job END ──'
}

function Invoke-JobMonitoring {
    <#
    .SYNOPSIS
        Scheduled installation monitoring job.
        Triggered every 5 min by schtasks.
        Equates to: python -m automation.control run_jenkins | stage=deploy
    #>
    [CmdletBinding()]
    param([bool]$DryRun)

    Write-JobLog '── Monitoring job START ──'

    $servers = Load-ServerList -Path 'configs\\\\server_list.txt' -IncludeDetails
    foreach ($srv in $servers) {
        Write-JobLog "Installing monitor for: $($srv.Hostname)"
        try {
            Start-InstallMonitor -Server $srv -UuidFile "output\\\\$($srv.Hostname).uuid" -Verbose -ErrorAction Stop
        } catch {
            Write-JobLog "Monitor error for $($srv.Hostname): $($_.Exception.Message)" -Level 'WARNING'
        }
    }
    Write-JobLog '── Monitoring job END ──'
}

function Invoke-JobFirmware {
    <#
    .SYNOPSIS
        Scheduled firmware ISO build (nightly).
        Equates to: python -m automation.control run_jenkins | BUILD_STAGE=firmware
    #>
    [CmdletBinding()]
    param([bool]$DryRun)

    Write-JobLog '── Firmware build job START ──'
    $ctrl = New-JenkinsCtrl -Params @{
        BUILD_STAGE   = 'firmware'
        DRY_RUN       = $DryRun
        SKIP_DOWNLOAD = $false
    }
    $result = $ctrl | Run-Jenkins
    if ($result.Success) { Write-JobLog 'Firmware build OK.' }
    else                  { Write-JobLog "Firmware build FAILED: $($result.Error)" -Level 'ERROR' }
    Write-JobLog '── Firmware build job END ──'
}

function Invoke-JobWindows {
    <#
    .SYNOPSIS
        Scheduled Windows ISO build (nightly).
        Equates to: python -m automation.control run_jenkins | BUILD_STAGE=windows
    #>
    [CmdletBinding()]
    param([bool]$DryRun)

    Write-JobLog '── Windows patch job START ──'
    $ctrl = New-JenkinsCtrl -Params @{
        BUILD_STAGE   = 'windows'
        DRY_RUN       = $DryRun
        BASE_ISO_PATH = 'C:\\\\ISOs\\\\Windows_Server_2022.iso'
    }
    $result = $ctrl | Run-Jenkins
    if ($result.Success) { Write-JobLog 'Windows patch OK.' }
    else                  { Write-JobLog "Windows patch FAILED: $($result.Error)" -Level 'ERROR' }
    Write-JobLog '── Windows patch job END ──'
}

function Invoke-JobMaintenanceDisable {
    <#
    .SYNOPSIS
        Scheduled maintenance disable (end-of-window cleanup).
        Equates to: python -m automation.control run_scheduler | task=maintenance_disable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ClusterId
    )

    Write-JobLog "── Maintenance disable for cluster '$ClusterId' START ──"
    $ctrl = New-SchedulerCtrl -TaskParams @{
        task       = 'maintenance_disable'
        cluster_id = $ClusterId
        dry_run    = $DryRun
    }
    $result = $ctrl | Run-Scheduler
    if ($result.Success) { Write-JobLog 'Maintenance disable OK.' }
    else                  { Write-JobLog "Maintenance disable FAILED: $($result.Error)" -Level 'ERROR' }
    Write-JobLog '── Maintenance disable END ──'
}

function Invoke-JobIRequest {
    <#
    .SYNOPSIS
        iRequest / BMC ISAPI form entry point.
        Wraps Run-IRequest using posted form data.
        Equates to Python: from automation.control import run_irequest; run_irequest(form_data)
    #>
    [CmdletBinding()]
    param([hashtable]$FormData)

    Write-JobLog '── iRequest entry START ──'
    $result = Run-IRequest -FormData $FormData
    if ($result.Success) { Write-JobLog "iRequest OK: $($result.RequestType) for cluster $($result.Params.ClusterId)" }
    else                  { Write-JobLog "iRequest FAILED: $($result.Error)" -Level 'ERROR' }
    Write-JobLog '── iRequest entry END ──'
    return $result
}

# ─── Dispatch ────────────────────────────────────────────────────────────────

$jobMap = @{
    reporting          = { Invoke-JobReporting -DryRun:$DryRun }
    monitoring         = { Invoke-JobMonitoring -DryRun:$DryRun }
    firmware           = { Invoke-JobFirmware   -DryRun:$DryRun }
    windows            = { Invoke-JobWindows    -DryRun:$DryRun }
    maintenance_disable= { Invoke-JobMaintenanceDisable -ClusterId $SchedulerParams.cluster_id }
    irequest           = { Invoke-JobIRequest    -FormData  $FormData            }
    all                = {
                              Invoke-JobReporting   -DryRun:$DryRun
                              Invoke-JobMonitoring  -DryRun:$DryRun
                          }
}

if ($PSCmdlet.ParameterSetName -eq 'Run') {
    if (-not $jobMap.ContainsKey($Job)) {
        Write-Error "Unknown job: $Job. Available: $($jobMap.Keys -join ', ')"
        exit 1
    }
    $jobMap[$Job].Invoke()
    exit 0
}

# ─── Register / Remove Windows Scheduled Tasks ────────────────────────────────

if ($PSCmdlet.ParameterSetName -eq 'Register') {
    # Build schtasks.exe command
    $taskCmd  = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$(Resolve-Path $PSCommandPath)`" -Job `"$Job`""
    $schedOps = @('/Create', '/TN', $TaskName, '/TR', $taskCmd, '/RL', 'HIGHEST', '/F')

    if ($RunTime -match '^\d{2}:\d{2}$') {
        $schedOps += @('/SC', 'DAILY', '/ST', $RunTime)
    } else {
        $schedOps += @('/SC', 'ONCE', '/ST', '00:00', '/SD', (Get-Date -Format 'yyyy/MM/dd'))
    }
    if ($RepeatMinutes -gt 0) {
        $schedOps += @('/RI', "$RepeatMinutes /DU", "00:$($RepeatMinutes.ToString('D2')):00")
    }
    $schedOps += @('/RU', $TaskUser)

    if ($Remove) {
        Write-JobLog "Removing scheduled task: $TaskName"
        & schtasks.exe /Delete /TN $TaskName /F 2>&1 | Out-Null
    } elseif ($Add -or $Register) {
        Write-JobLog "Registering scheduled task: $TaskName  ($Job at $RunTime)"
        & schtasks.exe @schedOps 2>&1 | ForEach-Object { Write-JobLog $_ }
    }

    # Show existing tasks
    Write-JobLog 'Current automation tasks:'
    & schtasks.exe /Query /TN 'HPE-*' /F /V /FO LIST 2>&1 | Out-String -Stream |
        Where-Object { $_ -match 'TaskName|Status|Next Run' } |
        ForEach-Object { Write-JobLog $_ }
    exit 0
}

# vim: ts=4 sw=4 et
