# Configuration Files Reference

<a id="top"></a>

## Table of Contents

- [Summary Table](#summary-table)
- [clusters_catalogue.json](#clusters_cataloguejson)
- [servers_catalogue.oneview.json](#servers_catalogueoneviewjson)
- [connection_hosts.json](#connection_hostsjson)
- [scom_config.json](#scom_configjson)
- [oneview_config.json](#oneview_configjson)
- [configmgr_config.json](#configmgr_configjson)
- [hpe_firmware_drivers_nov2025.json](#hpe_firmware_drivers_nov2025json)
- [windows_patches.json](#windows_patchesjson)
- [request_types.json](#request_typesjson)
- [email_distribution_lists.json](#email_distribution_listsjson)
- [opsramp_config.json](#opsramp_configjson)
- [Environment Variable Cheat Sheet](#environment-variable-cheat-sheet)

This directory holds all configuration for the automation pipeline. **Secrets are never stored here** — credentials are supplied via environment variables or CyberArk at runtime.

> **Test/mock fixtures only — never used by live commands.** Every file in `configs/` is a *mock/test fixture*. **Live (terminal and pipeline) commands do NOT read these files.** Live commands are driven entirely by **command parameters** and a small set of documented environment variables (`ONEVIEW_USER`, `ONEVIEW_PASSWORD`, `ONEVIEW_MODULE_NAME`, `MAINTENANCE_HOST`, `HPE_DOWNLOAD_USER`, `SMTP_USER`, `OPSRAMP_*`). In particular, `oneview_config.json`'s `appliance`, `module_name`, and `credentials` are example values used only by unit tests and mocks — the live HPEOneView module is resolved automatically from the appliance's version (or the `ONEVIEW_MODULE_NAME` override) and is **never** taken from this file.

<a name="summary-table"></a>

## Summary Table

| File | Purpose | Required | Secret? |
|------|---------|----------|---------|
| `server_list.txt` | Target server hostnames (one per line) | Yes | No |
| `clusters_catalogue.json` | Cluster definitions: servers, SCOM groups, iLO IPs, OneView scopes, schedules | Yes | No |
| `servers_catalogue.oneview.json` | OneView server definitions (serial → name, iLO IP, scope) | Yes | No |
| `connection_hosts.json` | Per-environment SCOM/OneView appliance host mappings | Yes | No |
| `scom_config.json` | SCOM connection, transport, maintenance and managed-server settings | Optional | No |
| `oneview_config.json` | HPE OneView appliance and module settings | Optional | No |
| `configmgr_config.json` | Example ConfigMgr site/MP/DP values (real builds pass these as runtime params) | No | No |
| `hpe_firmware_drivers_nov2025.json` | HPE SUT firmware/driver component manifest and repo URL | Yes | No |
| `windows_patches.json` | Windows security patch set (KB list, DISM order, metadata) | Yes | No |
| `request_types.json` | Single source of truth for automation request types, CI stage mapping and routing | Yes | No |
| `email_distribution_lists.json` | SMTP server and notification recipient lists | Optional | No |
| `opsramp_config.json` | OpsRamp API, credentials and alert/metric settings | Optional | No |
| `maintenance_distribution_list.txt` | **Repo-root** override for maintenance email recipients | Optional | No |

> `maintenance_distribution_list.txt` lives at the **repository root**, not in `configs/`.

---

<a name="clusters_cataloguejson"></a>

## clusters_catalogue.json

Defines logical clusters, their member servers, SCOM groups, iLO endpoints, OneView scopes/node IDs and maintenance schedules.

```json
{
  "clusters": {
    "CLU-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "servers": ["prod-server-01.example.com", "prod-server-02.example.com"],
      "scom_group": "SCOM_Prod_Cluster_01",
      "scom_version": "2019",
      "scom_management_server": "vr-opm19p1-7382.ad.example.com",
      "scom_environment": "production",
      "ilo_addresses": {
        "prod-server-01.example.com": "192.168.1.101",
        "prod-server-02.example.com": "192.168.1.102"
      },
      "oneview_scope": "Production_Cluster_01",
      "oneview_node_ids": {
        "prod-server-01.example.com": "OV_NODE_001",
        "prod-server-02.example.com": "OV_NODE_002"
      },
      "schedule": {
        "timezone": "UTC",
        "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "work_start": "08:00",
        "work_end": "17:00"
      },
      "environment": "production"
    }
  }
}
```

**Field notes**
- Only top-level keys under `clusters` are valid cluster IDs.
- `schedule` is used to compute the maintenance window end time when `-End` is omitted.
- `scom_version` selects the connection method (2012/2016 = PowerShell remoting only; 2019 UR1+ / 2025 = REST API also available).

---

<a name="servers_catalogueoneviewjson"></a>

## servers_catalogue.oneview.json

OneView-centric server catalogue used for serial-number lookups.

```json
{
  "servers": {
    "PROD-SERVER-01": {
      "serial_number": "MXQ1234567",
      "display_name": "Production Server 01",
      "ilo_ip": "192.168.1.101",
      "oneview_name": "PROD-SERVER-01.ad.example.com",
      "rack": "Rack-A",
      "environment": "production"
    }
  }
}
```

---

<a name="connection_hostsjson"></a>

## connection_hosts.json

Maps each environment to its SCOM management server and OneView appliance.

```json
{
  "environments": {
    "Test": {
      "scom": { "management_server": "VR-OPM19T1-7382.ad.example.com", "group_id": "TEST-SERVERS-GROUP", "environment": "test" },
      "oneview": { "appliance": "oneview-test.ad.example.com", "scope_name": "Test_Cluster_01" }
    },
    "Prod": {
      "scom": { "management_server": "VR-OPM19P1-7382.ad.example.com", "group_id": "PROD-SERVERS-GROUP", "environment": "production" },
      "oneview": { "appliance": "oneview.ad.example.com", "scope_name": "Production_Cluster_01" }
    }
  }
}
```

Host resolution priority: `-ManagementHost` → `$env:MAINTENANCE_HOST` → `connection_hosts.json` (by `-Environment`).

---

<a name="scom_configjson"></a>

## scom_config.json

```json
{
  "scom": {
    "use_winrm": true,
    "winrm": {
      "transport": "ntlm",
      "username_env": "SCOM_ADMIN_USER",
      "password_env": "SCOM_ADMIN_PASSWORD",
      "timeout_seconds": 300
    },
    "credentials": {
      "username_env": "SCOM_ADMIN_USER",
      "password_env": "SCOM_ADMIN_PASSWORD"
    },
    "maintenance_settings": {
      "default_duration_hours": 4,
      "comment_prefix": "iRequest Maintenance: ",
      "suppress_alerts": true,
      "health_state_reset": "green"
    },
    "management_servers": {
      "2019": {
        "test": { "group": "TEST-GROUP", "servers": ["scom-t1.ad.example.com"] },
        "production": { "group": "PROD-GROUP", "servers": ["scom-p1.ad.example.com"] }
      }
    }
  }
}
```

- `use_winrm: true` connects via WinRM; `false` uses the local `OperationsManager` module.
- Credentials are read from the named environment variables (never from the file).

---

<a name="oneview_configjson"></a>

## oneview_config.json

```json
{
  "oneview": {
    "appliance": "oneview.example.com",
    "module_name": "HPEOneView.1000",
    "use_winrm": false,
    "winrm": { "server": "oneview.example.com" },
    "credentials": {
      "username_env": "ONEVIEW_USER",
      "password_env": "ONEVIEW_PASSWORD"
    }
  }
}
```

- `module_name` must be a valid `HPEOneView.<version>` module (e.g. `HPEOneView.1000` for OneView 10.00).
- Credentials are supplied at runtime via `-OneViewUser`/`-OneViewPassword` or the env vars above.

---

<a name="configmgr_configjson"></a>

## configmgr_config.json

Example/mock data only. In real builds these values are passed as runtime parameters to `Start-PhysicalServerBuild` / `New-IsoBuild`: `-SiteCode`, `-ManagementPoint`, `-DistributionPoint`, `-SiteServer`, `-BootImageName`, `-TaskSequenceName`, `-RepoBaseUrl`.

```json
{
  "configmgr": {
    "site_code": "P01",
    "management_point": "mp01.ad.example.com",
    "distribution_points": ["dp01.ad.example.com"],
    "site_server": "cm01.ad.example.com",
    "boot_image_name": "WinPE x64 - HPE",
    "task_sequence_name_prefix": "TS - WinSrv2025 - HPE",
    "media_password_env": "CM_MEDIA_PASSWORD",
    "output_path": "\\\\fileserver\\osdmedia\\"
  }
}
```

---

<a name="hpe_firmware_drivers_nov2025json"></a>

## hpe_firmware_drivers_nov2025.json

HPE Smart Update Tools (SUT) repository and component manifest.

```json
{
  "firmware_drivers_version": "November 2025",
  "release_date": "2025-11-15",
  "hpe_repository_url": "https://downloads.hpe.com/repo/nov2025/",
  "spp_iso": "HPE-Service-Pack-ProLiant-2025.11.0.iso",
  "components": {
    "gen10_plus": {
      "firmware": [
        { "component": "HPE_BIOS", "version": "2.80" },
        { "component": "HPE_ILO5", "version": "2.70" }
      ],
      "drivers": [
        { "component": "HPE_Network_Adapter", "version": "1.10.0" }
      ]
    }
  },
  "spp_iso_checksum": "a1b2c3d4...",
  "download_credentials": {
    "username": "${HPE_DOWNLOAD_USER}",
    "password": "${HPE_DOWNLOAD_PASS}"
  }
}
```

`${VAR}` placeholders are replaced at runtime from environment variables (`HPE_DOWNLOAD_USER`, `HPE_DOWNLOAD_PASS`).

---

<a name="windows_patchesjson"></a>

## windows_patches.json

Security update set applied via DISM offline patching.

```json
{
  "patch_set": "November 2025 Security Updates",
  "base_os": "Windows Server 2022/2025",
  "release_date": "2025-11-15",
  "patches": [
    {
      "kb_number": "KB5041234",
      "severity": "Critical",
      "cve_ids": ["CVE-2025-12345"],
      "description": "Security update for Windows Kernel",
      "date_released": "2025-11-12",
      "applicable_versions": ["Windows Server 2022", "Windows Server 2025"]
    }
  ],
  "install_order": ["KB5041234"],
  "reboot_required": true,
  "offline_install": true
}
```

---

<a name="request_typesjson"></a>

## request_types.json

Authoritative map of automation request types to PowerShell handlers and CI stages. Consumed by the orchestrator (`Start-AutomationOrchestrator`) and CI.

```json
{
  "request_types": {
    "build_iso":              { "powershell_handler": "New-IsoBuild",              "ci_stage": "all" },
    "update_firmware":        { "powershell_handler": "Update-Firmware",          "ci_stage": "firmware" },
    "patch_windows":          { "powershell_handler": "Invoke-WindowsSecurityUpdate", "ci_stage": "windows" },
    "deploy":                 { "powershell_handler": "Invoke-IsoDeploy",          "ci_stage": "deploy" },
    "monitor":                { "powershell_handler": "Start-InstallMonitor",     "ci_stage": null },
    "maintenance_enable":     { "powershell_handler": "Set-MaintenanceMode",      "ci_stage": null },
    "maintenance_disable":    { "powershell_handler": "Set-MaintenanceMode",      "ci_stage": null },
    "maintenance_validate":   { "powershell_handler": "Set-MaintenanceMode",      "ci_stage": null },
    "opsramp_report":         { "powershell_handler": "Invoke-OpsRampClient",     "ci_stage": "scan" },
    "generate_uuid":          { "powershell_handler": "New-Uuid",                 "ci_stage": null },
    "connectivity_check":     { "powershell_handler": "Test-ServerConnectivity",  "ci_stage": null },
    "gitlab_maintenance":     { "powershell_handler": "Invoke-GitLabMaintenanceTrigger", "ci_stage": null },
    "physical_server_build":  { "powershell_handler": "Start-PhysicalServerBuild","ci_stage": "all" },
    "query_oneview_server":   { "powershell_handler": "Get-OneViewServerTarget",  "ci_stage": null },
    "oneview_connection_status": { "powershell_handler": "Get-OneViewConnectionStatus", "ci_stage": null },
    "oneview_server_list":    { "powershell_handler": "Get-OneViewServerList",    "ci_stage": null },
    "prebuild_validation":    { "powershell_handler": "Test-PreBuildValidation",  "ci_stage": null },
    "postbuild_validation":   { "powershell_handler": "Test-PostBuildValidation", "ci_stage": null },
    "publish_iso":            { "powershell_handler": "Publish-BootIso",          "ci_stage": "deploy" },
    "ilo_redfish_mount":      { "powershell_handler": "Invoke-IloRedfish",        "ci_stage": "deploy" }
  }
}
```

> The Windows-security handler is `Invoke-WindowsSecurityUpdate` — the exported cmdlet. (The source file is `Update-WindowsSecurity.ps1`.)

---

<a name="email_distribution_listsjson"></a>

## email_distribution_lists.json

```json
{
  "email": {
    "smtp_server": "smtp.example.com",
    "smtp_port": 587,
    "use_tls": true,
    "username_env": "SMTP_USER",
    "password_env": "SMTP_PASSWORD",
    "from_address": "maintenance-bot@example.com",
    "distribution_lists": {
      "maintenance_enabled": ["infrastructure-alerts@example.com"],
      "maintenance_disabled": ["infrastructure-alerts@example.com"],
      "failures": ["ops-alert@example.com"],
      "audit": ["audit-team@example.com"]
    }
  }
}
```

- Set `username_env`/`password_env` only when SMTP auth is required; omit for open relays.
- `maintenance_distribution_list.txt` at the repo root overrides `maintenance_enabled` / `maintenance_disabled`.

---

<a name="opsramp_configjson"></a>

## opsramp_config.json

```json
{
  "opsramp_api": {
    "base_url": "https://api.opsramp.com",
    "version": "v2",
    "auth_endpoint": "/oauth/token"
  },
  "credentials": {
    "client_id": "${OPSRAMP_CLIENT_ID}",
    "client_secret": "${OPSRAMP_CLIENT_SECRET}",
    "tenant_id": "${OPSRAMP_TENANT_ID}"
  },
  "integration": {
    "send_metrics": true,
    "send_alerts": true,
    "send_events": true
  }
}
```

---

<a name="environment-variable-cheat-sheet"></a>

## Environment Variable Cheat Sheet

```bash
# HPE repository access
export HPE_DOWNLOAD_USER="xxx"
export HPE_DOWNLOAD_PASS="xxx"

# iLO credentials (global; per-server override: ILO_USER_<SERVER>)
export ILO_USER="Administrator"
export ILO_PASSWORD="xxx"

# SCOM
export SCOM_ADMIN_USER="domain\\admin"
export SCOM_ADMIN_PASSWORD="xxx"

# OneView
export ONEVIEW_USER="ov_admin"
export ONEVIEW_PASSWORD="xxx"

# SMTP (if auth required)
export SMTP_USER="smtp_user"
export SMTP_PASSWORD="smtp_pass"

# OpsRamp
export OPSRAMP_CLIENT_ID="xxx"
export OPSRAMP_CLIENT_SECRET="xxx"
export OPSRAMP_TENANT_ID="xxx"
```

Store these in a `.env` file (gitignored) and load it before running commands.
