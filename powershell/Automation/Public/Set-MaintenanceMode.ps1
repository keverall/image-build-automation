#
# Set-MaintenanceMode.ps1 — SCOM / iLO / OpenView maintenance-mode orchestrator
# Equivalent of Python cli/maintenance_mode.py (~956 lines)
#
# Contains: Set-MaintenanceMode wrapper function, helper functions, manager classes,
#           and a script-mode guard for direct pwsh invocation.
#

function Set-MaintenanceMode {
    <#
    .SYNOPSIS
        Enable, disable, or validate maintenance mode for a server cluster.
        Callable from the module Router.

    .PARAMETER Action
        'enable', 'disable', or 'validate'.

    .PARAMETER ClusterId
        Cluster identifier string.

    .PARAMETER Start
        Maintenance start datetime string (default: now).

    .PARAMETER End
        Maintenance end datetime string.

    .PARAMETER DryRun
        Simulate without making changes.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .PARAMETER VerbosePreference
        Enable verbose debug logging.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now

    .EXAMPLE
        Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('enable','disable','validate')][string] $Action = 'enable',
        [Parameter(Mandatory, Position = 0)][string] $ClusterId,
        [string] $Start = $null,
        [string] $End = $null,
        [Parameter(Mandatory = $false)][switch] $DryRun,
        [Parameter(Mandatory = $false)][switch] $NoSchedule,
        [Parameter(Mandatory = $false)][switch] $VerbosePreference
    )

    $ErrorActionPreference = 'Continue'

    # Load configs
    $clustersCfg  = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg      = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'scom_config.json')           -Required:$false
    $openviewCfg  = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'openview_config.json')       -Required:$false
    $emailCfg     = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg   = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'opsramp_config.json') -Required:$false

    $clustersMap = $clustersCfg.Get_Item('clusters')
    if (-not $clustersMap -or -not $clustersMap.ContainsKey($ClusterId)) {
        Write-Error "Cluster ID '$ClusterId' not found in catalogue."
        return @{ Success = $false; Error = "Cluster ID '$ClusterId' not found in catalogue." }
    }
    $clusterDef = $clustersMap[$ClusterId]

    # Validate cluster definition
    $requiredFields = @('display_name','servers','scom_group','environment')
    $missing = foreach ($f in $requiredFields) { if (-not $clusterDef.ContainsKey($f)) { $f } }
    if ($missing) { Write-Error "Cluster definition missing required fields: $($missing -join ', ')"; return @{ Success = $false; Error = "Missing fields: $($missing -join ', ')" } }
    $servers = $clusterDef.Get_Item('servers')
    if (-not ($servers -is [System.Collections.IEnumerable]) -or -not ($servers | Measure-Object).Count) {
        Write-Error "Cluster 'servers' must be a non-empty list."
        return @{ Success = $false; Error = "Cluster 'servers' must be a non-empty list." }
    }

    # VALIDATE action
    if ($Action -eq 'validate') {
        Write-Host "Cluster '$ClusterId' validated. Servers: $($servers -join ', ')"
        $audit = @{ cluster_id=$ClusterId; action=$Action; dry_run=[bool]$DryRun; timestamp_start=(Get-Date).ToString('o'); steps=@{}; success=$true }
        _Save-AuditRecord $audit (Join-Path $Script:LogDir "validate_${ClusterId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json")
        return @{ Success = $true; Message = "Cluster '$ClusterId' validated." }
    }

    # Resolve Start / End
    $startDt = $null; $endDt = $null
    if ($Action -eq 'enable') {
        if ($Start)   { $startDt = _Parse-Datetime $Start }
        else          { $startDt = Get-Date }
        if ($End)     { $endDt   = _Parse-Datetime $End }
        else {
            $schedule = $clusterDef.Get_Item('schedule')
            if ($schedule) { $endDt = _Compute-NextWorkStart $schedule $startDt }
            else { Write-Error 'No --end and no schedule defined in cluster.'; return @{ Success = $false; Error = 'No end time or schedule defined.' } }
        }
        if ($endDt -le $startDt) { Write-Error 'End time must be after start time.'; return @{ Success = $false; Error = 'End time must be after start time.' } }
        $duration = $endDt - $startDt
        Write-Verbose "Maintenance window: $startDt → $endDt (duration: $duration)"
    }

    # Initialise managers
    $scomMgr = $null; try { $scomMgr = [SCOMManager]::new($scomCfg) } catch { Write-Warning "SCOM manager unavailable: $($_.Exception.Message)" }
    $iloMgr   = [ILOManager]::new($clusterDef)
    $ovMgr    = [OpenViewClient]::new($openviewCfg, $clusterDef)
    $emailer  = [EmailNotifier]::new($emailCfg)

    $opsrampClient = $null
    if ($opsrampCfg) { try { $opsrampClient = [OpsRamp_Client]::new((Join-Path $Script:ConfigDir 'opsramp_config.json')) } catch {} }

    # Execute action
    $overallOk = $true
    $audit     = @{ cluster_id=$ClusterId; action=$Action; dry_run=[bool]$DryRun; timestamp_start=(Get-Date).ToString('o'); steps=@{}; success=$true }

    if ($Action -eq 'enable') {
        # SCOM
        $scomOk = $false; $scomInfo = ''
        if ($scomMgr) {
            $durHrs  = $duration.TotalSeconds / 3600.0
            $comment = "iRequest Maintenance: $ClusterId"
            $scomRes = $scomMgr.EnterMaintenance($clusterDef.Get_Item('scom_group'), $duration, $comment, [bool]$DryRun)
            $scomOk  = $scomRes[0]; $scomInfo = if ($scomRes[1]) { ($scomRes[1] -join "`n") } else { '' }
        }
        $audit.steps['scom'] = @{ Success = $scomOk; Info = $scomInfo }
        if (-not $scomOk) { $overallOk = $false }

        # iLO
        $iloRes = $iloMgr.SetMaintenanceWindow($clusterDef, $startDt, $endDt, [bool]$DryRun)
        $iloOk  = $iloRes.Success
        $audit.steps['ilo'] = @{ Success = $iloOk; Details = $iloRes.Details }
        if (-not $iloOk) { $overallOk = $false }

        # OpenView
        $ovRes  = $ovMgr.SetMaintenance($clusterDef, $startDt, $endDt, [bool]$DryRun)
        $ovOk   = $ovRes[0];  $ovMsg = $ovRes[1]
        $audit.steps['openview'] = @{ Success = $ovOk; Message = $ovMsg }
        if (-not $ovOk) { $overallOk = $false }

        # Email
        $emailOk = $emailer.SendMaintenanceNotification('enabled', $clusterDef, $servers, $startDt, $endDt, [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk) { $overallOk = $false }

        # OpsRamp
        $opsOk = $false
        if ($opsrampClient -and -not $DryRun) {
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 1, @{ cluster = $ClusterId; environment = $clusterDef.Get_Item('environment') })
            }
            $opsOk = $opsrampClient.SendAlert($ClusterId, 'maintenance.enabled', 'INFO',
                "Maintenance enabled for $ClusterId",
                @{ cluster=$clusterDef.Get_Item('display_name'); servers=$servers;
                   start=$startDt.ToString('o'); end=$endDt.ToString('o') })
            $opsrampClient.SendEvent($ClusterId, 'maintenance.enabled',
                "Maintenance window started for $($clusterDef.Get_Item('display_name'))",
                @{ cluster=$ClusterId; action='enable' })
        }
        $audit.steps['opsramp'] = @{ Success = $opsOk }

        # Scheduled Task
        if ($IsWindows -and -not $NoSchedule) {
            $taskName  = "MaintenanceDisable-$ClusterId"
            $scriptAbs = (Resolve-Path $PSScriptRoot).Path
            $stTime    = $endDt.ToString('HH:mm')
            $sdDate    = $endDt.ToString('yyyy/MM/dd')
            schtasks /Delete /TN $taskName /F 2>$null | Out-Null
            try {
                schtasks /Create /TN $taskName /TR "`"$($PSHOME)\pwsh.exe`" `"$scriptAbs`" -a disable -c $ClusterId --no-schedule" `
                    /SC ONCE /ST $stTime /SD $sdDate /RL HIGHEST /RU SYSTEM /F 2>&1 | Out-Null
                $audit.steps.scheduled_task = @{ Created = $true }
            } catch { $audit.steps.scheduled_task = @{ Created = $false; Error = $_.Exception.Message }; $overallOk = $false }
        }
    }
    elseif ($Action -eq 'disable') {
        # Email disable notification
        $emailOk = $emailer.SendMaintenanceNotification('disabled', $clusterDef, $servers, $null, (Get-Date), [bool]$DryRun)
        $audit.steps['email'] = @{ Sent = $emailOk }
        if (-not $emailOk) { $overallOk = $false }

        # OpsRamp
        if ($opsrampClient -and -not $DryRun) {
            foreach ($s in $servers) {
                $opsrampClient.SendMetric($s, 'maintenance.mode', 0, @{ cluster=$ClusterId })
            }
            $opsrampClient.SendAlert($ClusterId, 'maintenance.disabled', 'INFO',
                "Maintenance disabled for $ClusterId",
                @{ completed_at = (Get-Date -Format o) })
            $opsrampClient.SendEvent($ClusterId, 'maintenance.disabled',
                "Maintenance window ended for $($clusterDef.Get_Item('display_name'))",
                @{ cluster=$ClusterId; action='disable' })
        }

        # Clean up scheduled task
        if ($IsWindows) {
            $taskName = "MaintenanceDisable-$ClusterId"
            try { schtasks /Delete /TN $taskName /F 2>&1 | Out-Null; $audit.steps.scheduled_task_cleanup = @{ Deleted = $true } }
            catch { $audit.steps.scheduled_task_cleanup = @{ Deleted = $false; Error = $_.Exception.Message } }
        }
    }

    $audit.success = $overallOk
    $auditFile = Join-Path $Script:LogDir "$($Action)_${ClusterId}_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).json"
    _Save-AuditRecord $audit $auditFile

    if ($overallOk) { Write-Host "Maintenance $Action completed." }
    else            { Write-Error "Maintenance $Action finished with errors. Check $auditFile." }
    return @{ Success = $overallOk; Message = if ($overallOk) { "Maintenance $Action completed." } else { "Maintenance $Action finished with errors." } }
}

# ---- Constants (always defined so classes referencing them work on dot-source) ----
$Script:BaseDir  = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Script:ConfigDir  = Join-Path $Script:BaseDir 'configs'
$Script:LogDir     = Join-Path $Script:BaseDir 'logs'
$Script:DistList   = Join-Path $Script:BaseDir 'maintenance_distribution_list.txt'

if (-not (Test-Path $Script:LogDir)) { Ensure-DirectoryExists -Path $Script:LogDir }

# ---- Logging ----
Initialize-Logging -LogFile 'maintenance.log'

# ---- Parse datetime helpers ----
function _Parse-Datetime([string]$s) {
    if ($s.ToLower() -eq 'now') { return Get-Date }
    # Accept 'YYYY-MM-DD HH:MM[:SS]' or 'YYYY-MM-DDTHH:MM[:SS]'
    $s2 = $s.Replace('T',' ')
    $formats = @('yyyy-MM-dd HH:mm:ss','yyyy-MM-dd HH:mm')
    foreach ($fmt in $formats) {
        try { return [DateTime]::ParseExact($s2, $fmt, $null) } catch {}
    }
    throw "Invalid datetime format '$s'. Use 'now' or 'YYYY-MM-DD HH:MM[:SS]'."
}

function _Compute-NextWorkStart([hashtable]$Schedule, [DateTime]$After) {
    $workStartStr = $Schedule.Get_Item('work_start') ?? '08:00'
    $workStart    = [DateTime]::ParseExact($workStartStr,'HH:mm',$null).TimeOfDay
    $dayMap       = @{ Mon=0;Tue=1;Wed=2;Thu=3;Fri=4;Sat=5;Sun=6 }
    $workDays     = @($Schedule.Get_Item('work_days') ?? @('Mon','Tue','Wed','Thu','Fri')) | ForEach-Object { $dayMap[$_] }
    $candidate    = $After.Date
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
    $Audit | ConvertTo-Json -Depth 64 | Set-Content -Path $Path -Encoding UTF8 -Force
    # Append to master log
    $master = Join-Path $Script:LogDir 'maintenance_audit.log'
    $Audit | ConvertTo-Json -Depth 64 | Add-Content $master -Encoding UTF8
}

# ---- SCOMManager ----
class SCOMManager {
    [hashtable] $Config
    [string]    $MgmtServer
    [string]    $ModuleName
    [bool]      $UseWinRM
    [hashtable] $Cred

    SCOMManager([hashtable]$Config) {
        $this.Config      = $Config
        $this.MgmtServer  = $Config.Get_Item('management_server') ?? 'localhost'
        $this.ModuleName  = $Config.Get_Item('powershell_module') ?? 'OperationsManager'
        $this.UseWinRM    = [bool]($Config.Get_Item('use_winrm') ?? $false)
        $this.Cred        = $null
        $credCfg          = $Config.Get_Item('credentials')
        if ($credCfg) {
            $uenv = $credCfg.Get_Item('username_env')
            $penv = $credCfg.Get_Item('password_env')
            if ($uenv -and $penv) {
                $u = [System.Environment]::GetEnvironmentVariable($uenv)
                $p = [System.Environment]::GetEnvironmentVariable($penv)
                if ($u -and $p) { $this.Cred = @{ username = $u; password = $p } }
            }
        }
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

    [tuple[bool,string[]]] EnterMaintenance([string]$GroupDisplayName, [TimeSpan]$Duration,
                                             [string]$Comment, [bool]$DryRun = $false) {
        if ($DryRun) {
            Write-Verbose "[DRY RUN] Would enable SCOM maintenance for group '$GroupDisplayName', duration=$Duration"
            return @($true, @())
        }
        $totalSec       = [int]$Duration.TotalSeconds
        $safeComment    = $Comment.Replace("'","''")
        $script = New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                    -DurationSeconds $totalSec -Comment $safeComment -Operation 'start'
        $r = $this._RunPs($script)
        if ($r.Success) {
            Write-Verbose "SCOM maintenance enabled: $($r.Output)"
            return @($true, @($r.Output))
        }
        Write-Error "SCOM maintenance failed: $($r.Output)"
        return @($false, @($r.Output))
    }

    [bool] ExitMaintenance([string]$GroupDisplayName, [bool]$DryRun = $false) {
        if ($DryRun) {
            Write-Verbose "[DRY RUN] Would disable SCOM maintenance for group '$GroupDisplayName'"
            return $true
        }
        $script = New-ScomMaintenanceScript -GroupDisplayName $GroupDisplayName `
                    -DurationSeconds 0 -Comment 'exit' -Operation 'stop'
        $r = $this._RunPs($script)
        Write-Verbose "SCOM maintenance disable output: $($r.Output)"
        return $r.Success
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
        $this.ClusterDef  = $ClusterDef
        $this.Method      = 'rest'
        $this.TimeoutSeconds = 30
        $uCred            = Get-IloCredentials
        $this.GlobalUser  = $uCred[0]
        $this.GlobalPassword = $uCred[1]
    }

    [tuple[string,string]] _GetIloCredentials([string]$ServerName) {
        $credMap = $this.ClusterDef.Get_Item('ilo_credentials')
        if ($credMap -and $credMap.ContainsKey($ServerName)) {
            $info     = $credMap[$ServerName]
            $username = $info.Get_Item('username') ?? $this.GlobalUser
            $penv     = $info.Get_Item('password_env')
            $password = if ($penv) { (Get-CredentialSecret -EnvVarName $penv -Default $this.GlobalPassword) } else { $this.GlobalPassword }
            return $username, $password
        }
        return $this.GlobalUser, $this.GlobalPassword
    }

    [string] _GetIloIp([string]$ServerName) {
        $m = $this.ClusterDef.Get_Item('ilo_addresses')
        return if ($m) { $m.Get_Item($ServerName) } else { $null }
    }

    [hashtable] _CreateWindowRest([string]$IloIp, [string]$Username, [string]$Password,
                                   [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        if ($DryRun) { return @{ Success = $true; Msg = "[DRY RUN] Would create iLO maintenance window on $IloIp from $StartDt to $EndDt" } }
        $baseUrl = "https://$IloIp/rest/v1"
        # Quick reachability test via Invoke-RestMethod
        try {
            $null = Invoke-RestMethod -Uri "$baseUrl/systems/1" -Method Get `
                -Credential (New-Object System.Management.Automation.PSCredential($Username,
                    (ConvertTo-SecureString $Password -AsPlainText -Force))) `
                -TimeoutSec $this.TimeoutSeconds -ErrorAction Stop
        } catch {
            return @{ Success = $false; Msg = "iLO connection failed: $($_.Exception.Message)" }
        }
        $windowName = "maintenance_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
        $body       = @{
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
        } catch {
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
        $servers      = $ClusterDef.Get_Item('servers') ?? @()
        $iloMap       = $ClusterDef.Get_Item('ilo_addresses')
        if (-not $iloMap) {
            Write-Warning 'No iLO addresses defined; skipping iLO'
            return @{ Skipped = $true; Reason = 'No iLO addresses' }
        }
        $ok    = $true
        $detail = @{}
        foreach ($s in $servers) {
            $ip = $iloMap.Get_Item($s)
            if (-not $ip) { Write-Warning "No iLO IP for $s; skipping"; $detail[$s] = @{ Success=$false; Error='Missing iLO IP' }; $ok=$false; continue }
            $uCred = $this._GetIloCredentials($s)
            if (-not $uCred[0] -or -not $uCred[1]) {
                Write-Warning "Missing iLO credentials for $s; skipping"
                $detail[$s] = @{ Success=$false; Error='Missing credentials' }; $ok=$false; continue
            }
            $r = $this._CreateWindowRest($ip, $uCred[0], $uCred[1], $StartDt, $EndDt, $false)
            $detail[$s] = @{ Success=$r.Success; Msg=$r.Msg; IloIp=$ip }
            if (-not $r.Success) { $ok=$false }
        }
        return @{ Success=$ok; Details=$detail }
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
        $ovConfig       = $Config.Get_Item('openview') ?? @{}
        $this.Config    = $ovConfig
        $this.BaseUrl   = $ovConfig.Get_Item('default_api_url') ?? 'https://openview.example.com/api'
        $this.ApiVersion= $ovConfig.Get_Item('api_version') ?? 'v1'
        $this.Endpoint  = $ovConfig.Get_Item('maintenance_endpoint') ?? '/maintenance'
        $this.TimeoutSeconds = ($ovConfig.Get_Item('timeout_seconds') ?? 30)
        $authCfg        = $ovConfig.Get_Item('auth') ?? @{}
        $this.AuthType  = $authCfg.Get_Item('type') ?? 'basic'
        $uCreds         = Get-OpenViewCredentials
        $this.Username  = $uCreds[0]
        $this.Password  = $uCreds[1]
        $this.UseCli    = [bool]($ovConfig.Get_Item('use_cli') ?? $false)
        $this.CliPath   = $ovConfig.Get_Item('cli_path') ?? 'ovcall'
    }

    [tuple[bool,string]] SetMaintenance([hashtable]$ClusterDef, [DateTime]$StartDt, [DateTime]$EndDt, [bool]$DryRun) {
        $nodeIdsMap = $ClusterDef.Get_Item('openview_node_ids')
        if (-not $nodeIdsMap) { return @($true, 'No OpenView nodes configured') }
        $nodeIds    = [System.Collections.ArrayList]@($nodeIdsMap.Values)
        if ($this.UseCli) { return $this._SetViaCli($nodeIds, $StartDt, $EndDt, $ClusterDef.Get_Item('display_name'), $DryRun) }
        return $this._SetViaRest($nodeIds, $StartDt, $EndDt, $ClusterDef.Get_Item('display_name'), $DryRun)
    }

    [tuple[bool,string]] _SetViaRest([object[]]$NodeIds, [DateTime]$StartDt, [DateTime]$EndDt, [string]$ClusterName, [bool]$DryRun) {
        if ($DryRun) { return @($true, "[DRY RUN] OV REST for $($NodeIds -join ',')") }
        $body = @{
            nodes    = $NodeIds
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
            return @($true, "OpenView maintenance set for $($NodeIds.Count) nodes")
        } catch {
            return @($false, "OpenView REST call failed: $($_.Exception.Message)")
        }
    }

    [tuple[bool,string]] _SetViaCli([object[]]$NodeIds, [DateTime]$StartDt, [DateTime]$EndDt, [string]$ClusterName, [bool]$DryRun) {
        if ($DryRun) { return @($true, "[DRY RUN] OV CLI for $($NodeIds -join ',')") }
        $startStr = $StartDt.ToString('yyyy-MM-dd HH:mm:ss')
        $endStr   = $EndDt.ToString('yyyy-MM-dd HH:mm:ss')
         $nodesStr = ($NodeIds -join ',')
        $cmd      = "$($this.CliPath) -c `"set maintenance -nodes $nodesStr -start '$startStr' -end '$endStr' -comment '$ClusterName'`""
        $r        = Invoke-Command -Command (Split-PipelineCmd $cmd) -TimeoutSeconds $this.TimeoutSeconds
        $msg      = if ($r.Success) { $r.Output } else { $r.StandardError }
        return @($r.Success, $msg)
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
        $this.Config      = $Config.Get_Item('email')  ?? @{}
        $this.SmtpServer  = $this.Config.Get_Item('smtp_server') ?? 'localhost'
        $this.SmtpPort    = ($this.Config.Get_Item('smtp_port') ?? 25)
        $this.UseTls      = [bool]($this.Config.Get_Item('use_tls') ?? $false)
        $this.UseSsl      = [bool]($this.Config.Get_Item('use_ssl') ?? $false)
        $this.FromAddr    = $this.Config.Get_Item('from_address') ?? 'maintenance-bot@example.com'
        $this.Templates   = $this.Config.Get_Item('templates')  ?? @{}
        $this.UseSimple   = $false
        $this.DistLists   = $this.Config.Get_Item('distribution_lists') ?? @{}
        if (Test-Path $Script:DistList) {
            $this.SimpleRecipients = Get-Content $Script:DistList | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() }
            $this.UseSimple        = ($this.SimpleRecipients.Count -gt 0)
        }
    }

    [string[]] _GetRecipients([string]$Action) {
        if ($this.UseSimple) { return $this.SimpleRecipients }
        $key = "maintenance_$Action"
        return if ($this.DistLists.ContainsKey($key)) { $this.DistLists[$key] } else { @() }
    }

    [bool] SendMaintenanceNotification([string]$Action, [hashtable]$Cluster, [string[]]$Servers,
                                       [DateTime]$StartTime, [DateTime]$EndTime, [bool]$DryRun) {
        $recipients = $this._GetRecipients($Action)
        if (-not $recipients) {
            Write-Warning "No distribution list for action '$Action'; skipping email"
            return $false
        }
        $clusterName    = $Cluster.Get_Item('display_name') ?? $Cluster.Get_Item('scom_group') ?? 'Unknown'
        $environment    = $Cluster.Get_Item('environment') ?? 'unknown'
        $startStr       = if ($StartTime) { $StartTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
        $endStr         = if ($EndTime)   { $EndTime.ToString('yyyy-MM-dd HH:mm:ss') }  else { 'N/A' }
        $tplVars        = @{
            cluster_name    = $clusterName
            environment     = $environment
            servers         = ($Servers -join ', ')
            start_time      = $startStr
            end_time        = $endStr
            triggered_by    = 'iRequest'
            additional_info = if ($Action -eq 'enabled')      { 'Maintenance mode is now ACTIVE.' }
                          elseif ($Action -eq 'disabled')     { 'Maintenance mode has ENDED.' }
                          else                                 { "Maintenance action: $Action" }
        }
        $subjTpl = $this.Templates.Get_Item("subject_$Action") ?? "Maintenance {action} - {cluster_name} ({environment})"
        $subject = $subjTpl.Replace('{action}',$Action).Replace('{cluster_name}',$clusterName).Replace('{environment}',$environment)
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
            $mailMsg           = New-Object System.Net.Mail.MailMessage($this.FromAddr, $recipients[0])
            foreach ($r in $recipients) { $mailMsg.To.Add($r) | Out-Null }
            $mailMsg.Subject   = $subject
            $mailMsg.Body      = $body
            $mailMsg.IsBodyHtml = $false
            $smtp              = if ($this.UseSsl) {
                [System.Net.Mail.SmtpClient]::new($this.SmtpServer, $this.SmtpPort)
            } else {
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
        } catch {
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
    return ,$CommandString   # fallback: raw string passed through as single command
}

# ---- Main CLI logic (script mode only) ----
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.PSScriptRoot -ne $null) {
    $ErrorActionPreference = 'Continue'

    # Load configs
    $clustersCfg  = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Required:$false
    $scomCfg      = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'scom_config.json')           -Required:$false
    $openviewCfg  = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'openview_config.json')       -Required:$false
    $emailCfg     = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'email_distribution_lists.json') -Required:$false
    $opsrampCfg   = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'opsramp_config.json') -Required:$false

    $result = Set-MaintenanceMode @PSBoundParameters

    exit (if ($result.Success) { 0 } else { 1 })
}

# vim: ts=4 sw=4 et
