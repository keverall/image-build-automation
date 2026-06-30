#
# Public/New-OneViewMaintenanceScript.ps1 - Build a PowerShell script for HPE OneView maintenance mode enable/disable.
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

    .PARAMETER ModuleName
        PowerShell module name for HPE OneView (required).
        Format: HPEOneView.<major><minor> for OneView <major>.<minor> library (e.g., HPEOneView.1000 for OneView 10.00).
        See https://github.com/HewlettPackard/POSH-HPEOneView

    .EXAMPLE
        $ps = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'Production_Cluster_01' -Operation enable -ModuleName 'HPEOneView.1000'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Appliance,
        [Parameter(Mandatory, Position = 1)][string] $ScopeName,
        [Parameter(Mandatory, Position = 2)][ValidateSet('enable', 'disable')][string] $Operation,
        [Parameter(Mandatory = $false)][bool] $Async = $true,
        [Parameter(Mandatory = $false)][string] $ModuleName
    )
    
    if (-not $ModuleName) {
        Write-Warning "ModuleName not specified. Check oneview_config.json module_name setting."
        $ModuleName = $env:ONEVIEW_MODULE_NAME
    }
    if (-not $ModuleName) {
        $defaultModule = $null
        $installedModules = Get-Module -ListAvailable HPEOneView.* 2>$null | Select-Object -ExpandProperty Name
        if ($installedModules) {
            $sorted = $installedModules | Sort-Object { if ($_ -match 'HPEOneView\.(\d+)') { [int]$matches[1] } else { 0 } } -Descending
            $defaultModule = $sorted[0]
            Write-Verbose "Detected OneView module: $defaultModule"
        }
        if (-not $defaultModule) {
            $installedLegacy = Get-Module -ListAvailable HPOneView.* 2>$null | Select-Object -ExpandProperty Name
            if ($installedLegacy) {
                $defaultModule = $installedLegacy[0]
                Write-Verbose "Detected legacy OneView module: $defaultModule"
            }
        }
        $ModuleName = $defaultModule ?? 'HPEOneView.1000'
    }
    
    $asyncParam = if ($Async) { '-Async' } else { '' }
    
    if ($Operation -eq 'enable') {
        return @"
Import-Module $ModuleName -ErrorAction Stop
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
Import-Module $ModuleName -ErrorAction Stop
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