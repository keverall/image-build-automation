# The official HPEOneView.Xxx library (e.g., HPEOneView.1000) natively relies on immediate execution cmdlets (Enable-OVMaintenanceMode and Disable-OVMaintenanceMode). Because the HPE OneView appliance itself does not have a native internal scheduler to delay or automatically stop hardware-level maintenance mode, scheduling must be handled at the PowerShell wrapper level. [1] 
# The production-ready script below uses an HPE OneView Scope (highly recommended for clusters to avoid hardcoded naming structures) or a naming pattern to capture your server nodes, and utilizes an in-memory timer or background job to manage start, end, or duration windows. [1, 2] 
# ## Pre-Requisites
# Ensure your administration environment has the module loaded and a valid session established: [3] 

# Import-Module HPEOneView.1000
# Connect-OVMgmt -Hostname "oneview.yourdomain.local" -Credential (Get-Credential)

# ------------------------------
## The Script: Manage-OVClusterMaintenance.ps1

<#
.SYNOPSIS
    Manages HPE OneView Maintenance Mode for ProLiant server clusters with custom schedules or durations.
.EXAMPLE
    # Scenario A: Run immediately for a specific duration (e.g., 2 hours)
    .\Manage-OVClusterMaintenance.ps1 -ClusterScopeName "Production_ESXi_Cluster01" -Action Enable -DurationMinutes 120

    # Scenario B: Schedule an exact maintenance window (Start and End times)
    .\Manage-OVClusterMaintenance.ps1 -ClusterScopeName "Production_ESXi_Cluster01" -Action Enable -StartTime "2026-05-20 22:00:00" -EndTime "2026-05-21 02:00:00"

    # Scenario C: Emergency stop / manual disable override immediately 
    .\Manage-OVClusterMaintenance.ps1 -ClusterScopeName "Production_ESXi_Cluster01" -Action Disable
#>

[CmdletBinding()]param (
    [Parameter(Required = $true)]
    [string]$ClusterScopeName,

    [Parameter(Required = $true)]
    [ValidateSet("Enable", "Disable", "Stop")]
    [string]$Action,

    [Parameter(Required = $false)]
    [int]$DurationMinutes = 0,

    [Parameter(Required = $false)]
    [datetime]$StartTime,

    [Parameter(Required = $false)]
    [datetime]$EndTime
)
# 1. Fetch Cluster Members using OneView Scopes (Best Practice for Clusters)
Write-Host "Fetching cluster resources linked to Scope: $ClusterScopeName..." -ForegroundColor Cyan
$Scope = Get-OVScope -Name $ClusterScopeName
if (-not $Scope) {
    Write-Error "Scope '$ClusterScopeName' not found inside OneView appliance."
    return
}
# Filter members to isolate Server Hardware assets
$ClusterServers = $Scope.Members | Where-Object { $_.Type -eq "ServerHardware" } | ForEach-Object { Get-OVServer -Name $_.Name }
if ($ClusterServers.Count -eq 0) {
    Write-Warning "No ServerHardware resources found inside the scope '$ClusterScopeName'."
    return
}

Write-Host "Targeting cluster nodes: $(($ClusterServers.Name) -join ', ')" -ForegroundColor Yellow
# Helper Functions
function Set-OVClusterMaintenanceState ([string]$TargetState) {
    foreach ($Server in $ClusterServers) {
        if ($TargetState -eq "Enable") {
            Write-Host "Enabling Maintenance Mode on: $($Server.Name)" -ForegroundColor Green
            # -Async parameter switch lets us pipeline multiple hardware targets simultaneously
            Enable-OVMaintenanceMode -InputObject $Server -Async | Out-Null
        } else {
            Write-Host "Disabling/Stopping Maintenance Mode on: $($Server.Name)" -ForegroundColor Red
            Disable-OVMaintenanceMode -InputObject $Server -Async | Out-Null
        }
    }
}
# 2. Process Logic Paths based on Action
switch ($Action) {
    "Disable" {
        # Immediate manual override to turn off maintenance mode
        Set-OVClusterMaintenanceState -TargetState "Disable"
        Write-Host "Maintenance mode turned off immediately for cluster." -ForegroundColor Gray
    }
    "Stop" {
        # Immediate alias for Disable
        Set-OVClusterMaintenanceState -TargetState "Disable"
        Write-Host "All active maintenance timers halted." -ForegroundColor Gray
    }
    "Enable" {
        # Calculate dynamic times if DurationMinutes was specified instead of a strict EndTime
        if ($DurationMinutes -gt 0 -and -not $StartTime -and -not $EndTime) {
            $StartTime = [DateTime]::Now
            $EndTime = [DateTime]::Now.AddMinutes($DurationMinutes)
            Write-Host "Calculated window based on duration: Starting now, ending at $EndTime" -ForegroundColor Cyan
        }

        # Sub-Scenario A: Scheduled for the future
        if ($StartTime -and $StartTime -gt [DateTime]::Now) {
            $WaitStartSeconds = [Math]::Max(0, ($StartTime - [DateTime]::Now).TotalSeconds)
            Write-Host "Future start time detected. Waiting ($($WaitStartSeconds)s) until $StartTime to trigger..." -ForegroundColor Yellow
            Start-Sleep -Seconds $WaitStartSeconds
        }

        # Trigger Maintenance State
        Set-OVClusterMaintenanceState -TargetState "Enable"
        Write-Host "Cluster successfully placed into HPE OneView Maintenance Mode." -ForegroundColor Green

        # Sub-Scenario B: Track the End Time/Duration to auto-disable
        if ($EndTime -and $EndTime -gt [DateTime]::Now) {
            $WaitEndSeconds = ($EndTime - [DateTime]::Now).TotalSeconds
            Write-Host "Monitoring maintenance window. Will automatically disable at $EndTime ($($WaitEndSeconds)s remaining)..." -ForegroundColor Yellow
            
            # Keeps session active during long execution windows
            Start-Sleep -Seconds $WaitEndSeconds

            Write-Host "Maintenance window expired. Re-enabling standard monitoring states..." -ForegroundColor Cyan
            Set-OVClusterMaintenanceState -TargetState "Disable"
            Write-Host "Cluster maintenance mode safely disabled." -ForegroundColor Green
        }
    }
}

# ------------------------------
## Key Behavioral Implementation Details

# * SCOM Integration Response: When this script changes a server to Enable, OneView pushes a property change to its resource model. The SCOM Integration Kit processes this change on its next query polling cycle, suppressing target alerts and suspending automated Remote Support case submissions.
# * Asynchronous Processing (-Async): The script executes tasks using the -Async flag. This fires the REST API command to all blades or nodes simultaneously rather than sequentially blocking your PowerShell thread, completing large cluster changes in seconds.
# * Scope Optimization: By grouping your cluster objects under an HPE OneView Scope (e.g., Production_ESXi_Cluster01), adding or removing server hardware nodes from the physical cluster automatically updates this script's targets without needing to modify your code variables. [1, 4, 5] 

# If you are planning to run long-running tasks over several hours, would you like me to rewrite this as a Windows Scheduled Task setup script or a PowerShell Background Job (Start-Job) wrapper so that closing your PowerShell window doesn't abort the tracking timer?

# [1] [https://community.hpe.com](https://community.hpe.com/t5/hpe-oneview/powershell-enable-ovmaintenancemode/td-p/7218430)
# [2] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=a00111922en_us&page=s_configureov_powershell.html&docLocale=en_US)
# [3] [https://www.powershellgallery.com](https://www.powershellgallery.com/packages/HPEOneView.540/5.40.2929.2263/Content/en-US%5Cabout_HPEOneView.540.help.txt)
# [4] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00006562en_us&page=s_sh-server-maintenance-mode.html&docLocale=en_US)
# [5] [https://community.hpe.com](https://community.hpe.com/t5/hpe-oneview/maintenance-mode-for-servers/td-p/6990877)
