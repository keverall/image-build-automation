# Maintenance Mode Orchestration — Python

This guide documents Python-specific usage of `maintenance_mode.py`. For
language-agnostic concepts (architecture, scheduling, audit format, OpsRamp
integration, required environment variables, security, and troubleshooting) see
[../maintenance_mode.md](../maintenance_mode.md).

---

## Script Location

`src/automation/cli/maintenance_mode.py`

---

## Prerequisites (Python-specific)

- Python 3.9+ (includes `zoneinfo` for TZ handling) — on older Python install
  `backports.zoneinfo`
- PowerShell 5.1+ (bridge for SCOM cmdlet execution)
- SCOM 2015 console & `OperationsManager` module installed (if SCOM is used)
- HPE iLO PowerShell module (`HPiLOCmdlets`) optional — REST fallback uses
  `requests`
- HPE OpenView client utilities or API access (optional)

```bash
pip install -r requirements.txt
```

The script depends on `requests` and optionally on `pywinrm`.

---

## Running as Root or Administrator

The script must run under an account with Administrator privileges to create
Windows Scheduled Tasks and execute SCOM PowerShell cmdlets — even when
called from an elevated parent process.

---

## Configuration Files

| File | Purpose |
|------|---------|
| `clusters_catalogue.json` | Cluster definitions: servers, SCOM groups, iLO IPs, OpenView node IDs, schedules |
| `scom_config.json` | SCOM connection: server, module name, WinRM flags, credential env-var names |
| `openview_config.json` | OpenView: API URL, auth, optional CLI path |
| `email_distribution_lists.json` | SMTP settings and per-event recipient lists |
| `opsramp_config.json` | OpsRamp client (re-used from other scripts) |
| `maintenance_distribution_list.txt` | Optional override: one email per line |

### Example: `clusters_catalogue.json`

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

- **Cluster ID** must match a top-level key in `clusters`.
- Using a server hostname that is not a cluster key is rejected.
- `schedule` is only used when `--end` is omitted; defaults to the next
  `work_start` (e.g., 08:00 the following workday).
- `ilo_addresses` and `openview_node_ids` map server names to management
  endpoints.
- Credentials can be global (`ILO_USER` / `ILO_PASSWORD`) or per-server via
  `ilo_credentials` referencing environment variables.
