# PowerShell Module Testing Guide (Pester)

Complete guide to running and maintaining the Pester test suite for the `src/powershell/Automation` module.

---

## Overview

The PowerShell module uses **Pester v5+** as its BDD-style testing framework. Tests are colocated with the source under `tests/powershell/`.

**Framework:** [Pester](https://pester.dev/) v5.7.1  
**Test runner command:** `Invoke-Pester`  
**Test discovery:** `*.Unit.Tests.ps1`, `*.Tests.ps1` files in `tests/powershell/`  
**Offline support:** All dependencies are bundled under `vendor/modules/`

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

## Running Tests

### Run the Complete Test Suite

```powershell
# Run all Pester tests under tests/powershell/
Invoke-Pester -Path 'tests/powershell' -PassThru

# Verbose output — shows every passing and failing test
Invoke-Pester -Path 'tests/powershell' -PassThru -Show All
```

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

### Run via Wrapper Script

```powershell
# Run all tests with Pester auto-repair
pwsh -File scripts/run-tests.ps1

# Run high-priority maintenance mode tests only
pwsh -File scripts/run-maint-mode-tests.ps1
```

### Run a Single Test File

```powershell
Invoke-Pester -Path 'tests/powershell\Config.Unit.Tests.ps1'
```

### Run by Tag

```powershell
# Run Config + FileIO tests only
Invoke-Pester -Path 'tests/powershell' -Tag @('Config','FileIO') -PassThru

# Exclude integration tests
Invoke-Pester -Path 'tests/powershell' -ExcludeTag @('Integration') -PassThru
```

### CI / XML Output & Coverage Reports

```powershell
$result = Invoke-Pester -Path 'tests/powershell' -Tag 'Unit' `
            -OutputFile 'powershell-test-results.xml' `
            -OutputFormat NUnitXml `
            -PassThru

Write-Host "Passed: $($result.PassedCount)  Failed: $($result.FailedCount)"
exit $result.FailedCount
```

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

## Test File Structure

```
tests/powershell/
├── Tests.Tests.ps1                      # Shared BeforeAll/AfterAll (temp dirs, sample configs)
├── Config.Unit.Tests.ps1
├── Credentials.Unit.Tests.ps1
├── Executor.Unit.Tests.ps1
├── FileIO.Unit.Tests.ps1
├── Inventory.Unit.Tests.ps1
├── Validators.Unit.Tests.ps1
├── Router.Unit.Tests.ps1
├── New-Uuid.Unit.Tests.ps1
├── Audit.Unit.Tests.ps1
├── Set-MaintenanceMode.Unit.Tests.ps1   # Core unit tests
├── Set-MaintenanceMode.Enable.Tests.ps1  # High-priority enable action tests
├── Set-MaintenanceMode.Disable.Tests.ps1 # High-priority disable action tests
├── Set-MaintenanceMode.Validation.Tests.ps1 # High-priority validation tests
├── Invoke-IsoDeploy.Unit.Tests.ps1
├── Invoke-OpsRampClient.Unit.Tests.ps1
├── New-IsoBuild.Unit.Tests.ps1
├── New-OneViewMaintenanceScript.Unit.Tests.ps1
├── New-ScomConnection.Unit.Tests.ps1
├── New-ScomMaintenanceScript.Unit.Tests.ps1
├── Start-AutomationOrchestrator.Unit.Tests.ps1
├── Start-InstallMonitor.Unit.Tests.ps1
├── Test-BuildParams.Unit.Tests.ps1
├── Test-ClusterId.Unit.Tests.ps1
├── Test-ServerList.Unit.Tests.ps1
├── Update-Firmware.Unit.Tests.ps1
├── Update-WindowsSecurity.Unit.Tests.ps1
├── Generate-PSDocs.Unit.Tests.ps1
├── Pester.Integration.ps1
├── Test-GitLabIntegration.ps1
└── Test-GitLabCallback.ps1
```

---

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

## CI Integration

The CI pipeline requires a Windows agent with PowerShell 7+. See [powershell_ci.md](powershell_ci.md#ci-powershell-stage) for full pipeline configuration.

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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Import-Module : Module 'Automation' was not loaded` | `$Script:ModuleRoot` is not set | Run `Invoke-Pester -Path 'tests/powershell'` so shared `Tests.Tests.ps1` `BeforeAll` runs first |
| `Mock` has no effect | Mock scope is outside the `Describe` block | `Mock` must be inside the same `Describe` context as the `It` that triggers it |
| Tests never finish | Real network call blocking | Use `-Verifiable` on mocks and `Assert-MockCalled` to verify interception |

---

## See Also

- **CI integration:** [powershell_ci.md](powershell_ci.md)
- **Code quality:** [code_quality.md](code_quality.md)
- **Pester documentation:** https://pester.dev/docs/
