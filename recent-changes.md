# Change log:

<a id="top"></a>

## Table of Contents

  - [1) Command consolidation — 2-command workflow (runbook-aligned)](#1-command-consolidation-2-command-workflow-runbook-aligned)
  - [2) Maintenance mode progress report for DL](#2-maintenance-mode-progress-report-for-dl)
  - [3) Mock-only test hardening + repo testing rules (AGENTS.md)](#3-mock-only-test-hardening-repo-testing-rules-agentsmd)
  - [4) SCOM + OneView maintenance status report (`Get-MaintenanceStatusReport`)](#4-scom-oneview-maintenance-status-report-get-maintenancestatusreport)
  - [5) Profile auto-load fix + Setup-Profile regression test (catches "Connect-OneView not recognized")](#5-profile-auto-load-fix-setup-profile-regression-test-catches-connect-oneview-not-recognized)
  - [6) Parameter-usage guard + non-interactive `-DryRun` (`--DryRun`/`-DryRun`)](#6-parameter-usage-guard-non-interactive-dryrun-dryrun-dryrun)
  - [7) OneView live-session guard + GuardRail (destructive-action gate)](#7-oneview-live-session-guard-guardrail-destructive-action-gate)
  - [8) Automated live testing harness + captured test results](#8-automated-live-testing-harness-captured-test-results)
  - [9) Parameter rename `ManagementHost` → `OneViewHost` + `Get-OneViewConnectionStatus` overhaul](#9-parameter-rename-managementhost-oneviewhost-get-oneviewconnectionstatus-overhaul)
  - [10) Shared output formatting + `Connect-OneView` rewrite + runbook v2](#10-shared-output-formatting-connect-oneview-rewrite-runbook-v2)
  - [11) `Test-BuildParams` / `_Validate-Request` hardening](#11-test-buildparams-_validate-request-hardening)
  - [12) Parameter rename `SrvrId` → `ServerIdentifier` + wildcard filtering in `Get-OneViewServerList`](#12-parameter-rename-srvrid-serveridentifier-wildcard-filtering-in-get-oneviewserverlist)
  - [13) `Connect-OneView` & `ConvertToWildcardRegex` docs + alias inventory tests](#13-connect-oneview-converttowildcardregex-docs-alias-inventory-tests)
  - [14) Repo hygiene: LF normalization + git workflow docs](#14-repo-hygiene-lf-normalization-git-workflow-docs)
  - [15) Testing-issues documentation (OneView connectivity)](#15-testing-issues-documentation-oneview-connectivity)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Command consolidation — 2-command workflow (runbook-aligned) | Kev Everall |
| 2026-08-06 | Parameter-usage guard + non-interactive `-DryRun` (rejected `Connect-OneView --DryRun`) | Kev Everall |

<a id="1-command-consolidation-2-command-workflow-runbook-aligned"></a>

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

<a id="2-maintenance-mode-progress-report-for-dl"></a>

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

<a id="3-mock-only-test-hardening-repo-testing-rules-agentsmd"></a>

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

- Created `AGENTS.md` at repo root capturing the mandatory testing rules: `make test` must be safe to execute anywhere; tests are written and maintained using the functional unit-test scripts under `make test`; when a test uses mocking, it must avoid interactive input, never connect to live systems, default or source parameters from `configs/*.json`, and run destructive commands in `-DryRun`.

<a name="verification"></a>

#### Verification

- Ran `Configure-PhysicalBuild.Unit.Tests.ps1` + `Start-PhysicalServerBuild.Unit.Tests.ps1` directly → **9 passed, 0 failed**; the prompt now prints "Non-interactive / automated mode detected - deployment confirmation skipped (auto-cancelled)" instead of blocking.

<a id="4-scom-oneview-maintenance-status-report-get-maintenancestatusreport"></a>

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

<a id="5-profile-auto-load-fix-setup-profile-regression-test-catches-connect-oneview-not-recognized"></a>

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

<a id="6-parameter-usage-guard-non-interactive-dryrun-dryrun-dryrun"></a>

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

<a id="7-oneview-live-session-guard-guardrail-destructive-action-gate"></a>

### 7) OneView live-session guard + GuardRail (destructive-action gate)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-10 | Added a live OneView session guard (never drop/reconnect an active session) and a `GuardRail` regex gate that blocks build/deploy actions unless the resolved target server name matches, plus automated live test scripts (`testBuildDeploy.ps1`, `testConnectAndList.ps1`) | Kev Everall |

<a name="live-session-guard"></a>

#### Live Oneylive session guard

- `Connect-OneView` and `Connect-OneViewSession` now refuse to **reconnect to a different appliance** while a live session is active — re-establishing would drop the in-flight connection and risk incidents. They instead reuse the existing session for the same appliance (`-DryRun` is exempt, as it never makes a real connection).
- New `Private/GuardRail.ps1` with `Assert-GuardRail`: a case-insensitive **regex** matched against the resolved server name that aborts with no changes on mismatch (e.g. `-GuardRail 'test\-srv'`). Destructive confirmation (type `YES`) is still required unless `-SkipConfirmation`/`-DryRun`, or the run is automated (auto-cancels unless `-SkipConfirmation`).
- Wired into `Configure-PhysicalBuild`, `Start-PhysicalServerBuild`, `Invoke-IsoDeploy`, `Update-Firmware`, and `Test-ServerConnectivity` so a typo/wrong serial can never overwrite a production server with a Windows ISO + firmware.

<a name="automated-live-scripts"></a>

#### Automated live scripts

- Added `scripts/testBuildDeploy.ps1` (273 lines) and `scripts/testConnectAndList.ps1` (236 lines) to exercise connect/list/build paths against a live appliance without manual stepping.
- `Automation.psd1` + `Automation.psm1` register `GuardRail.ps1`; new `Test-ServerConnectivity.Tests.ps1` (89 lines) and extra `Connect-OneView` / `Configure-PhysicalBuild` / `Start-PhysicalServerBuild` / `Update-Firmware` / `Invoke-IsoDeploy` unit tests.

<a name="verification-7"></a>

#### Verification

- `Connect-OneView` to a second appliance while connected → `Already connected to OneView appliance '…'. Cannot reconnect … Run Disconnect-OneView first` (no drop). `Assert-GuardRail` with a non-matching name aborts with `GUARD RAIL MISMATCH - ACTION BLOCKED` and zero changes. New/updated unit tests pass under `make test`.

<a id="8-automated-live-testing-harness-captured-test-results"></a>

### 8) Automated live testing harness + captured test results

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-12 | Added an automated live-testing harness and captured a dated run of OneView connectivity/build results into `changes.md` | Kev Everall |

<a name="harness"></a>

#### Harness

- `add automated live testing` introduces the scaffolding that drives the live scripts from §7 against a real appliance and records outcomes, so repeated runs are reproducible rather than manual.
- Updated `docs/Automation/automation_commands.md` with the live-test workflow and regenerated the affected `docs/dynamic-code-docs/*` pages to match current function signatures.

<a name="captured-results"></a>

#### Captured results

- `test results 11-08-2026` appended a dated results section to `changes.md` documenting the 2026-08-11 live run (connectivity, server list, build/deploy smoke checks).

<a id="9-parameter-rename-managementhost-oneviewhost-get-oneviewconnectionstatus-overhaul"></a>

### 9) Parameter rename `ManagementHost` → `OneViewHost` + `Get-OneViewConnectionStatus` overhaul

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-13 | Renamed the OneView connectivity parameter from `-ManagementHost` to `-OneViewHost` across commands and tests; rewrote `Get-OneViewConnectionStatus` with a `_Format-ConnectionStatusResult` renderer and `-PassThru` | Kev Everall |

<a name="rename"></a>

#### Parameter rename `ManagementHost` → `OneViewHost`

- Applied consistently in `Connect-OneView`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Set-MaintenanceMode`, `Test-ServerConnectivity`, `Get-MaintenanceStatusReport`, the `OneViewSession`/`ParameterValidation`/`Logging` private helpers, and all corresponding `*.Tests.ps1` + `dynamic-code-docs` pages.
- This aligns OneView connectivity commands with the SCOM-vs-OneView host distinction introduced earlier (see §4/§6) and removes confusion between the SCOM management host and the HPE OneView appliance.

<a name="connection-status-overhaul"></a>

#### `Get-OneViewConnectionStatus` overhaul

- Rewrote the command (138 lines changed) to emit a concise, colour-coded status summary via new `Private/_Format-ConnectionStatusResult`: appliance OneView version, server count, per-server power/health, session source (`HPEOneViewModule` when reusing an active session vs `Explicit`), and module name.
- Added `-PassThru` to return the structured result on the success stream; trimmed `changes.md` (the old sprawling change notes) down by ~400 lines in the same commit.

<a name="verification-9"></a>

#### Verification

- `Get-OneViewConnectionStatus` renders the new summary; `-PassThru` returns the object; all renamed parameters resolve in unit tests (`Connect-OneView`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Set-MaintenanceMode`, `Test-ServerConnectivity`, `Setup-Profile`) — pass under `make test`.

<a id="10-shared-output-formatting-connect-oneview-rewrite-runbook-v2"></a>

### 10) Shared output formatting + `Connect-OneView` rewrite + runbook v2

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-17 | Added `OutputFormatter.ps1` shared renderers + `_Publish-Result`; rewrote `Connect-OneView` to a status-check with `-Json`/`-PassThru` and a `_Format-ConnectivityResult` view; added `docs/Automation/runbook-requirements-v2.md` | Kev Everall |

<a name="output-formatter"></a>

#### Shared output formatting (`OutputFormatter.ps1`)

- `_ConvertTo-FriendlyLabel` (code key → human-readable label), `_Test-IsScalar`, `_Stringify-Cell`, `_Render-KeyValue` (nested structures), `_Format-TableFromObjects`, `_Format-HumanReadable` (recursive indented lists/tables), and `_Publish-Result` (centralized result emission with JSON + custom-view options). Documented each in `docs/dynamic-code-docs/`.

<a name="connect-oneview-rewrite"></a>

#### `Connect-OneView` rewrite

- Now behaves as a **connectivity status check** rather than a bare connect: validates the host from `configs/connection_hosts.json` (`-JsonConfig`) so it stays non-interactive, reuses an active session via the §7 guard, and renders via new `_Format-ConnectivityResult`.
- Added `-PassThru` (return the structured `[hashtable]`) and `-Json` (emit a `ConvertTo-Json -Depth 6 -Compress` string) so the result is machine-consumable in pipelines/automation.

<a name="runbook-v2"></a>

#### Runbook requirements v2

- Added `docs/Automation/runbook-requirements-v2.md` (331 lines) capturing the revised, runbook-aligned requirements; refreshed `automation_commands.md` to match the new parameter/output shapes.

<a name="verification-10"></a>

#### Verification

- `Connect-OneView -DryRun` returns the structured result; `-Json` emits a compact JSON string; `-PassThru` returns the hashtable; `_Format-ConnectivityResult`/`_Format-HumanReadable` exercised by the updated `Connect-OneView.Tests.ps1`. `make test` green.

<a id="11-test-buildparams-_validate-request-hardening"></a>

### 11) `Test-BuildParams` / `_Validate-Request` hardening

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-17 | `Test-BuildParams` now validates and resolves the base ISO path to an iLO boot URL (rejecting local drives) and returns a structured result; `_Validate-Request` + `Validators` tests hardened | Kev Everall |

<a name="root-cause-11"></a>

#### Change

- `Test-BuildParams` shifted from "return a list of error strings" to "validate the base Windows ISO path and **resolve the iLO boot URL**". It now accepts a UNC/SMB or HTTPS path and produces a structured result (`Success`, `IsoUrl` → `cifs://…` or `https://…`), explicitly **rejecting local drive paths** on the automation host (consistent with the §1 admin-code-removal rule).
- `_Validate-Request` tightened its checks; `Validators.Unit.Tests.ps1` expanded (32 lines) to cover the new resolution behaviour. `automation_commands.md` regenerated to reflect the revised contract.

<a name="verification-11"></a>

#### Verification

- `Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'` → `Success=$true`, `IsoUrl='cifs://fileserver/isos/WinSrv2025.iso'`; `https://…` resolves to `https://…`; local-drive paths fail validation. `Validators` unit tests pass.

<a id="12-parameter-rename-srvrid-serveridentifier-wildcard-filtering-in-get-oneviewserverlist"></a>

### 12) Parameter rename `SrvrId` → `ServerIdentifier` + wildcard filtering in `Get-OneViewServerList`

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Renamed `-SrvrId` → `-ServerIdentifier` across commands/tests for consistency; `Get-OneViewServerList` gained a `-Filter` supporting PowerShell-style wildcards for name/health/power | Kev Everall |

<a name="rename-12"></a>

#### Parameter rename `SrvrId` → `ServerIdentifier`

- Reverted the earlier abbreviation (see `8f71040` "abbreviate OneView command parameters") in favour of the explicit, self-documenting `-ServerIdentifier` across `Configure-PhysicalBuild`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`, `Start-PhysicalServerBuild`, `Test-PreBuildValidation`, their unit tests, and `automation_commands.md`.

<a name="wildcard-filtering"></a>

#### Wildcard filtering in `Get-OneViewServerList`

- New `-Filter` parses `health:<value>` / `power:<value>` / `name:<value>` into case-insensitive predicate regexes validated before connecting. Matching is **substring-by-default** (e.g. `health:Critical`, `name:PROD`) and honours PowerShell wildcards (`*`, `?`) via the shared `_ConvertToWildcardRegex` (e.g. `name:PROD-*`, `name:srv-0?`).
- `_ConvertToWildcardRegex` (anchored, case-insensitive) lives alongside the command; unsupported filter forms return a clear `Unsupported -Filter …` error with no connection attempted.

<a name="verification-12"></a>

#### Verification

- `Get-OneViewServerList -Filter 'name:PROD-*'` matches `PROD-SRV-01`; `health:*Warning*` matches warning states; `power:On` filters by power; `name:PROD` substring-matches; an invalid filter returns the `Unsupported -Filter` error. `Get-OneViewServerTarget.Unit.Tests.ps1` (51 lines added) and the renamed-parameter tests pass.

<a id="13-connect-oneview-converttowildcardregex-docs-alias-inventory-tests"></a>

### 13) `Connect-OneView` & `ConvertToWildcardRegex` docs + alias inventory tests

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Documented `Connect-OneView`'s connectivity result handling (`_Complete-ConnectOneViewResult`) and `_ConvertToWildcardRegex`; added `OneViewAliasInventory.Unit.Tests.ps1` to verify documented aliases exist in parameter metadata | Kev Everall |

<a name="docs-13"></a>

#### Documentation

- Added `docs/dynamic-code-docs/_Complete-ConnectOneViewResult.md` describing `Connect-OneView`'s connectivity result object, and `_ConvertToWildcardRegex.md` describing the PowerShell-wildcard → regex conversion used by the §12 filter.
- `automation_commands.md` and `runbook-requirements-v2.md` refreshed to match current signatures.

<a name="alias-inventory-tests"></a>

#### Alias inventory tests

- New `tests/powershell/OneViewAliasInventory.Unit.Tests.ps1` validates that **every documented custom alias is present in the command's parameter metadata**, closing the gap between docs and implementation so an alias documented in `automation_commands.md` can never silently disappear from the code.

<a name="verification-13"></a>

#### Verification

- `OneViewAliasInventory.Unit.Tests.ps1` parses the documented alias table and asserts each alias resolves on the real command; failures surface a missing alias immediately. Passes under `make test`.

<a id="14-repo-hygiene-lf-normalization-git-workflow-docs"></a>

### 14) Repo hygiene: LF normalization + git workflow docs

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-13 | Added `.gitattributes` to normalise line endings (stop `.md`/`.ps1` churn across Stash/GitHub) and documented the rebase-hell-free git workflow in `git_process.md` | Kev Everall |

<a name="line-endings"></a>

#### Line-ending normalization

- Added `.gitattributes` with `*.md`/`*.ps1` (and related text) set to `eol=lf` so cross-platform editors and the Stash↔GitHub mirror stop generating meaningless whole-file diffs on every commit.

<a name="git-workflow-docs"></a>

#### Git workflow docs (`git_process.md`)

- Added `git_process.md` describing a rebase-hell-free flow: `pull.ff only`, a Stash mirror, and a one-`reset` recovery path; later expanded for clarity/structure. (The standalone file was subsequently consolidated/removed in favour of the in-repo guidance — see §15 — leaving `.gitattributes` as the durable change.)

<a id="15-testing-issues-documentation-oneview-connectivity"></a>

### 15) Testing-issues documentation (OneView connectivity)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-14 | Added `wip/testing-issues.md` capturing detailed OneView connectivity test issues and ongoing investigation notes | Kev Everall |

<a name="scope"></a>

#### Scope

- `docs: add detailed testing issues documentation for OneView connectivity tests` introduced `wip/testing-issues.md` (694 lines) logging live-connectivity failures, environment/config gaps, and remediation ideas for the OneView test surface.
- A later commit extended the same working file with further findings (843 lines added), keeping the investigation trail in one place under `wip/` rather than fragmenting it across commit messages.
