---
source:  ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1
generated: 2026-07-22 10:18 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Set-MaintenanceMode

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
  - [Example 4](#example-4)
  - [Example 5](#example-5)
  - [Example 6](#example-6)
  - [Example 7](#example-7)
  - [Example 8](#example-8)
  - [Example 9](#example-9)
- [Original Comment-Based Help](#original-comment-based-help)


<a name="description"></a>
## Description

Orchestrates maintenance-mode operations across SCOM 2015 and HPE OpenView for a logical cluster defined in clusters_catalogue.json. Supports immediate enable/disable as well as scheduled windows with automatic disable via Windows Task Scheduler. Integrates with OpsRamp for metric/alert emission and can send email notifications.  The function is the PowerShell implementation. All datetime values are UTC only. Local time conversion is not performed.

<a name="parameters"></a>
## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Action` | 'enable', 'disable', or 'validate'. Default is 'enable'. |
| `-TargetId` | Target identifier string (cluster ID or server name). Required. |
| `-Mode` | 'scom' for SCOM-only or 'oneview' for HPE OpenView-only. SCOM manages Windows cluster objects; OpenView manages hardware directly. Required. |
| `-Environment` | Environment selection: 'Test' or 'Prod'. Determines which hosts to connect to from connection_hosts.json. If not specified, reads from $env:ENVIRONMENT environment variable. Defaults to 'Prod' if neither is set. |
| `-ManagementHost` | Optional override for management server/appliance hostname/IP. Takes precedence over environment config. For SCOM mode: overrides SCOM management server For OneView mode: overrides OneView appliance Can also be set via $env:MAINTENANCE_HOST |
| `-SerialNumber` | Optional serial number for OneView mode (Marin's preference). Only valid when -Mode is 'oneview'. Will reject if used with SCOM mode. When provided, the script will look up the server by serial number in OneView. |
| `-Username` | Optional direct username parameter (for testing only). Not recommended for production use - use environment variables instead. For SCOM: overrides $env:SCOM_ADMIN_USER For OneView: overrides $env:ONEVIEW_USER |
| `-PostDisableWaitSeconds` | Seconds to sleep after disabling SCOM maintenance mode to allow servers time to reboot and restart services before alerting resumes. Default is 120 (2 minutes). Set to 0 to skip the wait. |
| `-ConfigDir` | Directory containing configuration files (default: 'configs'). |
| `-Start` | Maintenance start datetime (UTC only). Supported formats: - 'now': Current UTC time (default for enable action) - Relative offset: '+Xhours', '+Xminutes', '+Xdays', '+Xseconds' Examples: '+1hour', '+30minutes', '+2days', '+3600seconds' - Absolute UTC: 'YYYY-MM-DD HH:MM' or 'YYYY-MM-DDTHH:MM:SS' Examples: '2026-06-11 22:00', '2026-06-11T22:00:00' IMPORTANT: All times are UTC. No local timezone conversion is performed. |
| `-End` | Maintenance end datetime (UTC only). Same formats as Start. Required for 'enable' action. Examples: '+2hours', '2026-06-12 02:00', '2026-06-12T02:00:00' |
| `-DryRun` | Simulate without making changes. Shows what would happen. |
| `-MockMaintenanceState` | Dry-run only: mock validate status as 'enable', 'disable', or 'partial'. Default is 'disable'. |
| `-NoSchedule` | Do not create a Windows Scheduled Task for automatic disable at end time. |
| `-Json` | Output as JSON for API/iRequest integration. |

<a name="examples"></a>
## Examples

<a name="example-1"></a>
### Example 1
```powershell
# Validate configuration without making changes Set-MaintenanceMode -Action validate -TargetId 'CLU-CLUSTER-01' -Mode scom
```

<a name="example-2"></a>
### Example 2
```powershell
# Enable maintenance in Test environment with relative time Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+2hours'
```

<a name="example-3"></a>
### Example 3
```powershell
# Enable maintenance in Prod environment with absolute UTC time Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'
```

<a name="example-4"></a>
### Example 4
```powershell
# Disable maintenance with custom stabilization wait Set-MaintenanceMode -Action disable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -PostDisableWaitSeconds 60
```

<a name="example-5"></a>
### Example 5
```powershell
# Use host override for emergency maintenance Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -ManagementHost 'backup-server.local' -Start 'now' -End '+4hours'
```

<a name="example-6"></a>
### Example 6
```powershell
# Dry run to test configuration Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+1hour' -DryRun
```

<a name="example-7"></a>
### Example 7
```powershell
# OneView single server maintenance Set-MaintenanceMode -Action enable -TargetId 'server01.ad.example.com' -Mode oneview -Environment Test -Start 'now' -End '+1hour'
```

<a name="example-8"></a>
### Example 8
```powershell
# OneView with serial number (Marin's preference) Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' -Environment Test -Start 'now' -End '+1hour'
```

<a name="example-9"></a>
### Example 9
```powershell
# SCOM single server (no CLU- prefix) Set-MaintenanceMode -Action enable -TargetId 'myserver01' -Mode scom -Environment Prod -Start 'now' -End '+2hours'
```

<a name="original-comment-based-help"></a>
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
        
        All datetime values are UTC only. Local time conversion is not performed.

    .PARAMETER Action
        'enable', 'disable', or 'validate'. Default is 'enable'.

    .PARAMETER TargetId
        Target identifier string (cluster ID or server name). Required.

    .PARAMETER Mode
        'scom' for SCOM-only or 'oneview' for HPE OpenView-only. 
        SCOM manages Windows cluster objects; OpenView manages hardware directly.
        Required.

    .PARAMETER Environment
        Environment selection: 'Test' or 'Prod'. 
        Determines which hosts to connect to from connection_hosts.json.
        If not specified, reads from $env:ENVIRONMENT environment variable.
        Defaults to 'Prod' if neither is set.

    .PARAMETER ManagementHost
        Optional override for management server/appliance hostname/IP.
        Takes precedence over environment config.
        For SCOM mode: overrides SCOM management server
        For OneView mode: overrides OneView appliance
        Can also be set via $env:MAINTENANCE_HOST

    .PARAMETER SerialNumber
        Optional serial number for OneView mode (Marin's preference).
        Only valid when -Mode is 'oneview'. Will reject if used with SCOM mode.
        When provided, the script will look up the server by serial number in OneView.

    .PARAMETER Username
        Optional direct username parameter (for testing only).
        Not recommended for production use - use environment variables instead.
        For SCOM: overrides $env:SCOM_ADMIN_USER
        For OneView: overrides $env:ONEVIEW_USER

    .PARAMETER PostDisableWaitSeconds
        Seconds to sleep after disabling SCOM maintenance mode to allow servers
        time to reboot and restart services before alerting resumes.
        Default is 120 (2 minutes). Set to 0 to skip the wait.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs').

    .PARAMETER Start
        Maintenance start datetime (UTC only). Supported formats:
        - 'now': Current UTC time (default for enable action)
        - Relative offset: '+Xhours', '+Xminutes', '+Xdays', '+Xseconds'
          Examples: '+1hour', '+30minutes', '+2days', '+3600seconds'
        - Absolute UTC: 'YYYY-MM-DD HH:MM' or 'YYYY-MM-DDTHH:MM:SS'
          Examples: '2026-06-11 22:00', '2026-06-11T22:00:00'
        
        IMPORTANT: All times are UTC. No local timezone conversion is performed.

    .PARAMETER End
        Maintenance end datetime (UTC only). Same formats as Start.
        Required for 'enable' action.
        Examples: '+2hours', '2026-06-12 02:00', '2026-06-12T02:00:00'

    .PARAMETER DryRun
        Simulate without making changes. Shows what would happen.

    .PARAMETER MockMaintenanceState
        Dry-run only: mock validate status as 'enable', 'disable', or 'partial'.
        Default is 'disable'.

    .PARAMETER NoSchedule
        Do not create a Windows Scheduled Task for automatic disable at end time.

    .PARAMETER Json
        Output as JSON for API/iRequest integration.

    .RETURNS
        [hashtable] with Success (bool), Message, StartTimeUtc, EndTimeUtc,
        TargetId, ClusterName, ServerCount, DryRun, AuditFile,
        FailedObjects, and mode-specific fields:
        - scom mode only: ScomObjects, ScomSummary
        - oneview mode only: OneViewObjects, OneViewSummary

    .EXAMPLE
        # Validate configuration without making changes
        Set-MaintenanceMode -Action validate -TargetId 'CLU-CLUSTER-01' -Mode scom

    .EXAMPLE
        # Enable maintenance in Test environment with relative time
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+2hours'

    .EXAMPLE
        # Enable maintenance in Prod environment with absolute UTC time
        Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'

    .EXAMPLE
        # Disable maintenance with custom stabilization wait
        Set-MaintenanceMode -Action disable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -PostDisableWaitSeconds 60

    .EXAMPLE
        # Use host override for emergency maintenance
        Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Environment Prod -ManagementHost 'backup-server.local' -Start 'now' -End '+4hours'

    .EXAMPLE
        # Dry run to test configuration
        Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom -Environment Test -Start 'now' -End '+1hour' -DryRun

    .EXAMPLE
        # OneView single server maintenance
        Set-MaintenanceMode -Action enable -TargetId 'server01.ad.example.com' -Mode oneview -Environment Test -Start 'now' -End '+1hour'

    .EXAMPLE
        # OneView with serial number (Marin's preference)
        Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber 'ABC123XYZ' -Environment Test -Start 'now' -End '+1hour'

    .EXAMPLE
        # SCOM single server (no CLU- prefix)
        Set-MaintenanceMode -Action enable -TargetId 'myserver01' -Mode scom -Environment Prod -Start 'now' -End '+2hours'

    .LINK
        https://github.com/yourorg/image-build-automation/docs/testing.md
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
