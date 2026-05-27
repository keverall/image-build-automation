---
source:  ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1
generated: 2026-05-27 17:30 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Set-MaintenanceMode

## Description

Orchestrates maintenance-mode operations across SCOM 2015 and HPE OpenView for a logical cluster defined in clusters_catalogue.json. Supports immediate enable/disable as well as scheduled windows with automatic disable via Windows Task Scheduler. Integrates with OpsRamp for metric/alert emission and can send email notifications.

**SCOM Group Mode**: When maintenance mode is enabled or disabled for SCOM, ALL objects in the SCOM group are affected — servers, network devices, cluster nodes, and the cluster server itself. This ensures complete alert suppression across the entire cluster.

**Post-Disable Wait**: After disabling SCOM maintenance mode, a configurable wait period (default 120 seconds) allows servers time to reboot, restart services, and stabilize before alerting resumes. This prevents the false alerts that support staff frequently report.

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Action` | 'enable', 'disable', or 'validate'. |
| `-ClusterId` | Cluster identifier string. |
| `-Mode` | 'scom' for SCOM maintenance mode only, or 'all' for both SCOM and OpenView (default: 'all'). |
| `-PostDisableWaitSeconds` | Seconds to sleep after disabling SCOM maintenance mode to allow servers time to reboot and stabilize before alerting resumes. Default: 120 (2 minutes). Set to 0 to skip. |
| `-ConfigDir` | Directory containing configuration files (default: 'configs'). |
| `-Start` | Maintenance start datetime string (default: now) format YYYY-MM-DD HH:MM . |
| `-End` | Maintenance end datetime string format YYYY-MM-DD HH:MM . |
| `-DryRun` | Simulate without making changes. |
| `-NoSchedule` | Do not create a Windows Scheduled Task for automatic disable at end time. |
| `-VerbosePreference` | Enable verbose debug logging. |

## Examples

### Example 1: Enable maintenance (default mode = all)
```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now
```
Enables maintenance mode for both SCOM (all group objects) and OpenView using the current time as the start.

### Example 2: Enable with explicit time window
```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start '2026-05-17 12:00' -End '2026-05-17 13:00'
```
Enables maintenance mode for both SCOM and OpenView with a specific time window (UTC format YYYY-MM-DD HH:MM).

### Example 3: Disable maintenance (with default 120s stabilization wait)
```powershell
Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'
```
Disables maintenance mode for both SCOM and OpenView. After SCOM exit, waits 120 seconds for servers to stabilize before alerting resumes.

### Example 4: SCOM-only maintenance mode
```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode scom -Start now -End '+2hours'
```
Enables maintenance mode for SCOM only (all objects in the SCOM group). OpenView is not affected.

### Example 5: Explicit all systems maintenance mode
```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode all -Start '2026-05-17 12:00' -End '2026-05-17 18:00'
```
Explicitly enables maintenance mode for both SCOM and OpenView with a scheduled window.

### Example 6: SCOM-only dry run
```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode scom -DryRun -Start now -End '+1hour'
```
Simulates enabling SCOM-only maintenance mode without making actual changes.

### Example 7: Disable SCOM-only maintenance with custom wait
```powershell
Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01' -Mode scom -PostDisableWaitSeconds 60
```
Disables SCOM maintenance mode and waits 60 seconds for servers to stabilize.

### Example 8: Disable with no stabilization wait
```powershell
Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01' -PostDisableWaitSeconds 0
```
Disables maintenance mode and immediately resumes alerting (no wait period).

## Original Comment-Based Help
```powershell
.SYNOPSIS
        Enable, disable, or validate maintenance mode for a server cluster.
        Callable from the module Router.

    .DESCRIPTION
        Orchestrates maintenance-mode operations across SCOM 2015 and HPE OpenView
        for a logical cluster defined in clusters_catalogue.json.
        Supports immediate enable/disable as well as scheduled windows with
        automatic disable via Windows Task Scheduler.
        Integrates with OpsRamp for metric/alert emission and can send email
        notifications.  The function is the PowerShell implementation.
        automation.cli.maintenance_mode module.

    .PARAMETER Action
        'enable', 'disable', or 'validate'.

    .PARAMETER ClusterId
        Cluster identifier string.

    .PARAMETER Mode
        'scom' for SCOM maintenance mode only, or 'all' for both SCOM and OpenView.

    .PARAMETER PostDisableWaitSeconds
        Seconds to sleep after disabling SCOM maintenance mode to allow servers
        time to reboot and restart services before alerting resumes.
        Default is 120 (2 minutes). Set to 0 to skip the wait.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs').

    .PARAMETER Start
        Maintenance start datetime string (default: now) format YYYY-MM-DD HH:MM .

    .PARAMETER End
        Maintenance end datetime string format YYYY-MM-DD HH:MM .

    .PARAMETER DryRun
        Simulate without making changes.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .PARAMETER VerbosePreference
        Enable verbose debug logging.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now

    .EXAMPLE
        Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 2026-05-17 12:00 -End 2026-05-17 13:00 (default UTC format YYYY-MM-DD HH:MM )

    .EXAMPLE
        Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` — do not edit manually.*
