# Configuration Files Reference

This directory contains all configuration for the HPE ProLiant Windows Server ISO Automation pipeline.

## Summary Table

| File | Purpose | Required | Secret? |
|------|---------|----------|---------|
| `server_list.txt` | Target server hostnames | Yes | No |
| `clusters_catalogue.json` | Cluster definitions (SCOM groups, iLO IPs, schedules) | Yes | No |
| `hpe_firmware_drivers_nov2025.json` | HPE repository URL and component versions | Yes | No |
| `windows_patches.json` | Security patch KB list and metadata | Yes | No |
| `scom_config.json` | SCOM 2015 management server connection | Optional | No |
| `openview_config.json` | HPE OpenView API/CLI settings | Optional | No |
| `email_distribution_lists.json` | SMTP server and recipient lists | Optional | No |
| `opsramp_config.json` | OpsRamp API credentials | Yes (if OpsRamp used) | Yes |
| `maintenance_distribution_list.txt` | Override for maintenance emails | Optional | No |

**Secrets** (passwords, API keys, tokens) must be provided via **environment variables**, not stored in files.

---

## server_list.txt

Plain-text list of target servers, one per line. Optional columns for management IPs.

```
# Format: hostname  [ipmi_ip]  [ilo_ip]
server1.example.com
server2.example.com,192.168.1.102,192.168.1.202
server3.example.com,,,,  # (blank fields allowed but not recommended)
```

- **Column 1** (required): Server hostname (FQDN or NetBIOS name)
- **Column 2** (optional): IPMI/iDRAC/IPMI IP address
- **Column 3** (optional): iLO IP address

**Note**: When using `clusters_catalogue.json`, this file may be used for simple single-server builds only. Clustered environments should define servers in the catalogue.

---

## clusters_catalogue.json

Defines logical clusters, their member servers, SCOM groups, iLO endpoints, OpenView node IDs, and maintenance schedules.

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

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `display_name` | string | Human-readable cluster name |
| `servers` | array of strings | Member server hostnames (must match keys in `ilo_addresses`) |
| `scom_group` | string | SCOM 2015 group display name for this cluster |
| `scom_management_server` | string | SCOM management server hostname/IP |
| `ilo_addresses` | object | Map: `server_hostname → iLO IP/hostname` |
| `openview_node_ids` | object | Map: `server_hostname → OpenView node identifier` |
| `schedule.timezone` | string | IANA timezone (e.g., `Europe/Dublin`, `America/New_York`) |
| `schedule.work_days` | array of 3-char day codes | `["Mon","Tue","Wed","Thu","Fri"]` |
| `schedule.work_start` | string | Daily maintenance start (HH:MM, 24h) |
| `schedule.work_end` | string | Daily maintenance end (HH:MM, 24h) |
| `environment` | string | `production`, `staging`, or `dev` |

**Notes**:
- Only top-level keys in `clusters` are valid cluster IDs. Server hostnames that are not top-level keys are **rejected** by `maintenance_mode.py --validate`.
- `schedule` is used only when `--end` is omitted; the script calculates the next workday 08:00 after start time.
- `scom_management_server` can be overridden by `scom_config.json` per-environment but typically matches.

---

## hpe_firmware_drivers_nov2025.json

HPE Smart Update Tool (SUT) repository and component version manifest.

```json
{
  "firmware_drivers_version": "November 2025",
  "hpe_repository_url": "https://downloads.hpe.com/repo/nov2025/",
  "hpe_repository_username": "${HPE_DOWNLOAD_USER}",
  "hpe_repository_password": "${HPE_DOWNLOAD_PASS}",
  "components": {
    "gen10_plus": {
      "firmware": [
        {
          "component": "HPE_BIOS",
          "version": "2.80",
          "description": "System ROM"
        },
        {
          "component": "HPE_ILO5",
          "version": "2.70",
          "description": "iLO 5 Firmware"
        }
      ],
      "drivers": [
        {
          "component": "HPE_SSA",
          "version": "4.20",
          "description": "Smart Storage Administrator"
        }
      ]
    },
    "gen10": {
      "firmware": [...],
      "drivers": [...]
    }
  }
}
```

### Environment Substitution

Credentials use `${VAR}` placeholders replaced at runtime from environment:

```bash
export HPE_DOWNLOAD_USER="my_username"
export HPE_DOWNLOAD_PASS="my_password"
```

### Component Selection

The `update_firmware_drivers.py` script reads this manifest and instructs HPE SUT to:
1. Download each component (firmware + drivers) for the detected server generation
2. Verify checksums
3. Create a bootable Service Pack for ProLiant (SPP) ISO

---

## windows_patches.json

Security update specifications for DISM offline patching.

```json
{
  "patches": [
    {
      "kb_number": "KB5041234",
      "severity": "Critical",
      "cve_ids": ["CVE-2025-12345", "CVE-2025-67890"],
      "description": "Security update for Windows Kernel",
      "url": "https://catalog.update.microsoft.com/...",
      "release_date": "2025-03-15"
    }
  ]
}
```

**Notes**:
- `kb_number` must match Microsoft Update Catalog identifier
- `cve_ids` array may be empty if CVE IDs unknown
- `url` is optional metadata for manual lookup
- `patch_windows_security.py` mounts base ISO, applies these MSU files via DISM, generates patched ISO

---

## scom_config.json

System Center Operations Manager connection details.

```json
{
  "scom_2015": {
    "management_server": "scom01.example.com",
    "module_name": "OperationsManager",
    "use_winrm": false,
    "winrm_transport": "ntlm",
    "winrm_port": 5985,
    "credentials": {
      "username_env": "SCOM_ADMIN_USER",
      "password_env": "SCOM_ADMIN_PASSWORD"
    }
  }
}
```

### Fields

| Field | Description |
|-------|-------------|
| `management_server` | SCOM management server hostname/IP |
| `module_name` | PowerShell module name (typically `OperationsManager`) |
| `use_winrm` | If `true`, connect via WinRM instead of local PowerShell |
| `winrm_transport` | `ntlm`, `kerberos`, or `basic` |
| `winrm_port` | 5985 (HTTP) or 5986 (HTTPS) |
| `credentials.username_env` | Environment variable containing admin username |
| `credentials.password_env` | Environment variable containing admin password |

**Credentials** must be set as environment variables on the execution host:

```bash
export SCOM_ADMIN_USER="domain\\adminuser"
export SCOM_ADMIN_PASSWORD="secret_password"
```

---

## openview_config.json

HPE OpenView (Micro Focus) integration settings.

```json
{
  "openview": {
    "api_url": "https://openview.example.com:8443/rest/",
    "api_version": "v1",
    "auth_type": "basic",
    "username_env": "OPENVIEW_USER",
    "password_env": "OPENVIEW_PASSWORD",
    "use_cli": false,
    "cli_path": "C:\\Program Files\\OpenView\\bin\\ovcall.exe",
    "node_id_field": "node_id",
    "maintenance_mode_action": "set_maintenance",
    "verify_ssl": false
  }
}
```

### Modes

- **REST API** (`use_cli: false`): Script sends HTTP requests to `api_url` with Basic auth.
- **CLI** (`use_cli: true`): Script invokes `cli_path` with command-line arguments. Useful for legacy installations without REST enabled.

**Authentication**: Set environment variables:

```bash
export OPENVIEW_USER="ov_admin"
export OPENVIEW_PASSWORD="ov_password"
```

---

## email_distribution_lists.json

SMTP configuration and recipient lists for notification emails.

```json
{
  "smtp": {
    "server": "smtp.example.com",
    "port": 25,
    "use_tls": false,
    "use_ssl": false,
    "username_env": "SMTP_USER",
    "password_env": "SMTP_PASSWORD",
    "from_address": "iso-automation@example.com"
  },
  "distribution_lists": {
    "maintenance_enable": ["infra-team@example.com", "ops@example.com"],
    "maintenance_disable": ["infra-team@example.com"],
    "build_success": ["dev-team@example.com"],
    "build_failure": ["oncall-engineer@example.com", "infra-team@example.com"],
    "scan_critical": ["security@example.com"]
  }
}
```

### Override File

If `maintenance_distribution_list.txt` exists in repository root, its contents (one email per line) override the `maintenance_enable` and `maintenance_disable` lists. This allows quick updates without editing JSON.

**SMTP auth**: If your internal SMTP does not require authentication, omit `username_env`/`password_env` or leave them empty.

---

## opsramp_config.json

Existing OpsRamp integration configuration (not modified by this refactor).

```json
{
  "opsramp_api": {
    "base_url": "https://api.opsramp.com",
    "version": "v2"
  },
  "integration": {
    "send_metrics": true,
    "send_alerts": true,
    "send_events": true
  },
  "credentials": {
    "client_id_env": "OPSRAMP_CLIENT_ID",
    "client_secret_env": "OPSRAMP_CLIENT_SECRET",
    "tenant_id_env": "OPSRAMP_TENANT_ID"
  }
}
```

**Environment variables**:

```bash
export OPSRAMP_CLIENT_ID="your_client_id"
export OPSRAMP_CLIENT_SECRET="your_client_secret"
export OPSRAMP_TENANT_ID="your_tenant_id"
```

---

## Environment Variable Cheat Sheet

```bash
# HPE Repository Access
export HPE_DOWNLOAD_USER="xxx"
export HPE_DOWNLOAD_PASS="xxx"

# iLO Credentials (global defaults)
export ILO_USER="Administrator"
export ILO_PASSWORD="xxx"
# Per-server override: ILO_USER_<SERVER>, ILO_PASSWORD_<SERVER>

# SCOM (if used)
export SCOM_ADMIN_USER="domain\\admin"
export SCOM_ADMIN_PASSWORD="xxx"

# OpenView (if used)
export OPENVIEW_USER="ov_admin"
export OPENVIEW_PASSWORD="xxx"

# SMTP (if auth required)
export SMTP_USER="smtp_user"
export SMTP_PASSWORD="smtp_pass"

# OpsRamp
export OPSRAMP_CLIENT_ID="xxx"
export OPSRAMP_CLIENT_SECRET="xxx"
export OPSRAMP_TENANT_ID="xxx"
```

**Tip**: Store these in a `.env` file and load via `python-dotenv` (already in `requirements.txt`):

```python
from dotenv import load_dotenv
load_dotenv()  # Loads .env in current directory
```

---

## Validation

All scripts call `load_json_config()` which:
1. Checks file exists (if `required=True`)
2. Parses JSON (raises `JSONDecodeError` on syntax error)
3. Substitutes `${VAR}` from environment (searches `os.environ`, leaves unchanged if not found)

To validate all configs at startup (fast sanity check):

```bash
python -c "
from utils.config import load_json_config
import sys

files = [
    'configs/clusters_catalogue.json',
    'configs/scom_config.json',
    'configs/openview_config.json',
    'configs/email_distribution_lists.json',
    'configs/opsramp_config.json',
]

for f in files:
    try:
        load_json_config(f, required=False)
        print(f'OK: {f}')
    except Exception as e:
        print(f'ERROR: {f} — {e}', file=sys.stderr)
        sys.exit(1)
"
```

---

## Change History

- 2026-05-15: Added with DRY refactor and maintenance mode orchestration
