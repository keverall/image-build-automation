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
        [Alias('Appl')]
        [Parameter(Mandatory, Position = 0)][string] $Appliance,
        [Alias('Scope')]
        [Parameter(Mandatory, Position = 1)][string] $ScopeName,
        [Alias('Op')]
        [Parameter(Mandatory, Position = 2)][ValidateSet('enable', 'disable')][string] $Operation,
        [Parameter(Mandatory = $false)][bool] $Async = $true,
        [Parameter(Mandatory = $false)][string] $ModuleName
    )
    
    if (-not $ModuleName) {
        # 1. Explicit env override wins.
        $envVal = $env:ONEVIEW_MODULE_NAME
        if ($envVal -and $envVal -match '^(HPEOneView|HPOneView)\.\d+$') {
            if (Get-Module -ListAvailable -Name $envVal -ErrorAction SilentlyContinue) {
                $ModuleName = $envVal
            } else {
                Write-Warning "ONEVIEW_MODULE_NAME '$envVal' is not installed; detecting from appliance instead."
            }
        } elseif ($envVal) {
            Write-Warning "ONEVIEW_MODULE_NAME '$envVal' is not a valid OneView module name; ignoring."
        }
    }
    if (-not $ModuleName) {
        # 2. Probe the appliance and map its major version to the matching library.
        try {
            $ver = Invoke-RestMethod -Uri "https://${Appliance}/rest/version" -Method Get -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
            if ($ver -and $null -ne $ver.currentVersion) {
                [long]$n = 0
                if ([long]::TryParse("$($ver.currentVersion)", [ref]$n)) {
                    [int]$major = if ($n -ge 1000) { $n / 1000 } elseif ($n -ge 100) { $n / 100 } else { $n }
                    $candidate = "HPEOneView.$($major)000"
                    if (Get-Module -ListAvailable -Name $candidate -ErrorAction SilentlyContinue) {
                        $ModuleName = $candidate
                    } else {
                        Write-Warning "Appliance reports OneView $major, but module '$candidate' is not installed."
                    }
                }
            }
        } catch {
            Write-Verbose "Appliance version probe failed: $($_.Exception.Message)"
        }
    }
    if (-not $ModuleName) {
        # 3. Fallback: highest installed module (warned).
        $installedModules = @(Get-Module -ListAvailable HPEOneView.* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        if (-not $installedModules) {
            $installedModules = @(Get-Module -ListAvailable HPOneView.* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        }
        if ($installedModules) {
            $ModuleName = $installedModules | Sort-Object { if ($_ -match 'HPEOneView\.(\d+)') { [int]$matches[1] } elseif ($_ -match 'HPOneView\.(\d+)') { [int]$matches[1] } else { 0 } } -Descending | Select-Object -First 1
            Write-Warning "Could not pin OneView module from appliance/env; using highest installed '$ModuleName'. Verify it matches the appliance version."
        } else {
            $ModuleName = 'HPEOneView.1000'
        }
    }
    
    $asyncParam = if ($Async) { '-Async' } else { '' }
    
    if ($Operation -eq 'enable') {
        return @"
Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ModuleName' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ModuleName -ErrorAction Stop
Connect-OVMgmt -Appliance "$Appliance" -Credential `$cred -ErrorAction Stop
`$scope = Get-OVScope -Name "$ScopeName" -ErrorAction Stop
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (-not `$s.MaintenanceModeEnabled) {
        Enable-OVMaintenanceMode -InputObject `$s $asyncParam -ErrorAction Stop
        Write-Output "Maintenance enabled: `$(`$s.Name)"
    }
}
"@
    }
    else {
        return @"
Get-Module -Name 'HPEOneView.*','HPOneView.*' -ErrorAction SilentlyContinue | Where-Object { `$_.Name -ne '$ModuleName' } | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ModuleName -ErrorAction Stop
Connect-OVMgmt -Appliance "$Appliance" -Credential `$cred -ErrorAction Stop
`$scope = Get-OVScope -Name "$ScopeName" -ErrorAction Stop
`$servers = `$scope.Members | Where-Object { `$_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name `$_.Name }
foreach (`$s in `$servers) {
    if (`$s.MaintenanceModeEnabled) {
        Disable-OVMaintenanceMode -InputObject `$s $asyncParam -ErrorAction Stop
        Write-Output "Maintenance disabled: `$(`$s.Name)"
    }
}
"@
    }
}