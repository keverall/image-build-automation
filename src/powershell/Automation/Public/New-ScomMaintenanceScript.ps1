#
# Public/New-ScomMaintenanceScript.ps1 - Build a PowerShell script for SCOM maintenance mode start/stop.
# Supports both individual-instance (group-level) and cluster-level (cluster-class) operations.
#

function New-ScomMaintenanceScript {
    <#
    .SYNOPSIS
        Build a PowerShell script for SCOM maintenance mode start/stop.
        Supports two modes: Group (individual class instances) and Cluster (Microsoft.Windows.Cluster class).

    .PARAMETER GroupDisplayName
        SCOM group display name (used in Group mode).

    .PARAMETER ServerHostnames
        Array of server hostnames to resolve to SCOM class instances (used in Cluster mode).

    .PARAMETER EndTimeStr
        Maintenance end time as an ISO-8601 / culture-invariant datetime string (used for start).

    .PARAMETER Reason
        MaintenanceModeReason string: PlannedOther, PlannedHardwareInstallation,
        PlannedApplicationInstallation, etc. (default: PlannedOther).

    .PARAMETER Comment
        Maintenance comment string.

    .PARAMETER Operation
        'start' or 'stop' (default: start).

    .PARAMETER UseClusterMode
        Switch. When set, operates at Microsoft.Windows.Cluster class level
        and applies maintenance mode recursively to all cluster nodes.

    .EXAMPLE
        # Group mode - set maintenance on all instances in a group
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'CLU-CLUSTER-01' `
            -EndTimeStr '2026-05-22T06:00:00' -Reason 'PlannedOther' -Comment 'iRequest'

    .EXAMPLE
        # Cluster mode - set maintenance at cluster level + all nodes
        $ps = New-ScomMaintenanceScript -ServerHostnames @('srv01.corp.local','srv02.corp.local') `
            -EndTimeStr '2026-05-22T06:00:00' -Reason 'PlannedOther' -Comment 'iRequest' -UseClusterMode
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, Position = 0)][string] $GroupDisplayName,
        [Parameter(Mandatory = $false)][string[]]    $ServerHostnames,
        [Parameter(Mandatory = $false)][string]      $EndTimeStr,
        [Parameter(Mandatory = $false)][string]      $Reason = 'PlannedOther',
        [Parameter(Mandatory, Position = 1)][string] $Comment,
        [ValidateSet('start', 'stop')]
        [Parameter(Mandatory = $false)][string]      $Operation = 'start',
        [Parameter(Mandatory = $false)][switch]      $UseClusterMode
    )

    $safeComment = $Comment.Replace("'", "''")
    $serversBlock = if ($ServerHostnames -and $ServerHostnames.Count -gt 0) {
        $serverLines = $ServerHostnames | ForEach-Object { "                `"$($_.Replace('"','\"'))`"," }
        "`n                $($serverLines -join "`n")`n            "
    } else {
        '' 
    }

    if ($Operation -eq 'start') {
        if ($UseClusterMode) {
            # ─── CLUSTER MODE ─────────────────────────────────────────────────────
            # Strategy (per wip/HPe-Openview-maintenance-mode.ps1 + MS Learn SCOM docs):
            #   1. For each server hostname, resolve its SCOM agent
            #   2. If agent is cluster-managed, get the Microsoft.Windows.Cluster class instance
            #   3. Call ScheduleMaintenanceMode on the cluster instance (Recursive → all nodes)
            #   4. For non-cluster agents, call ScheduleMaintenanceMode on the individual instance
            return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ErrorAction Stop
`$MgmtSrv = Get-SCOMManagementServer | Select-Object -First 1
`$endTime  = [DateTime]::Parse('$EndTimeStr')
`$reason   = '$Reason'
`$comment  = '$safeComment'
`$failed   = @()
`$clusterNodeClass  = Get-SCOMClass -Name 'Microsoft.Windows.Cluster.Node' -ErrorAction SilentlyContinue
`$clusterClass      = Get-SCOMClass -Name 'Microsoft.Windows.Cluster'     -ErrorAction SilentlyContinue

`$serverList = @($serversBlock)

foreach (`$serverName in `$serverList) {
    try {
        `$agent = Get-SCOMAgent -Name `$serverName -ErrorAction Stop
        `$instance = `$agent.HostComputer
        if (`$agent.GetRemotelyManagedComputers()) {
            # Server is cluster-managed - find and schedule maintenance at cluster level
            `$clusters = `$agent.GetRemotelyManagedComputers()
            foreach (`$cluster in `$clusters) {
                `$cName   = `$cluster.ComputerName
                `$clusterInstances = Get-SCOMClassInstance -Class `$clusterClass -ErrorAction SilentlyContinue `
                    | Where-Object { `$_.Displayname -like "*`$cName*" }
                foreach (`$ci in `$clusterInstances) {
                    if (`$ci) {
                        try {
                            `$ci.ScheduleMaintenanceMode(`$endTime, `$reason, `$comment, 'Recursive')
                            Write-Host "Cluster maintenance started: `$(`$ci.DisplayName)"
                            `$nodes = `$ci.GetRelatedMonitoringObjects(`$clusterNodeClass)
                            if (`$nodes) {
                                foreach (`$node in `$nodes) {
                                    Write-Host "  Node in maintenance: `$(`$node.DisplayName)" -ForegroundColor Green
                                }
                            }
                        } catch {
                            Write-Warning "Cluster `$cName entry failed: `$(`$_.Exception.Message)"
                        }
                    }
                }
                # Also schedule maintenance on the cluster computer object
                `$clusterComputer = `$cluster.Computer
                try {
                    `$clusterComputer.ScheduleMaintenanceMode(`$endTime, `$reason, `$comment, 'Recursive')
                    Write-Host "Cluster computer maintenance started: `$cName" -ForegroundColor Blue
                } catch {
                    Write-Warning "`$cName computer entry failed: `$(`$_.Exception.Message)"
                }
            }
        } else {
            # Standalone server - individual maintenance mode
            try {
                `$instance.ScheduleMaintenanceMode(`$endTime, `$reason, `$comment)
                Write-Host "Maintenance started: `$serverName"
            } catch {
                Write-Error "Failed for `$serverName : `$(`$_.Exception.Message)"
                `$failed += `$serverName
            }
        }
    } catch {
        Write-Error "Agent `$serverName not found or unreachable: `$(`$_.Exception.Message)"
        `$failed += `$serverName
    }
}

if (`$failed.Count -gt 0) {
    Write-Error "Failed for: `$(`$failed -join ', ')"
    exit 1
} else {
    Write-Host "All cluster nodes entered maintenance successfully"
}
"@
        } else {
            # ─── GROUP MODE ───────────────────────────────────────────────────────
            return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ErrorAction Stop
`$group    = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$endTime  = [DateTime]::Parse('$EndTimeStr')
`$reason   = '$Reason'
`$comment  = '$safeComment'
`$failed   = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        Write-Host "`$(`$inst.Name) already in maintenance - skipping"
    } else {
        try {
            `$inst.ScheduleMaintenanceMode(`$endTime, `$reason, `$comment)
            Write-Host "Maintenance started: `$(`$inst.Name)"
        } catch {
            Write-Error "Failed for `$(`$inst.Name): `$(`$_.Exception.Message)"
            `$failed += `$inst.Name
        }
    }
}
if (`$failed.Count -gt 0) {
    Write-Error "Failed for: `$(`$failed -join ', ')"
    exit 1
} else {
    Write-Host "All group instances entered maintenance successfully"
}
"@
        }
    } else {
        # ─── STOP ───────────────────────────────────────────────────────────────
        if ($UseClusterMode) {
            return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ErrorAction Stop
`$MgmtSrv = Get-SCOMManagementServer | Select-Object -First 1
`$clusterNodeClass = Get-SCOMClass -Name 'Microsoft.Windows.Cluster.Node' -ErrorAction SilentlyContinue
`$clusterClass     = Get-SCOMClass -Name 'Microsoft.Windows.Cluster'     -ErrorAction SilentlyContinue
`$stopped  = @()
`$serverList = @($serversBlock)
foreach (`$serverName in `$serverList) {
    try {
        `$agent    = Get-SCOMAgent -Name `$serverName -ErrorAction Stop
        `$instance = `$agent.HostComputer
        if (`$agent.GetRemotelyManagedComputers()) {
            `$clusters = `$agent.GetRemotelyManagedComputers()
            foreach (`$cluster in `$clusters) {
                `$cName   = `$cluster.ComputerName
                `$clusterInstances = Get-SCOMClassInstance -Class `$clusterClass -ErrorAction SilentlyContinue `
                    | Where-Object { `$_.Displayname -like "*`$cName*" }
                foreach (`$ci in `$clusterInstances) {
                    if (`$ci) {
                        try {
                            `$ci.StopMaintenanceMode()
                            Write-Host "Cluster maintenance stopped: `$(`$ci.DisplayName)"
                            `$stopped += `$ci.DisplayName
                        } catch {
                            Write-Warning "Failed to stop cluster `$cName: `$(`$_.Exception.Message)"
                        }
                    }
                }
                `$clusterComputer = `$cluster.Computer
                try {
                    `$clusterComputer.StopMaintenanceMode()
                    Write-Host "Cluster computer maintenance stopped: `$cName"
                } catch {
                    Write-Warning "Failed to stop `$cName: `$(`$_.Exception.Message)"
                }
            }
        } else {
            if (`$instance.InMaintenanceMode) {
                try {
                    `$instance.StopMaintenanceMode()
                    Write-Host "Maintenance stopped: `$serverName"
                    `$stopped += `$serverName
                } catch {
                    Write-Error "Failed to stop for `$serverName : `$(`$_.Exception.Message)"
                }
            } else {
                Write-Host "`$serverName not in maintenance - skipping"
            }
        }
    } catch {
        Write-Warning "Agent `$serverName not found: `$(`$_.Exception.Message)"
    }
}
if (`$stopped.Count -gt 0) {
    Write-Host "Stopped maintenance for `$(`$stopped.Count) cluster nodes/servers"
} else {
    Write-Host "No cluster nodes/servers were in maintenance"
}
"@
        } elseif ($GroupDisplayName) {
            return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ErrorAction Stop
`$group     = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$stopped   = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        try {
            `$inst.StopMaintenanceMode()
            Write-Host "Maintenance stopped: `$(`$inst.Name)"
            `$stopped += `$inst.Name
        } catch {
            Write-Error "Failed to stop for `$(`$inst.Name): `$(`$_.Exception.Message)"
        }
    } else {
        Write-Host "`$(`$inst.Name) not in maintenance - skipping"
    }
}
if (`$stopped.Count -gt 0) {
    Write-Host "Stopped maintenance for `$(`$stopped.Count) instances"
} else {
    Write-Host "No instances were in maintenance"
}
"@
        } else {
            return @"
Write-Error "No GroupDisplayName or ServerHostnames supplied for stop operation."
exit 1
"@
        }
    }
}
