# SCOM Maintenance Mode - Authentication & Configuration

<a id="top"></a>
## Table of Contents

- [Required Secrets (CyberArk Safe: `SCOM-2015`)](#required-secrets-cyberark-safe-scom-2015)
- [Configuration Files](#configuration-files)
  - [`configs/scom_config.json`](#configsscom_configjson)
  - [`configs/scom_clusters_catalogue.json`](#configsscom_clusters_cataloguejson)
- [GitLab CI Integration](#gitlab-ci-integration)
  - [Required GitLab CI/CD Variables (Masked)](#required-gitlab-cicd-variables-masked)
  - [How it works](#how-it-works)
  - [Manual Testing](#manual-testing)
- [Setup Script](#setup-script)


Configure `Set-MaintenanceMode.ps1` for SCOM cluster-level maintenance mode. SCOM manages Microsoft Windows cluster objects - all servers and resources nested under the group are put into maintenance mode. See [DevOps Guide to HPE Terms](../devops-guide-to-HPe-Terms.md#top) for the relationship between SCOM, OneView, and iLO.

<a name="required-secrets-cyberark-safe-scom-2015"></a>
## Required Secrets (CyberArk Safe: `SCOM-2015`)

| Environment Variable | Purpose |
|-------------------|---------|
| `SCOM_ADMIN_USER` | SCOM admin username |
| `SCOM_ADMIN_PASSWORD` | SCOM admin password |

<a name="configuration-files"></a>
## Configuration Files

<a name="configsscom_configjson"></a>
### `configs/scom_config.json`

```json
{
  "scom": {
    "management_server": "VR-OPM19P1-7382.ad.example.com",
    "powershell_module": "OperationsManager",
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
    }
  }
}
```

<a name="configsscom_clusters_cataloguejson"></a>
### `configs/scom_clusters_catalogue.json`

```json
{
  "clusters": {
    "CLU-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "scom_group": "SCOM_Prod_Cluster_01",
      "scom_version": "2019",
      "scom_management_server": "VR-OPM19P1-7382.ad.example.com",
      "scom_environment": "production",
      "servers": [
        "prod-server-01.ad.example.com",
        "prod-server-02.ad.example.com",
        "prod-server-03.ad.example.com"
      ],
      "environment": "production"
    }
  }
}
```

<a name="gitlab-ci-integration"></a>
## GitLab CI Integration

In GitLab CI, secrets are fetched automatically via the `cyberark-bootstrap` job before any maintenance operations. 

<a name="required-gitlab-cicd-variables-masked"></a>
### Required GitLab CI/CD Variables (Masked)

| Variable | Description | Example |
|----------|-------------|---------|
| `CYBERARK_CCP_URL` | CyberArk AIM Web Service URL | `https://cyberark-ccp:443/AIMWebService/API/Accounts` |
| `CYBERARK_APP_ID` | Application ID registered in CyberArk | `ci` |

<a name="how-it-works"></a>
### How it works

1. The `cyberark-bootstrap` job runs `scripts/cyberark-bootstrap.ps1`
2. It queries the CyberArk REST API for `SCOM_ADMIN_USER` and `SCOM_ADMIN_PASSWORD`
3. Secrets are exported to `secrets.env` as artifacts
4. Subsequent maintenance jobs source `secrets.env` to set environment variables
5. `Set-MaintenanceMode.ps1` reads these variables via `Get-ScomCredentials`

<a name="manual-testing"></a>
### Manual Testing

```powershell
# Set variables manually for local testing
$env:SCOM_ADMIN_USER = 'scom_admin'
$env:SCOM_ADMIN_PASSWORD = 'SecurePassword123!'

# Or run the bootstrap script locally (requires network access to CyberArk)
pwsh -File ./scripts/cyberark-bootstrap.ps1 -CyberArkUrl "https://cyberark-ccp:443/AIMWebService/API/Accounts" -AppId "ci"
```

<a name="setup-script"></a>
## Setup Script

```powershell
# scripts/setup-scom.ps1
param([string]$ConfigDir = 'configs')

# Import the Automation module
Import-Module (Join-Path $PSScriptRoot 'src/powershell/Automation/Automation.psd1') -Force

# Verify SCOM module is available
if (-not (Get-Module -ListAvailable -Name 'OperationsManager')) {
    Write-Warning "OperationsManager module not found. Import from SCOM server:"
    Write-Warning "Import-Module \\VR-OPM19P1-7382.ad.example.com\share\OperationsManager"
}

# Test credentials are available
$scomUser = [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_USER')
$scomPass = [System.Environment]::GetEnvironmentVariable('SCOM_ADMIN_PASSWORD')
if (-not $scomUser -or -not $scomPass) {
    Write-Warning "SCOM credentials not found. Ensure CyberArk bootstrap ran or set manually:"
    Write-Warning "`$env:SCOM_ADMIN_USER`n`$env:SCOM_ADMIN_PASSWORD"
}
```


