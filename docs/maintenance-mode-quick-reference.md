# PowerShell Quick Reference - Maintenance Mode

## Module Import

The `Set-MaintenanceMode` function is available through the Automation module:

```powershell
Import-Module ./src/powershell/Automation/Automation.psd1 -WarningAction SilentlyContinue
```

## Quick Aliases (Available in Profile)

After adding the profile configuration, you can use these shortcuts:

### `mm` - Full maintenance mode command
```powershell
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours
```

### `mmenable` - Quick enable maintenance mode
```powershell
# Basic usage with defaults (scom, Prod, +2hours)
mmenable CLU-CLUSTER-01

# Specify mode and environment
mmenable CLU-CLUSTER-01 scom Prod

# Custom time window
mmenable CLU-CLUSTER-01 scom Prod -Start now -End +4hours

# Dry run
mmenable CLU-CLUSTER-01 scom Test -DryRun
```

### `mmdisable` - Quick disable maintenance mode
```powershell
# Basic usage with defaults
mmdisable CLU-CLUSTER-01

# Specify mode and environment
mmdisable CLU-CLUSTER-01 scom Prod
```

### `mmvalidate` - Quick validate maintenance mode
```powershell
# Basic usage with defaults
mmvalidate CLU-CLUSTER-01

# Specify mode and environment
mmvalidate CLU-CLUSTER-01 scom Prod
```

## Time Format Options

All time parameters support these formats:

- `now` - Current UTC time
- `+Xhours` - Relative hours (e.g., `+1hour`, `+2hours`)
- `+Xminutes` - Relative minutes (e.g., `+30minutes`)
- `+Xdays` - Relative days (e.g., `+1day`, `+7days`)
- `YYYY-MM-DD HH:MM` - Absolute UTC (e.g., `2026-06-11 22:00`)
- `YYYY-MM-DDTHH:MM:SS` - ISO 8601 UTC (e.g., `2026-06-11T22:00:00`)

## Examples

### Enable maintenance mode for a test cluster
```powershell
mmenable TEST-CLUSTER-01 scom Test -Start now -End +1hour -DryRun
```

### Enable maintenance mode for production with custom window
```powershell
mmenable CLU-CLUSTER-01 scom Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'
```

### Disable maintenance mode
```powershell
mmdisable CLU-CLUSTER-01 scom Prod
```

### Validate maintenance mode status
```powershell
mmvalidate CLU-CLUSTER-01 scom Prod
```

### Full control with mm
```powershell
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod `
   -Start now -End +2hours -DryRun
```

## Output

All commands display:
- Start Time (UTC) - ISO 8601 format
- End Time (UTC) - ISO 8601 format
- Success/Failure status
- Error messages (if any)
- Per-object status details (for successful operations)

## Setup

The aliases are automatically loaded when you start PowerShell if you've added the configuration to your profile at:
```
~/.config/powershell/Microsoft.PowerShell_profile.ps1
```

To reload the profile in an existing session:
```powershell
. ~/.config/powershell/Microsoft.PowerShell_profile.ps1
```
