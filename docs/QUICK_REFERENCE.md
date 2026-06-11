# Maintenance Mode - Quick Reference Card

## New Parameters (All Optional)

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-Environment` | Test\|Prod | Select environment for host resolution | `-Environment Prod` |
| `-ScomHost` | string | Override SCOM management server | `-ScomHost scom-backup.local` |
| `-OneViewHost` | string | Override OneView appliance | `-OneViewHost ov-test.local` |
| `-Username` | string | Direct username (testing only) | `-Username admin` |

## Credential Setup (Choose One Method)

### Method 1: Environment Variables (Recommended for Automation)
```bash
export ENVIRONMENT=Prod
export SCOM_ADMIN_USER=domain\admin
export SCOM_ADMIN_PASSWORD=secure_password
export ONEVIEW_USER=admin
export ONEVIEW_PASSWORD=password
```

### Method 2: .env File (Development/Testing)
```bash
# Copy template
cp .env.example .env

# Edit .env with your credentials
nano .env

# Load in PowerShell
. ./.env
```

### Method 3: Interactive Prompt (Manual Testing)
```powershell
# Don't set credentials - script will prompt you
Set-MaintenanceMode -Action validate -TargetId TEST-01 -Mode scom -Environment Test
# Will ask for username and password interactively
```

## Common Scenarios

### Scenario 1: Production Maintenance (Automated)
```powershell
$env:ENVIRONMENT = "Prod"
$env:SCOM_ADMIN_USER = "svc_scom_admin"
$env:SCOM_ADMIN_PASSWORD = "cyberark_retrieved_password"

Set-MaintenanceMode `
    -Action enable `
    -TargetId "PROD-CLUSTER-01" `
    -Mode scom `
    -Start "2026-06-11 22:00" `
    -End "2026-06-12 02:00"
```

### Scenario 2: Test Environment with Override
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId "TEST-CLUSTER-01" `
    -Mode scom `
    -Environment Test `
    -ScomHost "scom-test-backup.local"
```

### Scenario 3: Validate Configuration
```powershell
# Test connection without making changes
Set-MaintenanceMode `
    -Action validate `
    -TargetId "PROD-CLUSTER-01" `
    -Mode scom `
    -Environment Prod
```

### Scenario 4: Dry Run (See What Would Happen)
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId "PROD-CLUSTER-01" `
    -Mode scom `
    -Environment Prod `
    -DryRun
```

### Scenario 5: OneView Server Maintenance
```powershell
Set-MaintenanceMode `
    -Action enable `
    -TargetId "server01.ad.aib.pri" `
    -Mode oneview `
    -Environment Prod
```

## Host Resolution Priority

**For SCOM:**
1. `-ScomHost` parameter
2. `$env:SCOM_OVERRIDE_HOST`
3. `$env:SCOM_HOST`
4. `connection_hosts.json` → Prod/Test config
5. ❌ Error if not found

**For OneView:**
1. `-OneViewHost` parameter
2. `$env:ONEVIEW_OVERRIDE_HOST`
3. `$env:ONEVIEW_HOST`
4. `connection_hosts.json` → Prod/Test config
5. ❌ Error if not found

## Troubleshooting Quick Fixes

| Error | Solution |
|-------|----------|
| "SCOM host not configured" | Set `$env:SCOM_HOST` or add to `connection_hosts.json` |
| "Missing credentials: username" | Set env vars or run interactively |
| "Failed to connect to SCOM" | Check network, firewall, credentials |
| "Environment 'X' not found" | Use `Test` or `Prod` only |

## Config Files Location

| File | Path | Purpose |
|------|------|---------|
| Connection Hosts | `configs/connection_hosts.json` | Environment-specific hosts |
| Credentials Template | `.env` | Template for env vars |
| SCOM Config | `configs/scom_config.working.json` | SCOM settings (fallback) |
| OneView Config | `configs/oneview_config.working.json` | OneView settings (fallback) |

## Quick Commands

```powershell
# Load module
Import-Module ./src/powershell/Automation/Automation.psm1

# List available environments
(Import-JsonConfig configs/connection_hosts.json).environments.Keys

# Test connection
pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom -DryRun

# View current environment
Write-Host "Current: $env:ENVIRONMENT"
```

## Security Reminders

✅ **DO:** Use environment variables or CyberArk  
✅ **DO:** Use `-DryRun` to test first  
✅ **DO:** Check audit logs after operations  

❌ **DON'T:** Hardcode passwords in scripts  
❌ **DON'T:** Commit `.env` with real passwords  
❌ **DON'T:** Skip connection validation  

## Need Help?

- Full docs: `docs/maintenance-mode-environment-config.md`
- Implementation details: `IMPLEMENTATION_SUMMARY.md`
- Test script: `scripts/test-maintenance-connection.ps1`
