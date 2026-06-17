# Set-MaintenanceMode Command Reference

> Complete guide for using `Set-MaintenanceMode` from the project root.

## Quick Start

### Setup (One-Time)
```powershell
# From project root
make setup

# Or run the profile setup script
pwsh -File scripts/Setup-Profile.ps1

# Reload your profile
. $PROFILE
```

### Getting Help
```powershell
# Quick syntax help
Set-MaintenanceMode -?

# Full parameter documentation
Get-Help Set-MaintenanceMode -Full

# Specific parameter help
Get-Help Set-MaintenanceMode -Parameter Environment
Get-Help Set-MaintenanceMode -Parameter Start
```

---

## Command Syntax
```powershell
Set-MaintenanceMode -Action <enable|disable|validate> -TargetId <cluster-id> -Mode <scom|oneview> [-Environment <Test|Prod>] [options]
```

- **Action**: `enable`, `disable`, or `validate`
- **TargetId**: Cluster ID or server name
- **Mode**: `scom` or `oneview`
- **Environment**: `Test` or `Prod` (optional, defaults to `Prod`)

---

## Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `-Action` | `enable`, `disable`, or `validate` |
| `-TargetId` | Cluster ID (e.g., `CLU-CLUSTER-01`) or server name |
| `-Mode` | `scom` or `oneview` |

### Optional

| Parameter | Description |
|-----------|-------------|
| `-Environment` | `Test` or `Prod` (default: `Prod`) |
| `-ManagementHost` | Override management server/appliance hostname |
| `-Start` | Maintenance window start time |
| `-End` | Maintenance window end time |
| `-PostDisableWaitSeconds` | Wait after SCOM disable (default: 120, 0 to skip) |
| `-DryRun` | Simulate without making changes |
| `-SerialNumber` | OneView mode: look up server by serial number |
| `-Username` | Direct username (testing only) |
| `-Json` | Output as JSON for API integration |

---

## Time Formats

**All times are UTC only.** No local timezone conversion.

| Format | Example | Description |
|--------|---------|-------------|
| `now` | `-Start now` | Current UTC time |
| `+Xhours` | `-End +2hours` | Relative hours/minutes/days/seconds |
| `+Xminutes` | `-End +30minutes` | Relative from now |
| `+Xdays` | `-End +1day` | Relative from now |
| `YYYY-MM-DD HH:MM` | `-End '2026-06-12 02:00'` | Absolute UTC |
| `YYYY-MM-DDTHH:MM:SS` | `-End '2026-06-12T02:00:00'` | ISO 8601 UTC |

---

## Credential Setup

### Method 1: Environment Variables (Recommended)

```powershell
$env:ENVIRONMENT = "Prod"
$env:SCOM_ADMIN_USER = "svc_maintenance_admin"
$env:SCOM_ADMIN_PASSWORD = "password"

# Or for OneView
$env:ONEVIEW_USER = "maintenance_admin"
$env:ONEVIEW_PASSWORD = "password"
```

### Method 2: PowerShell Profile

Add to your `$PROFILE`:
```powershell
$env:SCOM_ADMIN_USER = "svc_maintenance_admin"
$env:SCOM_ADMIN_PASSWORD = "password"
```

### Method 3: Interactive Prompt

```powershell
# Just run the command - you'll be prompted for credentials
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

---

## Basic Examples

```powershell
# Enable maintenance mode
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours

# Disable maintenance mode
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod

# Validate maintenance mode status
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom

# Dry run (test without making changes)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -DryRun
```

---

## Full Command Examples

### Example 1: Basic Enable with Defaults
```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours
```

### Example 2: Dry Run (Test First!)
```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +1hour -DryRun
```

### Example 3: Custom Time Window
```powershell
# Absolute times
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start '2026-06-11 22:00' -End '2026-06-12 02:00'

# Mixed: relative start, absolute end
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start 'now' -End '2026-06-12 02:00'
```

### Example 4: Disable with Custom Wait
```powershell
# Disable maintenance and wait 60 seconds for stabilization
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -PostDisableWaitSeconds 60
```

### Example 5: OneView Server Maintenance
```powershell
# By server name
Set-MaintenanceMode -Action enable -TargetId server01.ad.example.com -Mode oneview -Environment Prod -Start now -End +1hour

# By serial number
Set-MaintenanceMode -Action enable -Mode oneview -Environment Test -SerialNumber ABC123XYZ -Start now -End +1hour
```

### Example 6: Host Override
```powershell
# Emergency: use backup SCOM server
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -ManagementHost backup-scom.local -Start now -End +4hours
```

### Example 7: JSON Output
```powershell
# Get structured JSON output for automation/API integration
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours -Json
```

---

## Host Resolution Priority

Both SCOM and OneView use the same resolution order:

1. `-ManagementHost` parameter (highest priority)
2. `$env:MAINTENANCE_HOST` environment variable
3. `configs/connection_hosts.json` → Environment config
4. Error if not found

---

## Output Format

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
======================
```

---

## Config Files

| File | Purpose |
|------|---------|
| `configs/connection_hosts.json` | Environment-specific hosts (Test/Prod) |
| `configs/clusters_catalogue.json` | Cluster definitions and mappings |
| `configs/scom_config.json` | SCOM server configuration |
| `configs/oneview_config.json` | OneView appliance configuration |
| `.env` | Credential template (gitignored) |

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Management host not configured" | Set `$env:MAINTENANCE_HOST` or update `connection_hosts.json` |
| "Missing credentials: username" | Set env vars or run interactively |
| "Failed to connect to SCOM" | Check network, firewall, credentials |
| "Environment 'X' not found" | Use `Test` or `Prod` only |
| `Set-MaintenanceMode` command not found | Import module: `Import-Module ./src/powershell/Automation/Automation.psd1` or run `make setup` |
| Profile errors | Check `$PROFILE` syntax, re-run `Setup-Profile.ps1` |

---

## Security Notes

❌ **DON'T** hardcode passwords in scripts  
❌ **DON'T** commit `.env` files with real credentials  
✅ **DO** use CyberArk or environment variables  
✅ **DO** use `-DryRun` to test before applying changes

---


## Quick Commands

```powershell
# List available environments
(Import-JsonConfig configs/connection_hosts.json).environments.Keys

# Test connection before running maintenance
pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom -DryRun

# Load module if needed
Import-Module ./src/powershell/Automation/Automation.psm1
```

---
## Related Documentation

- **Architecture & Flow**: [docs/maintenance_mode.md](maintenance_mode.md)
- **Setup Guide**: [docs/SETUP-GUIDE.md](SETUP-GUIDE.md)
- **Testing Guide**: [docs/testing.md](testing.md)
- **Environment Config**: [docs/maintenance-mode-environment-config.md](maintenance-mode-environment-config.md)
- **PowerShell Function Reference**: [docs/dynamic-code-docs/INDEX.md](dynamic-code-docs/INDEX.md) - Complete coverage of ALL PowerShell functions and cmdlets.
