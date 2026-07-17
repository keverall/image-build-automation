# Maintenance Mode Command Reference

## Table of Contents

- [Why Test First?](#why-test-first)
- [Quick Start](#quick-start)
- [Two-Phase Test](#two-phase-test)
  - [Phase 1: Network Ping](#phase-1-network-ping)
  - [Phase 2: Authentication Connect](#phase-2-authentication-connect)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Basic Connectivity Tests](#basic-connectivity-tests)
  - [Override Management Host](#override-management-host)
  - [CLI Wrapper](#cli-wrapper)
  - [DryRun Mode](#dryrun-mode)
- [Expected Output](#expected-output)
  - [Successful Test](#successful-test)
  - [Failed Test](#failed-test)
- [Exit Codes](#exit-codes)
- [Change Freeze Safety](#change-freeze-safety)
- [Troubleshooting](#troubleshooting)
- [Configuration Files](#configuration-files)
- [Related](#related)
- [Quick Start](#quick-start-1)
- [Commands](#commands)
  - [Enable Maintenance Mode](#enable-maintenance-mode)
  - [Disable Maintenance Mode](#disable-maintenance-mode)
  - [Validate Maintenance Status](#validate-maintenance-status)
- [Actions](#actions)
- [Target Identification](#target-identification)
  - [By ID (SCOM/OneView)](#by-id-scomoneview)
  - [By Serial Number (OneView Only)](#by-serial-number-oneview-only)
- [Environment Configuration](#environment-configuration)
- [Time Formats](#time-formats)
- [Parameters](#parameters-1)
- [Exit Codes](#exit-codes-1)
- [Output Formats](#output-formats)
  - [Human-Readable (Default)](#human-readable-default)
  - [JSON Output](#json-output)
- [Host Resolution Priority](#host-resolution-priority)
- [Credential Configuration](#credential-configuration)
- [Dry Run Mode](#dry-run-mode)
- [Troubleshooting](#troubleshooting-1)
- [Best Practices](#best-practices)
- [Related](#related-1)


<a id="top"></a>
> Complete guide for maintenance mode commands. **Always test connectivity first** before running maintenance operations.

<a name="table-of-contents"></a>
1. [Test-ServerConnectivity - Test Connectivity First](#1-test-serverconnectivity---test-connectivity-first)
2. [Set-MaintenanceMode - Maintenance Operations](#2-set-maintenancemode---maintenance-operations)

---

# 1. Test-ServerConnectivity - Test Connectivity First

> **ALWAYS test connectivity before running maintenance commands.** This read-only command verifies SCOM/OneView availability and is safe during change freezes.

<a name="why-test-first"></a>
## Why Test First?

Before enabling/disabling maintenance mode, verify:
- ✅ Network connectivity to management servers
- ✅ DNS resolution working
- ✅ Authentication credentials valid
- ✅ PowerShell modules installed

**Safe during change freezes** - no objects are modified, read-only operations only.

<a name="quick-start"></a>
## Quick Start

```powershell
# Test SCOM connectivity (Test environment)
Test-ServerConnectivity -Mode scom -Environment Test

# Test OneView connectivity (Prod environment)
Test-ServerConnectivity -Mode oneview -Environment Prod

# Test both platforms
Test-ServerConnectivity -Mode scom -Environment Prod
Test-ServerConnectivity -Mode oneview -Environment Prod
```

<a name="two-phase-test"></a>
## Two-Phase Test

<a name="phase-1-network-ping"></a>
### Phase 1: Network Ping

- **DNS Resolution**: Verifies hostname resolves correctly
- **TCP Port Probe**: Checks connectivity to required ports
  - SCOM: 5985/5986 (WinRM) or 5985/135
  - OneView: 443 (HTTPS)

<a name="phase-2-authentication-connect"></a>
### Phase 2: Authentication Connect

- **Module Check**: Verifies PowerShell module is installed
- **Authentication Test**: Full login with credentials
- **Immediate Disconnect**: Cleans up session after test

<a name="parameters"></a>
## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Mode` | **Required** | `scom` or `oneview` |
| `-Environment` | Optional | `Test` or `Prod` (default: `Prod`) |
| `-ManagementHost` | Optional | Override server/appliance hostname |
| `-ConfigDir` | Optional | Config file directory (default: `configs`) |
| `-PingTimeoutMs` | Optional | TCP timeout in ms (default: 3000) |
| `-Json` | Switch | Output as JSON for automation |
| `-DryRun` | Switch | Test configuration without network calls |

<a name="examples"></a>
## Examples

<a name="basic-connectivity-tests"></a>
### Basic Connectivity Tests

```powershell
# Test SCOM Test environment
Test-ServerConnectivity -Mode scom -Environment Test

# Test OneView Prod
Test-ServerConnectivity -Mode oneview -Environment Prod

# JSON output for automation
Test-ServerConnectivity -Mode scom -Environment Prod -Json | ConvertFrom-Json
```

<a name="override-management-host"></a>
### Override Management Host

```powershell
# Test specific server (bypasses config files)
Test-ServerConnectivity -Mode scom -ManagementHost 'scom-test.ad.example.com'
```

<a name="cli-wrapper"></a>
### CLI Wrapper

```powershell
# Auto-loads .env and module (convenient for manual testing)
pwsh scripts/test-connectivity.ps1 -Environment Test -Mode scom
```

<a name="dryrun-mode"></a>
### DryRun Mode

```powershell
# Test configuration without making network calls
Test-ServerConnectivity -Mode scom -Environment Test -DryRun

# DryRun with JSON output for automation
Test-ServerConnectivity -Mode oneview -Environment Prod -DryRun -Json

# CLI wrapper with DryRun
pwsh scripts/test-connectivity.ps1 -Environment Test -Mode scom -DryRun
```

**DryRun Output Example:**
```
==============================================
  Server Connectivity Test
==============================================

  Status:     AVAILABLE [DRY-RUN]
  Mode:       scom
  Host:       VR-OPM19T1-7382.ad.example.com
  Environment:Test
  Timestamp:  2026-06-23T12:21:10.9471327Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.254.254.254
    TCP:       Open (port 5985, 1ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: Yes
    Clean up:  Disconnected

  --- Dry-Run Configuration Summary ---
    Module:       OperationsManager
    Target ports: 5985, 5986
    WinRM:        True
    Cred user:    SCOM_ADMIN_USER
    Cred pass:    SCOM_ADMIN_PASSWORD
    Note:         Mock data - no actual connectivity test performed

==============================================
```

<a name="expected-output"></a>
## Expected Output

<a name="successful-test"></a>
### Successful Test

```
==============================================
  Server Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       scom
  Host:       VR-OPM19T1-7382.ad.example.com
  Environment:Test
  Timestamp:  2026-06-23T12:41:05

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.1.2.3
    TCP:       Open (port 5985, 12ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: Yes
    Clean up:  Disconnected

==============================================
```

<a name="failed-test"></a>
### Failed Test

```
==============================================
  Server Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       oneview-test.ad.example.com
  Environment:Test
  Timestamp:  2026-06-23T12:42:15

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    Error:     DNS resolution failed for 'oneview-test.ad.example.com': 
               The name does not exist

  --- Phase 2: Auth Connect ---
    Error:     Skipped - network ping failed

==============================================
```

<a name="exit-codes"></a>
## Exit Codes

- `0` - Available (DNS resolved + TCP open + Auth succeeded)
- `1` - Unavailable (any phase failed)

<a name="change-freeze-safety"></a>
## Change Freeze Safety

| Aspect | Status |
|--------|--------|
| Objects Modified | None |
| Maintenance Windows Created | None |
| Credentials Used | Read-only authentication only |
| Exit Code | 0 = Available, 1 = Unavailable |
| Duration | Immediate disconnect after auth |

**Verdict**: ✅ Safe to run during change freezes.

<a name="troubleshooting"></a>
## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| DNS resolution failed | Invalid hostname or DNS issue | Check hostname spelling, verify DNS records |
| TCP connection failed | Firewall blocking or server down | Verify firewall rules (5985/5986/443), check server status |
| Credentials not configured | Missing environment variables | Set `$env:SCOM_ADMIN_USER`/`$env:SCOM_ADMIN_PASSWORD` or `$env:ONEVIEW_USER`/`$env:ONEVIEW_PASSWORD` |
| Module not found | PowerShell module not installed | Install OperationsManager or HPEOneView version module |
| Module: Not loaded | Module import failed | Check module installation, verify version compatibility |

<a name="configuration-files"></a>
## Configuration Files

```
configs/
├── connection_hosts.json    # Environment host mappings
├── scom_config.json         # SCOM server configuration
└── oneview_config.json      # OneView appliance configuration
```

<a name="related"></a>
## Related

- [Set-MaintenanceMode](#2-set-maintenancemode---maintenance-operations) - Run maintenance after connectivity is verified
- [Code Map](Code_Map_Maitenance_Mode.md#15-test-serverconnectivity--read-only-connectivity-check) - Full implementation reference

---

# 2. Set-MaintenanceMode - Maintenance Operations

> Only run AFTER verifying connectivity with Test-ServerConnectivity.

<a name="quick-start-1"></a>
## Quick Start

```powershell
# Enable maintenance mode
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours

# Disable maintenance mode
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod

# Validate maintenance mode status
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom
```

<a name="commands"></a>
## Commands

<a name="enable-maintenance-mode"></a>
### Enable Maintenance Mode

```powershell
# Basic (default Prod environment)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Start now -End +2hours

# Specify environment
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours

# Dry run (test without applying)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Start now -End +1hour -DryRun
```

<a name="disable-maintenance-mode"></a>
### Disable Maintenance Mode

```powershell
# Disable with default stabilization wait (120 seconds)
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod

# Custom stabilization wait
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -PostDisableWaitSeconds 60
```

<a name="validate-maintenance-status"></a>
### Validate Maintenance Status

```powershell
# Check current maintenance mode status
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

<a name="actions"></a>
## Actions

| Action | Description |
|--------|-------------|
| `enable` | Place object into maintenance mode |
| `disable` | Remove object from maintenance mode |
| `validate` | Check current maintenance mode status |

<a name="target-identification"></a>
## Target Identification

<a name="by-id-scomoneview"></a>
### By ID (SCOM/OneView)

```powershell
# SCOM server or cluster ID
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom ...

# OneView server ID
Set-MaintenanceMode -Action enable -TargetId server01 -Mode oneview ...
```

<a name="by-serial-number-oneview-only"></a>
### By Serial Number (OneView Only)

```powershell
# Look up OneView server by serial number
Set-MaintenanceMode -Action enable -SerialNumber MXQ1234567 -Mode oneview ...
```

<a name="environment-configuration"></a>
## Environment Configuration

The environment determines which servers to use (from `configs/connection_hosts.json`):

```powershell
# Test environment (test servers)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Test ...

# Prod environment (production servers)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod ...
```

<a name="time-formats"></a>
## Time Formats

```powershell
# Absolute time
-Start '2026-06-23T14:30:00'

# Relative time
-Start 'now' -End '+2hours'
-Start '+1hour' -End '+4hours'
```

**Note**: All times are in UTC.

<a name="parameters-1"></a>
## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Action` | **Required** | `enable`, `disable`, or `validate` |
| `-TargetId` | Optional** | Server or cluster ID |
| `-SerialNumber` | Optional** | Hardware serial (OneView only) |
| `-Mode` | **Required** | `scom` or `oneview` |
| `-Environment` | Optional | `Test` or `Prod` (default: `Prod`) |
| `-Start` | Optional | Maintenance start time |
| `-End` | Optional | Maintenance end time |
| `-DryRun` | Switch | Test without applying changes |
| `-ManagementHost` | Optional | Override server hostname |
| `-PostDisableWaitSeconds` | Optional | Wait after disable (default: 120) |
| `-Json` | Switch | Output as JSON |

**Either `-TargetId` or `-SerialNumber` is required.

<a name="exit-codes-1"></a>
## Exit Codes

- `0` - Success
- `1` - Failure

<a name="output-formats"></a>
## Output Formats

<a name="human-readable-default"></a>
### Human-Readable (Default)

```
=== Maintenance Mode Command Audit ===
Timestamp (UTC): 2026-06-23T13:11:05.5793468Z
Action: enable
Target ID: CLU-CLUSTER-01
Mode: scom
Environment: Prod
Start Time (UTC): 2026-06-23T13:11:05.4885780Z
End Time (UTC): 2026-06-23T15:11:05.4886846Z

=== Command Result ===
Success: True
Server Count: 3
SCOM: 3/3 success
Maintenance:
  server01: InMaintenanceMode=True
  server02: InMaintenanceMode=True
  server03: InMaintenanceMode=True
========================================
```

<a name="json-output"></a>
### JSON Output

```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Json
```

Returns structured JSON for automation:

```json
{
  "success": true,
  "action": "enable",
  "target_id": "CLU-CLUSTER-01",
  "mode": "scom",
  "environment": "Prod",
  "server_count": 3,
  "servers": [...]
}
```

<a name="host-resolution-priority"></a>
## Host Resolution Priority

Determines which management server to use:

1. `-ManagementHost` parameter (explicit override)
2. `$env:MAINTENANCE_HOST` environment variable
3. `connection_hosts.json` (environment-based)

```powershell
# Override specific server
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -ManagementHost 'scom-backup.ad.example.com' ...
```

<a name="credential-configuration"></a>
## Credential Configuration

```powershell
# Option 1: Environment variables (recommended)
$env:SCOM_ADMIN_USER = 'svc_maintenance_admin'
$env:SCOM_ADMIN_PASSWORD = '...'

$env:ONEVIEW_USER = 'maintenance_admin'
$env:ONEVIEW_PASSWORD = '...'

# Option 2: CyberArk
# Automatically resolves credentials for SCOM_ADMIN and ONEVIEW accounts

# Option 3: Interactive prompt
# If no credentials found, prompts for username/password
```

<a name="dry-run-mode"></a>
## Dry Run Mode

Test configuration without applying changes:

```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours -DryRun
```

**Use `-DryRun` to**:
- Verify connectivity to all servers
- Test credential resolution
- Check environment-specific host resolution

<a name="troubleshooting-1"></a>
## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| Credentials not configured | Missing env vars | Set `$env:SCOM_ADMIN_USER`/PASSWORD or `$env:ONEVIEW_USER`/PASSWORD |
| Host not configured | No host in config | Set `$env:MAINTENANCE_HOST` or update `connection_hosts.json` |
| Connection failed | Network/auth issue | Run `Test-ServerConnectivity` first |
| Cluster not found | Invalid TargetId | Check cluster ID in `clusters_catalogue.json` |
| Server not found | Invalid TargetId | Check server ID in `servers_catalogue.json` |

<a name="best-practices"></a>
## Best Practices

1. **Always test connectivity first**: Use `Test-ServerConnectivity` before running maintenance
2. **Start with DryRun**: Verify configuration with `-DryRun` before applying
3. **Use appropriate environment**: `Test` for development, `Prod` for production
4. **Set reasonable time windows**: Don't leave maintenance mode indefinitely
5. **Validate before and after**: Ensure objects are actually in maintenance mode
6. **Document your actions**: Maintain audit logs of all maintenance operations

<a name="related-1"></a>
## Related

- [Test-ServerConnectivity](#1-test-serverconnectivity---test-connectivity-first) - Test connectivity before maintenance
- [Code Map](Code_Map_Maitenance_Mode.md#top) - Full implementation details
- [Architecture](maintenance_mode.md#top) - System design and workflows

