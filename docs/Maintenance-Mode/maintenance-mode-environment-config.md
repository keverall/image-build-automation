# Maintenance Mode - Environment-Based Connection Configuration

<a id="top"></a>
## Table of Contents

- [Overview](#overview)
- [New Parameters](#new-parameters)
  - [Set-MaintenanceMode Function](#set-maintenancemode-function)
  - [New Parameters Explained](#new-parameters-explained)
- [Configuration Files](#configuration-files)
  - [1. connection_hosts.json](#1-connection_hostsjson)
  - [2. clusters_catalogue.json](#2-clusters_cataloguejson)
  - [3. servers_catalogue.oneview.json](#3-servers_catalogueoneviewjson)
  - [4. .env File](#4-env-file)
- [Credential Resolution Order](#credential-resolution-order)
- [Host Resolution Order](#host-resolution-order)
  - [Set-MaintenanceMode](#set-maintenancemode)
  - [Test-ServerConnectivity](#test-serverconnectivity)
- [Connection Validation](#connection-validation)
- [Usage Examples](#usage-examples)
  - [Example 1: Use environment config (recommended)](#example-1-use-environment-config-recommended)
  - [Example 2: Override host for specific environment](#example-2-override-host-for-specific-environment)
  - [Example 3: Test mode with interactive credentials](#example-3-test-mode-with-interactive-credentials)
  - [Example 4: Using .env file](#example-4-using-env-file)
  - [Example 5: Automated/jenkins usage](#example-5-automatedjenkins-usage)
- [GDPR/EMIR Banking Environment Compliance](#gdpremir-banking-environment-compliance)
  - [Security Controls Implemented](#security-controls-implemented)
  - [Additional Controls Required for Production](#additional-controls-required-for-production)
- [Testing](#testing)
  - [Run Connection Test](#run-connection-test)
  - [Test-ServerConnectivity - JsonConfig Parameter](#test-serverconnectivity---jsonconfig-parameter)
  - [Run Connection Test (Legacy Script)](#run-connection-test-legacy-script)
  - [Validate Configuration](#validate-configuration)
- [Troubleshooting](#troubleshooting)
  - [Issue: "SCOM host not configured for environment 'Test'"](#issue-scom-host-not-configured-for-environment-test)
  - [Issue: "Missing credentials: username, password"](#issue-missing-credentials-username-password)
  - [Issue: "Failed to connect to SCOM management server"](#issue-failed-to-connect-to-scom-management-server)
  - [Issue: Interactive prompt doesn't appear](#issue-interactive-prompt-doesnt-appear)
- [Migration Guide](#migration-guide)
  - [From Old Config Format](#from-old-config-format)
- [Future Enhancements](#future-enhancements)


<a name="overview"></a>
## Overview

The maintenance mode scripts now support environment-based host selection with optional credential overrides. This allows you to manage different environments (Test, Prod) with separate SCOM and OneView appliances while maintaining security in regulated banking environments.

<a name="new-parameters"></a>
## New Parameters

<a name="set-maintenancemode-function"></a>
### Set-MaintenanceMode Function

```powershell
Set-MaintenanceMode `
    -Action <enable|disable|validate> `
    -TargetId <cluster-id> `
    -Mode <scom|oneview> `
    [-Environment <Test|Prod>] `
    [-ManagementHost <hostname>] `
    [-Username <username>] `
    [-PostDisableWaitSeconds <seconds>] `
    [-ConfigDir <path>] `
    [-Start <datetime>] `
    [-End <datetime>] `
    [-DryRun] `
    [-NoSchedule]
```

<a name="new-parameters-explained"></a>
### New Parameters Explained

- **`-Environment`**: Specifies which environment to connect to (Test or Prod). If not provided, reads from `ENVIRONMENT` environment variable, defaults to `Prod`.
- **`-ManagementHost`**: Optional override for management server/appliance hostname/IP. Works for both SCOM and OneView modes.
- **`-Username`**: Optional direct username parameter (for testing only; not recommended for production).

<a name="configuration-files"></a>
## Configuration Files

<a name="1-connection_hostsjson"></a>
### 1. connection_hosts.json

Located at: `configs/connection_hosts.json`

This file defines environment-specific connection settings:

```json
{
  "environments": {
    "Test": {
      "scom": {
        "management_server": "VR-OPM19T1-7382.ad.example.com",
        "group_id": "TEST-SERVERS-GROUP",
        "environment": "test"
      },
      "oneview": {
        "appliance": "oneview-test.ad.example.com",
        "scope_name": "Test_Cluster_01"
      }
    },
    "Prod": {
      "scom": {
        "management_server": "VR-OPM19P1-7382.ad.example.com",
        "group_id": "PROD-SERVERS-GROUP",
        "environment": "production"
      },
      "oneview": {
        "appliance": "oneview.ad.example.com",
        "scope_name": "Production_Cluster_01"
      }
    }
  }
}
```

**To add new environments:** Copy an existing environment block and modify the hostnames/group IDs.

<a name="2-clusters_cataloguejson"></a>
### 2. clusters_catalogue.json

Located at: `configs/clusters_catalogue.json`

Defines cluster IDs, server lists, and group mappings for maintenance operations:

```json
{
  "clusters": {
    "CLU-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "servers": ["server01.ad.example.com", "server02.ad.example.com"],
      "scom_group": "SCOM-CLUSTER-01-GROUP",
      "environment": "production"
    }
  }
}
```

**To add/modify clusters:**
- Edit `configs/clusters_catalogue.json`
- Cluster IDs use `CLU-` prefix format
- List all servers belonging to the cluster
- Specify the SCOM group name for SCOM mode

<a name="3-servers_catalogueoneviewjson"></a>
### 3. servers_catalogue.oneview.json

Located at: `configs/servers_catalogue.oneview.json`

Defines OneView server definitions with serial numbers:

```json
{
  "servers": {
    "server01": {
      "display_name": "Server 01",
      "oneview_name": "server01.ad.example.com",
      "serial_number": "ABC123XYZ"
    }
  }
}
```

**To add/modify servers:**
- Edit `configs/servers_catalogue.oneview.json`
- Include serial numbers for OneView lookups
- Map server keys to OneView display names

<a name="4-env-file"></a>
### 4. .env File

Located at: `.env` (project root)

Template credentials file (copy and fill in):

```bash
# Environment: Test or Prod
ENVIRONMENT=Prod

# SCOM Connection Settings
SCOM_ADMIN_USER=domain\adminuser
SCOM_ADMIN_PASSWORD=your_password_here

# OneView Connection Settings
ONEVIEW_USER=oneview_admin
ONEVIEW_PASSWORD=your_password_here

# Management Host Override (optional - overrides both SCOM and OneView)
MAINTENANCE_HOST=
```

**Security Note:** Never commit `.env` with real passwords. Add to `.gitignore`.

<a name="credential-resolution-order"></a>
## Credential Resolution Order

The script resolves credentials in this priority order:

1. **Command-line parameters** (`-Username`, etc.) - for testing only
2. **Environment variables** (`SCOM_ADMIN_USER`, `ONEVIEW_USER`, etc.)
3. **Interactive prompt** (if running interactively and credentials not set)
4. **Error** (if automated mode and credentials missing)

For passwords:
1. **Environment variables** (`SCOM_ADMIN_PASSWORD`, `ONEVIEW_PASSWORD`)
2. **Interactive secure prompt** (masked input)
3. **Error**

<a name="host-resolution-order"></a>
## Host Resolution Order

<a name="set-maintenancemode"></a>
### Set-MaintenanceMode

For SCOM and OneView in `Set-MaintenanceMode`:
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. `connection_hosts.json` based on `-Environment` parameter
4. Error if not configured

<a name="test-serverconnectivity"></a>
### Test-ServerConnectivity

For SCOM and OneView in `Test-ServerConnectivity`:

**With `-JsonConfig` switch:**
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. `connection_hosts.json` based on `-Environment` parameter
4. Error if not configured

**Without `-JsonConfig` switch (default):**
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. Interactive prompt for host (if `AUTOMATED_MODE` is not `true`)
4. Error if not configured

<a name="connection-validation"></a>
## Connection Validation

Before executing maintenance mode operations, the script:

1. Resolves the target host based on environment/parameters
2. Tests connectivity to SCOM/OneView
3. Returns error if connection fails (unless `-DryRun`)

This prevents silent failures and provides clear error messages.

<a name="usage-examples"></a>
## Usage Examples

<a name="example-1-use-environment-config-recommended"></a>
### Example 1: Use environment config (recommended)

```powershell
# Set environment variable
$env:ENVIRONMENT = "Prod"
$env:SCOM_ADMIN_USER = "domain\adminuser"
$env:SCOM_ADMIN_PASSWORD = "secure_password"

# Execute
Set-MaintenanceMode -Action enable -TargetId "CLU-CLUSTER-01" -Mode scom
```

<a name="example-2-override-host-for-specific-environment"></a>
### Example 2: Override host for specific environment

```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId "CLU-CLUSTER-01" `
    -Mode scom `
    -Environment Prod `
    -ManagementHost "backup-scom.example.com"
```

<a name="example-3-test-mode-with-interactive-credentials"></a>
### Example 3: Test mode with interactive credentials

```powershell
# Don't set credentials in env vars - script will prompt
Set-MaintenanceMode `
    -Action validate `
    -TargetId "TEST-CLUSTER-01" `
    -Mode scom `
    -Environment Test
```

<a name="example-4-using-env-file"></a>
### Example 4: Using .env file

```bash
# In bash/pwsh session
source .env  # or load via script

pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom
```

<a name="example-5-automatedjenkins-usage"></a>
### Example 5: Automated/jenkins usage

```groovy
// Jenkins pipeline
withCredentials([
    usernamePassword(credentialsId: 'scom-prod', usernameVariable: 'SCOM_ADMIN_USER', passwordVariable: 'SCOM_ADMIN_PASSWORD')
]) {
    sh '''
    export ENVIRONMENT=Prod
    pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 \\
        -Action enable \\
        -TargetId CLU-CLUSTER-01 \\
        -Mode scom
    '''
}
```

<a name="gdpremir-banking-environment-compliance"></a>
## GDPR/EMIR Banking Environment Compliance

<a name="security-controls-implemented"></a>
### Security Controls Implemented

✅ **No hardcoded credentials** - All credentials via env vars or secure prompts  
✅ **Environment isolation** - Separate hosts for Test/Prod  
✅ **Audit logging** - All connections logged with timestamps  
✅ **Connection validation** - Pre-flight checks prevent accidental operations  
✅ **Parameter overrides** - Flexibility for emergency scenarios  

<a name="additional-controls-required-for-production"></a>
### Additional Controls Required for Production

For EU GDPR/EMIR regulated environments, consider:

1. **CyberArk Integration**: Replace env vars with CyberArk CLI lookups
   ```powershell
   # Instead of env vars, use:
   $cred = Get-CyberArkCredential -Safe "SCOM-Prod" -Object "AdminUser"
   ```

2. **Network Segmentation**: Ensure jump box has restricted access to SCOM/OneView
   
3. **Just-In-Time Access**: Use PAM solutions for time-limited credentials

4. **Certificate-Based Auth**: Replace password auth with client certificates where supported

5. **Audit Trail Forwarding**: Send logs to SIEM for compliance monitoring

<a name="testing"></a>
## Testing

<a name="run-connection-test"></a>
### Run Connection Test

```powershell
# Test SCOM connection in Test environment using config file
pwsh scripts/test-connectivity.ps1 -Mode scom -JsonConfig -Environment Test

# Test OneView connection in Prod environment using config file
pwsh scripts/test-connectivity.ps1 -Mode oneview -JsonConfig -Environment Prod

# Test with explicit host (no config lookup)
pwsh scripts/test-connectivity.ps1 -Mode scom -ManagementHost 'scom-test.local'

# Test with interactive prompt (no -JsonConfig, no -ManagementHost)
pwsh scripts/test-connectivity.ps1 -Mode scom
# Script will prompt: "Enter SCOM management host (or press Enter to cancel):"
```

<a name="test-serverconnectivity---jsonconfig-parameter"></a>
### Test-ServerConnectivity - JsonConfig Parameter

The `Test-ServerConnectivity` function now supports `-JsonConfig` to explicitly use `connection_hosts.json`:

```powershell
# Use connection_hosts.json to resolve host
Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig

# Without -JsonConfig, prompts for host interactively
Test-ServerConnectivity -Mode scom

# Dry run to verify configuration
Test-ServerConnectivity -Mode scom -JsonConfig -DryRun
```

**Host Resolution Order for Test-ServerConnectivity:**

With `-JsonConfig:
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. `connection_hosts.json` based on `-Environment`

Without `-JsonConfig`:
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. Interactive prompt (if not in automated mode)

<a name="run-connection-test-legacy-script"></a>
### Run Connection Test (Legacy Script)

```powershell
# Test SCOM connection in Test environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom -DryRun

# Test OneView connection in Prod environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Prod -Mode oneview -DryRun
```

<a name="validate-configuration"></a>
### Validate Configuration

```powershell
# Check which hosts are configured
Import-JsonConfig configs/connection_hosts.json | ConvertTo-Json

# Test credential resolution
$env:ENVIRONMENT = "Test"
pwsh -Command "& { . src/powershell/Automation/Automation.psm1; Write-Host 'Config loaded successfully' }"
```

<a name="troubleshooting"></a>
## Troubleshooting

<a name="issue-scom-host-not-configured-for-environment-test"></a>
### Issue: "SCOM host not configured for environment 'Test'"

**Solution:** Add Test environment to `connection_hosts.json` or set `$env:MAINTENANCE_HOST` env var.

<a name="issue-missing-credentials-username-password"></a>
### Issue: "Missing credentials: username, password"

**Solution:** Set environment variables or run interactively to be prompted.

<a name="issue-failed-to-connect-to-scom-management-server"></a>
### Issue: "Failed to connect to SCOM management server"

**Check:**
- Network connectivity to management server
- Credentials are correct
- SCOM management group is accessible
- Firewall rules allow WinRM/RPC traffic

<a name="issue-interactive-prompt-doesnt-appear"></a>
### Issue: Interactive prompt doesn't appear

**Cause:** Script detected as automated mode.

**Solution:** Set `AUTOMATED_MODE=false` or provide credentials via env vars.

<a name="migration-guide"></a>
## Migration Guide

<a name="from-old-config-format"></a>
### From Old Config Format

Old: Single host in `scom_config.json`
```json
{
  "scom": {
    "management_server": "VR-OPM19P1-7382.ad.example.com"
  }
}
```

New: Multi-environment in `connection_hosts.json`
```json
{
  "environments": {
    "Prod": {
      "scom": {
        "management_server": "VR-OPM19P1-7382.ad.example.com"
      }
    },
    "Test": {
      "scom": {
        "management_server": "VR-OPM19T1-7382.ad.example.com"
      }
    }
  }
}
```

**Backward Compatibility:** Old config files still work. New `connection_hosts.json` takes precedence when environment parameter is used.

<a name="future-enhancements"></a>
## Future Enhancements

- [ ] Add support for multiple SCOM management groups per environment
- [ ] Implement certificate-based authentication option
- [ ] Add connection pooling for repeated operations
- [ ] Support for Azure Arc-enabled servers
- [ ] Integration with PIM (Privileged Identity Management)
