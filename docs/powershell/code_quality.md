# PowerShell Code Quality & Security Scanning

This document describes the automated code quality, linting, security scanning, and vulnerability detection for PowerShell scripts in the Jenkins CI/CD pipeline.

## Overview

Every build runs a **PowerShell Code Quality & Security Scan** stage (unless explicitly skipped via `SKIP_CODE_SCAN`) that executes:

| Tool | Purpose | Output Format |
|------|---------|---------------|
| **PSScriptAnalyzer** | PowerShell linter + security rules (Microsoft) | JSON, formatted text |
| **gitleaks** | Hardcoded secret detection in repository | JSON |

All reports are archived as build artifacts for traceability and compliance.

## Pipeline Stages

### 1. Setup

Installs all scanning tools and validates PowerShell module syntax:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck -Force
Install-Module gitleaks -Scope CurrentUser -SkipPublisherCheck -Force  # or download binary
```

Validates PowerShell syntax for all scripts under `powershell/Automation/` and
`powershell/Tests/`. Uses `Invoke-ScriptAnalyzer` as the lint entry-point (see below).

### 2. Code Quality & Security Scan

Runs immediately after Setup, before any build/deploy operations. It:

- Lints all PowerShell code in `powershell/Automation/` and `powershell/Tests/`
- Checks for PowerShell security anti-patterns (hardcoded credentials, unsafe invocation, etc.)
- Scans the repository history for committed secrets via gitleaks

**Skip this stage** by setting the `SKIP_CODE_SCAN` parameter to `true` in Jenkins.
**Fail the build on violations** by setting `FAIL_ON_CODE_ISSUES` to `true`.

### 3–9. Existing Build Stages

Unaffected; code scanning runs as a pre-check.

---

## Tool Details

### PSScriptAnalyzer (PowerShell Linter)

**Command:**
```powershell
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning,Information -OutputFormat Json -OutFile 'code_scan_results\psa_issues.json'
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning -OutputFormat Diagnostics
```

**Checks** (selected rules — severity indicated):

| Rule ID | Severity | Description |
|---------|----------|-------------|
| `PSAvoidUsingConvertToSecureStringWithPlainText` | Error / Warning | Hardcoded plain-text password before converting to `SecureString` |
| `PSAvoidUsingPlainTextForPassword` | Error | Credential parameter or variable accepting plain text |
| `PSAvoidUsingCmdletAliases` | Warning | Non-canonical alias in production script |
| `PSUseDeclaredVarsMoreThanAssignments` | Warning | Variable declared but never read |
| `PSUseSingularNouns` | Warning | Cmdlet noun should be singular |
| `PSAvoidUsingWriteHost` | Warning | `Write-Host` bypasses pipeline; use `Write-Output` or `Write-Verbose` |
| `PSUseShouldProcessForStateChangingFunctions` | Warning | Missing `[CmdletBinding(SupportsShouldProcess)]` on mutating functions |
| `PSUseStrictMode` | Warning / Information | Script not running with `Set-StrictMode -Version Latest` |
| `PSAvoidUsingInvokeExpression` | Error | `Invoke-Expression` with user input (code injection risk) |
| `PSAvoidUsingPositionalParameters` | Warning | Unnamed positional parameters reduce readability |
| `PSReviewUnusedParameter` | Warning | Cmdlet parameter declared but never referenced |
| `PSUseConsistentWhitespace` | Warning | Inconsistent spacing around operators / braces |
| `PSAvoidGlobalAliases` | Warning | Use of `$global:`scope without explicit need |

**Auto-fix**: Some PSA rules support automatic remediation. Run PowerShell 7+ and ensure the project enforces `CorrectiveSuggestions` and uses the `-EnableExit` or `-AutoFix` flags where available, e.g.:

```powershell
# Force auto-fix of supported rules (PowerShell 7+ / PSScriptAnalyzer latest)
$config = @{
    IncludeRules    = @('PSAvoidUsingCmdletAliases','PSUseConsistentWhitespace')
    AutoFix         = $true
}
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Settings $config
```

---

For build-critical rules (`AvoidUsingConvertToSecureStringWithPlainText`, `AvoidUsingPlainTextForPassword`, `AvoidUsingInvokeExpression`), PSScriptAnalyzer reports them as **Error**. Parses the JSON report for any finding with `Severity` equal to `Error` and uses it to indicate whether remediation is required.

### Gitleaks (Secret Detection)

**Command:**
```powershell
gitleaks detect --source=. --report-path=code_scan_results\gitleaks_report.json --report-format json --no-banner
```

**Detects:**
- AWS keys (`AKIA...`), GitHub tokens (`ghp_...`, `gho_...`)
- Private keys (`BEGIN RSA PRIVATE KEY`, `PuTTY-User-Key-File-2`)
- Generic passwords or API keys embedded in `.ps1` / `.psm1` files
- Connection strings, bearer tokens, high-entropy strings

**Scan scope:** entire repository (including history); runs on the checked-out workspace.

**False positives:** Add to `code_scan_results\.gitleaks.toml` or a root `.gitleaks.toml` allowlist.

---

## Report Structure

All scan reports are archived under `code_scan_results/` in each build:

```
code_scan_results/
├── psa_issues.json            # PSScriptAnalyzer JSON output
├── psa_issues.txt             # Human-readable PSScriptAnalyzer output
├── gitleaks_report.json       # Committed secrets (if any)
```

### Quality Gates

The build **alerts** via email on quality gate violations but does **not fail** by default — to avoid blocking active development.

Enable strict failure by setting `FAIL_ON_CODE_ISSUES=true` in Jenkins parameters.

| Metric | Threshold | Enforcement |
|--------|-----------|-------------|
| **PSScriptAnalyzer**: zero `Error`-severity findings | All `Error` findings must be resolved | Strict mode |
| **PSScriptAnalyzer**: zero `Warning`-severity findings recommended | Warnings reviewed each sprint | Advisory |
| **Gitleaks**: zero committed secrets | Any finding triggers immediate rotation | Always strict |

**To fail the build on violations** in a local or CI step:

```powershell
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error
if ($LASTEXITCODE -ne 0) { exit 1 }
```

---

## Local Development

Install tools and run all scans locally before committing:

```powershell
# Install analysis tools
Install-Module PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck -Force
# Get gitleaks from https://github.com/gitleaks/gitleaks/releases (or winget install gitleaks)

# Lint all PowerShell modules
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning -OutputFormat Diagnostics

# JSON report for CI / archival
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning -OutputFormat Json -OutFile 'psa_issues.json'

# Secret scan
gitleaks detect --source=. --report-path=gitleaks_report.json --report-format json --no-banner

# Enforce strict mode in every module
Set-StrictMode -Version Latest  # add to the top of every .ps1/.psm1 file
```

### Common PowerShell Quality Rules (Cheat Sheet)

```powershell
# 1. Never hardcode credentials
# BAD:
$password = "MySecretP@ss"
# GOOD:
$credential = Get-Credential   # prompts interactively
$credential = Get-Secret -Name 'MySecret' -Vault MyVault  # Microsoft.PowerShell.SecretManagement

# 2. Never use Invoke-Expression on outside input
# BAD:
Invoke-Expression $userInput
# GOOD:
iex $userInput   # same risk — avoid entirely; prefer direct cmdlet calls or -ScriptBlock params

# 3. Always validate inputs
# BAD:
param([string]$Path)
# GOOD:
param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ })] [string] $Path)

# 4. Use ShouldProcess for any mutating cmdlet
function Set-ServerState {
    [Cmdlet(VerbsCommon.Set, 'ServerState', SupportsShouldProcess)]
    param(...)
    if ($PSCmdlet.ShouldProcess($server, 'Update state')) { ... }
}

# 5. Pipe output, don't use Write-Host inside functions
# BAD:
Write-Host "Done"
# GOOD:
Write-Verbose "Processing $server" -Verbose
[PSCustomObject]@{ Status = 'Done'; Server = $server } | Write-Output

# 6. Set strict mode at the top of every script / module
Set-StrictMode -Version Latest
```

---

## Handling Findings

### 1. PSScriptAnalyzer `Error` findings

These are blocking issues. Fix before merging:

- **`AvoidUsingConvertToSecureStringWithPlainText` / `AvoidUsingPlainTextForPassword`** — replace literal password strings with `Get-Credential`, `Get-Secret` (Microsoft.PowerShell.SecretManagement), or an environment variable fetched at runtime.
- **`AvoidUsingInvokeExpression`** — refactor the caller; pass a `[ScriptBlock]` parameter instead of a raw string.
- **`AvoidUsingWriteHost` inside functions** — switch to `Write-Verbose`, `Write-Debug`, or return a PSCustomObject.

### 2. PSScriptAnalyzer `Warning` findings

Recommended to fix before merge, but not blocking:

- Add the missing `SupportsShouldProcess` attribute to any function that changes state.
- Rename cmdlets to use singular nouns (`Get-ServerList` → `Get-Server`).
- Replace aliases with full cmdlet names (e.g. `?` → `Where-Object`).

### 3. Gitleaks secrets

**URGENT**: If gitleaks finds a committed secret in a `.ps1` / `.psm1` file:

1. **Rotate the credential immediately** — treat it as exposed.
2. **Rewrite git history** — use `git filter-repo` or the BFG Repo-Cleaner to fully expunge the file from every commit.
3. **Invalidate the old token / key** — assume it is compromised; issue a replacement.
4. **Add a `.gitleaks.toml` allowlist entry** only if the finding is a confirmed false positive.

---

## Tool Versions

Pin versions in CI for reproducibility:

```powershell
# PSScriptAnalyzer uses the bundled AnalysisEngine with PowerShell engine version
$PSVersionTable.PSVersion.Major    # Minimum: 5.1 (Windows PowerShell) or 7.2 (cross-platform)
$PSVersionTable.PSEdition           # Desktop or Core
```

Update `PSScriptAnalyzer` via `Install-Module` to get the latest rule set.
Pin gitleaks by downloading a specific release binary (e.g. `v8.18.1`).

---

## Jenkins Pipeline Reference

The relevant stage is defined in `Jenkinsfile` as `Code Quality & Security Scan` (
`Jenkinsfile:214`–`380`). The stage currently only scans Python sources.
To add a PowerShell scan, extend the stage with:

```powershell
# === [6.5] PSScriptAnalyzer — PowerShell lint + security ===
echo [INFO] [6.5/7] Running PSScriptAnalyzer...
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning `
    -OutputFormat Json -OutFile 'code_scan_results\psa_issues.json'
$psaExit = $LASTEXITCODE
Invoke-ScriptAnalyzer -Path 'powershell\Automation' -Recurse -Severity Error,Warning `
    -OutputFormat Diagnostics | Out-File 'code_scan_results\psa_issues.txt' -Encoding utf8

if ($psaExit -ne 0) {
    echo "PSScriptAnalyzer found issues"
    # Count Error-severity findings from JSON
    try {
        $psaData = Get-Content 'code_scan_results\psa_issues.json' | ConvertFrom-Json
        $errors = $psaData | Where-Object { $_.Severity -eq 'Error' }
        if ($errors) {
            echo "FOUND $($errors.Count) PSScriptAnalyzer Error-level finding(s)"
            if ($strict) { exit 1 }
        }
    } catch {
        echo "Errors detected by PSScriptAnalyzer; check psa_issues.txt"
        if ($strict) { exit 1 }
    }
}
```

---

## Comparative Reference: Python vs PowerShell

| Concern | Python (`docs/python/code_quality.md`) | PowerShell (`this document`) |
|---------|----------------------------------------|------------------------------|
| Style linting | `ruff` | `PSScriptAnalyzer` |
| Deep linting | `pylint` | `PSScriptAnalyzer` (combined) |
| Complexity metrics | `radon mi` / `radon cc` | `PSScriptAnalyzer` (rule-level) |
| Security scanning | `bandit` | `PSScriptAnalyzer` (security rules) |
| Dependency vulns | `safety` | Not yet automated for PS modules |
| Secret detection | `gitleaks` | `gitleaks` (same tool) |
| Build authoring | `pytest` + `pytest-cov` | `Invoke-Pester` (testing doc) |
| CI platform | Jenkins `windows` (Python stage) | Jenkins `windows` (PS stage pending) |

---

## Future Enhancements

- **Strict-mode enforcement as gate**: `Set-StrictMode -Version Latest` required in every script/module, enforced by an `Invoke-Expression` architect rule in the linter ruleset.
- **Module signing**: extend `Set-StrictMode` checks to cover allCodeSigningSignature and block unsigned modules in the pipeline.
- **PSGallery module vulnerability scanning**: run `Install-Module` ´´ once the ecosystem matures (audit installed gallery modules against CVE feeds).
- **Security rule coverage**: expand PSScriptAnalyzer ruleset to include community-created SAST rules (e.g. `PSDSC` disallowed DSC patterns).
- **Gitleaks allowlist**: maintain a per-repo `code_scan_results\.gitleaks.toml` for known false-positive patterns (noise-specific credential names used in test fixtures).
- **Trivy secrets / SAST**: add Trivy secret scanning pass that understands `.ps1` context natively.
- **SonarQube / CodeQL**: forward PSA JSON alongside the existing Python reports and, if compliant, enable GitHub Advanced Security CodeQL for PowerShell SAST.

---

## Change History

- 2026-05-16: Initial PowerShell code quality guide, mirroring `docs/python/code_quality.md`. Covers PSScriptAnalyzer, gitleaks, Jenkins pipeline integration, quality gates, and local workflow.
