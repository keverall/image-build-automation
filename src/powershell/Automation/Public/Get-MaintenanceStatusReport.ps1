#
# Public/Get-MaintenanceStatusReport.ps1
#
# Read-only report that links SCOM and HPE OneView (OpenView) for every cluster
# in the catalogue: cluster + server state, SCOM maintenance windows currently
# tied to the SCOM client, the cluster power schedule (start-up / shut-down),
# and OneView maintenance state. Emits CSV (default) for the SCOM engineers to
# format freely in Excel. Pure reporting - never mutates maintenance mode.
#
# Request alias (router):  maintmode_status_report   -> Get-MaintenanceStatusReport
# Also invokable as:       scom-maintmode-status-report  (module alias)
#

function Get-MaintenanceStatusReport {
    <#
    .SYNOPSIS
        Generate a read-only status report linking SCOM and HPE OneView for all clusters.

    .DESCRIPTION
        For every cluster defined in clusters_catalogue.json the report collects:
          - Cluster + server inventory (from the catalogue, the single source of truth)
          - SCOM maintenance mode state + active maintenance window (start/end) per server
          - HPE OneView maintenance mode state per server
          - The cluster power schedule (daily start-up / shut-down) from the catalogue
        Live SCOM/OneView queries degrade gracefully to 'Unknown' when unreachable, so a
        catalogue-only report is always produced. The command is strictly read-only.

    .PARAMETER ConfigDir
        Configuration directory (default: <project-root>/configs).

    .PARAMETER Environment
        Environment used to resolve management hosts (Test | Prod). Default: Prod,
        or $env:ENVIRONMENT when set.

    .PARAMETER ManagementHost
        Override the SCOM management server (and OneView appliance, when the same host
        serves both). Otherwise resolved from connection_hosts.json.

    .PARAMETER IncludeLive
        Query live SCOM + OneView (default). Use -IncludeLive:$false for a catalogue-only
        report (no network calls).

    .PARAMETER Format
        Output format: Csv (default, written to -Path), Json, or Table (console).

    .PARAMETER Path
        CSV output path. Defaults to generated/reports/MaintenanceStatusReport_<ts>.csv.

    .PARAMETER DryRun
        Alias for -IncludeLive:$false - produce the catalogue-only report with no
        SCOM/OneView connections.

    .EXAMPLE
        Get-MaintenanceStatusReport -Environment Prod

    .EXAMPLE
        Invoke-RoutedRequest -RequestType 'maintmode_status_report' -Params @{ Environment = 'Prod' }

    .EXAMPLE
        scom-maintmode-status-report -Format Table
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Alias('Cfg')]
        [string] $ConfigDir = 'configs',

        [Alias('Env')]
        [ValidateSet('Test', 'Prod', 'Staging')]
        [string] $Environment,

        [Alias('Host', 'MgmtHost')]
        [string] $ManagementHost,

        [Alias('Live')]
        [bool] $IncludeLive = $true,

        [ValidateSet('Csv', 'Json', 'Table')]
        [string] $Format = 'Csv',

        [Alias('Out')]
        [string] $Path,

        [Alias('Dry')]
        [switch] $DryRun
    )

    if ($DryRun) { $IncludeLive = $false }

    $generatedUtc = (Get-UtcTimestamp)

    # ── Resolve config dir ────────────────────────────────────────────────────
    $effectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
        -MarkerFile 'clusters_catalogue.json' `
        -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')

    $clustersMap = Load-ClusterCatalogue (Join-Path $effectiveConfigDir 'clusters_catalogue.json')
    if (-not $clustersMap -or $clustersMap.Count -eq 0) {
        Write-Error "No clusters found in catalogue at '$effectiveConfigDir'."
        return @()
    }

    # ── Resolve environment + management hosts ────────────────────────────────
    $effectiveEnv = if ($PSBoundParameters.ContainsKey('Environment')) {
        $Environment
    } elseif ([System.Environment]::GetEnvironmentVariable('ENVIRONMENT')) {
        [System.Environment]::GetEnvironmentVariable('ENVIRONMENT')
    } else {
        'Prod'
    }

    $hostsCfgPath = Join-Path $effectiveConfigDir 'connection_hosts.json'
    $hostsCfg = if (Test-Path $hostsCfgPath) {
        Import-JsonConfig -Path $hostsCfgPath -Required:$false
    } else { @{} }

    $envConfig = $hostsCfg.Get_Item('environments') ?? @{}
    $selectedEnv = $envConfig.Get_Item($effectiveEnv) ?? @{}
    $scomEnv = $selectedEnv.Get_Item('scom') ?? @{}
    $ovEnv = $selectedEnv.Get_Item('oneview') ?? @{}

    $resolvedScomHost = if ($PSBoundParameters.ContainsKey('ManagementHost')) {
        $ManagementHost
    } elseif ([System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')) {
        [System.Environment]::GetEnvironmentVariable('MAINTENANCE_HOST')
    } else {
        $scomEnv.Get_Item('management_server')
    }
    $resolvedOvHost = if ($PSBoundParameters.ContainsKey('ManagementHost')) {
        $ManagementHost
    } else {
        $ovEnv.Get_Item('appliance')
    }

    # ── Optional OneView module resolution source (kept local; never from config) ──
    $scomCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'scom_config.json') -Required:$false
    $scomUseWinRm = $false
    if ($scomCfg -and $scomCfg.ContainsKey('scom')) {
        $sc = $scomCfg['scom']
        if ($sc.ContainsKey('use_winrm')) { $scomUseWinRm = [bool]$sc['use_winrm'] }
    }

    # ── Build live managers once (graceful: keep $null on any failure) ─────────
    $scomMgr = $null
    $ovMgr = $null
    if ($IncludeLive) {
        if ($resolvedScomHost) {
            try {
                $scomCfgCopy = @{
                    management_server = $resolvedScomHost
                    powershell_module = 'OperationsManager'
                    use_winrm         = $scomUseWinRm
                    credentials       = @{ username_env = 'SCOM_ADMIN_USER'; password_env = 'SCOM_ADMIN_PASSWORD' }
                }
                $scomMgr = [SCOMManager]::new($scomCfgCopy)
            } catch {
                Write-Warning "SCOM manager init failed ($resolvedScomHost): $($_.Exception.Message)"
            }
        } else {
            Write-Warning "No SCOM management host resolved for environment '$effectiveEnv' - SCOM column will be Unknown."
        }

        if ($resolvedOvHost) {
            try {
                $ovCfg = @{
                    oneview = @{
                        appliance   = $resolvedOvHost
                        use_winrm   = $false
                        credentials = @{ username_env = 'ONEVIEW_USER'; password_env = 'ONEVIEW_PASSWORD' }
                    }
                }
                $ovMgr = [OneViewClient]::new($ovCfg)
            } catch {
                Write-Warning "OneView manager init failed ($resolvedOvHost): $($_.Exception.Message)"
            }
        } else {
            Write-Warning "No OneView appliance resolved for environment '$effectiveEnv' - OneView column will be Unknown."
        }
    }

    # ── Helper: build a short-name lookup map (fqdn + hostname) ────────────────
    function _BuildServerKey([string]$Name) {
        $n = $Name.ToLower()
        $short = ($n.Split('.'))[0]
        return @($n, $short)
    }

    # ── Iterate clusters, one CSV row per server ──────────────────────────────
    $rows = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($clusterEntry in $clustersMap.GetEnumerator()) {
        $clusterKey = $clusterEntry.Key
        $cdef = $clusterEntry.Value

        $displayName  = $cdef.Get_Item('display_name') ?? $clusterKey
        $scomGroup    = $cdef.Get_Item('scom_group')
        $servers      = @($cdef.Get_Item('servers') ?? @())
        $clusterEnv   = $cdef.Get_Item('environment') ?? $effectiveEnv
        $ovScope      = $cdef.Get_Item('oneview_scope')

        $schedule     = $cdef.Get_Item('schedule') ?? @{}
        $powerStart   = if ($schedule -and $schedule.ContainsKey('work_start')) { $schedule['work_start'] } else { 'NOT CONFIGURED' }
        $powerEnd     = if ($schedule -and $schedule.ContainsKey('work_end'))   { $schedule['work_end'] }   else { 'NOT CONFIGURED' }
        $powerTz      = if ($schedule -and $schedule.ContainsKey('timezone'))   { $schedule['timezone'] }   else { 'n/a' }

        # ── Live SCOM status for this cluster ─────────────────────────────────
        $scomOk = $false
        $scomByServer = @{}
        if ($IncludeLive -and $scomMgr -and $scomGroup) {
            try {
                $status = $scomMgr.GetMaintenanceStatus($scomGroup, $servers, $false)
                if ($status.Success) {
                    $scomOk = $true
                    foreach ($obj in $status.Objects) {
                        $keys = _BuildServerKey $obj.Name
                        foreach ($k in $keys) { $scomByServer[$k] = $obj }
                    }
                } else {
                    Write-Verbose "SCOM status failed for group '$scomGroup': $($status.Error)"
                }
            } catch {
                Write-Verbose "SCOM status error for group '$scomGroup': $($_.Exception.Message)"
            }
        }

        # ── Live OneView status for this cluster ─────────────────────────────
        $ovOk = $false
        $ovByServer = @{}
        if ($IncludeLive -and $ovMgr -and $ovScope) {
            try {
                $ovStatus = $ovMgr.GetMaintenanceStatus($ovScope, 'Scope')
                if ($ovStatus.Success) {
                    $ovOk = $true
                    foreach ($obj in $ovStatus.Objects) {
                        $keys = _BuildServerKey $obj.Name
                        foreach ($k in $keys) { $ovByServer[$k] = $obj }
                    }
                } else {
                    Write-Verbose "OneView status failed for scope '$ovScope': $($ovStatus.Error)"
                }
            } catch {
                Write-Verbose "OneView status error for scope '$ovScope': $($_.Exception.Message)"
            }
        }

        if ($servers.Count -eq 0) {
            $servers = @($clusterKey)
        }

        foreach ($srv in $servers) {
            $srvKey = ($srv.ToLower())
            $srvShort = ($srv.ToLower().Split('.'))[0]

            # SCOM state for this server
            $scomState = 'Unknown'; $scomStart = ''; $scomEnd = ''
            $scomObj = $null
            if ($scomByServer.ContainsKey($srvKey)) { $scomObj = $scomByServer[$srvKey] }
            elseif ($scomByServer.ContainsKey($srvShort)) { $scomObj = $scomByServer[$srvShort] }
            if ($scomObj) {
                $scomState = if ($scomObj.InMaintenanceMode) { 'InMaintenance' } else { 'NotInMaintenance' }
                if ($scomObj.MaintenanceModeStartTime) { $scomStart = (Convert-ToUtcIso8601 $scomObj.MaintenanceModeStartTime) }
                if ($scomObj.MaintenanceModeEndTime)   { $scomEnd   = (Convert-ToUtcIso8601 $scomObj.MaintenanceModeEndTime) }
            }

            # OneView state for this server
            $ovState = 'Unknown'
            $ovObj = $null
            if ($ovByServer.ContainsKey($srvKey)) { $ovObj = $ovByServer[$srvKey] }
            elseif ($ovByServer.ContainsKey($srvShort)) { $ovObj = $ovByServer[$srvShort] }
            if ($ovObj) {
                $ovState = if ($ovObj.InMaintenanceMode) { 'InMaintenance' } else { 'NotInMaintenance' }
            }

            # Data completeness label for the row
            $dataSource = if (-not $IncludeLive) { 'CatalogueOnly' }
                          elseif ($scomOk -and $ovOk) { 'Live' }
                          elseif ($scomOk) { 'Partial-SCOM' }
                          elseif ($ovOk) { 'Partial-OneView' }
                          else { 'CatalogueOnly' }

            $row = [PSCustomObject]@{
                ReportGeneratedUtc   = $generatedUtc
                ClusterId            = $clusterKey
                ClusterDisplayName   = $displayName
                Environment          = $clusterEnv
                SCOMGroup            = $scomGroup
                Server               = $srv
                SCOMMaintenanceMode  = $scomState
                SCOMWindowStartUtc   = $scomStart
                SCOMWindowEndUtc     = $scomEnd
                SCOMWindowComment    = 'n/a (status query does not expose comment)'
                OneViewMaintenanceMode = $ovState
                OneViewScope         = $ovScope
                PowerScheduleStart   = $powerStart
                PowerScheduleEnd     = $powerEnd
                PowerScheduleTimezone = $powerTz
                DataSource           = $dataSource
            }
            $rows.Add($row)
        }
    }

    # ── Audit the report generation (read-only action, still auditable) ────────
    try {
        $audit = New-AuditLogger -Category 'maintenance_status_report' `
            -LogDir (Join-Path (Get-ProjectRoot) 'generated/logs/audit') -MasterLogName 'audit.log'
        $audit.Log('report_generate', 'INFO', '', "Rows=$($rows.Count) Environment=$effectiveEnv Live=$IncludeLive") | Out-Null
        $audit.Save() | Out-Null
    } catch {
        Write-Verbose "Audit logging skipped: $($_.Exception.Message)"
    }

    # ── Output ─────────────────────────────────────────────────────────────────
    $result = $rows.ToArray()
    switch ($Format) {
        'Json' { return ($result | ConvertTo-Json -Depth 4) }
        'Table' {
            $result | Format-Table -AutoSize | Out-Host
            return $result
        }
        default {
            if (-not $Path) {
                $projRoot = Get-ProjectRoot
                if (-not $projRoot) { $projRoot = (Get-Location).Path }
                $reportDir = Join-Path $projRoot 'generated/reports'
                Ensure-DirectoryExists -Path $reportDir
                $Path = Join-Path $reportDir "MaintenanceStatusReport_$(Get-UtcFileTimestamp).csv"
            }
            $result | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
            Write-Output "Maintenance status report written to: $Path ($($result.Count) rows)"
            return $result
        }
    }
}
