# Set-MaintenanceMode Help Reference

## Getting Help

### Quick Help (Syntax Only)
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -?
```

### Full Help with All Parameters
```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Get-Help Set-MaintenanceMode -Full
```

### Help for Specific Parameter
```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Get-Help Set-MaintenanceMode -Parameter Environment
Get-Help Set-MaintenanceMode -Parameter Start
Get-Help Set-MaintenanceMode -Parameter Mode
```

### Examples Only
```powershell
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Get-Help Set-MaintenanceMode -Examples
```

## Required Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `-TargetId` | string | Cluster ID or server name |
| `-Mode` | `scom`, `oneview` | Which system to manage |

## Optional Parameters

### Environment Selection
```powershell
-Environment Test    # Use test environment hosts
-Environment Prod    # Use production environment hosts
                     # If omitted, uses $env:ENVIRONMENT or defaults to Prod
```

### Host Overrides
```powershell
-ManagementHost <hostname>   # Override management server/appliance (SCOM or OneView)
```

### Credentials (Testing Only)
```powershell
-Username <username>  # Direct username (not recommended for production)
                      # Password must be in env var or will prompt interactively
```

### Date/Time Parameters (UTC ONLY)

All datetime values are **UTC only**. No local timezone conversion is performed.

**Supported Formats:**

| Format | Example | Description |
|--------|---------|-------------|
| `now` | `-Start 'now'` | Current UTC time |
| `+Xhours` | `-End '+2hours'` | Relative hours from now |
| `+Xminutes` | `-End '+30minutes'` | Relative minutes from now |
| `+Xdays` | `-End '+1day'` | Relative days from now |
| `+Xseconds` | `-End '+3600seconds'` | Relative seconds from now |
| `YYYY-MM-DD HH:MM` | `-End '2026-06-12 02:00'` | Absolute UTC datetime |
| `YYYY-MM-DDTHH:MM:SS` | `-End '2026-06-12T02:00:00'` | ISO 8601 UTC format |

**Examples:**
```powershell
# Relative time
-Start 'now' -End '+2hours'
-Start 'now' -End '+90minutes'
-Start 'now' -End '+1day'

# Absolute UTC time
-Start '2026-06-11 22:00' -End '2026-06-12 02:00'
-Start '2026-06-11T22:00:00' -End '2026-06-12T02:00:00'

# Mixed
-Start 'now' -End '2026-06-12 02:00'
```

### Action Parameter
```powershell
-Action enable     # Enable maintenance mode (default)
-Action disable    # Disable maintenance mode
-Action validate   # Validate configuration without making changes
```

### Other Parameters
```powershell
-PostDisableWaitSeconds <int>  # Wait after SCOM disable (default: 120, set 0 to skip)
-ConfigDir <path>              # Config directory (default: 'configs')
-DryRun                        # Simulate without making changes
-NoSchedule                    # Skip Windows Task Scheduler creation
-Json                          # Output as JSON for API integration
```

## Complete Usage Examples

### Example 1: Validate Configuration
```powershell
Set-MaintenanceMode `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod
```

### Example 2: Enable Maintenance (Test Environment)
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+2hours'
```

### Example 3: Enable Maintenance (Prod with Absolute UTC Time)
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00'
```

### Example 4: Disable Maintenance with Custom Wait
```powershell
Set-MaintenanceMode `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -PostDisableWaitSeconds 60
```

### Example 5: Dry Run (Test Without Changes)
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+1hour' `
    -DryRun
```

### Example 6: Host Override (Emergency)
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ManagementHost 'backup-scom.local' `
    -Start 'now' `
    -End '+4hours'
```

### Example 7: OneView Single Server
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'server01.ad.aib.pri' `
    -Mode oneview `
    -Environment Test `
    -Start 'now' `
    -End '+1hour'
```

### Example 8: JSON Output for Automation
```powershell
$result = Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -Json | ConvertFrom-Json

if ($result.Success) {
    Write-Host "Maintenance enabled successfully"
} else {
    Write-Error "Failed: $($result.Error)"
}
```

## Credential Setup

### Method 1: Environment Variables (Recommended)
```powershell
$env:SCOM_ADMIN_USER = "domain\admin"
$env:SCOM_ADMIN_PASSWORD = "password"
$env:ONEVIEW_USER = "admin"
$env:ONEVIEW_PASSWORD = "password"
```

### Method 2: Interactive Prompt
If credentials are not set in environment variables and you run the script interactively, it will prompt you:
```
Enter SCOM username: domain\admin
Enter SCOM password: ******** (masked input)
```

### Method 3: .env File
Copy `.env` template and fill in your credentials, then load it:
```powershell
. ./.env
```

## Common Errors

| Error | Solution |
|-------|----------|
| "A parameter cannot be found that matches parameter name 'Help'" | Use `-?` instead of `-Help` |
| "SCOM host not configured" | Set `-Environment` or `$env:ENVIRONMENT` |
| "Missing credentials: username" | Set env vars or run interactively |
| "End time must be after start time" | Ensure end time is after start time |
| "Invalid datetime format" | Use supported formats listed above |

## Quick Reference Card

```
SYNTAX:
Set-MaintenanceMode [-Action] <enable|disable|validate> 
                    -TargetId <string> 
                    -Mode <scom|oneview> 
                    [-Environment <Test|Prod>] 
                    [-ManagementHost <string>] 
                    [-Username <string>] 
                    [-Start <datetime>] 
                    [-End <datetime>] 
                    [-PostDisableWaitSeconds <int>] 
                    [-DryRun] [-NoSchedule] [-Json]

DATETIME FORMATS:
  now                 - Current UTC time
  +Xhours/minutes/days/seconds - Relative time
  YYYY-MM-DD HH:MM    - Absolute UTC time
  YYYY-MM-DDTHH:MM:SS - ISO 8601 UTC

ENVIRONMENT VALUES:
  Test - Use test environment hosts
  Prod - Use production environment hosts (default)
```

## More Information

- Full testing guide: `docs/maint-mode-initial-testing.md`
- Environment config: `docs/maintenance-mode-environment-config.md`
- Quick start: `docs/TESTING_QUICK_START.md`
- Implementation summary: `IMPLEMENTATION_SUMMARY.md`
