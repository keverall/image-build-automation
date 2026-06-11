# Maintenance Mode Testing Guide

## Overview

This document provides comprehensive testing information for the maintenance mode scripts, including the new environment-based host selection and credential management features.

## Test Files

| File | Purpose | Lines |
|------|---------|-------|
| `Set-MaintenanceMode.Environment.Tests.ps1` | New environment & parameter tests | ~400 |
| `Set-MaintenanceMode.Unit.Tests.ps1` | Unit tests for existing functionality | Existing |
| `Set-MaintenanceMode.Enable.Tests.ps1` | Enable action tests | Existing |
| `Set-MaintenanceMode.Disable.Tests.ps1` | Disable action tests | Existing |
| `Set-MaintenanceMode.Validation.Tests.ps1` | Validation tests | Existing |

## Test Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `validate-maintenance-config.ps1` | Validate configuration setup | `pwsh scripts/validate-maintenance-config.ps1 -Environment Test` |
| `run-maintenance-tests.ps1` | Run test suites | `pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru` |
| `test-maintenance-connection.ps1` | Interactive connection testing | `pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom` |

## Test Coverage Areas

### 1. Environment Parameter Tests ✅

**What's tested:**
- Accepts `Test` environment
- Accepts `Prod` environment
- Rejects invalid environment values
- Falls back to `$env:ENVIRONMENT` when parameter not specified
- Defaults to `Prod` when no environment set

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example command:**
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -DryRun
```

### 2. Host Override Tests ✅

**What's tested:**
- `-ManagementHost` parameter acceptance
- Environment variable override (`$env:MAINTENANCE_HOST`)
- Priority chain: parameter > env var > config file

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example commands:**
```powershell
# Parameter override
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ManagementHost 'backup-scom.local' `
    -DryRun

# Environment variable override
$env:MAINTENANCE_HOST = 'override-scom.local'
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -DryRun
```

### 3. Credential Parameter Tests ✅

**What's tested:**
- `-Username` parameter acceptance
- Credential resolution priority chain
- Environment variable credentials
- Interactive prompt fallback

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example command:**
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Username 'test_admin' `
    -DryRun
```

### 4. Date/Time Format Tests ✅

**What's tested:**
- Relative time: `+Xhours`, `+Xminutes`, `+Xdays`, `+Xseconds`
- Absolute time: `YYYY-MM-DD HH:MM`, ISO 8601 format
- Mixed formats: relative start + absolute end
- `now` keyword

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example commands:**
```powershell
# Relative time
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -DryRun

# Absolute time
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00' `
    -DryRun

# ISO 8601
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11T22:00:00' `
    -End '2026-06-12T02:00:00' `
    -DryRun
```

### 5. Connection Validation Tests ✅

**What's tested:**
- SCOM connection pre-flight checks
- OneView connection pre-flight checks
- Dry-run mode skips validation
- Clear error messages on failure

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example command:**
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -DryRun
```

### 6. Combined Parameter Tests ✅

**What's tested:**
- Multiple new parameters together
- Interaction between environment and host override
- All time formats with environment selection

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example command:**
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ManagementHost 'custom-scom.local' `
    -Username 'admin' `
    -Start 'now' `
    -End '+2hours' `
    -PostDisableWaitSeconds 60 `
    -DryRun
```

### 7. Configuration File Tests ✅

**What's tested:**
- `connection_hosts.json` structure validation
- Test environment configuration
- Prod environment configuration
- Required fields presence

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Validation command:**
```powershell
pwsh scripts/validate-maintenance-config.ps1 -Environment Test
```

### 8. Backward Compatibility Tests ✅

**What's tested:**
- Works without new parameters
- Maintains existing behavior
- Old commands still function

**Test file:** `Set-MaintenanceMode.Environment.Tests.ps1`

**Example command:**
```powershell
# Old-style command (no new parameters)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Start 'now' `
    -End '+1hour' `
    -DryRun
```

## Running Tests

### Quick Validation

```powershell
# Validate configuration setup
pwsh scripts/validate-maintenance-config.ps1 -Environment Test
```

### Run Specific Test Suite

```powershell
# Run only environment tests
pwsh scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru

# Run date/time tests
pwsh scripts/run-maintenance-tests.ps1 -TestSuite DateTime -PassThru

# Run backward compatibility tests
pwsh scripts/run-maintenance-tests.ps1 -TestSuite BackwardCompat -PassThru
```

### Run All Tests

```powershell
# Run complete test suite
pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru
```

### Interactive Testing

```powershell
# Test SCOM connection in Test environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Test -Mode scom -DryRun

# Test OneView connection in Prod environment
pwsh scripts/test-maintenance-connection.ps1 -Environment Prod -Mode oneview -DryRun
```

## Test Results Interpretation

### Success Indicators

✅ Green checkmarks in output  
✅ `Success: true` in result objects  
✅ No error messages  
✅ Per-object status shows success  

### Failure Indicators

❌ Red X marks  
❌ `Success: false` with error message  
❌ NACK reasons in failed objects  
❌ Connection validation errors  

### Common Test Failures

| Failure | Cause | Solution |
|---------|-------|----------|
| "SCOM host not configured" | Missing environment config | Add to `connection_hosts.json` or set env var |
| "Missing credentials" | No credentials provided | Set env vars or use interactive mode |
| "Failed to connect" | Network/credential issue | Check connectivity and credentials |
| "Invalid environment" | Wrong parameter value | Use `Test` or `Prod` only |

## Manual Testing Checklist

Before deploying to production, manually test:

- [ ] **Configuration files exist and are valid**
  ```powershell
  pwsh scripts/validate-maintenance-config.ps1 -Environment Test
  ```

- [ ] **Environment parameter works**
  ```powershell
  Set-MaintenanceMode -Action validate -TargetId TEST-01 -Mode scom -Environment Test
  ```

- [ ] **Host override works**
  ```powershell
  Set-MaintenanceMode -Action validate -TargetId TEST-01 -Mode scom -ManagementHost custom.local
  ```

- [ ] **Relative time formats work**
  ```powershell
  Set-MaintenanceMode -Action enable -TargetId TEST-01 -Mode scom -Start now -End +1hour
  ```

- [ ] **Absolute time formats work**
  ```powershell
  Set-MaintenanceMode -Action enable -TargetId TEST-01 -Mode scom -Start '2026-06-11 22:00' -End '2026-06-12 02:00'
  ```

- [ ] **Connection validation works**
  ```powershell
  Set-MaintenanceMode -Action validate -TargetId TEST-01 -Mode scom -Environment Test
  ```

- [ ] **Backward compatibility maintained**
  ```powershell
  Set-MaintenanceMode -Action validate -TargetId PROD-01 -Mode scom
  ```

- [ ] **JSON output includes new fields**
  ```powershell
  Set-MaintenanceMode -Action validate -TargetId TEST-01 -Mode scom -Environment Test -Json
  ```

## Automated Testing (CI/CD)

Add to your Jenkins/GitLab pipeline:

```groovy
stage('Test Maintenance Mode') {
    steps {
        script {
            // Validate configuration
            sh 'pwsh scripts/validate-maintenance-config.ps1 -Environment Test'
            
            // Run unit tests
            sh 'pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru'
            
            // Integration test (dry-run)
            sh '''
            export ENVIRONMENT=Test
            pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 \\
                -Action validate \\
                -TargetId TEST-CLUSTER-01 \\
                -Mode scom \\
                -DryRun
            '''
        }
    }
}
```

## Troubleshooting Test Failures

### Issue: Tests fail with "Module not found"

**Solution:**
```powershell
# Ensure module path is correct
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
```

### Issue: Environment tests fail

**Solution:**
```powershell
# Verify connection_hosts.json exists
Test-Path configs/connection_hosts.json

# Verify environment structure
(Import-JsonConfig configs/connection_hosts.json).environments.Keys
```

### Issue: Date/time parsing fails

**Solution:**
```powershell
# Use standard format
-Start '2026-06-11 22:00' -End '2026-06-12 02:00'

# Or relative format
-Start 'now' -End '+2hours'
```

## Next Steps After Testing

1. ✅ All tests pass locally
2. ✅ Manual validation completed
3. ✅ Documentation reviewed
4. ✅ Peer review conducted
5. ✅ Deploy to staging environment
6. ✅ Integration testing with real SCOM/OneView
7. ✅ Production deployment

## Additional Resources

- **Implementation details:** `IMPLEMENTATION_SUMMARY.md`
- **Quick reference:** `docs/QUICK_REFERENCE.md`
- **Full documentation:** `docs/maintenance-mode-environment-config.md`
- **Command examples:** `docs/maint-mode-initial-testing.md`
