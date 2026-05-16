# PowerShell Testing — Quick Start Guide

Fast reference for running Pester tests on the `powershell/Automation` module.

---

## Install Pester

```powershell
# One-time install (current user, no admin required)
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force

# Verify
Get-Module Pester -ListAvailable
```

---

## Run All Tests

```powershell
# Discovered automatically from *.Tests.ps1 in powershell/Tests/
Invoke-Pester -Path 'powershell\Tests' -PassThru

# Verbose — every passing AND failing test in the console
Invoke-Pester -Path 'powershell\Tests' -PassThru -Show All
```

---

## Run a Single File

```powershell
Invoke-Pester -Path 'powershell\Tests\Config.Tests.ps1'
Invoke-Pester -Path 'powershell\Tests\New-Uuid.Tests.ps1'
```

---

## Run by Tag (subset by module)

```powershell
# Run Config + FileIO tests only
Invoke-Pester -Path 'powershell\Tests' -Tag @('Config','FileIO') -PassThru

# Exclude integration tests
Invoke-Pester -Path 'powershell\Tests' -ExcludeTag @('Integration') -PassThru
```

---

## CI / JUnit XML Output

```powershell
$result = Invoke-Pester -Path 'powershell\Tests' -Tag 'Unit' `
            -OutputFile 'powershell-test-results.xml' `
            -OutputFormat NUnitXml `
            -PassThru

Write-Host "Passed: $($result.PassedCount)  Failed: $($result.FailedCount)"
exit $result.FailedCount
```

---

## Step-by-Step for a New Repository Clone

```powershell
# 1. Clone the repo
git clone <repo-url>
cd image-build-automation

# 2. Install Pester
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force

# 3. Run the test suite
Invoke-Pester -Path 'powershell\Tests' -PassThru
```

---

## Smoke-Test that All Module Functions Exist

```powershell
# Run the ad-hoc smoke test (verifies all expected exports are present)
pwsh -File powershell/Tests/_import_test.ps1
# → "Summary: N OK, 0 MISSING"
```

---

## Typical Console Output

```
Describing Invoke-JsonConfig
  [+] Loads a valid JSON file                               12 ms
  [+] Returns empty hashtable for missing file when not required  5 ms
  [+] Throws when file is missing and required                         7 ms
[+] All tests passed        450 ms
Tests completed in 450 ms
```

---

## Cheatsheet

| Task | Command |
|---|---|
| Run all tests | `Invoke-Pester -Path 'powershell\Tests' -PassThru` |
| Run one file | `Invoke-Pester -Path 'powershell\Tests\<file>.Tests.ps1'` |
| Run by tag | `Invoke-Pester -Path 'powershell\Tests' -Tag @('Config') -PassThru` |
| JUnit XML for CI | `Invoke-Pester -Path 'powershell\Tests' -OutputFile results.xml -OutputFormat NUnitXml -PassThru` |
| Verbose all results | `Invoke-Pester -Path 'powershell\Tests' -PassThru -Show All` |
| Smoke-test module exports | `pwsh -File powershell/Tests/_import_test.ps1` |

---

## Next Steps

- Full Pester reference: [`powershell_testing.md`](powershell_testing.md)
- Module overview: [`powershell_api_reference.md`](powershell_api_reference.md)
- Python/pytest reference: [`../python/testing.md`](../python/testing.md)
