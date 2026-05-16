# PowerShell Module Testing Guide (Pester)

Complete guide to running and maintaining the Pester test suite for the `powershell/Automation` module.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Running Tests Locally](#running-tests-locally)
4. [Test File Structure](#test-file-structure)
5. [Shared Test Infrastructure](#shared-test-infrastructure)
6. [Writing a New Test](#writing-a-new-test)
7. [CI/CD Integration](#cicd-integration)
8. [Mocking](#mocking)
9. [Tagging & Filtering](#tagging--filtering)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The PowerShell module uses **Pester v5+** as its BDD-style testing framework — the equivalent of `pytest` for Python. Tests are colocated with the source under `powershell/Tests/` alongside their corresponding modules in `powershell/Automation/`.

**Framework:** [Pester](https://pester.dev/) v5.7.1 (latest stable at time of writing)

**Test runner command:** `Invoke-Pester`

**Test discovery:** `*.Tests.ps1` files in `powershell/Tests/`

**BDD keywords:** `Describe`, `Context`, `It`, `Should`, `Mock`, `BeforeAll`, `AfterAll`, `BeforeEach`, `AfterEach`

| Python / pytest concept | PowerShell / Pester equivalent |
|---|---|
| `tests/` directory | `powershell/Tests/` |
| `conftest.py` / fixtures | `BeforeAll` / `AfterAll` in each test file |
| `unittest.mock.patch` | `Mock` keyword |
| `assert x == y` | `$result | Should -Be expected` |
| `@pytest.mark.parametrize` | `It` blocks with data tables |
| Test runner: `pytest` | Test runner: `Invoke-Pester` |
| `pytest-cov` coverage reporting | `Invoke-Pester -Show All -PassThru | Format-NUnit` output |

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
| Pester | 5.0.0+ |

---

## Running Tests Locally

### Run the complete test suite

```powershell
# Run all Pester tests under powershell/Tests/
Invoke-Pester -Path 'powershell\Tests' -PassThru

# Verbose output — shows every passing and failing test
Invoke-Pester -Path 'powershell\Tests' -PassThru -Show All

# Included by -Show All: All / Errors / Failures / Inconclusive / Passed / Pending / Skipped / Describe / Context / Summary
Invoke-Pester -Path 'powershell\Tests' -PassThru -Show All
```

### Run a single test file

```powershell
Invoke-Pester -Path 'powershell\Tests\New-Uuid.Tests.ps1'
```

### Run a single `Describe` block

```powershell
Invoke-Pester -Path 'powershell\Tests\New-Uuid.Tests.ps1' -Tag New_Uuid
# or by Describe name
Invoke-Pester -Path 'powershell\Tests\New-Uuid.Tests.ps1'  # runs all in that file
```

### Run tests matching a specific `Describe` or `It`

```powershell
# Multiple -Tag filters (OR logic)
Invoke-Pester -Path 'powershell\Tests' -Tag @('Config','New-Uuid') -PassThru

# Filter by name wildcard
Invoke-Pester -Path 'powershell\Tests' -Name '*UUID*' -PassThru
```

### Exclude specific tags

```powershell
Invoke-Pester -Path 'powershell\Tests' -Tag @() -SkipTagFilter -ExcludeTag @('Integration') -PassThru
```

### Run integration tests only

```powershell
Invoke-Pester -Path 'powershell\Tests\Pester.All.api.ps1' -Tag 'Integration' -PassThru
```

### CI / non-interactive (generate NUnit XML)

```powershell
$result = Invoke-Pester -Path 'powershell\Tests' -Tag 'Unit' `
            -OutputFile 'test-results-powershell.xml' `
            -OutputFormat NUnitXml `
            -PassThru

# Exit with Pester's exit code for CI pipeline gating
exit $result.FailedCount
```

### Interactive TDD mode (watch for changes)

```powershell
# Requires Pester 5.3+
Invoke-Pester -Path 'powershell\Tests' -PassThru -CI
```

---

## Test File Structure

```
powershell/
└── Tests/
    ├── Tests.Tests.ps1               # Shared BeforeAll / AfterAll (temp dirs, sample configs)
    ├── Config.Tests.ps1              # Tests for powershell/Automation/Private/Config.psm1
    ├── Credentials.Tests.ps1         # Tests for powershell/Automation/Private/Credentials.psm1
    ├── Executor.Tests.ps1            # Tests for powershell/Automation/Private/Executor.psm1
    ├── FileIO.Tests.ps1              # Tests for powershell/Automation/Private/FileIO.psm1
    ├── Inventory.Tests.ps1           # Tests for powershell/Automation/Private/Inventory.psm1
    ├── Validators.Tests.ps1          # Tests for powershell/Automation/Public/Invoke-Validator.psm1
    ├── Router.Tests.ps1              # Tests for powershell/Automation/Private/Router.psm1
    ├── New-Uuid.Tests.ps1            # Tests for powershell/Automation/Public/New-Uuid.ps1
    ├── Audit.Tests.ps1               # Tests for powershell/Automation/Private/Audit.psm1
    ├── Set-MaintenanceMode.Tests.ps1 # Tests for powershell/Automation/Public/Set-MaintenanceMode.ps1
    ├── Pester.All.api.ps1            # Combined integration run helper
    ├── _import_test.ps1              # standalone smoke-test: verifies all module functions are exported
    ├── _debug_module.ps1             # ad-hoc debugging helper
    ├── _class_test.ps1               # ad-hoc class smoke test
    ├── _cls_final.ps1                # ad-hoc class smoke test
    └── _mod_detail.ps1               # ad-hoc detail / metadata dump
```

### Naming convention

- Each Pester test file is named `SourceFile.Tests.ps1`, mirroring the module file it tests
- The `*_test.ps1` files (prefixed with `_`) are **not** test suites — they are ad-hoc debugging/smoke scripts used during development; they are **not** discovered by Pester automatically unless explicitly targeted

---

## Shared Test Infrastructure

`powershell/Tests/Tests.Tests.ps1` is the equivalent of Python's `tests/conftest.py`. It runs `BeforeAll` before every individual test file and sets up:

- **`$Script:ModuleRoot`** — absolute path to `powershell/Automation/`
- **`$Script:TestRoot`** — absolute path to `powershell/Tests/`
- **`$Script:TempDir`** — unique temp directory (GUID-named), cleaned up in `AfterAll`
- **`$Script:ConfigDir`** — pre-created `configs/` subdir inside `$TempDir` with sample JSON fixtures:
  - `sample.json` — generic config
  - `server_list.txt` — three test servers (`srv01`/`srv02`/`srv03`)
  - `clusters_catalogue.json` — single `TEST-CLUSTER` definition
- **`$Script:LogDir`** and **`$Script:OutDir`** — temp log / output dirs

```powershell
BeforeAll {
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot    = $PSScriptRoot
    $Script:TempDir     = Join-Path $env:TEMP "AutomationTests_$(New-Guid).Trim('{}')"
    New-Item -ItemType Directory -Path $Script:TempDir -Force | Out-Null

    # ... sample configs written to $Script:ConfigDir ...

    AfterAll { Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
```

Individual test files reference `$Script:ModuleRoot` in their own `BeforeAll` to import the module:

```powershell
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}
```

---

## Writing a New Test

The pattern from the existing test files (taken from `Config.Tests.ps1` and `New-Uuid.Tests.ps1`):

```powershell
# powershell/Tests/<ModuleName>.Tests.ps1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe '<Cmdlet-Name>' {
    Context 'Given a valid input' {
        It 'Returns the expected result' {
            $result = <Cmdlet-Name> -Param $value
            $result | Should -Be $expected
        }
    }

    Context 'Given an invalid or missing input' {
        It 'Throws a terminating error' {
            { <Cmdlet-Name> -BadParam $value } | Should -Throw
        }
    }
}
```

### Common `Should` assertions

| Assertion | Syntax |
|---|---|
| Equality (loose) | `$result | Should -Be $expected` |
| Strict equality | `$result | Should -BeExactly $expected` |
| Inequality | `$result | Should -Not -Be $expected` |
| Null / empty | `$value | Should -BeNullOrEmpty` |
| File exists | `Test-Path $path | Should -Be $true` |
| Throw / error | `{ cmdlet -BadInput } | Should -Throw` |
| Match (regex) | `$str | Should -Match '^$[A-Z]'` |
| BeGreaterThan | `$val | Should -BeGreaterThan 0` |
| BeOfType | `$val | Should -BeOfType [int]` |

### Using `Mock`

Replace a cmdlet or function call within a `Describe` block:

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

### Using `BeforeEach` / `AfterEach`

Per-test setup/teardown (runs before/after every individual `It` block):

```powershell
BeforeEach {
    $Script:TestFile = Join-Path $Script:TempDir "test_$(New-Guid).json"
}
AfterEach {
    Remove-Item $Script:TestFile -ErrorAction SilentlyContinue
}
```

---

## Mocking

Pester's `Mock` keyword intercepts calls to a given command name inside the **currently executing scope** (including inside functions it calls).

```powershell
# Mock any command — prevents real execution, returns controlled value
Mock Get-Content { return @'fake-content'@ }

# Assert it was called exactly N times
Assert-MockCalled Get-Content -Times 1
Assert-MockCalled Get-Content -ParameterFilter { $Path -eq 'missing.txt' } -Times 1
```

**Scope note:** Mocks are scoped to the running `Describe` block. They do *not* leak across test files.

---

## Test File ↔ Source File Map

| Test file | Source module |
|---|---|
| `Config.Tests.ps1` | `Automation/Private/Config.psm1` |
| `Credentials.Tests.ps1` | `Automation/Private/Credentials.psm1` |
| `Executor.Tests.ps1` | `Automation/Private/Executor.psm1` |
| `FileIO.Tests.ps1` | `Automation/Private/FileIO.psm1` |
| `Inventory.Tests.ps1` | `Automation/Private/Inventory.psm1` |
| `Router.Tests.ps1` | `Automation/Private/Router.psm1` |
| `New-Uuid.Tests.ps1` | `Automation/Public/New-Uuid.ps1` |
| `Audit.Tests.ps1` | `Automation/Private/Audit.psm1` |
| `Validators.Tests.ps1` | `Automation/Public/Invoke-Validator.psm1` |
| `Set-MaintenanceMode.Tests.ps1` | `Automation/Public/Set-MaintenanceMode.ps1` |

---

## CI/CD Integration

### Current state

The Jenkinsfile (as of the current codebase) has **no `Invoke-Pester` stage**. The Linux-based `Unit Tests & Coverage` stage only runs `pytest` for the Python side of the project. Adding a Pester stage requires a Windows agent.

### Recommended Jenkins stage

```groovy
stage('PowerShell Tests') {
    agent { label 'windows' }
    steps {
        powershell '''
            # Install Pester if not already installed on the agent
            if (-not (Get-Module Pester -ListAvailable)) {
                Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
            }
            Import-Module Pester

            # Run unit tests, emit JUnit XML from path
            $result = Invoke-Pester -Path 'powershell\\Tests' -Tag 'Unit' `
                -OutputFile 'powershell-test-results.xml' `
                -OutputFormat NUnitXml `
                -PassThru

            Write-Host "Tests Passed : $($result.PassedCount)"
            Write-Host "Tests Failed : $($result.FailedCount)"
            if ($result.FailedCount -gt 0) { exit 1 }
        '''
    }
    post {
        always {
            junit 'powershell-test-results.xml'
        }
        failure {
            mail to: 'dev-team@yourcompany.com',
                 subject: "PowerShell Tests FAILED: Build #${BUILD_NUMBER}",
                 body: "Run Invoke-Pester locally to reproduce."
        }
    }
}
```

> **Note:** Because this project's Jenkinsfile already runs on a `windows` agent, place this stage immediately before the existing `Unit Tests & Coverage` (Python/pytest) stage. Both can coexist on the same agent.

### PR incremental testing for PowerShell

In Jenkins, use `CHANGE_ID` to mirror Python's PR incremental mode for PowerShell too:

```powershell
$isPR = $env:CHANGE_ID -ne $null -and $env:CHANGE_ID -ne ''
if ($isPR) {
    $target = $env:CHANGE_TARGET
    if ([string]::IsNullOrWhiteSpace($target)) { $target = "main" }
    git fetch origin $target 2>$null
    $changed = git diff --name-only origin/$target...HEAD
    # Map changed PowerShell files → affected *Tests.ps1 files
    $psTests = $changed | Where-Object { $_ -match 'automation/.*\.(ps1|psm1)$' }
    # Set $changedPowerShellTests accordingly...
}
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Import-Module : Module 'Automation' was not loaded because no valid module file was found` | `$Script:ModuleRoot` is not set or wrong path | Run `powershell/Tests/Tests.Tests.ps1` first; it sets `$Script:ModuleRoot` in `BeforeAll`. Pass through `$Script:ModuleRoot` from the shared file. |
| `The variable '$Script:ModuleRoot' cannot be retrieved because it has not been set` | Running an individual test file directly without the shared `BeforeAll` | Run via `Invoke-Pester -Path 'powershell\Tests'` so shared `Tests.Tests.ps1` `BeforeAll` runs first, or paste the `BeforeAll` block from `Tests.Tests.ps1` into your script. |
| `Mock` has no effect | Mock scope is outside the `Describe` block that calls the mocked cmdlet | `Mock` must be inside the same `Describe` context as the `It` that triggers it. |
| Tests never finish | A mocked `Invoke-Command` is not being hit and a real network call blocks | Verify `Mock` is applied with `-Verifiable`; use `Assert-MockCalled`. |
| Module not found on Windows Server 2016 | Pester was installed with `-Scope AllUsers` | Use `-Scope CurrentUser` or run `Install-Module Pester` from an elevated prompt, then `$env:PSModulePath` should include `C:\Program Files\WindowsPowerShell\Modules`. |
| `Should -Throw` not matching the expected exception | `Should -Throw` without a pattern matches any terminating error | Pass a regex pattern: `Should -Throw 'not found'` |

---

## See Also


- **CyberArk secrets + Jenkins setup** — full credential mapping, Bootstrap stage docs,
  and credential function reference: [`../powershell/powershell-jenkins-run-requirements.md`](../powershell/powershell/powershell-jenkins-run-requirements.md)
- Python/pytest testing guide: [`../python/testing.md`](../python/testing.md)
- PowerShell module overview: [`../powershell/powershell_api_reference.md`](../powershell/powershell_api_reference.md)
- Pester documentation: https://pester.dev/docs/
- Pester v6 migration guide: https://pester.dev/docs/migration/v5-to-v6
