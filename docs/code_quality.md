# PowerShell Code Quality & Security Scanning

Automated code quality, linting, and security scanning for PowerShell scripts in CI/CD pipelines.

---

## Overview

Every build runs a **Code Quality & Security Scan** stage that executes:

| Tool | Purpose | Output |
|------|---------|--------|
| **PSScriptAnalyzer** | PowerShell linter + security rules | JSON, text |
| **gitleaks** | Hardcoded secret detection | JSON |

All reports are archived as build artifacts.

---

## PSScriptAnalyzer (PowerShell Linter)

### Command

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck -Force

Invoke-ScriptAnalyzer -Path 'src\powershell\Automation' -Recurse -Severity Error,Warning -OutputFormat Json
```

### Key Rules

| Rule ID | Severity | Description |
|---------|----------|-------------|
| `PSAvoidUsingConvertToSecureStringWithPlainText` | Error | Hardcoded plain-text password |
| `PSAvoidUsingPlainTextForPassword` | Error | Credential in plain text |
| `PSAvoidUsingInvokeExpression` | Error | Code injection risk |
| `PSAvoidUsingCmdletAliases` | Warning | Non-canonical alias in production |
| `PSUseShouldProcessForStateChangingFunctions` | Warning | Missing `ShouldProcess` on mutating functions |

---

## Gitleaks (Secret Detection)

```powershell
gitleaks detect --source=. --report-format json --no-banner
```

**Detects:** AWS keys, GitHub tokens, private keys, bearer tokens, high-entropy strings.

---

## Quality Gates

| Metric | Threshold | Enforcement |
|--------|-----------|-------------|
| **PSScriptAnalyzer**: zero `Error`-severity findings | All `Error` findings must be resolved | Strict |
| **Gitleaks**: zero committed secrets | Any finding triggers credential rotation | Always |

---

## Local Development

```powershell
# Install tools
Install-Module PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck -Force
# winget install gitleaks

# Lint all PowerShell code
Invoke-ScriptAnalyzer -Path 'src\powershell\Automation' -Recurse -Severity Error,Warning

# Secret scan
gitleaks detect --source=. --report-format json --no-banner
```

---

## Quick Reference: Common Quality Rules

```powershell
# 1. Never hardcode credentials
# BAD:
$password = "MySecretP@ss"
# GOOD:
$credential = Get-Secret -Name 'MySecret' -Vault MyVault

# 2. Never use Invoke-Expression on outside input
# BAD:
Invoke-Expression $userInput
# GOOD: Avoid entirely; prefer direct cmdlet calls

# 3. Always validate inputs
param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ })] [string] $Path)

# 4. Use ShouldProcess for mutating cmdlets
[Cmdlet(VerbsCommon.Set, 'ServerState', SupportsShouldProcess)]

# 5. Set strict mode at script top
Set-StrictMode -Version Latest
```

---

## Handling Findings

### PSScriptAnalyzer `Error` Findings

These are blocking — fix before merging:

- **`AvoidUsingConvertToSecureStringWithPlainText`**: Replace literal passwords with `Get-Credential`, `Get-Secret`, or environment variables.
- **`AvoidUsingInvokeExpression`**: Refactor; pass a `[ScriptBlock]` parameter instead of raw string.

### Gitleaks Secrets

**URGENT**: If gitleaks finds a committed secret:

1. Rotate the credential immediately.
2. Rewrite git history with `git filter-repo` or BFG Repo-Cleaner.
3. Invalidate the old token/key.
4. Add false positives to `.gitleaks.toml` if needed.

---

## See Also

- CI integration: [powershell_ci.md](powershell_ci.md)
- Testing: [testing.md](testing.md)