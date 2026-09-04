# Maintenance Mode Orchestration

<a id="top"></a>

## Table of Contents

- [Two distinct maintenance modes: SCOM vs HPE OneView](#two-distinct-maintenance-modes-scom-vs-hpe-oneview)
- [Automatic maintenance mode in the build pipeline](#automatic-maintenance-mode-in-the-build-pipeline)
- [Flow](#flow)
- [Architecture](#architecture)
- [High-Level Flow](#high-level-flow)
- [Functionality](#functionality)
  - [Scheduled Automatic Disable](#scheduled-automatic-disable)
  - [Audit Logging](#audit-logging)
  - [OpsRamp Integration](#opsramp-integration)
  - [Environment Variables](#environment-variables)
  - [Configuration Files](#configuration-files)
  - [Error Handling](#error-handling)
  - [Timezone and Scheduling](#timezone-and-scheduling)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Future Enhancements](#future-enhancements)
- [Testing](#testing)
  - [Maintenance Mode Test Runner](#maintenance-mode-test-runner)
- [Change History](#change-history)

Maintenance mode silences monitoring alerts during change windows. There are **two completely independent systems** with different scopes, and they do **not** affect each other (enabling one never enables the other):

- **SCOM** (System Center Operations Manager) — maintenance mode on software/cluster **monitoring objects** (groups, clusters, Windows servers). Suppresses OS/application/cluster alerts.
- **HPE OneView** — maintenance mode on the **physical server-hardware** resource, via the HPEOneView PowerShell module. Suppresses hardware/firmware-compliance alerts and is what the automated build pipeline toggles.

Features include audit logging, OpsRamp telemetry, email notifications, and automatic disable via OS task scheduling.

> **The physical server build pipeline automatically enables HPE OneView maintenance mode** (and removes it afterwards) whenever it mounts an ISO or applies firmware. See [Automatic maintenance mode in the build pipeline](#automatic-maintenance-mode-in-the-build-pipeline). SCOM maintenance mode is **not** touched by the build — it is managed separately.

---

<a id="two-distinct-maintenance-modes-scom-vs-hpe-oneview"></a>

## Two distinct maintenance modes: SCOM vs HPE OneView

These are very different and must not be conflated. They target different layers and are enabled through different tools.

| Aspect | SCOM maintenance mode | HPE OneView maintenance mode |
|--------|----------------------|------------------------------|
| What it acts on | SCOM **monitoring objects** — groups, clusters, and Windows servers | The **server-hardware** resource in OneView (the physical box) |
| What gets silenced | OS / application / cluster alerts raised by SCOM | Hardware, iLO, and firmware-compliance alerts from OneView |
| Typical use | Patching, reboots, cluster failovers at the OS level | iLO/Redfish operations, firmware updates, OS (re)deployment via iLO |
| Target identity | Cluster ID or server name (`CLU-` prefix = cluster mode) | Server name, OneView name, or serial number |
| Enabled via | SCOM cmdlets / schedule-maintenance REST API | HPEOneView PowerShell module (`Enable-OVMaintenanceMode`) |
| Auto-expiry | Duration / end-time based; SCOM windows auto-expire | Set for a window (e.g. `+4hours`); removed explicitly by the build |
| Toggled by the build pipeline? | **No** | **Yes** (automatic) |

Because SCOM watches the OS/cluster and OneView watches the hardware, a full server rebuild that you want fully quiet may need **both**: OneView (automatic, via the build) for the hardware, and SCOM (manual/separate) for the OS-level monitoring.

Enable them independently:

```powershell
# OneView (hardware) — normally handled for you by the build pipeline
Set-MaintenanceMode -Action enable -Mode oneview -TargetId 'server01.ad.example.com' -Start 'now' -End '+4hours'

# SCOM (OS/cluster) — enable separately if SCOM monitors the host
Set-MaintenanceMode -Action enable -Mode scom -TargetId 'CLU-CLUSTER-01' -Environment Prod -Start 'now' -End '+4hours'
```

---

<a id="automatic-maintenance-mode-in-the-build-pipeline"></a>

## Automatic maintenance mode in the build pipeline

When you run a build with `Configure-PhysicalBuild` / `Start-PhysicalServerBuild`, the pipeline **automatically** places the target server into **HPE OneView maintenance mode**:

- **Enabled** before any destructive action — i.e. before the ISO is mounted and force-booted, and before post-OS firmware is applied via HPE SUT.
- **Disabled** after the build completes (and also on failure, so the server is never stranded in maintenance).

This stops OneView from raising hardware/firmware alerts or compliance checks while the server is being wiped, reinstalled, and reflashed — avoiding unnecessary on-call callouts.

```powershell
# OneView maintenance mode is ON by default during the build
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' -FirmwareFolders @('\\fileserver\fw\BIOS') `
    -InMaintenanceWindow -Deploy -GuardRail 'srv01'

# Skip it only when OneView is unavailable or the server is not OneView-managed
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' `
    -NoMaintenanceMode -InMaintenanceWindow -Deploy -GuardRail 'srv01'
```

Key points:

- Controlled by `-OneViewMaintenanceMode` (default `$true`). Use `-NoMaintenanceMode` to skip.
- Only **HPE OneView** maintenance mode is automated here. **SCOM maintenance mode is never toggled by the build** — the build operates at the hardware/iLO layer. If you also want to suppress SCOM alerts on the rebuilt host, enable SCOM maintenance mode separately with `Set-MaintenanceMode -Mode scom` (see above).
- This behaviour is required by the runbook (`docs/Automation/runbook-requirements-v2.md`): maintenance mode is part of the standard build workflow, not an optional manual step.

---

<a id="flow"></a>

## Flow

- SCOM: enable, disable, or validate maintenance mode for a cluster of servers, via PowerShell cmdlets or the SCOM [schedule maintenance REST API](https://learn.microsoft.com/en-us/rest/api/operationsmanager/schedule-maintenance) (SCOM 2019 UR1+).
- HPE OneView: enable, disable, or validate maintenance mode per server or scope via the HPEOneView PowerShell module (e.g. `HPEOneView.1000`).
- Maintenance mode suppresses SCOM and OneView alerting for the window.
- Update OpsRamp metrics/events (OpsRamp is not used for alerting itself, to avoid duplicate alerts).
- Email the distribution list when maintenance mode changes for a cluster group.

---

<a id="architecture"></a>

## Architecture

```
iRequest or manual call (Set-MaintenanceMode)
          ↓
    enable action
          ↓
     ├─ SCOM      → maintenance mode on group/server objects (duration-based)
     ├─ OneView   → Enable-OVMaintenanceMode per server or scope member
     ├─ OpsRamp   → metrics + alerts + events
     ├─ Email     → distribution-list notification
     └─ Scheduler → schedule disable at window end time
          ↓
    ... maintenance window ...
          ↓
    Scheduler triggers disable at computed end time
          ↓
     ├─ Email disabled notification
     ├─ OpsRamp metrics = 0
     └─ SCOM windows auto-expire (duration / end-time)
```

---

<a id="high-level-flow"></a>

## High-Level Flow

1. **Enable** - validate the target (cluster ID, server name, or OneView serial number), optionally compute the end time from the cluster schedule, then enable maintenance in SCOM or OneView. Optionally schedule a one-shot task to run disable at the end time.
2. **Disable** - reverse the enable actions and clear the maintenance windows (SCOM disable includes a post-disable stabilization wait, default 120s).
3. **Validate** - query the actual maintenance mode status from SCOM/OneView without altering state.
4. **Dry run** (`-DryRun`) - walk any action with mock data and audit records but skip all subsystem mutations.

---

<a id="functionality"></a>

## Functionality

---

<a id="scheduled-automatic-disable"></a>

### Scheduled Automatic Disable

When enable is called without `-NoSchedule`, a one-shot OS task is created to run disable at the computed end time. This task sends the disabled notification, resets OpsRamp metrics, and writes an audit entry. The task should not be skipped unless disable is managed another way.

---

<a id="audit-logging"></a>

### Audit Logging

Every run writes a timestamped JSON file and appends one JSON line to a master log. Records include target ID, action, mode, dry-run flag, per-system success flags (SCOM, OneView, email, OpsRamp), start/end timestamps, and any errors.

---

<a id="opsramp-integration"></a>

### OpsRamp Integration

On enable/disable (non-dry-run): publish per-server metric `maintenance.mode` (1 / 0), fire `maintenance.enabled` or `maintenance.disabled` alerts, and emit an event. Failure to publish is recorded in the audit record but does not block the overall operation.

---

<a id="environment-variables"></a>

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` | SCOM connection credentials |
| `ONEVIEW_USER` / `ONEVIEW_PASSWORD` | OneView authentication |
| `ENVIRONMENT` | Default environment (`Test` / `Prod`) when `-Environment` is not passed |
| `MAINTENANCE_HOST` | Optional management host override |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP auth (optional / often not required internally) |
| `OPSRAMP_*` family | OpsRamp client credentials (shared across scripts) |

---

<a id="configuration-files"></a>

### Configuration Files

Configuration lives in JSON files under `configs/`, plus one optional plain-text list at the repository root.

| File | Purpose |
|------|---------|
| `configs/connection_hosts.json` | Environment-based host resolution (`environments` → `Test`/`Prod` → `scom`/`oneview`) |
| `configs/clusters_catalogue.json` | Cluster definitions: servers, SCOM groups, default schedules |
| `configs/servers_catalogue.oneview.json` | OneView servers: serial number / display name / OneView name mapping |
| `configs/scom_config.json` | SCOM connection settings (server, module name, WinRM flags, credential env-var names) |
| `configs/oneview_config.json` | OneView `appliance` and `module_name` (e.g. `HPEOneView.1000`) |
| `configs/email_distribution_lists.json` | SMTP settings and recipient lists for enabled / disabled / failure events |
| `configs/opsramp_config.json` | OpsRamp client settings (re-used across all automation stages) |
| `maintenance_distribution_list.txt` (repo root) | Optional override: one email per line (takes precedence over JSON lists) |

---

<a id="error-handling"></a>

### Error Handling

No automatic rollback is performed on partial failure (e.g., some servers succeeded and others failed). The operator receives a structured audit record with per-object success flags, an email notification if the mail subsystem is healthy, and OpsRamp alerts. Manual recovery is via the SCOM console, OneView, or by re-running `Set-MaintenanceMode -Action disable`.

---

<a id="timezone-and-scheduling"></a>

### Timezone and Scheduling

All datetime values are UTC only; no local timezone conversion is performed. Supply explicit UTC datetimes (`YYYY-MM-DD HH:MM` or ISO 8601) or relative offsets (`now`, `+2hours`) for `-Start` / `-End`.

---

<a id="security-considerations"></a>

## Security Considerations

- Credentials flow through environment variables exclusively; no plaintext configs.
- Scheduler tasks run as SYSTEM by default - restrict to a dedicated service account under least-privilege policy.
- Audit records are local by default; forward to SIEM for retention and access control.

---

<a id="troubleshooting"></a>

## Troubleshooting

| Symptom | Check |
|---------|-------|
| SCOM module not found | Install SCOM console or remote administration tools; verify `scom_config.json` module name |
| OneView connection failures | Verify appliance hostname and credentials; check HTTPS 443 reachability; verify the HPEOneView module (`oneview_config.json` `module_name`) is installed |
| Scheduler task not created | Run elevated or ensure `SeBatchLogonRight` for the acting account |
| Email not sent | Verify SMTP connectivity and `smtp_server` in `email_distribution_lists.json` |
| OpsRamp metrics absent | Check `opsramp_config.json` presence and network access |

---

<a id="future-enhancements"></a>

## Future Enhancements

- Automatic rollback of successful subsystems on partial failure
- SCOM exit-notification via SCOM alert pipeline
- Per-server individual windows within a cluster

---

<a id="testing"></a>

## Testing

<a id="maintenance-mode-test-runner"></a>

### Maintenance Mode Test Runner

A dedicated test runner (`make maint-mode-tests`) runs high-priority Pester tests for the three primary actions:

- **Enable** (`Set-MaintenanceMode.Enable.Tests.ps1`) - validates SCOM and OneView enable paths
- **Disable** (`Set-MaintenanceMode.Disable.Tests.ps1`) - validates reverse operations and post-disable waits
- **Validate** (`Set-MaintenanceMode.Validation.Tests.ps1`) - validates cluster configuration without altering state

```bash
# Run maintenance mode tests only
make maint-mode-tests

# Or directly
pwsh -File scripts/run-maint-mode-tests.ps1
```

Each test file contains BDD-style Pester `Describe`/`Context`/`It` blocks covering enable/disable/validate actions, parameter validation, dry-run behaviour, and error scenarios. Results include a Jest/Pytest-style summary block with pass/fail counts.

---

<a id="change-history"></a>

## Change History

- 2026-06-09: Added `make maint-mode-tests` target and dedicated test runner for high-priority enable/disable/validate scenarios
- 2026-05-16: Initial version of language-agnostic maintenance-mode reference
