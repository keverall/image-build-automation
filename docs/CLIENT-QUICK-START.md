# Maintenance Mode - Quick Start Guide

<a id="top"></a>
## Table of Contents

- [Setup (One-Time)](#setup-one-time)
- [Usage](#usage)
  - [Full Control](#full-control)
  - [Time Formats](#time-formats)
- [Output](#output)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Test Before Running](#test-before-running)
  - [Production with Custom Window](#production-with-custom-window)
  - [OneView Server by Serial](#oneview-server-by-serial)
  - [Disable Maintenance](#disable-maintenance)
- [Troubleshooting](#troubleshooting)
  - [Command Not Found](#command-not-found)
  - [Check Available Commands](#check-available-commands)
<a name="setup-one-time"></a>
## Setup (One-Time)

Run this script once to configure your PowerShell profile with the Automation module:

```powershell
./scripts/Setup-Profile.ps1
```

Then restart PowerShell or reload your profile:

```powershell
. $PROFILE
```

<a name="usage"></a>
## Usage

<a name="full-control"></a>
### Full Control

```powershell
# Enable with all options
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +4hours -DryRun

# OneView with serial number
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test -DryRun

# Custom time window
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start '2026-06-12 22:00' -End '2026-06-13 02:00'
```

<a name="time-formats"></a>
### Time Formats

- `now` - Current time
- `+1hour`, `+2hours`, `+30minutes` - Relative times
- `2026-06-12 22:00` - Absolute UTC time
- `2026-06-12T22:00:00` - ISO 8601 format

<a name="output"></a>
## Output

The `Set-MaintenanceMode` command shows consistent, formatted output:

```
=== Maintenance Mode Command Audit ===
Timestamp (UTC): 2026-06-12T14:00:00.1234567Z
Action: enable
Target ID: CLU-CLUSTER-01
Mode: scom
Environment: Prod
Start Time (UTC): 2026-06-12T14:00:00.1234567Z
End Time (UTC): 2026-06-12T16:00:00.1234567Z

=== Command Result ===
Success: True
Server Count: 3
SCOM: 4/4 success
=====================
```

<a name="parameters"></a>
## Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Action` | Yes | `enable`, `disable`, or `validate` | - |
| `-TargetId` | Yes | Cluster/server ID | - |
| `-Mode` | Yes | `scom` or `oneview` | - |
| `-Environment` | No | `Test` or `Prod` | `Prod` |
| `-Start` | No | Maintenance window start time | `now` |
| `-End` | No | Maintenance window end time | `+2hours` |
| `-DryRun` | No | Simulate only | `false` |
| `-ManagementHost` | No | Override management server hostname | - |
| `-SerialNumber` | No | OneView: look up server by serial number | - |

<a name="examples"></a>
## Examples

<a name="test-before-running"></a>
### Test Before Running
```powershell
Set-MaintenanceMode -Action enable -TargetId TEST-CLUSTER-01 -Mode scom -Environment Prod -DryRun
```

<a name="production-with-custom-window"></a>
### Production with Custom Window
```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start '2026-06-12 22:00' -End '2026-06-13 02:00'
```

<a name="oneview-server-by-serial"></a>
### OneView Server by Serial
```powershell
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test -Start now -End +2hours
```

<a name="disable-maintenance"></a>
### Disable Maintenance
```powershell
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

<a name="troubleshooting"></a>
## Troubleshooting

<a name="command-not-found"></a>
### Command Not Found
```powershell
# Reload profile
. $PROFILE

# Or import module directly
Import-Module ./src/powershell/Automation/Automation.psd1
```

<a name="check-available-commands"></a>
### Check Available Commands
```powershell
Get-Command Set-MaintenanceMode
```
