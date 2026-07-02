# Maintenance Mode Orchestration

## Table of Contents

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


Maintenance mode manages scheduled maintenance windows for clusters across two monitoring systems:

- **SCOM 2015** (System Center Operations Manager) - maintenance mode on groups
- **HPE iLO** (Integrated Lights-Out) - Redfish / REST maintenance windows
- **HPE OneView** - REST API or optional legacy CLI

Features include audit logging, OpsRamp telemetry, email notifications, and automatic disable via OS task scheduling.

---

<a name="flow"></a>
## Flow

- SCOM: Maintenance mode needs to operate the SCOM using the [schedule maintenance functionality](https://learn.microsoft.com/en-us/rest/api/operationsmanager/schedule-maintenance)
  - first the script must powershell remote into the server using SCOM and HPe iLO so get a token for the SCOM management servers [here](https://learn.microsoft.com/en-us/rest/api/operationsmanager/#initialize-the-csrf-token)
  - enable, disable or stop maintenance mode for the cluster of servers in SCOM

- HPE OneView: Enable maintenance mode for cluster of servers or disable or stop separately.

- Also disable all alerting during maintenance window SCOM and HPE OneView
- Update OpsRamp
- Alerting is via Marin's alerting SCOM code not via Opsramp do not duplicate alerts
- email dist list when Maintenance mode changes for cluster group

---

<a name="architecture"></a>
## Architecture

```
iRequest or manual call
          ↓
    enable action
          ↓
     ├─ SCOM      → maintenance mode on management groups (duration-based)
     ├─ iLO       → Redfish/POST maintenance windows
      ├─ OneView  → REST API or CLI fallback for node maintenance
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
     └─ SCOM/iLO windows auto-expire (duration / end-time)
```

---

<a name="high-level-flow"></a>
## High-Level Flow

1. **Enable** - validate cluster ID, optionally compute end time from the cluster schedule, then enable maintenance on each configured subsystem (SCOM, iLO, OneView). Optionally schedule a one-shot task to run disable at end time.
2. **Disable** - reverse the enable actions and clear the maintenance windows.
3. **Validate** - confirm the cluster definition and environment are ready without altering any subsystem state.
4. **Dry run** - walk the enable/disable path with real-time logs and audit records but skip all subsystem mutations.

---

<a name="functionality"></a>
## Functionality

---

<a name="scheduled-automatic-disable"></a>
### Scheduled Automatic Disable

When enable is called without `--no-schedule` / `-NoSchedule`, a one-shot OS task is created to run disable at the computed end time. This task sends the disabled notification, resets OpsRamp metrics, and writes an audit entry. The task should not be skipped unless disable is managed another way.

---

<a name="audit-logging"></a>
### Audit Logging

Every run writes a timestamped JSON file and appends one JSON line to a master log. Records include cluster ID, action, dry-run flag, per-system success flags (SCOM, iLO, OneView, email, OpsRamp), start/end timestamps, and any errors.

---

<a name="opsramp-integration"></a>
### OpsRamp Integration

On enable/disable (non-dry-run): publish per-server metric `maintenance.mode` (1 / 0), fire `maintenance.enabled` or `maintenance.disabled` alerts, and emit an event. Failure to publish is recorded in the audit record but does not block the overall operation.

---

<a name="environment-variables"></a>
### Environment Variables

| Variable | Purpose |
|----------|---------|
| `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` | SCOM connection credentials |
| `ILO_USER` / `ILO_PASSWORD` | iLO credentials (global; per-server overrides supported) |
| `ONEVIEW_USER` / `ONEVIEW_PASSWORD` | OneView API/CLI authentication |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP auth (optional / often not required internally) |
| `OPSRAMP_*` family | OpsRamp client credentials (shared across scripts) |

---

<a name="configuration-files"></a>
### Configuration Files

Dozens of options live in clustered JSON files and optional plain-text lists under the `configs/` directory. The conventions are the same across all implementations.

| File | Purpose |
|------|---------|
| `clusters_catalogue.json` | Cluster definitions: servers, SCOM groups, iLO IPs, OneView node IDs, default schedules |
| `scom_config.json` | SCOM connection settings (server, module name, WinRM flags, credential env-var names) |
| `oneview_config.json` | OneView API URL, auth type, optional CLI path |
| `email_distribution_lists.json` | SMTP settings and recipient lists for enabled / disabled / failure events |
| `opsramp_config.json` | OpsRamp client settings (re-used across all automation stages) |
| `maintenance_distribution_list.txt` | Optional override: one email per line (takes precedence over JSON lists) |

---

<a name="error-handling"></a>
### Error Handling

No automatic rollback is performed on partial failure (e.g., SCOM succeeded but iLO failed). The operator receives a structured audit record with per-system success flags, an email notification if the mail subsystem is healthy, and OpsRamp alerts. Manual recovery is via the SCOM console, iLO interface, or by re-running the script with `--disable` / `-Action disable`.

---

<a name="timezone-and-scheduling"></a>
### Timezone and Scheduling

The server's OS timezone should match the `timezone` field in the cluster schedule. The scheduler assumes local time equals the configured timezone when calculating end times. When crossing timezones, supply explicit ISO 8601 datetimes for `--start` / `-Start` and `--end` / `-End`.

---

<a name="security-considerations"></a>
## Security Considerations

- Credentials flow through environment variables exclusively; no plaintext configs.
- Scheduler tasks run as SYSTEM by default - restrict to a dedicated service account under least-privilege policy.
- iLO credentials must hold only maintenance-window-level privileges.
- Audit records are local by default; forward to SIEM for retention and access control.

---

<a name="troubleshooting"></a>
## Troubleshooting

| Symptom | Check |
|---------|-------|
| SCOM module not found | Install SCOM console or remote administration tools; verify `scom_config.json` module name |
| iLO connection failures | Verify IPs and credentials in the cluster catalogue; check HTTPS 443 reachability; self-signed certs handled by default |
| OneView not implemented in initial release | Set `"use_cli": true` and `"cli_path"` in `oneview_config.json` for CLI fallback |
| Scheduler task not created | Run elevated or ensure `SeBatchLogonRight` for the acting account |
| Email not sent | Verify SMTP connectivity and `smtp_server` in `email_distribution_lists.json` |
| OpsRamp metrics absent | Check `opsramp_config.json` presence and network access |

---

<a name="future-enhancements"></a>
## Future Enhancements

- Automatic rollback of successful subsystems on partial failure
- Status query command to inspect current maintenance state per cluster / server
- SCOM exit-notification via SCOM alert pipeline
- Per-server individual windows within a cluster
- Redfish 2023+ `MaintenanceWindow` collection improvements

---

<a name="testing"></a>
## Testing

<a name="maintenance-mode-test-runner"></a>
### Maintenance Mode Test Runner

A dedicated test runner (`make maint-mode-tests`) runs high-priority Pester tests for the three primary actions:

- **Enable** (`Set-MaintenanceMode.Enable.Tests.ps1`) - validates SCOM, iLO, and OneView enable paths
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

<a name="change-history"></a>
## Change History

- 2026-06-09: Added `make maint-mode-tests` target and dedicated test runner for high-priority enable/disable/validate scenarios
- 2026-05-16: Initial version of language-agnostic maintenance-mode reference
