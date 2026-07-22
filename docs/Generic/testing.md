# PowerShell Module Testing Guide (Pester)

<a id="top"></a>
## Table of Contents

- [Overview](#overview)
  - [BDD Keywords](#bdd-keywords)
- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
  - [Run the Complete Test Suite](#run-the-complete-test-suite)
  - [Run via Makefile](#run-via-makefile)
  - [Run via Wrapper Script](#run-via-wrapper-script)
  - [Run a Single Test File](#run-a-single-test-file)
  - [Run by Tag](#run-by-tag)
  - [CI / XML Output & Coverage Reports](#ci-xml-output-and-coverage-reports)
  - [Code Coverage](#code-coverage)
- [Test File Structure](#test-file-structure)
- [Writing a New Test](#writing-a-new-test)
  - [Common Assertions](#common-assertions)
- [Mocking](#mocking)
- [CI Integration](#ci-integration)
- [Troubleshooting](#troubleshooting)
- [See Also](#see-also)
- [Maintenance Mode Testing](#maintenance-mode-testing)
  - [Test Files](#test-files)
  - [Test Scripts](#test-scripts)
  - [Running Maintenance Mode Tests](#running-maintenance-mode-tests)
  - [Test Coverage Areas](#test-coverage-areas)
  - [Interpreting Test Results](#interpreting-test-results)
  - [Manual Testing Checklist](#manual-testing-checklist)
  - [Maintenance Mode Behavior](#maintenance-mode-behavior)
  - [Maintenance Mode Testing Examples](#maintenance-mode-testing-examples)
  - [Per-Object Status Reporting](#per-object-status-reporting)
  - [Safety Warnings](#safety-warnings)
Complete guide to running and maintaining the Pester test suite for the `src/powershell/Automation` module.

---

<a name="overview"></a>
## Overview

The PowerShell module uses **Pester v5+** as its BDD-style testing framework. Tests are colocated with the source under `tests/powershell/`.

**Framework:** [Pester](https://pester.dev/docs/quick-start/) v5.7.1  
**Test runner command:** `Invoke-Pester`  
**Test discovery:** `*.Unit.Tests.ps1`, `*.Tests.ps1` files in `tests/powershell/`  
**Offline support:** All dependencies are bundled under `vendor/modules/`

<a name="bdd-keywords"></a>
### BDD Keywords

| Pester concept | PowerShell equivalent |
|---|---|
| `Describe` | Test suite |
| `Context` | Arrange/Act blocks |
| `It` | Individual assertion |
| `Mock` | Intercept command calls |
| `BeforeAll` / `AfterAll` | Test fixtures |
| `Should` | Assertion |

---

<a name="prerequisites"></a>
## Prerequisites

```powershell
# Install Pester (scoped to current user, no admin required)
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force

# Verify installation
Get-Module Pester -ListAvailable
```

**Minimum supported versions:**

| Runtime | Version |
|---|---|
| Windows PowerShell | 5.1 |
| PowerShell 7 | 7.2+ |
| Pester | 5.7.1 (bundled) |

---

<a name="running-tests"></a>
## Running Tests

<a name="run-the-complete-test-suite"></a>
### Run the Complete Test Suite

```powershell
# Run all Pester tests under tests/powershell/
Invoke-Pester -Path 'tests/powershell' -PassThru

# Verbose output - shows every passing and failing test
Invoke-Pester -Path 'tests/powershell' -PassThru -Show All
```

<a name="run-via-makefile"></a>
### Run via Makefile

```bash
# Run all tests (default, lint + test)
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration

# Run high-priority Set-MaintenanceMode tests (enable/disable/validate)
make maint-mode-tests

# Run lint + tests combined (CI step)
make lint-test
```

<a name="run-via-wrapper-script"></a>
### Run via Wrapper Script

```powershell
# Run all tests with Pester auto-repair
pwsh -File scripts/run-tests.ps1

# Run high-priority maintenance mode tests only
pwsh -File scripts/run-maint-mode-tests.ps1
```

<a name="run-a-single-test-file"></a>
### Run a Single Test File

```powershell
Invoke-Pester -Path 'tests/powershell\Config.Unit.Tests.ps1'
```

<a name="run-by-tag"></a>
### Run by Tag

```powershell
# Run Config + FileIO tests only
Invoke-Pester -Path 'tests/powershell' -Tag @('Config','FileIO') -PassThru

# Exclude integration tests
Invoke-Pester -Path 'tests/powershell' -ExcludeTag @('Integration') -PassThru
```

<a name="ci-xml-output-and-coverage-reports"></a>
### CI / XML Output & Coverage Reports

```powershell
$result = Invoke-Pester -Path 'tests/powershell' -Tag 'Unit' `
            -OutputFile 'powershell-test-results.xml' `
            -OutputFormat NUnitXml `
            -PassThru

Write-Output "Passed: $($result.PassedCount)  Failed: $($result.FailedCount)"
exit $result.FailedCount
```

<a name="code-coverage"></a>
### Code Coverage

Pester generates code coverage data for the PowerShell source modules. By default, CI jobs produce `coverage-results.xml` (in Cobertura format) for GitLab integration.

**To generate the coverage report:**
```bash
# Via make
make coverage

# Direct script call
pwsh -File scripts/coverage-report.ps1
```
*Output: `coverage-results.xml` (Cobertura XML format)*

**For HTML visualization:**
- Upload `coverage-results.xml` to [Coveralls](https://coveralls.io) or similar services
- Use `cobertura-xml-to-html` or `lcov` tools to convert to HTML locally

---

<a name="test-file-structure"></a>
## Test File Structure

```
tests/powershell/
├── Tests.Tests.ps1                                # Shared BeforeAll/AfterAll (temp dirs, sample configs)
├── Config.Unit.Tests.ps1
├── Credentials.Unit.Tests.ps1
├── Executor.Unit.Tests.ps1
├── FileIO.Unit.Tests.ps1
├── Inventory.Unit.Tests.ps1
├── Validators.Unit.Tests.ps1
├── Router.Unit.Tests.ps1
├── New-Uuid.Unit.Tests.ps1
├── Audit.Unit.Tests.ps1
├── Set-MaintenanceMode.Unit.Tests.ps1             # Core unit tests
├── Set-MaintenanceMode.Enable.Tests.ps1           # High-priority enable action tests
├── Set-MaintenanceMode.Disable.Tests.ps1          # High-priority disable action tests
├── Set-MaintenanceMode.Validation.Tests.ps1       # High-priority validation tests
├── Set-MaintenanceMode.Environment.Tests.ps1      # Environment variable handling tests
├── Invoke-IsoDeploy.Unit.Tests.ps1
├── Invoke-OpsRampClient.Unit.Tests.ps1
├── New-IsoBuild.Unit.Tests.ps1
├── New-OneViewMaintenanceScript.Unit.Tests.ps1
├── New-ScomConnection.Unit.Tests.ps1
├── New-ScomMaintenanceScript.Unit.Tests.ps1
├── Start-AutomationOrchestrator.Unit.Tests.ps1
├── Start-InstallMonitor.Unit.Tests.ps1
├── Update-Firmware.Unit.Tests.ps1
├── Update-WindowsSecurity.Unit.Tests.ps1
├── Generate-PSDocs.Unit.Tests.ps1
├── Makefile.Unit.Tests.ps1                        # Makefile target validation tests
├── Pester.Integration.ps1                         # Integration test suite
├── Test-GitLabIntegration.ps1                     # GitLab CI integration tests
├── Test-GitLabCallback.ps1                        # GitLab webhook callback tests
├── _import_test.ps1                               # Module import validation
├── _mod_detail.ps1                                # Module detail inspection
├── _cls_final.ps1                                 # Class-based tests (final)
├── _class_test.ps1                                # Class-based test helpers
└── _debug_module.ps1                              # Module debugging utilities
```

---

<a name="writing-a-new-test"></a>
## Writing a New Test

```powershell
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'My-Cmdlet' {
    Context 'Given a valid input' {
        It 'Returns the expected result' {
            $result = My-Cmdlet -Param $value
            $result | Should -Be $expected
        }
    }

    Context 'Given an invalid input' {
        It 'Throws a terminating error' {
            { My-Cmdlet -BadParam $value } | Should -Throw
        }
    }
}
```

<a name="common-assertions"></a>
### Common Assertions

| Assertion | Syntax |
|---|---|
| Equality | `$result \| Should -Be $expected` |
| Strict equality | `$result \| Should -BeExactly $expected` |
| Null / empty | `$value \| Should -BeNullOrEmpty` |
| Throw / error | `{ cmdlet -BadInput } \| Should -Throw` |
| BeGreaterThan | `$val \| Should -BeGreaterThan 0` |
| BeOfType | `$val \| Should -BeOfType [int]` |

---

<a name="mocking"></a>
## Mocking

Pester's `Mock` keyword intercepts calls to a given command name inside the **currently executing scope**.

```powershell
Describe 'Invoke-PowerShellScript' {
    It 'Returns success when underlying command succeeds' {
        Mock Invoke-Command { return [pscustomobject]@{ success = $true } } -Verifiable
        $result = Invoke-PowerShellScript -Script 'Get-Process'
        $result.success | Should -Be $true
        Assert-MockCalled Invoke-Command -Times 1
    }
}
```

**Scope note:** Mocks are scoped to the running `Describe` block. They do *not* leak across test files.

---

<a name="ci-integration"></a>
## CI Integration

The CI pipeline requires a Windows agent with PowerShell 7+. See [powershell_ci.md](powershell_ci.md#markdown-header-2-ci-pipeline-powershell-stage-requirements) for full pipeline configuration.

```groovy
stage('PowerShell Tests') {
    agent { label 'windows' }
    steps {
        powershell '''
            if (-not (Get-Module Pester -ListAvailable)) {
                Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
            }
            $result = Invoke-Pester -Path 'tests/powershell' -Tag 'Unit' `
                -OutputFile 'powershell-test-results.xml' `
                -OutputFormat NUnitXml `
                -PassThru
            if ($result.FailedCount -gt 0) { exit 1 }
        '''
    }
    post { always { junit 'powershell-test-results.xml' } }
}
```

---

<a name="troubleshooting"></a>
## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Import-Module : Module 'Automation' was not loaded` | `$Script:ModuleRoot` is not set | Run `Invoke-Pester -Path 'tests/powershell'` so shared `Tests.Tests.ps1` `BeforeAll` runs first |
| `Mock` has no effect | Mock scope is outside the `Describe` block | `Mock` must be inside the same `Describe` context as the `It` that triggers it |
| Tests never finish | Real network call blocking | Use `-Verifiable` on mocks and `Assert-MockCalled` to verify interception |

---

<a name="see-also"></a>
## See Also

- **CI integration:** [powershell_ci.md](powershell_ci.md#top)
- **Code quality:** [code_quality.md](code_quality.md#top)
- **Pester documentation:** https://pester.dev/docs/quick-start/

---

<a name="maintenance-mode-testing"></a>
## Maintenance Mode Testing

Comprehensive testing for maintenance mode operations across SCOM and OneView systems.

<a name="test-files"></a>
### Test Files

| File | Purpose | Description |
|------|---------|-------------|
| `tests/powershell/Environment.Tests.ps1` | Environment/parameter tests | Tests for environment selection, host override, parameters |
| `tests/powershell/DateTime.Tests.ps1` | Date/time format tests | Tests for time parsing, format validation |
| `tests/powershell/BackwardCompat.Tests.ps1` | Backward compatibility tests | Tests for existing behavior preservation |
| `tests/powershell/Connection.Tests.ps1` | Connection validation tests | Tests for connectivity validation |

<a name="test-scripts"></a>
### Test Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/validate-maintenance-config.ps1` | Validate configuration | `pwsh scripts/validate-maintenance-config.ps1 -Environment Test` |
| `scripts/run-maintenance-tests.ps1` | Run test suite | `pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru` |
| `scripts/test-maintenance-connection.ps1` | Interactive connection test | `pwsh scripts/test-maintenance-connection.ps1 -Environment Test` |

<a name="running-maintenance-mode-tests"></a>
### Running Maintenance Mode Tests

```powershell
# Validate configuration first
pwsh scripts/validate-maintenance-config.ps1 -Environment Test

# Run specific test suite
pwsh scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru

# Run all maintenance mode tests
pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru

# Run with detailed output
Invoke-Pester -Path tests/powershell/Environment.Tests.ps1 -Output Detailed

# Quick test: validate a cluster
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Test -DryRun
```

<a name="test-coverage-areas"></a>
### Test Coverage Areas

| Area | Description | Test File |
|------|-------------|----------|
| Environment parameter | Test/Prod environment selection | Environment.Tests.ps1 |
| Host override | ManagementHost parameter and env var | Environment.Tests.ps1 |
| Credential parameters | Username parameter | Environment.Tests.ps1 |
| Relative time formats | +Xhours, +Xminutes, +Xdays, +Xseconds | DateTime.Tests.ps1 |
| Absolute time formats | YYYY-MM-DD HH:MM, ISO 8601 | DateTime.Tests.ps1 |
| Connection validation | SCOM/OneView pre-flight checks | Connection.Tests.ps1 |
| Combined parameters | Multiple parameters together | Environment.Tests.ps1 |
| Configuration files | connection_hosts.json structure | Environment.Tests.ps1 |
| Backward compatibility | Existing behavior preservation | BackwardCompat.Tests.ps1 |

<a name="interpreting-test-results"></a>
### Interpreting Test Results

**Test Status Indicators:**

```powershell
# Pester output symbols
✓  # Test passed
✗  # Test failed
!  # Test skipped (prerequisites not met)
```

**Success Criteria:**

```powershell
# All tests pass
Tests Passed: 100, Failed: 0, Skipped: 0, Duration: 25s

# Some tests skipped (e.g., requires actual SCOM server)
Tests Passed: 95, Failed: 0, Skipped: 5, Duration: 30s

# Test failure - investigate
Tests Passed: 90, Failed: 10, Skipped: 0, Duration: 25s
```

**Test Output Analysis:**

```powershell
# Each test shows:
[+] Should connect to SCOM with admin credentials 150ms  # Passed
[-] Should handle invalid environment 50ms                # Failed
    Expected: $true but got: $false
[!] Should test OneView maintenance mode 20ms             # Skipped (no OneView server)
```

**Common Test Failures:**

| Failure | Cause | Solution |
|---------|-------|----------|
| "SCOM host not configured" | Missing environment config | Add to `connection_hosts.json` or set `$env:MAINTENANCE_HOST` |
| "Missing credentials" | No credentials provided | Set `$env:SCOM_ADMIN_USER` and `$env:SCOM_ADMIN_PASSWORD` |
| "Failed to connect" | Network/auth issue | Verify server URL and credentials |
| "Invalid environment" | Wrong parameter value | Use `Test` or `Prod` only |
| "Module not found" | Pester not installed | Run `make setup` or install Pester manually |

**Troubleshooting Tips:**

```powershell
# Run with verbose output
Invoke-Pester -Path tests/powershell/Environment.Tests.ps1 -Output Detailed

# Run specific test
Invoke-Pester -Path tests/powershell/Environment.Tests.ps1 -TestName "*Environment parameter*"

# Export results to XML
Invoke-Pester -Path tests/powershell/ -OutputFile test-results.xml -OutputFormat NUnitXml
```

<a name="manual-testing-checklist"></a>
### Manual Testing Checklist

Before deploying maintenance mode changes:

- [ ] **Configuration valid** - `pwsh scripts/validate-maintenance-config.ps1`
- [ ] **Test environment works** - `-Environment Test -DryRun`
- [ ] **Prod environment works** - `-Environment Prod -DryRun`
- [ ] **Host override works** - `-ManagementHost backup-server.local`
- [ ] **Relative time formats work** - `-Start now -End +1hour`
- [ ] **Absolute time formats work** - `-Start 2025-01-15T10:00:00Z -End 2025-01-15T12:00:00Z`
- [ ] **Serial number lookup works** - Only OneView mode, requires real OneView server
- [ ] **Connection validation works** - Use `Set-MaintenanceMode -Action validate -Mode scom` for SCOM, `Test-ServerConnectivity` for OneView
- [ ] **Credential resolution works** - Environment vars and interactive prompt
- [ ] **JSON output works** - `-Json` flag
- [ ] **Backward compatibility** - Old command syntax still works

**SCOM-specific checks:**
- [ ] Group mode applies to all cluster objects
- [ ] Post-disable wait works (`-PostDisableWaitSeconds`)
- [ ] SCOM version detection works
- [ ] REST API connection works (SCOM 2019+)
- [ ] PowerShell cmdlet fallback works (legacy versions)

**OneView-specific checks:**
- [ ] Server scope resolution works
- [ ] Maintenance window creation works
- [ ] Per-object status reporting works

<a name="maintenance-mode-behavior"></a>
### Maintenance Mode Behavior

| Mode | Description | Target Resolution |
|------|-------------|-------------------|
| `scom` | SCOM cluster maintenance | Group name from `clusters_catalogue.json` |
| `oneview` | OneView server maintenance | Server hardware from OneView API |

**SCOM Mode:**
- Applies maintenance mode to entire cluster group
- Includes all nested objects (servers, databases, services)
- Uses REST API for SCOM 2019+, PowerShell cmdlets for legacy
- Optional post-disable wait for stability

**OneView Mode:**
- Applies maintenance mode to specific server or scope
- Creates maintenance window in OneView
- Supports serial number lookup
- Per-object status with ACK/NACK details

**Environment Resolution:**
1. `-ManagementHost` parameter (highest priority)
2. `$env:MAINTENANCE_HOST` environment variable
3. `connection_hosts.json` → Environment config

**Credential Resolution:**

*Username:*
1. `-Username` parameter
2. `$env:SCOM_ADMIN_USER` (SCOM) or `$env:ONEVIEW_USER` (OneView)
3. Interactive prompt (not recommended for automation)

*Password:*
1. `$env:SCOM_ADMIN_PASSWORD` (SCOM) or `$env:ONEVIEW_PASSWORD` (OneView)
2. Interactive prompt

<a name="maintenance-mode-testing-examples"></a>
### Maintenance Mode Testing Examples

**Example 1: Basic Validation (No Changes)**
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Test`
```

**Example 2: Dry Run Enable**
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Start now `
    -End '+1hour' `
    -Environment Test `
    -DryRun
```

**Example 3: Host Override**
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Prod `
    -ManagementHost backup-scom.local `
    -DryRun`
```

**Example 4: OneView with Serial Number**
```powershell
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -Mode oneview `
    -TargetId '' `
    -SerialNumber 'ABC123XYZ' `
    -Start now `
    -End '+1hour' `
    -Environment Test `
    -DryRun
```

**Example 5: JSON Output for Automation**
```powershell
$result = pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Test `
    -Json | ConvertFrom-Json

# Check success
if ($result.Success) {
    Write-Output "Validation passed: $($result.State)"
}
```

<a name="per-object-status-reporting"></a>
### Per-Object Status Reporting

When maintenance mode is enabled or disabled, the response includes detailed status for each object:

**Enable Response:**
```json
{
  "Cluster": "CLU-CLUSTER-01",
  "Action": "enable",
  "StartTime": "2025-01-15T10:00:00Z",
  "EndTime": "2025-01-15T12:00:00Z",
  "Environment": "Test",
  "DryRun": false,
  "PerObjectStatus": [
    {
      "Name": "PROD-SERVER-01",
      "Mode": "scom",
      "Status": "Success",
      "Message": "Maintenance mode enabled successfully",
      "AckRequired": false,
      "NackReason": null
    },
    {
      "Name": "PROD-SERVER-02",
      "Mode": "scom",
      "Status": "Failed",
      "Message": "Maintenance mode failed",
      "AckRequired": false,
      "NackReason": "Server not in maintenance window"
    }
  ]
}
```

**Status Values:**

| Status | Description | Requires Ack |
|--------|-------------|--------------|
| `Success` | Maintenance mode applied successfully | No |
| `Failed` | Maintenance mode failed | No |
| `NeedsAck` | Waiting for acknowledgment | Yes |
| `Unknown` | Status unknown | No |

**Common NACK Reasons:**
- Permission denied
- SCOM agent unreachable
- Object not found in SCOM
- Agent not found in SCOM
- SCOM operation failed

**Testing Per-Object Reporting:**
```powershell
# Enable and check status
$result = pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Test `
    -Start now `
    -End '+1hour' `
    -Json | ConvertFrom-Json

# Analyze per-object status
$result.PerObjectStatus | Format-Table Name, Status, Message -AutoSize

# Count successes and failures
$successes = ($result.PerObjectStatus | Where-Object { $_.Status -eq 'Success' }).Count
$failures = ($result.PerObjectStatus | Where-Object { $_.Status -eq 'Failed' }).Count

Write-Output "Successes: $successes, Failures: $failures"
```

<a name="safety-warnings"></a>
### Safety Warnings

⚠️ **Always test with `-DryRun` first**

```powershell
# DryRun is safe - no changes to systems
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Test `
    -Start now `
    -End '+1hour' `
    -DryRun

# Remove -DryRun to ACTUALLY enable maintenance mode
pwsh src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId CLU-CLUSTER-01 `
    -Mode scom `
    -Environment Test `
    -Start now `
    -End '+1hour'
```

**Safety Checklist:**
- ✅ `-DryRun` mode does NOT modify any systems
- ✅ `-Action validate` only checks configuration
- ⚠️  `-Action enable` without `-DryRun` WILL enable maintenance mode
- ⚠️  `-Action disable` without `-DryRun` WILL disable maintenance mode
- ✅ Always review dry-run output before removing `-DryRun`
- ✅ Use `-Environment Test` for initial testing
- ✅ Verify credentials before applying to production

