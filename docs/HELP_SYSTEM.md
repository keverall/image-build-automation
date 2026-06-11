# Set-MaintenanceMode Help System

## Help Commands That Work

All of the following commands will display help:

```powershell
# Standard PowerShell help flags (all work now)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Help
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -h
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -?

# Using module import (recommended for full documentation)
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
Get-Help Set-MaintenanceMode -Full
Get-Help Set-MaintenanceMode -Parameter Environment
Get-Help Set-MaintenanceMode -Examples
```

## What Was Fixed

**Problem:** `-Help`, `-h`, and `--help` parameters were not recognized when using `pwsh -File`

**Solution:** Added `[Alias('h', 'help', '?')][switch] $ShowHelp` parameter that:
1. Catches all common help flag variations
2. Imports the module to access full function documentation
3. Displays comprehensive help with `Get-Help Set-MaintenanceMode -Full`
4. Exits cleanly after showing help

## Help Output Includes

✅ **Syntax** - Complete command syntax with all parameters  
✅ **Parameters** - Detailed description of each parameter  
✅ **Valid Values** - Shows allowed values like `Test|Prod` for Environment  
✅ **Examples** - 8 practical usage examples  
✅ **Common Parameters** - Standard PowerShell parameters  
✅ **Remarks** - Additional notes and considerations  

## Quick Examples from Help

```powershell
# Validate configuration
Set-MaintenanceMode -Action validate -TargetId 'PROD-CLUSTER-01' -Mode scom

# Enable in Test environment with relative time
Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom `
    -Environment Test -Start 'now' -End '+2hours'

# Enable in Prod with absolute UTC time
Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom `
    -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'

# Disable with custom wait
Set-MaintenanceMode -Action disable -TargetId 'PROD-CLUSTER-01' -Mode scom `
    -Environment Prod -PostDisableWaitSeconds 60

# Dry run test
Set-MaintenanceMode -Action enable -TargetId 'TEST-CLUSTER-01' -Mode scom `
    -Environment Test -Start 'now' -End '+1hour' -DryRun
```

## Key Information Shown in Help

### Required Parameters
- `-TargetId` - Cluster ID or server name
- `-Mode` - `scom` or `oneview`

### Optional Parameters
- `-Environment` - `Test` or `Prod` (defaults to Prod)
- `-ScomHost` - SCOM server override
- `-OneViewHost` - OneView appliance override
- `-Username` - Direct username (testing only)

### Date/Time Formats (UTC Only)
- `now` - Current UTC time
- `+Xhours` - Relative hours (e.g., `+2hours`)
- `+Xminutes` - Relative minutes (e.g., `+30minutes`)
- `+Xdays` - Relative days (e.g., `+1day`)
- `YYYY-MM-DD HH:MM` - Absolute UTC (e.g., `2026-06-12 02:00`)
- `YYYY-MM-DDTHH:MM:SS` - ISO 8601 UTC

### Important Notes
- **All times are UTC only** - No local timezone conversion
- **Environment defaults to Prod** if not specified
- **Credentials via environment variables** or interactive prompt
- **Use -DryRun first** to test without making changes

## More Information

- Full testing guide: `docs/maint-mode-initial-testing.md`
- Environment configuration: `docs/maintenance-mode-environment-config.md`
- Quick reference: `docs/SET-MAINTENANCEMODE-HELP.md`
