# Maintenance Mode Command Reference

<a id="top"></a>

## Table of Contents

- [Quick Start](#quick-start)
- [Two-Phase Test](#two-phase-test)
  - [Phase 1: Network Ping](#phase-1-network-ping)
  - [Phase 2: Authentication Connect](#phase-2-authentication-connect)
- [Parameters](#parameters)
- [Examples](#examples)
- [Exit Codes](#exit-codes)
- [Change Freeze Safety](#change-freeze-safety)
- [Troubleshooting](#troubleshooting)
- [Configuration Files](#configuration-files)
- [Quick Start](#quick-start-1)
- [Actions](#actions)
- [Target Identification](#target-identification)
- [Time Formats](#time-formats)
- [Parameters](#parameters-1)
- [Output Formats](#output-formats)
- [Host Resolution Priority](#host-resolution-priority)
- [Credential Configuration](#credential-configuration)
- [Dry Run Mode](#dry-run-mode)
- [Troubleshooting](#troubleshooting-1)
- [Best Practices](#best-practices)
- [Related](#related)

> Complete guide for maintenance mode commands. **Always test connectivity first** before running maintenance operations.
> Setup: run `make setup` (registers the Automation module) or `pwsh scripts/Setup-Profile.ps1` to add the module import to your PowerShell profile.

---

# 1. Test-ServerConnectivity - Test Connectivity First

> **ALWAYS test connectivity before running maintenance commands.** This read-only command verifies **OneView appliance** availability and is safe during change freezes. The OneView session persists in `$global:ConnectedSessions` after testing - use `Disconnect-OneView` when finished. For SCOM connectivity, use `Test-ScomMaintenanceConnectivity`.

<a name="quick-start"></a>

## Quick Start

```powershell
# Test OneView connectivity (explicit host)
Test-ServerConnectivity -ManagementHost 'oneview-test.ad.example.com'

# Resolve host from connection_hosts.json for an environment
Test-ServerConnectivity -Environment Test -JsonConfig
```

<a name="two-phase-test"></a>

## Two-Phase Test

<a name="phase-1-network-ping"></a>

### Phase 1: Network Ping

- **DNS Resolution**: Verifies hostname resolves correctly
- **TCP Port Probe**: Checks HTTPS connectivity (port 443 by default)

<a name="phase-2-authentication-connect"></a>

### Phase 2: Authentication Connect

- **Module Check**: Verifies the HPEOneView PowerShell module is installed
- **Authentication Test**: Full login via `Connect-OVMgmt`
- **Persistent Session**: the OneView session remains active in `$global:ConnectedSessions` for subsequent commands; close it explicitly with `Disconnect-OneView`

<a name="parameters"></a>

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-ManagementHost` | Optional* | OneView appliance hostname (required for live runs) |
| `-Environment` | Optional | `Test` or `Prod`; used with `-JsonConfig` to resolve the host |
| `-Credential` | Optional | `PSCredential` for the connection; prompted interactively if omitted |
| `-JsonConfig` | Switch | Resolve host from `configs/connection_hosts.json` |
| `-ConfigDir` | Optional | Config file directory (default: `configs`) |
| `-PingTimeoutMs` | Optional | TCP timeout in ms (default: 3000) |
| `-Port` | Optional | TCP port to probe (default: 443) |
| `-Json` | Switch | Output as JSON for automation |
| `-DryRun` | Switch | Test configuration without network calls |

\* Required for a live (non-`-DryRun`) test unless resolved via `-JsonConfig` or `$env:MAINTENANCE_HOST`.

<a name="examples"></a>

## Examples

```powershell
# Basic connectivity test
Test-ServerConnectivity -ManagementHost 'oneview.ad.example.com'

# JSON output for automation
Test-ServerConnectivity -ManagementHost 'oneview.ad.example.com' -Json | ConvertFrom-Json

# DryRun - verify configuration without network calls
Test-ServerConnectivity -Environment Test -JsonConfig -DryRun

# CLI wrapper (auto-loads .env and module)
pwsh scripts/test-connectivity.ps1 -Environment Test
```

<a name="exit-codes"></a>

## Exit Codes

- `0` - Available (DNS resolved + TCP open + Auth succeeded)
- `1` - Unavailable (any phase failed)

<a name="change-freeze-safety"></a>

## Change Freeze Safety

Read-only: no objects are modified and no maintenance windows are created. ✅ Safe to run during change freezes.

<a name="troubleshooting"></a>

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| DNS resolution failed | Invalid hostname or DNS issue | Check hostname spelling, verify DNS records |
| TCP connection failed | Firewall blocking or appliance down | Verify firewall rules (443), check appliance status |
| Credentials not configured | Missing environment variables | Set `$env:ONEVIEW_USER` / `$env:ONEVIEW_PASSWORD` or pass `-Credential` |
| Module not found | HPEOneView module not installed | Install the HPEOneView module (see `configs/oneview_config.json` `module_name`) |

<a name="configuration-files"></a>

## Configuration Files

```
configs/
├── connection_hosts.json    # Environment host mappings (environments → Test/Prod → scom/oneview)
├── scom_config.json         # SCOM server configuration
└── oneview_config.json      # OneView appliance configuration (appliance, module_name)
```

---

# 2. Set-MaintenanceMode - Maintenance Operations

> Only run AFTER verifying connectivity.

<a name="quick-start-1"></a>

## Quick Start

```powershell
# Enable maintenance mode
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours

# Disable maintenance mode
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod

# Validate maintenance mode status
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom

# Dry run (test without applying)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Start now -End +1hour -DryRun
```

<a name="actions"></a>

## Actions

| Action | Description |
|--------|-------------|
| `enable` | Place target into maintenance mode |
| `disable` | Remove target from maintenance mode (with stabilization wait) |
| `validate` | Check current maintenance mode status (read-only) |

<a name="target-identification"></a>

## Target Identification

```powershell
# By cluster ID or server name (SCOM or OneView)
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom ...
Set-MaintenanceMode -Action enable -TargetId server01 -Mode oneview ...

# By serial number (OneView only)
Set-MaintenanceMode -Action enable -SerialNumber MXQ1234567 -Mode oneview ...
```

<a name="time-formats"></a>

## Time Formats

```powershell
# Absolute UTC
-Start '2026-06-23 14:30'  # or '2026-06-23T14:30:00'

# Relative
-Start 'now' -End '+2hours'
-Start '+1hour' -End '+4hours'
```

**Note**: All times are UTC; no local timezone conversion is performed.

<a name="parameters-1"></a>

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Action` | Optional | `enable` (default), `disable`, or `validate` |
| `-TargetId` | Required** | Cluster ID (`CLU-` prefix) or server name |
| `-SerialNumber` | Optional** | Hardware serial (OneView only; rejected for SCOM) |
| `-Mode` | **Required** | `scom` or `oneview` |
| `-Environment` | Optional | `Test` or `Prod` (default: `$env:ENVIRONMENT`, then `Prod`) |
| `-ManagementHost` | Optional | Override management server/appliance |
| `-Start` / `-End` | Optional | Maintenance window (UTC); `-End` defaults from config for enable |
| `-PostDisableWaitSeconds` | Optional | Wait after SCOM disable (default: 120, 0 to skip) |
| `-Username` | Optional | Direct username (testing only) |
| `-ConfigDir` | Optional | Config directory (default: `configs`) |
| `-DryRun` | Switch | Simulate without applying changes |
| `-NoSchedule` | Switch | Skip Windows Task Scheduler auto-disable |
| `-Json` | Switch | JSON output (script-mode invocation) |

** Either `-TargetId` or `-SerialNumber` (OneView) is required.

<a name="output-formats"></a>

## Output Formats

Default output is human-readable (audit header, per-server maintenance status). Use `-Json` for structured output for API/iRequest integration.

<a name="host-resolution-priority"></a>

## Host Resolution Priority

1. `-ManagementHost` parameter (explicit override)
2. `$env:MAINTENANCE_HOST` environment variable
3. `configs/connection_hosts.json` (`environments` → `Test`/`Prod` → `scom.management_server` or `oneview.appliance`)

<a name="credential-configuration"></a>

## Credential Configuration

```powershell
# Environment variables (recommended)
$env:SCOM_ADMIN_USER = 'svc_maintenance_admin'
$env:SCOM_ADMIN_PASSWORD = '...'
$env:ONEVIEW_USER = 'maintenance_admin'
$env:ONEVIEW_PASSWORD = '...'

# Or interactive prompt if credentials are not set (non-automated mode)
```

<a name="dry-run-mode"></a>

## Dry Run Mode

```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours -DryRun
```

`-DryRun` verifies target/host/config resolution using mock data without connecting or changing anything.

<a name="troubleshooting-1"></a>

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| Credentials not configured | Missing env vars | Set `$env:SCOM_ADMIN_USER`/PASSWORD or `$env:ONEVIEW_USER`/PASSWORD |
| Host not configured | No host in config | Set `$env:MAINTENANCE_HOST` or update `connection_hosts.json` |
| Connection failed | Network/auth issue | Run `Test-ServerConnectivity` (OneView) or `Test-ScomMaintenanceConnectivity` (SCOM) first |
| Target not found in catalogue | Invalid TargetId | Check `clusters_catalogue.json` / `servers_catalogue.oneview.json` |

<a name="best-practices"></a>

## Best Practices

1. **Test connectivity first**: `Test-ServerConnectivity` / `Test-ScomMaintenanceConnectivity`
2. **Disconnect OneView when finished**: `Disconnect-OneView` closes the persistent session
3. **Start with `-DryRun`** to verify configuration
4. **Validate before and after**: `-Action validate` confirms actual state
5. **Set reasonable time windows**; don't leave maintenance mode indefinitely

<a name="related"></a>

## Related

- [Code Map](Code_Map_Maitenance_Mode.md#top) - Full implementation details
- [Architecture](maintenance_mode.md#top) - System design and workflows
- [Environment configuration](maintenance-mode-environment-config.md#top)
