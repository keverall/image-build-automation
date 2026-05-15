#
# Private/_RouteMap.ps1 — Request type → handler function name mapping.
# Loaded before Router.ps1 so $script:RouteMap is defined when Router parses.
#

$script:RouteMap = @{
    'build_iso'         = 'New-IsoBuild'
    'update_firmware'   = 'Update-Firmware'
    'patch_windows'     = 'Invoke-WindowsSecurityUpdate'
    'deploy'            = 'Invoke-IsoDeploy'
    'monitor'           = 'Start-InstallMonitor'
    'maintenance_enable'   = 'Set-MaintenanceMode'
    'maintenance_disable'  = 'Set-MaintenanceMode'
    'maintenance_validate' = 'Set-MaintenanceMode'
    'opsramp_report'    = 'Invoke-OpsRamp'
    'generate_uuid'     = 'Test-Uuid'
}
