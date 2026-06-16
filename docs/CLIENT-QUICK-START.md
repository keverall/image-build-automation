# Maintenance Mode - Quick Start Guide

## Setup (One-Time)

Run this script once to add the `mm` command to your PowerShell profile:

```powershell
./scripts/Setup-MaintenanceModeAliases.ps1
```

Then restart PowerShell or reload your profile:

```powershell
. $PROFILE
```

## Usage

### Full Control

```powershell
# Enable with all options
mm enable CLU-CLUSTER-01 -mode scom -env Prod -Start now -End +4hours -DryRun

# OneView with serial number
mm enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test -DryRun

# Custom time window
mm enable CLU-CLUSTER-01 scom Prod -Start '2026-06-12 22:00' -End '2026-06-13 02:00'
```

### Time Formats

- `now` - Current time
- `+1hour`, `+2hours`, `+30minutes` - Relative times
- `2026-06-12 22:00` - Absolute UTC time
- `2026-06-12T22:00:00` - ISO 8601 format

## Output

The `mm` command shows consistent, formatted output:

```
=== Maintenance Mode ===
Action: enable | Target: CLU-CLUSTER-01 | Mode: scom
Environment: Prod | Time: 2026-06-12T13:00:00Z → 2026-06-12T15:00:00Z
Status: ✓ Success
[DRY RUN MODE]
========================
```

## Parameters

| Parameter | Position | Description | Default |
|-----------|----------|-------------|---------|
| Action | 0 | `enable`, `disable`, `validate` | `enable` |
| Target | 1 | Cluster/server ID | Required |
| Mode | 2 | `scom` or `oneview` | `scom` |
| Environment | 3 | `Test` or `Prod` | `Prod` |
| Start | - | Start time | `now` |
| End | - | End time | `+2hours` |
| DryRun | - | Simulate only | `false` |

## Examples

### Test Before Running
```powershell
mm enable TEST-CLUSTER-01 -DryRun
```

### Production with Custom Window
```powershell
mm enable CLU-CLUSTER-01 -mode scom -env Prod -Start '2026-06-12 22:00' -End '2026-06-13 02:00'
```

### OneView Server by Serial
```powershell
mm enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
```

### Quick Disable
```powershell
mm disable CLU-CLUSTER-01
```

## Troubleshooting

### Command Not Found
```powershell
# Reload profile
. $PROFILE

# Or import module directly
Import-Module ./src/powershell/Automation/Automation.psd1
```

### Check Available Commands
```powershell
Get-Command mm*
```
