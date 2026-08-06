# Change log:

<a id="top"></a>

## Table of Contents

  - [1) Command consolidation — 2-command workflow (runbook-aligned)](#1-command-consolidation-2-command-workflow-runbook-aligned)
  - [2) Maintenance mode progress report for DL](#2-maintenance-mode-progress-report-for-dl)
  - [3) Mock-only test hardening + repo testing rules (AGENTS.md)](#3-mock-only-test-hardening-repo-testing-rules-agentsmd)
  - [4) SCOM + OneView maintenance status report (`Get-MaintenanceStatusReport`)](#4-scom-oneview-maintenance-status-report-get-maintenancestatusreport)
  - [5) Profile auto-load fix + Setup-Profile regression test (catches "Connect-OneView not recognized")](#5-profile-auto-load-fix-setup-profile-regression-test-catches-connect-oneview-not-recognized)
  - [6) Parameter-usage guard + non-interactive `-DryRun` (`--DryRun`/`-DryRun`)](#6-parameter-usage-guard-non-interactive-dryrun-dryrun-dryrun)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Command consolidation — 2-command workflow (runbook-aligned) | Kev Everall |
| 2026-08-06 | Parameter-usage guard + non-interactive `-DryRun` (rejected `Connect-OneView --DryRun`) | Kev Everall |

<a name="1-command-consolidation-2-command-workflow-runbook-aligned"></a>

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

<a name="3-mock-only-test-hardening-repo-testing-rules-agentsmd"></a>

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

<a name="4-scom-oneview-maintenance-status-report-get-maintenancestatusreport"></a>

### 4) SCOM + OneView maintenance status report (`Get-MaintenanceStatusReport`)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Added `Get-MaintenanceStatusReport` linking SCOM + HPE OneView; live mode discovers clusters from the SCOM appliance (not the catalogue), `-OneViewHost` param, serial/name cross-link; catalogue used only for `-DryRun` mock | Kev Everall |

<a name="live-discovery-vs-mock-config"></a>

#### Live discovery vs mock config

- **Live mode** discovers clusters/groups and their member servers from the **connected SCOM management group** (`Get-SCOMGroup` + `Get-SCOMClassInstance`), not from `clusters_catalogue.json`. In-memory mappings built from SCOM/OneView **API** calls are allowed.
- **`-DryRun` / `-IncludeLive:$false`** uses `configs/clusters_catalogue.json` (and `servers_catalogue.oneview.json` for the SCOM↔OneView link) as mock data only — static config is never the source for live commands, per `AGENTS.md`.

<a name="oneview-host--serialname-linking"></a>

#### OneView host + serial/name linking

- Added `-OneViewHost` (separate from `-ManagementHost` for SCOM); falls back to `-ManagementHost` when only that is supplied.
- Each server is linked SCOM↔OneView **per server by name (serial where available)** via a live OneView server index; mock mode links from the dry config. Output includes `OneViewLinkMethod` (`Name` / `Serial` / `None` / `Catalogue`).
- Emits CSV (default) with columns: cluster, server, SCOM maintenance mode + window, OneView maintenance mode + link method, power schedule (from catalogue enrichment), and `DataSource` (`Live` / `Partial-*` / `CatalogueOnly`). Read-only; degrades gracefully to `Unknown`.

<a name="verification-1"></a>

#### Verification

- Parse-clean; `Get-MaintenanceStatusReport -IncludeLive:$false` returns 5 pure objects sourced from `configs/`, with `OneViewLinkMethod=Name` for servers present in `servers_catalogue.oneview.json`. Live SCOM discovery path confirmed correct by code review (cannot reach SCOM from this host).

<a name="5-profile-auto-load-fix-setup-profile-regression-test-catches-connect-oneview-not-recognized"></a>

### 5) Profile auto-load fix + Setup-Profile regression test (catches "Connect-OneView not recognized")

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | `Setup-Profile.ps1` now injects the Automation module into the user profile (plus `HPEOneView.1000` guarded by `$IsWindows`); added `Setup-Profile.Tests.ps1` regression test that verifies a fresh shell resolves `Connect-OneView`, and wired it into `make automation-mode-tests` | Kev Everall |

<a name="root-cause-profile"></a>

#### Root cause

- `Connect-OneView` (and all Automation commands) were "not recognized" in a fresh PowerShell window on the test server because the profile produced by `Setup-Profile.ps1` did not import the Automation module.
- The existing `tests/powershell/Connect-OneView.Tests.ps1` could not catch this: it `Import-Module`s the module in `BeforeAll`, so the command is always present during the test. A test that pre-imports the module is *workless* for the "published but not working" failure mode.

<a name="fix-profile"></a>

#### Fix

- `scripts/Setup-Profile.ps1` injected block now imports `Automation.psd1` on every platform, and pre-loads `HPEOneView.1000` inside `if ($IsWindows)` so it loads on the Windows test server but is safely skipped on Linux/macOS where that module cannot load.
- Added a `-ProfileRoot` test hook so the script writes profiles under a temp dir instead of the operator's real `$PROFILE` (test-safe).
- `make setup` (Makefile → `setup-runner.ps1` + `Setup-Profile.ps1`) installs the profile, so a new pwsh / VS Code terminal auto-loads `Connect-OneView`.

<a name="verification-profile"></a>

#### Verification

- New `tests/powershell/Setup-Profile.Tests.ps1` (3 tests): asserts the generated profile imports the Automation module; asserts the OneView pre-load is `$IsWindows`-guarded; launches a fresh `pwsh` that sources the profile and verifies `Connect-OneView` resolves and runs `Connect-OneView -DryRun`. All 3 pass.
- Added `Setup-Profile.Tests.ps1` to the `automation-mode-tests` runner (`scripts/run-automation-mode-tests.ps1`); `make automation-mode-tests` now reports **103 passed, 0 failed** (1 unrelated pre-existing skip). It is also auto-discovered by `make test`.

<a name="6-parameter-usage-guard-non-interactive-dryrun-dryrun-dryrun"></a>

### 6) Parameter-usage guard + non-interactive `-DryRun` (`--DryRun`/`-DryRun`)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-06 | Rejected stray double-dash flags (e.g. `Connect-OneView --DryRun`) and made `-DryRun` non-interactive via a shared `Assert-ParameterNotFlag` helper | Kev Everall |

<a name="root-cause-params"></a>

#### Root cause

- `Connect-OneView --DryRun` did not behave like the intended `-DryRun` switch. PowerShell treats `--` as "end of parameters", so the `DryRun` token was bound to `-ManagementHost` (value `--DryRun`) and the `-DryRun` switch was never set - causing the live path to prompt for credentials against a bogus appliance.
- `Connect-OneView -DryRun` with no host still prompted for a host, i.e. a "dry run" was not fully non-interactive.
- The guard existed as an inline `StartsWith('-')` check in `Connect-OneView` only, so the same class of mistake was not caught elsewhere.

<a name="fix-params"></a>

#### Fix

- Added `src/powershell/Automation/Private/ParameterValidation.ps1` with the shared `Assert-ParameterNotFlag` helper. It rejects any bound string **value** that starts with `-` **or** matches one of the *caller command's own* declared parameter/alias names (introspected from the call stack). Parameter names/aliases and hostnames are never ambiguous, so this is safe and needs no per-command configuration.
- Registered `ParameterValidation.ps1` in `Automation.psm1` `$_privateOrder` so every Public command can call it.
- `Public/Connect-OneView.ps1` replaced its inline guard with `Assert-ParameterNotFlag -Parameters $PSBoundParameters`. `Test-ServerConnectivity` calls the same helper.
- `Connect-OneView -DryRun` (no host) now forwards `-JsonConfig`, so `Test-ServerConnectivity` resolves the appliance from `configs/connection_hosts.json` and stays **non-interactive** (no host prompt). `-DryRun` never reads credentials and never makes a live connection, per the existing config-only rule.
- `Test-ServerConnectivity` live branch now only prompts for a host when the session is **interactive** (real TTY and `AUTOMATED_MODE`/`CI` unset); under automation it fails fast with `ManagementHost is required` instead of hanging.

<a name="verification-params"></a>

#### Verification

- `Connect-OneView --DryRun` -> rejected: `Invalid value for parameter -ManagementHost : '--DryRun'. It looks like a parameter flag ...` (no prompt, no credentials).
- `Connect-OneView -ManagementHost -DryRun` -> rejected by PowerShell (`Missing an argument for parameter 'ManagementHost'`).
- `Connect-OneView -DryRun` -> AVAILABLE [DRY-RUN], host resolved from config, non-interactive.
- `Connect-OneView` (live, no host, `AUTOMATED_MODE=true`) -> fails fast with `ManagementHost is required`, no hang.
- `make automation-mode-tests`: **103 passed, 0 failed**, 1 pre-existing skip; `scripts/lint.ps1` (PSScriptAnalyzer): 146 files, all checks passed.
