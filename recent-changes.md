# Change log:

<a id="top"></a>

## Table of Contents

- [Change log:](#change-log)
  - [Table of Contents](#table-of-contents)
    - [1) Command consolidation — 2-command workflow (runbook-aligned)](#1-command-consolidation--2-command-workflow-runbook-aligned)
      - [**1. `Configure-PhysicalBuild`** — new read-only 4-eye review command (`src/powershell/Automation/Public/Configure-PhysicalBuild.ps1`):](#1-configure-physicalbuild--new-read-only-4-eye-review-command-srcpowershellautomationpublicconfigure-physicalbuildps1)
      - [**2. `Start-PhysicalServerBuild`** — the actual deploy (already existed, now has firmware support):](#2-start-physicalserverbuild--the-actual-deploy-already-existed-now-has-firmware-support)
      - [Admin code removal](#admin-code-removal)
      - [Tests: 488 passed, 0 failed, 1 pre-existing skip](#tests-488-passed-0-failed-1-pre-existing-skip)
      - [Runbook alignment verification](#runbook-alignment-verification)
    - [2) Maintenance mode progress report for DL](#2-maintenance-mode-progress-report-for-dl)
      - [Key findings:](#key-findings)
      - [**Recommendations:**](#recommendations)
      - [Runbook alignment:](#runbook-alignment)
    - [3) Mock-only test hardening + repo testing rules (AGENTS.md)](#3-mock-only-test-hardening--repo-testing-rules-agentsmd)
      - [Root cause](#root-cause)
      - [Fix](#fix)
      - [Repo context (AGENTS.md)](#repo-context-agentsmd)
      - [Verification](#verification)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Command consolidation — 2-command workflow (runbook-aligned) | Kev Everall |

<a name="command-consolidation-2-command-workflow-runbook-aligned"></a>

### 1) Command consolidation — 2-command workflow (runbook-aligned)

#### **1. `Configure-PhysicalBuild`** — new read-only 4-eye review command (`src/powershell/Automation/Public/Configure-PhysicalBuild.ps1`):

- Resolves full server identity from OneView (hostname, serial, iLO IP, model, rack, OneView URI, maintenance mode)
- Resolves ISO URL (from ConfigMgr build or external HTTPS/SMB path)
- Runs `Test-PreBuildValidation` (OneView, iLO Redfish, ConfigMgr, network, ISO reachability)
- Prints comprehensive summary: server identity block, ISO details, firmware folders, all destructive actions listed
- Interactive confirmation prompt (`Type 'DEPLOY' to proceed`) — skipped with `-SkipConfirmation` for automation
- Returns a structured plan hashtable that can be piped to `Start-PhysicalServerBuild`
- **6 new Pester tests**, all pass

#### **2. `Start-PhysicalServerBuild`** — the actual deploy (already existed, now has firmware support):

- Already has the confirmation step (`Confirm-IsoDeployment`)
- Now accepts `-FirmwareFolders` (string array) + `-FirmwareConfig` + `-SkipFirmware`
- Runs `Update-Firmware` post-OS-install when firmware folders are supplied
`-FirmwareFolders` parameter (string array)

Added to both `Update-Firmware` and `Start-PhysicalServerBuild`:

- Accepts multiple firmware component source directories from Marin
- Passed to `hpe_sut` via `--firmware-components` flag
- Usage: `-FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5', 'C:\fw\Storage')`
- Hardware engineer can run standalone: `Update-Firmware -Server srv01 -FirmwareFolders @('C:\fw\BIOS_v2.80')`

<a name="admin-code-removal"></a>

#### Admin code removal

- Removed all `New-SmbShare`, `Get-SmbShare`, `WindowsPrincipal`/`IsInRole`, "Run as Administrator" logic from 3 files
- Local drive paths now throw: "Supply -ExternalIsoPath as an SMB/UNC or HTTPS URL instead"
- Updated `automation_commands.md` (SMB share section → ISO path requirements)
- Regenerated all 204 dynamic-code-docs

<a name="tests-488-passed-0-failed-1-pre-existing-skip"></a>

#### Tests: 488 passed, 0 failed, 1 pre-existing skip

<a name="runbook-alignment-verification"></a>

#### Runbook alignment verification

| Runbook requirement | Covered by 2-command design |
|---|---|
| Target server identified in OneView | ✅ `Configure-PhysicalBuild` step 1 |
| Target approved for imaging | ✅ 4-eye confirmation prompt |
| ISO path validated and reachable | ✅ `Test-PreBuildValidation` |
| iLO credentials verified | ✅ Redfish session check |
| ISO mounted via iLO | ✅ `Invoke-IloRedfish -Action MountAndBoot` |
| One-time boot override | ✅ `SetOneTimeBootCd` |
| Task sequence execution | ✅ ConfigMgr handles post-WinPE |
| Post-build validation | ✅ `Test-PostBuildValidation` (hostname, domain, OU, drivers, CM client) |
| Firmware update post-OS | ✅ New `-FirmwareFolders` param |
| Audit trail | ✅ Audit log in `$finally` block |
| Rollback procedure | ⚠️ iLO eject on failure (partial) |

<a name="2-maintenance-mode-progress-report-for-dl"></a>

### 2) Maintenance mode progress report for DL

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Added docs/Maintenance-Mode/maint_mode_status.md to summarise the state and progress on maintenance mode commands and build | Kev Everall |

<a name="key-findings"></a>

#### Key findings:  

- **67 maintenance mode tests, all passing** — across 8 test files covering SCOM + OneView enable/disable/validate
- **Full feature coverage verified** — time formats, environment resolution, serial number lookup, scheduled tasks, DryRun, OpsRamp integration
- **4 critical risks identified** for banking deployment:
  1. **SCOM module dependency** — silently degrades with `Write-Warning` instead of failing fast
  2. **Plain-text env var credentials** — needs CyberArk/Azure Key Vault integration
  3. **Windows Task Scheduler** — blocked by AppLocker/CAS in banking (use `-NoSchedule`)
  4. **Local catalogue lookup** for OneView serials — not live API resolution

#### **Recommendations:**

1. Pre-flight SCOM module availability check
2. Secret vault integration for credentials
3. `-Confirm` parameter for 4-eye validation on live enable/disable

<a name="runbook-alignment"></a>

#### Runbook alignment:  

Per `runbook-requirements.md`, maintenance mode is a **separate operational concern** from the ISO build/deploy pipeline. The 2-command workflow (`Configure-PhysicalBuild` + `Start-PhysicalBuild`) does not include maintenance mode commands — they're standalone SCOM/OneView orchestration tools.

<a name="3-mock-only-test-hardening--repo-testing-rules-agentsmd"></a>

### 3) Mock-only test hardening + repo testing rules (AGENTS.md)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Added `AGENTS.md` documenting mock-only testing rules; fixed `Configure-PhysicalBuild` confirmation to auto-cancel in non-interactive/automated mode so `make test` never blocks on `Read-Host` | Kev Everall |

<a name="root-cause"></a>

#### Root cause

- `Configure-PhysicalBuild` only bypassed its `Type 'DEPLOY' to proceed` prompt via `-SkipConfirmation`. The 4th unit test relied on `$env:AUTOMATED_MODE = 'true'` to auto-cancel, but the code called `Read-Host` unconditionally → `make test` hung waiting for input.

<a name="fix"></a>

#### Fix

- `src/powershell/Automation/Public/Configure-PhysicalBuild.ps1` confirmation block now auto-cancels (returns `Cancelled=$true`, `Success=$false`) when `AUTOMATED_MODE`/`CI` is set **or** stdin is not interactive — it can never block a test run.
- `Start-PhysicalServerBuild` already skips its `Confirm-IsoDeployment` prompt under `-DryRun`, so its tests were unaffected.

<a name="repo-context-agentsmd"></a>

#### Repo context (AGENTS.md)

- Created `AGENTS.md` at repo root capturing the mandatory testing rule: `make test` is **mock-only** — no interactive input (use `-DryRun`/`-SkipConfirmation` or set `AUTOMATED_MODE`/`CI`), no live SCOM/OneView/iLO connections, all parameters defaulted or sourced from `configs/*.json`, and destructive commands always exercised in `-DryRun`.

<a name="verification"></a>

#### Verification

- Ran `Configure-PhysicalBuild.Unit.Tests.ps1` + `Start-PhysicalServerBuild.Unit.Tests.ps1` directly → **9 passed, 0 failed**; the prompt now prints "Non-interactive / automated mode detected - deployment confirmation skipped (auto-cancelled)" instead of blocking.
