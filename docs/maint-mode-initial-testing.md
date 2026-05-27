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