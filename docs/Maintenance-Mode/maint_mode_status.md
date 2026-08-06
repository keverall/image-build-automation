# Maintenance Mode Status Report

<a id="top"></a>

## Table of Contents

- [1. Overview](#1-overview)
- [2. Test Coverage](#2-test-coverage)
  - [Full test suite (all modules)](#full-test-suite-all-modules)
- [3. Feature Coverage](#3-feature-coverage)
  - [Enable action](#enable-action)
  - [Disable action](#disable-action)
  - [Validate action](#validate-action)
  - [Environment configuration](#environment-configuration)
- [4. Critical Gaps / Risks](#4-critical-gaps-risks)
  - [⚠️ SCOM PowerShell module dependency](#scom-powershell-module-dependency)
  - [⚠️ Credential handling — env vars vs. secure vault](#credential-handling-env-vars-vs-secure-vault)
  - [⚠️ Scheduled task creation](#scheduled-task-creation)
  - [⚠️ OneView serial number lookup](#oneview-serial-number-lookup)
  - [⚠️ SCOM group resolution](#scom-group-resolution)
- [5. Runbook Alignment](#5-runbook-alignment)
- [6. Recent Changes (last 7 days)](#6-recent-changes-last-7-days)
- [7. Recommendations for Delivery Lead](#7-recommendations-for-delivery-lead)

**Prepared for:** Delivery Lead
**Date:** 2026-08-06
**Environment:** Regulated banking EU (no admin/sudo privileges)
**Report context:** Maintenance mode enable/disable + OneView/SCOM orchestration

---

<a name="1-overview"></a>

## 1. Overview

| Area | Status | Details |
|---|---|---|
| **Core module** | ✅ Stable | `Set-MaintenanceMode` in `src/powershell/Automation/Public/Set-MaintenanceMode.ps1` |
| **Code lines** | ~1,200 | Single file containing function + script-mode CLI entry + helper classes |
| **Exported from module** | ✅ Yes | Listed in `Automation.psm1` `Export-ModuleMember` + `Automation.psd1` `FunctionsToExport` |
| **Dual-mode support** | ✅ SCOM + OneView | `-Mode scom` and `-Mode oneview` both implemented |
| **DryRun support** | ✅ Yes | `-DryRun` skip-all-mutations, mock validate status |
| **Automation-safe** | ✅ Yes | `AUTOMATED_MODE=true` skips interactive credential prompts |

---

<a name="2-test-coverage"></a>

## 2. Test Coverage

| Test file | Tests | Passed | Failed | Skipped |
|---|---|---|---|---|
| `Set-MaintenanceMode.Enable.Tests.ps1` | 8 | 8 | 0 | 0 |
| `Set-MaintenanceMode.Disable.Tests.ps1` | 5 | 5 | 0 | 0 |
| `Set-MaintenanceMode.Unit.Tests.ps1` | 12 | 12 | 0 | 0 |
| `Set-MaintenanceMode.Validation.Tests.ps1` | 7 | 7 | 0 | 0 |
| `Set-ManagementMode.Environment.Tests.ps1` | 27 | 27 | 0 | 0 |
| `New-OneViewMaintenanceScript.Unit.Tests.ps1` | 4 | 4 | 0 | 0 |
| `New-ScomMaintenanceScript.Unit.Tests.ps1` | 3 | 3 | 0 | 0 |
| `Test-ScomMaintenanceConnectivity.ps1` | 1 | 1 | 0 | 0 |
| **Total** | **67** | **67** | **0** | **0** |

<a name="full-test-suite-all-modules"></a>

### Full test suite (all modules)

- **488 passed, 0 failed, 1 pre-existing skip** (in `test-progress-e2e` log file test, unrelated to maintenance mode)

---

<a name="3-feature-coverage"></a>

## 3. Feature Coverage

<a name="enable-action"></a>

### Enable action

- ✅ Relative time: `-Start 'now' -End '+2hours'`, `'+30minutes'`, `'+1day'`
- ✅ Absolute UTC: `-Start '2026-06-11 22:00' -End '2026-06-12 02:00'`
- ✅ ISO 8601: `-Start '2026-06-11T22:00:00'`
- ✅ Default duration (4 hours if `-End` omitted)
- ✅ Environment-based host resolution (`Test` / `Prod`)
- ✅ Host override (`-ManagementHost` / `$env:MAINTENANCE_HOST`)
- ✅ OneView serial-number lookup (`-SerialNumber`)
- ✅ Scheduled task auto-creation (Windows Task Scheduler)
- ✅ `-NoSchedule` to skip task creation
- ✅ `-DryRun` simulation
- ✅ OpsRamp metric/alert emission

<a name="disable-action"></a>

### Disable action

- ✅ Valid cluster ID → success
- ✅ Invalid cluster ID → `Success=$false` with error message
- ✅ Post-disable stabilization wait (`-PostDisableWaitSeconds`, default 120s, 0 to skip)
- ✅ `-DryRun` simulation

<a name="validate-action"></a>

### Validate action

- ✅ DryRun mode with `-MockMaintenanceState` (`enable`, `disable`, `partial`)
- ✅ Live SCOM validation via `SCOMManager.GetMaintenanceStatus()`
- ✅ Live OneView validation via `OneViewClient.GetMaintenanceStatus()`
- ✅ Serial number resolution for OneView
- ✅ Hostname lookup in SCOM clusters

<a name="environment-configuration"></a>

### Environment configuration

- ✅ `connection_hosts.json` with `environments.Test.scom` and `environments.Prod.scom`
- ✅ `connection_hosts.json` with `environments.Test.oneview` and `environments.Prod.oneview`
- ✅ `$env:ENVIRONMENT` fallback when `-Environment` not specified
- ✅ `$env:MAINTENANCE_HOST` override
- ✅ `$env:SCOM_ADMIN_USER` / `$env:SCOM_ADMIN_PASSWORD` credential resolution
- ✅ `$env:ONEVIEW_USER` / `$env:ONEVIEW_PASSWORD` credential resolution
- ✅ Interactive prompt fallback (only when not `AUTOMATED_MODE` and terminal is interactive)
- ✅ Cluster catalogue validation (required fields: `display_name`, `servers`, `scom_group`, `environment`)

---

<a name="4-critical-gaps-risks"></a>

## 4. Critical Gaps / Risks

<a name="scom-powershell-module-dependency"></a>

### ⚠️ SCOM PowerShell module dependency

- **Risk:** SCOM mode requires `OperationsManager` module (`Import-Module OperationsManager`)
- **Current handling:** Caught in try/catch with `Write-Warning` — silently degrades
- **In banking environment:** SCOM management server may not be reachable from the automation host
- **Mitigation needed:** Pre-flight check for SCOM module availability; fail fast with clear error if SCOM mode requested but module unavailable

<a name="credential-handling-env-vars-vs-secure-vault"></a>

### ⚠️ Credential handling — env vars vs. secure vault

- **Risk:** Credentials read from `$env:SCOM_ADMIN_PASSWORD` / `$env:ONEVIEW_PASSWORD` as plain strings
- **Current handling:** Interactive prompt fallback, but env vars stored in plain text
- **Banking requirement:** Production should use a secret vault (CyberArk, Azure Key Vault)
- **Status:** Not yet implemented — documented as future work in AGENTS.md

<a name="scheduled-task-creation"></a>

### ⚠️ Scheduled task creation

- **Risk:** Windows Task Scheduler (`schtasks /create`) requires elevated privileges
- **Current handling:** Wrapped in try/catch, failures are non-fatal (maint mode still applied)
- **Banking environment:** Task Scheduler likely blocked by AppLocker/CAS
- **Mitigation:** `-NoSchedule` flag available; recommend always use in banking

<a name="oneview-serial-number-lookup"></a>

### ⚠️ OneView serial number lookup

- **Risk:** `_Resolve-ServerNameFromSerial()` looks up in `servers_catalogue.oneview.json` (local file), not the OneView API
- **Current handling:** If serial not found in catalogue, returns `"Serial:$SerialNumber"` as cluster name
- **Impact:** Live mode may attempt SCOM operations against a name that doesn't exist in SCOM
- **Status:** Documented as known limitation — catalogue must be kept current

<a name="scom-group-resolution"></a>

### ⚠️ SCOM group resolution

- **Risk:** `_Resolve-ScomServerToCluster()` does hostname-only matching (strips domain)
- **Current handling:** Falls back to `scom_clusters_catalogue.json` if present, otherwise `clusters_catalogue.json`
- **Impact:** Server hostname must exactly match (case-insensitive) catalogue entry
- **Status:** Works for current environment; brittle if hostnames change

---

<a name="5-runbook-alignment"></a>

## 5. Runbook Alignment

Per `docs/Automation/runbook-requirements.md`:

| Runbook requirement | Maintenance mode coverage |
|---|---|
| Change approval for production builds | Not enforced in code — must be process-level |
| Service account permissions | Env vars / interactive prompt only (no secure vault) |
| Auditable hosting | ✅ Audit JSON written to `generated/logs/audit/` |
| Audit logs showing who initiated | ✅ `AuditLogger` captures all enable/disable actions |

---

<a name="6-recent-changes-last-7-days"></a>

## 6. Recent Changes (last 7 days)

| Date | Change | Impact |
|---|---|---|
| 2026-08-06 | Added `-FirmwareFolders` support (unrelated to maint mode) | No impact on maintenance mode |
| 2026-08-06 | Created `Configure-PhysicalBuild` and `-FirmwareFolders` param | Maintenance mode not involved |
| 2026-08-06 | Removed all Administrator/sudo code from ISO path resolver | **Maintenance mode unaffected** — does not use SMB shares or admin checks |
| 2026-08-05 | Added `-SerialNumber` to OneView mode in `Set-MaintenanceMode` | New feature — 3 tests added, all passing |

---

<a name="7-recommendations-for-delivery-lead"></a>

## 7. Recommendations for Delivery Lead

1. **Pre-flight SCOM module check** — Add a check at the top of `Set-MaintenanceMode` that fails early if `-Mode scom` is specified but the `OperationsManager` module isn't importable. This would catch configuration issues before attempting API calls.

2. **Secret vault integration** — Replace `$env:SCOM_ADMIN_PASSWORD` / `$env:ONEVIEW_PASSWORD` env var reads with `Get-Secret` / vault integration. Flag this as a security requirement for production deployment.

3. **Remove scheduled task creation in banking** — The Windows Task Scheduler code path should be conditionally compiled out or guarded by a `$env:ENVIRONMENT -ne 'Banking'` check, since AppLocker/CAS will block it.

4. **Add `-Confirm` parameter** — Currently there's no confirmation prompt for enable/disable actions. While `-DryRun` provides simulation capability, a live enable/disable should require explicit `-Confirm` acknowledgment (aligns with the "4-eye principle" for destructive actions).

5. **Certificate pinning for SCOM/OneView** — Currently uses `-SkipCertificateCheck` in some paths. Banking environments should enforce certificate validation with pinning rather than blanket skip.
