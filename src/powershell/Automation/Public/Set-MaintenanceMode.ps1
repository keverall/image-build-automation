#
# Set-MaintenanceMode.ps1 — SCOM / iLO / OpenView maintenance-mode orchestrator
# Equivalent of reference implementation cli/maintenance_mode.py (~956 lines)
#
# Contains: Set-MaintenanceMode wrapper function, helper functions, manager classes,
#           and a script-mode guard for direct pwsh invocation.
#

# ---- Script-mode param block (MUST be at top of script) ----
# Supports two output modes:
# 1. Human-readable (default): for direct command-line usage
# 2. JSON: for iRequest/REST API integration (when -Json flag is used)
param(
    [switch]$Json
)

# ---- Module import for script mode ----
# Only import if:
# 1. The Automation module is not already loaded in this session
# 2. We are NOT being dot-sourced by the module itself (InvocationName == '.')
# This prevents circular imports when the module loads this script via dot-source.
if (-not (Get-Module -Name 'Automation' -ErrorAction SilentlyContinue) -and $MyInvocation.InvocationName -ne '.') {
    # Check if we're being invoked directly (not dot-sourced)
    if ($MyInvocation.InvocationName -match '\.ps1$') {
        # Running directly with pwsh -File - import the module
        $modulePath = Join-Path $PSScriptRoot '..\Automation.psd1'
        Import-Module $modulePath -Force -WarningAction SilentlyContinue
    }
}

function Set-MaintenanceMode {
    <#
    .SYNOPSIS
        Enable, disable, or validate maintenance mode for a server cluster.
        Callable from the module Router.

    .DESCRIPTION
        Orchestrates maintenance-mode operations across SCOM 2015, HPE iLO,
        and HPE OpenView for a logical cluster defined in clusters_catalogue.json.
        Supports immediate enable/disable as well as scheduled windows with
        automatic disable via Windows Task Scheduler.
        Integrates with OpsRamp for metric/alert emission and can send email
        notifications.  The function is the PowerShell implementation.
        automation.cli.maintenance_mode module.

    .PARAMETER Action
        'enable', 'disable', or 'validate'.

    .PARAMETER ClusterId
        Cluster identifier string.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs').

    .PARAMETER Start
        Maintenance start datetime string (default: now) format YYYY-MM-DD HH:MM .

    .PARAMETER End
        Maintenance end datetime string format YYYY-MM-DD HH:MM .

    .PARAMETER DryRun
        Simulate without making changes.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now

    .EXAMPLE
        Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 2026-05-17 12:00 -End 2026-05-17 13:00 (default UTC format YYYY-MM-DD HH:MM )

    .EXAMPLE
        Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][ValidateSet('enable', 'disable', 'validate')][string] $Action = 'enable',
        [Parameter(Mandatory, Position = 1)][string] $ClusterId,
        [string] $ConfigDir = 'configs',
        [string] $Start = $null,
        [string] $End = $null,
        [switch] $DryRun,
        [switch] $NoSchedule
    )

    $ErrorActionPreference = 'Continue'

    # Use passed ConfigDir param or fall back to script-level variable
    $EffectiveConfigDir = if ($PSBoundParameters.ContainsKey('ConfigDir')) { $ConfigDir } else { $Script:ConfigDir }

    # Load configs
    $clustersCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'scom_config.json')           -Required:$false
    $openviewCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'openview_config.json')       -Required:$false
    $oneviewCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'oneview_config.json')         -Required:$false
    $emailCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg = Import-JsonConfig -Path (Join-Path $EffectiveConfigDir 'opsramp_config.json') -Required:$false

    $clustersMap = $clustersCfg.Get_Item('clusters')
    if (-not $clustersMap -or -not $clustersMap.ContainsKey($ClusterId)) {
        Write-Verbose "Cluster ID '$ClusterId' not found in catalogue."
        return @{ Success = $false; Error = "Cluster ID '$ClusterId' not found in catalogue." }
    }
    $clusterDef = $clustersMap[$ClusterId]

    # Validate cluster definition
    $requiredFields = @('display_name', 'servers', 'scom_group', 'environment')
    $missing = foreach ($f in $requiredFields) { if (-not $clusterDef.ContainsKey($f)) { $f } }
    if ($missing) { Write-Verbose "Cluster definition missing required fields: $($missing -join ', ')"; return @{ Success = $false; Error = "Missing fields: $($missing -join ', ')" } }
    $servers = $clusterDef.Get_Item('servers')
    if (-not ($servers -is [System.Collections.IEnumerable]) -or -not ($servers | Measure-Object).Count) {
        Write-Verbose "Cluster 'servers' must be a non-empty list."
        return @{ Success = $false; Error = "Cluster 'servers' must be a non-empty list." }
    }

    # VALIDATE action
    if ($Action -eq 'validate') {
        Write-Host "Cluster '$ClusterId' validated. Servers: $($servers -join ', ')"
        $audit = @{ cluster_id = $ClusterId; action = $Action; dry_run = [bool]$DryRun; timestamp_start = Get-UtcTimestamp; steps = @{}; success = $true }
        _Save-AuditRecord $audit (Join-Path $Script:MaintLogDir "validate_${ClusterId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json")
        return @{ Success = $true; Message = "Cluster '$ClusterId' validated." }
    }

    # Resolve Start / End
    $startDt = $null; $endDt = $null
    if ($Action -eq 'enable') {
        if ($Start) { $startDt = _Parse-Datetime $Start }
        else { $startDt = Get-Date }
        if ($End) { $endDt = _Parse-Datetime $End }
        else {
            $schedule = $clusterDef.Get_Item('schedule')
            if ($schedule) { $endDt = _Compute-NextWorkStart $schedule $startDt }
            else { Write-Verbose 'No --end and no schedule defined in cluster.'; return @{ Success = $false; Error = 'No end time or schedule defined.' } }
        }
        if ($endDt -le $startDt) { Write-Verbose 'End time must be after start time.'; return @{ Success = $false; Error = 'End time must be after start time.' } }
        $duration = $endDt - $startDt
        Write-Verbose "Maintenance window: $startDt → $endDt (duration: $duration)"
    }

    # Initialise managers
    $scomMgr = $null; try { $scomMgr = [SCOMManager]::new($scomCfg) } catch { Write-Warning "SCOM manager unavailable: $($_.Exception.Message)" }
    $iloMgr = [ILOManager]::new($clusterDef)
    $ovMgr = [OpenViewClient]::new($openviewCfg, $clusterDef)
    $oneviewMgr = $null; try { $oneviewMgr = [OneViewManager]::new($oneviewCfg, $clusterDef) } catch { Write-Warning "OneView manager unavailable: $($_.Exception.Message)" }
    $emailer = [EmailNotifier]::new($emailCfg)

    $opsrampClient = $null
    if ($opsrampCfg) { try { $opsrampClient = [OpsRamp_Client]::new((Join-Path $Script:ConfigDir 'opsramp_config.json')) } catch { Write-Debug "OpsRamp init failed" } }

    # Execute action
    $overallOk = $true
    $audit = @{ cluster_id = $ClusterId; action = $Action; dry_run = [bool]$DryRun; timestamp_start = Get-UtcTimestamp; steps = @{}; success = $true }
    $utcStart = $null
    $utcEnd = $null

    if ($Action -eq 'enable') {
        # SCOM
        $scomOk = $false; $scomInfo = ''
        if ($scomMgr) {
            $durHrs = $duration.TotalSeconds / 3600.0
            $comment = "iRequest Maintenance: $ClusterId"
            $serversArr = [string[]]@($clusterDef.Get_Item('servers'))
            $scomRes = $scomMgr.EnterMaintenance(
                $clusterDef.Get_Item('scom_group'),
                $duration, $comment, [bool]$DryRun,
                $serversArr, $true)
            $scomOk = $scomRes.Success
            $scomInfo = if ($scomRes.Output) { ($scomRes.Output -join "`n") } else { '' }
        }
        $audit.steps['scom'] = @{ Success = $scomOk; Info = $scomInfo }
        if (-not $scomOk) { $overallOk = $false }

        # iLO
        $iloRes = $iloMgr.SetMaintenanceWindow($clusterDef, $startDt, $endDt, [bool]$DryRun)
        $iloOk = $iloRes.Success
        $audit.steps['ilo'] = @{ Success = $iloOk; Details = $iloRes.Details }
        if (-not $iloOk) { $overallOk = $false }

        # OpenView
        $ovRes = $ovMgr.SetMaintenance($clusterDef, $startDt, $endDt, [bool]$DryRun)
        $ovOk = $ovRes.Success; $ovMsg = $ovRes.Message
        $audit.steps['openview'] = @{ Success = $ovOk; Message = $ovMsg }
        if (-not $ovOk) { $overallOk = $false }

        # OneView (HPE OneView for iLO)
        if ($oneviewMgr) {
            $oneviewRes = $oneviewMgr.SetMaintenanceWindow($clusterDef, $startDt, $endDt, [bool]$DryRun)
            $oneviewOk = $oneviewRes.Success; $oneviewMsg = $oneviewRes.Message
            $audit.steps['oneview'] = @{ Success = $oneviewOk; Message = $oneviewMsg }
            if (-not $oneviewOk) { $overallOk = $false }
        }

        # Email
        $emailOk = $emailer.SendMaintenanceNotification('enabled', $clusterDef, $servers, $startDt, $endDt, [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk -and -not $DryRun) { $overallOk = $false }

        # OpsRamp
        $opsOk = $false
        if ($opsrampClient -and -not $DryRun) {
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 1, @{ cluster = $ClusterId; environment = $clusterDef.Get_Item('environment') })
            }
            $opsOk = $opsrampClient.SendAlert($ClusterId, 'maintenance.enabled', 'INFO',
                "Maintenance enabled for $ClusterId",
                @{ cluster = $clusterDef.Get_Item('display_name'); servers = $servers;
                    start = Convert-ToUtcIso8601 $startDt; end = Convert-ToUtcIso8601 $endDt
                })
            $opsrampClient.SendEvent($ClusterId, 'maintenance.enabled',
                "Maintenance window started for $($clusterDef.Get_Item('display_name'))",
                @{ cluster = $ClusterId; action = 'enable' })
        }
        $audit.steps['opsramp'] = @{ Success = $opsOk }

        # Scheduled Task
        if ($IsWindows -and -not $NoSchedule) {
            $taskName = "MaintenanceDisable-$ClusterId"
            $scriptAbs = (Resolve-Path $PSScriptRoot).Path
            $stTime = $endDt.ToString('HH:mm')
            $sdDate = $endDt.ToString('yyyy/MM/dd')
            schtasks /Delete /TN $taskName /F 2>$null | Out-Null
            try {
                schtasks /Create /TN $taskName /TR "`"$($PSHOME)\pwsh.exe`" `"$scriptAbs`" -Action disable -ClusterId $ClusterId -NoSchedule" `
                    /SC ONCE /ST $stTime /SD $sdDate /RL HIGHEST /RU SYSTEM /F 2>&1 | Out-Null
                $audit.steps.scheduled_task = @{ Created = $true }
            }
            catch { $audit.steps.scheduled_task = @{ Created = $false; Error = $_.Exception.Message }; $overallOk = $false }
        }
        
        # Capture computed UTC times for output
        $utcStart = Convert-ToUtcIso8601 $startDt
        $utcEnd = Convert-ToUtcIso8601 $endDt
    }
    elseif ($Action -eq 'disable') {
        # Email disable notification
        $emailOk = $emailer.SendMaintenanceNotification('disabled', $clusterDef, $servers, $null, (Get-Date), [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk) { $overallOk = $false }

        # OpsRamp
        if ($opsrampClient -and -not $DryRun) {
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 0, @{ cluster = $ClusterId })
            }
            $opsrampClient.SendAlert($ClusterId, 'maintenance.disabled', 'INFO',
                "Maintenance disabled for $ClusterId",
                @{ completed_at = Get-UtcTimestamp })
            $opsrampClient.SendEvent($ClusterId, 'maintenance.disabled',
                "Maintenance window ended for $($clusterDef.Get_Item('display_name'))",
                @{ cluster = $ClusterId; action = 'disable' })
        }

        # Clean up scheduled task
        if ($IsWindows) {
            $taskName = "MaintenanceDisable-$ClusterId"
            try { schtasks /Delete /TN $taskName /F 2>&1 | Out-Null; $audit.steps.scheduled_task_cleanup = @{ Deleted = $true } }
            catch { $audit.steps.scheduled_task_cleanup = @{ Deleted = $false; Error = $_.Exception.Message } }
        }
    }

    $audit.success = $overallOk
    $auditFile = Join-Path $Script:MaintLogDir "$($Action)_${ClusterId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
    _Save-AuditRecord $audit $auditFile

    # Build detailed completion message
    $clusterName = $clusterDef.Get_Item('display_name') ?? $ClusterId
    $serverCount = ($servers | Measure-Object).Count
    $dryRunNote = if ($DryRun) { " [DRY-RUN]" } else { "" }
    
    $detailMessage = if ($overallOk) {
        if ($Action -eq 'enable') {
            $durationStr = if ($duration) { " (Duration: $($duration.Hours)h $($duration.Minutes)m)" } else { "" }
            "Maintenance $Action completed for cluster '$clusterName' ($serverCount servers)$durationStr$dryRunNote. Window: $utcStart -> $utcEnd"
        } elseif ($Action -eq 'disable') {
            "Maintenance $Action completed for cluster '$clusterName' ($serverCount servers)$dryRunNote. Maintenance mode deactivated."
        } else {
            "Validation completed for cluster '$clusterName' ($serverCount servers). Configuration is valid."
        }
    } else {
        "Maintenance $Action finished with errors for cluster '$clusterName'$dryRunNote. Check audit: $auditFile"
    }
    
    if ($overallOk) { Write-Host $detailMessage }
    else { Write-Warning $detailMessage }
    
    return @{ 
        Success = $overallOk
        Message = $detailMessage
        StartTimeUtc = if ($Action -eq 'enable') { $utcStart } else { $null }
        EndTimeUtc = if ($Action -eq 'enable') { $utcEnd } else { $null }
        ClusterId = $ClusterId
        ClusterName = $clusterName
        ServerCount = $serverCount
        DryRun = [bool]$DryRun
        AuditFile = $auditFile
    }
}

# ---- Constants (always defined so classes referencing them work on dot-source) ----
# Determine base directory - handle both module import and direct script execution
# Script is at: src/powershell/Automation/Public/Set-MaintenanceMode.ps1
# When dot-sourced by module: $PSScriptRoot = module dir (src/powershell/Automation/)
# When run directly: $PSScriptRoot = script dir (src/powershell/Automation/Public/)
# Only set if not already set (e.g., by module import)
if (-not $Script:BaseDir -or $Script:BaseDir -eq '') {
    $current = $PSScriptRoot
    if (-not $current -and $MyInvocation.MyCommand.Path) {
        $current = Split-Path $MyInvocation.MyCommand.Path
    }
    if (-not $current) { $current = Get-Location }
    while ($current -and -not (Test-Path (Join-Path $current 'kilo.json')) -and -not (Test-Path (Join-Path $current 'Makefile'))) {
        $parent = Split-Path $current
        if ($parent -eq $current -or -not $parent) { break }
        $current = $parent
    }
    if (Test-Path $current) {
        $Script:BaseDir = (Resolve-Path $current).Path
    } else {
        $Script:BaseDir = $current
    }
}
# Only set config dir if not already set
if (-not $Script:ConfigDir -or $Script:ConfigDir -eq '') {
    $Script:ConfigDir = Join-Path $Script:BaseDir 'configs'
}
if (-not $Script:MaintLogDir -or $Script:MaintLogDir -eq '') {
    $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
    if ($isTesting) {
        $Script:MaintLogDir = Join-Path $Script:BaseDir 'generated/logs/testing'
    } else {
        $Script:MaintLogDir = Join-Path $Script:BaseDir 'generated/logs/audit'
    }
}
if (-not $Script:DistList -or $Script:DistList -eq '') {
    $Script:DistList = Join-Path $Script:BaseDir 'maintenance_distribution_list.txt'
}

if (-not (Test-Path $Script:MaintLogDir)) { Ensure-DirectoryExists -Path $Script:MaintLogDir }

# ---- Logging ----
Initialize-Logging -LogFile 'maintenance.log'

# ---- Parse datetime helpers ----
function _Parse-Datetime([string]$s) {
    if ($s.ToLower() -eq 'now') { return Get-Date }
    
    # Handle relative time offsets like +1hour, +30minutes, +2days
    if ($s -match '^\+([\d]+)(seconds?|minutes?|hours?|days?)$') {
        $value = [int]$Matches[1]
        $unit = $Matches[2].ToLower()
        $offset = switch ($unit) {
            'second' { [TimeSpan]::FromSeconds($value) }
            'seconds' { [TimeSpan]::FromSeconds($value) }
            'minute' { [TimeSpan]::FromMinutes($value) }
            'minutes' { [TimeSpan]::FromMinutes($value) }
            'hour' { [TimeSpan]::FromHours($value) }
            'hours' { [TimeSpan]::FromHours($value) }
            'day' { [TimeSpan]::FromDays($value) }
            'days' { [TimeSpan]::FromDays($value) }
            default { [TimeSpan]::Zero }
        }
        return (Get-Date).Add($offset)
    }
    
    $s2 = $s.Replace('T', ' ')
    $formats = @('yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm')
    foreach ($fmt in $formats) {
        try { return [DateTime]::ParseExact($s2, $fmt, $null) } catch { continue }
    }
    try { return [DateTime]::Parse($s2) } catch { Write-Debug "DateTime parse failed" }
    throw "Invalid datetime format '$s'. Use 'now', '+1hour', or 'YYYY-MM-DD HH:MM[:SS]'."
}

function _Compute-NextWorkStart([hashtable]$Schedule, [DateTime]$After) {
    $workStartStr = $Schedule.Get_Item('work_start') ?? '08:00'
    $workStart = [DateTime]::ParseExact($workStartStr, 'HH:mm', $null).TimeOfDay
    $dayMap = @{ Mon = 0; Tue = 1; Wed = 2; Thu = 3; Fri = 4; Sat = 5; Sun = 6 }
    $workDays = @($Schedule.Get_Item('work_days') ?? @('Mon', 'Tue', 'Wed', 'Thu', 'Fri')) | ForEach-Object { $dayMap[$_] }
    $candidate = $After.Date
    while ($true) {
        if ($candidate.DayOfWeek -in $workDays) {
            $dt = $candidate.Date + $workStart
            if ($dt -gt $After) { return $dt }
        }
        $candidate = $candidate.AddDays(1)
    }
}

function _Save-AuditRecord([hashtable]$Audit, [string]$Path) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    # Add GitLab context if available
    if ($Script:GitlabContext) {
        $Audit.gitlab_context = $Script:GitlabContext
    }
    
    $Audit | ConvertTo-Json -Depth 64 | Set-Content -Path $Path -Encoding UTF8 -Force
    # Append to master log
    $ts = Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ'
    $master = Join-Path $Script:MaintLogDir "maintenance_audit_${ts}_INFO.log"
    $Audit | ConvertTo-Json -Depth 64 | Add-Content $master -Encoding UTF8
}

# ---- SCOMManager ----
class SCOMManager {
    [hashtable] $Config
    [string]    $MgmtServer
    [string]    $ModuleName
    [bool]      $UseWinRM
    [hashtable] $Cred
    [int]       $ScomVersion       # 2012 | 2016 | 2019 | 2025
    [bool]      $RestApiReady      # $true for 2019 UR1+ and 2025

    SCOMManager([hashtable]$Config) {
        $this.Config = $Config
        $this.MgmtServer = $Config.Get_Item('management_server') ?? 'localhost'
        $this.ModuleName = $Config.Get_Item('powershell_module') ?? 'OperationsManager'
        $this.UseWinRM = [bool]($Config.Get_Item('use_winrm') ?? $false)
        $this.Cred = $null
        $this.ScomVersion = 0
        $this.RestApiReady = $false
        $credCfg = $Config.Get_Item('credentials')
        if ($credCfg) {
            $uenv = $credCfg.Get_Item('username_env')
            $penv = $credCfg.Get_Item('password_env')
            if ($uenv -and $penv) {
                $u = [System.Environment]::GetEnvironmentVariable($uenv)
                $p = [System.Environment]::GetEnvironmentVariable($penv)
                if ($u -and $p) { $this.Cred = @{ username = $u; password = $p } }
            }
        }
        # Detect SCOM version and REST-API readiness on first use (lazy, on demand)
    }

    [hashtable] _RunPs([string]$Script) {
        if ($this.UseWinRM) {
            if (-not $this.Cred) { return @{ Success = $false; Output = 'WinRM credentials not configured' } }
            return Invoke-PowerShellWinRM -Script $Script `
                -Server $this.MgmtServer -Username $this.Cred['username'] -Password $this.Cred['password']
        }
        else {
            return Invoke-PowerShellScript -Script $Script
        }
    }

    [void] _DetectVersion() {
        if ($this.ScomVersion -gt 0) { return }
        if (-not $this.Cred) { return }
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$null = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$verLine = (Get-SCOMManagementServer | Select-Object -First 1).Version
`$ver = if (`$verLine) { `$verLine.Trim() } else { 'unknown' }
# Test whether REST /authenticate endpoint responds
`$restOk = `$false
try {
    `$base = "http://$($this.MgmtServer)/OperationsManager"
    `$null = Invoke-WebRequest -Uri "`$base/authenticate" -Method Head `
        -TimeoutSec 5 -UseDefaultCredentials -ErrorAction Stop
    `$restOk = `$true
} catch { `$restOk = `$false }
Write-Output "SCOM_VERSION: `$ver"
Write-Output "SCOM_REST_READY: `$restOk"
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            foreach ($line in ($r.Output -split "`n")) {
                $trimmed = $line.Trim()
                if ($trimmed -match '^SCOM_VERSION:\s*(\d+)')         { $this.ScomVersion = [int]$Matches[1] }
                if ($trimmed -match '^SCOM_REST_READY:\s*(True|true)') { $this.RestApiReady = $true }
            }
        }
        if ($this.ScomVersion -eq 0) { $this.ScomVersion = 2016 }   # safe default
        Write-Verbose "SCOM version detected: $($this.ScomVersion), REST ready: $($this.RestApiReady)"
    }

    [object[]] GetGroupMembers([string]$GroupDisplayName) {
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction SilentlyContinue
if (-not `$group) { Write-Error "Group '$GroupDisplayName' not found"; exit 1 }
`$instances = Get-SCOMClassInstance -Group `$group
`$instances | ForEach-Object { `$_.Name }
"@
        $r = $this._RunPs($script)
        if (-not $r.Success) { return @() }
        return ($r.Output -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
    }

    [hashtable] EnterMaintenance([string]$GroupDisplayName, [TimeSpan]$Duration,
        [string]$Comment, [bool]$DryRun = $false,
        [string[]]$ServerHostnames = $null,
        [bool]$UseClusterMode = $false) {

        if ($DryRun) {
            if ($UseClusterMode) {
                Write-Verbose "[DRY RUN] Would enable SCOM maintenance for group '$GroupDisplayName', Cluster mode (servers: $($ServerHostnames -join ', '))"
            } else {
                Write-Verbose "[DRY RUN] Would enable SCOM maintenance for group '$GroupDisplayName'"
            }
            return @{ Success = $true; Output = @() }
        }

        $this._DetectVersion()

        $endTimeUtc = (Get-Date).ToUniversalTime().Add($Duration)
        $endTimeStr = $endTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss')
        $safeComment = $Comment.Replace("'", "''")

        # ── SCOM 2019 UR1+ and 2025: use REST API ────────────────────────────
        if ($this.ScomVersion -ge 2019 -and $this.RestApiReady) {
            return $this._EnterMaintenanceRest($endTimeStr, $safeComment, $ServerHostnames, $UseClusterMode)
        }

        # ── 2012 / 2016 / 2019-without-REST: use PowerShell cmdlets ───────────
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -EndTimeStr $endTimeStr -Reason 'PlannedOther' -Comment $safeComment -Operation 'start' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                -EndTimeStr $endTimeStr -Reason 'PlannedOther' -Comment $safeComment -Operation 'start'
        }
        $r = $this._RunPs($script)
        if ($r.Success) {
            Write-Verbose "SCOM maintenance enabled: $($r.Output)"
            return @{ Success = $true; Output = @($r.Output) }
        }
        Write-Error "SCOM maintenance failed: $($r.Output)"
        return @{ Success = $false; Output = @($r.Output) }
    }

    [bool] ExitMaintenance([string]$GroupDisplayName, [bool]$DryRun = $false,
        [string[]]$ServerHostnames = $null,
        [bool]$UseClusterMode = $false) {

        if ($DryRun) {
            if ($UseClusterMode) {
                Write-Verbose "[DRY RUN] Would disable SCOM maintenance, Cluster mode for $($ServerHostnames -join ', ')"
            } else {
                Write-Verbose "[DRY RUN] Would disable SCOM maintenance for group '$GroupDisplayName'"
            }
            return $true
        }

        $this._DetectVersion()

        # ── SCOM 2019 UR1+ and 2025: use REST API ────────────────────────────
        if ($this.ScomVersion -ge 2019 -and $this.RestApiReady) {
            $r = $this._ExitMaintenanceRest($ServerHostnames, $UseClusterMode)
            return $r.Success
        }

        # ── 2012 / 2016 / 2019-without-REST: use PowerShell cmdlets ───────────
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -Comment 'exit' -Operation 'stop' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                -Comment 'exit' -Operation 'stop'
        }
        $r = $this._RunPs($script)
        Write-Verbose "SCOM maintenance disable output: $($r.Output)"
        return $r.Success
    }

    # ════════════════════════════════════════════════════════════════════════
    # PRIVATE — SCOM REST API helpers (2019 UR1+ and 2025 only)
    # ════════════════════════════════════════════════════════════════════════

    [hashtable] _EnterMaintenanceRest([string]$EndTimeStr, [string]$Comment,
        [string[]]$ServerHostnames, [bool]$UseClusterMode) {

        if (-not $this.Cred) { return @{ Success = $false; Output = 'No SCOM REST credentials' } }

        # The REST script authenticates, resolves monitoring object IDs, calls POST /ScheduleMaintenance
        $serverJson = ($ServerHostnames | ForEach-Object { "`"$($_.Replace('"','\"'))`"" }) -join ","
        $script = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$server     = "$($this.MgmtServer)"
`$user       = "$($this.Cred['username'])"
`$pass       = "$($this.Cred['password'])"
`$baseUrl    = "http://`$server/OperationsManager"
`$endTime    = [DateTime]::Parse('$EndTimeStr')
`$endIso     = `$endTime.ToString('yyyy-MM-ddTHH:mm:ss')
`$comment    = '$Comment'

# ── Authenticate and obtain CSRF token ────────────────────────────────────
`$headers   = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
`$headers.Add('Content-Type','application/json; charset=utf-8')
`$bodyRaw   = "(Network):`$user:`$pass"
`$bytes     = [System.Text.Encoding]::UTF8.GetBytes(`$bodyRaw)
`$encAuth   = [Convert]::ToBase64String(`$bytes)
`$jsonBody  = `$encAuth | ConvertTo-Json
`$session   = `$null
try {
    `$resp = Invoke-WebRequest -Method POST -Uri "`$baseUrl/authenticate" `
        -Headers `$headers -Body `$jsonBody -UseDefaultCredentials -SessionVariable session
} catch {
    Write-Error "SCOM REST authentication failed: `$(`$_.Exception.Message)"
    exit 1
}
`$csrf = `$session.Cookies.GetCookies(`$baseUrl) | Where-Object { `$_.Name -eq 'SCOM-CSRF-TOKEN' }
if (`$csrf) { `$headers.Add('SCOM-CSRF-TOKEN', [System.Web.HttpUtility]::UrlDecode(`$csrf.Value)) }

# ── Resolve monitoring object IDs ─────────────────────────────────────────
`$ids     = [System.Collections.ArrayList]::new()
`$servers = @($serverJson)
foreach (`$srvName in `$servers) {
    try {
        `$bodyCriteria = "DisplayName LIKE '%`$srvName%'" | ConvertTo-Json
        `$classResp = Invoke-WebRequest -Uri "`$baseUrl/data/class/monitors" `
            -Method Post -Body `$bodyCriteria -Headers `$headers -WebSession `$session `
            -ErrorAction Stop
        `$classData = `$classResp.Content | ConvertFrom-Json
        foreach (`$obj in `$classData) {
            if (`$obj.Id) { [void]`$ids.Add([string]`$obj.Id) }
        }
    } catch {
        Write-Warning "Could not resolve ID for `$srvName : `$(`$_.Exception.Message)"
    }
}
if (`$ids.Count -eq 0) {
    Write-Error "No monitoring object IDs resolved for: $($ServerHostnames -join ', ')"
    Write-Error "Please verify the servers are monitored by this SCOM management group."
    exit 1
}

# ── Call POST /ScheduleMaintenance ────────────────────────────────────────
`$durationMin = [int](`$endTime - (Get-Date)).TotalMinutes
`$freqType = 8   # 8 = OneTimeSchedule as per REST API docs
`$reqBody = @{
    scheduleName          = 'MaintenanceMode_PowerShell'
    monitoringObjectsId   = @(`$ids)
    startTime             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
    duration              = [Math]::Max(1, `$durationMin)
    freqType              = `$freqType
    category              = 0
    scheduleEffectiveFrom = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
    recursive             = `$true
    enabled               = `$true
    comment               = `$comment
} | ConvertTo-Json -Depth 5
try {
    `$result = Invoke-WebRequest -Uri "`$baseUrl/ScheduleMaintenance" `
        -Method Post -Body `$reqBody -Headers `$headers -ContentType 'application/json' `
        -WebSession `$session -ErrorAction Stop
    Write-Host "SCOM REST maintenance scheduled. IDs: `$(`$result.Content)"
    exit 0
} catch {
    Write-Error "SCOM REST maintenance failed: `$(`$_.Exception.Message)"
    exit 1
}
"@
        $r = $this._RunPs($script)
        return @{ Success = $r.Success; Output = @($r.Output) }
    }

    [hashtable] _ExitMaintenanceRest([string[]]$ServerHostnames, [bool]$UseClusterMode) {
        if (-not $this.Cred) { return @{ Success = $false; Output = 'No SCOM REST credentials' } }

        $serverJson = ($ServerHostnames | ForEach-Object { "`"$($_.Replace('"','\"'))`"" }) -join ","
        # Exit maintenance for REST SCOM:
        # Use Start-SCOMMaintenanceMode PowerShell cmdlet to disable (mirrors stop flow)
        # because the REST API does not expose a direct maintenanceMode 'stop' endpoint.
        # The OperationsManager PowerShell module is installed on the same mgmt server.
        $endTimeStr = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
        $script = if ($UseClusterMode) {
            New-ScomMaintenanceScript -ServerHostnames $ServerHostnames `
                -Comment 'exit' -Operation 'stop' -UseClusterMode
        } else {
            New-ScomMaintenanceScript -GroupDisplayName '' `
                -Comment 'exit' -Operation 'stop' -UseClusterMode
        }
        if (-not $script) {
            $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$($this.MgmtServer)" -ErrorAction Stop
`$endTime = [DateTime]::Parse('$EndTimeStr')
`$stopped = @()
`$servers = @($serverJson)
foreach (`$srvName in `$servers) {
    `$inst = Get-SCOMClassInstance -Name "*`$srvName*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (`$inst -and `$inst.InMaintenanceMode) {
        try { `$inst.StopMaintenanceMode(); `$stopped += `$srvName } catch { Write-Warning "`$srvName: `$(`$_.Exception.Message)" }
    } else { Write-Host "`$srvName not in maintenance - skipping" }
}
if (`$stopped.Count -gt 0) { Write-Host "Stopped for `$(`$stopped.Count) servers" } else { Write-Host "None in maintenance" }
"@
        }
        $r = $this._RunPs($script)
        return @{ Success = $r.Success; Output = @($r.Output) }
    }
}

# ---- OneViewManager ----
class OneViewManager {
    [hashtable] $Config
    [string]    $Appliance
    [string]    $ModuleName
    [bool]      $UseWinRM
    [hashtable] $Cred
    [string]    $ScopeName

    OneViewManager([hashtable]$Config, [hashtable]$ClusterDef) {
        $this.Config = $Config
        $ovConfig = $Config.Get_Item('oneview') ?? @{}
        $this.Appliance = $ovConfig.Get_Item('appliance') ?? 'oneview.example.com'
        $this.ModuleName = $ovConfig.Get_Item('module_name') ?? 'HPOneView.Managed'
        $this.UseWinRM = [bool]($ovConfig.Get_Item('use_winrm') ?? $true)
        $this.Cred = $null
        $this.ScopeName = $ClusterDef.Get_Item('oneview_scope') ?? $ClusterDef.Get_Item('display_name')
        
        $credCfg = $ovConfig.Get_Item('credentials')
        if ($credCfg) {
            $uenv = $credCfg.Get_Item('username_env') ?? 'ONEVIEW_USER'
            $penv = $credCfg.Get_Item('password_env') ?? 'ONEVIEW_PASSWORD'
            $u = [System.Environment]::GetEnvironmentVariable($uenv)
            $p = [System.Environment]::GetEnvironmentVariable($penv)
            if ($u -and $p) { $this.Cred = @{ username = $u; password = $p } }
        }
    }

    [hashtable] _RunPs([string]$Script) {
        if ($this.UseWinRM) {
            if (-not $this.Cred) { return @{ Success = $false; Output = 'WinRM credentials not configured' } }
            return Invoke-PowerShellWinRM -Script $Script `
                -Server $this.Appliance -Username $this.Cred['username'] -Password $this.Cred['password']
        }
        else {
            return Invoke-PowerShellScript -Script $Script
        }
    }

    [hashtable] SetMaintenanceWindow([hashtable]$ClusterDef, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun = $false) {
        if ($DryRun) {
            Write-Verbose "[DRY RUN] Would enable OneView maintenance for scope '$($this.ScopeName)'"
            return @{ Success = $true; Output = "DRY RUN: OneView maintenance for $($this.ScopeName)" }
        }
        
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
Connect-OVMgmt -Appliance "$($this.Appliance)" -Credential (New-Object System.Management.Automation.PSCredential("$($this.Cred['username'])", (ConvertTo-SecureString "$($this.Cred['password'])" -AsPlainText -Force))) -ErrorAction Stop
`$scope = Get-OVScope -Name "$($this.ScopeName)" -ErrorAction SilentlyContinue
if (-not `$scope) { Write-Error "Scope '$($this.ScopeName)' not found"; exit 1 }
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (-not `$s.MaintenanceModeEnabled) {
        Enable-OVMaintenanceMode -InputObject `$s -Async -ErrorAction Stop
        Write-Host "OneView maintenance enabled: `$(`$s.Name)"
    }
}
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            return @{ Success = $true; Output = $r.Output }
        }
        Write-Error "OneView maintenance failed: $($r.Output)"
        return @{ Success = $false; Output = $r.Output }
    }

    [hashtable] StopMaintenance([hashtable]$ClusterDef, [bool]$DryRun = $false) {
        if ($DryRun) {
            Write-Verbose "[DRY RUN] Would disable OneView maintenance for scope '$($this.ScopeName)'"
            return @{ Success = $true; Output = "DRY RUN: OneView disable for $($this.ScopeName)" }
        }
        
        $script = @"
Import-Module $($this.ModuleName) -ErrorAction Stop
Connect-OVMgmt -Appliance "$($this.Appliance)" -Credential (New-Object System.Management.Automation.PSCredential("$($this.Cred['username'])", (ConvertTo-SecureString "$($this.Cred['password'])" -AsPlainText -Force))) -ErrorAction Stop
`$scope = Get-OVScope -Name "$($this.ScopeName)" -ErrorAction SilentlyContinue
if (-not `$scope) { Write-Error "Scope '$($this.ScopeName)' not found"; exit 1 }
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (`$s.MaintenanceModeEnabled) {
        Disable-OVMaintenanceMode -InputObject `$s -Async -ErrorAction Stop
        Write-Host "OneView maintenance disabled: `$(`$s.Name)"
    }
}
"@
        $r = $this._RunPs($script)
        if ($r.Success) {
            return @{ Success = $true; Output = $r.Output }
        }
        Write-Error "OneView maintenance stop failed: $($r.Output)"
        return @{ Success = $false; Output = $r.Output }
    }
}

# ---- ILOManager ----
class ILOManager {
    [hashtable] $ClusterDef
    [string]    $Method
    [int]       $TimeoutSeconds
    [string]    $GlobalUser
    [string]    $GlobalPassword

    ILOManager([hashtable]$ClusterDef) {
        $this.ClusterDef = $ClusterDef
        $this.Method = 'rest'
        $this.TimeoutSeconds = 30
        $uCred = Get-IloCredentials
        $this.GlobalUser = $uCred[0]
        $this.GlobalPassword = $uCred[1]
    }

    [hashtable] _GetIloCredentials([string]$ServerName) {
        $credMap = $this.ClusterDef.Get_Item('ilo_credentials')
        if ($credMap -and $credMap.ContainsKey($ServerName)) {
            $info = $credMap[$ServerName]
            $username = $info.Get_Item('username') ?? $this.GlobalUser
            $penv = $info.Get_Item('password_env')
            $password = if ($penv) { (Get-CredentialSecret -EnvVarName $penv -Default $this.GlobalPassword) } else { $this.GlobalPassword }
            return @{ Username = $username; Password = $password }
        }
        return @{ Username = $this.GlobalUser; Password = $this.GlobalPassword }
    }

    [string] _GetIloIp([string]$ServerName) {
        $m = $this.ClusterDef.Get_Item('ilo_addresses')
        return if ($m) { $m.Get_Item($ServerName) } else { $null }
    }

    [hashtable] _CreateWindowRest([string]$IloIp, [string]$Username, [SecureString]$Password,
        [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        if ($DryRun) { return @{ Success = $true; Msg = "[DRY RUN] Would create iLO maintenance window on $IloIp from $StartDt to $EndDt" } }
        $baseUrl = "https://$IloIp/rest/v1"
        # Quick reachability test via Invoke-RestMethod
        try {
            $null = Invoke-RestMethod -Uri "$baseUrl/systems/1" -Method Get `
                -Credential (New-Object System.Management.Automation.PSCredential($Username,
                    (ConvertTo-SecureString $Password -AsPlainText -Force))) `
                -TimeoutSec $this.TimeoutSeconds -ErrorAction Stop
        }
        catch {
            return @{ Success = $false; Msg = "iLO connection failed: $($_.Exception.Message)" }
        }
        $windowName = "maintenance_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
        $body = @{
            Name      = $windowName
            StartTime = $StartDt.ToString('o')
            EndTime   = $EndDt.ToString('o')
            Repeat    = 'Once'
        }
        try {
            $resp = Invoke-RestMethod -Uri "$baseUrl/maintenancewindows" -Method Post -Body ($body | ConvertTo-Json) `
                -ContentType 'application/json' `
                -Credential (New-Object System.Management.Automation.PSCredential($Username,
                    (ConvertTo-SecureString $Password -AsPlainText -Force))) `
                -TimeoutSec $this.TimeoutSeconds -ErrorAction Stop
            return @{ Success = $true; Msg = "Created iLO maintenance window (id=$($resp.Id)) on $IloIp" }
        }
        catch {
            return @{ Success = $false; Msg = "iLO API error: $($_.Exception.Message)" }
        }
    }

    [hashtable] SetMaintenanceWindow([hashtable]$ClusterDef, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        if ($DryRun) {
            $fake = @{}
            foreach ($s in ($ClusterDef.Get_Item('servers') ?? @())) {
                $fake[$s] = @{ Success = $true; Msg = '[DRY RUN]'; IloIp = ($ClusterDef.Get_Item('ilo_addresses').Get_Item($s) ?? 'N/A') }
            }
            return @{ Success = $true; Details = $fake }
        }
        $servers = $ClusterDef.Get_Item('servers') ?? @()
        $iloMap = $ClusterDef.Get_Item('ilo_addresses')
        if (-not $iloMap) {
            Write-Warning 'No iLO addresses defined; skipping iLO'
            return @{ Skipped = $true; Reason = 'No iLO addresses' }
        }
        $ok = $true
        $detail = @{}
        foreach ($s in $servers) {
            $ip = $iloMap.Get_Item($s)
            if (-not $ip) { Write-Warning "No iLO IP for $s; skipping"; $detail[$s] = @{ Success = $false; Error = 'Missing iLO IP' }; $ok = $false; continue }
            $uCred = $this._GetIloCredentials($s)
            if (-not $uCred.Username -or -not $uCred.Password) {
                Write-Warning "Missing iLO credentials for $s; skipping"
                $detail[$s] = @{ Success = $false; Error = 'Missing credentials' }; $ok = $false; continue
            }
            $r = $this._CreateWindowRest($ip, $uCred.Username, $uCred.Password, $StartDt, $EndDt, $false)
            $detail[$s] = @{ Success = $r.Success; Msg = $r.Msg; IloIp = $ip }
            if (-not $r.Success) { $ok = $false }
        }
        return @{ Success = $ok; Details = $detail }
    }
}

# ---- OpenViewClient ----
class OpenViewClient {
    [hashtable] $Config
    [string]    $BaseUrl
    [string]    $ApiVersion
    [string]    $Endpoint
    [int]       $TimeoutSeconds
    [string]    $AuthType
    [string]    $Username
    [string]    $Password
    [bool]      $UseCli
    [string]    $CliPath

    OpenViewClient([hashtable]$Config, [hashtable]$ClusterDef) {
        $ovConfig = $Config.Get_Item('openview') ?? @{}
        $this.Config = $ovConfig
        $this.BaseUrl = $ovConfig.Get_Item('default_api_url') ?? 'https://openview.example.com/api'
        $this.ApiVersion = $ovConfig.Get_Item('api_version') ?? 'v1'
        $this.Endpoint = $ovConfig.Get_Item('maintenance_endpoint') ?? '/maintenance'
        $this.TimeoutSeconds = ($ovConfig.Get_Item('timeout_seconds') ?? 30)
        $authCfg = $ovConfig.Get_Item('auth') ?? @{}
        $this.AuthType = $authCfg.Get_Item('type') ?? 'basic'
        $uCreds = Get-OpenViewCredentials
        $this.Username = $uCreds[0]
        $this.Password = $uCreds[1]
        $this.UseCli = [bool]($ovConfig.Get_Item('use_cli') ?? $false)
        $this.CliPath = $ovConfig.Get_Item('cli_path') ?? 'ovcall'
    }

    [hashtable] SetMaintenance([hashtable]$ClusterDef, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        $nodeIdsMap = $ClusterDef.Get_Item('openview_node_ids')
        if (-not $nodeIdsMap) { return @{ Success = $true; Message = 'No OpenView nodes configured' } }
        $nodeIds = [System.Collections.ArrayList]@($nodeIdsMap.Values)
        if ($this.UseCli) { return $this._SetViaCli($nodeIds, $StartDt, $EndDt, $ClusterDef.Get_Item('display_name'), $DryRun) }
        return $this._SetViaRest($nodeIds, $StartDt, $EndDt, $ClusterDef.Get_Item('display_name'), $DryRun)
    }

    [hashtable] _SetViaRest([object[]]$NodeIds, [DateTime]$StartDt, [DateTime]$EndDt, [string]$ClusterName, [bool]$DryRun) {
        if ($DryRun) { return @{ Success = $true; Message = "[DRY RUN] OV REST for $($NodeIds -join ',')" } }
        $body = @{
            nodes      = $NodeIds
            start_time = $StartDt.ToString('o')
            end_time   = $EndDt.ToString('o')
            comment    = "Maintenance for $ClusterName"
            cluster    = $ClusterName
        }
        try {
            $null = Invoke-RestMethod -Uri ($this.BaseUrl.TrimEnd('/') + '/' + $this.ApiVersion.TrimStart('/') + $this.Endpoint) `
                -Method Post -Body ($body | ConvertTo-Json -Depth 5) `
                -Credential (New-Object System.Management.Automation.PSCredential($this.Username,
                    (ConvertTo-SecureString $this.Password -AsPlainText -Force))) `
                -TimeoutSec $this.TimeoutSeconds -ErrorAction Stop
            return @{ Success = $true; Message = "OpenView maintenance set for $($NodeIds.Count) nodes" }
        }
        catch {
            return @{ Success = $false; Message = "OpenView REST call failed: $($_.Exception.Message)" }
        }
    }

    [hashtable] _SetViaCli([object[]]$NodeIds, [DateTime]$StartDt, [DateTime]$EndDt, [string]$ClusterName, [bool]$DryRun) {
        if ($DryRun) { return @{ Success = $true; Message = "[DRY RUN] OV CLI for $($NodeIds -join ',')" } }
        $startStr = $StartDt.ToString('yyyy-MM-dd HH:mm:ss')
        $endStr = $EndDt.ToString('yyyy-MM-dd HH:mm:ss')
        $nodesStr = ($NodeIds -join ',')
        $cmd = "$($this.CliPath) -c `"set maintenance -nodes $nodesStr -start '$startStr' -end '$endStr' -comment '$ClusterName'`""
        $r = Invoke-Command -Command (Split-PipelineCmd $cmd) -TimeoutSeconds $this.TimeoutSeconds
        $msg = if ($r.Success) { $r.Output } else { $r.StandardError }
        return @{ Success = $r.Success; Message = $msg }
    }
}

# ---- EmailNotifier ----
class EmailNotifier {
    [hashtable] $Config
    [string]    $SmtpServer
    [int]       $SmtpPort
    [bool]      $UseTls
    [bool]      $UseSsl
    [string]    $FromAddr
    [hashtable] $Templates
    [bool]      $UseSimple
    [string[]]  $SimpleRecipients
    [hashtable] $DistLists

    EmailNotifier([hashtable]$Config) {
        $this.Config = $Config.Get_Item('email') ?? @{}
        $this.SmtpServer = $this.Config.Get_Item('smtp_server') ?? 'localhost'
        $this.SmtpPort = ($this.Config.Get_Item('smtp_port') ?? 25)
        $this.UseTls = [bool]($this.Config.Get_Item('use_tls') ?? $false)
        $this.UseSsl = [bool]($this.Config.Get_Item('use_ssl') ?? $false)
        $this.FromAddr = $this.Config.Get_Item('from_address') ?? 'maintenance-bot@example.com'
        $this.Templates = $this.Config.Get_Item('templates') ?? @{}
        $this.UseSimple = $false
        $this.DistLists = $this.Config.Get_Item('distribution_lists') ?? @{}
        if (Test-Path $Script:DistList) {
            $this.SimpleRecipients = Get-Content $Script:DistList | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() }
            $this.UseSimple = ($this.SimpleRecipients.Count -gt 0)
        }
    }

    [string[]] _GetRecipients([string]$Action) {
        if ($this.UseSimple) { return $this.SimpleRecipients }
        $key = "maintenance_$Action"
        if ($this.DistLists.ContainsKey($key)) { return $this.DistLists[$key] }
        return @()
    }

    [bool] SendMaintenanceNotification([string]$Action, [hashtable]$Cluster, [string[]]$Servers,
        [Nullable[DateTime]]$StartTime, [Nullable[DateTime]]$EndTime, [bool]$DryRun) {
        $recipients = $this._GetRecipients($Action)
        if (-not $recipients) {
            Write-Warning "No distribution list for action '$Action'; skipping email"
            return $false
        }
        $clusterName = $Cluster.Get_Item('display_name') ?? $Cluster.Get_Item('scom_group') ?? 'Unknown'
        $environment = $Cluster.Get_Item('environment') ?? 'unknown'
        $startStr = if ($StartTime -and $StartTime -ne [DateTime]::MinValue) { $StartTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
        $endStr = if ($EndTime -and $EndTime -ne [DateTime]::MinValue) { $EndTime.ToString('yyyy-MM-dd HH:mm:ss') }  else { 'N/A' }
        $tplVars = @{
            cluster_name    = $clusterName
            environment     = $environment
            servers         = ($Servers -join ', ')
            start_time      = $startStr
            end_time        = $endStr
            triggered_by    = 'iRequest'
            additional_info = if ($Action -eq 'enabled') { 'Maintenance mode is now ACTIVE.' }
            elseif ($Action -eq 'disabled') { 'Maintenance mode has ENDED.' }
            else { "Maintenance action: $Action" }
        }
        $subjTpl = $this.Templates.Get_Item("subject_$Action") ?? "Maintenance {action} - {cluster_name} ({environment})"
        $subject = $subjTpl.Replace('{action}', $Action).Replace('{cluster_name}', $clusterName).Replace('{environment}', $environment)
        $bodyTpl = $this.Templates.Get_Item('body_template') ??
        "Dear Team,`n`nMaintenance window for cluster '$clusterName' has $Action.`n`nStart: $startStr`nEnd: $endStr`nServers: $($Servers -join ', ')`n`n$($tplVars['additional_info'])`n`nRegards,`nMaintenance Bot"
        $bodyAction = if ($Action -eq 'enabled') { 'been ENABLED' } elseif ($Action -eq 'disabled') { 'been DISABLED' } else { $Action }
        $body = $bodyTpl.Replace('{action}', $bodyAction)
        foreach ($k in $tplVars.Keys) { $body = $body.Replace("{${k}}", $tplVars[$k]); $subject = $subject.Replace("{${k}}", $tplVars[$k]) }

        if ($DryRun) {
            Write-Verbose "[DRY RUN] Email to: $($recipients -join ', ')"
            Write-Verbose "Subject: $subject"
            Write-Verbose "Body: $body"
            return $true
        }

        try {
            $mailMsg = New-Object System.Net.Mail.MailMessage($this.FromAddr, $recipients[0])
            foreach ($r in $recipients) { $mailMsg.To.Add($r) | Out-Null }
            $mailMsg.Subject = $subject
            $mailMsg.Body = $body
            $mailMsg.IsBodyHtml = $false
            $smtp = if ($this.UseSsl) {
                [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
            }
            else {
                $s = [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
                if ($this.UseTls) { $s.EnableSsl = $true }
                $s
            }
            if ($this.Username) {
                $sec = ConvertTo-SecureString $this.Password -AsPlainText -Force
                $smtp.Credentials = New-Object System.Management.Automation.PSCredential($this.Username, $sec)
            }
            $smtp.Send($mailMsg)
            Write-Verbose "Notification email sent to $($recipients -join ', ')"
            return $true
        }
        catch {
            Write-Error "Failed to send email: $($_.Exception.Message)"
            return $false
        }
    }
}

# ---- Helper: split a command string into an array (mirrors subprocess list style) ----
function Split-PipelineCmd([string]$CommandString) {
    # Minimal split: respects double-quoted groups
    $tokens = [System.Management.Automation.CommandParameterTokenizer]::new(
        [System.Management.Automation.Language.TokenKind]::Generic
    ).Tokenize($CommandString, [ref]$null)
    return , $CommandString   # fallback: raw string passed through as single command
}

# ---- Main CLI logic (script mode only) ----
# Supports two output modes:
# 1. Human-readable (default): for direct command-line usage
# 2. JSON: for iRequest/REST API integration (when -Json flag is used)

if ($MyInvocation.InvocationName -ne '.' -and $null -ne $MyInvocation.PSScriptRoot) {
    $ErrorActionPreference = 'Continue'

    $boundParams = @{}
    $i = 0
    while ($i -lt $args.Count) {
        $arg = $args[$i]
        switch ($arg) {
            '-Action'    { if ($i + 1 -lt $args.Count) { $boundParams['Action'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '--Action'   { if ($i + 1 -lt $args.Count) { $boundParams['Action'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '-ClusterId' { if ($i + 1 -lt $args.Count) { $boundParams['ClusterId'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '--ClusterId'{ if ($i + 1 -lt $args.Count) { $boundParams['ClusterId'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '-ConfigDir' { if ($i + 1 -lt $args.Count) { $boundParams['ConfigDir'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '--ConfigDir'{ if ($i + 1 -lt $args.Count) { $boundParams['ConfigDir'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '-Start'     { if ($i + 1 -lt $args.Count) { $boundParams['Start'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '--Start'    { if ($i + 1 -lt $args.Count) { $boundParams['Start'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '-End'       { if ($i + 1 -lt $args.Count) { $boundParams['End'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '--End'      { if ($i + 1 -lt $args.Count) { $boundParams['End'] = $args[$i + 1]; $i += 2 } else { $i++ } }
            '-DryRun'    { $boundParams['DryRun'] = $true; $i++ }
            '--DryRun'   { $boundParams['DryRun'] = $true; $i++ }
            '-NoSchedule'{ $boundParams['NoSchedule'] = $true; $i++ }
            '--NoSchedule'{ $boundParams['NoSchedule'] = $true; $i++ }
            '-WhatIf'    { $boundParams['DryRun'] = $true; $i++ }
            '--WhatIf'   { $boundParams['DryRun'] = $true; $i++ }
            default      { $i++ }
        }
    }

    if (-not $boundParams.ContainsKey('Action')) {
        $boundParams['Action'] = 'enable'
    }
    if (-not $boundParams.ContainsKey('DryRun')) {
        $boundParams['DryRun'] = $false
    }
    if (-not $boundParams.ContainsKey('NoSchedule')) {
        $boundParams['NoSchedule'] = $false
    }

    # Use provided ConfigDir or fall back to script-level variable
    $effectiveConfigDir = $boundParams['ConfigDir'] ?? $Script:ConfigDir
    # Resolve relative paths
    if (-not [System.IO.Path]::IsPathRooted($effectiveConfigDir)) {
        $effectiveConfigDir = Join-Path (Get-Location) $effectiveConfigDir
    }
    $resolvedPath = Resolve-Path $effectiveConfigDir -ErrorAction SilentlyContinue
    if ($resolvedPath) {
        $effectiveConfigDir = $resolvedPath
    }

    # Load configs
    $clustersCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'scom_config.json')           -Required:$false
    $openviewCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'openview_config.json')       -Required:$false
    $emailCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'opsramp_config.json') -Required:$false

    $result = Set-MaintenanceMode @boundParams

    # Add request metadata for iRequest traceability
    $result['request_type'] = "maintenance_$($boundParams['Action'])"
    $result['timestamp'] = Get-UtcTimestamp
    $result['timestamp_local'] = Get-LocalTimestamp
    $result['source'] = 'direct'

    if ($Json) {
        # Output JSON for iRequest/REST API integration
        $result | ConvertTo-Json -Depth 64
        exit $(if ($result.Success) { 0 } else { 1 })
    }

    # Human-readable output for direct command-line usage
    $logEntry = @{
        timestamp = $result['timestamp']
        timestamp_local = $result['timestamp_local']
        action = $boundParams['Action']
        cluster_id = $boundParams['ClusterId']
        config_dir = $boundParams['ConfigDir'] ?? $Script:ConfigDir
        start_time_utc = if ($result['StartTimeUtc']) { $result['StartTimeUtc'] } else { 'N/A' }
        end_time_utc = if ($result['EndTimeUtc']) { $result['EndTimeUtc'] } else { 'N/A' }
        dry_run = $boundParams['DryRun']
        no_schedule = $boundParams['NoSchedule']
        script_path = $MyInvocation.MyCommand.Path
    }
    Write-Host "=== Maintenance Mode Command Audit ==="
    Write-Host "Timestamp (UTC): $($logEntry.timestamp)"
    Write-Host "Timestamp (Local): $($logEntry.timestamp_local)"
    Write-Host "Action: $($logEntry.action)"
    Write-Host "Cluster ID: $($logEntry.cluster_id)"
    Write-Host "Config Dir: $($logEntry.config_dir)"
    if ($boundParams['Action'] -eq 'enable') {
        Write-Host "Start Time (UTC): $($logEntry.start_time_utc)"
        Write-Host "End Time (UTC): $($logEntry.end_time_utc)"
    }
    Write-Host "Dry Run: $($logEntry.dry_run)"
    Write-Host "No Schedule: $($logEntry.no_schedule)"
    Write-Host "==================================="

    Write-Host ""
    Write-Host "=== Command Result ==="
    Write-Host "Success: $($result.Success)"
    if ($result.Message) { Write-Host "Message: $($result.Message)" }
    if ($result.Error) { Write-Host "Error: $($result.Error)" }
    Write-Host "======================"

    exit $(if ($result.Success) { 0 } else { 1 })
}

# vim: ts=4 sw=4 et
