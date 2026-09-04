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
  - [CI / XML Output & Coverage Reports](#ci-xml-output-coverage-reports)
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

Guide to running and maintaining the Pester test suite for `src/powershell/Automation`.

<a id="overview"></a>

## Overview

The module uses **Pester v6+** (BDD-style). Tests colocate with source under `tests/powershell/`.

**Framework:** [Pester](https://pester.dev/docs/quick-start/) v6.0.1
**Runner:** `Invoke-Pester`
**Discovery:** `*.Unit.Tests.ps1`, `*.Tests.ps1` in `tests/powershell/`
**Offline:** dependencies bundled under `vendor/modules/`

<a id="bdd-keywords"></a>

### BDD Keywords

| Pester concept | PowerShell equivalent |
|---|---|
| `Describe` | Test suite |
| `Context` | Arrange/Act blocks |
| `It` | Individual assertion |
| `Mock` | Intercept command calls |
| `BeforeAll` / `AfterAll` | Test fixtures |
| `Should` | Assertion |

<a id="prerequisites"></a>

## Prerequisites

```powershell
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
Get-Module Pester -ListAvailable
```

| Runtime | Version |
|---|---|
| PowerShell 7 | 7.2+ |
| Pester | 6.0.1 (bundled) |

<a id="running-tests"></a>

## Running Tests

<a id="run-the-complete-test-suite"></a>

### Run the Complete Test Suite

```powershell
Invoke-Pester -Path 'tests/powershell' -PassThru
Invoke-Pester -Path 'tests/powershell' -PassThru -Show All
```

<a id="run-via-makefile"></a>

### Run via Makefile

```bash
make test                 # default: lint + test
make test-unit            # unit tests only
make test-integration     # integration tests only
make maint-mode-tests     # Set-MaintenanceMode enable/disable/validate
make lint-test            # lint + tests (CI step)
```

<a id="run-via-wrapper-script"></a>

### Run via Wrapper Script

```powershell
pwsh -File scripts/run-tests.ps1            # all tests, Pester auto-repair
pwsh -File scripts/run-maint-mode-tests.ps1 # maintenance mode tests only
```

<a id="run-a-single-test-file"></a>

### Run a Single Test File

```powershell
Invoke-Pester -Path 'tests/powershell\Config.Unit.Tests.ps1'
```

<a id="run-by-tag"></a>

### Run by Tag

```powershell
Invoke-Pester -Path 'tests/powershell' -Tag @('Config','FileIO') -PassThru
Invoke-Pester -Path 'tests/powershell' -ExcludeTag @('Integration') -PassThru
```

<a id="ci-xml-output-coverage-reports"></a>

### CI / XML Output & Coverage Reports

```powershell
$result = Invoke-Pester -Path 'tests/powershell' -Tag 'Unit' `
            -OutputFile 'powershell-test-results.xml' `
            -OutputFormat NUnitXml `
            -PassThru
Write-Output "Passed: $($result.PassedCount)  Failed: $($result.FailedCount)"
exit $result.FailedCount
```

<a id="code-coverage"></a>

### Code Coverage

CI jobs produce `coverage-results.xml` (Cobertura) for GitLab integration.

```bash
make coverage                 # via make
pwsh -File scripts/coverage-report.ps1
```

Visualize with Coveralls or `cobertura-xml-to-html` / `lcov`.

<a id="test-file-structure"></a>

## Test File Structure

Tests colocate under `tests/powershell/`. Each Public cmdlet and key Private helper has a `*.Unit.Tests.ps1` (helpers use `*.Tests.ps1`).

- `Set-MaintenanceMode.{Unit,Enable,Disable,Validation,Environment}.Tests.ps1` - core maintenance mode
- `Start-AutomationOrchestrator.Unit.Tests.ps1`, `Router.Unit.Tests.ps1` - orchestrator/routing
- `Get-OneViewServerTarget/List/ConnectionStatus/Version.Tests.ps1`, `Test-ServerConnectivity.Tests.ps1` - OneView
- `New-ScomConnection.Unit.Tests.ps1`, `New-ScomMaintenanceScript.Unit.Tests.ps1` - SCOM
- `New-IsoBuild`, `Publish-BootIso`, `Invoke-IsoDeploy`, `Invoke-IloRedfish`, `Start-InstallMonitor`, `Start-PhysicalServerBuild` - build/deploy
- `Update-Firmware`, `Update-WindowsSecurity` - patching
- `Test-PreBuildValidation`, `Test-PostBuildValidation` - validation
- `Config`, `Credentials`, `Executor`, `FileIO`, `Inventory`, `Logging`, `Audit`, `Validators` - Private modules
- `Pester.Integration.ps1`, `Test-GitLabIntegration.ps1`, `Test-GitLabCallback.ps1` - integration/CI

<a id="writing-a-new-test"></a>

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

<a id="common-assertions"></a>

### Common Assertions

| Assertion | Syntax |
|---|---|
| Equality | `$result \| Should -Be $expected` |
| Strict equality | `$result \| Should -BeExactly $expected` |
| Null / empty | `$value \| Should -BeNullOrEmpty` |
| Throw / error | `{ cmdlet -BadInput } \| Should -Throw` |
| BeGreaterThan | `$val \| Should -BeGreaterThan 0` |
| BeOfType | `$val \| Should -BeOfType [int]` |

<a id="mocking"></a>

## Mocking

`Mock` intercepts calls to a command within the currently executing scope.

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

Mocks are scoped to the running `Describe` block and do not leak across test files.

<a id="ci-integration"></a>

## CI Integration

Requires a Windows agent with PowerShell 7+. See [powershell_ci.md](powershell_ci.md#markdown-header-2-ci-pipeline-powershell-stage-requirements).

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
                -OutputFormat NUnitXml -PassThru
            if ($result.FailedCount -gt 0) { exit 1 }
        '''
    }
    post { always { junit 'powershell-test-results.xml' } }
}
```

<a id="troubleshooting"></a>

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Import-Module : Module 'Automation' was not loaded` | `$Script:ModuleRoot` not set | Run `Invoke-Pester -Path 'tests/powershell'` so shared `Tests.Tests.ps1` `BeforeAll` runs first |
| `Mock` has no effect | Mock scope outside the `Describe` block | `Mock` must be inside the same `Describe` as the `It` that triggers it |
| Tests never finish | Real network call blocking | Use `-Verifiable` mocks and `Assert-MockCalled` to verify interception |

<a id="see-also"></a>

## See Also

- **CI integration:** [powershell_ci.md](powershell_ci.md#top)
- **Code quality:** [code_quality.md](code_quality.md#top)
- **Pester documentation:** https://pester.dev/docs/quick-start/

<a id="maintenance-mode-testing"></a>

## Maintenance Mode Testing

Testing for maintenance mode operations across SCOM and OneView.

<a id="test-files"></a>

### Test Files

| File | Purpose |
|------|---------|
| `tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1` | Core unit tests |
| `tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1` | High-priority enable action |
| `tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1` | High-priority disable action |
| `tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1` | High-priority validation |
| `tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1` | Environment/host resolution |
| `tests/powershell/Test-ServerConnectivity.Tests.ps1` | OneView connectivity check |

<a id="test-scripts"></a>

### Test Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/validate-maintenance-config.ps1` | Validate configuration | `pwsh scripts/validate-maintenance-config.ps1 -Environment Test` |
| `scripts/run-maintenance-tests.ps1` | Run test suite | `pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru` |
| `scripts/test-maintenance-connection.ps1` | Interactive connection test | `pwsh scripts/test-maintenance-connection.ps1 -Environment Test` |

<a id="running-maintenance-mode-tests"></a>

### Running Maintenance Mode Tests

```powershell
pwsh scripts/validate-maintenance-config.ps1 -Environment Test
pwsh scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru
pwsh scripts/run-maintenance-tests.ps1 -TestSuite All -PassThru
Invoke-Pester -Path tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1 -Output Detailed
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Test -DryRun
```

<a id="test-coverage-areas"></a>

### Test Coverage Areas

| Area | Description | Test File |
|------|-------------|----------|
| Environment parameter | Test/Prod selection | Set-MaintenanceMode.Environment.Tests.ps1 |
| Host override | OneViewHost parameter / env var | Set-MaintenanceMode.Environment.Tests.ps1 |
| Credential parameters | Username parameter | Set-MaintenanceMode.Environment.Tests.ps1 |
| Relative time formats | +Xhours, +Xminutes, +Xdays, +Xseconds | Set-MaintenanceMode.Environment.Tests.ps1 |
| Absolute time formats | YYYY-MM-DD HH:MM, ISO 8601 | Set-MaintenanceMode.Environment.Tests.ps1 |
| Connection validation | SCOM/OneView pre-flight checks | Test-ServerConnectivity.Tests.ps1 |
| Combined parameters | Multiple parameters together | Set-MaintenanceMode.Environment.Tests.ps1 |
| Configuration files | connection_hosts.json structure | Set-MaintenanceMode.Environment.Tests.ps1 |
| Backward compatibility | Existing behavior preservation | Set-MaintenanceMode.Unit.Tests.ps1 |

<a id="interpreting-test-results"></a>

### Interpreting Test Results

Pester symbols: `✓` passed, `✗` failed, `!` skipped (prerequisites not met).

```
Tests Passed: 100, Failed: 0, Skipped: 0, Duration: 25s   # ideal
Tests Passed: 95, Failed: 0, Skipped: 5, Duration: 30s    # some require real SCOM server
Tests Passed: 90, Failed: 10, Skipped: 0, Duration: 25s   # failure - investigate
```

| Failure | Cause | Solution |
|---------|-------|----------|
| "SCOM host not configured" | Missing environment config | Add to `connection_hosts.json` or set `$env:MAINTENANCE_HOST` |
| "Missing credentials" | No credentials provided | Set `$env:SCOM_ADMIN_USER` / `$env:SCOM_ADMIN_PASSWORD` |
| "Failed to connect" | Network/auth issue | Verify server URL and credentials |
| "Invalid environment" | Wrong parameter value | Use `Test` or `Prod` only |
| "Module not found" | Pester not installed | `make setup` or install Pester manually |

<a id="manual-testing-checklist"></a>

### Manual Testing Checklist

- [ ] **Configuration valid** - `pwsh scripts/validate-maintenance-config.ps1`
- [ ] **Test environment works** - `-Environment Test -DryRun`
- [ ] **Prod environment works** - `-Environment Prod -DryRun`
- [ ] **Host override works** - `-OneViewHost backup-server.local`
- [ ] **Relative time formats work** - `-Start now -End +1hour`
- [ ] **Absolute time formats work** - `-Start 2025-01-15T10:00:00Z -End 2025-01-15T12:00:00Z`
- [ ] **Serial number lookup works** - OneView mode only, requires real OneView server
- [ ] **Connection validation works** - `Set-MaintenanceMode -Action validate -Mode scom` (SCOM), `Test-ServerConnectivity` (OneView)
- [ ] **Credential resolution works** - env vars and interactive prompt
- [ ] **JSON output works** - `-Json` flag
- [ ] **Backward compatibility** - old command syntax still works

**SCOM-specific:** group mode applies to all cluster objects; post-disable wait (`-PostDisableWaitSeconds`); SCOM version detection; REST API (2019+); PowerShell cmdlet fallback (legacy).

**OneView-specific:** server scope resolution; maintenance window creation; per-object status reporting.

<a id="maintenance-mode-behavior"></a>

### Maintenance Mode Behavior

| Mode | Description | Target Resolution |
|------|-------------|-------------------|
| `scom` | SCOM cluster maintenance | Group name from `clusters_catalogue.json` |
| `oneview` | OneView server maintenance | Server hardware from OneView API |

**SCOM Mode:** applies to entire cluster group (all nested objects); REST API for SCOM 2019+, PowerShell cmdlets for legacy; optional post-disable wait.

**OneView Mode:** applies to specific server or scope; creates maintenance window; supports serial number lookup; per-object status with ACK/NACK.

**Environment Resolution:** 1. `-OneViewHost` parameter, 2. `$env:MAINTENANCE_HOST`, 3. `connection_hosts.json` → Environment config.

**Credential Resolution:** Username: 1. `-Username`, 2. `$env:SCOM_ADMIN_USER`/`$env:ONEVIEW_USER`, 3. interactive prompt. Password: 1. `$env:SCOM_ADMIN_PASSWORD`/`$env:ONEVIEW_PASSWORD`, 2. interactive prompt.

<a id="maintenance-mode-testing-examples"></a>

### Maintenance Mode Testing Examples

```powershell
# 1. Basic validation (no changes)
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Test

# 2. Dry-run enable
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom `
    -Start now -End '+1hour' -Environment Test -DryRun

# 3. Host override
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom `
    -Environment Prod -OneViewHost backup-scom.local -DryRun

# 4. OneView with serial number
Set-MaintenanceMode -Action enable -Mode oneview -TargetId '' -SerialNumber 'ABC123XYZ' `
    -Start now -End '+1hour' -Environment Test -DryRun

# 5. JSON output for automation
$result = Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 `
    -Mode scom -Environment Test -Json | ConvertFrom-Json
if ($result.Success) { Write-Output "Validation passed: $($result.State)" }
```

<a id="per-object-status-reporting"></a>

### Per-Object Status Reporting

Enable/disable responses include detailed status per object:

```json
{
  "Cluster": "CLU-CLUSTER-01",
  "Action": "enable",
  "StartTime": "2025-01-15T10:00:00Z",
  "EndTime": "2025-01-15T12:00:00Z",
  "Environment": "Test",
  "DryRun": false,
  "PerObjectStatus": [
    { "Name": "PROD-SERVER-01", "Mode": "scom", "Status": "Success",
      "Message": "Maintenance mode enabled successfully", "AckRequired": false, "NackReason": null },
    { "Name": "PROD-SERVER-02", "Mode": "scom", "Status": "Failed",
      "Message": "Maintenance mode failed", "AckRequired": false, "NackReason": "Server not in maintenance window" }
  ]
}
```

| Status | Description | Requires Ack |
|--------|-------------|--------------|
| `Success` | Applied successfully | No |
| `Failed` | Failed | No |
| `NeedsAck` | Waiting for acknowledgment | Yes |
| `Unknown` | Status unknown | No |

Common NACK reasons: permission denied; SCOM agent unreachable; object/agent not found in SCOM; SCOM operation failed.

```powershell
$result = Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom `
    -Environment Test -Start now -End '+1hour' -Json | ConvertFrom-Json
$result.PerObjectStatus | Format-Table Name, Status, Message -AutoSize
$successes = ($result.PerObjectStatus | Where-Object { $_.Status -eq 'Success' }).Count
$failures  = ($result.PerObjectStatus | Where-Object { $_.Status -eq 'Failed' }).Count
Write-Output "Successes: $successes, Failures: $failures"
```

<a id="safety-warnings"></a>

### Safety Warnings

⚠️ Always test with `-DryRun` first. `-DryRun` and `-Action validate` make no system changes; `-Action enable`/`disable` without `-DryRun` WILL change maintenance state. Review dry-run output, use `-Environment Test` for initial runs, and verify credentials before production.

```powershell
# Safe - no changes
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom `
    -Environment Test -Start now -End '+1hour' -DryRun
# Actually enable - remove -DryRun
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom `
    -Environment Test -Start now -End '+1hour'
```
