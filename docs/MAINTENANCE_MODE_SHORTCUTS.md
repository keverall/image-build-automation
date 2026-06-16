# Maintenance Mode Shortcuts

## Overview

The `mm` command provides a quick way to use maintenance mode with consistent, formatted output.

## Setup

The shortcuts are automatically available when you load your PowerShell profile:

```powershell
. $PROFILE
```

Or import the module directly:

```powershell
Import-Module ./src/powershell/Automation/Automation.psd1 -WarningAction SilentlyContinue
```

## Usage

### Basic Command

```powershell
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours -DryRun
```

### Parameters

All standard `Set-MaintenanceMode` parameters are supported:

- **-Action**: `enable`, `disable`, or `validate`
- **-TargetId**: Cluster or server identifier
- **-Mode**: `scom` or `oneview`
- **-Environment**: `Test` or `Prod`
- **-Start**: Start time (`now`, `+1hour`, `2026-06-12T14:00:00`)
- **-End**: End time (`+2hours`, `2026-06-12T16:00:00`)
- **-DryRun**: Simulate without making changes

## Output Format

The `mm` command provides consistent output for both success and error cases:

```
=== Maintenance Mode Command Audit ===
Timestamp (UTC): 2026-06-12T13:11:05.5793468Z
Action: enable
Target ID: CLU-CLUSTER-01
Mode: scom
Environment: Prod
Start Time (UTC): 2026-06-12T13:11:05.4885780Z
End Time (UTC): 2026-06-12T15:11:05.4886846Z

=== Command Result ===
Success: True
Server Count: 3
SCOM: 4/4 success
[DRY-RUN]
======================
```

### Key Features

- **Consistent fields** for both success and error cases
- **UTC ISO datetimes** for start and end times
- **Relative time conversion** (`now`, `+1hour` → actual UTC times)
- **Mode-specific summaries** (SCOM or OneView)
- **DRY-RUN indicator** when simulating

## Examples

### Enable Maintenance Mode (Dry Run)

```powershell
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours -DryRun
```

### Enable Maintenance Mode (Live)

```powershell
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours
```

### Validate Maintenance Mode

```powershell
mm -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

### Disable Maintenance Mode

```powershell
mm -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

## Time Formats

Supported time formats:

- `now` - Current UTC time
- `+Xhours` - Relative hours (e.g., `+1hour`, `+2hours`)
- `+Xminutes` - Relative minutes (e.g., `+30minutes`)
- `+Xdays` - Relative days (e.g., `+1day`)
- `YYYY-MM-DD HH:MM` - Absolute UTC time
- `YYYY-MM-DDTHH:MM:SS` - ISO 8601 UTC format

## Troubleshooting

### Command Not Found

If `mm` is not recognized, reload your profile:

```powershell
. $PROFILE
```

Or use the full command:

```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours
```

### Profile Errors

Check your profile for syntax errors:

```powershell
pwsh -NoProfile -Command "Test-Path \$PROFILE"
```

If there are issues, restore the default profile or remove the maintenance mode section and re-add it.
