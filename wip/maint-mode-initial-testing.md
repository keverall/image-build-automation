# Set-MaintenanceMode.ps1 Testing Commands

## Parameter Summary

The script supports both `-DryRun` and `-WhatIf` as equivalent parameters for simulation mode.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Action` | string | 'enable', 'disable', or 'validate' (default: enable) |
| `-ClusterId` | string | Cluster identifier (required) |
| `-ConfigDir` | string | Configuration directory (default: configs) |
| `-Start` | string | Start datetime: 'now' or 'YYYY-MM-DD HH:MM' |
| `-End` | string | End datetime: relative ('+1hour') or absolute |
| `-DryRun` | switch | Simulate without making changes |
| `-WhatIf` | switch | Alias for -DryRun |
| `-NoSchedule` | switch | Skip Windows Scheduled Task creation |
| `-Json` | switch | Output as JSON for API integration |

## Testing Commands

**1. Dry-run first (recommended) to validate config:**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour' -DryRun
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -DryRun
```

**2. Using WhatIf (alias for DryRun):**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour' -WhatIf
```

**3. For immediate enable/disable with specific end time:**

```powershell
# Enable with 1-hour window ending 1 hour from now
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour'

# Disable
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01'
```

**4. Using datetime format instead of relative:**

```powershell
# Enable with explicit end time (Dublin time zone assumed for production)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '2026-05-25 17:00' -ConfigDir './configs'
```

**5. Using the module import approach:**

```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Set-MaintenanceMode -Action enable -ClusterId 'STAGING-CLUSTER-01' -Start 'now' -End '+30min' -DryRun
```

**6. Validate cluster configuration:**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action validate -ClusterId 'PROD-CLUSTER-01'
```

## Notes

- The script operates on **clusters** defined in `clusters_catalogue.json`, not individual servers from `server_list.txt`.
- For "now" as the time parameter: `Start 'now'` works for start time; `End` must still be provided for enable action.
- Use `-DryRun` or `-WhatIf` first to validate configuration loading without making changes.
- JSON output mode (`-Json`) is available for iRequest/REST API integration.