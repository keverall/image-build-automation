# Secret Scanning — Tooling, Policy and Audit Posture

<a id="top"></a>

## Table of Contents

- [1. What runs and where](#1-what-runs-and-where)
- [2. Coverage: tokens, SHA keys, SSH keys](#2-coverage-tokens-sha-keys-ssh-keys)
- [3. Markdown vs code policy](#3-markdown-vs-code-policy)
- [4. Running the scanner](#4-running-the-scanner)
- [5. Risk acceptance: allowlist and inline suppression](#5-risk-acceptance-allowlist-and-inline-suppression)
- [6. Tooling decision: Snyk vs the PowerShell-native stack](#6-tooling-decision-snyk-vs-the-powershell-native-stack)
- [7. Audit red flags found during the secret review](#7-audit-red-flags-found-during-the-secret-review)

---

<a id="1-what-runs-and-where"></a>

## 1. What runs and where

| Layer | Tool | Scope | Gate |
|-------|------|-------|------|
| CI (authoritative) | GitLab Secret Detection (Gitleaks) + `.gitleaks.toml` | Full git history, all files | `allow_failure: true` until cutover |
| CI (repo policy) | `scripts/secret-scan.ps1` | Working tree, Markdown-aware | `allow_failure: true` until cutover |
| Local / pre-commit | Gitleaks pre-commit hook + `scripts/secret-scan.ps1` | Staged working tree | Blocks the commit |
| Developer manual | `make sec-scan` / `sec-scan-enforce` / `sec-scan-fix` | Working tree | Report / fail / fix |

Gitleaks remains authoritative for full-history scanning. `scripts/secret-scan.ps1`
is the offline, dependency-free scanner that adds the repository-specific policy
in §3 and the `-Fix` remediation path. It exists so a developer on an air-gapped
workstation, or a pre-commit hook with no network, still gets the same coverage
for the categories in §2.

<a id="2-coverage-tokens-sha-keys-ssh-keys"></a>

## 2. Coverage: tokens, SHA keys, SSH keys

Both `.gitleaks.toml` and `scripts/secret-scan.ps1` detect:

- **Tokens** — GitLab (`glpat-`, `glptt-`, `gldt-`, `glrt-`, `glsoat-`, `glcbt-`,
  `glft-`, `glimt-`, `glagent-`, `glffct-`), GitHub (`ghp_`, `gho_`, `ghu_`,
  `ghs_`, `ghr_`, `github_pat_`), AWS access key IDs, Google/Firebase API keys,
  Slack (`xox[baprs]-`), JWTs, hardcoded Bearer tokens.
- **SHA / HMAC / signing keys** — values assigned to `*key` / `*secret` / `*salt`
  names containing `sha`, `hmac`, `signing`, `signature`, `symmetric`, `master`,
  `encryption`, or `crypto`.
- **SSH keys** — private key blocks (`BEGIN OPENSSH/RSA/EC/DSA/PGP PRIVATE KEY`),
  PuTTY key files, and public key bodies (`ssh-rsa` / `ssh-ed25519` /
  `ecdsa-sha2-*` followed by an `AAAA...` base64 body).
- **Connection strings / storage keys** — `AccountKey=`, `SharedAccessKey=`,
  `SharedAccessSignature=`, embedded `Password=` / `Pwd=`.
- **Generic assigned secrets** — high-entropy (>3.0 bits/char) literals assigned
  to password/token/secret/API-key names, plus short weak defaults such as
  `"password"` or `"changeme"`.

<a id="3-markdown-vs-code-policy"></a>

## 3. Markdown vs code policy

Documentation legitimately contains example tokens, sample credentials and key
snippets. Scanning them identically to source creates noise that trains review-
ers to ignore the gate. The policy is therefore:

- **Markdown (`.md`, `.markdown`)** — findings are **report-only**. They appear
  in the console and JSON report but never fail the pipeline and are never
  auto-fixed. Placeholder values (`glptt-xxxxxx`, `Secure@123!`, `MySecret...`)
  are expected here.
- **Code and config (everything else)** — findings are **gate-eligible**. In
  `enforce` mode a non-allowlisted finding at or above `-FailOn` exits non-zero.
  With `-Fix`, a hardcoded literal in a `.ps1` / `.psm1` / `.psd1` file is
  rewritten to a `$env:NAME` reference (backup written next to the file).

This split is the reason the repository-local scanner exists alongside Gitleaks,
which has no per-file-type policy.

<a id="4-running-the-scanner"></a>

## 4. Running the scanner

```bash
make sec-scan           # report-only scan (Markdown reported, code listed)
make sec-scan-enforce   # exits non-zero on a code/config finding
make sec-scan-fix       # rewrite hardcoded PowerShell secrets to $env:NAME
```

Direct invocation:

```powershell
pwsh -File scripts/secret-scan.ps1 -Mode enforce -FailOn Warning
pwsh -File scripts/secret-scan.ps1 -Fix -WhatIf     # preview the rewrite
```

Outputs `generated/output/security/secret-scan-report.json` (full, machine-
readable) and `secret-scan-code-quality.json` (GitLab Code Quality, rendered
inline in the MR on every tier).

Pre-commit (optional but recommended):

```bash
pipx install pre-commit
pre-commit install
```

<a id="5-risk-acceptance-allowlist-and-inline-suppression"></a>

## 5. Risk acceptance: allowlist and inline suppression

- One-off false positive on a single line: append a trailing comment
  `secret-scan:allow`.
- Accepted risk: add an entry to `.secret-scan-allowlist.json` keyed by
  fingerprint. An entry is honoured **only** when `owner`, `justification` and a
  future `expires` date are present. `UNASSIGNED` / `UNREVIEWED` entries are
  rejected and re-raised, and expired entries are re-raised automatically.
- Gitleaks has its own narrow allowlist in `.gitleaks.toml` (vendored modules,
  generated output, explicit placeholder syntax). Do not broaden it to hide
  findings; accept them explicitly instead.

<a id="6-tooling-decision-snyk-vs-the-powershell-native-stack"></a>

## 6. Tooling decision: Snyk vs the PowerShell-native stack

**Recommendation: do not add Snyk for this repository.** It is not a good fit
for the workload and would add licence cost with near-zero additional coverage.

- **Snyk Code (SAST)** does not support PowerShell. This repository is
  ~20,000 lines of PowerShell plus two small Python helpers. Snyk Code would
  cover only the Python helpers, which Semgrep already covers.
- **Snyk Open Source (SCA)** needs a supported manifest/lockfile
  (`package.json`, `requirements.txt`, `pyproject.toml`, `*.csproj`, `go.mod`).
  This repository has **none** — dependencies are vendored PowerShell modules.
  Snyk has no meaningful ecosystem to resolve here.
- **Snyk Container** could scan the `POWERSHELL_IMAGE`, but GitLab Container
  Scanning (Trivy) already does that for free in-pipeline.

Where the same budget buys more:

| Need | Snyk | Better fit here |
|------|------|-----------------|
| PowerShell SAST | Not supported | **PSScriptAnalyzer** security ruleset (already wired: `sast-powershell`) |
| Secrets in code + history | Snyk Code/Secrets | **Gitleaks** via GitLab Secret Detection (already wired) + `scripts/secret-scan.ps1` |
| Python SAST | Snyk Code | **Semgrep** (already wired) |
| IaC / container CVEs | Snyk IaC/Container | **Trivy** via GitLab Container/IaC Scanning (already wired) |
| PowerShell supply chain | Not supported | Pin modules by exact version + hash, mirror internally, verify Authenticode (`Save-Module` + `Get-AuthenticodeSignature`) |
| Live-credential verification | Snyk Secrets | **TruffleHog** (`--only-verified`) if false positives become a problem |

If the Bank mandates a single commercial ASPM/SCA vendor, the correct move is to
raise the missing-PowerShell-support gap with the vendor and keep PSScriptAnalyzer
as the PowerShell analyzer, rather than assume Snyk covers it.

<a id="7-audit-red-flags-found-during-the-secret-review"></a>

## 7. Audit red flags found during the secret review

These were found while scanning for tokens/keys. Secret material itself is
clean (no real credentials in tracked files), but the following would be raised
by a security/audit review. Items 1–4 are the highest priority.

| # | Finding | Why it is a red flag | Suggested action |
|---|---------|----------------------|------------------|
| 1 | `.security-baseline.json` has **144 exceptions, all `owner: UNASSIGNED` / `justification: UNREVIEWED`** | The gate script treats these as invalid and re-raises them, so there is effectively no approved risk ledger — a documented control that does not control anything | Triage each entry; assign an owner and expiry, or remediate and regenerate |
| 2 | Security jobs run **report-only** (`SECURITY_ENFORCEMENT_MODE: "report"`, `allow_failure: true` on secret detection, SAST, dependency, container) | No security control can fail the pipeline today; auditors expect a dated cutover plan and evidence | Execute the §2 cutover in `SECURITY_PIPELINE.md`; set a date and flip to `enforce` |
| 3 | Vendored `scripts/modules/` (76 files) is **both gitignored and force-tracked**, and excluded from secret scanning | Third-party code committed without provenance/hashes, with HPE/SCOM sample credentials, and a scanner blind spot | Add to `SECRET_DETECTION_EXCLUDED_PATHS` explicitly (documents intent), record upstream version + SHA256, and migrate to a pinned internal mirror |
| 4 | **Supply chain not pinned**: `Install-Module PSScriptAnalyzer -Force` from PSGallery per job, `Set-PSRepository -InstallationPolicy Trusted`, `-SkipPublisherCheck` (`Ensure-Pester.ps1:71`), mutable `POWERSHELL_IMAGE` tag | Reproducibility and integrity of the build toolchain cannot be evidenced | Pin module versions + hashes, verify Authenticode, mirror internally, pin the image by digest |
| 5 | Repository remotes point at **personal `github.com/keverall` / `gitlab.com/keverall`** accounts while containing client-specific OneView/SCOM/CyberArk automation | Regulated client code on personal accounts is a data-governance and IP concern, even with fail-closed CI instance pinning | Move to an organisation-owned remote; confirm history ownership |
| 6 | Tracked `wip/` scratch directory (scripts + docs, `.gitignore` entry commented out) | Ephemeral code and example credentials on the main branch expand attack surface and audit scope | Untrack `wip/`, re-enable `/wip/` in `.gitignore`, or move to a private branch |
| 7 | Commits authored by `Automation System <automation@example.com>` | Weakens segregation of duties and change attribution under EMIR/DORA | Require attributable, signed commits for production changes |
| 8 | Existing code findings already recorded in `SECURITY_PIPELINE.md` §4 (`Set-StrictMode -Off`, no audit actor identity, `SkipCertificateCheck` defaults, zero `ShouldProcess`) | Independently flagged as EMIR-review blockers and still open | Track as the separate remediation program already described |

Note: the only **hardcoded credential in code** found by this review was a weak
default in `wip/connect-marin.ps1` (`$Defaultadmpassword = "password"`), which has <!-- secret-scan:allow -->
been remediated to `$env:DEFAULTADMPASSWORD`. Markdown example credentials
(`docs/Generic/oneview-auth.md`, `docs/Generic/scom-auth.md`) are report-only by
policy and remain documentation placeholders.
