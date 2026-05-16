# Maintenance Mode Orchestration (PowerShell)

## Overview

The `Set-MaintenanceMode` cmdlet (in `powershell/Automation/Public/Set-MaintenanceMode.ps1`) manages scheduled maintenance windows for clusters across three monitoring systems:

- **SCOM 2015** (System Center Operations Manager) using the OperationsManager module (local or WinRM)
- **HPE iLO** (Integrated Lights-Out) using the Redfish/REST maintenance windows API
- **HPE OpenView** (Micro Focus OpenView) using REST API or optional legacy CLI

Provides audit logging, OpsRamp integration, email notifications, and automatic cleanup via Windows Task Scheduler (`schtasks`).

## Architecture

```
iRequest / Manual Call
       ↓
Set-MaintenanceMode -Action enable -ClusterId PROD-CLUSTER-01
       ↓
   ├─ SCOMManager     → New-ScomMaintenanceScript + Invoke-PowerShellWinRM / Invoke-PowerShellScript
   ├─ ILOManager      → Invoke-RestMethod (Redfish maintenancewindows)
   ├─ OpenViewClient  → Invoke-RestMethod / Invoke-Command (CLI fallback)
   ├─ EmailNotifier   → System.Net.Mail.SmtpClient
   ├─ OpsRamp_Client  → metrics + alerts + events
   └─ schtasks        → schedule disable at end time
       ↓
... maintenance window ...
       ↓
schtasks triggers Set-MaintenanceMode -Action disable --no-schedule
       ↓
   ├─ Email disabled notification
   ├─ OpsRamp metrics = 0
   └─ (SCOM/iLO auto-expire via duration)
```

## Shared Utilities (DRY)

`Set-MaintenanceMode.ps1` uses the private helpers in `powershell/Automation/Private/`:

- **Config.ps1** — `Import-JsonConfig` with `${VAR}` environment substitution
- **Logging.ps1** — `Initialize-Logging` (file + console)
- **Audit.ps1** — `_Save-AuditRecord` writes per-action JSON + appends to `maintenance_audit.log`
- **Executor.ps1** — `Invoke-PowerShellScript`, `Invoke-PowerShellWinRM`, `Invoke-Command` wrappers
- **Credentials.ps1** — `Get-IloCredentials`, `Get-OpenViewCredentials`, `Get-CredentialSecret`
- **Base.ps1** — `AutomationBase` class (used by other modules; maintenance re-uses the same patterns)
- **FileIO.ps1** — `Ensure-DirectoryExists`

All public cmdlets follow the same pattern: import the module manifest, call `Initialize-Logging` once, load JSON configs, then execute.

## Prerequisites

1. **Windows Server 2016/2019/2022** (or Windows 10/11 for local dev) with:
   - PowerShell 5.1+ (Desktop) or 7.2+ (Core)
   - SCOM 2015 console or remote management tools (`OperationsManager` module)
   - Network access to SCOM management server (WinRM 5985/5986), iLO HTTPS (443), OpenView endpoint
2. **Credentials** as environment variables (CyberArk-injected in Jenkins):
   - `SCOM_ADMIN_USER`, `SCOM_ADMIN_PASSWORD`
   - `ILO_USER`, `ILO_PASSWORD` (global; per-server overrides via `ilo_credentials` in cluster definition)
   - `OPENVIEW_USER`, `OPENVIEW_PASSWORD`
   - `SMTP_USER`, `SMTP_PASSWORD` (optional)
3. **Module installed** (see `powershell/README.md`):
   ```powershell
   Import-Module .\powershell\Automation\Automation.psd1 -Force
   ```

## Configuration Files (root `configs/`)

| File | Purpose |
|------|---------|
| `clusters_catalogue.json` | Clusters, servers, SCOM groups, iLO IPs, OpenView node IDs, schedules |
| `scom_config.json` | Management server, module name, WinRM flag, credential env-var names |
| `openview_config.json` | API URL, version, endpoint, auth type, optional CLI path |
| `email_distribution_lists.json` | SMTP settings + distribution lists for enabled/disabled events |
| `opsramp_config.json` | Existing OpsRamp integration (re-used) |
| `maintenance_distribution_list.txt` | Optional one-email-per-line override |

Example cluster entry (same JSON as Python):

```json
"PROD-CLUSTER-01": {
  "display_name": "Production Cluster 01",
  "servers": ["web01.example.com", "web02.example.com"],
  "scom_group": "SCOM_Prod_WebDB",
  "ilo_addresses": { "web01.example.com": "192.168.1.101" },
  "openview_node_ids": { "web01.example.com": "OV001" },
  "schedule": { "timezone": "Europe/Dublin", "work_days": ["Mon","Tue"], "work_start": "08:00" },
  "environment": "production"
}
```

## Usage

### Enable Maintenance Window

```powershell
# Explicit start/end
Set-MaintenanceMode -Action enable -ClusterId PROD-CLUSTER-01 `
    -Start "2025-05-15 22:00:00" -End "2025-05-16 08:00:00"

# Use cluster schedule for end time
Set-MaintenanceMode -Action enable -ClusterId PROD-CLUSTER-01 -Start now
```

When `-End` is omitted, the next work-day `work_start` is computed.

### Disable (Manual)

```powershell
Set-MaintenanceMode -Action disable -ClusterId PROD-CLUSTER-01
```

### Validate Cluster Definition

```powershell
Set-MaintenanceMode -Action validate -ClusterId PROD-CLUSTER-01
```

### Dry Run

```powershell
Set-MaintenanceMode -Action enable -ClusterId PROD-CLUSTER-01 -Start now -DryRun
```

No SCOM/iLO/OpenView changes are made; audit, email (if configured), and logs are still produced.

### Verbose Logging

Add `-Verbose` (or set `$VerbosePreference = 'Continue'`).

## Scheduled Automatic Disable

On `enable` (unless `-NoSchedule`), a one-time scheduled task `MaintenanceDisable-<ClusterId>` is created that runs at the computed end time. The task invokes:

```powershell
pwsh.exe Set-MaintenanceMode.ps1 -Action disable -ClusterId <id> -NoSchedule
```

The task runs as SYSTEM (or the specified `/RU`). SCOM/iLO windows auto-expire; the task ensures email + OpsRamp cleanup.

## Audit Logging

Each run writes:
- `logs/<action>_<ClusterId>_<unix-ts>.json`
- Appends one JSON line to `logs/maintenance_audit.log`

Audit contains: cluster, action, dry-run flag, per-system results (scom/ilo/openview/email/opsramp), start/end, success flag, any errors.

## OpsRamp Integration

On enable/disable (non-dry-run):
- Metric `maintenance.mode` = 1 (enabled) or 0 (disabled) per server
- Alert `maintenance.enabled` / `maintenance.disabled`
- Event with cluster details

Failure to send does not fail the overall operation but is recorded in the audit.

## Error Handling & Rollback

No automatic rollback on partial failure (intentional). The operator receives:
- Detailed per-system success flags in the audit JSON
- Email notification (if possible)
- OpsRamp alerts for failures

Manual recovery: SCOM console, iLO Redfish, or re-run with `-Action disable`.

## Timezone and Schedule

- Server local time is assumed to match the cluster `schedule.timezone`.
- Provide absolute ISO strings (`-Start "2025-05-15T22:00:00"`) when crossing timezones.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` | SCOM connection |
| `ILO_USER` / `ILO_PASSWORD` | Global iLO credentials |
| `OPENVIEW_USER` / `OPENVIEW_PASSWORD` | OpenView auth |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP auth (optional) |
| `OPSRAMP_*` | OpsRamp client (re-used from other stages) |

## Files Created

| Path | Description |
|------|-------------|
| `logs/<action>_<cluster>_<ts>.json` | Per-action audit |
| `logs/maintenance_audit.log` | Master line-delimited JSON |
| Windows Task `MaintenanceDisable-<cluster>` | Auto-disable scheduler |

## Troubleshooting

- **SCOM module not found**: Install SCOM console/remote tools; ensure `scom_config.json` points to correct module name.
- **iLO REST failures**: Verify IPs in catalogue, credentials, and that iLO firmware supports Redfish maintenance windows. Self-signed certs are accepted (no verify).
- **OpenView CLI fallback**: Set `"use_cli": true` and `"cli_path"` in `openview_config.json`.
- **Scheduled task not created**: Run as Administrator or ensure `SeBatchLogonRight`.
- **Email not sent**: Check SMTP reachability and `email_distribution_lists.json`.

## Integration with iRequest

Call via:

```powershell
pwsh.exe -File Set-MaintenanceMode.ps1 -Action enable -ClusterId PROD-CLUSTER-01 -Start now
```

Capture exit code (0 = success).

## Security Considerations

- No plaintext passwords in configs; all via environment variables / CyberArk.
- Scheduled tasks run as SYSTEM by default — restrict via dedicated service account if needed.
- iLO credentials limited to maintenance-window privileges.
- Audit logs can be shipped to SIEM.

## Jenkins Pipeline Integration

The root `Jenkinsfile` currently runs Python scans in the `Code Quality & Security Scan` stage. Extend it for PowerShell maintenance mode exactly as described in `docs/powershell/code_quality.md`:

```powershell
# Inside the existing 'Code Quality & Security Scan' stage (after Python tools)
echo [INFO] [7/7] Running PSScriptAnalyzer on maintenance module...
Invoke-ScriptAnalyzer -Path 'powershell\Automation\Public\Set-MaintenanceMode.ps1' `
    -Severity Error,Warning -OutputFormat Json `
    -OutFile 'code_scan_results\psa_maintenance.json'

# Future: add dedicated Pester stage for maintenance tests
$result = Invoke-Pester -Path 'powershell\Tests\Set-MaintenanceMode.Tests.ps1' `
    -OutputFile 'maintenance-pester-results.xml' -OutputFormat NUnitXml -PassThru
if ($result.FailedCount -gt 0) { exit 1 }
```

See `docs/powershell/code_quality.md` for the full PSScriptAnalyzer + gitleaks configuration, quality gates, and `FAIL_ON_CODE_ISSUES` parameter handling.

## Future Enhancements

- Rollback logic on partial subsystem failure
- Status query cmdlet (`Get-MaintenanceStatus`)
- SCOM alert integration for exit notification
- Per-server (not just cluster) maintenance windows
- Redfish 2023+ `MaintenanceWindow` collection improvements

## Change History

- 2026-05-16: Initial PowerShell maintenance-mode guide, matching `Set-MaintenanceMode.ps1` implementation and referencing the Jenkins PowerShell scan pipeline from `docs/powershell/code_quality.md`.
