#
# Start-InstallMonitor.ps1 — Windows installation progress monitor
# Equivalent of Python cli/monitor_install.py (481 lines → ~330 PS lines)
#
# Contains: Start-InstallMonitor wrapper function, InstallationMonitor class,
#           and a script-mode guard for direct pwsh invocation.
#

function Start-InstallMonitor {
    <#
    .SYNOPSIS
        Monitor Windows Server installation progress on HPE ProLiant hardware.
        Callable from the module Router.

    .PARAMETER Server
        Monitor a single server only.

    .PARAMETER ServerList
        Path to server_list.txt (default: configs\server_list.txt).

    .PARAMETER TimeoutSeconds
        Maximum monitoring duration in seconds (default: 7200).

    .PARAMETER PollIntervalSeconds
        Seconds between checks (default: 30).

    .PARAMETER OpsRampConfig
        Path to opsramp_config.json.

    .RETURNS
        [hashtable] with status, progress, and details.

    .EXAMPLE
        Start-InstallMonitor -Server 'srv01.corp.local' -TimeoutSeconds 3600
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string] $Server    = $null,
        [Parameter(Mandatory = $false)][string] $ServerList  = 'configs\server_list.txt',
        [Parameter(Mandatory = $false)][int]    $TimeoutSeconds  = 7200,
        [Parameter(Mandatory = $false)][int]    $PollIntervalSeconds = 30,
        [Parameter(Mandatory = $false)][string] $OpsRampConfig = 'configs\opsramp_config.json'
    )
    try {
        $monitor = [InstallationMonitor]::new($ServerList, $OpsRampConfig)
        if ($Server) {
            $si = ($monitor.Servers | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $si) { return @{ Success=$false; Error="Server not found: $Server" } }
            $r = $monitor.MonitorServer($si, $TimeoutSeconds, $PollIntervalSeconds)
            return @{ Success = ($r.status -eq 'completed'); Status = $r.status; Details = $r }
        }
        else {
            $summary = $monitor.MonitorAll($TimeoutSeconds)
            return @{ Success = ($summary['completed'] -gt 0); Summary = $summary }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

$Script:LogDir = Join-Path $PSScriptRoot '..\..\logs'
Initialize-Logging -LogFile 'monitoring.log'

# ---- Phase-name map ----
$Script:PhaseMap = @{
    0 = 'Not Started'; 1 = 'Generalize'; 2 = 'Specialize'
    3 = 'Running Windows'; 4 = 'RunPhase'
}

# ---- InstallationMonitor class ----
class InstallationMonitor {
    [string]              $ServerListPath
    [string]              $OpsRampConfigPath
    [ServerInfo[]]        $Servers
    [hashtable]           $Sessions
    [System.Collections.ArrayList] $MonitorLog
    [OpsRamp_Client]      $OpsRampClient

    # Constants
    [int] $CheckInterval    = 30
    [int] $InstallTimeout   = 7200

    InstallationMonitor([string]$ServerList, [string]$OpsRampConfig) {
        $this.ServerListPath  = $ServerList
        $this.OpsRampConfigPath = $OpsRampConfig
        $this.Servers         = Load-ServerList -Path $ServerList -IncludeDetails
        $this.Sessions        = @{}
        $this.MonitorLog      = [System.Collections.ArrayList]::new()
        $this.OpsRampClient   = $this._InitOpsRampClient()
    }

    [OpsRamp_Client] _InitOpsRampClient() {
        if (-not (Test-Path $this.OpsRampConfigPath)) { Write-Warning 'OpsRamp config not found'; return $null }
        try { return [OpsRamp_Client]::new($this.OpsRampConfigPath) }
        catch { Write-Warning "OpsRamp init failed: $($_.Exception.Message)"; return $null }
    }

    [void] _Log([string]$Action, [string]$ServerName, [string]$Status, [string]$Details = '') {
        $null = $this.MonitorLog.Add(@{ timestamp=(Get-Date).ToString('o'); action=$Action; server=$ServerName; status=$Status; details=$Details })
        Write-Host "[$Status] $Action | $ServerName | $Details"
    }

    [hashtable] CheckIloStatus([ServerInfo]$Server) {
        $ip = $Server.ILO_IP
        if (-not $ip) { return @{ status='unknown'; reason='No iLO IP' } }
        # Ping
        $r = Invoke-Command -Command @('ping','-n','1','-w','2000',$ip) -TimeoutSeconds 10
        if (-not $r.Success) { return @{ status='offline'; power_state='unknown'; boot_source='unknown' } }
        # Redfish query
        $rfUrl  = "https://$ip/redfish/v1/Systems/1"
        $cred   = Get-IloCredentials
        try {
            $resp = Invoke-RestMethod -Uri $rfUrl -Method Get `
                -TimeoutSec 5 `
                -Credential (New-Object System.Management.Automation.PSCredential($cred[0],
                    (ConvertTo-SecureString $cred[1] -AsPlainText -Force))) `
                -ErrorAction Stop
            return @{ status='online'; power_state=$resp.PowerState; boot_source=($resp.Boot.BootSourceOverrideTarget); ilo_reachable=$true }
        } catch {
            return @{ status='ilo_error'; http_status=if($_.Exception.Response){$_.Exception.Response.StatusCode}else{'connect_fail'} }
        }
    }

    [hashtable] CheckWinRM([ServerInfo]$Server) {
        $hn = $Server.Hostname
        try {
            $r  = Invoke-PowerShellScript -Script "Test-WSMan -ComputerName $hn -ErrorAction SilentlyContinue" -TimeoutSeconds 10
            if ($r.Success) { return @{ winrm_accessible=$true; transport='WinRM' } }
            else            { return @{ winrm_accessible=$false; error=$r.Output } }
        } catch { return @{ winrm_accessible=$false; error=$_.Exception.Message } }
    }

    [hashtable] QueryInstallProgressWinRM([ServerInfo]$Server) {
        $hn = $Server.Hostname
        $progress = @{ setup_phase=$null; install_state=$null; progress_percent=$null; last_event=$null; winrm_accessible=$true }
        $psScript = @'
$sp = Get-ItemProperty -Path 'HKLM:\SYSTEM\Setup' -Name 'Phase' -ErrorAction SilentlyContinue
$is = Get-ItemProperty -Path 'HKLM:\SYSTEM\Setup' -Name 'InstallState' -ErrorAction SilentlyContinue
$pg = Get-ItemProperty -Path 'HKLM:\SYSTEM\Setup\State' -Name 'SetupProgress' -ErrorAction SilentlyContinue
if($sp){Write-Output "Phase=$($sp.Phase)"}
if($is){Write-Output "InstallState=$($is.InstallState)"}
if($pg){Write-Output "Progress=$($pg.SetupProgress)"}
$events = Get-WinEvent -LogName 'System' -MaxEvents 10 | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-Setup' }
if($events){Write-Output "LastSetupEvent=$($events[0].Id)"}
'@
        try {
            $r = Invoke-PowerShellWinRM -Script $psScript -Server $hn -Username $null -Password $null
            if ($r.Success) {
                foreach ($line in ($r.Output -split "`n" | Where-Object { $_.Trim() })) {
                    $kv = $line.Split('=',2)
                    if ($kv.Count -eq 2) {
                        $k = $kv[0].Trim(); $v = $kv[1].Trim()
                        switch ($k) {
                            'Phase'          { $progress['setup_phase'] = [int]$v }
                            'InstallState'   { $progress['install_state'] = [int]$v }
                            'Progress'       { $progress['progress_percent'] = [int]$v }
                            'LastSetupEvent' { $progress['last_event'] = [int]$v }
                        }
                    }
                }
            }
        } catch {}
        return $progress
    }

    [hashtable] _SendOpsRampMetric([string]$ServerName, [string]$MetricName, [double]$Value) {
        if ($this.OpsRampClient) {
            try { $this.OpsRampClient.SendMetric($ServerName, $MetricName, $Value, @{ source='automation.cli.monitor_install' }) } catch {}
        }
    }

    [void] _SendOpsRampAlert([string]$ServerName, [string]$AlertType, [string]$Severity, [string]$Message) {
        if ($this.OpsRampClient) {
            try { $this.OpsRampClient.SendAlert($ServerName, $AlertType, $Severity, $Message) } catch {}
        }
    }

    [hashtable] MonitorServer([ServerInfo]$Server, [int]$Timeout = $this.InstallTimeout, [int]$PollInterval = $this.CheckInterval) {
        $hn = $Server.Hostname
        Write-Host "Starting monitor for $hn"
        $startTime = Get-Date
        $result = @{
            server           = $hn; start_time = $startTime.ToString('o'); status='monitoring'
            progress_percent = 0; current_phase = 'Not Started'; duration_seconds = 0
            check_count      = 0; ilo_events = @(); winrm_progress = @(); alerts_sent = 0
        }

        try {
            while ($true) {
                $checkTime = Get-Date -Format o
                $result['check_count']++
                $elapsed = ((Get-Date) - $startTime).TotalSeconds

                if ($elapsed -gt $Timeout) {
                    $result.status = 'timeout'; $result.error = "Timed out after $Timeout s"
                    $this._Log('monitor',$hn,'TIMEOUT',$result.error)
                    $this._SendOpsRampAlert $hn 'install_timeout' 'WARNING' 'Installation timed out'
                    break
                }
                # iLO
                $iloStatus = $this.CheckIloStatus $Server
                $psState   = $iloStatus.Get_Item('power_state') ?? 'unknown'
                $bootSrc   = $iloStatus.Get_Item('boot_source') ?? 'unknown'
                $result['ilo_events'] += @{ timestamp=$checkTime; power_state=$psState; boot_source=$bootSrc }

                # WinRM
                $winrmStatus   = $this.CheckWinRM $Server
                $winrmOk       = [bool]$winrmStatus.Get_Item('winrm_accessible')

                if ($winrmOk) {
                    $progress = $this.QueryInstallProgressWinRM $Server
                    $result['winrm_progress'] += @{ timestamp=$checkTime } + $progress
                    $phaseVal = $progress.Get_Item('setup_phase')
                    if ($null -ne $phaseVal) { $result['current_phase'] = $Script:PhaseMap[$phaseVal] ?? "Phase $phaseVal" }
                    $pct = $progress.Get_Item('progress_percent')
                    if ($null -ne $pct) { $result['progress_percent'] = $pct }
                }

                Write-Host "[$hn] Elapsed: $([math]::Round($elapsed))s | Power: $psState | WinRM: $(if($winrmOk){'ok'}else{'no'}) | Progress: $($result['progress_percent'])% | Phase: $($result['current_phase'])"

                $this._SendOpsRampMetric $hn 'install.progress.percent' $result['progress_percent']
                $this._SendOpsRampMetric $hn 'install.elapsed_seconds' $elapsed

                if ($result['progress_percent'] -eq 100) {
                    $result.status = 'completed'
                    $this._Log('monitor',$hn,'COMPLETE','Installation finished')
                    $this._SendOpsRampAlert $hn 'installation_complete' 'INFO' 'Windows installation completed'
                    break
                }
                $lastWinRM = $result['winrm_progress'][-1]
                if ($lastWinRM -and $lastWinRM['install_state'] -eq 2) {
                    $result.status = 'failed'; $result.error = 'Installation reported failure'
                    $this._Log('monitor',$hn,'FAILED',$result.error)
                    $this._SendOpsRampAlert $hn 'installation_failed' 'CRITICAL' 'Windows installation failed'
                    break
                }
                Start-Sleep -Seconds $PollInterval
            }
        }
        catch [System.Threading.ThreadInterruptedException] {
            $result.status = 'interrupted'; Write-Warning "Monitor interrupted for $hn"
        }
        catch {
            $result.status = 'error'; $result.error = $_.Exception.Message
            Write-Error "Monitor error for $hn: $($_.Exception.Message)"
        }
        finally {
            $result['end_time'] = (Get-Date).ToString('o')
            $result['duration_seconds'] = ((Get-Date) - $startTime).TotalSeconds
            $sessDir = Join-Path $Script:LogDir 'monitoring_sessions'
            Ensure-DirectoryExists -Path $sessDir
            $sessFile = Join-Path $sessDir "monitor_${hn}_$([int][double]::Parse((Get-Date -UFormat %s))).json"
            Save-Json -Data $result -Path $sessFile
            Write-Host "Monitoring session saved: $sessFile"
        }
        return $result
    }

    [hashtable] MonitorAll([int]$Timeout = $this.InstallTimeout) {
        Write-Host "`nStarting monitor for $($this.Servers.Count) servers"
        Write-Host $('='*60)
        $results = @()
        foreach ($s in $this.Servers) {
            $results += $this.MonitorServer($s, $Timeout)
        }
        $completed  = ($results | Where-Object { $_.status -eq 'completed' }).Count
        $failed     = ($results | Where-Object { $_.status -eq 'failed' }).Count
        $timedOut   = ($results | Where-Object { $_.status -eq 'timeout' }).Count
        $summary    = @{ timestamp=(Get-Date).ToString('o'); total=$results.Count; completed=$completed;
            failed=$failed; timeout=$timedOut; details=$results }
        $summaryFile = Join-Path $Script:LogDir "monitor_summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Save-Json -Data $summary -Path $summaryFile
        Write-Host "`nMonitoring Summary: Completed=$completed Failed=$failed Timeout=$timedOut Total=$($results.Count)"
        Write-Host "Saved: $summaryFile"
        return $summary
    }
}

# --- Main (script mode only) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.PSScriptRoot -ne $null) {
    try {
        $monitor = [InstallationMonitor]::new($ServerList, $OpsRampConfig)
        if ($Server) {
            $si = ($monitor.Servers | Where-Object { $_.Hostname -eq $Server } | Select-Object -First 1)
            if (-not $si) { Write-Error "Server not found: $Server"; exit 1 }
            $r = $monitor.MonitorServer($si, $TimeoutSeconds, $PollIntervalSeconds)
            exit (if ($r.status -eq 'completed') { 0 } else { 1 })
        }
        else {
            $summary = $monitor.MonitorAll($TimeoutSeconds)
            exit (if ($summary['completed'] -gt 0) { 0 } else { 1 })
        }
    }
    catch {
        Write-Error "Monitoring failed: $($_.Exception.Message)"
        exit 1
    }
}

# vim: ts=4 sw=4 et
