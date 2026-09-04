# PowerShell Code Quality & Security Scanning

<a id="top"></a>

## Table of Contents

- [Overview](#overview)
- [PSScriptAnalyzer (PowerShell Linter)](#psscriptanalyzer-powershell-linter)
  - [Command](#command)
  - [Key Rules](#key-rules)
- [Gitleaks (Secret Detection)](#gitleaks-secret-detection)
- [Quality Gates](#quality-gates)
- [Local Development](#local-development)
- [Quick Reference: Common Quality Rules](#quick-reference-common-quality-rules)
- [Handling Findings](#handling-findings)
  - [PSScriptAnalyzer `Error` Findings](#psscriptanalyzer-error-findings)
  - [Gitleaks Secrets](#gitleaks-secrets)
- [See Also](#see-also)

<a id="overview"></a>

## Overview

Every build runs a **Code Quality & Security Scan** stage executing PSScriptAnalyzer (linter + security rules) and gitleaks (secret detection). Reports are archived as build artifacts.

| Tool | Purpose | Output |
|------|---------|--------|
| **PSScriptAnalyzer** | PowerShell linter + security rules | JSON, text |
| **gitleaks** | Hardcoded secret detection | JSON |

<a id="psscriptanalyzer-powershell-linter"></a>

## PSScriptAnalyzer (PowerShell Linter)

<a id="command"></a>

### Command

```powershell
Install-Module PSScriptAnalyzer -RequiredVersion 1.21.0 -Scope CurrentUser -SkipPublisherCheck -Force -AllowClobber
# setup script handles offline install automatically:
pwsh -File scripts/setup-runner.ps1

Invoke-ScriptAnalyzer -Path 'src\powershell\Automation' -Recurse -Severity Error,Warning -OutputFormat Json
```

<a id="key-rules"></a>

### Key Rules

| Rule ID | Severity | Description |
|---------|----------|-------------|
| `PSAvoidUsingConvertToSecureStringWithPlainText` | Error | Hardcoded plain-text password |
| `PSAvoidUsingPlainTextForPassword` | Error | Credential in plain text |
| `PSAvoidUsingInvokeExpression` | Error | Code injection risk |
| `PSAvoidUsingCmdletAliases` | Warning | Non-canonical alias in production |
| `PSUseShouldProcessForStateChangingFunctions` | Warning | Missing `ShouldProcess` on mutating functions |

<a id="gitleaks-secret-detection"></a>

## Gitleaks (Secret Detection)

```powershell
gitleaks detect --source=. --report-format json --no-banner
```

Detects: AWS keys, GitHub tokens, private keys, bearer tokens, high-entropy strings.

<a id="quality-gates"></a>

## Quality Gates

| Metric | Threshold | Enforcement |
|--------|-----------|-------------|
| **PSScriptAnalyzer**: zero `Error` findings | All `Error` findings resolved | Strict |
| **Gitleaks**: zero committed secrets | Any finding triggers credential rotation | Always |

<a id="local-development"></a>

## Local Development

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck -Force
# winget install gitleaks

Invoke-ScriptAnalyzer -Path 'src\powershell\Automation' -Recurse -Severity Error,Warning
gitleaks detect --source=. --report-format json --no-banner
```

<a id="quick-reference-common-quality-rules"></a>

## Quick Reference: Common Quality Rules

```powershell
# 1. Never hardcode credentials
# BAD:  $password = "MySecretP@ss"
# GOOD: $credential = Get-Secret -Name 'MySecret' -Vault MyVault

# 2. Never use Invoke-Expression on outside input
# BAD:  Invoke-Expression $userInput
# GOOD: avoid entirely; prefer direct cmdlet calls

# 3. Always validate inputs
param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ })] [string] $Path)

# 4. Use ShouldProcess for mutating cmdlets
[Cmdlet(VerbsCommon.Set, 'ServerState', SupportsShouldProcess)]

# 5. Set strict mode at script top
Set-StrictMode -Version Latest
```

<a id="handling-findings"></a>

## Handling Findings

<a id="psscriptanalyzer-error-findings"></a>

### PSScriptAnalyzer `Error` Findings

Blocking - fix before merging:
- **`AvoidUsingConvertToSecureStringWithPlainText`**: replace literal passwords with `Get-Credential`, `Get-Secret`, or environment variables.
- **`AvoidUsingInvokeExpression`**: refactor; pass a `[ScriptBlock]` parameter instead of a raw string.

<a id="gitleaks-secrets"></a>

### Gitleaks Secrets

If gitleaks finds a committed secret:
1. Rotate the credential immediately.
2. Rewrite git history with `git filter-repo` or BFG Repo-Cleaner.
3. Invalidate the old token/key.
4. Add false positives to `.gitleaks.toml` if needed.

<a id="see-also"></a>

## See Also

- CI integration: [powershell_ci.md](powershell_ci.md#top)
- Testing: [testing.md](testing.md#top)
