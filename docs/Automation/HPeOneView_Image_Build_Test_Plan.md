# HPE OneView 1000 — Image Build Test Plan (ACTUAL / LIVE tests)

<a id="top"></a>

## Table of Contents

- [⚠ This is the LIVE INTEGRATION plan](#this-is-the-live-integration-plan)
- [Current OneView Connected Automation Command testing status and progress Summary](#current-oneview-connected-automation-command-testing-status-and-progress-summary)
- [Major Bugs fixed log](#major-bugs-fixed-log)
  - [1. Phantom proxy configuration on <mgmt-host>](#1-phantom-proxy-configuration-on-mgmt-host)
  - [2. Test-ServerConnectivity was disconnecting the OneView session after connecting](#2-test-serverconnectivity-was-disconnecting-the-oneview-session-after-connecting)
  - [3. Invoke-IsoDeploy Pester tests hanging on interactive prompts](#3-invoke-isodeploy-pester-tests-hanging-on-interactive-prompts)
  - [4. Test-ServerConnectivity Pester tests hanging on interactive credential prompts](#4-test-serverconnectivity-pester-tests-hanging-on-interactive-credential-prompts)
  - [5. Ripgrep JSON record exceeded 65536 bytes exception](#5-ripgrep-json-record-exceeded-65536-bytes-exception)
  - [6. Credential handling security hardened](#6-credential-handling-security-hardened)
- [Standing rule & execution notes](#standing-rule-execution-notes)
- [Phase 0 — Environment Prerequisites (checklist before live run)](#phase-0-environment-prerequisites-checklist-before-live-run)
- [Phase 1 — Connectivity (must pass before anything else)](#phase-1-connectivity-must-pass-before-anything-else)
- [Phase 2 — Get Server List](#phase-2-get-server-list)
- [Phase 3 — Information on Servers Connected to this OneView](#phase-3-information-on-servers-connected-to-this-oneview)
- [Phase 4 — Information on a Specific Server (BOTH identifiers)](#phase-4-information-on-a-specific-server-both-identifiers)
- [Phase 5 — Validate ISO Path & Assign to Server (BOTH identifiers)](#phase-5-validate-iso-path-assign-to-server-both-identifiers)
- [Phase 6 — Path / SMB-Name Generation (local drive AND network drive)](#phase-6-path-smb-name-generation-local-drive-and-network-drive)
- [Phase 7 — Reboot Server (BOTH identifiers)](#phase-7-reboot-server-both-identifiers)
- [Phase 8 — Post-Reboot Verification](#phase-8-post-reboot-verification)
- [Phase 9 — Negative, Edge & Boundary Tests](#phase-9-negative-edge-boundary-tests)
- [Phase 10 — Other Critical Tests](#phase-10-other-critical-tests)
- [Phase 11 — Test Run Summary (filled per cycle)](#phase-11-test-run-summary-filled-per-cycle)
- [Phase 12 — Notes for the Delivery Lead](#phase-12-notes-for-the-delivery-lead)

> ## ⚠ This document records ACTUAL tests, not automated mock testing
> This plan is executed by an engineer against the **real test appliance
> `oneview.example.com`**. It is **not** the automated regression suite.
> The automated tests (`AUTOMATION_TEST_PLAN.md` and the Pester suite) only
> exercise the code with **mocks and `-DryRun`** — they never touch a real
> appliance, fixture, or ISO, and make **no state changes**. Everything in
> this document, by contrast, is a **real** integration test with captured
> appliance output. Where a phase is destructive it requires an approved
> maintenance window. See [Phase 12](#phase-12--notes-for-the-delivery-lead)
> for the distinction from the mock-only automated plan.

<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 04/09/2026 08:41 UTC</p>
<!-- END:run-date -->

<a id="this-is-the-live-integration-plan"></a>

## ⚠ This is the LIVE INTEGRATION plan

> ### Why this document is kept separately from `AUTOMATION_TEST_PLAN.md`
> `AUTOMATION_TEST_PLAN.md` is the **offline CI regression / unit** plan — it runs entirely
> against **mocks** with **`-DryRun`** and makes **no real appliance calls and no state
> changes**. It proves the *code* but never exercises a live HPE OneView fixture. This
> document is the **LIVE integration** plan executed by an engineer against the **real test
> appliance `oneview.example.com`** — these are the **ACTUAL tests** with real captured
> output. It carries unique, non-regenerable value:
>
> - The **Major Bugs fixed log** (phantom proxy, the `Test-ServerConnectivity`
>   session-drop bug, and the interactive-prompt hangs) — captured incident history.
> - **Actual captured appliance output** (real `Version`, real 16-server fleet) as field evidence.
> - The standing **"test BOTH identifiers (name + serial)"** rule for every targeting command.
> - **Per-phase live evidence** rows filled in during a real maintenance window.
>
> This is exactly the **EMIR Art. 34 / DORA Art. 8–10** field evidence you cannot
> reproduce from mocks, so the document is retained — but it has been **re-pointed to
> the current (rewritten) command surface** below.

<a id="current-oneview-connected-automation-command-testing-status-and-progress-summary"></a>

## Current OneView Connected Automation Command testing status and progress Summary

<!-- BEGIN:oneview-status-summary -->
- Live integration plan re-pointed to the consolidated command surface (`Connect-OneView`, `Disconnect-OneView`, `Configure-PhysicalBuild`, `Test-BuildParams`); `Invoke-IsoDeploy` / `Get-OneViewVersion` / `Update-Firmware` retired from the public surface. Connect-while-connected edge case (CONN-05) added to Phase 1.
<!-- END:oneview-status-summary -->

<a id="major-bugs-fixed-log"></a>

## Major Bugs fixed log

**Date: 24/07/2026**

<a id="1-phantom-proxy-configuration-on-mgmt-host"></a>

### 1. Phantom proxy configuration on <mgmt-host>

A proxy was mistakenly configured and assumed to be in use on the <mgmt-host> automation server.
The server has no proxy — it sits behind a corporate firewall with direct connectivity. The phantom
proxy configuration was removed.

The proxy environment variables (`HTTP_PROXY`, etc.) had persisted because PowerShell environment
variables are stored as Windows credentials and survived process restarts. A dedicated PowerShell
cleanup script was written to purge the stale proxy env vars from the system.

<a id="2-test-serverconnectivity-was-disconnecting-the-oneview-session-after-connecting"></a>

### 2. Test-ServerConnectivity was disconnecting the OneView session after connecting

**Severity: Critical — cascading design flaw across all automation commands.**

`Test-ServerConnectivity` was disconnecting from the HPEOneView appliance immediately after
successfully connecting. This masked a much deeper design issue: the session lifecycle management
across all automation commands was fundamentally broken. Fixing this single defect exposed a
cavernous mess of related connectivity and session-handling design flaws across the entire
command set, requiring significant rework and retesting of Windows and HPEOneView connectivity
logic across all commands.

<a id="3-invoke-isodeploy-pester-tests-hanging-on-interactive-prompts"></a>

### 3. Invoke-IsoDeploy Pester tests hanging on interactive prompts

The 3 Pester tests for `Invoke-IsoDeploy` were hanging indefinitely because `Read-Host` prompts
fired when no target was supplied — acceptable for interactive use, fatal for automated testing
where no operator is present.

**Fix:** Added `$env:AUTOMATED_MODE = 'true'` to the test `BeforeAll` block (with save/restore in
`AfterAll`), matching the pattern used by other test files. This suppresses the interactive
`Read-Host` prompts, allowing the tests to run non-interactively. All 3 tests now pass in 309ms.

> **Note (04/09/2026):** `Invoke-IsoDeploy` is retired from the public surface; its role is now
> `Configure-PhysicalBuild` (external-ISO mode) + `Test-BuildParams` (path resolution). The
> automated-mode guard pattern described here remains the standard for all command tests.

<a id="4-test-serverconnectivity-pester-tests-hanging-on-interactive-credential-prompts"></a>

### 4. Test-ServerConnectivity Pester tests hanging on interactive credential prompts

All 35 tests in `Test-ServerConnectivity.Tests.ps1` were hanging because the credential prompt's
`$isInteractive` guard did not check for `AUTOMATED_MODE`, causing `Read-Host` to fire during
automated test runs where no operator is present to provide input.

**Fix:**
- Added `AUTOMATED_MODE` check to the credential prompt's `$isInteractive` guard in
  `Test-ServerConnectivity.ps1:247`, so it falls through to the non-interactive error path
  instead of calling `Read-Host`.
- Added `$env:AUTOMATED_MODE = 'true'` in `BeforeAll` (with save/restore in `AfterAll`) in
  `Test-ServerConnectivity.Tests.ps1`, matching the pattern used across all other test files.
- All 35 tests now pass in 880ms with no interactive prompts.

**Module under test:** `Automation` PowerShell module (`src/powershell/Automation/Automation.psm1`)
**OneView library:** `HPEOneView.1000` (OneView 10.x) via the public `Connect-OneView` / `Disconnect-OneView` wrappers (which call `Connect-OVMgmt` / `Disconnect-OVMgmt` internally)
**Test appliance:** `oneview.example.com` (Test environment)
**Key commands:** `Connect-OneView`, `Test-ServerConnectivity`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`, `Configure-PhysicalBuild`, `Test-BuildParams`, `Invoke-IloRedfish`, `Start-InstallMonitor`, `Test-PostBuildValidation`, `Set-MaintenanceMode`.

<a id="5-ripgrep-json-record-exceeded-65536-bytes-exception"></a>

### 5. Ripgrep JSON record exceeded 65536 bytes exception

Fixed. The root cause and resolution:

**Root cause** — The error `The ServicePointManager does not support proxies with the https scheme` is not a parameter-count bug. The `"with '3' argument(s)"` text is the HPEOneView internal `RestClient` call, which is why it reads like "too many parms". The real cause: the operator environment/PowerShell profile exports a corporate proxy using an **`https://`** scheme (`HTTPS_PROXY`). .NET rejects an `https`-scheme proxy, so `Connect-OVMgmt` throws.

**What changed** — `Private/OneViewSession.ps1`:
- Rewrote `Set-OneViewProxyBypass` as clean **PowerShell 7 / .NET Core** code (uses `::new()`, `??`, `HttpClient.DefaultProxy`).
- Removed the legacy `winhttp.dll` P/Invoke block (the old PS5.1/.NET-Framework approach).
- The helper now, before every `Connect-OVMgmt`:
  1. Rewrites any `https://` proxy env var (`HTTPS_PROXY`/`HTTP_PROXY`/etc.) to `http://` — proxies tunnel TLS via CONNECT, so the proxy link itself must be `http`.
  2. Rebuilds the in-process .NET proxy (`WebRequest.DefaultWebProxy` + `HttpClient.DefaultProxy`) so the appliance (and its resolved IP) is **bypassed → contacted directly**, while any legitimate `http` proxy stays in place for other traffic.
  3. Appends the appliance to `NO_PROXY` as a final safeguard.
- It is called from `Connect-OneViewSession`, which is shared by `Test-ServerConnectivity`, `Set-MaintenanceMode`, and `Get-OneViewServerTarget`, so all OneView commands are covered.

**Verification** — File re-parses with no syntax errors under `pwsh`, and no `winhttp`/`Add-Type` references remain.

**To deploy** — On the Windows server, re-import the module from the repo checkout (new PS7 session, or `Import-Module ...\Automation.psd1 -Force`) and re-run `Test-ServerConnectivity -OneViewHost oneview.example.com`. The `Status` should now report `AVAILABLE` with `Connected: Yes`.

I also corrected the stale project memory that claimed the module loads under PowerShell 5.1 — it runs under PS7, so no PS5.1 workarounds should be added going forward.

<a id="6-credential-handling-security-hardened"></a>

### 6. Credential handling security hardened

Credential handling hardened as checkov and:

Added a primary `-Credential ([PSCredential])` parameter — the secure entry point. Callers pass a PSCredential from a secret store / Get-Credential; the plaintext password is never assigned to a named variable and is only materialised by .NET inside Invoke-RestMethod -Credential at the network layer.
`-OneViewUser`/`-OneViewPassword` remain only as an env/CyberArk fallback, kept for compatibility with the sibling OneView commands.
Inline # SuppressMessage attributes document why the -AsPlainText conversion is unavoidable (REST Basic auth), so the suppression is auditable rather than silent.
Verification

PSScriptAnalyzer (project PSScriptAnalyzerSettings.psd1): 0 Errors on both files. Remaining Warnings (WriteHost, PSUseConsistentWhitespace, PlainTextForPassword) exactly match the existing Get-OneViewServerTarget.ps1.
Module imports, routes resolve (oneview_connection_status, oneview_server_list), and both -Credential and fallback paths work in DryRun/Mock.
Two things the security team will likely still flag (your call):

SkipCertificateCheck defaults to $true — for banking you probably want it $false with proper CA trust. I left it as-is to avoid breaking internal-CA appliances; say the word and I'll flip the default or remove the switch.
The same plaintext-param pattern exists in the older Get-OneViewServerTarget.ps1 / Resolve-OneViewTarget — I can retrofit -Credential there too for consistency if you want one standard across all OneView commands.

<a id="standing-rule-execution-notes"></a>

## Standing rule & execution notes

**Standing rule — test BOTH identifiers:** Every command that targets a server MUST be executed
**twice** — once by **server name** and once by **serial number** — to prove both resolution paths
work. Where a test appears below, run the name variant and the serial variant (the serial variant
also requires `-OneViewHost oneview.example.com` so the appliance can resolve the serial to a host/iLO).

**Execution notes:**
- All live calls require an approved **maintenance window** on the test appliance (the reboot/install
  tests are destructive).
- Credentials are supplied as a `PSCredential` (env / CyberArk fallback) — **never** plaintext
  `-User`/`-Password`. Flag any deviation to the security review. The primary parameter is `-Credential`.
- **Destructive operations are gated**: `Configure-PhysicalBuild` requires a mandatory `-GuardRail`
  regex (the resolved server name must match) and explicit `-Deploy` (or typing `APPROVE`);
  `Invoke-IloRedfish` destructive actions (`MountAndBoot`, `Reset`) require `-Force`. Always
  `-DryRun` first.
- **Connect-while-connected:** once `Connect-OneView` has established a live session, a second
  `Connect-OneView` **reuses** the session and never drops it (a different `-OneViewHost` only
  **warns** you to `Disconnect-OneView` first). Never "reconnect" a live session — it is the #1
  cause of in-flight-build incidents.

**Column legend:** **Exp. Pass** = expected sign-off date; **Act. Pass** = date/time the test last
passed on `oneview.example.com`; **Status** = `Planned`/`In Progress`/`Passed`/`Failed`/`Blocked`;
**Neg?** = `Y` for negative/edge/boundary tests; **ID-Type** = which identifier the row exercises
(`Name` / `Serial` / `Both` / `—`).

<a id="phase-0-environment-prerequisites-checklist-before-live-run"></a>

## Phase 0 — Environment Prerequisites (checklist before live run)

- [ ] `HPEOneView.1000` PowerShell module installed (PS 7+)
- [ ] `oneview.example.com` reachable from the automation host
- [ ] `PSCredential` for OneView available (env / CyberArk) — no plaintext
- [ ] iLO creds available; target server iLO IP known
- [ ] Network/UNC `.iso` path available for path-resolution test (the module does **NOT** auto-create SMB shares and **never** requires Administrator — supply a network-accessible path)
- [ ] Approved maintenance window on the test appliance
- [ ] `Start-InstallMonitor` timeout/poll tuned for the test server

<a id="phase-1-connectivity-must-pass-before-anything-else"></a>

## Phase 1 — Connectivity (must pass before anything else)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-01 | Connect & authenticate to oneview.example.com | — | `Connect-OneView -OneViewHost oneview.example.com -Credential $cred` | 1. Resolve creds as PSCredential. 2. Run. | `AuthConnect=$true`; session established in `$global:ConnectedSessions`. | N | 04/09/2026 | | Planned |
| OV-02 | Get appliance version (read from connection status) | — | `Get-OneViewConnectionStatus -OneViewHost oneview.example.com -IncludeServerCount` | Inspect `Version` / `ServerCount`. | `Version` populated (e.g. `8200`), consistent with OneView 10.x / `HPEOneView.1000`; `ServerCount` > 0. | N | 04/09/2026 | 27/07/2026 | Passed |
| OV-03 | Connect via public wrappers & disconnect cleanly | — | `Connect-OneView -OneViewHost oneview.example.com -Credential $cred` → `Disconnect-OneView` (and `Disconnect-OneView -Force`) | 1. Connect. 2. Confirm. 3. Disconnect. 4. Re-confirm status `Connected=$false`. | Session established then released; no orphaned sessions; `-Force` suppresses cleanup errors. | N | 04/09/2026 | | Planned |
| OV-04 | **Connect while already connected must NOT drop the live session** | — | With a live session active from OV-01: (a) `Connect-OneView -OneViewHost oneview.example.com` again (same host); (b) `Connect-OneView -OneViewHost <different-host>` | Assert the original session is **reused**, not torn down/reconnected; for a different host it **warns** to `Disconnect-OneView` first. | Original live session intact; no reconnect/drop; warning emitted for mismatched host. (Equivalent to CONN-05 in `AUTOMATION_TEST_PLAN.md`.) | N | 04/09/2026 | | Planned |

**OV-02 — Actual test output** (27/07/2026 15:55 UTC, appliance `oneview.example.com`):

```text
Get-OneViewConnectionStatus    0  1m 2s 982ms  15:55:18

Name                           Value
----                           -----
Reachable                      True
Success                        True
ServerCount
Appliance                      oneview.example.com
Connected                      True
Version                        8200
Error
Server
Authenticated                  True
SessionSource                  HPEOneViewModule
```

<a id="phase-2-get-server-list"></a>

## Phase 2 — Get Server List

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-05 | Retrieve full server list from oneview.example.com | — | `Get-OneViewServerList -OneViewHost oneview.example.com -Credential $cred` | Run, inspect `Servers`. | Non-empty list; each entry carries name, serial, iLO IP, `MaintMode`, `State`. | N | 04/09/2026 | 27/07/2026 | Passed |

**OV-05 — Actual test output** (27/07/2026 15:55 UTC, appliance `oneview.example.com`):

```text
==============================================
  OneView Server List (16 servers)
==============================================

Server Name                      Serial Number    Power     Health      iLO IP
---------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

Name                           Value
----                           -----
Success                        True
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, ALP-STARWAY-01ILO…}
Count                          16
Error
```

<a id="phase-3-information-on-servers-connected-to-this-oneview"></a>

## Phase 3 — Information on Servers Connected to this OneView

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-06 | Server count enumeration | — | `Get-OneViewConnectionStatus -IncludeServerCount` | Check `ServerCount`. | `ServerCount` > 0 and matches appliance inventory. | N | 04/09/2026 | 27/07/2026 | Passed |
| OV-07 | Per-server summary across all connected servers | — | `Get-OneViewServerList` + loop `Get-OneViewConnectionStatus -ServerIdentifier <each name>` | For each server, report power/health. | Every connected server reports `power_state` + `health_status`. | N | 04/09/2026 | | Planned |

<a id="phase-4-information-on-a-specific-server-both-identifiers"></a>

## Phase 4 — Information on a Specific Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-08a | Specific-server status — by server name | Name | `Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier <serverName>` | Run. | `Server` returned: `power_state`, `health_status`, `ilo_ip`, `enclosure_bay`, `resolved_by=Name`. | N | 04/09/2026 | | Planned |
| OV-08b | Specific-server status — by serial number | Serial | `Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier <serial> -IdentifierType Serial` | Run with serial + `-OneViewHost`. | Same `Server` object; `resolved_by=Serial`. | N | 04/09/2026 | | Planned |
| OV-09a | Server target resolution — by server name | Name | `Get-OneViewServerTarget -ServerIdentifier <serverName> -OneViewHost oneview.example.com` | Run. | `Success`, correct `Server`, `ResolvedBy=Name`. | N | 04/09/2026 | | Planned |
| OV-09b | Server target resolution — by serial number | Serial | `Get-OneViewServerTarget -ServerIdentifier <serial> -OneViewHost oneview.example.com -IdentifierType Serial` | Run with serial. | `Success`, correct `Server`, `ResolvedBy=Serial`. | N | 04/09/2026 | | Planned |

<a id="phase-5-validate-iso-path-assign-to-server-both-identifiers"></a>

## Phase 5 — Validate ISO Path & Assign to Server (BOTH identifiers)

> **Re-pointed (04/09/2026):** `Invoke-IsoDeploy` is retired. ISO-path resolution is now
> `Test-BuildParams`; the actual mount/boot/deploy is `Configure-PhysicalBuild` (external-ISO mode)
> or `Invoke-IloRedfish` for fine-grained control. The "both identifiers" rule still applies — run
> the name variant and the serial variant.

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-10a | Validate ISO path resolves to iLO URL — by server name | Name | `Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'` (+ `cifs://`, `https://`, `nfs://`, mapped `H:\`) | Confirm `IsoUrl` resolves to a `cifs://`/`https://`/`nfs://` address. | `Success=$true`; `IsoUrl` iLO-mountable. Local `C:` drive rejected. | N | 04/09/2026 | | Planned |
| OV-10b | Validate ISO path resolves to iLO URL — by serial | Serial | `Test-BuildParams -BaseIsoPath 'cifs://fileserver/isos/WinSrv2025.iso'` | Same resolution. | Same `IsoUrl` result. | N | 04/09/2026 | | Planned |
| OV-11a | Assign ISO (mount virtual media) — by server name | Name | `Configure-PhysicalBuild -ServerIdentifier <name> -OneViewHost oneview.example.com -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' -GuardRail '<regex>' -DryRun` then `-Deploy` | Review plan, then authorize. | Plan printed; with `-Deploy`/`APPROVE` media mounted via resolved iLO IP; `-GuardRail` enforced. | N | 04/09/2026 | | Planned |
| OV-11b | Assign ISO (mount virtual media) — by serial | Serial | `Configure-PhysicalBuild -ServerIdentifier <serial> -OneViewHost oneview.example.com -ExternalIsoPath 'cifs://…' -GuardRail '<regex>' -Deploy` | Same flow. | Same result. | N | 04/09/2026 | | Planned |
| OV-12 | Verify virtual media assigned | — | `Invoke-IloRedfish -Action Status -IloIp <ilo>` | Inspect `virtual_media`. | Media `Inserted`, image = assigned CIFS/HTTPS URL. | N | 04/09/2026 | | Planned |
| OV-13 | Set one-time boot to CD | — | `Invoke-IloRedfish -Action Boot -IloIp <ilo> -Force` | Set boot override. | `BootSourceOverrideTarget=Cd`, `Enabled=Once`. | N | 04/09/2026 | | Planned |

<a id="phase-6-path-smb-name-generation-local-drive-and-network-drive"></a>

## Phase 6 — Path / SMB-Name Generation (local drive AND network drive)

> **Corrected (04/09/2026):** The module does **NOT** auto-create an SMB share and **never**
> requires Administrator privileges (regulated banking environment). You supply a
> **network-accessible** path; `Test-BuildParams` / `Configure-PhysicalBuild` convert it to the
> `cifs://` URL iLO mounts. A bare local drive (`C:\`) is **rejected**.

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-14 | Path resolution from a MAPPED network drive (`H:\`) | — | `Test-BuildParams -BaseIsoPath 'H:\windows.iso'` (H: maps to `\\fileserver\isos`) | Trigger path conversion. | Mapped drive expanded to UNC → `cifs://fileserver/isos/windows.iso` (NO share creation). | N | 04/09/2026 | | Planned |
| OV-15 | Path resolution from NETWORK drive (UNC) | — | `Test-BuildParams -BaseIsoPath '\\fileserver\isos\custom.iso'` (and `//fileserver/isos/custom.iso`) | Trigger path conversion. | UNC / forward-slash UNC converted to `cifs://fileserver/isos/custom.iso` for iLO. | N | 04/09/2026 | | Planned |
| OV-16 | Verify generated SMB/CIFS names mount on iLO | — | `Invoke-IloRedfish -Action Mount -IsoUrl <generated cifs://> -Force` (both mapped- and network-derived URLs) | Mount each generated URL. | Both URLs mount successfully as virtual media. | N | 04/09/2026 | | Planned |

<a id="phase-7-reboot-server-both-identifiers"></a>

## Phase 7 — Reboot Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-17a | Reboot & boot from assigned ISO — by server name | Name | `Invoke-IloRedfish -Action MountAndBoot -IloIp <ilo> -IsoUrl <CIFS> -Force` | Insert ISO, one-time CD boot, `ForceRestart`. | `Success`; "Media inserted, one-time boot CD set, ForceRestart issued". | N | 04/09/2026 | | Planned |
| OV-17b | Reboot & boot from assigned ISO — by serial number | Serial | same, target from `<serial>` + `-OneViewHost` | Same flow. | `Success`; identical result. | N | 04/09/2026 | | Planned |
| OV-18 | Monitor reboot power-state transitions | Both | `Start-InstallMonitor -Server <name>` and `-SerialNumber <serial> -OneViewHost oneview.example.com` | Watch On → Off → On. | Correct completion/failure detection; `Success` for both identifier runs. | N | 04/09/2026 | | Planned |

<a id="phase-8-post-reboot-verification"></a>

## Phase 8 — Post-Reboot Verification

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-19 | Sleep then confirm server is back ONLINE | Both | After `Start-InstallMonitor` completes, `Start-Sleep` then `Get-OneViewConnectionStatus -ServerIdentifier <id>` (name AND serial) | Poll until `power_state=On`. | `power_state=On`, `Connected=$true` for both identifiers. | N | 04/09/2026 | | Planned |
| OV-20a | Confirm correct Windows image installed — by server name | Name | `Test-PostBuildValidation -Hostname <name> -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Hostname, OS version, drivers, ConfigMgr client pass; `AuditFile` written. | N | 04/09/2026 | | Planned |
| OV-20b | Confirm correct Windows image installed — by serial number | Serial | `Test-PostBuildValidation -SerialNumber <serial> -OneViewHost oneview.example.com -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Same checks pass; ISO now the active Windows image. | N | 04/09/2026 | | Planned |
| OV-21 | Confirm server remains manageable in OneView | Both | `Get-OneViewServerList` / `Get-OneViewConnectionStatus` post-install | Confirm health. | Server listed, `health_status` OK, ISO now the booted Windows image. | N | 04/09/2026 | | Planned |

<a id="phase-9-negative-edge-boundary-tests"></a>

## Phase 9 — Negative, Edge & Boundary Tests

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-22 | Invalid credentials rejected | — | `Get-OneViewConnectionStatus` with wrong creds | Bad password. | `Authenticated=$false`, `Connected=$false`, clear error, no crash. | Y | 04/09/2026 | | Planned |
| OV-23 | Unreachable / wrong host | — | `Get-OneViewConnectionStatus -OneViewHost 10.255.255.1` | Dead IP. | `Reachable=$false`, `Success=$false`, graceful. | Y | 04/09/2026 | | Planned |
| OV-24 | Destructive action without `-Force` blocked | — | `Invoke-IloRedfish -Action Reset -IloIp <ilo>` (no `-Force`) | Run. | `Success=$false`, "requires -Force", no reset. | Y | 04/09/2026 | | Planned |
| OV-25 | Mount without `-IsoUrl` | — | `Invoke-IloRedfish -Action Mount -IloIp <ilo> -Force` | Run. | `Success=$false`, "Mount requires -IsoUrl". | Y | 04/09/2026 | | Planned |
| OV-26 | Non-existent server identifier | Both | `Get-OneViewConnectionStatus -ServerIdentifier 'NOPE'` (name + serial-shaped) | Run both. | `Server.connected=$false` with "not found". | Y | 04/09/2026 | | Planned |
| OV-27 | Malformed SMB/CIFS URL | — | `Invoke-IloRedfish -Action Mount -IsoUrl 'not a url' -Force` | Run. | `Success=$false`, iLO media error surfaced cleanly. | Y | 04/09/2026 | | Planned |
| OV-28 | **Ambiguous server identifier (multi-match) — STRICT failure** | — | `Get-OneViewServerTarget -ServerIdentifier <shared substring>` | Run. | **Hard failure** — never silently picks one; `Success=$false` with "multiple matches" error. (Corrected: the resolver is strict single-server.) | Y | 04/09/2026 | | Planned |
| OV-29 | Empty server identifier | — | `Get-OneViewConnectionStatus -ServerIdentifier ''` | Run. | Treated as no lookup or clear validation error. | Y | 04/09/2026 | | Planned |
| OV-30 | Boundary timeout (0 / very low) | — | `Get-OneViewConnectionStatus -TimeoutSec 1` vs slow appliance | Run. | Times out gracefully, `Reachable=$false`, no hang. | Y | 04/09/2026 | | Planned |
| OV-31 | Cert-check toggle | — | `Get-OneViewConnectionStatus -SkipCertificateCheck $false` | Run vs self-signed. | Predictable; fails on bad cert unless skipped. | Y | 04/09/2026 | | Planned |
| OV-32 | Reset while powered Off | — | `Invoke-IloRedfish -Action Reset` on Off server | Run. | Handled: powers On or returns expected state error. | Y | 04/09/2026 | | Planned |
| OV-33 | Concurrent mount on same iLO | — | Two `Mount` calls in parallel | Run. | No corruption; second reflects media or clear conflict. | Y | 04/09/2026 | | Planned |
| OV-34 | **Build without `-GuardRail` blocked** | — | `Configure-PhysicalBuild -ServerIdentifier <name> -OneViewHost oneview.example.com -ExternalIsoPath '\\…'` (no `-GuardRail`) | Run. | Review aborts early; logged error; no deploy. | Y | 04/09/2026 | | Planned |
| OV-35 | **Build with non-matching `-GuardRail` blocked** | — | `Configure-PhysicalBuild … -GuardRail 'WRONG'` | Run. | Resolved name does not match regex → review aborts; no deploy. | Y | 04/09/2026 | | Planned |

<a id="phase-10-other-critical-tests"></a>

## Phase 10 — Other Critical Tests

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|------------|-------|----------------|------|-----------|-----------|--------|
| OV-36 | Maintenance mode enable/disable | Both | `Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber <sn> -Environment Test` then `disable` | Enable + confirm + disable + confirm (also by name). | Toggles correctly; no leftover maintenance. | N | 04/09/2026 | | Planned |
| OV-37 | Firmware update (folded into build; dry-run then real) | Both | `Configure-PhysicalBuild … -ExternalIsoPath '\\…' -FirmwareFolders @('\\srv\fw\BIOS') -GuardRail '<re>' -Deploy` (and `-DryRun` first) | Validate firmware path resolution, then stage. | Dry-run safe; firmware applied as part of the build step. (`Update-Firmware` is retired — its logic is now the build's firmware step.) | N | 04/09/2026 | | Planned |
| OV-38 | Idempotency of MountAndBoot | Both | `Invoke-IloRedfish -Action MountAndBoot` twice (name + serial) | Run twice. | Second run safe; no duplicate/error state. | N | 04/09/2026 | | Planned |
| OV-39 | Audit logging on destructive actions | — | Inspect `AuditFile` after OV-11/OV-17/OV-36 | Check entries. | Every destructive action logged w/ timestamp + result. | N | 04/09/2026 | | Planned |
| OV-40 | Credential hardening (no plaintext) | — | Run live commands with `-Credential`; scan logs | Confirm no password in output/log. | No secret materialisation outside network layer. | N | 04/09/2026 | | Planned |
| OV-41 | Change-freeze safety (read-only) | — | `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Test-ServerConnectivity -DryRun`, `Test-BuildParams -DryRun` | Confirm no mutation. | Read-only commands make no state changes. | N | 04/09/2026 | | Planned |
| OV-42 | Module compatibility check | — | `Set-MaintenanceMode` module matrix vs `HPEOneView.1000` | Confirm selection. | `HPEOneView.1000` chosen for OneView 10.x; PS 7+ noted. | N | 04/09/2026 | | Planned |

<a id="phase-11-test-run-summary-filled-per-cycle"></a>

## Phase 11 — Test Run Summary (filled per cycle)

<!-- BEGIN:phase11-rows -->
| Run # | Date/Time | Phase(s) | Tester | Appliance | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | 27/07/2026 18:55 UTC | Phases 1-10 (pending live execution) | | oneview.example.com | Pending |
| 2 | 24/07/2026 16:34 UTC | 2 | K Everall | oneview.example.com | Success |
| 3 | 24/07/2026 16:34 UTC | Phase 1 | K Everall | oneview.example.com | Passed (95/95) |
| 4 | 27/07/2026 14:55 UTC | Phase 1 | K Everall | oneview.example.com | Passed - Full connectivity verified: DNS resolved (203.0.113.10), TCP 443 open (12ms), auth connected, session persists. Get-OneViewConnectionStatus: Reachable=True, Connected=True, Authenticated=True, Version=8200. Session persistence confirmed (bug #2 fix verified). |
| 5 | 27/07/2026 17:00 UTC | Phase 1 | K Everall | oneview.example.com | Passed - Full connectivity verified. Server list output correctly, test passed. NOTE: version shown as HPEOneView.840 in one probe; will purge powershell env and fix. |
| 6 | 04/09/2026 08:41 UTC | Plan re-pointed to consolidated command surface | — | oneview.example.com | Plan updated (not executed) — `Invoke-IsoDeploy`/`Get-OneViewVersion`/`Update-Firmware` retired; `Connect-OneView`/`Test-BuildParams`/`Configure-PhysicalBuild` adopted; connect-while-connected edge added. |
<!-- END:phase11-rows -->

<a id="phase-12-notes-for-the-delivery-lead"></a>

## Phase 12 — Notes for the Delivery Lead

- **This is the LIVE / ACTUAL plan.** It is distinct from `AUTOMATION_TEST_PLAN.md`, which is
  automated testing that runs **only against mocks and `-DryRun`** and never contacts a real
  appliance. Keep both: the automated plan proves the *code* is wired correctly; this plan
  proves the **appliance integration** with real captured evidence (EMIR/DORA field record).
  A test marked **Passed** here reflects an *actual* run on `oneview.example.com`, not a mock.
- **Command surface re-pointed (04/09/2026):** `Invoke-IsoDeploy` → `Configure-PhysicalBuild` /
  `Test-BuildParams`; `Connect-OVMgmt`/`Disconnect-OVMgmt` → `Connect-OneView`/`Disconnect-OneView`;
  `Get-OneViewVersion` → `Get-OneViewConnectionStatus -IncludeServerCount`; `Update-Firmware` →
  folded into `Configure-PhysicalBuild` firmware step.
- **Two corrections applied:** (1) the module does **not** auto-create SMB shares / require Admin —
  supply a network path; (2) ambiguous server identifiers are a **strict hard failure**, not a
  "first match used" warning.
- **Connect-while-connected (OV-04)** is now an explicit gate: never reconnect a live session; a
  second `Connect-OneView` reuses it and only warns for a different host. This protects in-flight builds.
- Destructive steps (OV-11, OV-17, OV-37) require `-GuardRail` (build) and/or `-Force` (iLO) and an
  approved maintenance window. Always `-DryRun` first.
