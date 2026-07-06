# OneView Maintenance Mode - Authentication & Configuration

## Table of Contents

- [Required Secrets (CyberArk Safe: `HPE-OneView`)](#required-secrets-cyberark-safe-hpe-oneview)
- [Configuration Files](#configuration-files)
  - [`configs/oneview_config.json`](#configsoneview_configjson)
  - [`configs/oneview_servers_catalogue.json`](#configsoneview_servers_cataloguejson)
- [GitLab CI Integration](#gitlab-ci-integration)
  - [Required GitLab CI/CD Variables (Masked)](#required-gitlab-cicd-variables-masked)
  - [How it works](#how-it-works)
  - [Manual Testing](#manual-testing)
- [Setup Script](#setup-script)


Configure `Set-MaintenanceMode.ps1` for HPE OneView hardware-level maintenance mode. OneView manages individual server hardware via iLO - see [DevOps Guide to HPE Terms](../devops-guide-to-HPe-Terms.md) for the distinction between OneView maintenance mode and iLO maintenance mode.

<a name="required-secrets-cyberark-safe-hpe-oneview"></a>
## Required Secrets (CyberArk Safe: `HPE-OneView`)

| Environment Variable | Purpose |
|-------------------|---------|
| `ONEVIEW_USER` | OneView appliance admin username |
| `ONEVIEW_PASSWORD` | OneView appliance admin password |

<a name="configuration-files"></a>
## Configuration Files

<a name="configsoneview_configjson"></a>
### `configs/oneview_config.json`

```json
{
  "oneview": {
    "appliance": "oneview.ad.example.com",
    "module_name": "HPEOneView.1000",
    "use_winrm": false,
    "winrm": {
      "server": "oneview.ad.example.com"
    },
    "credentials": {
      "username_env": "ONEVIEW_USER",
      "password_env": "ONEVIEW_PASSWORD"
    }
  }
}
```

<a name="configsoneview_servers_cataloguejson"></a>
### `configs/oneview_servers_catalogue.json`

```json
{
  "servers": {
    "PROD-SERVER-01": {
      "display_name": "Production Server 01",
      "ilo_ip": "192.168.1.101",
      "oneview_name": "PROD-SERVER-01.ad.example.com",
      "rack": "Rack-A",
      "environment": "production"
    },
    "STAGING-SERVER-01": {
      "display_name": "Staging Server 01",
      "ilo_ip": "192.168.2.101",
      "oneview_name": "STAGING-SERVER-01.ad.example.com",
      "rack": "Rack-B",
      "environment": "staging"
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
2. It queries the CyberArk REST API for `ONEVIEW_USER` and `ONEVIEW_PASSWORD`
3. Secrets are exported to `secrets.env` as artifacts
4. Subsequent maintenance jobs source `secrets.env` to set environment variables
5. `Set-MaintenanceMode.ps1` reads these variables via `Get-OneViewCredentials`

<a name="manual-testing"></a>
### Manual Testing

```powershell
# Set variables manually for local testing
$env:ONEVIEW_USER = 'oneview_admin'
$env:ONEVIEW_PASSWORD = 'SecurePassword123!'

# Or run the bootstrap script locally (requires network access to CyberArk)
pwsh -File ./scripts/cyberark-bootstrap.ps1 -CyberArkUrl "https://cyberark-ccp:443/AIMWebService/API/Accounts" -AppId "ci"
```

<a name="setup-script"></a>
## Setup Script

```powershell
# scripts/setup-oneview.ps1
param([string]$ConfigDir = 'configs')

# Import the Automation module
Import-Module (Join-Path $PSScriptRoot 'src/powershell/Automation/Automation.psd1') -Force

# Verify HPE OneView module is available
$ovModules = Get-Module -ListAvailable -Name 'HPEOneView.*' | Select-Object -ExpandProperty Name
if (-not $ovModules) {
    Write-Warning "No HPEOneView.* module found. Install from PowerShell Gallery:"
    Write-Warning "Install-Module HPEOneView.1000 -Scope CurrentUser -AllowClobber -Force"
}
if ($ovModules -and $ovModules.Count -gt 1) {
    Write-Warning "Multiple modules detected: ($($ovModules -join ', '))"
    Write-Warning "Remove old versions: Uninstall-Module HPEOneView.OLD_VERSION -Force"
}

# Test credentials are available
$ovUser = [System.Environment]::GetEnvironmentVariable('ONEVIEW_USER')
$ovPass = [System.Environment]::GetEnvironmentVariable('ONEVIEW_PASSWORD')
if (-not $ovUser -or -not $ovPass) {
    Write-Warning "OneView credentials not found. Ensure CyberArk bootstrap ran or set manually:"
    Write-Warning "`$env:ONEVIEW_USER`n`$env:ONEVIEW_PASSWORD"
}
```

