---
source:  ./scripts/secret-scan.ps1
generated: 2026-09-15
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# secret-scan

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

PowerShell-native, offline secret scanner. It complements - does not replace - GitLab-managed Secret Detection (Gitleaks), which remains the authoritative CI scanner and the only one that scans full git history. This script exists because it adds three things Gitleaks does not do in this repository: 1. A repo-specific policy: findings in Markdown (.md/.markdown) are REPORT-ONLY (documentation legitimately contains example tokens and key snippets); findings in code/config are gate-eligible. 2. A -Fix path that rewrites a hardcoded PowerShell secret into an environment-variable reference ($env:NAME), per DevSecOps practice. 3. No external binary and no network, so it runs in a pre-commit hook and on an air-gapped developer workstation. Rules cover the four categories named by the platform standard: * Tokens        - GitLab / GitHub / AWS / Google / Slack / JWT / bearer * SHA keys      - HMAC / signing / symmetric / salt material * SSH keys      - private blocks (OpenSSH/RSA/EC/DSA/PGP/PuTTY) and public key bodies (authorized_keys material) * Connection strings / storage account keys Findings are matched against .secret-scan-allowlist.json by fingerprint (rule + file + normalised matched text). Risk acceptance is explicit: each entry carries an owner, justification and expiry, and an expired entry is re-raised. Inline suppression is also supported with a trailing comment 'secret-scan:allow' on the offending line, for one-off false positives.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Mode` | 'report'  - always exit 0; findings are still written to all artifacts. 'enforce' - exit non-zero when an active code/config finding is present. |
| `-FailOn` | Minimum severity that gates in 'enforce' mode. |
| `-Fix` | Rewrite hardcoded PowerShell secret literals into $env:NAME references. Creates a .bak backup next to each modified file. Never touches Markdown. Honours -WhatIf / -Confirm. |
| `-Path` | Roots to scan. Defaults to the repository root. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
pwsh -File scripts/secret-scan.ps1 -Mode report
```

<a id="example-2"></a>

### Example 2

```powershell
pwsh -File scripts/secret-scan.ps1 -Mode enforce -FailOn Warning
```

<a id="example-3"></a>

### Example 3

```powershell
pwsh -File scripts/secret-scan.ps1 -Fix -WhatIf
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
    Repository secret scanner: tokens, SHA/HMAC keys, SSH private and public keys.

.DESCRIPTION
    PowerShell-native, offline secret scanner. It complements - does not replace -
    GitLab-managed Secret Detection (Gitleaks), which remains the authoritative
    CI scanner and the only one that scans full git history. This script exists
    because it adds three things Gitleaks does not do in this repository:

      1. A repo-specific policy: findings in Markdown (.md/.markdown) are
         REPORT-ONLY (documentation legitimately contains example tokens and
         key snippets); findings in code/config are gate-eligible.
      2. A -Fix path that rewrites a hardcoded PowerShell secret into an
         environment-variable reference ($env:NAME), per DevSecOps practice.
      3. No external binary and no network, so it runs in a pre-commit hook and
         on an air-gapped developer workstation.

    Rules cover the four categories named by the platform standard:
      * Tokens        - GitLab / GitHub / AWS / Google / Slack / JWT / bearer
      * SHA keys      - HMAC / signing / symmetric / salt material
      * SSH keys      - private blocks (OpenSSH/RSA/EC/DSA/PGP/PuTTY) and
                        public key bodies (authorized_keys material)
      * Connection strings / storage account keys

    Findings are matched against .secret-scan-allowlist.json by fingerprint
    (rule + file + normalised matched text). Risk acceptance is explicit: each
    entry carries an owner, justification and expiry, and an expired entry is
    re-raised. Inline suppression is also supported with a trailing comment
    'secret-scan:allow' on the offending line, for one-off false positives.

.PARAMETER Mode
    'report'  - always exit 0; findings are still written to all artifacts.
    'enforce' - exit non-zero when an active code/config finding is present.

.PARAMETER FailOn
    Minimum severity that gates in 'enforce' mode.

.PARAMETER Fix
    Rewrite hardcoded PowerShell secret literals into $env:NAME references.
    Creates a .bak backup next to each modified file. Never touches Markdown.
    Honours -WhatIf / -Confirm.

.PARAMETER Path
    Roots to scan. Defaults to the repository root.

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Mode report

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Mode enforce -FailOn Warning

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Fix -WhatIf
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
