# Set-MaintenanceMode.ps1 Testing Commands

## Parameter Summary

The script supports both `-DryRun` and `-WhatIf` as equivalent parameters for simulation mode.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Action` | string | 'enable', 'disable', or 'validate' (default: enable) |
| `-ClusterId` | string | Cluster identifier (required) |
| `-Mode` | string | 'scom' for SCOM-only, 'all' for SCOM + OpenView (default: all) |
| `-PostDisableWaitSeconds` | int | Seconds to wait after SCOM disable for server stabilization (default: 120) |
| `-ConfigDir` | string | Configuration directory (default: configs) |
| `-Start` | string | Start datetime: 'now' or 'YYYY-MM-DD HH:MM' |
| `-End` | string | End datetime: relative ('+1hour') or absolute |
| `-DryRun` | switch | Simulate without making changes |
| `-WhatIf` | switch | Alias for -DryRun |
| `-NoSchedule` | switch | Skip Windows Scheduled Task creation |
| `-Json` | switch | Output as JSON for API integration |

## SCOM Group Mode Behavior

When maintenance mode is enabled or disabled for SCOM (via either `-Mode scom` or `-Mode all`), **ALL objects in the SCOM group** are affected — servers, network devices, cluster nodes, and the cluster server itself. This ensures complete alert suppression across the entire cluster.

After disabling SCOM maintenance mode, a configurable wait period (default 120 seconds) allows servers time to reboot, restart services, and stabilize before alerting resumes, preventing false alerts.

## Testing Commands

**1. Dry-run first (recommended) to validate config:**

```powershell
# All systems (SCOM + OpenView) - default mode
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour' -DryRun
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -DryRun

# SCOM-only mode
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode scom -Start 'now' -End '+1hour' -DryRun
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -Mode scom -DryRun
```

**2. Using WhatIf (alias for DryRun):**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode all -Start 'now' -End '+1hour' -WhatIf
```

**3. Enable/disable with mode parameter:**

```powershell
# SCOM + OpenView (explicit all mode)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode all -Start 'now' -End '+1hour'

# SCOM-only mode
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode scom -Start 'now' -End '+2hours'
```

**4. Disable with stabilization wait period:**

```powershell
# Disable with default 120-second wait (recommended)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -Mode all

# Disable with custom 60-second wait
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -Mode scom -PostDisableWaitSeconds 60

# Disable with no wait (immediate alerting resume — use with caution)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -PostDisableWaitSeconds 0
```

**5. Using datetime format instead of relative:**

```powershell
# Enable with explicit end time (Dublin time zone assumed for production)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '2026-05-25 17:00' -ConfigDir './configs'
```

**6. Using the module import approach:**

```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Set-MaintenanceMode -Action enable -ClusterId 'STAGING-CLUSTER-01' -Mode scom -Start 'now' -End '+30min' -DryRun
Set-MaintenanceMode -Action disable -ClusterId 'STAGING-CLUSTER-01' -Mode all -PostDisableWaitSeconds 60
```

**7. Validate cluster configuration:**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action validate -ClusterId 'PROD-CLUSTER-01'
```

## Notes

- The script operates on **clusters** defined in `clusters_catalogue.json`, not individual servers from `server_list.txt`.
- **SCOM group mode**: ALL objects in the SCOM group (servers, network devices, cluster nodes, cluster server) are put into maintenance mode — not just cluster nodes.
- For "now" as the time parameter: `Start 'now'` works for start time; `End` must still be provided for enable action.
- Use `-DryRun` or `-WhatIf` first to validate configuration loading without making changes.
- **Post-disable wait**: After SCOM maintenance is disabled, servers need time to reboot and stabilize. The default 120-second wait prevents false alerts that support staff frequently report. Set `-PostDisableWaitSeconds 0` to skip.
- JSON output mode (`-Json`) is available for iRequest/REST API integration.

## Per-Object Status Reporting

When maintenance mode is enabled or disabled, the response includes **detailed per-object status** for every server, network device, cluster node, and cluster server in the SCOM group. This allows the iRequest CMDB to be accurately updated with the maintenance state of each individual object.

### Response Object Structure

Both JSON output (`-Json`) and the return hashtable contain these fields for iRequest integration:

| Field | Type | Description |
|-------|------|-------------|
| `ScomObjects` | array | Array of all objects with their maintenance status |
| `ScomSummary` | object | Aggregated counts (total, success, already_in_maintenance, failed) |
| `FailedObjects` | array | Filtered list of only failed objects with NACK details |

### Per-Object Object Structure

Each entry in `ScomObjects` contains:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Object display name (e.g., `srv01.corp.local`) |
| `Type` | string | SCOM class type (e.g., `WindowsComputer`, `WindowsCluster`) |
| `Action` | string | `enable` or `disable` |
| `Status` | string | `success`, `already_in_maintenance`, `not_in_maintenance`, or `failed` |
| `Message` | string | Human-readable status message |
| `NackReason` | string or null | Failure reason (only present for failed objects) |
| `Resolution` | string or null | Suggested fix for failures (only present for failed objects) |

### Common NACK Reasons

| NackReason | Resolution |
|------------|------------|
| Permission denied | Verify SCOM operator role permissions |
| SCOM agent unreachable | Verify SCOM agent is running and network connectivity |
| Object not found in SCOM | Verify object is monitored by SCOM |
| Agent not found in SCOM | Verify agent is installed and registered with SCOM |
| SCOM operation failed | Check SCOM management server logs |

### CLI Output Example

When running from command line, per-object status is displayed as a table:

```
=== SCOM Per-Object Status ===
Total Objects: 15
Success: 12
Already in Maintenance: 2
Failed: 1

[OK] srv01.corp.local (WindowsComputer) - success
[SKIP] srv02.corp.local (WindowsComputer) - already_in_maintenance
[FAIL] net-switch-01.corp.local (NetworkDevice) - failed
  NACK Reason: SCOM agent unreachable
  Resolution: Verify SCOM agent is running and network connectivity
===============================

=== NACK Summary (Failed Objects) ===
Total Failed: 1
  - net-switch-01.corp.local: SCOM agent unreachable
    Fix: Verify SCOM agent is running and network connectivity
===================================
```

### JSON Output Example (iRequest Integration)

```json
{
  "Success": false,
  "ScomObjects": [
    {
      "Name": "srv01.corp.local",
      "Type": "WindowsComputer",
      "Action": "enable",
      "Status": "success",
      "Message": "Maintenance mode enabled"
    },
    {
      "Name": "net-switch-01.corp.local",
      "Type": "NetworkDevice",
      "Action": "enable",
      "Status": "failed",
      "Message": "Access denied",
      "NackReason": "Permission denied",
      "Resolution": "Verify SCOM operator role permissions"
    }
  ],
  "ScomSummary": {
    "Total": 15,
    "Success": 12,
    "AlreadyInMaintenance": 2,
    "Failed": 1
  },
  "FailedObjects": [
    {
      "Name": "net-switch-01.corp.local",
      "Type": "NetworkDevice",
      "Action": "enable",
      "Status": "failed",
      "NackReason": "Permission denied",
      "Resolution": "Verify SCOM operator role permissions"
    }
  ]
}
```

### Testing Per-Object Reporting

```powershell
# Dry-run to see response structure without making changes
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour' -DryRun -Json | ConvertFrom-Json | Select-Object ScomObjects, ScomSummary, FailedObjects

# Live run with JSON output for iRequest CMDB integration
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode scom -Start 'now' -End '+2hours' -Json

# Verify per-object status in module approach
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
$result = Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Mode all -Start 'now' -End '+1hour' -DryRun
$result.ScomObjects | Format-Table Name, Type, Status, NackReason
$result.FailedObjects | ForEach-Object { Write-Host "$($_.Name): $($_.NackReason) -> $($_.Resolution)" }
```