# Automation Test Plan — Physical Server Build and ISO Pipeline

<a id="top"></a>

## Table of Contents

- [How to execute (runner reference)](#how-to-execute-runner-reference)
- [1. Connection Lifecycle (run this FIRST)](#1-connection-lifecycle-run-this-first)
- [2. Non-Destructive Lookup, Validation & Monitoring](#2-non-destructive-lookup-validation--monitoring)
- [3. Build-Time ISO Patching (writes a file, not a server)](#3-build-time-iso-patching-writes-a-file-not-a-server)
- [4. ⚠ DESTRUCTIVE — ISO Installation & Maintenance (highlighted)](#4--destructive--iso-installation--maintenance-highlighted)
- [5. Orchestration, Routing & Utility](#5-orchestration-routing--utility)
- [6. Shared / Infrastructure Modules](#6-shared--infrastructure-modules)
- [7. Test Run Summary (filled per cycle)](#7-test-run-summary-filled-per-cycle)
  - [Run log](#run-log)
- [8. Coverage Gaps & Legacy/Removed Commands](#8-coverage-gaps--legacyremoved-commands)
- [9. Notes for the Delivery Lead](#9-notes-for-the-delivery-lead)

<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 04/09/2026 08:25 UTC</p>
<!-- END:run-date -->

<a id="how-to-execute-runner-reference"></a>

## How to execute (runner reference):

| Command | What it runs |
|---------|--------------|
| `make test` | All Pester unit tests (`scripts/run-tests.ps1`) |
| `make coverage` | Unit tests with code-coverage report (CI gate) |
| `make test-integration` | `tests/powershell/Pester.Integration.ps1` |
| `make automation-mode-tests` | ISO build / OneView / iLO Redfish / orchestrator / connection flows |
| `make maint-mode-tests` | `Set-MaintenanceMode` enable/disable/validation suite |
| `pwsh scripts/testConnectAndList.ps1 -OneViewHost <host>` | Non-destructive connectivity/list harness (read-only matrix) |
| `pwsh scripts/testBuildDeploy.ps1 -Server <srv> -GuardRail '<re>'` | Build/deploy harness (safe `-DryRun` unless `-Live`) |

**Column legend:**

- **Expected Pass Date** — target sign-off date agreed with the delivery lead.
- **Actual Pass Date** — date/time the test last passed in the target environment. Leave blank until executed.
- **Status** — `Planned` / `In Progress` / `Passed` / `Failed` / `Blocked`.
- **CI?** — `Y` if already wired into the GitLab CI test stage; `N` if it still needs execution/evidence.

> **Execution order is mandatory.** Section 1 (Connection Lifecycle) MUST be completed and green before any command in Sections 2–4 is run against a live appliance. The connection commands establish and protect the live OneView session — losing it mid-run can drop an in-flight deployment and cause an incident.

---

<a id="1-connection-lifecycle-run-this-first"></a>

## 1. Connection Lifecycle (run this FIRST)

> **Why first:** Every downstream OneView command reuses the active session. A dropped or duplicated session is the #1 cause of live-incident bugs. These tests prove: status works with/without a session, connect establishes a session, a second connect never drops the live connection, disconnect closes it cleanly, and reconnect restores it.

| Test ID | Component / Command | Test Scope (parameters / edge cases) | Test File (existing) | Expected Result | Status | CI? |
|---------|--------------------|--------------------------------------|----------------------|-----------------|--------|-----|
| CONN-01 | `Test-ServerConnectivity` (no session) | Bare run with **no** active session and **no** `-OneViewHost`. Edge: must fail/return gracefully (`Available=$false`, `NetworkPing`/`AuthConnect` empty) — **never throw, never prompt**. | `tests/powershell/Test-ServerConnectivity.Tests.ps1` | Graceful no-session report; no interactive prompt. | Planned | Y |
| CONN-02 | `Connect-OneView` (establish live session) | LIVE: `Connect-OneView -OneViewHost <host>` (creds prompted). NON-INTERACTIVE: `Connect-OneView -OneViewHost <host> -Credential $cred`. BARE (no params) in automated mode → warns "requires -OneViewHost". DRY-RUN: `Connect-OneView -DryRun`. `-PassThru` returns hashtable; `-Json` returns JSON string. | `tests/powershell/Connect-OneView.Tests.ps1` | Session established; `AuthConnect=$true`; host report on success stream with `-PassThru`/`-Json`. | Planned | Y |
| CONN-03 | `Test-ServerConnectivity` (active session) | After CONN-02, bare run reports the active `Connect-OneView` session (`Available=$true`, `Mode=oneview`, `OneViewHost` populated). With `-OneViewHost <same>` re-checks that appliance only. With `-DryRun` returns mock without connecting. | `tests/powershell/Test-ServerConnectivity.Tests.ps1` | Active session reported; `NetworkPing`/`AuthConnect` populated. | Planned | Y |
| CONN-04 | `Get-OneViewConnectionStatus` (active) | Bare → reports active session (`Connected=$true`, `Reachable=$true`, `Authenticated=$true`). `-MockResult` returns the supplied hashtable with no HTTP. `-DryRun` prints checks only. | `tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1` | Connected/Reachable/Authenticated all `$true`; `SessionSource=HPEOneViewModule`. | Planned | Y |
| CONN-05 | **`Connect-OneView` while already connected — live session must NOT be dropped** | EDGE (critical): with a live session active from CONN-02, run `Connect-OneView` again — (a) same `-OneViewHost`, then (b) a *different* `-OneViewHost`. Assert the original live session is **reused**, not torn down/reconnected; for a different host it **warns** which appliance you are on and tells you to `Disconnect-OneView` first. **No loss of the live connection.** | `tests/powershell/Connect-OneView.Tests.ps1` | Original session intact; no reconnect/drop; warning emitted for mismatched host. | Planned | Y |
| CONN-06 | `Disconnect-OneView` (verify close) | With live session active, `Disconnect-OneView` (clean) then `Disconnect-OneView -Force` (suppress cleanup errors). EDGE: `Disconnect-OneView` when **nothing** is connected → returns `Success` (graceful, no throw). After disconnect, `Get-OneViewConnectionStatus` returns `Connected=$false`. | `tests/powershell/Connect-OneView.Tests.ps1` | `Success=$true`; subsequent status `Connected=$false`. | Planned | Y |
| CONN-07 | **Reconnect** (full lifecycle) | Disconnect (CONN-06) → `Connect-OneView -OneViewHost <host> -Credential $cred` → confirm `Test-ServerConnectivity`/`Get-OneViewConnectionStatus` show `Connected=$true` again. Proves the connect→disconnect→connect cycle is repeatable with no stale-state bug. | `tests/powershell/Connect-OneView.Tests.ps1` | Session re-established; status green after reconnect. | Planned | Y |
| CONN-08 | `Get-OneViewConnectionStatus` (explicit host + server) | `-OneViewHost <host> -IncludeServerCount` (server count). `-ServerIdentifier srv01` (power/health). `-ServerIdentifier MXQ1234567 -IdentifierType Serial` and the same with `-IdentifierType Auto` (serial auto-detect). Aliases `-OVHost`/`-SrvrId`/`-IdTyp`. `-TimeoutSec`, `-SkipCertificateCheck`. | `tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1` | Correct `ServerCount`, per-server `Server` block; Auto resolves serial. | Planned | Y |
| CONN-09 | `Get-OneViewServerList` (parameter matrix) | `-OneViewHost` (or reuse session). `-Filter` variants: `health:Critical`, `power:On`, `maintenance:Yes`, `maintenance:No`, `name:PROD`, `name:PROD-*` (wildcard), `name:srv-0?`. `-Summary` vs `-Detail`. `-PageSize 100`, `-Port 443`, `-TimeoutSec`, `-Credential`/`-OneViewUser`+`-OneViewPassword`, `-PassThru` (returns hashtable), `-MockResult`, `-DryRun`. | `tests/powershell/Get-OneViewServerList.Unit.Tests.ps1` | Full fleet returned; filter narrows correctly; `MaintMode`/`State` columns accurate. | Planned | Y |
| CONN-10 | `Get-OneViewServerTarget` (resolve + strict single-server) | Resolve by **name**, **serial** (`-IdentifierType Serial`), **iLO IP**, **bay**; `-IdentifierType Auto` default. `-DryRun`. EDGE: a name/serial that matches **>1 server** → hard failure (never silently picks one). EDGE: no session and no `-OneViewHost` → exception explaining how to connect. | `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1` | Correct single server + `ResolvedBy`; multi-match rejected. | Planned | Y |

---

<a id="2-non-destructive-lookup-validation--monitoring"></a>

## 2. Non-Destructive Lookup, Validation & Monitoring

All commands here are **safe on the live appliance** (read-only lookups, path/validation checks, or status monitoring). Run the full parameter/value matrix for each.

| Test ID | Component / Command | Test Scope (parameters / edge cases) | Test File (existing) | Expected Result | Status | CI? |
|---------|--------------------|--------------------------------------|----------------------|-----------------|--------|-----|
| ND-01 | `Test-BuildParams` (path formats) | `-BaseIsoPath` for **every** accepted format: `\\server\share\file.iso` (UNC backslash), `//server/share/file.iso` (forward slash), `cifs://server/share/file.iso`, `smb://server/share/file.iso`, `https://…`, `nfs://…`, mapped drive `H:\file.iso`. EDGE: **local drive** `C:\isos\file.iso` → **rejected** with guidance to use SMB/UNC/HTTPS. `-FirmwareFolders @('\\srv\fw\BIOS','H:\fw\iLO5')` (mixed). `-DryRun` (format only). | `tests/powershell/Test-BuildParams.Unit.Tests.ps1` *(to be added)* | `Success=$true`; `IsoUrl` = resolved `cifs://`/`https://`/`nfs://`; local path rejected. | Planned | N |
| ND-02 | `Test-PreBuildValidation` (checks + skips) | `-ServerIdentifier`, `-OneViewHost`, `-IloIp`, `-IsoUrl`, `-ManagementPoint`, `-DistributionPoint`, `-BootImageName`, `-TaskSequenceName`. Skip flags: `-SkipOneView`, `-SkipIlo`, `-SkipDpMp`, `-SkipIsoUrl` (each individually + all). `-DryRun` (validate inputs, skip network probes). | `tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1` | `Checks` all pass for valid target; skipped checks absent. | Planned | Y |
| ND-03 | `Test-PostBuildValidation` (post-build checks) | `-Hostname` (required unless `-SerialNumber`). `-SerialNumber MXQ1234567 -OneViewHost <host>` (resolved via OneView). `-ExpectedHostname`, `-Domain`, `-ExpectedOsVersion`. Skip flags: `-SkipCmClient`, `-SkipDrivers`, `-SkipRemote` (all WinRM checks). `-DryRun`. | `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1` | `Checks` reflect built state; `AuditFile` written. | Planned | Y |
| ND-04 | `Start-InstallMonitor` (monitoring) | `-Server srv01`. No params (monitor all from list). `-SerialNumber MXQ1234567 -OneViewHost <host>`. `-TimeoutSeconds 3600 -PollIntervalSeconds 15` (custom). `-OpsRampConfig <path>` (only read when passed). EDGE: per-server status vs bulk `Summary`. | `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1` | Correct completion/failure detection; read-only (no change). | Planned | Y |
| ND-05 | `Invoke-IloRedfish` — `Status` & `Eject` (non-destructive) | `-Action Status -IloIp <ip>` (read power + media). `-Action Eject -IloIp <ip>` (detach media). `-DryRun` for each. Aliases `-Ilo`. EDGE: `-Action Status` with no `-IloIp` → parameter error. | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | `Success=$true`; no mount/reboot performed. | Planned | Y |
| ND-06 | `Invoke-OpsRampClient` (monitoring/ITSM) | Factory `Invoke-OpsRampClient -ConfigPath <opsramp_config.json>` returns client. Companion `Invoke-OpsRamp` connectivity test (token obtain). `-DryRun`. | `tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1` | Client constructed; no change to server/build. | Planned | Y |
| ND-07 | `New-Uuid` (deterministic) | `New-Uuid -ServerName srv01`; stable output for same input; differs for different input. | `tests/powershell/New-Uuid.Unit.Tests.ps1` | Stable UUID per server name. | Planned | Y |
| ND-08 | `Invoke-PowerShellScript` (local) | `-Script 'Get-Process \| Select-Object -First 5' -TimeoutSeconds 30`. `-DryRun`. EDGE: script that exceeds `-TimeoutSeconds` → terminated; output captured. **Destructive depends on script** — only run reviewed scripts. | `tests/powershell/Invoke-PowerShellScript.Unit.Tests.ps1` *(to be added)* | Output captured; timeout honoured. | Planned | N |
| ND-09 | `Invoke-PowerShellWinRM` (remote) | `-Script 'Get-Service wuauserv' -Server srv01`. `-DryRun`. EDGE: unreachable server → graceful error. **Destructive depends on script.** | `tests/powershell/Invoke-PowerShellWinRM.Unit.Tests.ps1` *(to be added)* | Remote output returned; errors handled. | Planned | N |
| ND-10 | `Get-RouteMap` (routing) | `Get-RouteMap` returns route table; router resolves request types to handlers (companion of AT-ORC-02). | `tests/powershell/Router.Unit.Tests.ps1` | Routes resolve to handlers. | Planned | Y |

> **Non-destructive iLO note:** `Invoke-IloRedfish -Action Mount` attaches virtual media but "changes nothing on disk" — it is safe to include here for validation, but treat `MountAndBoot`/`Reset`/`Boot` as **destructive** (Section 4). `Status`/`Eject` are fully non-destructive.

---

<a id="3-build-time-iso-patching-writes-a-file-not-a-server"></a>

## 3. Build-Time ISO Patching (writes a file, not a server)

`Invoke-WindowsSecurityUpdate` patches a **base ISO file on disk** (offline DISM servicing). It does **not** touch a live server, but it **does write/overwrite** a file at `OutputDir`, so it is not "safe everywhere" — run it against a scratch directory, never over a golden image you still need.

| Test ID | Component / Command | Test Scope (parameters / edge cases) | Test File (existing) | Expected Result | Status | CI? |
|---------|--------------------|--------------------------------------|----------------------|-----------------|--------|-----|
| BLD-01 | `Invoke-WindowsSecurityUpdate` (patch + method + dry-run) | `-BaseIsoPath 'C:\isos\WinSrv2025.iso' -Server srv01`. `-Method dism` and `-Method powershell`. `-DryRun` (simulate). `-OutputDir <scratch>`. `-PatchesConfig <manifest>` (required live; default only with `-DryRun`). EDGE: `-SerialNumber MXQ1234567 -OneViewHost <host>` for output naming. | `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1` | Patched ISO produced at `OutputDir`; dry-run writes nothing. | Planned | Y |

---

<a id="4--destructive--iso-installation--maintenance-highlighted"></a>

## 4. ⚠ DESTRUCTIVE — ISO Installation & Maintenance (highlighted)

> ### 🔴 READ BEFORE RUNNING
> Every command in this section can **wipe, reinstall, reboot, or change the maintenance state of a production banking server**. They are gated by a mandatory **`-GuardRail`** regex (the *resolved* server name must match) and/or a confirmation (`APPROVE` / `-Force` / `-Deploy`).
>
> **Rules:**
> 1. Run Sections 1–3 first and confirm green.
> 2. Only run inside an **approved maintenance window**.
> 3. Always pass `-GuardRail '<server-regex>'` (case-insensitive) — omitting it aborts early.
> 4. Prefer `-DryRun` first to print the plan without acting.
> 5. `Configure-PhysicalBuild` automatically places the target in **OneView maintenance mode** before destructive ops and removes it after (skip with `-NoMaintenanceMode` only when OneView is unavailable).
> 6. Evidence each run in Section 7.

| Test ID | Component / Command | Test Scope (parameters / edge cases) | Test File (existing) | Expected Result | Status | CI? |
|---------|--------------------|--------------------------------------|----------------------|-----------------|--------|-----|
| DEST-01 | `Configure-PhysicalBuild` — 4-eye review (NO deploy) | Full review: `-ServerIdentifier srv01 -OneViewHost <host> -IloIp <ip> -Domain corp.local -GuardRail 'srv01'`. Assert it prints the plan + lists destructive actions and **waits for `APPROVE`** — no change made. `-DryRun` prints plan only. | `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1` | Plan shown; no deploy until `APPROVE`. | Planned | Y |
| DEST-02 | `Configure-PhysicalBuild` — GuardRail matrix (EDGE) | (a) `-GuardRail 'srv01'` matches resolved name → allowed. (b) `-GuardRail 'WRONG'` does **not** match → review aborted. (c) **Omitted** `-GuardRail` → early abort with logged error. (d) `-GuardRail 'quickview\.ilo0'` regex matches `quickview.ilo03.alp`. | `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1` | Match→proceed; non-match/omit→abort (no deploy). | Planned | Y |
| DEST-03 | `Configure-PhysicalBuild` — `-Deploy` (authorize) + External ISO paths | `-Deploy` (alias `-Execute`) skips prompt. `-ExternalIsoPath` for **each** format: UNC `\\`, forward `//`, `cifs://`, `smb://`, `https://`, mapped `H:\`. ConfigMgr params (`-SiteCode`/`-ManagementPoint`/`-DistributionPoint`/`-BootImageName`/`-TaskSequenceName`/`-SiteServer`) **not required** in external-ISO mode. | `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1` | Deploy authorized; correct ISO URL mounted. | Planned | Y |
| DEST-04 | `Configure-PhysicalBuild` — skip / maintenance flags | `-NoMaintenanceMode` (≡ `-OneViewMaintenanceMode:$false`). `-SkipPreBuild`, `-SkipOneView`, `-SkipIlo`, `-SkipDpMp`, `-SkipIsoUrl`. `-Force` (ack power On). `-ExpectedHostname`, `-InMaintenanceWindow`. `-PassThru`/`-Json`. Re-run monitoring variant: `-SkipPreBuild -SkipOneView -SkipMount`. | `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1` | Flags honoured; maint mode toggled as set. | Planned | Y |
| DEST-05 | `Invoke-IloRedfish` — `MountAndBoot` / `Reset` (DESTRUCTIVE) | `-Action MountAndBoot -IloIp <ip> -IsoUrl <url> -Force` (wipe/reinstall). `-Action Reset -IloIp <ip> -Force`. EDGE: **without** `-Force` → prompts (or blocked in automated mode). `-Action Boot` (one-time boot, no immediate reboot). `-DryRun`. `-CdDeviceId`. | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | Destructive actions require `-Force`; dry-run prints only. | Planned | Y |
| DEST-06 | `Invoke-IloRedfish` — `Mount` (prep, non-wiping) | `-Action Mount -IloIp <ip> -IsoUrl <url>` (attaches media, no reboot). `-DryRun`. Included here because it precedes a destructive boot. | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | Media mounted; no reboot. | Planned | Y |
| DEST-07 | `Set-MaintenanceMode` (enable/disable — semi-destructive) | `-Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test`. `-Action disable`. Validation paths (bad input rejected). Environment Test vs Prod routing. **Requires approved window** — changes alerting state of a live server. | `tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1`, `.Enable.Tests.ps1`, `.Disable.Tests.ps1`, `.Validation.Tests.ps1`, `.Environment.Tests.ps1` | Mode enabled/disabled; invalid input rejected. | Planned | Y |

---

<a id="5-orchestration-routing--utility"></a>

## 5. Orchestration, Routing & Utility

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Status | CI? |
|---------|--------------------|-----------|----------------------|-----------------|--------|-----|
| ORCH-01 | `Start-AutomationOrchestrator` | `-RequestType build_iso -Params @{ SiteCode='P01'; ManagementPoint='mp01.corp.local' }`. Dispatch by request type. | `tests/powershell/Start-AutomationOrchestrator.Unit.Tests.ps1` | Correct handler invoked. | Planned | Y |
| ORCH-02 | `Get-RouteMap` / router | Route map + router resolution (see ND-10). | `tests/powershell/Router.Unit.Tests.ps1` | Routes resolve to handlers. | Planned | Y |
| ORCH-03 | `New-Uuid` | Deterministic UUID (see ND-07). | `tests/powershell/New-Uuid.Unit.Tests.ps1` | Stable UUID per input. | Planned | Y |
| ORCH-04 | `Invoke-OpsRampClient` | OpsRamp API client (see ND-06). | `tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1` | Client constructed/called. | Planned | Y |
| ORCH-05 | `Run-CIPipeline` / `Run-Scheduler` / `Run-GitLab` | Control-surface factories: `Run-CIPipeline -Params @{Stage='build';Version='1.0'}`, `Run-Scheduler -TaskParams @{Server='srv01';Timeout=3600}`, `Run-GitLab -Params @{TargetId='CLU-01';Action='enable'}`. | `tests/powershell/Test-GitLabIntegration.ps1`, `Test-GitLabCallback.ps1` | Factory returns runnable pipeline object. | Planned | Y |

---

<a id="6-shared--infrastructure-modules"></a>

## 6. Shared / Infrastructure Modules

| Test ID | Component | Test Scope | Test File (existing) | Expected Result | Status | CI? |
|---------|-----------|-----------|----------------------|-----------------|--------|-----|
| INF-01 | `Audit` | Audit log write/read | `tests/powershell/Audit.Unit.Tests.ps1` | Entries persisted. | Planned | Y |
| INF-02 | `Config` | Config load/resolve | `tests/powershell/Config.Unit.Tests.ps1` | Resolved correctly. | Planned | Y |
| INF-03 | `Credentials` | `PSCredential` handling, secure materialisation | `tests/powershell/Credentials.Unit.Tests.ps1` | No plaintext leakage. | Planned | Y |
| INF-04 | `Executor` | Command execution wrapper | `tests/powershell/Executor.Unit.Tests.ps1` | Executed/timed. | Planned | Y |
| INF-05 | `FileIO` | File read/write helpers | `tests/powershell/FileIO.Unit.Tests.ps1` | IO ops correct. | Planned | Y |
| INF-06 | `Inventory` | Inventory parsing | `tests/powershell/Inventory.Unit.Tests.ps1` | Parsed. | Planned | Y |
| INF-07 | `Validators` | Input validators | `tests/powershell/Validators.Unit.Tests.ps1` | Rules enforced. | Planned | Y |
| INF-08 | `Logging` | Structured logging + redaction | `tests/powershell/Logging.Unit.Tests.ps1` | Logs written; secrets redacted. | Planned | Y |
| INF-09 | `AutomationCommandLogging` | Per-command audit logging | `tests/powershell/AutomationCommandLogging.Unit.Tests.ps1` | Invocations logged (args redacted). | Planned | Y |
| INF-10 | `Update-TestProgress` (tooling) | Markdown block edit + HTML report | `tests/powershell/Update-TestProgress.Unit.Tests.ps1` | Block edit + report verified. | Planned | Y |
| INF-11 | `Setup-Profile` | Module registration in profile | `tests/powershell/Setup-Profile.Tests.ps1` | `Get-Command -Module Automation` populated. | Planned | Y |

---

<a id="7-test-run-summary-filled-per-cycle"></a>

## 7. Test Run Summary (filled per cycle)

Record each execution run here so the lead can trace sign-off to a build/CI job.

<!-- BEGIN:automation-evidence-rows -->
|Run #|Date/Time|Command / Suite|Environment|Result|Reason for full testing rerun|
|---|---|---|---|---|---|
|1|21/07/2026|Full Automation suite (legacy commands)|Test VDI|Passed (68/68)|Initial test run|
|2|23/07/2026 09:31|Full Automation suite|Test VDI|Passed (93/93)|Fixed OneView connectivity + logging|
|3|23/07/2026 18:55|Full Automation suite|Test VDI|Passed (93/93)|Connectivity/logging fix rerun|
|4|24/07/2026 16:34|`make automation-mode-tests`|Test VDI|Passed (95/95)|Removed phantom proxy; fixed session-lifecycle; suppressed prompts|
|5|27/07/2026 15:30|Live `Test-ServerConnectivity` + `Get-OneViewConnectionStatus`|Prod oneview.example.com|Passed|Verified session-lifecycle fix; all phases (DNS/TCP/Auth) green|
|6|31/07/2026|CHANGE FREEZE — no testing|N/A|N/A|N/A|
|7|02/08/2026 01:54|`make automation-mode-tests`|CachyOS Linux|Passed (99/99)|Post-freeze regression rerun|
|8|04/09/2026 08:25|Test plan REWRITTEN to match rewritten `automation_commands.md` (connection-first, destructive highlighted)|N/A|Planned|Command surface consolidated: `Connect-OneView`/`Disconnect-OneView`/`Configure-PhysicalBuild` added; `New-IsoBuild`/`Publish-BootIso`/`Invoke-IsoDeploy`/`Start-PhysicalServerBuild`/`Get-OneViewVersion`/`Test-ServerList`/SCOM scripts removed from public surface|
<!-- END:automation-evidence-rows -->

<a id="run-log"></a>

### Run log

Latest Full test run output (from `make test` / `make automation-mode-tests`):

```text
================================================================================
                           TEST SUMMARY BLOCK
================================================================================
 Total Tests   : 99
 Passed        : 99
 Failed        : 0
 Skipped       : 0
 Duration      : 3.15s
```

---

<a id="8-coverage-gaps--legacyremoved-commands"></a>

## 8. Coverage Gaps & Legacy/Removed Commands

**Not yet covered by an automated test file (add before sign-off):**

- `Test-BuildParams` (ND-01) — path-format matrix incl. local-drive rejection.
- `Invoke-PowerShellScript` (ND-08) — local exec, timeout, capture.
- `Invoke-PowerShellWinRM` (ND-09) — remote WinRM exec.

**Legacy / removed from the public command surface** — test files still exist in `tests/powershell/` but these commands are **no longer documented** in `automation_commands.md` (merged into `Configure-PhysicalBuild` or retired). Decide per command: restore docs, or delete the test file + implementation:

| Legacy command | Disposition |
|----------------|-------------|
| `New-IsoBuild` | Merged into `Configure-PhysicalBuild` (Build mode) |
| `Publish-BootIso` | Merged into `Configure-PhysicalBuild` |
| `Invoke-IsoDeploy` | Replaced by `Configure-PhysicalBuild` + `Get-OneViewServerTarget` |
| `Start-PhysicalServerBuild` | Replaced by `Configure-PhysicalBuild` |
| `Get-OneViewVersion` | Version now read from `Get-OneViewConnectionStatus -IncludeServerCount` |
| `Test-ServerList` | Replaced by `Get-OneViewServerList` |
| `Resolve-OneViewTarget` | Now an **internal** resolver used by `Get-OneViewServerTarget` (keep tests, not public) |
| `Update-Firmware` | Folded into `Configure-PhysicalBuild` firmware step / `-FirmwareFolders` |
| `New-OneViewMaintenanceScript`, `New-ScomConnection`, `New-ScomMaintenanceScript` | Maintenance-mode scripting retired from public surface (SCOM via `Set-MaintenanceMode`) |

---

<a id="9-notes-for-the-delivery-lead"></a>

## 9. Notes for the Delivery Lead

- **Execution order is mandatory:** Section 1 (Connection Lifecycle) MUST be green before Sections 2–4. The "connect while connected must not drop the live session" test (CONN-05) is the key regression guard against live-incident session-loss bugs.
- **Offline unit tests** (CI? = Y) run automatically in GitLab CI and satisfy the bulk of regression coverage. They do **not** touch live OneView/iLO/ConfigMgr, so they are safe during a change freeze.
- **Live/integration tests** and any `Set-MaintenanceMode` enable/disable against real appliances (DEST-07) must be executed inside an approved maintenance window and evidenced in Section 7.
- The **destructive section (4)** is highlighted for a reason — `Configure-PhysicalBuild`, `Invoke-IloRedfish -Action MountAndBoot|Reset`, and `Set-MaintenanceMode` can wipe/reboot/re-alert a production server. Always `-DryRun` first, always `-GuardRail`, always inside a window.
- `Invoke-WindowsSecurityUpdate` (Section 3) is non-server-destructive but **writes files** — never point `-OutputDir` at a golden image you still need.
- Credential handling across the OneView/iLO surface uses `PSCredential` parameters with env/CyberArk fallback (no plaintext `-User`/`-Password`); flag any deviation to the security review.
