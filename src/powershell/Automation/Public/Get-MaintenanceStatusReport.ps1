#
# Public/Get-MaintenanceStatusReport.ps1
#
# Read-only report that links SCOM and HPE OneView (OpenView) for clusters and
# their servers discovered from the LIVE connected SCOM appliance.
#
# IMPORTANT (per AGENTS.md testing rule):
#   - In LIVE mode the cluster/server list is discovered from SCOM itself
#     (Get-SCOMGroup + members). configs/clusters_catalogue.json is NOT the
#     source of truth here - it is only used as a fallback for -DryRun /
#     -IncludeLive:$false mock runs (i.e. tests).
#   - OneView is linked per server by server NAME (live), falling back to the
#     catalogue serial mapping only in mock mode.
#   - Never mutates maintenance mode; degrades gracefully to 'Unknown'.
#
# Request alias (router):  maintmode_status_report   -> Get-MaintenanceStatusReport
# Also invokable as:       scom-maintmode-status-report  (module alias)
#

function Get-MaintenanceStatusReport {
    <#
    .SYNOPSIS
        Generate a read-only status report linking SCOM and HPE OneView for clusters.

    .DESCRIPTION
        Discovers clusters/groups and their member servers from the connected SCOM
        management group (live), then for each server collects:
          - SCOM maintenance mode state + active maintenance window (start/end)
          - HPE OneView maintenance mode state (linked per server by name/serial)
          - The cluster power schedule (from catalogue enrichment; SCOM has none)
        Live SCOM/OneView queries degrade gracefully to 'Unknown' when unreachable.
        In -DryRun / -IncludeLive:$false the catalogue is used as mock data only.

    .PARAMETER ConfigDir
        Configuration directory (default: <project-root>/configs).

    .PARAMETER Environment
        Environment used to resolve management hosts (Test | Prod). Default: Prod,
        or $env:ENVIRONMENT when set.

    .PARAMETER ManagementHost
        Override the SCOM management server. Otherwise resolved from
        connection_hosts.json or $env:MAINTENANCE_HOST.

    .PARAMETER OneViewHost
        Override the HPE OneView appliance (may differ from the SCOM host). When
        omitted, resolved from connection_hosts.json, then falls back to
        -ManagementHost if that was supplied.

    .PARAMETER IncludeLive
        Query live SCOM + OneView (default). Use -IncludeLive:$false for a
        catalogue-only mock report (no network calls) - used by tests.

    .PARAMETER Format
        Output format: Csv (default, written to -Path), Json, or Table (console).

    .PARAMETER Path
        CSV output path. Defaults to generated/reports/MaintenanceStatusReport_<ts>.csv.

    .PARAMETER DryRun
        Alias for -IncludeLive:$false - catalogue-only mock report, no connections.

    .PARAMETER Json
        Emit the result rows as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.

    .PARAMETER PassThru
        Also return the structured [PSObject[]] result rows on the success stream.
        By default the command writes only the human-readable report (per -Format)
        and returns nothing, so the terminal/log never receives a truncated
        object dump. Capture the result into a variable, e.g.
        `$rows = Get-MaintenanceStatusReport -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself). When combined with -PassThru the report
        is suppressed but the objects are still returned.

    .OUTPUTS
        By default, nothing is returned on the success stream (the report is
        written to the host per -Format, or to a CSV file). With -PassThru, the
        [PSObject[]] result rows. With -Json, a JSON [string] of the same rows.

    .EXAMPLE
        Get-MaintenanceStatusReport -Environment Prod

    .EXAMPLE
        Get-MaintenanceStatusReport -ManagementHost scom01.corp.local -OneViewHost oneview.corp.local

    .EXAMPLE
        Invoke-RoutedRequest -RequestType 'maintmode_status_report' -Params @{ Environment = 'Prod' }
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

        [Alias('OVHost')]
        [string] $OneViewHost,

        [Alias('Live')]
        [bool] $IncludeLive = $true,

        [ValidateSet('Csv', 'Json', 'Table')]
        [string] $Format = 'Csv',

        [Alias('Out')]
        [string] $Path,

        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )

    if ($DryRun) {
        $IncludeLive = $false 
    }

    $generatedUtc = (Get-UtcTimestamp)

    # ── Resolve config dir ────────────────────────────────────────────────────
    $effectiveConfigDir = Resolve-EffectiveConfigDir -ConfigDir $ConfigDir `
        -MarkerFile 'clusters_catalogue.json' `
        -ExplicitlyBound:$PSBoundParameters.ContainsKey('ConfigDir')

    $clustersMap = Load-ClusterCatalogue (Join-Path $effectiveConfigDir 'clusters_catalogue.json')

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
    } else {
        @{} 
    }

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
    $resolvedOvHost = if ($PSBoundParameters.ContainsKey('OneViewHost')) {
        $OneViewHost
    } elseif ($PSBoundParameters.ContainsKey('ManagementHost')) {
        $ManagementHost
    } else {
        $ovEnv.Get_Item('appliance')
    }

    $scomCfg = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'scom_config.json') -Required:$false
    $scomUseWinRm = $false
    if ($scomCfg -and $scomCfg.ContainsKey('scom') -and $scomCfg['scom'].ContainsKey('use_winrm')) {
        $scomUseWinRm = [bool]$scomCfg['scom']['use_winrm']
    }

    # ── Build live managers (graceful: keep $null on any failure) ─────────────
    $scomMgr = $null
    $ovMgr = $null
    if ($IncludeLive) {
        if ($resolvedScomHost) {
            try {
                $scomMgr = [SCOMManager]::new(@{
                        management_server = $resolvedScomHost
                        powershell_module = 'OperationsManager'
                        use_winrm         = $scomUseWinRm
                        credentials       = @{ username_env = 'SCOM_ADMIN_USER'; password_env = 'SCOM_ADMIN_PASSWORD' }
                    })
            } catch {
                Write-Warning "SCOM manager init failed ($resolvedScomHost): $($_.Exception.Message)"
            }
        } else {
            Write-Warning "No SCOM management host resolved for environment '$effectiveEnv'."
        }

        if ($resolvedOvHost) {
            try {
                $ovMgr = [OneViewClient]::new(@{
                        oneview = @{
                            appliance   = $resolvedOvHost
                            use_winrm   = $false
                            credentials = @{ username_env = 'ONEVIEW_USER'; password_env = 'ONEVIEW_PASSWORD' }
                        }
                    })
            } catch {
                Write-Warning "OneView manager init failed ($resolvedOvHost): $($_.Exception.Message)"
            }
        } else {
            Write-Warning "No OneView appliance resolved for environment '$effectiveEnv'."
        }
    }

    # ── Helper: build a short-name lookup key (fqdn + hostname) ────────────────
    function _BuildServerKey([string]$Name) {
        $n = $Name.ToLower()
        return @($n, ($n.Split('.'))[0])
    }

    # ── Discover cluster units ─────────────────────────────────────────────────
    # LIVE: enumerate groups + member servers from the connected SCOM appliance.
    # MOCK (-DryRun): fall back to the catalogue (test fixture only).
    $clusterUnits = [System.Collections.Generic.List[hashtable]]::new()

    if ($IncludeLive -and $scomMgr) {
        $discScript = @"
Import-Module $($scomMgr.ModuleName) -ErrorAction Stop
`$null = New-SCOMManagementGroupConnection -ComputerName "$($scomMgr.MgmtServer)" -ErrorAction Stop
`$groups = Get-SCOMGroup -ErrorAction Stop
`$out = @()
foreach (`$g in `$groups) {
    try {
        `$members = Get-SCOMClassInstance -Group `$g -ErrorAction SilentlyContinue
        `$servers = `@(`$members | Where-Object {
            `$_.ClassName -like '*Windows*Computer*' -or `$_.ClassName -like '*Cluster*'
        } | ForEach-Object { `$_.DisplayName })
        if (`$servers.Count -gt 0) {
            `$out += @{ group = `$g.DisplayName; servers = `$servers }
        }
    } catch { }
}
`$out | ConvertTo-Json -Depth 4
"@
        try {
            $dr = $scomMgr._RunPs($discScript)
            if ($dr.Success -and $dr.Output) {
                $discovered = $dr.Output | ConvertFrom-Json
                foreach ($d in $discovered) {
                    $clusterUnits.Add(@{
                            ClusterId   = $d.group
                            DisplayName = $d.group
                            SCOMGroup   = $d.group
                            Servers     = @($d.servers)
                            Environment = $effectiveEnv
                            OvScope     = $null
                            Schedule    = @{}
                            Source      = 'SCOM'
                        })
                }
            }
        } catch {
            Write-Verbose "SCOM discovery error: $($_.Exception.Message)"
        }
    }

    # Mock fallback (also covers -DryRun and live-SCOM-unavailable).
    if ($clusterUnits.Count -eq 0) {
        if ($IncludeLive) {
            Write-Warning "Live SCOM discovery returned no clusters - falling back to catalogue (mock) data."
        }
        if ($clustersMap) {
            foreach ($ce in $clustersMap.GetEnumerator()) {
                $cdef = $ce.Value
                $clusterUnits.Add(@{
                        ClusterId   = $ce.Key
                        DisplayName = $cdef.Get_Item('display_name') ?? $ce.Key
                        SCOMGroup   = $cdef.Get_Item('scom_group')
                        Servers     = @($cdef.Get_Item('servers') ?? @())
                        Environment = $cdef.Get_Item('environment') ?? $effectiveEnv
                        OvScope     = $cdef.Get_Item('oneview_scope')
                        Schedule    = $cdef.Get_Item('schedule') ?? @{}
                        Source      = 'Catalogue'
                    })
            }
        }
    }

    if ($clusterUnits.Count -eq 0) {
        Write-Error "No clusters discovered from SCOM and none in catalogue at '$effectiveConfigDir'."
        return (_Publish-Result -Result @() -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }

    # ── Build OneView server index once (live) for name/serial linking ────────
    $ovIndex = $null
    if ($IncludeLive -and $ovMgr) {
        try {
            $ovList = Get-OneViewServerList -OneViewHost $resolvedOvHost -PassThru
            if ($ovList.Success) {
                $ovIndex = @{}
                foreach ($s in $ovList.Servers) {
                    $nm = "$($s.name)".ToLower(); $sh = ($nm.Split('.'))[0]
                    $ovIndex[$nm] = $s; $ovIndex[$sh] = $s
                    if ($s.serial_number) {
                        $ovIndex["$($s.serial_number)".ToLower()] = $s 
                    }
                }
            }
        } catch {
            Write-Verbose "OneView server list error: $($_.Exception.Message)"
        }
    }

    # ── Dry config SCOM<->OneView index (mock only, sourced from configs/) ─────
    # Used when -DryRun / -IncludeLive:$false. No API calls - purely the static
    # servers_catalogue.oneview.json dry fixture, keyed by name/serial.
    $dryOvIndex = $null
    if (-not $IncludeLive) {
        try {
            $svc = Import-JsonConfig -Path (Join-Path $effectiveConfigDir 'servers_catalogue.oneview.json') -Required:$false
            if ($svc -and $svc.ContainsKey('servers')) {
                $dryOvIndex = @{}
                foreach ($e in $svc['servers'].GetEnumerator()) {
                    $v = $e.Value
                    foreach ($kk in @($e.Key, $v['oneview_name'], $v['display_name'], $v['serial_number'])) {
                        if ($kk) {
                            $dryOvIndex["$($kk)".ToLower()] = $v 
                        }
                    }
                    if ($v['oneview_name']) {
                        $dryOvIndex[($v['oneview_name'].ToLower().Split('.'))[0]] = $v
                    }
                }
            }
        } catch {
            Write-Verbose "Dry OneView config load error: $($_.Exception.Message)"
        }
    }

    # ── Iterate cluster units, one CSV row per server ─────────────────────────
    $rows = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($unit in $clusterUnits) {
        $scomGroup = $unit.SCOMGroup
        $servers = if ($unit.Servers.Count -eq 0) {
            @($unit.ClusterId) 
        } else {
            $unit.Servers 
        }
        $schedule = $unit.Schedule
        $powerStart = if ($schedule -and $schedule.ContainsKey('work_start')) {
            $schedule['work_start'] 
        } else {
            'n/a (not sourced from SCOM)' 
        }
        $powerEnd = if ($schedule -and $schedule.ContainsKey('work_end')) {
            $schedule['work_end'] 
        } else {
            'n/a (not sourced from SCOM)' 
        }
        $powerTz = if ($schedule -and $schedule.ContainsKey('timezone')) {
            $schedule['timezone'] 
        } else {
            'n/a' 
        }

        # ── Live SCOM status for this group ───────────────────────────────────
        $scomOk = $false
        $scomByServer = @{}
        if ($IncludeLive -and $scomMgr -and $scomGroup) {
            try {
                $status = $scomMgr.GetMaintenanceStatus($scomGroup, $servers, $false)
                if ($status.Success) {
                    $scomOk = $true
                    foreach ($obj in $status.Objects) {
                        foreach ($k in (_BuildServerKey $obj.Name)) {
                            $scomByServer[$k] = $obj 
                        }
                    }
                }
            } catch {
                Write-Verbose "SCOM status error for '$scomGroup': $($_.Exception.Message)" 
            }
        }

        # ── OneView status: live (per-server link) or mock (dry config) ─────────
        $ovOk = $false
        $ovByServer = @{}   # keyed by server name -> status object (live only)
        if ($IncludeLive -and $ovMgr -and $ovIndex) {
            # Link each SCOM/server name to an OneView server, then resolve state.
            foreach ($srv in $servers) {
                $srvKey = $srv.ToLower(); $srvShort = ($srvKey.Split('.'))[0]
                $ovServer = $null
                if ($ovIndex.ContainsKey($srvKey)) {
                    $ovServer = $ovIndex[$srvKey] 
                } elseif ($ovIndex.ContainsKey($srvShort)) {
                    $ovServer = $ovIndex[$srvShort] 
                }
                if ($ovServer) {
                    try {
                        $st = $ovMgr.GetMaintenanceStatus($ovServer.name, 'ServerHardware')
                        if ($st.Success -and $st.Objects.Count -gt 0) {
                            $ovOk = $true
                            $ovByServer[$srvKey] = $st.Objects[0]
                            if (-not $ovByServer.ContainsKey($srvShort)) {
                                $ovByServer[$srvShort] = $st.Objects[0] 
                            }
                        }
                    } catch {
                        Write-Verbose "OneView status error for '$($ovServer.name)': $($_.Exception.Message)" 
                    }
                }
            }
        }

        foreach ($srv in $servers) {
            $srvKey = $srv.ToLower(); $srvShort = ($srvKey.Split('.'))[0]

            # SCOM state
            $scomState = 'Unknown'; $scomStart = ''; $scomEnd = ''
            $scomObj = $null
            if ($scomByServer.ContainsKey($srvKey)) {
                $scomObj = $scomByServer[$srvKey] 
            } elseif ($scomByServer.ContainsKey($srvShort)) {
                $scomObj = $scomByServer[$srvShort] 
            }
            if ($scomObj) {
                $scomState = if ($scomObj.InMaintenanceMode) {
                    'InMaintenance' 
                } else {
                    'NotInMaintenance' 
                }
                if ($scomObj.MaintenanceModeStartTime) {
                    $scomStart = (Convert-ToUtcIso8601 $scomObj.MaintenanceModeStartTime) 
                }
                if ($scomObj.MaintenanceModeEndTime) {
                    $scomEnd = (Convert-ToUtcIso8601 $scomObj.MaintenanceModeEndTime) 
                }
            }

            # OneView state + link method
            $ovState = 'Unknown'; $linkMethod = 'None'
            $ovObj = $null
            if ($ovByServer.ContainsKey($srvKey)) {
                $ovObj = $ovByServer[$srvKey] 
            } elseif ($ovByServer.ContainsKey($srvShort)) {
                $ovObj = $ovByServer[$srvShort] 
            }
            if ($ovObj) {
                $linkMethod = if ($unit.Source -eq 'Catalogue') {
                    'Catalogue' 
                } else {
                    'Name' 
                }
                $ovState = if ($ovObj.InMaintenanceMode) {
                    'InMaintenance' 
                } else {
                    'NotInMaintenance' 
                }
            } elseif (-not $IncludeLive -and $dryOvIndex) {
                # Mock: link from dry config (servers_catalogue.oneview.json) - no live state
                $dryMatch = $null
                if ($dryOvIndex.ContainsKey($srvKey)) {
                    $dryMatch = $dryOvIndex[$srvKey] 
                } elseif ($dryOvIndex.ContainsKey($srvShort)) {
                    $dryMatch = $dryOvIndex[$srvShort] 
                }
                if ($dryMatch) {
                    $matchedBySerial = ($dryMatch['serial_number'] -and
                        (($srvKey -eq $dryMatch['serial_number'].ToLower()) -or ($srvShort -eq $dryMatch['serial_number'].ToLower())))
                    $linkMethod = if ($matchedBySerial) {
                        'Serial' 
                    } else {
                        'Name' 
                    }
                }
            }

            $dataSource = if (-not $IncludeLive) {
                'CatalogueOnly' 
            } elseif ($scomOk -and $ovOk) {
                'Live' 
            } elseif ($scomOk) {
                'Partial-SCOM' 
            } elseif ($ovOk) {
                'Partial-OneView' 
            } else {
                'CatalogueOnly' 
            }

            $rows.Add([PSCustomObject]@{
                    ReportGeneratedUtc     = $generatedUtc
                    ClusterId              = $unit.ClusterId
                    ClusterDisplayName     = $unit.DisplayName
                    Environment            = $unit.Environment
                    SCOMGroup              = $scomGroup
                    Server                 = $srv
                    SCOMMaintenanceMode    = $scomState
                    SCOMWindowStartUtc     = $scomStart
                    SCOMWindowEndUtc       = $scomEnd
                    SCOMWindowComment      = 'n/a (status query does not expose comment)'
                    OneViewMaintenanceMode = $ovState
                    OneViewLinkMethod      = $linkMethod
                    OneViewScope           = $unit.OvScope
                    PowerScheduleStart     = $powerStart
                    PowerScheduleEnd       = $powerEnd
                    PowerScheduleTimezone  = $powerTz
                    DataSource             = $dataSource
                })
        }
    }

    # ── Audit the report generation (read-only action, still auditable) ────────
    try {
        $audit = New-AuditLogger -Category 'maintenance_status_report' `
            -LogDir (Join-Path (Get-ProjectRoot) 'generated/logs/audit') -MasterLogName 'audit.log'
        $src = if ($IncludeLive) {
            'SCOM' 
        } else {
            'Catalogue' 
        }
        $audit.Log('report_generate', 'INFO', '', "Rows=$($rows.Count) Environment=$effectiveEnv Live=$IncludeLive Source=$src") | Out-Null
        $audit.Save() | Out-Null
    } catch {
        Write-Verbose "Audit logging skipped: $($_.Exception.Message)" 
    }

    # ── Output ─────────────────────────────────────────────────────────────────
    $result = $rows.ToArray()

    # Human-readable report (per -Format). Suppressed with -Quiet.
    if (-not $Quiet) {
        switch ($Format) {
            'Json' {
                $result | ConvertTo-Json -Depth 4 | Out-Host 
            }
            'Table' {
                $result | Format-Table -AutoSize | Out-Host 
            }
            default {
                if (-not $Path) {
                    $projRoot = Get-ProjectRoot
                    if (-not $projRoot) {
                        $projRoot = (Get-Location).Path 
                    }
                    $reportDir = Join-Path $projRoot 'generated/reports'
                    Ensure-DirectoryExists -Path $reportDir
                    $Path = Join-Path $reportDir "MaintenanceStatusReport_$(Get-UtcFileTimestamp).csv"
                }
                $result | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
                Write-Host "Maintenance status report written to: $Path ($($result.Count) rows)"
            }
        }
    }

    # Data consumers: -Json for a JSON string, -PassThru for the raw objects.
    if ($Json) {
        return ($result | ConvertTo-Json -Depth 4)
    }
    if ($PassThru) {
        return $result
    }
    return
}
