# to run the script can be run directly. 

However, there's an important distinction: the script operates on **clusters** defined in `clusters_catalogue.json`, not individual servers from `server_list.txt`. The `server_list.txt` contains individual server names for other purposes, but maintenance mode requires cluster-level configuration.

For testing with "now" as the time parameter:
- `Start 'now'` works for start time (line 263 in the script handles this)
- `End` must still be provided since the script requires an end time for "enable" action (line 119-120)

Here are the commands for testing:

**1. Dry-run first (recommended) to validate config:**

```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour' -DryRun
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01' -DryRun
```

**2. For immediate enable/disable with specific end time:**

```powershell
# Enable with 1-hour window ending 1 hour from now
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '+1hour'

# Disable
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action disable -ClusterId 'PROD-CLUSTER-01'
```

**3. Using datetime format instead of relative:**

```powershell
# Enable with explicit end time (Dublin time zone assumed for production)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '2026-05-25 17:00' -ConfigDir './configs'
```

**4. Using the module import approach:**

```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Set-MaintenanceMode -Action enable -ClusterId 'STAGING-CLUSTER-01' -Start 'now' -End '+30min' -DryRun
```

**Note:** The script requires the module dependencies. For standalone testing without full setup, use `-DryRun` first to validate configuration loading.