# Maintenance Mode - Environment-Based Connection Configuration

## Overview

The maintenance mode scripts now support environment-based host selection with optional credential overrides. This allows you to manage different environments (Test, Prod) with separate SCOM and OneView appliances while maintaining security in regulated banking environments.

## New Parameters

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

### New Parameters Explained

- **`-Environment`**: Specifies which environment to connect to (Test or Prod). If not provided, reads from `ENVIRONMENT` environment variable, defaults to `Prod`.
- **`-ManagementHost`**: Optional override for management server/appliance hostname/IP. Works for both SCOM and OneView modes.
- **`-Username`**: Optional direct username parameter (for testing only; not recommended for production).

## Configuration Files

### 1. connection_hosts.json

Located at: `configs/connection_hosts.json`

This file defines environment-specific connection settings:

```json
{
  "environments": {
    "Test": {
      "scom": {
        "management_server": "VR-OPM19T1-7382.ad.aib.pri",
        "group_id": "TEST-SERVERS-GROUP",
        "environment": "test"
      },
      "oneview": {
        "appliance": "oneview-test.ad.aib.pri",
        "scope_name": "Test_Cluster_01"
      }
    },
    "Prod": {
      "scom": {
        "management_server": "VR-OPM19P1-7382.ad.aib.pri",
        "group_id": "PROD-SERVERS-GROUP",
        "environment": "production"
      },
      "oneview": {
        "appliance": "oneview.ad.aib.pri",
        "scope_name": "Production_Cluster_01"
      }
    }
  }
}
```

**To add new environments:** Copy an existing environment block and modify the hostnames/group IDs.

### 2. .env File

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

## Host Resolution Order

For SCOM:
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. `connection_hosts.json` based on `-Environment` parameter
4. Error if not configured

For OneView:
1. `-ManagementHost` parameter
2. `$env:MAINTENANCE_HOST`
3. `connection_hosts.json` based on `-Environment` parameter
4. Error if not configured

## Connection Validation

Before executing maintenance mode operations, the script:

1. Resolves the target host based on environment/parameters
2. Tests connectivity to SCOM/OneView
3. Returns error if connection fails (unless `-DryRun`)

This prevents silent failures and provides clear error messages.

## Usage Examples

### Example 1: Use environment config (recommended)

```powershell
# Set environment variable
$env:ENVIRONMENT = "Prod"
$env:SCOM_ADMIN_USER = "domain\adminuser"
$env:SCOM_ADMIN_PASSWORD = "secure_password"

# Execute
Set-MaintenanceMode -Action enable -TargetId "CLU-CLUSTER-01" -Mode scom
```

### Example 2: Override host for specific environment

```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId "CLU-CLUSTER-01" `
    -Mode scom `
    -Environment Prod `
    -ManagementHost "backup-scom.example.com"
```

### Example 3: Test mode with interactive credentials

```powershell
# Don't set credentials in env vars - script will prompt
Set-MaintenanceMode `
    -Action validate `
    -TargetId "TEST-CLUSTER-01" `
    -Mode scom `
    -Environment Test
```

### Example 4: Using .env file

```bash
# In bash/pwsh session
source .env  # or load via script

pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom
```

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

## GDPR/EMIR Banking Environment Compliance

### Security Controls Implemented

✅ **No hardcoded credentials** - All credentials via env vars or secure prompts  
✅ **Environment isolation** - Separate hosts for Test/Prod  
✅ **Audit logging** - All connections logged with timestamps  
✅ **Connection validation** - Pre-flight checks prevent accidental operations  
✅ **Parameter overrides** - Flexibility for emergency scenarios  

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

## Testing

### Run Connection Test

```powershell
# Test SCOM connection in Test environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom -DryRun

# Test OneView connection in Prod environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Prod -Mode oneview -DryRun
```

### Validate Configuration

```powershell
# Check which hosts are configured
Import-JsonConfig configs/connection_hosts.json | ConvertTo-Json

# Test credential resolution
$env:ENVIRONMENT = "Test"
pwsh -Command "& { . src/powershell/Automation/Automation.psm1; Write-Host 'Config loaded successfully' }"
```

## Troubleshooting

### Issue: "SCOM host not configured for environment 'Test'"

**Solution:** Add Test environment to `connection_hosts.json` or set `$env:MAINTENANCE_HOST` env var.

### Issue: "Missing credentials: username, password"

**Solution:** Set environment variables or run interactively to be prompted.

### Issue: "Failed to connect to SCOM management server"

**Check:**
- Network connectivity to management server
- Credentials are correct
- SCOM management group is accessible
- Firewall rules allow WinRM/RPC traffic

### Issue: Interactive prompt doesn't appear

**Cause:** Script detected as automated mode.

**Solution:** Set `AUTOMATED_MODE=false` or provide credentials via env vars.

## Migration Guide

### From Old Config Format

Old: Single host in `scom_config.json`
```json
{
  "scom": {
    "management_server": "VR-OPM19P1-7382.ad.aib.pri"
  }
}
```

New: Multi-environment in `connection_hosts.json`
```json
{
  "environments": {
    "Prod": {
      "scom": {
        "management_server": "VR-OPM19P1-7382.ad.aib.pri"
      }
    },
    "Test": {
      "scom": {
        "management_server": "VR-OPM19T1-7382.ad.aib.pri"
      }
    }
  }
}
```

**Backward Compatibility:** Old config files still work. New `connection_hosts.json` takes precedence when environment parameter is used.

## Future Enhancements

- [ ] Add support for multiple SCOM management groups per environment
- [ ] Implement certificate-based authentication option
- [ ] Add connection pooling for repeated operations
- [ ] Support for Azure Arc-enabled servers
- [ ] Integration with PIM (Privileged Identity Management)
