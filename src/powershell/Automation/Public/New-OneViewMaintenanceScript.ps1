#
# Public/New-OneViewMaintenanceScript.ps1 — Build a PowerShell script for HPE OneView maintenance mode enable/disable.
#

function New-OneViewMaintenanceScript {
    <#
    .SYNOPSIS
        Build a PowerShell script for HPE OneView maintenance mode operations.

    .PARAMETER Appliance
        OneView appliance hostname or IP.

    .PARAMETER ScopeName
        OneView scope name containing server hardware resources.

    .PARAMETER Operation
        'enable' or 'disable' maintenance mode.

    .PARAMETER Async
        Use -Async parameter for bulk operations (default: true).

    .EXAMPLE
        $ps = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'Production_Cluster_01' -Operation enable
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Appliance,
        [Parameter(Mandatory, Position = 1)][string] $ScopeName,
        [Parameter(Mandatory, Position = 2)][ValidateSet('enable', 'disable')][string] $Operation,
        [Parameter(Mandatory = $false)][bool] $Async = $true
    )
    
    $asyncParam = if ($Async) { '-Async' } else { '' }
    
    if ($Operation -eq 'enable') {
        return @"
Import-Module HPOneView.Managed -ErrorAction Stop
Connect-OVMgmt -Appliance "$Appliance" -Credential `$cred -ErrorAction Stop
`$scope = Get-OVScope -Name "$ScopeName" -ErrorAction Stop
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (-not `$s.MaintenanceModeEnabled) {
        Enable-OVMaintenanceMode -InputObject `$s $asyncParam -ErrorAction Stop
        Write-Host "Maintenance enabled: `$(`$s.Name)"
    }
}
"@
    }
    else {
        return @"
Import-Module HPOneView.Managed -ErrorAction Stop
Connect-OVMgmt -Appliance "$Appliance" -Credential `$cred -ErrorAction Stop
`$scope = Get-OVScope -Name "$ScopeName" -ErrorAction Stop
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (`$s.MaintenanceModeEnabled) {
        Disable-OVMaintenanceMode -InputObject `$s $asyncParam -ErrorAction Stop
        Write-Host "Maintenance disabled: `$(`$s.Name)"
    }
}
"@
    }
}