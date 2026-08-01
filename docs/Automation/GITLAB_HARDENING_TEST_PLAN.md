# GitLab CI/CD Hardening & Compliance Test Plan — EMIR / DORA

<a id="top"></a>

## Table of Contents

- [1. Standards & Scope](#1-standards-scope)
- [2. How to execute (runner reference)](#2-how-to-execute-runner-reference)
- [3. GitLab CI/CD Hardening Test Scenarios](#3-gitlab-cicd-hardening-test-scenarios)
- [4. Security Gate Posture](#4-security-gate-posture)
- [5. Pipeline Coverage (per run)](#5-pipeline-coverage-per-run)
- [6. Known Findings (baseline)](#6-known-findings-baseline)
- [7. Test Run Summary (filled per cycle)](#7-test-run-summary-filled-per-cycle)

> Controls the security and regulatory posture of the **GitLab CI/CD pipeline**
> that delivers changes to production banking infrastructure (firmware, ISO
> deployment, monitoring suppression). The pipeline is itself an in-scope ICT
> system under EMIR Art. 34 and DORA Art. 8–10. This document records the
> execution evidence for those controls, mirroring the Automation and OneView
> test plans.

<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/08/2026 20:43 UTC</p>
<!-- END:run-date -->

<a name="1-standards-scope"></a>

## 1. Standards & Scope

| Standard | Relevance |
|---|---|
| **EMIR (Reg. 648/2012) Art. 34** | Operational risk; ICT change must be controlled and evidenced |
| **DORA (Reg. 2022/2554) Art. 8–10** | ICT risk management, secure development, change management |
| **EBA/GL/2019/04** | ICT & security risk management guidelines |
| **GitLab secure CI templates** | Secret Detection (all tiers), SAST/Dependency/Container scanning (Ultimate) |

In scope: `.gitlab-ci.yml`, `scripts/ci-security-check.ps1`, `PSScriptAnalyzerSettings.Security.psd1`,
`scripts/run-coverage.ps1`, `scripts/Detect-Runner.ps1`, `scripts/ci/New-ComplianceEvidence.ps1`,
`.security-baseline.json`, and the generated compliance artifacts.

**Critical note:** GitLab ships **no PowerShell SAST analyzer**. The Semgrep SAST
job covers the Python helper and any IaC, but all ~20,000 lines of PowerShell are
scanned *only* by the `sast-powershell` job (PSScriptAnalyzer security ruleset).
If that job is removed, the PowerShell is entirely unscanned.

<a name="2-how-to-execute-runner-reference"></a>

## 2. How to execute (runner reference)

| Command | What it runs |
|---|---|
| `make gitlab-hardening-update` | Interactive: append an evidence row + regenerate HTML |
| `make gitlab-hardening-update-ci` | Non-interactive (env-var driven) for the pipeline `compliance-evidence` job |
| `pwsh -File scripts/ci-security-check.ps1 -Mode report` | Run the PowerShell security gate locally |
| `pwsh -File scripts/run-coverage.ps1 -Threshold 70` | Run the Pester suite with coverage locally |

<a name="3-gitlab-cicd-hardening-test-scenarios"></a>

## 3. GitLab CI/CD Hardening Test Scenarios

Each scenario maps a pipeline control to the regulatory requirement it evidences.
Status: `Not tested` / `Partial` / `Pass` (updated as the controls are verified
against the Bank's GitLab instance).

| # | Control / Job | What it verifies | Maps to | Status |
|---|---|---|---|---|
| 1 | Pipeline not disabled by default (`workflow:` kill-switch via `PIPELINE_ENABLED`) | No blanket `when: never`; an explicit, auditable switch disables it | EMIR change control | Pass |
| 2 | GitLab Secret Detection (Gitleaks, historic scan) | No committed secrets across full history | DORA Art. 9 (sec dev) | Partial (report-only) |
| 3 | `sast-powershell` (PSScriptAnalyzer security ruleset) | Inject/cred-handling/error-suppression in PowerShell | DORA Art. 9 | Partial (report-only) |
| 4 | `sast-powershell` does NOT suppress InvokeExpression / ConvertToSecureString / UsernameAndPassword rules | Gate cannot be weakened by style config | EMIR traceability | Pass |
| 5 | Security findings baselined in `.security-baseline.json` with owner/justification/expiry | Risk-accepted exceptions are accountable | EMIR Art. 34 | Partial (placeholders) |
| 6 | Expired baseline entries auto re-raised | Exceptions cannot be buried indefinitely | EMIR Art. 34 | Pass |
| 7 | Coverage measured + reported per run (`run-coverage.ps1`, Cobertura + JUnit) | Test evidence per pipeline run | DORA Art. 8 | Pass |
| 8 | Coverage threshold declared (70%) and enforced-able (`-EnforceThreshold`) | Quality gate is real, not decorative | DORA Art. 8 | Pass |
| 9 | Dependency Scanning + Container Scanning templates included | Supply-chain CVE detection | DORA Art. 9 | Partial (Ultimate) |
| 10 | `compliance-evidence` artifact produced (retained) per default-branch run | Demonstrable control record | EMIR Art. 34 | Pass |
| 11 | `Detect-Runner.ps1` branches module import on runner OS (`uname`) | Pipeline runs on Linux or Windows runners | Ops resilience | Pass |
| 12 | Secrets never echoed to job logs (`cyberark-bootstrap`) | No credential disclosure in CI output | DORA Art. 9 | Pass |
| 13 | Maintenance jobs `interruptible: false`, gated on `cyberark-bootstrap` | Prod change cannot be half-applied then cancelled | EMIR change control | Pass |
| 14 | Tier-portable (Free/Premium via Code Quality widget; Ultimate via Security Dashboard) | Controls visible regardless of Bank tier | Operability | Partial |
| 15 | `POWERSHELL_IMAGE` is runner OS, not OneView estate; Windows image configurable | Correct mental model for DevOps | Operability | Pass |

<a name="4-security-gate-posture"></a>

## 4. Security Gate Posture

| Setting | Current value | Notes |
|---|---|---|
| `SECURITY_ENFORCEMENT_MODE` | `report` | report-only during remediation window |
| `SECURITY_FAIL_ON` | `Warning` | |
| `GITLAB_TIER_ULTIMATE` | `false` | flip to `true` once Bank tier confirmed |
| `COVERAGE_THRESHOLD` | `70` | enforced via `-EnforceThreshold` at cutover |

**Cutover to `enforce`** requires: (1) AppSec review of every
`.security-baseline.json` entry (owner/justification/expiry set); (2) signed-off
remediation plan for any finding not baselined; (3) a change ticket flipping
`SECURITY_ENFORCEMENT_MODE` to `enforce`. This is a tracked commitment, not a
permanent state. See `docs/compliance/SECURITY_PIPELINE.md`.

<a name="5-pipeline-coverage-per-run"></a>

## 5. Pipeline Coverage (per run)

Code coverage measured by the pipeline `test-unit` job. Recorded per pipeline run.

<!-- BEGIN:gitlab-coverage-rows -->
| Run | Date/Time | Coverage % | Threshold | Enforcement | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | 01/08/2026 20:32:39 UTC | N/A | 70 | report | Baseline snapshot; coverage measured on next pipeline run |
| 2 | 01/08/2026 20:43:27 UTC | N/A | 70 | report | SAST/Secret Detection + security gate + coverage + compliance evidence |
| 3 | 01/08/2026 20:43:27 UTC |  |  |  |  |
<!-- END:gitlab-coverage-rows -->

<a name="6-known-findings-baseline"></a>

## 6. Known Findings (baseline)

The current security gate surfaces 144 active PowerShell findings (gating at
Warning+). These are risk-accepted via `.security-baseline.json` **only once each
entry has owner/justification/expiry** — today they are placeholders and are
re-raised if the gate moves to `enforce`. The highest-severity items that block
an EMIR review (and are tracked as a separate code-remediation program) are:

| # | Finding | Primary location |
|---|---|---|
| 1 | `Set-MaintenanceMode.ps1` builds here-strings with plaintext passwords then `Invoke-Expression` (5 sites) | `Public/Set-MaintenanceMode.ps1` |
| 2 | `cyberark-bootstrap.ps1:76` disables cert validation process-wide, never restored | `scripts/cyberark-bootstrap.ps1` |
| 3 | Audit trail has no actor identity, lost on crash, no tamper-evidence | `Automation.psm1`, `Private/Audit.ps1` |
| 4 | `Set-StrictMode -Off` module-wide | `Automation.psm1:12` |
| 5 | `SkipCertificateCheck = $true` by default + non-overridable bypasses | multiple `Public/*.ps1` |
| 6 | Zero `ShouldProcess`/`-WhatIf` on destructive ops | 0/80 files |
| 7 | Remote execution + all 4 validation functions untested | `src/powershell` |
| 8 | Unverified binary download; `Install-Module -SkipPublisherCheck` | `scripts/setup-runner.ps1` |
| 9 | `.env` committed & not gitignored (values empty today) | `.env` → `.env.example` |
| 10 | Vendored `HPEOneView.1000/Samples/*` contain demo credentials (scanner noise) | `scripts/modules/.../Samples` |

<a name="7-test-run-summary-filled-per-cycle"></a>

## 7. Test Run Summary (filled per cycle)

Execution evidence for each pipeline run that exercised the hardening controls.
Append a row with `make gitlab-hardening-update` or from the GitLab
`compliance-evidence` job.

<!-- BEGIN:gitlab-hardening-evidence-rows -->
| Run | Date/Time | Pipeline/Job | Environment | Result | Ref/Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | 01/08/2026 20:32:39 UTC | gitlab-ci (security + compliance) | GitLab CI | Partial (report-only gate) | Initial hardening controls introduced (SAST/Secret Detection + security gate + coverage + compliance evidence) |
| 2 | 01/08/2026 20:43:27 UTC | gitlab-ci security+compliance | GitLab CI | Partial (report-only gate) | SAST/Secret Detection + security gate + coverage + compliance evidence |
| 3 | 01/08/2026 20:43:27 UTC | gitlab-ci (security + compliance) | GitLab CI | Partial (report-only gate) |  |
<!-- END:gitlab-hardening-evidence-rows -->
