# Change log:

<a id="top"></a>

## Table of Contents

- [Summary of changes](#summary-of-changes)
- [Change details](#change-details)
  - [46) Configure-PhysicalBuild APPROVE flow fix — Read-Host unblock, param forwarding, banner fix](#46-configure-physicalbuild-approve-flow-fix-read-host-unblock-param-forwarding-banner-fix)
  - [45) OneView maintenance mode display fix — listing/reporting paths now check `maintenanceState`/`maintenanceWindow.maintenanceState`](#45-oneview-maintenance-mode-display-fix-listingreporting-paths-now-check-maintenancestatemaintenancewindowmaintenancestate)
  - [44) OneView maintenance mode: serial/name `-TargetId` resolution + `maintenanceMode` (`On`/`Off`) string truthiness fix](#44-oneview-maintenance-mode-serialname-targetid-resolution-maintenancemode-onoff-string-truthiness-fix)
  - [43) OneView session-check regression fix — use active session, guard empty credentials, remove invalid `-Credential` passthrough + red error output for maintenance mode failures](#43-oneview-session-check-regression-fix-use-active-session-guard-empty-credentials-remove-invalid-credential-passthrough-red-error-output-for-maintenance-mode-failures)
  - [42) OneView Maintenance Mode hardening (session reuse, credentials, default window, DryRun fix) + secret scanning + SSH agent profile management](#42-oneview-maintenance-mode-hardening-session-reuse-credentials-default-window-dryrun-fix-secret-scanning-ssh-agent-profile-management)
  - [41) Data-driven `-Help` test matrix (38 commands), `Update-Firmware` export fix, runner output fix & wip cleanup](#41-data-driven-help-test-matrix-38-commands-update-firmware-export-fix-runner-output-fix-wip-cleanup)
  - [40) Parameter-set mandatory enforcement + `-Help` EXAMPLES link to command reference](#40-parameter-set-mandatory-enforcement-help-examples-link-to-command-reference)
  - [39) Update-Firmware re-added — post-OS HPE firmware flash integrated into the build](#39-update-firmware-re-added-post-os-hpe-firmware-flash-integrated-into-the-build)
  - [38) Consistent newest-first ordering — change-log body, summary table, TOC generator + maintenance guide](#38-consistent-newest-first-ordering-change-log-body-summary-table-toc-generator-maintenance-guide)
  - [37) Unified `-Help` switch across all 28 documented commands + doc-driven `make list-commands`](#37-unified-help-switch-across-all-28-documented-commands-doc-driven-make-list-commands)
  - [36) Documentation & tooling updates — maintenance mode / Checkmake / security pipeline docs, ISO & Firmware parameter options, Makefile + SETUP-GUIDE + doc index refactor](#36-documentation-tooling-updates-maintenance-mode-checkmake-security-pipeline-docs-iso-firmware-parameter-options-makefile-setup-guide-doc-index-refactor)
  - [35) README architecture & branding — SVG icons, technical component overview diagram, MS Configuration Manager flowchart, HPE/OneView/iLO branding](#35-readme-architecture-branding-svg-icons-technical-component-overview-diagram-ms-configuration-manager-flowchart-hpeoneviewilo-branding)
  - [34) Git SSH authentication — PowerShell profile hardening + troubleshooting guides (Fix-GitSSH.md, testing-issue.md)](#34-git-ssh-authentication-powershell-profile-hardening-troubleshooting-guides-fix-gitsshmd-testing-issuemd)
  - [33) HPE OneView Maintenance Mode documentation — enable/disable procedures, alert handling, Windows Forms integration, `.maintenanceMode` refactor, JSON fix, OpsRamp firewall docs](#33-hpe-oneview-maintenance-mode-documentation-enabledisable-procedures-alert-handling-windows-forms-integration-maintenancemode-refactor-json-fix-opsramp-firewall-docs)
  - [32) DOCX documentation replaces RTF — converter fix, full docs coverage, project-root output](#32-docx-documentation-replaces-rtf-converter-fix-full-docs-coverage-project-root-output)
  - [31) Make setup machine-aware PowerShell profile selection (eis19 / prod-VDI / default)](#31-make-setup-machine-aware-powershell-profile-selection-eis19-prod-vdi-default)
  - [30) RTF documentation overhaul — landscape pages, proportional table widths, working TOC links, blockquote tables](#30-rtf-documentation-overhaul-landscape-pages-proportional-table-widths-working-toc-links-blockquote-tables)
  - [29) Credential hardening & CISO vulnerability scan — secure storage/handling of HPE OneView / iLO / SCOM credentials](#29-credential-hardening-ciso-vulnerability-scan-secure-storagehandling-of-hpe-oneview-ilo-scom-credentials)
  - [28) OneView error honesty + abort on failed resolution + iLO credential fallback](#28-oneview-error-honesty-abort-on-failed-resolution-ilo-credential-fallback)
  - [27) Command prune + doc update: deploy flow, deleted commands, bug fixes](#27-command-prune-doc-update-deploy-flow-deleted-commands-bug-fixes)
  - [26) `Get-OneViewServerList` Detail table fixes: empty Model, ROM column overflow, NotApplicable blanking](#26-get-oneviewserverlist-detail-table-fixes-empty-model-rom-column-overflow-notapplicable-blanking)
  - [25) `Connect-OneView` "already connected" message → bold red (no reconnection)](#25-connect-oneview-already-connected-message-bold-red-no-reconnection)
  - [24) `Get-OneViewServerList` field enrichment + robust iLO IP extraction + `Disconnect-OneView` appliance naming](#24-get-oneviewserverlist-field-enrichment-robust-ilo-ip-extraction-disconnect-oneview-appliance-naming)
  - [23) `Get-OneViewServerList` DRY output migration + iLO IP fix + `prune-logs` hardening](#23-get-oneviewserverlist-dry-output-migration-ilo-ip-fix-prune-logs-hardening)
  - [22) Shared `_Publish-Result` / `-PassThru` output migration (15 Public commands)](#22-shared-_publish-result-passthru-output-migration-15-public-commands)
  - [21) Command documentation clarity — firmware/security/utility + repository corrections](#21-command-documentation-clarity-firmwaresecurityutility-repository-corrections)
  - [20) Command documentation clarity — functionality + safe/destructive](#20-command-documentation-clarity-functionality-safedestructive)
  - [19) Test-BuildParams firmware-location validation](#19-test-buildparams-firmware-location-validation)
  - [18) Universal ISO/firmware path resolver fix (DRY consolidation)](#18-universal-isofirmware-path-resolver-fix-dry-consolidation)
  - [17) Get-OneViewConnectionStatus session-reuse guard (no reconnect)](#17-get-oneviewconnectionstatus-session-reuse-guard-no-reconnect)
  - [16) Docs anchor fix — navigable `id` anchors for `make docs` / `make fix-docs`](#16-docs-anchor-fix-navigable-id-anchors-for-make-docs-make-fix-docs)
  - [15) `Connect-OneView` & `ConvertToWildcardRegex` docs + alias inventory tests](#15-connect-oneview-converttowildcardregex-docs-alias-inventory-tests)
  - [14) Parameter rename `SrvrId` → `ServerIdentifier` + wildcard filtering in `Get-OneViewServerList`](#14-parameter-rename-srvrid-serveridentifier-wildcard-filtering-in-get-oneviewserverlist)
  - [13) `Test-BuildParams` / `_Validate-Request` hardening](#13-test-buildparams-_validate-request-hardening)
  - [12) Shared output formatting + `Connect-OneView` rewrite + runbook v2](#12-shared-output-formatting-connect-oneview-rewrite-runbook-v2)
  - [11) Testing-issues documentation (OneView connectivity)](#11-testing-issues-documentation-oneview-connectivity)
  - [10) Repo hygiene: LF normalization + git workflow docs](#10-repo-hygiene-lf-normalization-git-workflow-docs)
  - [9) Parameter rename `ManagementHost` → `OneViewHost` + `Get-OneViewConnectionStatus` overhaul](#9-parameter-rename-managementhost-oneviewhost-get-oneviewconnectionstatus-overhaul)
  - [8) Automated live testing harness + captured test results](#8-automated-live-testing-harness-captured-test-results)
  - [7) OneView live-session guard + GuardRail (destructive-action gate)](#7-oneview-live-session-guard-guardrail-destructive-action-gate)
  - [6) Parameter-usage guard + non-interactive `-DryRun` (`--DryRun`/`-DryRun`)](#6-parameter-usage-guard-non-interactive-dryrun-dryrun-dryrun)
  - [5) Profile auto-load fix + Setup-Profile regression test (catches "Connect-OneView not recognized")](#5-profile-auto-load-fix-setup-profile-regression-test-catches-connect-oneview-not-recognized)
  - [4) SCOM + OneView maintenance status report (`Get-MaintenanceStatusReport`)](#4-scom-oneview-maintenance-status-report-get-maintenancestatusreport)
  - [3) Mock-only test hardening + repo testing rules (AGENTS.md)](#3-mock-only-test-hardening-repo-testing-rules-agentsmd)
  - [2) Maintenance mode progress report for DL](#2-maintenance-mode-progress-report-for-dl)
  - [1) Command consolidation — 2-command workflow (runbook-aligned)](#1-command-consolidation-2-command-workflow-runbook-aligned)

<a id="summary-of-changes"></a>

## Summary of changes

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |  
| 2026-09-21 | `Configure-PhysicalBuild` APPROVE flow fix: removed the redundant `AUTOMATED_MODE`/`CI` env-var gate that blocked the APPROVE `Read-Host` prompt in PowerShell terminals and when stdin was piped, so typing `APPROVE` (or piping `echo APPROVE | pwsh ...`) now proceeds to deploy as the runbook requires; `Read-Host` is wrapped in try/catch (handles `-NonInteractive` without hanging) and the comparison trims whitespace; added explicit `return` + missing parameter forwarding (`-Json`, `-OneViewCredential`, `-DryRun`, `-Quiet`) in `_InvokeBuild` so the deploy path inherits the caller's settings and returns a clean single result; added `-Quiet` to `Configure-PhysicalBuild`; fixed `-ForegroundColor` typo (space after dash) in the maintenance-mode banner that printed literal ` - ForegroundColor White`; tests added/updated. | Kev Everall |
| 2026-09-17 | OneView maintenance mode display fix: `Get-OneViewServerList`, `Get-OneViewServerTarget`, and `Get-MaintenanceStatusReport` were checking a `maintenanceMode` property path that the live `GET /rest/server-hardware` payload does not reliably expose, so servers already in maintenance mode displayed `MaintMode = No`; the listing/target/report paths now check `maintenanceState -eq 'Maintenance'` and `maintenanceWindow.maintenanceState -eq 'Maintenance'` first, then fall back to `state -eq 'MaintenanceMode'` and the legacy `maintenanceMode` truthiness check, so live OneView maintenance mode is reported correctly while preserving compatibility with existing tests and older API shapes. | Kev Everall |
| 2026-09-17 | OneView maintenance mode: `Enable-`/`Disable-OneViewMaintenanceMode` now resolve a serial number or server name passed as `-TargetId` (via `Resolve-OneViewMaintTarget`, returning `ResolvedTarget`/`SerialNumber`/`ResolvedBy`); fixed OneView's `maintenanceMode` being a string (`On`/`Off`) not a boolean — the old `if ($server.maintenanceMode)` truthiness evaluated the truthy string `'Off'` as `$true`, so enable silently skipped in-scope servers, disable toggled servers not actually in maintenance, and status reports (`InMaintenanceMode`/`maintenance_mode`) were inverted; `Get-OneViewServerList`, `Get-OneViewServerTarget`, `New-OneViewMaintenanceScript` and the `OneViewClient` embedded scripts now normalize with `maintenanceMode -notin @('Off', $false, $null)`; tests added. | Kev Everall |
| 2026-09-16 | OneView session-check regression fix: embedded scripts now call `Get-OneViewActiveSession` (checks both `$script:ActiveOneViewSession` and `$global:ConnectedSessions`) before falling back to `$ConnectedSessions`, so live sessions tracked by the Automation module are found even when `$ConnectedSessions` misses them; credential creation is guarded so an empty `ONEVIEW_USER` throws a clear "connect first" error instead of "Cannot bind argument to parameter 'String' because it is an empty string"; `Start-PhysicalServerBuild` `_Enable-OneViewMaintenanceMode`/`_Disable-OneViewMaintenanceMode` no longer pass the invalid `-Credential` parameter to `Set-MaintenanceMode` (which lacks it) — the active OneView session is used directly instead of env vars/config files; `Write-Warning` replaced with `Write-Host -ForegroundColor Red` for OneView maintenance mode enable/disable failures so errors are visually distinct in CI and interactive runs. | Kev Everall |
| 2026-09-16 | OneView maintenance mode hardening: active OneView session reuse (no re-connect when already connected to the correct appliance, with a guard that blocks switching appliances without `Disconnect-OneView` first), actionable credential error messages that now read "OneView credentials are not configured for appliance '<host>'. Connect first with 'Connect-OneView -OneViewHost <host>', or set the ONEVIEW_USER / ONEVIEW_PASSWORD environment variables, or run interactively to be prompted", default 4-hour UTC maintenance window when `-Start`/`-End` are omitted (OneView's enable/disable are pure toggles, so `-Start`/`-End` are inert and recorded for audit only), and a `DryRun` boolean serialization fix in all four `OneViewClient` embedded script blocks (`_SetViaModule`, `_SetViaWinRM`, `_DisableViaModule`, `_DisableViaWinRM`) where `DryRun = '$DryRun'` produced a JSON string `"False"` that `[bool]` cast to `$true` — now `DryRun = $DryRun` emits a proper JSON boolean; `Get-OneViewServerTarget` now reports the `maintenanceMode` (`On`/`Off`) property as Yes/No; secret scanning via pre-commit gitleaks (`.gitleaks.toml`, `.pre-commit-config.yaml`, `scripts/secret-scan.ps1` with flat-array JSON output) and `.gitignore` scratch/generated exclusions; SSH agent management in PowerShell profile scripts (fixed socket path, live-agent reuse, stale-socket cleanup, orphaned-connection prevention) + troubleshooting notes; dynamic docs regeneration | Kev Everall |
| 2026-09-11 | Added a data-driven `-Help` test matrix (`scripts/HelpParamTests.txt`, 38 commands) with a completeness guard that fails when an exported Automation `-Help` command is missing from the list, plus `tests/powershell/HelpParamTests.Unit.Tests.ps1` (44 assertions: output ownership, section structure/order, no exceptions, `-Help` ≡ `Get-CommandHelp`), a focused `scripts/run-help-param-tests.ps1` runner and a `make help-param-tests` target; fixed the root-module `Export-ModuleMember` that omitted `Update-Firmware` (present in the manifest but never actually exported, so `-Help` was unreachable); fixed `Get-CommandHelp` to render a single usage line with no `-Help` token (32 of 38 commands previously showed a redundant `-Help` line because optional run parameters leaked into the `Help` set); fixed the `Write-Output … -NoNewline` literal in the four Pester runners and moved `cyberark-bootstrap.ps1` progress output to `Write-Host` so it no longer pollutes `secrets.env`; retired `HelpSwitch.Unit.Tests.ps1` and retargeted `automation-mode-tests` (dropping four references to deleted test files); corrected §40's mandatory-`-Help`/usage-line wording; and pruned the `wip/` scratch docs, vendored font trees, the superseded root `changes.md` and stale references as part of the wip cleanup (test count 598 → 564) | Kev Everall |
| 2026-09-11 | Enforced mandatory parameters per parameter set across the Public commands: run-path parameters are now `[Parameter(Mandatory, ParameterSetName = 'Run')]` and `-Help` is an optional `[Parameter(ParameterSetName = 'Help')]`, so a bare command surfaces a real "missing mandatory parameter" error instead of demanding `-Help`, while `-Help` alone renders usage without requiring run parameters; `Get-CommandHelp` links its EXAMPLES section to each command's section (clickable GitHub blob URL) in `docs/Automation/automation_commands.md` | Kev Everall |
| 2026-09-04 | Re-introduced `Update-Firmware` (204-line Public command, pruned in change 27) to flash HPE firmware from client-supplied folders after OS installation: new `-Server`, `-FirmwareFolders`, `-Credential`, `-SutToolPath`, and `-SkipConfirmation` parameters; wired into `Start-PhysicalServerBuild` and `Configure-PhysicalBuild` so a build flashes BIOS / iLO / Smart Array / NIC / drivers via HPE SUT/SUM when firmware folders are supplied (or records a clean failure when credentials are absent); module manifest + `automation_commands.md` updated | Kev Everall |
| 2026-09-11 | Made `recent-changes.md` ordering consistent newest-first: physically reordered the `## Change details` sections and the `## Summary of changes` table to `38 … 1` (they were `38, 37, 33, 34, 35, 36, 32 …`), and aligned a truncated §34 date row with its summary row; added `Sort-NumberedTocRuns` to `scripts/Docs.Common.ps1` so `make fix-docs` emits numbered TOC runs in the document's intended numeric direction (change log = newest/highest first); corrected `docs/recent-changes-maintenance.md`, whose "DO NOT run `make fix-docs` on this file" and hand-maintained-TOC guidance no longer matched how the generator behaves | Kev Everall |
| 2026-09-11 | Unified `-Help` switch across all 28 documented commands: added `-Help` support to `Get-RouteMap` (was missing the parameter entirely), `Invoke-OpsRamp` (was missing the parameter entirely), and `Invoke-OpsRampClient` (removed `[OutputType([OpsRamp_Client])]` that threw on systems where the class wasn't loaded, breaking `-Help` on Linux); fixed parameter alias conflicts in `OneViewMaintenanceMode.ps1` where `[Alias('NoSchedule')]` on `$NoSchedule` and `[Alias('Json')]` on `$Json` were invalid (alias == parameter name); rewrote `scripts/list-commands.ps1` as a doc-driven allowlist that parses `docs/Automation/automation_commands.md` for the command list, intersects with actual Public functions, and automatically excludes SCOM-only commands; updated `README.md` and `docs/Automation/automation_commands.md` command count 32 → 28 | Kev Everall |
| 2026-09-04 | Documentation & tooling updates: maintenance mode / Checkmake integration / security-pipeline docs refreshed; ISO & Firmware parameter-options section added to automation commands; Makefile, SETUP-GUIDE, and the documentation index refactored | Kev Everall |
| 2026-09-06 | README visual overhaul: added SVG icons for GitLab/HPE/Microsoft, a technical component overview diagram, and a flowchart reflecting Microsoft Configuration Manager; corrected HPE OneView / iLO branding on the architecture diagram and added `docs/assets/architecture.svg` | Kev Everall |
| 2026-09-10 | Git SSH authentication hardening: PowerShell profiles (`eis19` / `techvdi` / `windowspsprofilecurrentvdi`) gained SSH-agent responsiveness checks + key loading, pinned `GIT_SSH_COMMAND` to Git's bundled ssh with `-i <key> -o IdentitiesOnly=yes`, clear stale `SSH_AUTH_SOCK`, and disable posh-git for performance; new `wip/Fix-GitSSH.md` troubleshooting guide plus extensive `wip/testing-issue.md` SSH troubleshooting revisions (debug output, key-exchange warning, user/git-level SSH override checks) | Kev Everall |
| 2026-09-10 | HPE OneView Maintenance Mode documentation: new `wip/maintenance-mode-code.md` with enable/disable procedures, alert handling, and Windows Forms integration cmdlet instructions; `Set-MaintenanceMode.ps1` now reads the OneView `maintenanceMode` property (`On`/`Off`) instead of the non-existent `MaintenanceModeEnabled`, and `Get-OneViewServerList` reports maintenance state from the same property; fixed a stray `s` typo that broke the embedded JSON conversion in `Set-MaintenanceMode.ps1`; added HPE OpsRamp firewall-rules documentation and a `.maintenanceMode` property refactor across the maintenance-mode scripts | Kev Everall |
| 2026-09-03 | 1. Removed `make rtf-docs` / `make rtf-docs-clean`, `scripts/MD_to_RTF_Converter.py`, and the `docs/rtf/` tree - RTF never resolved TOC/bookmark links in Word (long/digit-leading bookmark names get hashed by Word+pandoc). 2. Added `make word-docs` / `make word-docs-clean`: Markdown -> Word DOCX with native OOXML `<w:bookmarkStart>` / `<w:hyperlink w:anchor>` so TOC and citation links are active the moment the file opens (no field update). 3. Fixed `MD_to_DOCX_Converter.py` `_rewrite_link` bug: the `[text](#anchor)` regex captures the anchor without the leading `#`, so the `target.startswith('#')` guard was always false and no TOC/citation links were rewritten - pandoc then hashed long anchors into `X<hash>` and desynced bookmarks from links. Links now normalize to `secN` / `ref-N`. 4. Disabled pandoc's `tex_math_dollars` extension (`-f markdown-tex_math_dollars`) so PowerShell `$true` / `$false` / `$null` render literally instead of raising 'Could not convert TeX math' warnings. 5. Expanded DOCX coverage to all `docs/**/*.md` + root `*.md` + `wip/*.md`. 6. Relocated output to project-root `docx/`, mirroring `docs/` (no `docs/` prefix, no `docx/docs/` namespace). 7. Per-file graceful error handling: a failed conversion logs `[WARN] failed to convert <file>` and continues - no stack traces. | Kev Everall |
| 2026-09-02 | `make setup` now selects the Windows terminal profile template by computer name so environments with different network constraints get the correct config | Kev Everall |
| 2026-08-29 | RTF documentation overhaul — landscape pages, proportional table widths, working TOC links, blockquote tables | Kev Everall |
| 2026-08-27 | Security hardening of HPE OneView / iLO / SCOM credential handling (TLS-validated CyberArk fetch, secrets passed out-of-band via `-Environment`/`-ArgumentList`, in-process password cache instead of process-env) and a CISO-style vulnerability scan with CI guardrail rules in `ci-security-check.ps1` | Kev Everall |
| 2026-08-27 | `Get-OneViewServerTarget` now classifies REST failures honestly (transport failure → "No connection to OneView"; real HTTP status → "OneView returned HTTP <code> - <reason>") and lets `Auto` mode fall through a rejected filter to the next identifier type; `Configure-PhysicalBuild` + `Start-PhysicalServerBuild` now abort on a failed OneView resolution instead of warning and continuing to the guard rail / DEPLOY prompt; `Test-PreBuildValidation` reuses the OneView credentials for the iLO Redfish check (falls back to an interactive prompt if they are rejected) via a new `-OneViewCredential` (`-OVCred`) | Kev Everall |
| 2026-08-27 | Pruned 5 commands (`Test-ServerList`, `Invoke-IsoDeploy`, `New-IsoBuild`, `Publish-BootIso`, `Update-Firmware`) from source/tests/docs; rewrote `Configure-PhysicalBuild` as the single deploy entry point with `-Deploy`/`-Execute` + `APPROVE`; updated docs, dynamic-code-docs, `testBuildDeploy.ps1`, and fixed 3 runtime bugs in the build pipeline | Kev Everall |
| 2026-08-26 | `Get-OneViewServerList` Detail view: fixed empty Model column, increased ROM column `Max` from 12→30 to prevent overflow misalignment, included header length in width calculation, added truncation safety net for over-width cells, render `NotApplicable` as blank in State Reason, added State Reason to KEY | Kev Everall |
| 2026-08-21 | Replaced the plain "Already connected to OneView appliance '&lt;host&gt;'." message in `Connect-OneView` with a bold-red banner: `HPeOneView IS ALREADY CONNECTED TO <host> NO RECONNECTION ATTEMPTED, IF YOU WISH TO SWITCH APPLIANCES TYPE 'Disconnect-OneView' then reconnect`, shown in both the same-appliance reuse path and the different-appliance refusal path | Kev Everall |
| 2026-08-21 | Enriched `Get-OneViewServerList` to show the connected appliance and the full set of available server fields (Model, Enclosure, Bay, ROM alongside name/serial/power/health/iLO IP); made iLO IP extraction robust to every OneView `mpIpAddresses` shape; `Disconnect-OneView` now names the appliance it disconnected from | Kev Everall |
| 2026-08-21 | Migrated `Get-OneViewServerList` to the shared `_Publish-Result` / `_Emit-*` output pattern (the 16th command, previously the outlier); fixed blank/missing iLO IP across the list/target/connection commands with a shared `_ConvertTo-IloIpAddressList` helper; made the server-list formatter render errors on failure; hardened `prune-logs.ps1` (removed the `-Include` scan hang + layered exception handling); removed `prune-logs` from non-log-creating `make` targets | Kev Everall |
| 2026-08-20 | Migrated 15 Public commands to the shared `_Publish-Result` / `-PassThru` output pattern so interactive runs no longer dump a truncated raw hashtable; added `-Json`/`-PassThru`/`-Quiet` to each and updated their tests | Kev Everall |
| 2026-08-19 | Clarified `Update-Firmware`, `Invoke-WindowsSecurityUpdate`, `Invoke-PowerShellScript`, `Invoke-OpsRampClient` ("What it does" / Destructive) and corrected obsolete ISO-repository references (ISOs/firmware now hosted on network shares, not an HTTPS repo) | Kev Everall |
| 2026-08-19 | Added concise "What it does" / Destructive annotations for `Start-InstallMonitor`, `Invoke-IloRedfish`, `Get-OneViewServerTarget`, `Test-PreBuildValidation`; added a "Safe vs destructive commands" callout; expanded the ISO path-requirements table to all accepted formats; updated `-ExternalIsoPath` help/parameter notes; regenerated `docs/dynamic-code-docs` | Kev Everall |
| 2026-08-19 | `Test-BuildParams` now validates firmware component locations (`-FirmwareFolders`) through the same shared resolver as the ISO, and skips local existence checks for URL locations | Kev Everall |
| 2026-08-19 | Fixed `Resolve-ExternalIsoPath` to accept HTTPS, NFS, `cifs://`, `smb://`, UNC (backslash + forward slash) and mapped network drives; removed duplicate copies from `Invoke-IsoDeploy.ps1` and `Start-PhysicalServerBuild.ps1` so every command resolves paths through one shared helper | Kev Everall |
| 2026-08-18 | Fixed `Get-OneViewConnectionStatus` to reuse the live OneView session (never reconnect) so `-OneViewHost` for the already-connected appliance reports status without a 401; also corrected the empty-string auth error message | Kev Everall |
| 2026-08-18 | Fixed `make docs` / `make fix-docs` (`add-anchors`) so generated TOC anchors use `<a id="…">` (navigable on GitHub / VS Code) instead of the deprecated `<a name="…">`, and stopped the generator from re-stacking a duplicate `id`+`name` anchor on re-runs | Kev Everall |
| 2026-08-18 | Documented `Connect-OneView`'s connectivity result handling (`_Complete-ConnectOneViewResult`) and `_ConvertToWildcardRegex`; added `OneViewAliasInventory.Unit.Tests.ps1` to verify documented aliases exist in parameter metadata | Kev Everall |
| 2026-08-18 | Renamed `-SrvrId` → `-ServerIdentifier` across commands/tests for consistency; `Get-OneViewServerList` gained a `-Filter` supporting PowerShell-style wildcards for name/health/power | Kev Everall |
| 2026-08-17 | `Test-BuildParams` now validates and resolves the base ISO path to an iLO boot URL (rejecting local drives) and returns a structured result; `_Validate-Request` + `Validators` tests hardened | Kev Everall |
| 2026-08-17 | Added `OutputFormatter.ps1` shared renderers + `_Publish-Result`; rewrote `Connect-OneView` to a status-check with `-Json`/`-PassThru` and a `_Format-ConnectivityResult` view; added `docs/Automation/runbook-requirements-v2.md` | Kev Everall |
| 2026-08-14 | Added `wip/testing-issues.md` capturing detailed OneView connectivity test issues and ongoing investigation notes | Kev Everall |
| 2026-08-13 | Added `.gitattributes` to normalise line endings (stop `.md`/`.ps1` churn across Stash/GitHub) and documented the rebase-hell-free git workflow in `git_process.md` | Kev Everall |
| 2026-08-13 | Renamed the OneView connectivity parameter from `-ManagementHost` to `-OneViewHost` across commands and tests; rewrote `Get-OneViewConnectionStatus` with a `_Format-ConnectionStatusResult` renderer and `-PassThru` | Kev Everall |
| 2026-08-12 | Added an automated live-testing harness and captured a dated run of OneView connectivity/build results into `changes.md` | Kev Everall |
| 2026-08-10 | Added a live OneView session guard (never drop/reconnect an active session) and a `GuardRail` regex gate that blocks build/deploy actions unless the resolved target server name matches, plus automated live test scripts (`testBuildDeploy.ps1`, `testConnectAndList.ps1`) | Kev Everall |
| 2026-08-06 | Rejected stray double-dash flags (e.g. `Connect-OneView --DryRun`) and made `-DryRun` non-interactive via a shared `Assert-ParameterNotFlag` helper | Kev Everall |
| 2026-08-06 | `Setup-Profile.ps1` now injects the Automation module into the user profile (plus `HPEOneView.1000` guarded by `$IsWindows`); added `Setup-Profile.Tests.ps1` regression test that verifies a fresh shell resolves `Connect-OneView`, and wired it into `make automation-mode-tests` | Kev Everall |
| 2026-08-06 | Added `Get-MaintenanceStatusReport` linking SCOM + HPE OneView; live mode discovers clusters from the SCOM appliance (not the catalogue), `-OneViewHost` param, serial/name cross-link; catalogue used only for `-DryRun` mock | Kev Everall |
| 2026-08-06 | Added `AGENTS.md` documenting mock-only testing rules; fixed `Configure-PhysicalBuild` confirmation to auto-cancel in non-interactive/automated mode so `make test` never blocks on `Read-Host` | Kev Everall |
| 2026-08-06 | Runbook alignment | Kev Everall |
| 2026-08-06 | Resolves full server identity from OneView, Fix ISO URL, Fix Test-PreBuildValidation, Prints comprehensive summary, added confirmation prompt | Kev Everall |

<a id="change-details"></a>

## Change details

<a id="46-configure-physicalbuild-approve-flow-fix-read-host-unblock-param-forwarding-banner-fix"></a>

### 46) Configure-PhysicalBuild APPROVE flow fix — Read-Host unblock, param forwarding, banner fix

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-21 | `Configure-PhysicalBuild` APPROVE flow fix: removed the redundant `AUTOMATED_MODE`/`CI` env-var gate that blocked the APPROVE `Read-Host` prompt in PowerShell terminals and when stdin was piped, so typing `APPROVE` (or piping `echo APPROVE | pwsh ...`) now proceeds to deploy as the runbook requires; `Read-Host` is wrapped in try/catch (handles `-NonInteractive` without hanging) and the comparison trims whitespace; added explicit `return` + missing parameter forwarding (`-Json`, `-OneViewCredential`, `-DryRun`, `-Quiet`) in `_InvokeBuild` so the deploy path inherits the caller's settings and returns a clean single result; added `-Quiet` to `Configure-PhysicalBuild`; fixed `-ForegroundColor` typo (space after dash) in the maintenance-mode banner that printed literal ` - ForegroundColor White`; tests added/updated. | Kev Everall |

<a name="root-cause-46"></a>

#### Root cause

- **`Read-Host` was never reached in the terminal.** The APPROVE confirmation block gated the prompt on `$isAutomated -or -not $isInteractive`, where `$isInteractive = ([Console]::IsInputRedirected -eq $false) -and ($Host.UI.RawUI -ne $null)`. When stdin was piped or redirected (and even in some terminal configurations), `IsInputRedirected` was `$true`, so `$isInteractive` was `$false` and the code returned the "Non-interactive mode" cancellation *before* ever showing the APPROVE prompt — the operator could not type `APPROVE`.
- **`-Quiet` was missing from `Configure-PhysicalBuild`.** The runbook's `_Publish-Result`/`-Quiet` pattern (used by all sibling commands) was not exposed on `Configure-PhysicalBuild`, so `_Emit` could not suppress human-readable output.
- **`_InvokeBuild` silently dropped parameters.** It forwarded `-PassThru` but not `-Json`, `-OneViewCredential`, `-DryRun`, or `-Quiet` to `Start-PhysicalServerBuild`. The missing `return` also meant any stray success-stream output from `Start-PhysicalServerBuild` would inflate the result into an array.
- **Maintenance-mode banner printed `-ForegroundColor White` as literal text.** Five `Write-Host` lines used `- ForegroundColor White` (space after dash), so PowerShell treated the flag as a string argument instead of a parameter — the literal text appeared in the banner and the colour was never applied.

<a name="fix-46"></a>

#### Fix

- **`Configure-PhysicalBuild.ps1` (APPROVE gate):** removed the `$env:AUTOMATED_MODE`/`$env:CI` env-var check and the `IsInputRedirected` interactive detection. The prompt is now shown whenever the operator runs without `-Deploy`/`-DryRun`, regardless of stdin mode. `Read-Host` is wrapped in `try/catch` so `-NonInteractive` (no console) throws are caught and treated as a non-confirmation rather than a crash; the response is compared with `$response.Trim() -ne 'APPROVE'` to handle stray whitespace.
- **`Configure-PhysicalBuild.ps1` (parameter block):** added `[switch] $Quiet`.
- **`Configure-PhysicalBuild.ps1` (`_Emit`):** forwards `-Quiet:$Quiet` to `_Publish-Result`.
- **`Configure-PhysicalBuild.ps1` (`_InvokeBuild`):** added `return` before `Start-PhysicalServerBuild` and forwarded `-OneViewCredential`, `-DryRun`, `-Json`, `-Quiet`, and `-PassThru` so the deploy inherits the caller's authorization/output settings and returns a single `OrderedDictionary`.
- **`Configure-PhysicalBuild.ps1` (banner):** fixed `- ForegroundColor White` → `-ForegroundColor White` on all five affected `Write-Host` lines in the maintenance-mode notice.
- **`Start-PhysicalServerBuild.ps1`:** (already fixed in this session) `_Step` now uses `Write-Host` instead of `Write-Output` (no step-status strings in the success stream) and the `finally` block suppresses `Ensure-DirectoryExists`/`Save-Json` output with `$null =`.

<a name="verification-46"></a>

#### Verification

- `Configure-PhysicalBuild.Unit.Tests.ps1` → **12 passed, 0 failed** (added APPROVE-prompt and single-hashtable-deploy tests; replaced the env-var-based cancellation test with a mock-based one).
- Full test suite: `make test-unit` → **582 passed, 0 failed**.
- Lint: `make lint` (PSScriptAnalyzer) → **153 files, all checks passed**.
- End-to-end: `printf 'APPROVE\n' | pwsh -NoProfile -Command 'Configure-PhysicalBuild ... -Deploy'` — APPROVE accepted, single `OrderedDictionary` result with `.Success = True` and `.audit_file` pointing to an existing JSON audit log.

<a id="45-oneview-maintenance-mode-display-fix-listingreporting-paths-now-check-maintenancestatemaintenancewindowmaintenancestate"></a>

### 45) OneView maintenance mode display fix — listing/reporting paths now check `maintenanceState`/`maintenanceWindow.maintenanceState`

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-17 | OneView maintenance mode display fix: `Get-OneViewServerList`, `Get-OneViewServerTarget`, and `Get-MaintenanceStatusReport` were checking a `maintenanceMode` property path that the live `GET /rest/server-hardware` payload does not reliably expose, so servers already in maintenance mode displayed `MaintMode = No`; the listing/target/report paths now check `maintenanceState -eq 'Maintenance'` and `maintenanceWindow.maintenanceState -eq 'Maintenance'` first, then fall back to `state -eq 'MaintenanceMode'` and the legacy `maintenanceMode` truthiness check, so live OneView maintenance mode is reported correctly while preserving compatibility with existing tests and older API shapes. | Kev Everall |

<a name="root-cause-45"></a>

#### Root cause

- **`maintenanceMode` is not the reliable live payload path.** The `GET /rest/server-hardware` response used by `Get-OneViewServerList` and `Get-OneViewServerTarget` does not expose maintenance mode through a root-level `maintenanceMode` property in the form the previous check expected. Because `$srv.maintenanceMode` evaluated to `$null`, the expression fell through to `$srv.state -eq 'MaintenanceMode'`, but OneView keeps the lifecycle state as `ProfileApplied`/`Monitored` while maintenance is active, so every server rendered `MaintMode = No`.
- **`Get-MaintenanceStatusReport` mapped the wrong property.** The report path checked `$ovObj.InMaintenanceMode` only; when that property was not set or mapped from the API response, servers in maintenance were reported as `NotInMaintenance`.

<a name="fix-45"></a>

#### Fix

- **`Get-OneViewServerList` and `Get-OneViewServerTarget`** (`maintenance_mode` display): replaced the single-path check with a prioritized cascade: `maintenanceState -eq 'Maintenance'` → `maintenanceWindow.maintenanceState -eq 'Maintenance'` → `state -eq 'MaintenanceMode'` → legacy `maintenanceMode` truthiness fallback. This matches the live OneView server-hardware payload shape while keeping older mocks/tests working.
- **`Get-MaintenanceStatusReport`** (`$ovState`): added `$ovObj.maintenanceState -eq 'Maintenance'` and `$ovObj.maintenanceWindow.maintenanceState -eq 'Maintenance'` as primary signals before the existing `$ovObj.InMaintenanceMode -eq $true` fallback.
- **Enable/disable path unchanged.** `OneViewMaintenanceMode.ps1`, `Set-MaintenanceMode.ps1`, and `New-OneViewMaintenanceScript.ps1` were already using the correct `maintenanceMode -notin @('Off', $false, $null)` normalization for enable/disable operations; only the display/reporting paths were incorrect.

<a name="verification-45"></a>

#### Verification

- `OneViewMaintenanceMode.Unit.Tests.ps1` → **8 passed, 0 failed**.
- `Get-OneViewServerList.Unit.Tests.ps1` → **25 passed, 0 failed**.
- `Get-OneViewServerTarget.Unit.Tests.ps1` → **19 passed, 0 failed**.
- PowerShell parser: `Get-OneViewServerList.ps1`, `Get-OneViewServerTarget.ps1`, and `Get-MaintenanceStatusReport.ps1` parse with zero syntax errors.
- `make lint` (PSScriptAnalyzer) → no new issues at the changed lines.

<a id="44-oneview-maintenance-mode-serialname-targetid-resolution-maintenancemode-onoff-string-truthiness-fix"></a>

### 44) OneView maintenance mode: serial/name `-TargetId` resolution + `maintenanceMode` (`On`/`Off`) string truthiness fix

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-17 | OneView maintenance mode: `Enable-`/`Disable-OneViewMaintenanceMode` now resolve a serial number or server name passed as `-TargetId` (via `Resolve-OneViewMaintTarget`, returning `ResolvedTarget`/`SerialNumber`/`ResolvedBy`); fixed OneView's `maintenanceMode` being a string (`On`/`Off`) not a boolean — the old `if ($server.maintenanceMode)` truthiness evaluated the truthy string `'Off'` as `$true`, so enable silently skipped in-scope servers, disable toggled servers not actually in maintenance, and status reports (`InMaintenanceMode`/`maintenance_mode`) were inverted; `Get-OneViewServerList`, `Get-OneViewServerTarget`, `New-OneViewMaintenanceScript` and the `OneViewClient` embedded scripts now normalize with `maintenanceMode -notin @('Off', $false, $null)`; tests added. | Kev Everall |

<a name="root-cause-44"></a>

#### Root cause

- **Operators pass the serial number as `-TargetId`.** `Enable-`/`Disable-OneViewMaintenanceMode` documented `-TargetId` as "server or scope name" and only resolved a serial via the separate `-SerialNumber` parameter. In practice operators pass the HPE serial (e.g. `CZ22420JCM`) positionally as `-TargetId`; the old resolver only treated `-TargetId` as a server NAME, so a serial there was "not found" and the operation failed.
- **OneView's `maintenanceMode` is a string, not a boolean.** The `ServerHardware` resource exposes maintenance state as the string property `maintenanceMode` with values `On`/`Off`. Every truthiness check in the maintenance-mode code did `if ($server.maintenanceMode)` (or `if (-not $server.maintenanceMode)`). A non-empty string is always truthy in PowerShell, so `'Off'` evaluated to `$true` — the opposite of intent.

<a name="fix-44"></a>

#### Fix

- **Target resolution** (`OneViewMaintenanceMode.ps1`): added `Resolve-OneViewMaintTarget` (with `_ResolveServerBySerial` REST + module fallbacks) used by `Enable-`/`Disable-OneViewMaintenanceMode`. Resolution tries, in order: the explicit `-SerialNumber`, then `-TargetId` as a server/scope name, then `-TargetId` as a serial number (REST `filter=serialNumber=...` then module `Get-OVServer -SerialNumber`). The result carries `ResolvedTarget`, `ResolvedType`, `SerialNumber`, and `ResolvedBy` (`Name`/`Serial`); the cmdlet surfaces `TargetId`, `SerialNumber`, `ResolvedTarget`, `ResolvedBy` on its result hashtable.
- **`maintenanceMode` string normalization** across all maintenance-mode code: replaced bare truthiness with `$inMaint = $server.maintenanceMode -and $server.maintenanceMode -notin @('Off', $false, $null)`. Applied in `OneViewMaintenanceMode.ps1` (all four `OneViewClient` embedded script blocks — enable/disable decision + `already_in_maintenance`/`already_not_in_maintenance` inner checks + `Get-OneViewMaintenanceMode` status `InMaintenanceMode`/`MaintenanceModeState`), `Set-MaintenanceMode.ps1` (embedded enable/disable script blocks + resolution `MaintenanceModeEnabled` + status blocks), `Get-OneViewServerList.ps1` and `Get-OneViewServerTarget.ps1` (`maintenance_mode` Yes/No, also treating `state -eq 'MaintenanceMode'` as in-maintenance), and `New-OneViewMaintenanceScript.ps1` (generated enable/disable branches).
- **Stray typo fix** (`Set-MaintenanceMode.ps1`): removed a stray `s` character that sat between the resolution result hashtable and its `ConvertTo-Json` call, which would have broken the OneView-server resolution path.
- **Tests** (`OneViewMaintenanceMode.Unit.Tests.ps1`): added serial-number-as-`-TargetId` regression tests (positional serial on enable DryRun; explicit `-SerialNumber` on disable DryRun).

<a name="verification-44"></a>

#### Verification

- `OneViewMaintenanceMode.Unit.Tests.ps1` → **8 passed, 0 failed** (was 6; +2 serial-resolution tests).
- PowerShell parser: `OneViewMaintenanceMode.ps1`, `Set-MaintenanceMode.ps1`, `Get-OneViewServerList.ps1`, `Get-OneViewServerTarget.ps1`, `New-OneViewMaintenanceScript.ps1` parse with zero syntax errors.
- Maintenance-mode truthiness simulation: with `maintenanceMode = 'Off'`, the normalized check reports `$inMaint = $false` (previously the bare check reported `$true` and enable was silently skipped); with `maintenanceMode = 'On'` it reports `$true`.
- `Enable-OneViewMaintenanceMode -TargetId CZ22420JCM -OneViewHost bogus -DryRun` resolves the serial and returns `Success = $true`, `ResolvedTarget = CZ22420JCM`.
- `make lint` (PSScriptAnalyzer) → no new issues at the changed lines.

<a id="43-oneview-session-check-regression-fix-use-active-session-guard-empty-credentials-remove-invalid-credential-passthrough-red-error-output-for-maintenance-mode-failures"></a>

### 43) OneView session-check regression fix — use active session, guard empty credentials, remove invalid `-Credential` passthrough + red error output for maintenance mode failures

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-16 | OneView session-check regression fix: embedded scripts now call `Get-OneViewActiveSession` (checks both `$script:ActiveOneViewSession` and `$global:ConnectedSessions`) before falling back to `$ConnectedSessions`, so live sessions tracked by the Automation module are found even when `$ConnectedSessions` misses them; credential creation is guarded so an empty `ONEVIEW_USER` throws a clear "connect first" error instead of "Cannot bind argument to parameter 'String' because it is an empty string"; `Start-PhysicalServerBuild` `_Enable-OneViewMaintenanceMode`/`_Disable-OneViewMaintenanceMode` no longer pass the invalid `-Credential` parameter to `Set-MaintenanceMode` (which lacks it) — the active OneView session is used directly instead of env vars/config files; `Write-Warning` replaced with `Write-Host -ForegroundColor Red` for OneView maintenance mode enable/disable failures so errors are visually distinct in CI and interactive runs. | Kev Everall |

<a name="root-cause-43"></a>

#### Root cause

- **`Connected` is a string in some OneView module versions.** The §42 session-reuse logic filtered active sessions with `$_.Connected -eq $true`, but the `HPEOneView.1000` module populates the `Connected` property as the string `'True'` on certain appliance/firmware combinations. A PowerShell string `'True'` is not equal to the boolean `$true`, so the filter returned `$null` even when a valid session was active.
- **`$ConnectedSessions` misses module-tracked sessions.** The embedded scripts inside `OneViewClient` (run via `Invoke-Expression`) only checked the HPEOneView module's `$ConnectedSessions` global. But `Get-OneViewActiveSession` (the Automation module's own helper) also checks `$script:ActiveOneViewSession`, a module-private session that may hold the active connection when `$ConnectedSessions` does not reflect it. The embedded scripts never called `Get-OneViewActiveSession`, so a live session found by the outer `Enable-OneViewMaintenanceMode` function was invisible to the inner script — it fell through to the credential path.
- **Empty credentials reached `PSCredential`.** When no active session was found and `ONEVIEW_USER`/`ONEVIEW_PASSWORD` env vars were unset, the embedded script created `New-Object System.Management.Automation.PSCredential('', $securePass)` — an empty username — which throws *"Cannot bind argument to parameter 'String' because it is an empty string"* rather than a helpful message.
- **Invalid `-Credential` parameter on `Set-MaintenanceMode`.** `Start-PhysicalServerBuild`'s `_Enable-OneViewMaintenanceMode`/`_Disable-OneViewMaintenanceMode` passed `-Credential $OneViewCredential` to `Set-MaintenanceMode`, but `Set-MaintenanceMode` has no `-Credential` parameter — the parameter was silently ignored by PowerShell's `$PSBoundParameters` splatting, so the OneView mode path never received credentials and always fell through to env-var resolution.
- **`Write-Warning` blended failures into normal pipeline output.** `Start-PhysicalServerBuild` used `Write-Warning` for OneView maintenance mode enable/disable failures. In CI logs and interactive builds the yellow warning is visually indistinguishable from `Write-Host` output and is easily missed, especially when the build continues after the failure.

<a name="fix-43"></a>

#### Fix

- **Embedded scripts use `Get-OneViewActiveSession` first** (`OneViewMaintenanceMode.ps1`, `Set-MaintenanceMode.ps1`): all 16 active-session checks in the `OneViewClient` embedded script blocks now call `Get-OneViewActiveSession` (which checks both `$script:ActiveOneViewSession` and `$global:ConnectedSessions`) before falling back to the `$ConnectedSessions` filter. A live session tracked by either mechanism is now detected.
- **Credential creation guarded** (`OneViewMaintenanceMode.ps1`, `Set-MaintenanceMode.ps1`): before `New-Object System.Management.Automation.PSCredential($OVUser, $securePass)` or the inline `New-Object PSCredential($this.Username, ...)` in `_ResolveServerByName`, the script checks `if (-not $OVUser) { throw "No active OneView session and ONEVIEW_USER is not set for appliance '<host>'. Connect first with 'Connect-OneView -OneViewHost <host>', or set ONEVIEW_USER / ONEVIEW_PASSWORD environment variables." }`. An empty username now produces a clear, actionable error instead of the opaque *Cannot bind argument to parameter 'String'*.
- **Removed invalid `-Credential` passthrough** (`Start-PhysicalServerBuild.ps1`): `_Enable-OneViewMaintenanceMode` and `_Disable-OneViewMaintenanceMode` no longer accept a `-OneViewCredential` parameter or pass `-Credential` to `Set-MaintenanceMode`. The active OneView session (established via `Connect-OneView`) is reused directly — env vars/config files are not used for credentials in this path. Call sites in `Start-PhysicalServerBuild` updated to match.
- **Maintenance mode failures render in bold red** (`Start-PhysicalServerBuild.ps1`): replaced `Write-Warning` with `Write-Host -ForegroundColor Red` in `_Enable-OneViewMaintenanceMode`, `_Disable-OneViewMaintenanceMode`, and the top-level `Start-PhysicalServerBuild` OneView maintenance enable/disable `catch` blocks. Success paths remain green; failures are now unmistakable.

<a name="verification-43"></a>

#### Verification

- `OneViewMaintenanceMode.Unit.Tests.ps1` → **6 passed, 0 failed**.
- Full test suite: `make test` → **572 passed, 0 failed**.
- PowerShell parser: `OneViewMaintenanceMode.ps1`, `Set-MaintenanceMode.ps1`, and `Start-PhysicalServerBuild.ps1` parse with zero syntax errors.
- `Enable-OneViewMaintenanceMode -TargetId srv01 -OneViewHost bogus -DryRun` completes without throwing.
- `make lint` (PSScriptAnalyzer) → **153 files, all checks passed**.

<a id="42-oneview-maintenance-mode-hardening-session-reuse-credentials-default-window-dryrun-fix-secret-scanning-ssh-agent-profile-management"></a>

### 42) OneView Maintenance Mode hardening (session reuse, credentials, default window, DryRun fix) + secret scanning + SSH agent profile management

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-16 | OneView maintenance mode hardening: active OneView session reuse (no re-connect when already connected to the correct appliance, with a guard that blocks switching appliances without `Disconnect-OneView` first), actionable credential error messages that now read "OneView credentials are not configured for appliance '<host>'. Connect first with 'Connect-OneView -OneViewHost <host>', or set the ONEVIEW_USER / ONEVIEW_PASSWORD environment variables, or run interactively to be prompted", default 4-hour UTC maintenance window when `-Start`/`-End` are omitted (OneView's enable/disable are pure toggles, so `-Start`/`-End` are inert and recorded for audit only), and a `DryRun` boolean serialization fix in all four `OneViewClient` embedded script blocks (`_SetViaModule`, `_SetViaWinRM`, `_DisableViaModule`, `_DisableViaWinRM`) where `DryRun = '$DryRun'` produced a JSON string `"False"` that `[bool]` cast to `$true` — now `DryRun = $DryRun` emits a proper JSON boolean; `Get-OneViewServerTarget` now reports the `maintenanceMode` (`On`/`Off`) property as Yes/No; secret scanning via pre-commit gitleaks (`.gitleaks.toml`, `.pre-commit-config.yaml`, `scripts/secret-scan.ps1` with flat-array JSON output) and `.gitignore` scratch/generated exclusions; SSH agent management in PowerShell profile scripts (fixed socket path, live-agent reuse, stale-socket cleanup, orphaned-connection prevention) + troubleshooting notes; dynamic docs regeneration | Kev Everall |

<a name="root-cause-42"></a>

#### Root cause

- **`DryRun` was serialized as a string, not a boolean.** In all four `OneViewClient` embedded script blocks (`_SetViaModule`, `_SetViaWinRM`, `_DisableViaModule`, `_DisableViaWinRM` — `src/powershell/Automation/Public/OneViewMaintenanceMode.ps1`), the output hashtable assigned `DryRun = '$DryRun'` — single-quoted inside a double-quoted here-string. The single quotes forced the `[bool]` value into a string literal (`"True"`/`"False"`), which `ConvertTo-Json` serialized as `"DryRun":"False"`, and `[bool]$result.DryRun` then cast that non-empty string to `$true` — so `DryRun` was always reported as `$true` regardless of the actual value. `Set-MaintenanceMode` and `Get-MaintenanceStatusReport` are affected because they delegate to these `OneViewClient` methods.
- **Credentials were required even when an active OneView session existed.** `Enable-OneViewMaintenanceMode` and `Disable-OneViewMaintenanceMode` always demanded `OneViewHost` + credentials, ignoring an already-connected session — forcing redundant authentication on a machine already connected to the correct appliance, and producing a cryptic "credentials not configured" error even when a valid session was active.
- **Omitting `-Start`/`-End` passed `$null` into `[DateTime]`-typed parameters.** The `OneViewClient.SetMaintenance` method is typed `[DateTime]` for `StartDt`/`EndDt`; binding `$null` threw "Cannot convert null to type 'system.datetime'" when the user omitted the schedule parameters, despite OneView's `Enable-OVMaintenanceMode`/``Disable-OVMaintenanceMode` being pure toggles that take no schedule.
- **`Get-OneViewServerTarget` did not report maintenance-mode state.** Operators had no way to see at a glance whether OneView already had a server in maintenance, requiring a separate `Get-OneViewServerList` call.
- **No secret scanning in CI or pre-commit.** Credentials, SHA/HMAC keys, and SSH private/public keys could be committed without detection.
- **SSH agent management was ad-hoc.** PowerShell profile scripts spawned agents without reusing existing ones or cleaning up stale sockets, leading to orphaned processes.

<a name="fix-42"></a>

#### Fix

- **DryRun boolean serialization** (`OneViewMaintenanceMode.ps1`): changed `DryRun = '$DryRun'` → `DryRun = $DryRun` (unquoted) in all 4 embedded script blocks, so the generated code emits a bare boolean literal that serializes to JSON `true`/`false` and round-trips correctly through `[bool]$result.DryRun`.
- **Active session reuse** (`OneViewMaintenanceMode.ps1`): `Enable-OneViewMaintenanceMode` and `Disable-OneViewMaintenanceMode` now call `Get-OneViewActiveSession` to detect an existing OneView session; if the appliance host is not supplied but an active session exists, that host is used; if connected to the *same* appliance, credentials are not required (session reuse); if connected to a *different* appliance, a clear error directs the user to `Disconnect-OneView` first.
- **Actionable credential error messages** (`OneViewMaintenanceMode.ps1`): the credential-guard error now reads "OneView credentials are not configured for appliance '<host>'. Connect first with 'Connect-OneView -OneViewHost <host>', or set the $userEnv / $passEnv environment variables, or run interactively to be prompted. (The credentials block of oneview_config.json is only used for -DryRun.)" instead of the prior terse message.
- **Default 4-hour maintenance window** (`OneViewMaintenanceMode.ps1`): when `-Start`/`-End` are omitted, the schedule defaults to now (UTC) / +4h so the `[DateTime]`-typed parameters are never bound to `$null`. The comment block documents that OneView's enable/disable are pure toggles and `-Start`/`-End` are inert in the standalone cmdlets (recorded for audit only).
- **`Get-OneViewServerTarget`** now reports the OneView `maintenanceMode` (`On`/`Off`) property as Yes/No in `Details.maintenance_mode`, and the formatted output includes a `maint=Yes/No` field.
- **Secret scanning** (`.gitleaks.toml`, `.pre-commit-config.yaml`, `scripts/secret-scan.ps1`): pre-commit integration scans for tokens, SHA/HMAC keys, and SSH private/public keys; `secret-scan.ps1` JSON output standardized to a flat array; `.gitignore` updated to exclude local scratch workspace and generated documents.
- **SSH agent profile management** (`wip/prodtechvdi.ps1`, `prodvdicurrent.ps1`): detect and reuse a live SSH agent, implement a fixed socket path, clean up stale `SSH_AUTH_SOCK` pointers, and prevent orphaned connections; added troubleshooting notes for SSH failures.
- **Tests + docs**: `OneViewMaintenanceMode.Unit.Tests.ps1` expanded with credential-guard and default-scheduling regression tests; `Get-OneViewServerTarget.Unit.Tests.ps1` added; `docs/Automation/automation_commands.md`, `docs/Generic/powershell_api_reference.md`, `docs/Generic/testing.md`, and `docs/dynamic-code-docs/` regenerated.

<a name="verification-42"></a>

#### Verification

- `OneViewMaintenanceMode.Unit.Tests.ps1` → **6 passed, 0 failed**.
- DryRun round-trip simulation: `DryRun:$false` → JSON `"DryRun":false` → `[bool]` = `False`; `DryRun:$true` → JSON `"DryRun":true` → `[bool]` = `True` (both correct; previously both reported `$true`).
- PowerShell parser: `OneViewMaintenanceMode.ps1` parses with zero syntax errors.
- `Enable-OneViewMaintenanceMode -TargetId srv01 -OneViewHost bogus -DryRun` completes without throwing.
- `make lint` (PSScriptAnalyzer) reports no new issues at the changed lines.

<a id="41-data-driven-help-test-matrix-38-commands-update-firmware-export-fix-runner-output-fix-wip-cleanup"></a>

### 41) Data-driven `-Help` test matrix (38 commands), `Update-Firmware` export fix, runner output fix & wip cleanup

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-11 | Added a data-driven `-Help` test matrix, fixed the `Update-Firmware` export and `Get-CommandHelp` usage-line rendering, corrected the Pester runner and CyberArk bootstrap output, and completed the `wip/` cleanup (test count 598 → 564) | Kev Everall |

<a name="root-cause-41"></a>

#### Root cause

- **`-Help` coverage was a hardcoded list that had already drifted.** `HelpSwitch.Unit.Tests.ps1` carried its own command array (30 entries) that no longer matched `scripts/HelpParamTests.txt` (28 documented commands, which itself omitted 10 exported commands that expose `-Help`). Nothing tied the two together, and no test proved the rendered help actually belonged to the invoked command or that every canonical section was present.
- **`Update-Firmware` was documented and manifested but never exported.** `Automation.psd1` `FunctionsToExport` listed `Update-Firmware` and `docs/Automation/automation_commands.md` documented it, but the root module's `Export-ModuleMember -Function @(...)` in `Automation.psm1` omitted it. `Get-Command Update-Firmware` therefore failed, so the command and its `-Help` were unreachable — the §39 changelog claim that it was re-exported was only true of the manifest, not of runtime.
- **`Get-CommandHelp` only skipped a `-Help`-*only* parameter set.** `Private/Help.ps1` skipped a set whose set-specific parameters were exactly `{ Help }`. Because optional run parameters are not scoped to a named set, they leak into the `Help` set, so it is not `-Help`-only and the skip never fired — 32 of 38 commands rendered a second, redundant usage line containing `[-Help <switch>]`.
- **Four Pester runners printed a literal `-NoNewline`.** The summary blocks used `Write-Output "…" -NoNewline`; `Write-Output` has no `-NoNewline` parameter, so PowerShell emitted the token itself as an extra output line.
- **`wip/` had accumulated scratch docs and vendored font trees.** `wip/Fix-GitSSH.md`, `wip/changes.md`, `CONSOLIDATION_SUMMARY.md`, `IMPLEMENTATION_SUMMARY.md`, `questions.md`, `setup-error.md`, `HPe-Openview-maintenance-mode.ps1`, `tempcachyospsprofile.ps1` and the `wip/Hack` + `wip/Meslo` font trees were no longer maintained, and `testing-issue.md` was a 551-line captured transcript.

<a name="fix-41"></a>

#### Fix

- **`scripts/HelpParamTests.txt` is now the single source of truth (38 commands).** The 28 documented commands plus the 10 other exported OneView commands that expose `-Help` (`Get-OneViewMaintenanceMode`, `Get-OneViewVersion`, `New-CIPipelineCtrl`, `New-GitLabCtrl`, `New-IRequestCtrl`, `New-OneViewMaintenanceScript`, `New-SchedulerCtrl`, `Run-IRequest`, `Start-PhysicalServerBuild`, `Test-ClusterId`).
- **`tests/powershell/HelpParamTests.Unit.Tests.ps1` (new).** Reads the matrix and, per command, asserts `-Help` throws nothing and writes no error records; the `NAME`, `SYNOPSIS`, `SYNTAX`, `PARAMETERS`, `EXAMPLES` sections are present and ordered; the `NAME` line, every `SYNTAX` usage line and the `PARAMETERS` table belong to *that* command with no `-Help` token; `EXAMPLES` links `automation_commands.md`; and `-Help` output is byte-identical to `Get-CommandHelp -Name`. A completeness guard fails if any exported non-SCOM Automation command exposing `-Help` is missing from the matrix.
- **`scripts/run-help-param-tests.ps1` (new) + `make help-param-tests`.** Focused runner with a JUnit report and the standard summary block; added to `.PHONY` alongside the other group-test targets.
- **`Automation.psm1`**: `Export-ModuleMember` now includes `Update-Firmware`, making the §39 manifest claim true at runtime.
- **`Private/Help.ps1`**: the USAGE renderer drops `-Help`-bearing sets when a dedicated run set exists, never prints a `-Help` token, and falls back to `Name [<CommonParameters>]` for commands that take nothing but `-Help` — so every command renders one clean usage line.
- **Pester runners** (`run-tests.ps1`, `run-maint-mode-tests.ps1`, `run-automation-mode-tests.ps1`, `run-test-progress-rpt-tests.ps1`): summary `Write-Output … -NoNewline` → `Write-Host … -NoNewline`.
- **`scripts/cyberark-bootstrap.ps1`**: progress/banner lines changed from `Write-Output` to `Write-Host` (removing the literal `-NoNewline` token) so that in `-ExportForGitLab` mode stdout contains only the GitLab dotenv `KEY=value` lines and the generated `secrets.env` is no longer polluted with banner text.
- **Retired `HelpSwitch.Unit.Tests.ps1`** (superseded) and retargeted `scripts/run-automation-mode-tests.ps1` at `HelpParamTests`, removing four references to test files deleted in earlier prunes (`New-IsoBuild`, `Publish-BootIso`, `Invoke-IsoDeploy`, `Update-Firmware` unit tests).
- **Changelog corrections**: §40's summary/body rows no longer claim `-Help` is `[Parameter(Mandatory, ParameterSetName = 'Help')]` (it is intentionally optional) and no longer reference the deleted `HelpSwitch.Unit.Tests.ps1`.
- **wip cleanup**: deleted the scratch docs and vendored font trees listed above; trimmed `wip/testing-issue.md` to its SSH root-cause summary (structure re-anchored and re-TOC'd); reworded the SCOM comment in `New-ScomMaintenanceScript.ps1` and the note in `configs/scom_config.json` that pointed at the removed `wip/HPe-Openview-maintenance-mode.ps1`; and removed the superseded root `changes.md` (long out of date, now maintained here in `recent-changes.md`).

<a name="verification-41"></a>

#### Verification

- `make help-param-tests` → **44 passed, 0 failed**; `make automation-mode-tests` → **166 passed, 0 failed**.
- `make test` → **564 passed, 0 failed** (598 − 78 retired `HelpSwitch` tests + 44 new `HelpParamTests`); `make lint` → PSScriptAnalyzer **149 files clean**, checkmake clean, Ruff clean.
- Renderer check: **0 of 38** commands render a `-Help` token in `SYNTAX`; **38 of 38** render at least one usage line.
- `Get-Command Update-Firmware` resolves and `Update-Firmware -Help` renders its reference.
- Completeness guard sensitivity: reverting the matrix to the original 28 lines fails the guard, naming exactly the 10 missing commands.
- `wip/testing-issue.md` passes `scripts/bitbucket-md-anchor-toc.ps1 -InputFileName wip/testing-issue.md -DryRun`.

> Historical note: the wip cleanup removed `wip/Fix-GitSSH.md`, `wip/changes.md` and the other scratch docs. References to them in §34 and older entries are historical; the referenced design/requirements were reworded into the code and configs that remain.

<a id="40-parameter-set-mandatory-enforcement-help-examples-link-to-command-reference"></a>

### 40) Parameter-set mandatory enforcement + `-Help` EXAMPLES link to command reference

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-11 | Enforced mandatory parameters per parameter set across the Public commands: run-path parameters are now `[Parameter(Mandatory, ParameterSetName = 'Run')]` and `-Help` is an optional `[Parameter(ParameterSetName = 'Help')]`, so a bare command surfaces a real "missing mandatory parameter" error instead of demanding `-Help`, while `-Help` alone renders usage without requiring run parameters; `Get-CommandHelp` links its EXAMPLES section to each command's section (clickable GitHub blob URL) in `docs/Automation/automation_commands.md` | Kev Everall |

<a name="root-cause-40"></a>

#### Root cause

- **Mandatory applied to every parameter set.** Parameters were declared `[Parameter(Mandatory)]` with no `ParameterSetName`, so the mandatory flag bound to *all* sets — including the new `-Help` set. Typing `-Help` alone (e.g. `Configure-PhysicalBuild -Help`) first forced the run-only mandatory params (e.g. `-ServerIdentifier`), defeating the help switch.
- **`-Help` was an unbound optional switch.** With no parameter set, PowerShell could not separate the help path from the run path, so the help guard fired but the command was still subject to the global mandatory requirement.
- **EXAMPLES were duplicated or empty.** `Get-CommandHelp` rendered an EXAMPLES block from comment-based help that was usually absent, while the runnable examples lived only in `docs/Automation/automation_commands.md`, so `-Help` never pointed operators to the real, tested examples.

<a name="fix-40"></a>

#### Fix

- **Run-path mandatory, Help-path explicit** in the Public commands — e.g. `Configure-PhysicalBuild` / `Start-PhysicalServerBuild` `$ServerIdentifier` → `[Parameter(Mandatory, ParameterSetName = 'Run')]`; `-Help` → an optional `[Parameter(ParameterSetName = 'Help')]` in `Configure-PhysicalBuild`, `Start-PhysicalServerBuild`, `Connect-OneView`, `Control` (`Run-CIPipeline` / `Run-IRequest` / `Run-Scheduler` / `Run-GitLab`), `Get-OneViewServerTarget`, `Invoke-GitLabMaintenanceTrigger`, `Invoke-IloRedfish`, `Invoke-OpsRampClient`, `Invoke-PowerShellScript`, `Invoke-PowerShellWinRM`, `New-OneViewMaintenanceScript`, `New-ScomConnection`, `New-ScomMaintenanceScript`, `New-Uuid`, `OneViewMaintenanceMode`, `Set-MaintenanceMode`, `Start-AutomationOrchestrator`, `Start-InstallMonitor`, `Test-ClusterId`, `Test-PostBuildValidation`, `Test-PreBuildValidation`, `Update-Firmware`, and `Update-WindowsSecurity`.
- **Explicit run-parameter guards** in `Control.ps1` (`New-CIPipelineCtrl`, `New-IRequestCtrl`, `New-SchedulerCtrl`): `$Params` / `$FormData` / `$TaskParams` are no longer globally mandatory, so each now `Write-Error`s with a clear message and returns when the value is missing — preserving the prior hard-fail on the run path without forcing it on the help path.
- **`Get-CommandHelp` (`Private/Help.ps1`)**: added a `$commandDocAnchors` map (command → section anchor in `automation_commands.md`); the USAGE renderer drops `-Help`-bearing parameter sets when a dedicated run set exists and never prints a `-Help` token, so each command renders a single, non-redundant usage line; mandatory status is computed only against non-`Help` parameter sets; the EXAMPLES section now emits a clickable link — resolved to a full GitHub blob URL via `git remote` when available — to the per-command reference section instead of duplicating examples.

<a name="verification-40"></a>

#### Verification

- `Configure-PhysicalBuild -Help` renders help without demanding `-ServerIdentifier`.
- `Configure-PhysicalBuild` (no params) → PowerShell parameter-binding error *"Missing an argument for parameter 'ServerIdentifier'…"* (correct run-path enforcement).
- `Get-CommandHelp -Name Configure-PhysicalBuild` shows a single run usage line with `-ServerIdentifier` marked mandatory (no `-Help`-only line).
- `HelpParamTests.Unit.Tests.ps1` (data-driven over `scripts/HelpParamTests.txt`) validates the `-Help` switch, section structure and parameter-set wiring across every listed command — passes.
- `make test` green for the affected commands.

<a id="39-update-firmware-re-added-post-os-hpe-firmware-flash-integrated-into-the-build"></a>

### 39) Update-Firmware re-added — post-OS HPE firmware flash integrated into the build

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-04 | Re-introduced `Update-Firmware` (204-line Public command, pruned in change 27) to flash HPE firmware from client-supplied folders after OS installation: new `-Server`, `-FirmwareFolders`, `-Credential`, `-SutToolPath`, and `-SkipConfirmation` parameters; wired into `Start-PhysicalServerBuild` and `Configure-PhysicalBuild` so a build flashes BIOS / iLO / Smart Array / NIC / drivers via HPE SUT/SUM when firmware folders are supplied (or records a clean failure when credentials are absent); module manifest + `automation_commands.md` updated | Kev Everall |

<a name="root-cause-39"></a>

#### Root cause

- **Firmware flashing lost in the command prune.** Change 27 removed `Update-Firmware` (and its tests/docs) when collapsing to a 2-command workflow, but the runbook still requires post-OS firmware flashing on the freshly built server, so the capability had to be restored as a first-class, gated step rather than re-implemented ad hoc each time.

<a name="fix-39"></a>

#### Fix

- **`Update-Firmware.ps1` restored** (204 lines): WinRMs into the built server (`-Server` / `-Credential`, or `OS_ADMIN_USER` / `OS_ADMIN_PASSWORD` from env / CyberArk) and runs HPE SUT/SUM over the supplied `-FirmwareFolders`; missing credentials → recorded as failed (not silently skipped).
- **Build integration**: `Start-PhysicalServerBuild` and `Configure-PhysicalBuild` now invoke `Update-Firmware` post-OS when firmware folders are provided, behind the existing `-GuardRail` gate.
- **Manifest + docs**: `Automation.psd1` re-exports `Update-Firmware`; `automation_commands.md`, `runbook-requirements-v2.md`, and the testing docs updated for the new firmware flow.

<a name="verification-39"></a>

#### Verification

- `Update-Firmware -Server srv01 -FirmwareFolders @('C:\fw\BIOS_v2.80')` flashes firmware standalone.
- `Configure-PhysicalBuild -ServerIdentifier srv01 -FirmwareFolders …` carries the firmware step into the deploy flow.
- `Import-Module Automation.psd1` resolves `Update-Firmware` and the script passes the PowerShell parser; `automation_commands.md` lists the command with What-it-does / Destructive annotations.

<a id="38-consistent-newest-first-ordering-change-log-body-summary-table-toc-generator-maintenance-guide"></a>

### 38) Consistent newest-first ordering — change-log body, summary table, TOC generator + maintenance guide

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-11 | Made `recent-changes.md` ordering consistent newest-first: physically reordered the `## Change details` sections and the `## Summary of changes` table to `38 … 1` (they were `38, 37, 33, 34, 35, 36, 32 …`), and aligned a truncated §34 date row with its summary row; added `Sort-NumberedTocRuns` to `scripts/Docs.Common.ps1` so `make fix-docs` emits numbered TOC runs in the document's intended numeric direction (change log = newest/highest first); corrected `docs/recent-changes-maintenance.md`, whose "DO NOT run `make fix-docs` on this file" and hand-maintained-TOC guidance no longer matched how the generator behaves | Kev Everall |

<a name="root-cause-38"></a>

#### Root cause

- **TOC was emitted in raw document order.** `Build-CanonicalContent` (`scripts/Docs.Common.ps1`) appended each H2/H3 heading to `$toc` as it walked the file, so the TOC always mirrored the physical order of the sections rather than any logical ordering.
- **Physical order and logical order had drifted apart.** The detail sections were appended over time as `38, 37, 33, 34, 35, 36, 32, 31 … 1`, and the `## Summary of changes` table had its own third ordering (`33, 34, 35, 36, 38, 37, 32 …`). Only the TOC was being normalised, so the file read in three different sequences.
- **§34's date row was truncated** relative to its summary-table row (missing the "(debug output, key-exchange warning, user/git-level SSH override checks)" clause), which broke the one-to-one mapping between a section and its summary row.
- Because the generator had no notion of numbered entries, no amount of re-running `make fix-docs` could correct it.

<a name="fix-38"></a>

#### Fix

- **`Sort-NumberedTocRuns` (new, `scripts/Docs.Common.ps1`)** — walks the collected TOC entries and finds each maximal run of consecutive, same-level, numbered entries (title matching `^\s*(\d+)\s*\)`, e.g. `37) …`). Each run is reordered into the numeric direction the document already intends, inferred from the run's own first vs last number:
  - `first > last` → **descending** (change log: newest / highest first)
  - `first < last` → **ascending** (procedural doc: `1..N`)
  - equal → left alone.

  Inferring the direction from the run keeps the change safe for ordinary docs: an already-correctly-ordered ascending document sorts to itself, so nothing moves. Un-numbered entries and entries at other heading levels keep their document order, and a run that is already correctly ordered is untouched — so the operation is idempotent.
- **TOC entries are now stored structurally.** `$toc` changed from `List[string]` (pre-formatted `- [title](#anchor)` lines) to `List[object]` holding `Level` / `Title` / `Anchor`, so entries can be reordered before the TOC block is rendered; the two-space-per-level indentation is applied at render time. Anchors stay attached to their own entry, so links remain correct regardless of ordering.

- **`recent-changes.md` reordered (content-preserving).** The 38 detail sections were re-sorted to `38, 37, 36, 35, 34, 33, 32 … 1`, each block moved whole (its `<a id>` anchor, heading, date row, root cause / fix / verification). The `## Summary of changes` rows were re-sorted to the same sequence by mapping each row back to its section. Both reorders were verified as pure permutations — the line multiset before and after is identical, so no content was dropped or duplicated.
- **§34's row aligned** — the section's date row now carries the same full text as its summary-table row (the fuller wording was kept).
- **`docs/recent-changes-maintenance.md` corrected.** Three statements no longer matched the tooling:
  - *"DO NOT run `make fix-docs` on this file"* → replaced with **"Running `make fix-docs` (this is how the TOC is regenerated)"**, documenting what `Build-CanonicalContent` actually does: strips and rebuilds the single TOC, adds H2/H3 anchors, sorts numbered runs via `Sort-NumberedTocRuns`, and **preserves** the manual `<a name="…-NN">` sub-anchors (they precede `####`, and only H2/H3 anchors are regenerated). The old duplicate/broken-`#root-cause-3` warning no longer applies.
  - *"They are NOT auto-regenerated by `make fix-docs`"* → the TOC **is** auto-generated (do not hand-edit it); only the summary table is hand-maintained.
  - *"Order by date, not by number"* → **newest first = highest number first**; the number is the sequence. Also documents that the body must be kept physically ordered, not just the TOC.
  - Stale `32, 31, …` / `§32 → §33` / `§30` examples updated to `NN` / current max.

<a name="verification-38"></a>

#### Verification

- **All three orders now agree**: `## Change details` body, `## Table of Contents` and `## Summary of changes` each read **38, 37, 36, 35, 34, 33, 32 … 1** (38 entries).
- Reorder integrity: line multiset identical before/after (1353 lines, no additions or losses).
- `make fix-docs`: **91 files, 91 passed, 0 failed**, 1897 valid links / 0 invalid — no other document's TOC disturbed (`recent-changes.md` is the only file with numbered headings).
- Idempotent: re-running `make fix-docs` reports no further changes.
- `make test`: **598 passed, 0 failed**. `make lint`: PSScriptAnalyzer **150 files, all checks passed**; Python lint clean.

<a id="37-unified-help-switch-across-all-28-documented-commands-doc-driven-make-list-commands"></a>

### 37) Unified `-Help` switch across all 28 documented commands + doc-driven `make list-commands`

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-11 | Unified `-Help` switch across all 28 documented commands: added `-Help` support to `Get-RouteMap` (was missing the parameter entirely), `Invoke-OpsRamp` (was missing the parameter entirely), and `Invoke-OpsRampClient` (removed `[OutputType([OpsRamp_Client])]` that threw on systems where the class wasn't loaded, breaking `-Help` on Linux); fixed parameter alias conflicts in `OneViewMaintenanceMode.ps1` where `[Alias('NoSchedule')]` on `$NoSchedule` and `[Alias('Json')]` on `$Json` were invalid (alias == parameter name); rewrote `scripts/list-commands.ps1` as a doc-driven allowlist that parses `docs/Automation/automation_commands.md` for the command list, intersects with actual Public functions, and automatically excludes SCOM-only commands; updated `README.md` and `docs/Automation/automation_commands.md` command count 32 → 28 | Kev Everall |

<a name="root-cause-37"></a>

#### Root cause

- **Missing `-Help` parameters**: `Get-RouteMap.ps1` and `Invoke-OpsRamp` (in `Invoke-OpsRampClient.ps1`) had no `$Help` switch in their `param()` block, so calling `Get-RouteMap -Help` or `Invoke-OpsRamp -Help` threw: *"A parameter cannot be found that matches parameter name 'Help'"*.
- **`-OutputType` evaluation before `$Help` check**: `Invoke-OpsRampClient.ps1` declared `[OutputType([OpsRamp_Client])]`. PowerShell evaluates attribute types at function-definition time. On systems where the `OpsRamp_Client` class is not loaded (e.g. Linux or module import without the class dependency), this threw *"Unable to find type [OpsRamp_Client]"* — preventing the `[switch]$Help` parameter (already declared) from ever being reached.
- **Invalid parameter aliases**: `OneViewMaintenanceMode.ps1` declared `[Alias('NoSchedule')]` on a parameter named `$NoSchedule` and `[Alias('Json')]` on a parameter named `$Json`. PowerShell forbids an alias being identical to its parameter name, so both commands (`Enable-OneViewMaintenanceMode`, `Disable-OneViewMaintenanceMode`, `Get-OneViewMaintenanceMode`) failed at parameter binding with *"The 'NoSchedule' parameter is already bound to the value 'False'."*
- **`make list-commands` included SCOM-only commands**: the script used `Get-Command -Module Automation` which listed SCOM-specific commands not documented in the main command reference, and missed commands with unapproved verbs (e.g. `Update-Firmware`).

<a name="fix-37"></a>

#### Fix

- **`Get-RouteMap.ps1`**: added `[Parameter(ParameterSetName = 'Help')][switch]$Help` and `if ($Help) { Get-CommandHelp -Name 'Get-RouteMap'; return }` before the `return` statement.
- **`Invoke-OpsRampClient.ps1`**: 
  - `Invoke-OpsRamp` — added `[Parameter(ParameterSetName = 'Help')][switch]$Help` and the `if ($Help)` guard.
  - `Invoke-OpsRampClient` — removed `[OutputType([OpsRamp_Client])]` (the type reference was only for documentation; output type discovery still works via runtime inspection). The `$Help` switch was already declared.
- **`OneViewMaintenanceMode.ps1`**: removed `[Alias('NoSchedule')]` from `$NoSchedule` and `[Alias('Json')]` from `$Json` in all three functions (`Enable-OneViewMaintenanceMode`, `Disable-OneViewMaintenanceMode`, `Get-OneViewMaintenanceMode`).
- **`scripts/list-commands.ps1`**: rewrote as a doc-driven allowlist:
  - Parses `docs/Automation/automation_commands.md` for documented `Verb-Noun` command tokens.
  - Intersects with actual `function` definitions found in `src/powershell/Automation/Public/`.
  - Automatically excludes SCOM-only commands (not documented in the main commands doc).
  - Displays each command's synopsis from its comment-based help.
- **`README.md` + `docs/Automation/automation_commands.md`**: updated command count 32 → 28 to reflect the current pruned set.

<a name="verification-37"></a>

#### Verification

- `Get-RouteMap -Help` → renders man-page reference (was failing).
- `Invoke-OpsRamp -Help` → renders man-page reference (was failing).
- `Invoke-OpsRampClient -Help` → renders man-page reference (was failing on non-Windows).
- `Enable-OneViewMaintenanceMode -Help` / `Disable-OneViewMaintenanceMode -Help` / `Get-OneViewMaintenanceMode -Help` → no alias-conflict errors.
- `make list-commands` → shows 28 commands, no SCOM-only commands, no errors.
- All 598 Pester tests pass.
- Full `-Help` matrix verified: every one of the 28 documented commands responds to `-Help` and calls `Get-CommandHelp` for the man-page reference.

<a id="36-documentation-tooling-updates-maintenance-mode-checkmake-security-pipeline-docs-iso-firmware-parameter-options-makefile-setup-guide-doc-index-refactor"></a>

### 36) Documentation & tooling updates — maintenance mode / Checkmake / security pipeline docs, ISO & Firmware parameter options, Makefile + SETUP-GUIDE + doc index refactor

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-04 | Documentation & tooling updates: maintenance mode / Checkmake integration / security-pipeline docs refreshed; ISO & Firmware parameter-options section added to automation commands; Makefile, SETUP-GUIDE, and the documentation index refactored | Kev Everall |

<a name="change-36"></a>

#### Change

- **Maintenance mode docs** (`docs/Maintenance-Mode/maintenance_mode.md`) — refreshed enable/disable + alert handling content.
- **Checkmake + security pipeline** (`docs/Generic/CHECKMAKE_INTEGRATION.md`, `docs/compliance/SECURITY_PIPELINE.md`, `docs/Generic/{audit_process,code_quality,oneview-auth,oneview-module-versions,powershell_ci}.md`, `docs/Automation/runbook-requirements-v2.md`) — updated to reflect current Checkmake integration and the hardened security pipeline.
- **ISO & Firmware parameter options** (`docs/Automation/automation_commands.md`) — added a dedicated section documenting the accepted ISO/firmware path formats and the `-ExternalIsoPath` / `-FirmwareFolders` parameter options.
- **Build/setup refactor** (`Makefile`, `docs/SETUP-GUIDE.md`, `docs/HPEProLiantWindowsServerISOAutomationDocumentationIndex.md`) — restructured setup and documentation-index wiring for clarity and consistency.

<a name="verification-36"></a>

#### Verification

- Affected `.md` docs render; `make` targets referenced in `Makefile` and `SETUP-GUIDE.md` remain consistent; the documentation index lists the current doc set.

<a id="35-readme-architecture-branding-svg-icons-technical-component-overview-diagram-ms-configuration-manager-flowchart-hpeoneviewilo-branding"></a>

### 35) README architecture & branding — SVG icons, technical component overview diagram, MS Configuration Manager flowchart, HPE/OneView/iLO branding

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-06 | README visual overhaul: added SVG icons for GitLab/HPE/Microsoft, a technical component overview diagram, and a flowchart reflecting Microsoft Configuration Manager; corrected HPE OneView / iLO branding on the architecture diagram and added `docs/assets/architecture.svg` | Kev Everall |

<a name="change-35"></a>

#### Change

- **`docs/assets/icons/{gitlab,hpe,microsoft}.svg`** — added brand SVG icons and switched the README to reference them inline.
- **`docs/assets/architecture.svg`** — added a dedicated architecture diagram asset (refactored out of the README's embedded markup) for the technical component overview.
- **`README.md`** — added a *Technical component overview* diagram and reworked the pipeline flowchart to reflect **Microsoft Configuration Manager** (was mislabelled), corrected the HPE OneView / iLO node branding on the flowchart, and switched flowchart/overview icons to the new SVG brand assets.

<a name="verification-35"></a>

#### Verification

- `README.md` renders the component-overview diagram, the corrected ConfigMgr flowchart, and the GitLab/HPE/Microsoft SVG icons; `docs/assets/{architecture.svg,icons/*.svg}` exist and are referenced.

<a id="34-git-ssh-authentication-powershell-profile-hardening-troubleshooting-guides-fix-gitsshmd-testing-issuemd"></a>

### 34) Git SSH authentication — PowerShell profile hardening + troubleshooting guides (Fix-GitSSH.md, testing-issue.md)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-10 | Git SSH authentication hardening: PowerShell profiles (`eis19` / `techvdi` / `windowspsprofilecurrentvdi`) gained SSH-agent responsiveness checks + key loading, pinned `GIT_SSH_COMMAND` to Git's bundled ssh with `-i <key> -o IdentitiesOnly=yes`, clear stale `SSH_AUTH_SOCK`, and disable posh-git for performance; new `wip/Fix-GitSSH.md` troubleshooting guide plus extensive `wip/testing-issue.md` SSH troubleshooting revisions (debug output, key-exchange warning, user/git-level SSH override checks) | Kev Everall |

<a name="root-cause-34"></a>

#### Root cause

- **Morning breakage from a dead ssh-agent socket**: profiles trusted `$env:SSH_AUTH_SOCK` to mean a live agent, but a stale socket (agent process gone) caused `git` to talk to a dead endpoint and offer no key — intermittent auth failures with no clear cause.
- **Windows OpenSSH blocked in the locked-down VDI**: `GIT_SSH` / `GIT_SSH_COMMAND` had to be pinned to Git's bundled `ssh.exe` (forward slashes, since git hands `GIT_SSH` to a shell that treats `\` as an escape) with `IdentitiesOnly=yes` so the correct `id_ed25519` key is always offered.
- **No consolidated troubleshooting path**: SSH key-permission, user/git-level SSH override, and environment-variable conflicts had to be diagnosed ad hoc.

<a name="fix-34"></a>

#### Fix

- **`wip/techvdi-profile.ps1` / `wip/eis19profile.ps1` / `wip/windowspsprofilecurrentvdi.ps1`**:
  - Added `Test-SshAgentResponsive` — `ssh-add -l` must return exit 0 (keys present) or "no identities" (alive but empty); otherwise the socket is treated as dead and a fresh agent is started via `Start-SshAgentAndLoadKey`, which loads `id_ed25519`.
  - Pinned `GIT_SSH_COMMAND` to Git's bundled `ssh.exe -i <key> -o IdentitiesOnly=yes` and persist it to the user env so VS Code's git (separate process) reuses it.
  - Clear stale `SSH_AUTH_SOCK` (process + user env) on load since direct key auth needs no agent.
  - Disabled posh-git import and set max history / de-dupe for faster shell startup; module path made user-relative.

<a name="verification-34"></a>

#### Verification

- `wip/testing-issue.md` gained SSH debug output (verbose `ssh -vT`), a key-exchange (algorithm) vulnerability warning, and checks for user `~/.ssh/config`, git-level `GIT_SSH_COMMAND`/`core.sshCommand` overrides, and `SSH_AUTH_SOCK`/`GIT_SSH` environment settings.
- `wip/Fix-GitSSH.md` added as a dedicated step-by-step Git SSH authentication troubleshooting guide (since removed in the wip cleanup — see §41).
- Profiles parse under the PowerShell parser; the `techvdi-profile.ps1` merge-conflict markers introduced during the `SSH_AUTH_SOCK` rework were resolved.

<a id="33-hpe-oneview-maintenance-mode-documentation-enabledisable-procedures-alert-handling-windows-forms-integration-maintenancemode-refactor-json-fix-opsramp-firewall-docs"></a>

### 33) HPE OneView Maintenance Mode documentation — enable/disable procedures, alert handling, Windows Forms integration, `.maintenanceMode` refactor, JSON fix, OpsRamp firewall docs

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-10 | HPE OneView Maintenance Mode documentation: new `wip/maintenance-mode-code.md` with enable/disable procedures, alert handling, and Windows Forms integration cmdlet instructions; `Set-MaintenanceMode.ps1` now reads the OneView `maintenanceMode` property (`On`/`Off`) instead of the non-existent `MaintenanceModeEnabled`, and `Get-OneViewServerList` reports maintenance state from the same property; fixed a stray `s` typo that broke the embedded JSON conversion in `Set-MaintenanceMode.ps1`; added HPE OpsRamp firewall-rules documentation and a `.maintenanceMode` property refactor across the maintenance-mode scripts | Kev Everall |

<a name="root-cause-33"></a>

#### Root cause

- **Wrong maintenance-mode property**: the maintenance-mode scripts read `$server.MaintenanceModeEnabled`, a property that does not exist on the OneView `ServerHardware` resource. OneView exposes the state as the string property `maintenanceMode` (`On` / `Off`), so the old check always evaluated as `$false`/empty and every server was reported as "not in maintenance" even while OneView showed it in maintenance mode. `Get-OneViewServerList` rendered the column from the same non-existent property.
- **Embedded JSON conversion broken**: `Set-MaintenanceMode.ps1` includes an embedded PowerShell snippet (for the SCOM/OneView bridge) whose `ConvertTo-Json` line had a stray leading `s` — `s    $result | ConvertTo-Json -Depth 5` — which made the generated script syntactically invalid.
- **Missing operations docs**: enable/disable procedures, alert-suppression handling, and the Windows Forms integration cmdlet set had no consolidated reference; OpsRamp firewall rules were undocumented.

<a name="fix-33"></a>

#### Fix

- **`maintenanceMode` property** (`OneViewMaintenanceMode.ps1`, `New-OneViewMaintenanceScript.ps1`, `Set-MaintenanceMode.ps1`, `Get-OneViewServerList.ps1`): replaced every `$server.MaintenanceModeEnabled` read with `$server.maintenanceMode`, and `Get-OneViewServerList` now maps `maintenanceMode` not in `@('Off', $false, $null)` to `Yes` / otherwise `No`. The already-in-maintenance / already-not-in-maintenance short-circuits and the enable/disable loops now key off the real property.
- **JSON conversion typo** (`Set-MaintenanceMode.ps1`): removed the stray `s` so the embedded snippet reads `$result | ConvertTo-Json -Depth 5`.
- **`wip/maintenance-mode-code.md`**: new consolidated reference covering enable/disable procedures, alert handling details, and the HPE OneView Maintenance Mode cmdlets plus their integration into a Windows Forms front-end.
- **OpsRamp firewall docs**: added the HPE OpsRamp integration firewall-rules section (ports/protocols required for the OpsRamp agent ↔ gateway link).

<a name="verification-33"></a>

#### Verification

- `Get-OneViewServerList.Unit.Tests.ps1`: updated assertions for the `maintenance_mode` column now pass (server with `maintenanceMode = 'On'` reports `Yes`; `Off`/`$null` reports `No`).
- `Set-MaintenanceMode.ps1` parses cleanly (stray `s` removed); the embedded conversion snippet is valid PowerShell.
- `wip/maintenance-mode-code.md` and the OpsRamp firewall section are present and consistent with the cmdlet signatures.

<a id="32-docx-documentation-replaces-rtf-converter-fix-full-docs-coverage-project-root-output"></a>

### 32) DOCX documentation replaces RTF — converter fix, full docs coverage, project-root output

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-09-03 | 1. Removed `make rtf-docs` / `make rtf-docs-clean`, `scripts/MD_to_RTF_Converter.py`, and the `docs/rtf/` tree - RTF never resolved TOC/bookmark links in Word (long/digit-leading bookmark names get hashed by Word+pandoc). 2. Added `make word-docs` / `make word-docs-clean`: Markdown -> Word DOCX with native OOXML `<w:bookmarkStart>` / `<w:hyperlink w:anchor>` so TOC and citation links are active the moment the file opens (no field update). 3. Fixed `MD_to_DOCX_Converter.py` `_rewrite_link` bug: the `[text](#anchor)` regex captures the anchor without the leading `#`, so the `target.startswith('#')` guard was always false and no TOC/citation links were rewritten - pandoc then hashed long anchors into `X<hash>` and desynced bookmarks from links. Links now normalize to `secN` / `ref-N`. 4. Disabled pandoc's `tex_math_dollars` extension (`-f markdown-tex_math_dollars`) so PowerShell `$true` / `$false` / `$null` render literally instead of raising 'Could not convert TeX math' warnings. 5. Expanded DOCX coverage to all `docs/**/*.md` + root `*.md` + `wip/*.md`. 6. Relocated output to project-root `docx/`, mirroring `docs/` (no `docs/` prefix, no `docx/docs/` namespace). 7. Per-file graceful error handling: a failed conversion logs `[WARN] failed to convert <file>` and continues - no stack traces. | Kev Everall |

<a name="root-cause-32"></a>

#### Root cause

Two independent problems blocked the DOCX route:

- **RTF was broken by design**: Word (and pandoc) reject bookmark names that begin with a digit and silently rename any name longer than ~32 characters to a `SHA-1` hash (`X<hash>`). The RTF converter emitted long, digit-leading anchors (e.g. `61-prerequisites`), so the bookmarks Word created did not match the link targets in the TOC/citations — links never resolved without an interactive field-update.
- **The DOCX converter's own `_rewrite_link` regressed**: `_INT_LINK = r"\[([^\]]+)\]\(#([^)\s]+)\)"` captures group 2 as the anchor *without* the leading `#` (the `#` is a literal in the pattern). The rewrite function then did `if target.startswith("#")`, which is always **False**, so it fell through to the `return m.group(0)` no-op branch. Every TOC/citation link was left pointing at the original long anchor, and pandoc hashed those into `X<hash>` bookmarks with no matching target.

<a name="fix-32"></a>

#### Fix

- **`scripts/MD_to_RTF_Converter.py` is gone** (deleted along with `docs/rtf/`); Word DOCX now replaces RTF as the help-doc format.
- **`scripts/MD_to_DOCX_Converter.py`**:
  - `_rewrite_link` no longer tests for a leading `#` (the regex never captures it): it normalises `valid_bm_name(m.group(2))` and looks it up in `heading_map`, rewriting every TOC/citation target to its `secN`/`ref-N` bookmark id so bookmark and link target stay in sync.
  - `pandoc` is now invoked with `-f markdown-tex_math_dollars` (math extension disabled) so `$true`/`$false`/`$null` PowerShell variables render as literal text; `capture_output=True` + explicit `returncode` check means a failing conversion raises a `RuntimeError(msg)` caught by the caller as a single `[WARN] failed to convert <file>` — no tracebacks, no stderr spam.
  - `discover_md_files` now mirrors the old RTF source set exactly: root `README.md`, `docs/Automation/{automation_commands,runbook-requirements,runbook-requirements-v2}.md`, `docs/dynamic-code-docs/*.md`, and `wip/*.md`. (Root `README.md` is intentionally **not** emitted to `docx/` to avoid colliding with `docs/README.md` once the `docs/` prefix is stripped; it remains in-repo as `.md`.)
  - Output relocated to project-root `docx/`, mirroring `docs/` (e.g. `docs/Automation/foo.md` → `docx/Automation/foo.docx`) with the leading `docs/` prefix removed.
- **`Makefile`**: added `word-docs` / `word-docs-clean` targets and removed `rtf-docs` / `rtf-docs-clean` (plus their `.PHONY` entries).
- **`wip/SSO.md` authoring**: the source is hand-written with a manual `## Table of Contents` of `[N) Title](#secN)` bullets, in-text citation links `[N](#ref-N)`, and a references section whose entries are `<a id="ref-N">…</a>`. The converter normalises that scheme into `secN`/`ref-N` OOXML bookmarks, so `docx/wip/SSO.docx` carries 56 native bookmarks with TOC→`secN` and citation→`ref-N` hyperlinks that fire in Word on open (no field update). This was the concrete test case that drove the `_rewrite_link` fix, the tex-math disable, and the graceful error handling.

<a name="verification-32"></a>

#### Verification

- `make word-docs` → `Converted 270 markdown files to DOCX under .../docx`; `docx/` mirrors `docs/` + `wip/` (no `docs/` prefix).
- `docx/wip/SSO.docx`: 56 bookmarks, **0** hashed `X<hash>` anchors, TOC bullets → `secN`, citation links → `ref-N`, all resolving in Word on open.
- `make word-docs-clean`: removes `docx/`; re-running `make word-docs` reproduces cleanly.
- `make lint-make` (checkmake) + `make lint-python` (ruff): clean, no issues.
- 0 "Could not convert TeX math" warnings on the previously-noisy dynamic-code-docs.

<a id="31-make-setup-machine-aware-powershell-profile-selection-eis19-prod-vdi-default"></a>

### 31) Make setup machine-aware PowerShell profile selection (eis19 / prod-VDI / default)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-09-02 | `make setup` now selects the Windows terminal profile template by computer name so environments with different network constraints get the correct config | Kev Everall |

<a name="root-cause-31"></a>

#### Root cause

`make setup` (`scripts/Setup-Profile.ps1`) deployed a single `wip/windowspsprofile.ps1` to every Windows machine regardless of host. That could not satisfy two environments at once:

- **eis19** (internal-only test server) must **not** carry the corporate `HTTP(S)_PROXY` block, yet its `wip/eis19profile.ps1` template had a stray proxy block plus a wrong `gitSshPath` pointing at `C:\Windows\System32\OpenSSH` (which the file's own comments say is blocked), causing `git pull` failures and `~/.ssh/config` corruption.
- **prod VDI** needs the corporate proxy to reach the internet, but the generic template had none.

#### Fix

`scripts/Setup-Profile.ps1` now resolves the Windows terminal profile template per machine via a new `Resolve-TerminalTemplate` function (matched by computer name substring):

- **eis19\*** → `wip/eis19profile.ps1` (no proxy, Git-bundled ssh — fixed)
- **\*vdi\* / \*prod\*** → `wip/techvdi-profile.ps1` (corporate proxy + Git-bundled ssh)
- **default Windows** → `wip/windowspsprofile.ps1`
- **Linux/macOS** → `wip/psprofile.ps1` (unchanged)

Fixed `wip/eis19profile.ps1`: removed the bogus proxy block and changed `$gitSshPath` to Git's bundled `...\AppData\Local\Programs\Git\usr\bin` (matching `windowspsprofile.ps1` and the file's own comments). The broken eis19 state (proxy + `System32\OpenSSH`) is gone from its source template, so a fresh `make setup` on eis19 deploys a working profile.

<a name="verification-31"></a>

#### Verification

- `Setup-Profile.ps1` passes the PowerShell parser (`[System.Management.Automation.Language.Parser]::ParseFile` → SYNTAX OK).
- `wip/eis19profile.ps1` head confirmed: no proxy block; `$gitSshPath = "$env:USERPROFILE/AppData/Local/Programs/Git/usr/bin"`.
- `wip/techvdi-profile.ps1` confirmed to retain the proxy block and the correct Git-bundled `gitSshPath`.

<a name="caveats-31"></a>

#### Caveats

- **VS Code profile** (`vscodeprofile.ps1`) is still shared/cross-platform and not machine-aware. If prod VDI needs git to work inside the VS Code integrated terminal, it'll need the proxy too — currently only the external-terminal profile gets it.
- Hostnames are matched by substring (`eis19`, `vdi`, `prod`). If the real computer names differ (e.g. `EIS19-SRV` or `PROD-VDI-01`), confirm they still match, or adjust the regex in `Resolve-TerminalTemplate` (`scripts/Setup-Profile.ps1:119`).

<a id="30-rtf-documentation-overhaul-landscape-pages-proportional-table-widths-working-toc-links-blockquote-tables"></a>

### 30) RTF documentation overhaul — landscape pages, proportional table widths, working TOC links, blockquote tables

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |  
| 2026-08-29 | RTF documentation overhaul — landscape pages, proportional table widths, working TOC links, blockquote tables | Kev Everall |  

RTF exports for `ConfigMgr-Build.md` and `OneView-Firmware.md` had poor readability: portrait orientation for wide tables, fixed-width columns that overflowed, TOC links that didn't navigate, and blockquote table rows that ran together. Refactored the shared `New-RtfDocument` helper and the two Markdown→RTF converters to fix all of it.

**What changed**

| Area | Before | After |
|---|---|---|
| Page orientation | Portrait (8.5×11) | Landscape (11×8.5) |
| Table columns | Fixed 4.5 in / 2 in | Proportional with `\colsx` and flexible widths |
| Section headings | Bold + underline | Section heading style with page break before |
| TOC links | Plain text URLs | Working `\v` hyperlinks with `\ul` clickable entries |
| Blockquote tables | Merged rows with no borders | Full cell borders + shading for readability |
| Indentation | 0.5 in | 0.75 in for body + nested lists |
| Page margins | 1 in all sides | 0.75 in all sides |

**Files touched**

- `src/Public/Documentation/New-RtfDocument.ps1` — orientation, margins, heading styles, proportional columns, TOC link format
- `src/Public/Documentation/ConvertTo-RtfFromMarkdown.ps1` — blockquote-to-table border logic, heading style calls, TOC style
- `src/Public/Documentation/ConvertTo-ConfigMgrBuildRtf.ps1` — column width ratios for wide firmware tables
- `src/Public/Documentation/ConvertTo-OneViewFirmwareRtf.ps1` — same

**Verification**

Regenerated both RTF docs end-to-end and opened them in Word. Tables fit without horizontal scrolling, TOC entries navigate to the correct headings, blockquote firmware tables are easy to read across, and landscape orientation preserves the wide server-model columns.

#### Tests: 488 passed, 0 failed, 1 pre-existing skip

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

<a id="29-credential-hardening-ciso-vulnerability-scan-secure-storagehandling-of-hpe-oneview-ilo-scom-credentials"></a>

### 29) Credential hardening & CISO vulnerability scan — secure storage/handling of HPE OneView / iLO / SCOM credentials

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-27 | Security hardening of HPE OneView / iLO / SCOM credential handling (TLS-validated CyberArk fetch, secrets passed out-of-band via `-Environment`/`-ArgumentList`, in-process password cache instead of process-env) and a CISO-style vulnerability scan with CI guardrail rules in `ci-security-check.ps1` | Kev Everall |

<a name="root-cause-29"></a>

#### Root cause

A security review of how OneView / iLO / SCOM usernames and passwords are **stored and handled** in transit and in-process surfaced four exposure classes:

- **TLS validation disabled on the credential fetch (CWE-295, CRITICAL)**: `scripts/cyberark-bootstrap.ps1` set `ServerCertificateValidationCallback = { $true }` while retrieving admin passwords from CyberArk. A MITM on the internal network could impersonate the appliance and harvest the returned OneView/SCOM credentials.
- **Secrets interpolated into executed script/command text (CWE-214 / CWE-532, HIGH)**: SCOM and OneView passwords were embedded directly into strings run via `Invoke-PowerShellScript` (a child `pwsh -Command` process) and WinRM `Invoke-Command` scriptblocks — so the plaintext password landed in child-process command lines, transcripts, and logs. (`Set-MaintenanceMode.ps1`: `Test-ScomConnection`, the `SCOMManager` REST bodies, `_RunPs`, and the five OneView module/WinRM functions.)
- **Passwords cached into the process environment (CWE-526 / CWE-214, MEDIUM)**: `Credentials.ps1` wrote resolved passwords to process environment variables (`[System.Environment]::SetEnvironmentVariable`). Those variables are inherited by every child process and are readable via `/proc/$pid/environ` — iLO/OneView/SCOM passwords leaked to everything the runner spawned.
- **CI dotenv artifact not gitignored (CWE-538, LOW)**: `secrets.env` (the CyberArk dotenv export) was not in `.gitignore`, so a developer redirect could commit live credentials.

<a name="fix-29"></a>

#### Fix

- **`scripts/cyberark-bootstrap.ps1`** — replaced the blanket accept-all callback with proper chain validation plus optional certificate pinning via a new `CYBERARK_EXPECTED_THUMBPRINT` env var, and enforced TLS 1.2. The credential response now traverses only a verified channel; the safe callback is ignored by the new scanner because it validates `$sslPolicyErrors` and pins a thumbprint rather than blindly returning `$true`.
- **`src/powershell/Automation/Public/Set-MaintenanceMode.ps1`** — SCOM `Test-ScomConnection` and the `SCOMManager` REST bodies now read credentials from a `param()` block supplied out-of-band: `-Environment` for the local child process (`Invoke-PowerShellScript`) and `-ArgumentList` for WinRM (`Invoke-PowerShellWinRM`), mirroring the already-secure `Test-ScomMaintenanceConnectivity` pattern. `_RunPs` injects credentials via `-Environment` (local) / `-ArgumentList` (WinRM).
- **OneView WinRM paths (Finding 5)** — converted `_SetViaModule`, `_DisableViaModule`, `ResolveTarget`, `_GetMaintenanceStatusViaModule`, and `ResolveServerBySerial` to a `param([string]$OVUser = $env:OV_CONN_USER, [string]$OVPwd = $env:OV_CONN_PASS)` block. WinRM now passes `-ArgumentList @($this.Username, $this.Password)`; the in-process `Invoke-Expression` path sets `$env:OV_CONN_USER`/`$env:OV_CONN_PASS` immediately before execution and clears them in a `finally` block. The password no longer appears in executed script text.
- **`src/powershell/Automation/Private/Credentials.ps1`** — resolved secrets are now held in a module-scoped in-process cache (`$script:_CredCache`) and **never** written to the process environment; only non-secret usernames are still cached to env. iLO/OneView/SCOM passwords are no longer exposed to child processes.
- **`.gitignore`** — added `secrets.env`. **`.envexample`** — documented `CYBERARK_EXPECTED_THUMBPRINT`.
- **`scripts/ci-security-check.ps1`** — added `Get-CustomSecurityFindings` (runs alongside PSScriptAnalyzer, merged into the same `$findings` pipeline) with two rules that flow through the existing fingerprint / baseline / SAST-report machinery:
  - `CustomTlsValidationDisabled` (Error, CWE-295) — flags `ServerCertificateValidationCallback = { … }` that returns `$true` without checking `$sslPolicyErrors` or pinning a certificate.
  - `CustomEmbeddedSecret` (Warning, CWE-214/532) — flags `$($this.Password)` / `$($this.Cred['password'])` / `$($this.Cred['username'])` interpolated into an executed string.
  Both gate in `enforce` mode and can be risk-accepted via `.security-baseline.json`.

<a name="verification-29"></a>

#### Verification

- All touched `.ps1` files (`cyberark-bootstrap.ps1`, `Set-MaintenanceMode.ps1`, `Credentials.ps1`, `ci-security-check.ps1`) pass the PowerShell parser.
- `ci-security-check.ps1 -Mode report` runs end-to-end; the safe `cyberark-bootstrap.ps1` callback is **not** flagged (it contains `$sslPolicyErrors` + `Thumbprint`), and **zero** `CustomTlsValidationDisabled` / `CustomEmbeddedSecret` findings exist in the current tree → no remaining violations.
- A proof test confirms the custom rules *do* detect the bad patterns (`acceptAll=True` for `{ $true }`; secret matches for `$(this.Password)` / `$(this.Cred['password'])`), so they will block future regressions.
- `grep` confirms no `$(this.Password)` / `$(this.Cred['password'])` interpolation and no `ServerCertificateValidationCallback = { $true }` remain in `src/` / `scripts/`.

<a id="28-oneview-error-honesty-abort-on-failed-resolution-ilo-credential-fallback"></a>

### 28) OneView error honesty + abort on failed resolution + iLO credential fallback

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-27 | `Get-OneViewServerTarget` now classifies REST failures honestly (transport failure → "No connection to OneView"; real HTTP status → "OneView returned HTTP <code> - <reason>") and lets `Auto` mode fall through a rejected filter to the next identifier type; `Configure-PhysicalBuild` + `Start-PhysicalServerBuild` now abort on a failed OneView resolution instead of warning and continuing to the guard rail / DEPLOY prompt; `Test-PreBuildValidation` reuses the OneView credentials for the iLO Redfish check (falls back to an interactive prompt if they are rejected) via a new `-OneViewCredential` (`-OVCred`) | Kev Everall |

<a name="root-cause-28"></a>

#### Root cause

- **Misleading error message**: `Get-OneViewServerTarget` wrapped its `Invoke-RestMethod` call in a single `try/catch` that returned the raw exception text verbatim — `OneView query failed: Response status code does not indicate success: 400 (Bad Request).` — regardless of cause. A 400 from a rejected `Serial` filter was indistinguishable from a genuine outage, and (worse) in `Auto` mode the loop aborted on the *first* identifier type that threw, so a valid server could not be resolved via `Name` even when the appliance was reachable.
- **Carry-on after failure**: `Configure-PhysicalBuild` and `Start-PhysicalServerBuild` call `Get-OneViewServerTarget` directly and only `WARN`ed (or `_Step`ped) on a failed resolution, then continued to the guard rail, ISO resolution, pre-build validation and the destructive `DEPLOY` prompt. A failed target resolution therefore produced a build plan / deploy authorization against an unresolvable server. `Resolve-OneViewTarget` (the central resolver) already aborted correctly; the two build commands did not.
- **Redundant iLO login**: iLO and OneView are separate auth domains, but the same credentials are normally used for both. The pre-build iLO check only accepted `-IloCredential` or an interactive prompt, so supplying OneView credentials alone still forced a second login even though they were valid for iLO.

<a name="fix-28"></a>

#### Fix

- **Honest error classification** (`Get-OneViewServerTarget.ps1`): added `_Classify-OneViewRequestError`, which detects a transport-level failure (no working path to the appliance) and reports `No connection to OneView at '<host>'. <detail>.` rather than leaking the raw exception. A real HTTP response is reported as `OneView returned HTTP <code> - <reason>` (e.g. `400 - Bad Request (the identifier/filter was rejected by OneView)`, `401 - Unauthorized (session expired or invalid credentials)`). The `try/catch` now wraps each identifier-type query *inside* the `Auto` loop, so a rejected filter on one type (e.g. `400` on `Serial`) is logged and the loop continues to the next (`IloIp` → `EnclosureBay` → `Name`) instead of aborting the whole resolution. A connection failure still returns `No connection` immediately.
- **Abort on failed resolution** (`Configure-PhysicalBuild.ps1`, `Start-PhysicalServerBuild.ps1`): when `Get-OneViewServerTarget` returns `Success=$false`, the command now `return`s a failure result immediately (recording the error) instead of continuing. `Configure-PhysicalBuild` aborts before the guard rail / ISO / pre-build steps; `Start-PhysicalServerBuild` aborts before the guard rail and any destructive iLO steps. This guarantees no `DEPLOY` prompt / no destructive action is offered against an unresolvable target. (`-DryRun` still suppresses the abort, matching the existing `pre_build_validation` convention, since a DryRun preview never performs destructive work.)
- **iLO credential fallback** (`Test-PreBuildValidation.ps1`): added `-OneViewCredential` (alias `-OVCred`). In the `ilo_credentials` check, an explicit `-IloCredential` still wins; otherwise the iLO Redfish GET first tries `-OneViewCredential`. If those are rejected by iLO it writes a clear warning — `iLO login failed using the OneView credentials ('<user>') - they are not accepted by iLO. Prompting for iLO credentials.` — and opens an interactive `Get-Credential` prompt (when interactive); if no prompt is possible and no iLO credential is available it fails with a clear message rather than hanging. `-OneViewCredential` is also threaded into the OneView resolution calls so a single credential authenticates both appliances.
- **Parameter threading**: `-OneViewCredential` (`-OVCred`) added to `Configure-PhysicalBuild`, `Start-PhysicalServerBuild`, and `Test-PreBuildValidation`, and passed through to the iLO check and the OneView resolution.

<a name="verification-28"></a>

#### Verification

- Full `tests/powershell` suite: **520 passed, 0 failed**.
- New regression tests:
  - `Get-OneViewServerTarget`: a transport exception returns `No connection to OneView…` (never the raw `Response status code…` text); a `400` is reported as `HTTP 400…` and not leaked verbatim; `Auto` mode falls through a `400` on `Serial` and resolves via `Name`.
  - `Configure-PhysicalBuild`: a failed OneView resolution returns `Success=$false` and never reaches the guard rail (a `Mock Assert-GuardRail { throw }` proves the abort stops it).
  - `Start-PhysicalServerBuild`: a failed OneView resolution returns `Success=$false` with `error` matching `OneView resolution failed` and never reaches the guard rail / destructive steps.
  - `Test-PreBuildValidation`: `-OneViewCredential` succeeds for the iLO Redfish check; falls back to `-IloCredential` when the OneView credentials are rejected; fails (stating the reason) when the OneView credentials are rejected and no fallback is available.

<a id="27-command-prune-doc-update-deploy-flow-deleted-commands-bug-fixes"></a>

### 27) Command prune + doc update: deploy flow, deleted commands, bug fixes

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-27 | Pruned 5 commands (`Test-ServerList`, `Invoke-IsoDeploy`, `New-IsoBuild`, `Publish-BootIso`, `Update-Firmware`) from source/tests/docs; rewrote `Configure-PhysicalBuild` as the single deploy entry point with `-Deploy`/`-Execute` + `APPROVE`; updated docs, dynamic-code-docs, `testBuildDeploy.ps1`, and fixed 3 runtime bugs in the build pipeline | Kev Everall |

<a name="commands-removed"></a>

#### Commands removed

- Deleted `src/powershell/Automation/Public/{Test-ServerList,Invoke-IsoDeploy,New-IsoBuild,Publish-BootIso,Update-Firmware}.ps1`, their unit tests, and their dynamic-code-docs pages.
- Pruned `Automation.psd1` / `Automation.psm1` exports and comments to match.
- `Configure-PhysicalBuild` is now the **only** deploy entry point. `Start-PhysicalServerBuild` no longer accepts `-FirmwareFolders`, `-FirmwareConfig`, `-SkipIsoBuild`, `-SkipPublish`, `-Mock`, or `-SkipConfirmation` from external callers; firmware post-OS is not currently implemented inline.

<a name="configure-physicalbuild-changes"></a>

#### `Configure-PhysicalBuild` rewrite

- Added `-Deploy` (alias `-Execute`) as the explicit authorization switch; removed `-SkipConfirmation` and `-Mock` from the public surface.
- Added `-DryRun` so the review can run non-interactively without reaching the approval gate.
- Authorization flow: typing `APPROVE` at the interactive prompt, or passing `-Deploy`/`-Execute`, internally invokes `Start-PhysicalServerBuild` with the same parameters — the operator never re-types them.
- On `APPROVE`/`-Deploy`, `_InvokeBuild` passes `-SkipConfirmation` internally to `Start-PhysicalServerBuild` so the guard-rail confirmation inside `Assert-GuardRail` is bypassed (approval was already given here).
- Removed the firmware display block and `FirmwareFolders`/`FirmwareConfig` from the plan hashtable.
- Results now emit through `_Publish-Result` (clean block by default; `-PassThru`/`-Json` opt into structured output).

<a name="start-physicalserverbuild-changes"></a>

#### `Start-PhysicalServerBuild` changes

- Replaced the ISO build/publish block with direct `Resolve-ExternalIsoPath` from `-ExternalIsoPath`; removed all `New-IsoBuild`/`Publish-BootIso` call sites.
- Removed the firmware execution block (`Update-Firmware` call).
- Restored `-SkipConfirmation` as an **internal** parameter: it is not advertised to users, but `Configure-PhysicalBuild._InvokeBuild` passes it so `Assert-GuardRail` skips its destructive confirmation when approval was already given.
- Removed obsolete `.PARAMETER` doc lines for `-SkipIsoBuild`, `-SkipPublish`, `-SkipFirmware`, `-FirmwareFolders`, `-FirmwareConfig`, and `-Mock` from comment-based help.

<a name="doc-updates"></a>

#### Documentation updates

- `docs/Automation/automation_commands.md`: removed all sections/TOC entries for deleted commands; updated "How commands fit together" and safe/destructive tables to use `APPROVE`/`-Deploy`; rewrote `Configure-PhysicalBuild` and `Start-PhysicalServerBuild` parameter tables to match current signatures; added `testBuildDeploy` examples using `-ExternalIsoPath`.
- `docs/dynamic-code-docs/Configure-PhysicalBuild.md`: regenerated — removed `-SkipConfirmation`, `-FirmwareFolders`, `-FirmwareConfig`; added `-Deploy`/`-Execute`, `-PassThru`, `-Json`.
- `docs/dynamic-code-docs/Start-PhysicalServerBuild.md`: regenerated — removed obsolete params listed above.
- `docs/dynamic-code-docs/INDEX.md`: removed dead links to deleted command docs and stale internal helper docs (`_Emit-IsoDeployResult`, `_Format-IsoDeploySummary`).
- Removed stale doc files `_Emit-IsoDeployResult.md` and `_Format-IsoDeploySummary.md` (helpers no longer exist).

<a name="test-script-updates"></a>

#### Test script + unit test updates

- `scripts/testBuildDeploy.ps1`: rewrote to exercise `Configure-PhysicalBuild` + `Start-PhysicalServerBuild` directly; removed all `Invoke-IsoDeploy`/`Update-Firmware` calls; removed `-all` param; ISO/firmware path validation exercised through `Resolve-ExternalIsoPath` + `Test-PathEx` only.
- `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1`: rewrote — dropped `-SkipConfirmation`/`-Mock`/`-FirmwareFolders` references; replaced with `-DryRun`, `-Deploy`, and external ISO path tests; 9 tests, all pass.
- `tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1`: updated parameter list and skip flags to match current surface; replaced `-SkipIsoBuild`/`-SkipPublish` with `-ExternalIsoPath`.

<a name="bug-fixes-27"></a>

#### Bug fixes

- **`_Step` null-array crash** (`Start-PhysicalServerBuild.ps1`): `_Step` used `$script:overall['steps']` but `$overall` was a local `[ordered]@{}` — under `-SkipOneView` the function received a null result and crashed with "Cannot index into a null array". Fixed to use the local `$overall` variable.
- **`-DryRun` bypass in `Configure-PhysicalBuild`**: the confirmation block did not check `$DryRun`, so automated tests that passed `-DryRun` still hit the non-interactive auto-cancel path. Fixed: `-DryRun` now short-circuits before the approval gate and returns the review plan.
- **`-IloCredential` passthrough**: `_InvokeBuild` was passing `-IloCredential $IloCredential` to `Start-PhysicalServerBuild`, which does not accept that parameter. Fixed: removed from `_InvokeBuild`.
- **`-SkipConfirmation` passthrough to `Assert-GuardRail`**: `Start-PhysicalServerBuild` now passes `-SkipConfirmation:$SkipConfirmation` into `Assert-GuardRail` so approval given by `Configure-PhysicalBuild` (via `_InvokeBuild`) is honoured without a second `YES` prompt.

<a name="verification-27"></a>

#### Verification

- `Configure-PhysicalBuild.Unit.Tests.ps1`: **9 passed, 0 failed**.
- `Start-PhysicalServerBuild.Unit.Tests.ps1`: **2 passed, 0 failed**.
- `make automation-mode-tests`: **115 passed, 0 failed**, 0 skipped (full suite including the updated `Configure-PhysicalBuild` + `Start-PhysicalServerBuild` + `Setup-Profile` + `Connect-OneView` + `Get-OneViewConnectionStatus` + `Get-OneViewServerList` + `Get-OneViewServerTarget` + `Test-PreBuildValidation` + `Test-BuildParams` + `Validators` + `AutomationCommandLogging` + `Router` + `Run-*` runners).
- Module import: `Import-Module Automation.psd1 -Force -DisableNameChecking` succeeds; `Get-Command Configure-PhysicalBuild, Start-PhysicalServerBuild` resolves with the expected parameter sets.
- `Resolve-ExternalIsoPath` is now called from exactly one source file (`Private/ExternalIso.ps1`); all deploy commands resolve through it.

<a id="26-get-oneviewserverlist-detail-table-fixes-empty-model-rom-column-overflow-notapplicable-blanking"></a>

### 26) `Get-OneViewServerList` Detail table fixes: empty Model, ROM column overflow, NotApplicable blanking

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-26 | `Get-OneViewServerList` Detail view: fixed empty Model column, increased ROM column `Max` from 12→30 to prevent overflow misalignment, included header length in width calculation, added truncation safety net for over-width cells, render `NotApplicable` as blank in State Reason, added State Reason to KEY | Kev Everall |

<a name="root-cause-26"></a>

#### Root cause

- **Empty Model column**: the Detail table column definition used `Prop = 'model_number'`, which mapped to `$srv.modelNumber` from the OneView REST API. The `modelNumber` field exists on the server-hardware resource but is consistently **blank/null** in real appliances, so the Model column showed nothing. The populated model string lives in `$srv.model`.
- **Column misalignment after ROM**: the ROM column had `Max = 12`, but real ROM version strings like `U32 v3.50 (04/17/2025)` are 22 chars. PowerShell's composite-format specifier `{N,-12}` left-aligns short strings but does **not** truncate long ones, so the 22-char value overflowed its 12-char slot and shifted every subsequent column (State Reason, Model) out of alignment.
- **`NotApplicable` clutter**: OneView returns `stateReason = "NotApplicable"` as a default sentinel for the majority of servers (meaning "no special reason; state is self-explanatory"). Seeing `NotApplicable` in every row added noise without information.

<a name="fix-26"></a>

#### Fix

- **`Model` column populated** — changed the column definition from `Prop = 'model_number'` to `Prop = 'model'`, pointing at the field that OneView actually populates. The `model_number` key is still extracted into the entry hashtables for `-PassThru` consumers, but the display column now reads `model`.
- **ROM column width** — increased `Max` from 12 to 30 so typical ROM version strings (≤ 22 chars) fit without truncation.
- **Width calculation** — the per-column width now includes the header length (`[math]::Max($def.Header.Length, $maxDataLen)`), preventing a header wider than the data from being clipped.
- **Truncation safety net** — when a cell value exceeds its computed width, it is truncated to `width - 3` characters + `…` (`Substring(0, [math]::Max(0, $widths[$i] - 3)) + '...'`). This replaces the ad-hoc name-only truncation with a generalised guarantee that no column can ever overflow, regardless of field.
- **`NotApplicable` blanking** — in the cell-builder, `if ($val -eq 'NotApplicable') { $val = '' }` at render time only (the raw `state_reason` value remains in `-PassThru` results for programmatic consumers).
- **KEY documentation** — added a `State Reason` section to the KEY block explaining the `NotApplicable` → blank mapping and listing the non-default values (`UserInitiated`, `Unmanaged`, `Removed`).

<a name="verification-26"></a>

#### Verification

- `Get-OneViewServerList.Unit.Tests.ps1`: **19 passed, 0 failed** (17 existing + 2 new: Model data populated, ROM alignment column-count parity).
- `scripts/lint.ps1` (PSScriptAnalyzer): all checks passed, no new findings.
- Updated the §26 test mock to use realistic OneView fields: `model = 'DL380 Gen10'` (no `modelNumber`, which doesn't exist in the real API) and long ROM strings (`P89 v2.92 (11/23/2021)`, `U32 v3.50 (04/17/2025)`) that previously caused overflow.

<a id="25-connect-oneview-already-connected-message-bold-red-no-reconnection"></a>

### 25) `Connect-OneView` "already connected" message → bold red (no reconnection)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-21 | Replaced the plain "Already connected to OneView appliance '&lt;host&gt;'." message in `Connect-OneView` with a bold-red banner: `HPeOneView IS ALREADY CONNECTED TO <host> NO RECONNECTION ATTEMPTED, IF YOU WISH TO SWITCH APPLIANCES TYPE 'Disconnect-OneView' then reconnect`, shown in both the same-appliance reuse path and the different-appliance refusal path | Kev Everall |

<a name="change-25"></a>

#### Change

- When `Connect-OneView` is run and a live session already exists, it now prints a prominent bold-red (`ESC[1;31m`) banner instead of the previous plain/verbose message, making it unmistakable that no reconnection was attempted and how to switch appliances (`Disconnect-OneView` then reconnect).
- The banner is emitted in both the **reuse** path (same appliance / no host — previously only set `$result.Message`, never displayed) and the **refusal** path (different appliance). The structured `Message` returned via `-PassThru` carries the same text so automation callers see it too.

<a name="verification-25"></a>

#### Verification

- Mocked `Get-OneViewActiveSession` + `Test-ServerConnectivity` (`Connect-OneView -OneViewHost va-oneviewt-01` while already connected) renders the banner containing `HPeOneView IS ALREADY CONNECTED TO va-oneviewt-01` and `Disconnect-OneView`; the 53 existing unit tests still pass.

<a id="24-get-oneviewserverlist-field-enrichment-robust-ilo-ip-extraction-disconnect-oneview-appliance-naming"></a>

### 24) `Get-OneViewServerList` field enrichment + robust iLO IP extraction + `Disconnect-OneView` appliance naming

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-21 | Enriched `Get-OneViewServerList` to show the connected appliance and the full set of available server fields (Model, Enclosure, Bay, ROM alongside name/serial/power/health/iLO IP); made iLO IP extraction robust to every OneView `mpIpAddresses` shape; `Disconnect-OneView` now names the appliance it disconnected from | Kev Everall |

<a name="change-24"></a>

#### Change

- **`Get-OneViewServerList` table enrichment** — the header block now prints the connected appliance (`Appliance: <host>`, taken from the resolved session host) and the rendered table adds **Model**, **Enclosure**, **Bay** and **ROM** columns (these fields were already fetched into each server object but never displayed). Per-server column widths are computed dynamically so long names/enclosure names don't break alignment. The `Appliance` is also carried on the returned result object.
- **Robust iLO IP extraction (fixes the still-blank column)** — `_ConvertTo-IloIpAddressList` (OutputFormatter.ps1) was rewritten to accept the whole server object and scan every known location OneView uses for management IPs: `mpIpAddresses`, `mpHostInfo.mpIpAddresses`, `iloIpAddress`, `managementIP`. Each candidate value is matched against an IPv4/IPv6 pattern, so the iLO column populates whether OneView returns a `string[]`, `@{ ipAddress = … }` objects, `@{ address = … }` objects, or nests the addresses under `mpHostInfo`. All IPs are joined with `, ` (verified: `ipAddress` + `address` object shapes both render, e.g. `10.9.9.9, 10.9.9.10`).
- **`Disconnect-OneView` appliance naming** — captures the active session's appliance name before disconnecting and reports `Successfully disconnected from OneView appliance '<name>'`; the structured result now also carries `Appliance` (useful for client/automation callers).

<a name="verification-24"></a>

#### Verification

- `Get-OneViewServerList.Unit.Tests.ps1` (17), `Get-OneViewConnectionStatus.Unit.Tests.ps1` (23), `Get-OneViewServerTarget.Unit.Tests.ps1` (13) — **53 passed, 0 failed**.
- End-to-end render check: `Get-OneViewServerList` prints `Appliance: va-oneviewt-01` and the 9-column table; `srv-alpha` renders `iLO IP = 10.9.9.9, 10.9.9.10` (object-array `ipAddress`), `srv-beta` renders `192.168.1.5` (object-array `address`). `Disconnect-OneView` (mocked session) reports `Successfully disconnected from OneView appliance 'va-oneviewt-01'` with `Appliance` in the result.

<a id="23-get-oneviewserverlist-dry-output-migration-ilo-ip-fix-prune-logs-hardening"></a>

### 23) `Get-OneViewServerList` DRY output migration + iLO IP fix + `prune-logs` hardening

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-21 | Migrated `Get-OneViewServerList` to the shared `_Publish-Result` / `_Emit-*` output pattern (the 16th command, previously the outlier); fixed blank/missing iLO IP across the list/target/connection commands with a shared `_ConvertTo-IloIpAddressList` helper; made the server-list formatter render errors on failure; hardened `prune-logs.ps1` (removed the `-Include` scan hang + layered exception handling); removed `prune-logs` from non-log-creating `make` targets | Kev Everall |

<a name="scope-23"></a>

#### Scope

- `Get-OneViewServerList` was the one command **not** covered by the §22 `_Publish-Result` / `-PassThru` migration. It still used an ad-hoc local formatter plus manual `-PassThru` gating — which is also what let a duplicate `_Format-ServerListResult` formatter drift and collide with `Test-ServerList.ps1` (the "Server List Validation" shadowing bug fixed earlier in `9cb8049`).
- The server-list / server-target / connection-status commands rendered an **empty iLO IP column** because `ilo_ip` was taken as `$srv.mpIpAddresses | Select-Object -First 1`, which yields nothing useful when OneView returns `mpIpAddresses` as an array of address objects (`@{ ipAddress = …; type = … }`).
- Build commands (`Start-PhysicalServerBuild`, etc.) do **not** re-query OneView for the iLO IP — they read `Details.ilo_ip` from `Get-OneViewServerTarget` (`Start-PhysicalServerBuild.ps1:423`). With `ilo_ip` blank, that a→b→c chain broke and forced manual `-IloIp` entry.
- `prune-logs.ps1` hung indefinitely: `Get-ChildItem -Recurse -File -Include *.log,*.json,*.txt` over ~937 files never returned (>60 s), blocking `make lint` / `make test` on the developer machine.

<a name="change-23"></a>

#### Change

- **`Get-OneViewServerList` DRY migration** — added `-Json` / `-Quiet`, created `_Emit-OneViewServerListResult` (thin wrapper over `_Publish-Result -CustomView { _Format-OneViewServerListResult }`), and routed **every** exit path (mock, bad filter, dry-run, no-session, session-fail, success, exception) through it, mirroring `Get-OneViewConnectionStatus`. The uniquely-named `_Format-OneViewServerListResult` is now the only formatter, eliminating the duplicate-function fragility.
- **Shared iLO IP helper** — added `_ConvertTo-IloIpAddressList` to `Private/OutputFormatter.ps1`. It extracts every address string from `mpIpAddresses` whether it is a `string[]` or an array of `@{ ipAddress = … }` objects (also handles `address` / `ipv4Address` / dictionary forms), joining them with `, ` so **all** IPs are shown and returned. Applied in `Get-OneViewServerList`, `Get-OneViewServerTarget` (`Details.ilo_ip`, consumed by build commands) and `Get-OneViewConnectionStatus` (per-server lookup).
- **Formatter failure rendering (regression fix)** — `_Format-OneViewServerListResult` previously did `if (-not $Result.Success) { return }`, so failures rendered **nothing** after the DRY migration. It now prints the `Error` in red, so the no-session / bad-filter / exception paths still give the operator clear feedback (and removing the duplicate `result:` INFO line no longer loses that feedback).
- **Removed duplicate `result:` INFO lines** — dropped the `$logger.Info("… result: …")` summary line from `Get-OneViewServerList` and `Get-OneViewConnectionStatus` (it duplicated the human-readable table on screen). The failure-path INFO lines are retained.
- **`prune-logs.ps1` hardening** — replaced the hanging `-Include *.log,*.json,*.txt -Recurse` scan with `Get-ChildItem -Recurse -File | Where-Object { $_.Extension -in … }` (~0.04 s vs >60 s hang). Added **layered exception handling**: per-file `try/catch` (one undeletable log warns and continues instead of aborting the whole prune) wrapped in an outer `try/catch` that exits `1` with a clear `[prune-logs] Failed:` message instead of a stack dump.
- **`Makefile` `prune-logs` wiring** — removed `prune-logs` as a prerequisite from `help`, `lint`, `lint-test`, `setup`, `docs`, `fix-docs`, `fix-docs-dryrun` and `clean` (the latter already `rm -rf`s `generated/`, so pruning first was pointless). Kept it only on the log-generating targets: `test`, `test-unit`, `test-integration`, `maint-mode-tests`, `automation-mode-tests`, `test-progress-rpt-tests`, `coverage`.

<a name="verification-23"></a>

#### Verification

- `Get-OneViewServerList.Unit.Tests.ps1` (17), `Get-OneViewConnectionStatus.Unit.Tests.ps1` (23), `Get-OneViewServerTarget.Unit.Tests.ps1` (13) — **53 passed, 0 failed**.
- End-to-end proof with the real OneView `mpIpAddresses` object shape: `(_ConvertTo-IloIpAddressList @(@{ ipAddress='10.1.2.3' }, @{ ipAddress='10.1.2.4' }))` → `10.1.2.3 | 10.1.2.4`; string array → `192.168.1.5`; `$null` → `''` (no throw). `Get-OneViewServerList` returns and renders `ilo_ip` (`10.9.9.9`) from an object-array mock.
- Failure-path proof: `Get-OneViewServerList` with no session now renders `Error: No active OneView session…` (was blank).
- `prune-logs.ps1` runs in ~0.04 s and exits `0`; `PSScriptAnalyzer` on all four changed `.ps1` files: no new issues (the only findings are pre-existing in `Get-OneViewServerTarget.ps1`).

<a id="22-shared-_publish-result-passthru-output-migration-15-public-commands"></a>

### 22) Shared `_Publish-Result` / `-PassThru` output migration (15 Public commands)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-20 | Migrated 15 Public commands to the shared `_Publish-Result` / `-PassThru` output pattern so interactive runs no longer dump a truncated raw hashtable; added `-Json`/`-PassThru`/`-Quiet` to each and updated their tests | Kev Everall |

<a name="scope-22"></a>

#### Scope

- Many Public commands ended their main (and error) paths with a bare `return $result` (an unformatted hashtable). On an interactive run PowerShell rendered that as a truncated 2-column `Name / Value` table dumped to the terminal/transcript after the human-readable report — noisy and unreadable for nested structures.
- The fix generalises the pattern already established by `Test-ServerConnectivity` / `Test-ServerList` (§12) to every remaining command that published a result.

<a name="change-22"></a>

#### Change

- Added `[switch] $Json`, `[Alias('PT')] [switch] $PassThru`, `[switch] $Quiet` to each migrated command's param block, with matching `.PARAMETER` / `.RETURNS` doc comments.
- Every main + early-exit/error path that returned the structured object now routes through `_Publish-Result` (from `Private/OutputFormatter.ps1`):
  - **Command-specific view** — when a command already printed a bespoke report, that report was extracted into a local `_Format-<VerbNoun>Result` function and emitted via a thin `_Emit-<VerbNoun>Result` wrapper using `_Publish-Result -CustomView { param($r) _Format-<VerbNoun>Result -Result $r }` (e.g. `Connect-OneView`, `Get-OneViewConnectionStatus`, `Get-OneViewVersion`, `Test-PostBuildValidation`, `Start-InstallMonitor`, `Update-Firmware`, `Invoke-IsoDeploy`).
  - **Generic view** — commands without a bespoke report route straight through `_Publish-Result -Result $result` (e.g. `Disconnect-OneView`, `New-IsoBuild`, `Publish-BootIso`, `Start-PhysicalServerBuild`, `Update-WindowsSecurity`, `Start-AutomationOrchestrator`), using the recursive `_Format-HumanReadable` renderer.
- **New default behaviour:** the command writes the human-readable report and returns **nothing** on the success stream (no truncated hashtable). `-PassThru` *also* returns the raw structured object; `-Json` emits a `ConvertTo-Json` string; `-Quiet` suppresses the report.

<a name="commands-22"></a>

#### Commands migrated

- OneView / connection: `Get-OneViewVersion`, `Get-OneViewConnectionStatus`, `Connect-OneView`, `Disconnect-OneView`
- Read-only reports: `Test-PostBuildValidation`, `Start-InstallMonitor`, `Get-MaintenanceStatusReport`
- ISO / firmware build pipeline: `New-IsoBuild`, `Update-Firmware`, `Publish-BootIso`, `Invoke-IsoDeploy`
- Deploy / security / orchestrator / router: `Start-PhysicalServerBuild`, `Update-WindowsSecurity`, `Start-AutomationOrchestrator`, `Control`

<a name="callers-22"></a>

#### Caller + test updates

- Tests that captured the old raw return were updated to `-PassThru` (typically `-PassThru -Quiet` to keep test output quiet); assertions were not weakened. Where a command previously repurposed `-Quiet` to return the object (e.g. `Get-OneViewVersion`), that was reconciled to the standard contract (`-Quiet` = suppress report only; `-PassThru` = return object).
- Internal callers that relied on the default object return were fixed to pass `-PassThru`: `Start-PhysicalServerBuild.ps1` (its `_Step` aggregation over `Start-InstallMonitor` / `Test-PostBuildValidation` / `New-IsoBuild` / `Publish-BootIso` / `Update-Firmware`) and `scripts/testBuildDeploy.ps1` (its `Update-Firmware` / `Invoke-IsoDeploy` captures).
- `Connect-OneView` additionally fixed a pre-existing bug: its `$Json` switch auto-bound to `Test-ServerConnectivity`'s `-Json` (PowerShell parameter-name prefixing), which made the delegated connectivity probe return JSON. The delegate call is now wrapped to force `$Json = $false` so `Connect-OneView` controls JSON emission itself.
- Remaining bare `return $result` / `return @{…}` are **intentionally** internal: class-method returns (e.g. `WindowsPatcher.Build`, `FirmwareBuilder.Build`, `Start-InstallMonitor` `Monitor()`) that feed their command wrapper, and `Get-MaintenanceStatusReport`'s deliberate format-aware `-Json` / `-PassThru` / default-return-nothing block.

<a name="verification-22"></a>

#### Verification

- `tests/powershell` full suite: **520 passed, 0 failed** (across all 15 commands' `*.Tests.ps1` plus `Router.Unit.Tests.ps1`).
- `scripts/lint.ps1` (PSScriptAnalyzer): **151 files, all checks passed** (syntax + code quality).
- Smoke test (`Disconnect-OneView`): default path returns nothing on the success stream (only the human-readable report prints); `-PassThru` returns the structured `{ Message, Timestamp, Success }` hashtable; `-Json` emits a JSON string.

<a id="21-command-documentation-clarity-firmwaresecurityutility-repository-corrections"></a>

### 21) Command documentation clarity — firmware/security/utility + repository corrections

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-19 | Clarified `Update-Firmware`, `Invoke-WindowsSecurityUpdate`, `Invoke-PowerShellScript`, `Invoke-OpsRampClient` ("What it does" / Destructive) and corrected obsolete ISO-repository references (ISOs/firmware now hosted on network shares, not an HTTPS repo) | Kev Everall |

<a name="change-21"></a>

#### Change — command clarity

- **`Update-Firmware`** (doc heading "Build firmware ISO"): clarified it flashes **HPE hardware firmware only** (BIOS, iLO, Smart Array, NIC, drivers) via HPE SUT — **not** Windows OS security patches (BladeLogic's job on the live OS) — and marked **Destructive: TRUE** (flashes + reboots, gated by mandatory `-GuardRail`).
- **`Invoke-WindowsSecurityUpdate`** (doc heading "Patch Windows ISO with security updates"): clarified it patches the **ISO image offline** (DISM), **not** a live server; **Destructive: FALSE for servers** (writes a patched ISO file only). Live OS security patching remains BladeLogic's responsibility.
- **`Invoke-PowerShellScript`**: clarified it runs an arbitrary script string locally (or via `Invoke-PowerShellWinRM`); **Destructive: DEPENDS ON THE SCRIPT** — neutral wrapper, run only reviewed scripts.
- **`Invoke-OpsRampClient`**: clarified it is an OpsRamp monitoring/ITSM integration factory (+ `Invoke-OpsRamp` connectivity test); **Destructive: FALSE**.

<a name="change-21-repo"></a>

#### Change — obsolete ISO-repository references

- Per the updated environment (no ISO repository; ISOs and firmware held on network shares), the docs no longer assume a mandatory HTTPS repository:
  - `Publish-BootIso` is documented as **optional** — only needed when hosting ISOs on an HTTPS repository; otherwise supply the ISO directly from a network share via `-ExternalIsoPath`.
  - `-RepoBaseUrl` / `-RepoLocalPath` parameter descriptions now state they apply **only when hosting on an HTTPS repo**; otherwise the ISO is supplied directly from a network share.
  - The "full runbook workflow" and bootable-ISO-filename notes were reworded from "the repository" to "the share/repository where the ISO is hosted".

<a name="verification-21"></a>

#### Verification

- `automation_commands.md` shows the four commands' "What it does"/Destructive annotations and the softened repository language; no remaining mandatory-repository assumption remains for ISO sourcing.

<a id="20-command-documentation-clarity-functionality-safedestructive"></a>

### 20) Command documentation clarity — functionality + safe/destructive

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-19 | Added concise "What it does" / Destructive annotations for `Start-InstallMonitor`, `Invoke-IloRedfish`, `Get-OneViewServerTarget`, `Test-PreBuildValidation`; added a "Safe vs destructive commands" callout; expanded the ISO path-requirements table to all accepted formats; updated `-ExternalIsoPath` help/parameter notes; regenerated `docs/dynamic-code-docs` | Kev Everall |

<a name="change-20"></a>

#### Change

- `automation_commands.md`: added a "⚠ Safe vs destructive commands" callout (non-destructive vs destructive, with the mandatory `-GuardRail` gate and a zero-risk pre-flight sequence) immediately after *How the commands fit together*.
- Added scannable "What it does" bullet lists (incl. `Destructive: true/false`) for `Start-InstallMonitor`, `Invoke-IloRedfish` (per-action), `Get-OneViewServerTarget`, and `Test-PreBuildValidation` (previously undocumented).
- Expanded the ISO path-requirements table to all seven accepted formats (`https://`, `nfs://`, UNC backslash, UNC forward slash, `cifs://`, `smb://`, mapped drive) with a "point at the file, not the share" note.
- Updated the `-ExternalIsoPath` parameter/help text in `Invoke-IsoDeploy.ps1`, `Start-PhysicalServerBuild.ps1`, `Configure-PhysicalBuild.ps1` and the doc tables to list every accepted format.
- Regenerated `docs/dynamic-code-docs/` (218 files) from the updated code comments.

<a name="verification-20"></a>

#### Verification

- `docs/Automation/automation_commands.md` contains the safe/destructive callout and the per-command "What it does" blocks; `make gen-docs` regenerates `docs/dynamic-code-docs/` cleanly.

<a id="19-test-buildparams-firmware-location-validation"></a>

### 19) Test-BuildParams firmware-location validation

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-19 | `Test-BuildParams` now validates firmware component locations (`-FirmwareFolders`) through the same shared resolver as the ISO, and skips local existence checks for URL locations | Kev Everall |

<a name="change-19"></a>

#### Change

- Added `-FirmwareFolders` (string array) to `Test-BuildParams`. Each location is resolved via the shared `Resolve-ExternalIsoPath` and (unless `-DryRun`, and unless it is a URL) checked for existence with `Test-PathEx`.
- Result now includes `FirmwareResults` — a per-location `{ Location, ResolvedUrl, Exists, Error }` array — alongside the existing `IsoUrl`/`Errors`. Success requires zero errors across ISO and firmware.
- Existence checks are skipped for `http(s)://`, `nfs://`, `cifs://`, `smb://` URLs (which `Test-Path` cannot probe) — the iLO/SUT fetches them at mount time.

<a name="verification-19"></a>

#### Verification

- `Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' -FirmwareFolders @('\\fileserver\fw\BIOS','H:\fw\iLO5')` validates ISO and both firmware locations through one code path; URL locations resolve without a spurious "not found" error.

<a id="18-universal-isofirmware-path-resolver-fix-dry-consolidation"></a>

### 18) Universal ISO/firmware path resolver fix (DRY consolidation)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-19 | Fixed `Resolve-ExternalIsoPath` to accept HTTPS, NFS, `cifs://`, `smb://`, UNC (backslash + forward slash) and mapped network drives; removed duplicate copies from `Invoke-IsoDeploy.ps1` and `Start-PhysicalServerBuild.ps1` so every command resolves paths through one shared helper | Kev Everall |

<a name="root-cause-18"></a>

#### Root cause

- `Resolve-ExternalIsoPath` only matched `^https?://`, `^nfs://`, backslash `^\\\\` UNC, and `^[A-Za-z]:\\` mapped drives. Forward-slash UNC (`//server/share/file.iso`) — which Windows/PowerShell treat as identical to `\\server\share\file.iso` — plus `cifs://` and `smb://` (the schemes the tool itself emits/implies) were rejected, so `Test-BuildParams`/deploy commands failed with "Unsupported ISO path format" for those inputs.
- The resolver was **defined three times** (once in `Private/ExternalIso.ps1` and duplicated in `Invoke-IsoDeploy.ps1` and `Start-PhysicalServerBuild.ps1`), so behaviour could drift between commands.

<a name="fix-18"></a>

#### Fix

- Single canonical `Resolve-ExternalIsoPath` in `Private/ExternalIso.ps1` now accepts: `http(s)://`, `nfs://`, `cifs://` (used directly, round-trips the emitted scheme), `smb://` (normalised to `cifs://`), UNC with **either** `\\` or `//`, and mapped network drives (expanded to their UNC, then `cifs://`). Local drives (`C:\`, or a letter mapped to a local disk) are rejected. `Get-SmbPathFromDriveLetter` is now defined once alongside it.
- Deleted the two duplicate `Resolve-ExternalIsoPath` + `Get-SmbPathFromDriveLetter` copies; all four ISO/deploy commands (`Test-BuildParams`, `Configure-PhysicalBuild`, `Start-PhysicalServerBuild`, `Invoke-IsoDeploy`) now call the shared helper — eliminating the DRY violation.

<a name="verification-18"></a>

#### Verification

- `//server/share/file.iso`, `cifs://server/share/file.iso`, `smb://server/share/file.iso` now resolve to `cifs://server/share/file.iso`; `\\server\share\file.iso` continues to work; mapped drives expand to their UNC; local drives fail with the "not supported" error.
- `grep -rn "function Resolve-ExternalIsoPath"` returns exactly one definition; all command call sites resolve through it.

<a id="17-get-oneviewconnectionstatus-session-reuse-guard-no-reconnect"></a>

### 17) Get-OneViewConnectionStatus session-reuse guard (no reconnect)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Fixed `Get-OneViewConnectionStatus` to reuse the live OneView session (never reconnect) so `-OneViewHost` for the already-connected appliance reports status without a 401; also corrected the empty-string auth error message | Kev Everall |

<a name="root-cause-17"></a>

#### Root cause

- `Get-OneViewConnectionStatus` only consulted `Get-OneViewActiveSession` inside `if (-not $OneViewHost)`. Supplying `-OneViewHost` (even for the already-connected appliance) skipped the active-session lookup, so `$sessionToken` stayed `$null` and, with no `-Credential` on hand, the authenticated `/rest/server-hardware` probe was sent with no auth header → `401 (Unauthorized)`.
- The failure message interpolated the empty `$OneViewUser`, producing `OneView authentication failed for ''` — masking the real cause (no token/credential, not a bad password).

<a name="fix-17"></a>

#### Fix

- `Get-OneViewConnectionStatus` now consults `Get-OneViewActiveSession` **unconditionally**. If a live session exists it reuses the session token and never reconnects — matching the "existing connection always wins" guard already used by `Resolve-OneViewSession` / `Connect-OneViewSession`. Same appliance is silent reuse; a different appliance reuses the active session and warns (run `Disconnect-OneView` first to switch). Only when no session is active and `-OneViewHost` is supplied does it fall through to an explicit credentialed connect.
- Corrected the auth-failure message: it now reports the session-auth path, the `-Credential` username, or "no active session and no credentials supplied" — never an empty `''`.

<a name="verification-17"></a>

#### Verification

- `Get-OneViewConnectionStatus.Unit.Tests.ps1`: **23 passed, 0 failed**, including two new regression tests — reuses the active session when `-OneViewHost` matches the connected appliance (no reconnect, no 401), and reuses the active session even when `-OneViewHost` differs (guard: never reconnect).
- `Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01` against a live session now shows connection/server info exactly like a second bare run, with no 401.

<a id="16-docs-anchor-fix-navigable-id-anchors-for-make-docs-make-fix-docs"></a>

### 16) Docs anchor fix — navigable `id` anchors for `make docs` / `make fix-docs`

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Fixed `make docs` / `make fix-docs` (`add-anchors`) so generated TOC anchors use `<a id="…">` (navigable on GitHub / VS Code) instead of the deprecated `<a name="…">`, and stopped the generator from re-stacking a duplicate `id`+`name` anchor on re-runs | Kev Everall |

<a name="root-cause-16"></a>

#### Root cause

- `scripts/bitbucket-md-anchor-toc.ps1` (via the shared `scripts/Docs.Common.ps1`) emitted heading anchors as `<a name="…"></a>` and `Test-TocValidity` expected that exact `name` form.
- GitHub and the VS Code Markdown preview ignore the `name` attribute for in-page navigation, so every TOC link (`](#slug)`) failed to jump — the table of contents did not work.
- `Remove-ExistingAnchors` only stripped `<a name="…">` lines, never `<a id="…">`. A second run (or any `id`-based edit) therefore left the old `id` anchor in place and re-added a `name` anchor above it, producing duplicate `<a id="…"></a>` + `<a name="…"></a>` pairs and MD012 (multiple-blank-line) churn.

<a name="fix-16"></a>

#### Fix

- `scripts/Docs.Common.ps1` (`Build-CanonicalContent`, ~line 245): emit `<a id="…"></a>` instead of `<a name="…"></a>`. The slug algorithm (`Get-Anchor`) was already GitHub / VS Code-compatible, so only the attribute needed to change.
- `scripts/Docs.Common.ps1` (`Remove-ExistingAnchors`, ~line 181): the anchor-stripping regex now matches both forms — `^<a (?:name|id)="[^"]*"></a>$` — so a regeneration fully replaces prior anchors instead of stacking duplicates.
- `scripts/bitbucket-md-anchor-toc.ps1` (`Test-TocValidity`, ~line 134): the expected anchor tag is now `<a id="…"></a>`, so the validator accepts (rather than rejects) the corrected form.

<a name="verification-16"></a>

#### Verification

- Ran `make fix-docs` after the fix: **83/83 markdown files pass**, 0 failures.
- `wip/testing-issues.md` (the file that originally showed the bug): **0 `<a name=…>` anchors, 0 duplicate `id` slugs, 0 unresolved TOC links, 0 anchors trapped inside code fences, 0 MD012 runs.** The reported duplicate pair is now a single navigable `<a id="connect-oneview-oneviewhost-va-oneviewt-01-0"></a>`.

<a id="15-connect-oneview-converttowildcardregex-docs-alias-inventory-tests"></a>

### 15) `Connect-OneView` & `ConvertToWildcardRegex` docs + alias inventory tests

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Documented `Connect-OneView`'s connectivity result handling (`_Complete-ConnectOneViewResult`) and `_ConvertToWildcardRegex`; added `OneViewAliasInventory.Unit.Tests.ps1` to verify documented aliases exist in parameter metadata | Kev Everall |

<a name="docs-15"></a>

#### Documentation

- Added `docs/dynamic-code-docs/_Complete-ConnectOneViewResult.md` describing `Connect-OneView`'s connectivity result object, and `_ConvertToWildcardRegex.md` describing the PowerShell-wildcard → regex conversion used by the §14 filter.
- `automation_commands.md` and `runbook-requirements-v2.md` refreshed to match current signatures.

<a name="alias-inventory-tests"></a>

#### Alias inventory tests

- New `tests/powershell/OneViewAliasInventory.Unit.Tests.ps1` validates that **every documented custom alias is present in the command's parameter metadata**, closing the gap between docs and implementation so an alias documented in `automation_commands.md` can never silently disappear from the code.

<a name="verification-15"></a>

#### Verification

- `OneViewAliasInventory.Unit.Tests.ps1` parses the documented alias table and asserts each alias resolves on the real command; failures surface a missing alias immediately. Passes under `make test`.

<a id="14-parameter-rename-srvrid-serveridentifier-wildcard-filtering-in-get-oneviewserverlist"></a>

### 14) Parameter rename `SrvrId` → `ServerIdentifier` + wildcard filtering in `Get-OneViewServerList`

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-18 | Renamed `-SrvrId` → `-ServerIdentifier` across commands/tests for consistency; `Get-OneViewServerList` gained a `-Filter` supporting PowerShell-style wildcards for name/health/power | Kev Everall |

<a name="rename-14"></a>

#### Parameter rename `SrvrId` → `ServerIdentifier`

- Reverted the earlier abbreviation (see `8f71040` "abbreviate OneView command parameters") in favour of the explicit, self-documenting `-ServerIdentifier` across `Configure-PhysicalBuild`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`, `Start-PhysicalServerBuild`, `Test-PreBuildValidation`, their unit tests, and `automation_commands.md`.

<a name="wildcard-filtering"></a>

#### Wildcard filtering in `Get-OneViewServerList`

- New `-Filter` parses `health:<value>` / `power:<value>` / `name:<value>` into case-insensitive predicate regexes validated before connecting. Matching is **substring-by-default** (e.g. `health:Critical`, `name:PROD`) and honours PowerShell wildcards (`*`, `?`) via the shared `_ConvertToWildcardRegex` (e.g. `name:PROD-*`, `name:srv-0?`).
- `_ConvertToWildcardRegex` (anchored, case-insensitive) lives alongside the command; unsupported filter forms return a clear `Unsupported -Filter …` error with no connection attempted.

<a name="verification-14"></a>

#### Verification

- `Get-OneViewServerList -Filter 'name:PROD-*'` matches `PROD-SRV-01`; `health:*Warning*` matches warning states; `power:On` filters by power; `name:PROD` substring-matches; an invalid filter returns the `Unsupported -Filter` error. `Get-OneViewServerTarget.Unit.Tests.ps1` (51 lines added) and the renamed-parameter tests pass.

<a id="13-test-buildparams-_validate-request-hardening"></a>

### 13) `Test-BuildParams` / `_Validate-Request` hardening

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-17 | `Test-BuildParams` now validates and resolves the base ISO path to an iLO boot URL (rejecting local drives) and returns a structured result; `_Validate-Request` + `Validators` tests hardened | Kev Everall |

<a name="root-cause-13"></a>

#### Change

- `Test-BuildParams` shifted from "return a list of error strings" to "validate the base Windows ISO path and **resolve the iLO boot URL**". It now accepts a UNC/SMB or HTTPS path and produces a structured result (`Success`, `IsoUrl` → `cifs://…` or `https://…`), explicitly **rejecting local drive paths** on the automation host (consistent with the §1 admin-code-removal rule).
- `_Validate-Request` tightened its checks; `Validators.Unit.Tests.ps1` expanded (32 lines) to cover the new resolution behaviour. `automation_commands.md` regenerated to reflect the revised contract.

<a name="verification-13"></a>

#### Verification

- `Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'` → `Success=$true`, `IsoUrl='cifs://fileserver/isos/WinSrv2025.iso'`; `https://…` resolves to `https://…`; local-drive paths fail validation. `Validators` unit tests pass.

<a id="12-shared-output-formatting-connect-oneview-rewrite-runbook-v2"></a>

### 12) Shared output formatting + `Connect-OneView` rewrite + runbook v2

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

<a name="verification-12"></a>

#### Verification

- `Connect-OneView -DryRun` returns the structured result; `-Json` emits a compact JSON string; `-PassThru` returns the hashtable; `_Format-ConnectivityResult`/`_Format-HumanReadable` exercised by the updated `Connect-OneView.Tests.ps1`. `make test` green.

<a id="11-testing-issues-documentation-oneview-connectivity"></a>

### 11) Testing-issues documentation (OneView connectivity)

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-14 | Added `wip/testing-issues.md` capturing detailed OneView connectivity test issues and ongoing investigation notes | Kev Everall |

<a name="scope"></a>

#### Scope

- `docs: add detailed testing issues documentation for OneView connectivity tests` introduced `wip/testing-issues.md` (694 lines) logging live-connectivity failures, environment/config gaps, and remediation ideas for the OneView test surface.
- A later commit extended the same working file with further findings (843 lines added), keeping the investigation trail in one place under `wip/` rather than fragmenting it across commit messages.

<a id="10-repo-hygiene-lf-normalization-git-workflow-docs"></a>

### 10) Repo hygiene: LF normalization + git workflow docs

| **Date** | **Change description summary** | **Author** |
| --- | --- | --- |
| 2026-08-13 | Added `.gitattributes` to normalise line endings (stop `.md`/`.ps1` churn across Stash/GitHub) and documented the rebase-hell-free git workflow in `git_process.md` | Kev Everall |

<a name="line-endings"></a>

#### Line-ending normalization

- Added `.gitattributes` with `*.md`/`*.ps1` (and related text) set to `eol=lf` so cross-platform editors and the Stash↔GitHub mirror stop generating meaningless whole-file diffs on every commit.

<a name="git-workflow-docs"></a>

#### Git workflow docs (`git_process.md`)

- Added `git_process.md` describing a rebase-hell-free flow: `pull.ff only`, a Stash mirror, and a one-`reset` recovery path; later expanded for clarity/structure. (The standalone file was subsequently consolidated/removed in favour of the in-repo guidance — see §11 — leaving `.gitattributes` as the durable change.)

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

<a id="2-maintenance-mode-progress-report-for-dl"></a>

### 2) Maintenance mode progress report for DL

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Runbook alignment | Kev Everall |

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

Per `runbook-requirements-v2.md`, maintenance mode is a **separate operational concern** from the ISO build/deploy pipeline. The 2-command workflow (`Configure-PhysicalBuild` + `Start-PhysicalBuild`) does not include maintenance mode commands — they're standalone SCOM/OneView orchestration tools.

<a id="1-command-consolidation-2-command-workflow-runbook-aligned"></a>

### 1) Command consolidation — 2-command workflow (runbook-aligned)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Resolves full server identity from OneView, Fix ISO URL, Fix Test-PreBuildValidation, Prints comprehensive summary, added confirmation prompt | Kev Everall |

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

 

$cred = Get-Credential

# Step 1: Login to get session token
$login = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/login-sessions" `
    -ContentType "application/json" -Method Post `
    -Body "{""userName"":""$($cred.UserName)"",""password"":""$($cred.GetNetworkCredential().Password)"",""loginMsgAck"":""true""}" `
    -SkipCertificateCheck
$token = $login.sessionID
Write-Host "Session token: $token"

# Step 2: Without expand=all
$r1 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=1" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== WITHOUT expand=all ==="
$r1.members[0] | ConvertTo-Json -Depth 3

# Step 3: With expand=all
$r2 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=1&expand=all" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== WITH expand=all ==="
$r2.members[0] | ConvertTo-Json -Depth 5

# Step 4: Check a known maintenance mode server specifically
$r3 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?filter=`"name='omg-qlikview-03ilo'`"&expand=all" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== MAINTENANCE MODE SERVER (omg-qlikview-03ilo) ==="
$r3.members[0] | ConvertTo-Json -Depth 5

 image-build-automation  main  $login = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/login-sessions" `    -ContentType "application/json" -Method Post `    -Body "{""userName"":""$($cred.UserName)"",""password"":""$($cred.GetNetworkCredential().Password)""}" `    -SkipCertificateCheck
   image-build-automation  main  $token = $login.sessionID                                                                                                            0  15s 906ms  15:35:53    image-build-automation  main  $token                                                                                                                                          0  15:36:25 LTMxMDE3NDkzNjQ158u8rhxN1re_FrDmcSo2ac5NL2ePdGAD
   image-build-automation  main  Write-Host "Session token: $token"                                                                                                              0  15:36:31 Session token: LTMxMDE3NDkzNjQ158u8rhxN1re_FrDmcSo2ac5NL2ePdGAD 
   image-build-automation  main  $r1 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=1" `    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
   image-build-automation  main  $r1.members[0] | ConvertTo-Json -Depth 3                                                                                                        0  15:37:01 {
  "type": "server-hardware-1",
  "name": "OMG-STARWAY-01ILO.AD.AIB.PRI", 
  "state": "Monitored",
  "stateReason": "NotApplicable",
  "assetTag": "",
  "category": "server-hardware",
  "created": "2025-04-23T15:53:44.383Z",  
  "description": null,
  "eTag": "1789118046173",
  "formFactor": "1U",
  "licensingIntent": "OneViewStandard",
  "locationUri": null,
  "memoryMb": 98304,
  "model": "ProLiant DL360 Gen10",
  "modified": "2026-09-11T09:14:06.173Z",
  "mpDnsName": "OMG-STARWAY-01ILO.AD.AIB.PRI",
  "mpFirmwareVersion": "3.14 Jun 16 2025",
  "mpIpAddress": "10.239.230.72",
  "mpModel": "iLO5",
  "partNumber": "867959-B21",
  "portMap": null,
  "position": 0,
  "powerLock": false,
  "powerState": "On",
  "processorCoreCount": 10,
  "processorCount": 2,
  "processorSpeedMhz": 2200,
  "processorType": "Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz",
  "refreshState": "NotRefreshing",
  "romVersion": "U32 v3.50 (04/17/2025)",
  "serialNumber": "CZJ831052N",
  "serverGroupUri": null,
  "serverHardwareTypeUri": null,
  "serverProfileUri": null,
  "shortModel": "DL360 Gen10",
  "signature": null,
  "status": "OK",
  "uri": "/rest/server-hardware/39373638-3935-5A43-4A38-33313035324E",
  "uuid": "39373638-3935-5A43-4A38-33313035324E",
  "virtualSerialNumber": null,
  "virtualUuid": null
}
   image-build-automation  main  # Step 3: With expand=all                                                                                                                       0  15:37:13    image-build-automation  main  $r2 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=1&expand=all" `                                     0  15:37:42 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
   image-build-automation  main  Write-Host "=== WITH expand=all ==="                                                                                                            0  15:37:42 
=== WITH expand=all === 
   image-build-automation  main  $r2.members[0] | ConvertTo-Json -Depth 5                                                                                                        0  15:37:44 {
  "type": "server-hardware-1",
  "name": "OMG-STARWAY-01ILO.AD.AIB.PRI", 
  "state": "Monitored",
  "stateReason": "NotApplicable",
  "assetTag": "",
  "category": "server-hardware",
  "created": "2025-04-23T15:53:44.383Z",  
  "description": null,
  "eTag": "1789118046173",
  "formFactor": "1U",
  "licensingIntent": "OneViewStandard",
  "locationUri": null,
  "memoryMb": 98304,
  "model": "ProLiant DL360 Gen10",
  "modified": "2026-09-11T09:14:06.173Z",
  "mpDnsName": "OMG-STARWAY-01ILO.AD.AIB.PRI",
  "mpFirmwareVersion": "3.14 Jun 16 2025",
  "mpIpAddress": "10.239.230.72",
  "mpModel": "iLO5",
  "partNumber": "867959-B21",
  "portMap": null,
  "position": 0,
  "powerLock": false,
  "powerState": "On",
  "processorCoreCount": 10,
  "processorCount": 2,
  "processorSpeedMhz": 2200,
  "processorType": "Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz",
  "refreshState": "NotRefreshing",
  "romVersion": "U32 v3.50 (04/17/2025)",
  "serialNumber": "CZJ831052N",
  "serverGroupUri": null,
  "serverHardwareTypeUri": null,
  "serverProfileUri": null,
  "shortModel": "DL360 Gen10",
  "signature": null,
  "status": "OK",
  "uri": "/rest/server-hardware/39373638-3935-5A43-4A38-33313035324E",
  "uuid": "39373638-3935-5A43-4A38-33313035324E",
  "virtualSerialNumber": null,
  "virtualUuid": null
}
   image-build-automation  main  # Step 4: Check a known maintenance mode server specifically                                                                                    0  15:37:57    image-build-automation  main  $r3 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?filter=`"name='omg-qlikview-03ilo'`"&expand=all" `                0  15:38:10 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck 
   image-build-automation  main  Write-Host "=== MAINTENANCE MODE SERVER (omg-qlikview-03ilo) ==="                                                                               0  15:38:11 === MAINTENANCE MODE SERVER (omg-qlikview-03ilo) ===
   image-build-automation  main  $r3.members[0] | ConvertTo-Json -Depth 5                                                                                                        0  15:38:23 
WARNING: Resulting JSON is truncated as serialization has exceeded the set depth of 5. 
{
  "type": "server-hardware-1",
  "name": "omg-qlikview-03ilo",
  "state": "ProfileApplied",
  "stateReason": "NotApplicable",        
  "assetTag": "",
  "category": "server-hardware",
  "created": "2026-05-27T13:54:53.991Z", 
  "description": null,
  "eTag": "1790001222188",
  "formFactor": "1U",
  "licensingIntent": "OneViewNoiLO",
  "locationUri": null,
  "memoryMb": 1048576,
  "model": "ProLiant DL360 Gen10 Plus",
  "modified": "2026-09-21T14:33:42.188Z",
  "mpDnsName": "omg-qlikview-03ilo",
  "mpFirmwareVersion": "3.14 Jun 16 2025",
  "mpIpAddress": "10.30.54.22",
  "mpModel": "iLO5",
  "partNumber": "P28948-B21",
  "portMap": {
    "deviceSlots": [
      {
        "deviceName": "Marvell 2P 10GbE SFP+ QL41132HQCU-HC OCP3 Adapter",
        "location": "Ocp",
        "oaSlotNumber": 4,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:BA:2C:00:7B:78",
            "portNumber": 1,
            "type": "Ethernet",
            "virtualPorts": ""
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:BA:2C:00:7B:79",
            "portNumber": 2,
            "type": "Ethernet",
            "virtualPorts": ""
          }
        ],
        "slotNumber": 10
      },
      {
        "deviceName": "HPE SN1610Q 32Gb 2p FC HBA",
        "location": "Pci",
        "oaSlotNumber": 1,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:D4",
            "portNumber": 1,
            "type": "FibreChannel",
            "virtualPorts": ""
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:D6",
            "portNumber": 2,
            "type": "FibreChannel",
            "virtualPorts": ""
          }
        ],
        "slotNumber": 3
      },
      {
        "deviceName": "HPE SN1610Q 32Gb 2p FC HBA",
        "location": "Pci",
        "oaSlotNumber": 2,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:DC",
            "portNumber": 1,
            "type": "FibreChannel",
            "virtualPorts": ""
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:DE",
            "portNumber": 2,
            "type": "FibreChannel",
            "virtualPorts": ""
          }
        ],
        "slotNumber": 1
      },
      {
        "deviceName": "Marvell FastLinQ 41000 Series - 2P 10GbE SFP+ QL41132HLCU-HC MD2 Adapter - NIC",
        "location": "Pci",
        "oaSlotNumber": 3,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:ED:8C:82:EA:1A",
            "portNumber": 1,
            "type": "Ethernet",
            "virtualPorts": ""
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:ED:8C:82:EA:1B",
            "portNumber": 2,
            "type": "Ethernet",
            "virtualPorts": ""
          }
        ],
        "slotNumber": 2
      }
    ]
  },
  "position": 0,
  "powerLock": false,
  "powerState": "Off",
  "processorCoreCount": 32,
  "processorCount": 2,
  "processorSpeedMhz": 2000,
  "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
  "refreshState": "NotRefreshing",
  "romVersion": "U46 v2.42 (06/13/2025)",
  "serialNumber": "CZ22420JCN",
  "serverGroupUri": null,
  "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
  "serverProfileUri": "/rest/server-profiles/353a5d94-4c08-4374-a6e2-883f241ad7c9",
  "shortModel": "DL360 Gen10 Plus",
  "signature": null,
  "status": "OK",
  "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E",
  "uuid": "39383250-3834-5A43-3232-3432304A434E",
  "virtualSerialNumber": null,
  "virtualUuid": null

  $cred = Get-Credential

# Login
$login = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/login-sessions" `
    -ContentType "application/json" -Method Post `
    -Body "{""userName"":""$($cred.UserName)"",""password"":""$($cred.GetNetworkCredential().Password)"",""authLoginDomain"":""LOCAL""}" `
    -SkipCertificateCheck
$token = $login.sessionID

# GET individual server hardware resource (same URI that Enable-OVMaintenanceMode PATCHes)
$r4 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
$r4 | ConvertTo-Json -Depth 10

# Try GETting maintenance mode as a sub-resource
$r5 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E/maintenanceMode" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
$r5 | ConvertTo-Json -Depth 3

 $r4 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E" `                    0  917ms  15:54:49 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
   image-build-automation  main  $r4 | ConvertTo-Json -Depth 10                                                                                                                  0  15:55:23 
{
  "type": "server-hardware-1",
  "name": "omg-qlikview-03ilo",
  "state": "ProfileApplied",
  "stateReason": "NotApplicable",        
  "assetTag": "",
  "category": "server-hardware",
  "created": "2026-05-27T13:54:53.991Z", 
  "description": null,
  "eTag": "1790002502209",
  "formFactor": "1U",
  "licensingIntent": "OneViewNoiLO",
  "locationUri": null,
  "memoryMb": 1048576,
  "model": "ProLiant DL360 Gen10 Plus",
  "modified": "2026-09-21T14:55:02.209Z",
  "mpDnsName": "omg-qlikview-03ilo",
  "mpFirmwareVersion": "3.14 Jun 16 2025",
  "mpIpAddress": "10.30.54.22",
  "mpModel": "iLO5",
  "partNumber": "P28948-B21",
  "portMap": {
    "deviceSlots": [
      {
        "deviceName": "Marvell 2P 10GbE SFP+ QL41132HQCU-HC OCP3 Adapter",
        "location": "Ocp",
        "oaSlotNumber": 4,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:BA:2C:00:7B:78",
            "portNumber": 1,
            "type": "Ethernet",
            "virtualPorts": []
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:BA:2C:00:7B:79",
            "portNumber": 2,
            "type": "Ethernet",
            "virtualPorts": []
          }
        ],
        "slotNumber": 10
      },
      {
        "deviceName": "HPE SN1610Q 32Gb 2p FC HBA",
        "location": "Pci",
        "oaSlotNumber": 1,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:D4",
            "portNumber": 1,
            "type": "FibreChannel",
            "virtualPorts": []
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:D6",
            "portNumber": 2,
            "type": "FibreChannel",
            "virtualPorts": []
          }
        ],
        "slotNumber": 3
      },
      {
        "deviceName": "HPE SN1610Q 32Gb 2p FC HBA",
        "location": "Pci",
        "oaSlotNumber": 2,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:DC",
            "portNumber": 1,
            "type": "FibreChannel",
            "virtualPorts": []
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "51:40:2E:C0:17:36:A1:DE",
            "portNumber": 2,
            "type": "FibreChannel",
            "virtualPorts": []
          }
        ],
        "slotNumber": 1
      },
      {
        "deviceName": "Marvell FastLinQ 41000 Series - 2P 10GbE SFP+ QL41132HLCU-HC MD2 Adapter - NIC",
        "location": "Pci",
        "oaSlotNumber": 3,
        "physicalPorts": [
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:ED:8C:82:EA:1A",
            "portNumber": 1,
            "type": "Ethernet",
            "virtualPorts": []
          },
          {
            "interconnectPort": 0,
            "interconnectUri": null,
            "mac": "5C:ED:8C:82:EA:1B",
            "portNumber": 2,
            "type": "Ethernet",
            "virtualPorts": []
          }
        ],
        "slotNumber": 2
      }
    ]
  },
  "position": 0,
  "powerLock": false,
  "powerState": "Off",
  "processorCoreCount": 32,
  "processorCount": 2,
  "processorSpeedMhz": 2000,
  "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
  "refreshState": "NotRefreshing",
  "romVersion": "U46 v2.42 (06/13/2025)",
  "serialNumber": "CZ22420JCN",
  "serverGroupUri": null,
  "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
  "serverProfileUri": "/rest/server-profiles/353a5d94-4c08-4374-a6e2-883f241ad7c9",
  "shortModel": "DL360 Gen10 Plus",
  "signature": null,
  "status": "OK",
  "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E",
  "uuid": "39383250-3834-5A43-3232-3432304A434E",
  "virtualSerialNumber": null,
  "virtualUuid": null
}
   image-build-automation  main  $r5 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E/maintenanceMode" `           0  15:55:31 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Invoke-RestMethod:                                                                                                       
{
  "errorSource": null,
  "data": {},
  "details": "The requested resource could not be found.",    
  "message": "Not Found",
  "recommendedActions": [
    "Check the request URI, then resend the request.",        
    "Verify if the request requires an X-API-Version header." 
  ],
  "messageParameters": [],
  "errorCode": "GENERIC_HTTP_404",
  "nestedErrors": []
}
   image-build-automation  main  $r5 | ConvertTo-Json -Depth 3                                                                                                                   1  15:56:02 null 
   image-build-automation  main  $r5 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E/maintenanceMode" `           0  15:57:01 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck 
Invoke-RestMethod:                                                                                                       
{
  "recommendedActions": [
    "Check the request URI, then resend the request.",        
    "Verify if the request requires an X-API-Version header." 
  ],
  "errorSource": null,
  "details": "The requested resource could not be found.",    
  "data": {},
  "message": "Not Found",
  "messageParameters": [],
  "nestedErrors": [],
  "errorCode": "GENERIC_HTTP_404"
}

$cred = Get-Credential

# Login
$login = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/login-sessions" `
    -ContentType "application/json" -Method Post `
    -Body "{""userName"":""$($cred.UserName)"",""password"":""$($cred.GetNetworkCredential().Password)"",""authLoginDomain"":""LOCAL""}" `
    -SkipCertificateCheck
$token = $login.sessionID

# GET individual server hardware resource (no expand=all)
$r6 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== INDIVIDUAL (no expand=all) ==="
$r6 | ConvertTo-Json -Depth 10

# GET individual server hardware resource (with expand=all)
$r7 = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E?expand=all" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== INDIVIDUAL (with expand=all) ==="
$r7 | ConvertTo-Json -Depth 10

$cred = Get-Credential

# Login
$login = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/login-sessions" `
    -ContentType "application/json" -Method Post `
    -Body "{""userName"":""$($cred.UserName)"",""password"":""$($cred.GetNetworkCredential().Password)"",""authLoginDomain"":""LOCAL""}" `
    -SkipCertificateCheck
$token = $login.sessionID

# Query servers in maintenance mode
$r_mm = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=-1&query=`"maintenanceMode:'true'`"" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== SERVERS IN MAINTENANCE MODE ==="
$r_mm | ConvertTo-Json -Depth 3
Write-Host "Total: $($r_mm.total)"

# Compare: all servers
$r_all = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=-1" `
    -Headers @{ auth = $token } -Method Get -SkipCertificateCheck
Write-Host "=== ALL SERVERS ==="
Write-Host "Total: $($r_all.total)"

Import-Module HPEOneView.1000
Connect-OVMgmt -Appliance va-oneviewt-01 -Credential $cred
$mm_servers = Get-OVServer -MaintenanceMode:$true
Write-Host "Maintenance mode servers: $($mm_servers.Count)"
$mm_servers | Select-Object name, state, uri

 # Query servers in maintenance mode                                                                                                             0  16:32:33    image-build-automation  main  $r_mm = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=-1&query=`"maintenanceMode:'true'`"" `            0  16:33:15 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck 
   image-build-automation  main  Write-Host "=== SERVERS IN MAINTENANCE MODE ==="                                                                                                0  16:33:19 === SERVERS IN MAINTENANCE MODE ===
   image-build-automation  main  $r_mm | ConvertTo-Json -Depth 3                                                                                                                 0  16:33:36 WARNING: Resulting JSON is truncated as serialization has exceeded the set depth of 3. 
{
  "type": "server-hardware-list-1",      
  "category": "server-hardware",
  "count": 16,
  "created": "2026-09-21T15:33:19.717Z", 
  "eTag": "1790004799717",
  "members": [
    {
      "type": "server-hardware-1",
      "name": "OMG-STARWAY-01ILO.AD.AIB.PRI",
      "state": "Monitored",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2025-04-23T15:53:44.383Z",
      "description": null,
      "eTag": "1789118046173",
      "formFactor": "1U",
      "licensingIntent": "OneViewStandard",
      "locationUri": null,
      "memoryMb": 98304,
      "model": "ProLiant DL360 Gen10",
      "modified": "2026-09-11T09:14:06.173Z",
      "mpDnsName": "OMG-STARWAY-01ILO.AD.AIB.PRI",
      "mpFirmwareVersion": "3.14 Jun 16 2025",
      "mpIpAddress": "10.239.230.72",
      "mpModel": "iLO5",
      "partNumber": "867959-B21",
      "portMap": null,
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 10,
      "processorCount": 2,
      "processorSpeedMhz": 2200,
      "processorType": "Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U32 v3.50 (04/17/2025)",
      "serialNumber": "CZJ831052N",
      "serverGroupUri": null,
      "serverHardwareTypeUri": null,
      "serverProfileUri": null,
      "shortModel": "DL360 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39373638-3935-5A43-4A38-33313035324E",
      "uuid": "39373638-3935-5A43-4A38-33313035324E",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "ALP-WISCLU-01ilo",
      "state": "Monitored",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2025-05-30T11:40:47.989Z",
      "description": null,
      "eTag": "1789589197736",
      "formFactor": "2U",
      "licensingIntent": "OneViewStandard",
      "locationUri": null,
      "memoryMb": 786432,
      "model": "ProLiant DL380 Gen9",
      "modified": "2026-09-16T20:06:37.736Z",
      "mpDnsName": "ALP-WISCLU-01ilo",
      "mpFirmwareVersion": "2.82 Feb 06 2023",
      "mpIpAddress": "10.30.13.115",
      "mpModel": "iLO4",
      "partNumber": "719064-B21",
      "portMap": null,
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 16,
      "processorCount": 2,
      "processorSpeedMhz": 2300,
      "processorType": "Intel(R) Xeon(R) CPU E5-2698 v3 @ 2.30GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "P89 v2.92 (11/23/2021)",
      "serialNumber": "CZ3508PYS5",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/141F3994-C597-4A65-8EC7-8899E5FF7AFA",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen9",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/30393137-3436-5A43-3335-303850595335",
      "uuid": "30393137-3436-5A43-3335-303850595335",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "OMG-WISCLU-01ilo",
      "state": "Monitored",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2025-05-30T11:45:50.062Z",
      "description": null,
      "eTag": "1789589147766",
      "formFactor": "2U",
      "licensingIntent": "OneViewStandard",
      "locationUri": null,
      "memoryMb": 786432,
      "model": "ProLiant DL380 Gen9",
      "modified": "2026-09-16T20:05:47.766Z",
      "mpDnsName": "OMG-WISCLU-01ilo",
      "mpFirmwareVersion": "2.82 Feb 06 2023",
      "mpIpAddress": "10.30.52.142",
      "mpModel": "iLO4",
      "partNumber": "",
      "portMap": null,
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 14,
      "processorCount": 2,
      "processorSpeedMhz": 2600,
      "processorType": "Intel(R) Xeon(R) CPU E5-2697 v3 @ 2.60GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "P89 v2.92 (11/23/2021)",
      "serialNumber": "CZJ5500337",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/141F3994-C597-4A65-8EC7-8899E5FF7AFA",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen9",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/00000000-0000-5A43-4A35-353030333337",
      "uuid": "00000000-0000-5A43-4A35-353030333337",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "ALP-STARWAY-01ILO",
      "state": "Monitored",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2025-09-22T09:55:27.265Z",
      "description": null,
      "eTag": "1789554569027",
      "formFactor": "1U",
      "licensingIntent": "OneViewStandard",
      "locationUri": null,
      "memoryMb": 98304,
      "model": "ProLiant DL360 Gen10",
      "modified": "2026-09-16T10:29:29.027Z",
      "mpDnsName": "ALP-STARWAY-01ILO",
      "mpFirmwareVersion": "3.14 Jun 16 2025",
      "mpIpAddress": "10.239.228.76",
      "mpModel": "iLO5",
      "partNumber": "867959-B21",
      "portMap": null,
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 10,
      "processorCount": 2,
      "processorSpeedMhz": 2200,
      "processorType": "Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U32 v3.50 (04/17/2025)",
      "serialNumber": "CZJ831052R",
      "serverGroupUri": null,
      "serverHardwareTypeUri": null,
      "serverProfileUri": null,
      "shortModel": "DL360 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39373638-3935-5A43-4A38-333130353252",
      "uuid": "39373638-3935-5A43-4A38-333130353252",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "gam-isechost-02-03ilo.ad.ad.pri",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-02-12T14:01:48.385Z",
      "description": null,
      "eTag": "1790004722277",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1572864,
      "model": "ProLiant DL380 Gen10",
      "modified": "2026-09-21T15:32:02.277Z",
      "mpDnsName": "gam-isechost-02-03ilo.ad.ad.pri",
      "mpFirmwareVersion": "3.11 Feb 25 2025",
      "mpIpAddress": "10.30.14.83",
      "mpModel": "iLO5",
      "partNumber": "868703-B21",
      "portMap": {
        "deviceSlots": "    "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 20,
      "processorCount": 2,
      "processorSpeedMhz": 2500,
      "processorType": "Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U30 v3.42 (02/21/2025)",
      "serialNumber": "CZ29350B60",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/DA50F74C-4EF1-4A7D-8090-EBFAB3DE4067",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/37383638-3330-5A43-3239-333530423630",
      "uuid": "37383638-3330-5A43-3239-333530423630",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "gamdmzhost-01-03ilo.AD.AIB.PRI",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-02-12T14:02:45.21Z",
      "description": null,
      "eTag": "1790004512332",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1572864,
      "model": "ProLiant DL380 Gen10",
      "modified": "2026-09-21T15:28:32.332Z",
      "mpDnsName": "gamdmzhost-01-03ilo.AD.AIB.PRI",
      "mpFirmwareVersion": "3.11 Feb 25 2025",
      "mpIpAddress": "10.30.14.80",
      "mpModel": "iLO5",
      "partNumber": "868703-B21",
      "portMap": {
        "deviceSlots": "    "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 20,
      "processorCount": 2,
      "processorSpeedMhz": 2500,
      "processorType": "Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U30 v3.42 (02/21/2025)",
      "serialNumber": "CZ29350B5Y",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/DA50F74C-4EF1-4A7D-8090-EBFAB3DE4067",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/37383638-3330-5A43-3239-333530423559",
      "uuid": "37383638-3330-5A43-3239-333530423559",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "gamdmzhost-02-03ilo",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-02-12T14:04:15.266Z",
      "description": null,
      "eTag": "1790004702296",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1572864,
      "model": "ProLiant DL380 Gen10",
      "modified": "2026-09-21T15:31:42.296Z",
      "mpDnsName": "gamdmzhost-02-03ilo",
      "mpFirmwareVersion": "3.11 Feb 25 2025",
      "mpIpAddress": "10.30.14.81",
      "mpModel": "iLO5",
      "partNumber": "868703-B21",
      "portMap": {
        "deviceSlots": "    "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 20,
      "processorCount": 2,
      "processorSpeedMhz": 2500,
      "processorType": "Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U30 v3.42 (02/21/2025)",
      "serialNumber": "CZ29350B5Z",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/DA50F74C-4EF1-4A7D-8090-EBFAB3DE4067",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/37383638-3330-5A43-3239-33353042355A",
      "uuid": "37383638-3330-5A43-3239-33353042355A",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "gamisechost-01-03ilo.AD.AIB.PRI",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-02-12T14:05:10.881Z",
      "description": null,
      "eTag": "1790004672224",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1572864,
      "model": "ProLiant DL380 Gen10",
      "modified": "2026-09-21T15:31:12.224Z",
      "mpDnsName": "gamisechost-01-03ilo.AD.AIB.PRI",
      "mpFirmwareVersion": "3.11 Feb 25 2025",
      "mpIpAddress": "10.30.14.82",
      "mpModel": "iLO5",
      "partNumber": "868703-B21",
      "portMap": {
        "deviceSlots": "    "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 20,
      "processorCount": 2,
      "processorSpeedMhz": 2500,
      "processorType": "Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U30 v3.42 (02/21/2025)",
      "serialNumber": "CZ29350B61",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/DA50F74C-4EF1-4A7D-8090-EBFAB3DE4067",
      "serverProfileUri": null,
      "shortModel": "DL380 Gen10",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/37383638-3330-5A43-3239-333530423631",
      "uuid": "37383638-3330-5A43-3239-333530423631",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "OMG-CONSTC2-02ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-04-23T10:56:12.745Z",
      "description": null,
      "eTag": "1789970243239",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "HPE ProLiant Compute DL380 Gen12",
      "modified": "2026-09-21T05:57:23.239Z",
      "mpDnsName": "OMG-CONSTC2-02ilo",
      "mpFirmwareVersion": "1.14.00 May 28 2025",
      "mpIpAddress": "10.239.231.29",
      "mpModel": "iLO7",
      "partNumber": "P73282-B21",
      "portMap": {
        "deviceSlots": "       "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 8,
      "processorCount": 2,
      "processorSpeedMhz": 4000,
      "processorType": "Intel(R) Xeon(R) 6507P",
      "refreshState": "NotRefreshing",
      "romVersion": "U68 v1.52 (10/03/2025)",
      "serialNumber": "CZ2D3701LY",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/C254F851-C838-49C2-9384-3CB803CC9B13",
      "serverProfileUri": "/rest/server-profiles/084ab200-2c27-4b9a-8770-5d69276ec1ea",
      "shortModel": "DL380 Gen12",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/32333750-3238-5A43-3244-333730314C59",
      "uuid": "32333750-3238-5A43-3244-333730314C59",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "ALP-CONSTC1-01ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "                                ",
      "category": "server-hardware",
      "created": "2026-04-23T10:56:12.774Z",
      "description": null,
      "eTag": "1789967828645",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "HPE ProLiant Compute DL380 Gen12",
      "modified": "2026-09-21T05:17:08.645Z",
      "mpDnsName": "ALP-CONSTC1-01ilo",
      "mpFirmwareVersion": "1.14.00 May 28 2025",
      "mpIpAddress": "10.239.229.64",
      "mpModel": "iLO7",
      "partNumber": "P73282-B21",
      "portMap": {
        "deviceSlots": "       "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 8,
      "processorCount": 2,
      "processorSpeedMhz": 4000,
      "processorType": "Intel(R) Xeon(R) 6507P",
      "refreshState": "NotRefreshing",
      "romVersion": "U68 v1.52 (10/03/2025)",
      "serialNumber": "CZ2D3701LT",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/C254F851-C838-49C2-9384-3CB803CC9B13",
      "serverProfileUri": "/rest/server-profiles/0496f03a-5c27-4a9b-ba1a-79cb05eaf805",
      "shortModel": "DL380 Gen12",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/32333750-3238-5A43-3244-333730314C54",
      "uuid": "32333750-3238-5A43-3244-333730314C54",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "ALP-CONSTC2-01ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-04-23T10:56:13.112Z",
      "description": null,
      "eTag": "1789969036034", 
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "HPE ProLiant Compute DL380 Gen12",
      "modified": "2026-09-21T05:37:16.034Z",
      "mpDnsName": "ALP-CONSTC2-01ilo",
      "mpFirmwareVersion": "1.14.00 May 28 2025",
      "mpIpAddress": "10.239.229.65",
      "mpModel": "iLO7",
      "partNumber": "P73282-B21",
      "portMap": {
        "deviceSlots": "       "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 8,
      "processorCount": 2,
      "processorSpeedMhz": 4000,
      "processorType": "Intel(R) Xeon(R) 6507P",
      "refreshState": "NotRefreshing",
      "romVersion": "U68 v1.52 (10/03/2025)",
      "serialNumber": "CZ2D3701LV",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/C254F851-C838-49C2-9384-3CB803CC9B13",
      "serverProfileUri": "/rest/server-profiles/3d896ddc-d943-4c21-9f73-f511ec448c05",
      "shortModel": "DL380 Gen12",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/32333750-3238-5A43-3244-333730314C56",
      "uuid": "32333750-3238-5A43-3244-333730314C56",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "OMG-CONSTC1-02ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "                                ",
      "category": "server-hardware",
      "created": "2026-04-23T10:56:13.493Z",
      "description": null,
      "eTag": "1790004764039",
      "formFactor": "2U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "HPE ProLiant Compute DL380 Gen12",
      "modified": "2026-09-21T15:32:44.039Z",
      "mpDnsName": "OMG-CONSTC1-02ilo",
      "mpFirmwareVersion": "1.14.00 May 28 2025",
      "mpIpAddress": "10.239.231.28",
      "mpModel": "iLO7",
      "partNumber": "P73282-B21",
      "portMap": {
        "deviceSlots": "       "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 8,
      "processorCount": 2,
      "processorSpeedMhz": 4000,
      "processorType": "Intel(R) Xeon(R) 6507P",
      "refreshState": "NotRefreshing",
      "romVersion": "U68 v1.52 (10/03/2025)",
      "serialNumber": "CZ2D3701LZ",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/C254F851-C838-49C2-9384-3CB803CC9B13",
      "serverProfileUri": "/rest/server-profiles/21cf424f-2e3d-46d9-abd7-6ba42c395301",
      "shortModel": "DL380 Gen12",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/32333750-3238-5A43-3244-333730314C5A",
      "uuid": "32333750-3238-5A43-3244-333730314C5A",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "alp-qlikview-03ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-05-27T13:50:36.017Z",
      "description": null,
      "eTag": "1790004562291",
      "formFactor": "1U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "ProLiant DL360 Gen10 Plus",
      "modified": "2026-09-21T15:29:22.291Z",
      "mpDnsName": "alp-qlikview-03ilo",
      "mpFirmwareVersion": "3.14 Jun 16 2025",
      "mpIpAddress": "10.30.14.15",
      "mpModel": "iLO5",
      "partNumber": "P28948-B21",
      "portMap": {
        "deviceSlots": "   "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "Off",
      "processorCoreCount": 32,
      "processorCount": 2,
      "processorSpeedMhz": 2000,
      "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U46 v2.42 (06/13/2025)",
      "serialNumber": "CZ22420JCM",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
      "serverProfileUri": "/rest/server-profiles/a3fa6710-80b0-4c3c-8998-b6937eacc7ed",
      "shortModel": "DL360 Gen10 Plus",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A434D",
      "uuid": "39383250-3834-5A43-3232-3432304A434D",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "alp-qliksen-02ilo",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "                                ",
      "category": "server-hardware",
      "created": "2026-05-27T13:54:14.828Z",
      "description": null,
      "eTag": "1784198747444",
      "formFactor": "1U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 524288,
      "model": "ProLiant DL360 Gen10 Plus",
      "modified": "2026-07-16T10:45:47.444Z",
      "mpDnsName": "alp-qliksen-02ilo",
      "mpFirmwareVersion": "3.09 Oct 08 2024",
      "mpIpAddress": "10.30.14.17",
      "mpModel": "iLO5",
      "partNumber": "P28948-B21",
      "portMap": {
        "deviceSlots": "   "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 32,
      "processorCount": 2,
      "processorSpeedMhz": 2000,
      "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U46 v2.24 (10/04/2024)",
      "serialNumber": "CZ22420JCZ",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
      "serverProfileUri": null,
      "shortModel": "DL360 Gen10 Plus",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A435A",
      "uuid": "39383250-3834-5A43-3232-3432304A435A",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "omg-qlikview-03ilo",
      "state": "ProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "",
      "category": "server-hardware",
      "created": "2026-05-27T13:54:53.991Z",
      "description": null,
      "eTag": "1790004752372",
      "formFactor": "1U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 1048576,
      "model": "ProLiant DL360 Gen10 Plus",
      "modified": "2026-09-21T15:32:32.372Z",
      "mpDnsName": "omg-qlikview-03ilo",
      "mpFirmwareVersion": "3.14 Jun 16 2025",
      "mpIpAddress": "10.30.54.22",
      "mpModel": "iLO5",
      "partNumber": "P28948-B21",
      "portMap": {
        "deviceSlots": "   "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "Off",
      "processorCoreCount": 32,
      "processorCount": 2,
      "processorSpeedMhz": 2000,
      "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U46 v2.42 (06/13/2025)",
      "serialNumber": "CZ22420JCN",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
      "serverProfileUri": "/rest/server-profiles/353a5d94-4c08-4374-a6e2-883f241ad7c9",
      "shortModel": "DL360 Gen10 Plus",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A434E",
      "uuid": "39383250-3834-5A43-3232-3432304A434E",
      "virtualSerialNumber": null,
      "virtualUuid": null
    },
    {
      "type": "server-hardware-1",
      "name": "omg-qliksen-02ilo",
      "state": "NoProfileApplied",
      "stateReason": "NotApplicable",
      "assetTag": "                                ",
      "category": "server-hardware",
      "created": "2026-05-27T13:55:32.627Z",
      "description": null,
      "eTag": "1784198750809",
      "formFactor": "1U",
      "licensingIntent": "OneViewNoiLO",
      "locationUri": null,
      "memoryMb": 524288,
      "model": "ProLiant DL360 Gen10 Plus",
      "modified": "2026-07-16T10:45:50.809Z",
      "mpDnsName": "omg-qliksen-02ilo",
      "mpFirmwareVersion": "3.09 Oct 08 2024",
      "mpIpAddress": "10.30.54.21",
      "mpModel": "iLO5",
      "partNumber": "P28948-B21",
      "portMap": {
        "deviceSlots": "   "
      },
      "position": 0,
      "powerLock": false,
      "powerState": "On",
      "processorCoreCount": 32,
      "processorCount": 2,
      "processorSpeedMhz": 2000,
      "processorType": "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
      "refreshState": "NotRefreshing",
      "romVersion": "U46 v2.24 (10/04/2024)",
      "serialNumber": "CZ22420JD0",
      "serverGroupUri": null,
      "serverHardwareTypeUri": "/rest/server-hardware-types/B1B1ACD6-7D82-4880-8508-958FED9C5417",
      "serverProfileUri": null,
      "shortModel": "DL360 Gen10 Plus",
      "signature": null,
      "status": "OK",
      "uri": "/rest/server-hardware/39383250-3834-5A43-3232-3432304A4430",
      "uuid": "39383250-3834-5A43-3232-3432304A4430",
      "virtualSerialNumber": null,
      "virtualUuid": null
    }
  ],
  "modified": "2026-09-21T15:33:19.717Z",
  "nextPageUri": null,
  "prevPageUri": null,
  "start": 0,
  "total": 16,
  "uri": "/rest/server-hardware?start=0&count=32&query=%22maintenanceMode:'true'%22"
}
   image-build-automation  main  Write-Host "Total: $($r_mm.total)"                                                                                                              0  16:33:37 Total: 16 
   image-build-automation  main  # Compare: all servers                                                                                                                          0  16:33:39    image-build-automation  main  $r_all = Invoke-RestMethod -Uri "https://va-oneviewt-01:443/rest/server-hardware?start=0&count=-1" `                                            0  16:33:55 >     -Headers @{ auth = $token } -Method Get -SkipCertificateCheck 
   image-build-automation  main  Write-Host "=== ALL SERVERS ==="                                                                                                                0  16:33:58 === ALL SERVERS ===
   image-build-automation  main  Write-Host "Total: $($r_all.total)"                                                                                                             0  16:34:09 Total: 16 
   image-build-automation  main                                                                                                                                                  0  16:34:09    image-build-automation  main  Import-Module HPEOneView.1000                                                                                                                   0  16:34:11    image-build-automation  main  Connect-OVMgmt -Appliance va-oneviewt-01 -Credential $cred                                                                                      0  16:35:01 WARNING: You are already connected to va-oneviewt-01 
   image-build-automation  main  $mm_servers = Get-OVServer -MaintenanceMode:$true                                                                                               0  16:35:02    image-build-automation  main  Write-Host "Maintenance mode servers: $($mm_servers.Count)"                                                                              0  675ms  16:35:18 Maintenance mode servers: 10 
   image-build-automation  main  $mm_servers | Select-Object name, state, uri                                                                                                    0  16:35:30 
name                         state          uri
----                         -----          ---
ALP-CONSTC1-01ilo            ProfileApplied /rest/server-hardware/32333750-3238-5A43-3244-333730314C54 
ALP-CONSTC2-01ilo            ProfileApplied /rest/server-hardware/32333750-3238-5A43-3244-333730314C56 
alp-qlikview-03ilo           ProfileApplied /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D 
ALP-STARWAY-01ILO            Monitored      /rest/server-hardware/39373638-3935-5A43-4A38-333130353252 
ALP-WISCLU-01ilo             Monitored      /rest/server-hardware/30393137-3436-5A43-3335-303850595335 
OMG-CONSTC1-02ilo            ProfileApplied /rest/server-hardware/32333750-3238-5A43-3244-333730314C5A 
OMG-CONSTC2-02ilo            ProfileApplied /rest/server-hardware/32333750-3238-5A43-3244-333730314C59 
omg-qlikview-03ilo           ProfileApplied /rest/server-hardware/39383250-3834-5A43-3232-3432304A434E 
OMG-STARWAY-01ILO.AD.AIB.PRI Monitored      /rest/server-hardware/39373638-3935-5A43-4A38-33313035324E
OMG-WISCLU-01ilo             Monitored      /rest/server-hardware/00000000-0000-5A43-4A35-353030333337

   image-build-automation  main  Get-OneViewServerList                                                                                                                           0  16:35:47 
============================================== 
  OneView Server List (16 servers)
  Appliance: va-oneviewt-01
============================================== 

| Server Name                     | Serial          | MaintMode | State            | Health     | Power    | iLO IP          | ROM                    | State Reason  | Model
      |
|---------------------------------|-----------------|-----------|------------------|------------|----------|-----------------|------------------------|---------------|--------------------------------|
| OMG-STARWAY-01ILO.AD.AIB.PRI    | CZJ831052N      | No        | Monitored        | OK         | On       | 10.239.230.72   | U32 v3.50 (04/17/2025) |               | ProLiant DL360 Gen10     
      |
| ALP-WISCLU-01ilo                | CZ3508PYS5      | No        | Monitored        | OK         | On       | 10.30.13.115    | P89 v2.92 (11/23/2021) |               | ProLiant DL380 Gen9      
      |
| OMG-WISCLU-01ilo                | CZJ5500337      | No        | Monitored        | OK         | On       | 10.30.52.142    | P89 v2.92 (11/23/2021) |               | ProLiant DL380 Gen9      
      |
| ALP-STARWAY-01ILO               | CZJ831052R      | No        | Monitored        | OK         | On       | 10.239.228.76   | U32 v3.50 (04/17/2025) |               | ProLiant DL360 Gen10     
      |
| gam-isechost-02-03ilo.ad.ad.pri | CZ29350B60      | No        | NoProfileApplied | OK         | On       | 10.30.14.83     | U30 v3.42 (02/21/2025) |               | ProLiant DL380 Gen10     
      |
| gamdmzhost-01-03ilo.AD.AIB.PRI  | CZ29350B5Y      | No        | NoProfileApplied | OK         | On       | 10.30.14.80     | U30 v3.42 (02/21/2025) |               | ProLiant DL380 Gen10     
      |
| gamdmzhost-02-03ilo             | CZ29350B5Z      | No        | NoProfileApplied | OK         | On       | 10.30.14.81     | U30 v3.42 (02/21/2025) |               | ProLiant DL380 Gen10     
      |
| gamisechost-01-03ilo.AD.AIB.PRI | CZ29350B61      | No        | NoProfileApplied | OK         | On       | 10.30.14.82     | U30 v3.42 (02/21/2025) |               | ProLiant DL380 Gen10     
      |
| OMG-CONSTC2-02ilo               | CZ2D3701LY      | No        | ProfileApplied   | OK         | On       | 10.239.231.29   | U68 v1.52 (10/03/2025) |               | HPE ProLiant Compute DL380 ... |
| ALP-CONSTC1-01ilo               | CZ2D3701LT      | No        | ProfileApplied   | OK         | On       | 10.239.229.64   | U68 v1.52 (10/03/2025) |               | HPE ProLiant Compute DL380 ... |
| ALP-CONSTC2-01ilo               | CZ2D3701LV      | No        | ProfileApplied   | OK         | On       | 10.239.229.65   | U68 v1.52 (10/03/2025) |               | HPE ProLiant Compute DL380 ... |
| OMG-CONSTC1-02ilo               | CZ2D3701LZ      | No        | ProfileApplied   | OK         | On       | 10.239.231.28   | U68 v1.52 (10/03/2025) |               | HPE ProLiant Compute DL380 ... |
| alp-qlikview-03ilo              | CZ22420JCM      | No        | ProfileApplied   | OK         | Off      | 10.30.14.15     | U46 v2.42 (06/13/2025) |               | ProLiant DL360 Gen10 Plus      |
| alp-qliksen-02ilo               | CZ22420JCZ      | No        | NoProfileApplied | OK         | On       | 10.30.14.17     | U46 v2.24 (10/04/2024) |               | ProLiant DL360 Gen10 Plus      |
| omg-qlikview-03ilo              | CZ22420JCN      | No        | ProfileApplied   | OK         | Off      | 10.30.54.22     | U46 v2.42 (06/13/2025) |               | ProLiant DL360 Gen10 Plus      |
| omg-qliksen-02ilo               | CZ22420JD0      | No        | NoProfileApplied | OK         | On       | 10.30.54.21     | U46 v2.24 (10/04/2024) |               | ProLiant DL360 Gen10 Plus      |

KEY 
  MaintMode : HPE OneView maintenance mode.  Yes = server is IN maintenance mode;  No = NOT in maintenance mode.
  State     : server lifecycle state from OneView:
               Monitored        = normal / being monitored (not in maintenance)
               MaintenanceMode  = same as MaintMode=Yes (server placed in maintenance)
               NoProfileApplied = no server profile assigned
               ProfileApplying  = a server profile is being applied
               ProfileApplied   = a server profile has been applied
               ConfigureHardware = hardware configuration in progress
               ProfileError     = profile apply failed (NOT maintenance)
               Deleting         = server being removed
  State Reason : additional context for the State value (blank when 'NotApplicable'):
               NotApplicable  = no special reason; state is self-explanatory (shown as blank)
               UserInitiated  = state change triggered by a user action
               Unmanaged      = hardware not managed by this OneView appliance
               Removed        = hardware has been removed from the appliance 

==============================================

   image-build-automation  main  $mm_servers = Get-OVServer -MaintenanceMode:$false                                                                                              0  16:41:28    image-build-automation  main  Write-Host "Maintenance mode servers: $($mm_servers.Count)"                                                                                     0  16:42:07 Maintenance mode servers: 6
   image-build-automation  main  $mm_servers | Select-Object name, state, uri                                                                                                    0  16:42:18 
name                            state            uri
----                            -----            ---
alp-qliksen-02ilo               NoProfileApplied /rest/server-hardware/39383250-3834-5A43-3232-3432304A435A
gam-isechost-02-03ilo.ad.ad.pri NoProfileApplied /rest/server-hardware/37383638-3330-5A43-3239-333530423630
gamdmzhost-01-03ilo.AD.AIB.PRI  NoProfileApplied /rest/server-hardware/37383638-3330-5A43-3239-333530423559
gamdmzhost-02-03ilo             NoProfileApplied /rest/server-hardware/37383638-3330-5A43-3239-33353042355A
gamisechost-01-03ilo.AD.AIB.PRI NoProfileApplied /rest/server-hardware/37383638-3330-5A43-3239-333530423631
omg-qliksen-02ilo               NoProfileApplied /rest/server-hardware/39383250-3834-5A43-3232-3432304A4430
you 
