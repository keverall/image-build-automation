#
# Public/New-ScomMaintenanceScript.ps1 — Build a PowerShell script for SCOM maintenance mode start/stop.
#

function New-ScomMaintenanceScript {
    <#
    .SYNOPSIS
        Build a PowerShell script for SCOM maintenance mode start/stop on a group.

    .PARAMETER GroupDisplayName
        SCOM group display name.

    .PARAMETER DurationSeconds
        Duration in seconds (used for start).

    .PARAMETER Comment
        Maintenance comment string.

    .PARAMETER Operation
        'start' or 'stop' (default: start).

    .EXAMPLE
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'PROD-CLUSTER-01' -DurationSeconds 14400 -Comment 'iRequest'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $GroupDisplayName,
        [Parameter(Mandatory, Position = 1)][int]    $DurationSeconds,
        [Parameter(Mandatory, Position = 2)][string] $Comment,
        [ValidateSet('start','stop')]
        [Parameter(Mandatory = $false)][string] $Operation = 'start'
    )
    $safeComment = $Comment.Replace("'", "''")
    if ($Operation -eq 'start') {
        return @"
Import-Module OperationsManager -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$duration = New-TimeSpan -Seconds $DurationSeconds
`$comment = '$safeComment'
`$failed = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        Write-Host "`$(`$inst.Name) already in maintenance - skipping"
    } else {
        try {
            Start-SCOMMaintenanceMode -Instance `$inst -Duration `$duration -Comment `$comment -ErrorAction Stop
            Write-Host "Maintenance started: `$(`$inst.Name)"
        } catch {
            Write-Error "Failed for `$(`$inst.Name): `$_"
            `$failed += `$inst.Name
        }
    }
}
if (`$failed.Count -gt 0) {
    Write-Error "Failed for: `$(`$failed -join ', ')"
    exit 1
} else {
    Write-Host "All instances entered maintenance successfully"
}
"@
    }
    else {
        return @"
Import-Module OperationsManager -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$stopped = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        try {
            Stop-SCOMMaintenanceMode -Instance `$inst -ErrorAction Stop
            Write-Host "Maintenance stopped: `$(`$inst.Name)"
            `$stopped += `$inst.Name
        } catch {
            Write-Error "Failed to stop for `$(`$inst.Name): `$_"
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
    }
}
