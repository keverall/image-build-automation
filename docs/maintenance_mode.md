# Maintenance Mode Orchestration

## Overview

The `maintenance_mode.py` script manages scheduled maintenance windows for clusters across three monitoring systems:

- **SCOM 2015** (System Center Operations Manager) using PowerShell cmdlets
- **HPE iLO** (Integrated Lights-Out) using REST API or CLI
- **HPE OpenView** (Micro Focus OpenView) using REST API or legacy CLI

Provides audit logging, OpsRamp integration, email notifications, and automatic cleanup via Windows Task Scheduler.

## Architecture

```
iRequest / Manual Call
       ↓
maintenance_mode.py (enable)
       ↓
  ├─ SCOM       → PowerShell cmdlets → group maintenance mode (duration-based)
  ├─ iLO        → REST / ilorest → maintenance windows
  ├─ OpenView   → HTTP API / CLI → node maintenance
  ├─ OpsRamp    → metrics + alerts
  ├─ Email      → distribution list notification
  └─ schtasks   → schedule disable at end time
       ↓
... maintenance window ...
       ↓
schtasks triggers maintenance_mode.py (disable) at end time
       ↓
  ├─ Email disabled notification
  ├─ OpsRamp metrics = 0
  └─ (SCOM/iLO auto-expire via duration)
```

## Prerequisites

1. **Windows Server 2016** with:
   - Python 3.9+ (includes `zoneinfo` for TZ handling) – or install `pytz` if using older Python
   - PowerShell 5.1+
   - SCOM 2015 console & OperationsManager module installed
   - HPE iLO PowerShell module (`HPiLOCmdlets`) *optional* – REST fallback uses `requests`
   - HPE OpenView client utilities or API access *optional*
2. **Credentials** set as environment variables on the system where the script runs:
   - `SCOM_ADMIN_USER`, `SCOM_ADMIN_PASSWORD` (if WinRM or explicit credentials required)
   - `ILO_USER`, `ILO_PASSWORD` (global iLO credentials; per-cluster overrides supported)
   - `OPENVIEW_USER`, `OPENVIEW_PASSWORD` (if OpenView requires auth)
   - `SMTP_USER`, `SMTP_PASSWORD` (if SMTP auth needed)
3. **Python dependencies** installed:
   ```bash
   pip install -r requirements.txt
   ```
   The script uses `requests` and optionally `pywinrm`.
4. **Network access** from the script host to:
   - SCOM management server (WinRM 5985/5986 if remote)
   - iLO interfaces of all target servers (HTTPS 443)
   - OpenView API endpoint (HTTPS typically)
   - SMTP server

**Note:** The script must be run under an account with Administrator privileges to create Windows Scheduled Tasks and execute SCOM PowerShell cmdlets.

## Configuration Files (root `configs/`)

| File | Purpose |
|------|---------|
| `clusters_catalogue.json` | Defines clusters, their servers, SCOM groups, iLO IPs, OpenView node IDs, and default schedules. |
| `scom_config.json` | SCOM connection details (management server, module name, WinRM flags, credentials env vars). |
| `openview_config.json` | OpenView API URL, auth, optional CLI path. |
| `email_distribution_lists.json` | SMTP settings and distribution lists for enabled/disabled/failure events. |
| `opsramp_config.json` | Existing OpsRamp integration (used unchanged). |

### Example: clusters_catalogue.json

```json
{
  "clusters": {
    "PROD-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "servers": ["web01.example.com", "web02.example.com", "db01.example.com"],
      "scom_group": "SCOM_Prod_WebDB",
      "scom_management_server": "scom01.example.com",
      "ilo_addresses": {
        "web01.example.com": "192.168.1.101",
        "web02.example.com": "192.168.1.102",
        "db01.example.com": "192.168.1.103"
      },
      "openview_node_ids": {
        "web01.example.com": "OV001",
        "web02.example.com": "OV002",
        "db01.example.com": "OV003"
      },
      "schedule": {
        "timezone": "Europe/Dublin",
        "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "work_start": "08:00",
        "work_end": "17:00"
      },
      "environment": "production"
    }
  }
}
```

### Important Notes

- **Cluster ID** must match a top-level key in `clusters`. Using a server hostname that is not a cluster key will be rejected.
- `schedule` is used only when `--end` is omitted; it calculates the next maintenance window end (default: next work start, e.g., 08:00 on next workday).
- `ilo_addresses` and `openview_node_ids` map server names to their respective management endpoints.
- Credentials can be global (`ILO_USER`/`ILO_PASSWORD`) or per-server via `ilo_credentials` that reference environment variables.

## Usage

### Enable Maintenance Window

```bash
# Using explicit start/end
python scripts/maintenance_mode.py \
  --cluster-id PROD-CLUSTER-01 \
  --start "2025-05-15 22:00:00" \
  --end "2025-05-16 08:00:00"

# Use now as start; let end be computed from cluster schedule
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --start now
```

When `--end` is omitted, script uses the cluster's `schedule.work_start` on the next workday after start.

### Disable Maintenance (Manual)

While the scheduled task automatically runs disable at the end time, you can also manually trigger:

```bash
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --disable
```

### Validate Cluster Configuration

```bash
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --action validate
```

### Dry Run

```bash
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --start now --dry-run
```

No changes are made to SCOM/iLO/OpenView, but logs, audit records, and emails (if configured) are still generated as simulated.

### Verbose Logging

Add `--verbose` to see DEBUG-level logs.

## Scheduled Automatic Disable

When `enable` is called and `--no-schedule` is **not** set, the script creates a Windows Scheduled Task named `MaintenanceDisable-<cluster_id>` that runs at the computed/passed end time. This task invokes the script with `--action disable --no-schedule`, which:

- Sends the maintenance-disabled email
- Sends OpsRamp metrics (maintenance.mode = 0)
- Logs an audit entry

SCOM/iLO maintenance windows automatically expire based on the duration set during enable (SCOM) or the window's end time (iLO). No additional interaction is needed for them, but the task ensures notifications and cleanup metrics happen promptly.

## Audit Logging

Each run creates a JSON audit file in `logs/maintenance_<action>_<cluster>_<timestamp>.json`. Additionally, a master log `logs/maintenance_audit.log` contains one JSON object per line for all actions.

Audit includes:
- Cluster ID, action, dry-run flag
- Per-system results: SCOM, iLO, OpenView, email, OpsRamp
- Start and end timestamps
- Any error messages

## OpsRamp Integration

Automatically sends:
- Metric `maintenance.mode` per server (1 = enabled, 0 = disabled)
- Alert of type `maintenance.enabled` / `maintenance.disabled` with details
- Event `maintenance.enabled` / `maintenance.disabled`

If OpsRamp configuration is missing or fails, the script continues but logs the failure and returns non-zero exit code if any critical step fails.

## Error Handling & Rollback

The script does **not** perform automatic rollback if a subset of operations fails (e.g., SCOM succeeded but iLO failed). This is intentional to avoid leaving systems in inconsistent state during partial failures. Instead, the operator receives:
- Detailed audit with per-system success flags
- Email notification (if possible) indicating partial or full failure
- OpsRamp alerts for failures

Manual recovery may involve:
- Using SCOM console to end maintenance manually for affected servers
- Using iLO interface to clear maintenance windows
- Running the script with `--disable` after fixing issues or using iLO CLI to remove windows.

## Timezone and Schedule

- The server's system timezone should be set to the timezone used in cluster schedules (e.g., Europe/Dublin). The script performs naive datetime calculations assuming local time matches the scheduled timezone.
- If your server runs in a different timezone, ensure you provide absolute ISO datetimes with `--start` and `--end` to avoid ambiguity.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SCOM_ADMIN_USER` | SCOM administrator username (if required) |
| `SCOM_ADMIN_PASSWORD` | SCOM admin password |
| `ILO_USER` | Global iLO username (default: Administrator) |
| `ILO_PASSWORD` | Global iLO password |
| `OPENVIEW_USER` | OpenView API/CLI username |
| `OPENVIEW_PASSWORD` | OpenView password |
| `SMTP_USER` | SMTP auth username (optional) |
| `SMTP_PASSWORD` | SMTP auth password (optional) |
| `OPSRAMP_CLIENT_ID`, `OPSRAMP_CLIENT_SECRET`, `OPSRAMP_TENANT_ID` | OpsRamp integration (already used by other scripts) |

## Files Created

| Path | Description |
|------|-------------|
| `logs/maintenance_<action>_<cluster>_<ts>.json` | Per-action audit record |
| `logs/maintenance_audit.log` | Master log (line-delimited JSON) |
| Windows Task Scheduler entry `MaintenanceDisable-<cluster>` | Scheduled disable task |

## Troubleshooting

### SCOM errors: "OperationsManager module not found"
Install SCOM console or remote administration tools on the machine running the script.

### iLO connection failures
- Verify iLO IPs in `clusters_catalogue.json`
- Confirm `ILO_USER`/`ILO_PASSWORD` are correct and have Administrator privileges
- Check network connectivity to iLO ports (443)
- For self-signed certificates, warnings are suppressed; if SSL errors occur, ensure `verify=False` is used in REST client (already).

### OpenView not implemented
By default the OpenView client attempts REST; if your environment uses CLI, set `"use_cli": true` and `"cli_path": "C:\\Path\\to\\ovcall.exe"` in `openview_config.json`.

### Scheduled task not created
Ensure the script has permission to create tasks (Administrator). Run the script elevated or ensure the user account has `SeBatchLogonRight`.

### Email not sent
Verify SMTP server and credentials; check `email_distribution_lists.json` and that `smtp_server` is reachable.

## Integration with iRequest

To call from iRequest:
```bash
# Using absolute path
C:\Python39\python.exe C:\path\to\maintenance_mode.py --cluster-id PROD-CLUSTER-01 --start now
```

iRequest should capture the script's exit code (0 = success, non-zero = failure) and log output.

## Security Considerations

- Avoid storing plaintext passwords in config files; use environment variables or a secrets manager.
- Schedule tasks run as SYSTEM by default; ensure this account has necessary environment access or change to a dedicated service account.
- Ensure iLO credentials have only the minimum required privileges (maintenance window management).
- Audit logs are stored locally; consider shipping them to a central SIEM.

## Future Enhancements

- Add rollback logic: if any subsystem fails, attempt to revert successful ones.
- Add status query to report current maintenance state across systems.
- Add integration with SCOM for automated exit notification.
- Support per-server individual windows within a cluster.
- Add more sophisticated iLO/Redfish detection and fallback.
