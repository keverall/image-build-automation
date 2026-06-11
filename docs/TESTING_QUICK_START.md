# Maintenance Mode Testing - Quick Start Guide

## 30-Second Quick Start

```powershell
# Validate your setup
pwsh scripts/validate-maintenance-config.ps1 -Environment Test

# Run environment tests
pwsh scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru

# Try a test command
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -DryRun
```

## Common Test Commands

### Test 1: Basic Validation (Safe - No Changes)
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod
```

### Test 2: Dry Run with New Parameters
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+1hour' `
    -DryRun
```

### Test 3: Host Override
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ManagementHost 'backup-scom.local'
```

### Test 4: Different Time Formats
```powershell
# Relative time
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+2hours' `
    -DryRun

# Absolute time
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00' `
    -DryRun
```

## What Was Added

### New Parameters (All Optional)
- `-Environment Test|Prod` - Select environment
- `-ManagementHost <hostname>` - Override management server/appliance
- `-Username <username>` - Direct username (testing only)

### New Features Tested
✅ Environment-based host selection  
✅ Host override via parameter or env var  
✅ Multiple date/time formats (relative & absolute)  
✅ Connection validation before operations  
✅ Backward compatibility maintained  

### Files You Need
1. **Config:** `configs/connection_hosts.json` (NEW)
2. **Template:** `.env` (NEW - copy and fill in)
3. **Tests:** `tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1` (NEW)
4. **Docs:** `docs/maint-mode-initial-testing.md` (UPDATED)

## Running All Tests

```powershell
# Full test suite with results
pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru
```

## Troubleshooting

**Problem:** "SCOM host not configured"  
**Solution:** Set `$env:ENVIRONMENT` or add to `connection_hosts.json`

**Problem:** "Missing credentials"  
**Solution:** Set env vars or run interactively (script will prompt)

**Problem:** Tests fail  
**Solution:** Run `pwsh scripts/validate-maintenance-config.ps1 -Environment Test`

## More Information

- **Full testing guide:** `docs/MAINTENANCE_MODE_TESTING.md`
- **Command reference:** `docs/maint-mode-initial-testing.md`
- **Implementation details:** `IMPLEMENTATION_SUMMARY.md`
- **Quick reference:** `docs/QUICK_REFERENCE.md`

## Safety Notes

✅ **DryRun is safe** - No changes made to systems  
✅ **Validate is safe** - Only checks configuration  
⚠️ **Enable/Disable without DryRun** - WILL make changes  

Always test with `-DryRun` first!
