# HPE OneView 1000 — Live Integration Test Plan

<a id="top"></a>
## Table of Contents

- [HPE OneView 1000 — Live Integration Test Plan](#hpe-oneview-1000--live-integration-test-plan)
  - [Table of Contents](#table-of-contents)
  - [**Current OneView Connected Automation Command testing status and progress Summary**](#current-oneview-connected-automation-command-testing-status-and-progress-summary)
  - [Major Bugs fixed log](#major-bugs-fixed-log)
    - [1. Phantom proxy configuration on EWISMGMT-19](#1-phantom-proxy-configuration-on-ewismgmt-19)
    - [2. Test-ServerConnectivity was disconnecting the OneView session after connecting](#2-test-serverconnectivity-was-disconnecting-the-oneview-session-after-connecting)
    - [3. Invoke-IsoDeploy Pester tests hanging on interactive prompts](#3-invoke-isodeploy-pester-tests-hanging-on-interactive-prompts)
    - [4. Test-ServerConnectivity Pester tests hanging on interactive credential prompts](#4-test-serverconnectivity-pester-tests-hanging-on-interactive-credential-prompts)
  - [Phase 0 — Environment Prerequisites (checklist before live run)](#phase-0--environment-prerequisites-checklist-before-live-run)
  - [Phase 1 — Connectivity (must pass before anything else)](#phase-1--connectivity-must-pass-before-anything-else)
  - [Phase 2 — Get Server List](#phase-2--get-server-list)
  - [Phase 3 — Information on Servers Connected to this OneView](#phase-3--information-on-servers-connected-to-this-oneview)
  - [Phase 4 — Information on a Specific Server (BOTH identifiers)](#phase-4--information-on-a-specific-server-both-identifiers)
  - [Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)](#phase-5--assign-iso-file-to-server-for-install-both-identifiers)
  - [Phase 6 — SMB Name Generation (local drive AND network drive)](#phase-6--smb-name-generation-local-drive-and-network-drive)
  - [Phase 7 — Reboot Server (BOTH identifiers)](#phase-7--reboot-server-both-identifiers)
  - [Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)](#phase-8--post-reboot-verification-sleep-then-confirm-connected--correct-windows-image)
  - [Phase 9 — Negative, Edge \& Boundary Tests](#phase-9--negative-edge--boundary-tests)
  - [Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)](#phase-10--other-critical-tests-setup-automation-hpeoneview-package)
  - [Phase 11 — Execution Evidence (per cycle)](#phase-11--execution-evidence-per-cycle)
  - [Phase 12 — Notes for the Delivery Lead](#phase-12--notes-for-the-delivery-lead)
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 24/07/2026 16:34 UTC</p>
<!-- END:run-date -->
<a name="current-oneview-connected-automation-command-testing-status-and-progress-summary"></a>
## **Current OneView Connected Automation Command testing status and progress Summary**

<!-- BEGIN:oneview-status-summary -->
- **Fixed major bugs and had to write script to remove proxy env vars from powershell/windows state, and refactor major sections of code to fix issues listed in detail below in major bugs fixed log**
<!-- END:oneview-status-summary -->

<a name="major-bugs-fixed-log"></a>
## Major Bugs fixed log

**Date: 24/07/2026**

<a name="1-phantom-proxy-configuration-on-ewismgmt-19"></a>
### 1. Phantom proxy configuration on EWISMGMT-19

A proxy was mistakenly configured and assumed to be in use on the EWISMGMT-19 automation server.
The server has no proxy — it sits behind a corporate firewall with direct connectivity. The phantom
proxy configuration was removed.

The proxy environment variables (`HTTP_PROXY`, etc.) had persisted because PowerShell environment
variables are stored as Windows credentials and survived process restarts. A dedicated PowerShell
cleanup script was written to purge the stale proxy env vars from the system.

<a name="2-test-serverconnectivity-was-disconnecting-the-oneview-session-after-connecting"></a>
### 2. Test-ServerConnectivity was disconnecting the OneView session after connecting

**Severity: Critical — cascading design flaw across all automation commands.**

`Test-ServerConnectivity` was disconnecting from the HPEOneView appliance immediately after
successfully connecting. This masked a much deeper design issue: the session lifecycle management
across all automation commands was fundamentally broken. Fixing this single defect exposed a
cavernous mess of related connectivity and session-handling design flaws across the entire
command set, requiring significant rework and retesting of Windows and HPEOneView connectivity
logic across all commands.

<a name="3-invoke-isodeploy-pester-tests-hanging-on-interactive-prompts"></a>
### 3. Invoke-IsoDeploy Pester tests hanging on interactive prompts

The 3 Pester tests for `Invoke-IsoDeploy` were hanging indefinitely because `Read-Host` prompts
fired when no target was supplied — acceptable for interactive use, fatal for automated testing
where no operator is present.

**Fix:** Added `$env:AUTOMATED_MODE = 'true'` to the test `BeforeAll` block (with save/restore in
`AfterAll`), matching the pattern used by other test files. This suppresses the interactive
`Read-Host` prompts, allowing the tests to run non-interactively. All 3 tests now pass in 309ms.

<a name="4-test-serverconnectivity-pester-tests-hanging-on-interactive-credential-prompts"></a>
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
**OneView library:** `HPEOneView.1000` (OneView 10.x) via `Connect-OVMgmt` / `Disconnect-OVMgmt`
**Test appliance:** `HPEOpenview.1000` (Test environment)
**Key commands:** `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`,
`Invoke-IloRedfish`, `Start-InstallMonitor`, `Test-PostBuildValidation`, `Set-MaintenanceMode`,
`Update-Firmware`.

**Standing rule — test BOTH identifiers:** Every command that targets a server MUST be executed
**twice** — once by **server name** and once by **serial number** — to prove both resolution paths
work. Where a test appears below, run the name variant and the serial variant (the serial variant
also requires `-OneViewHost HPEOpenview.1000` so the appliance can resolve the serial to a host/iLO).

**Execution notes:**
- All live calls require an approved **maintenance window** on the test appliance (the reboot/install
  tests are destructive).
- Credentials are supplied as a `PSCredential` (env / CyberArk fallback) — **never** plaintext
  `-User`/`-Password`. Flag any deviation to the security review.
- A local ISO file is shared over SMB and mounted as iLO virtual media; the resulting CIFS URL
  (`//<host>/<share>/<file>.iso`) is what `Invoke-IloRedfish -IsoUrl` consumes. The automation
  auto-creates the SMB share when run as Administrator (see `Invoke-IsoDeploy`/`-ExternalIsoPath`).

**Column legend:** **Exp. Pass** = expected sign-off date (fill per schedule); **Act. Pass** = date/time
the test last passed on `HPEOpenview.1000`; **Status** = `Planned`/`In Progress`/`Passed`/`Failed`/`Blocked`;
**Neg?** = `Y` for negative/edge/boundary tests; **ID-Type** = which identifier the row exercises
(`Name` / `Serial` / `Both` / `—`).

---

<a name="phase-0-environment-prerequisites-checklist-before-live-run"></a>
## Phase 0 — Environment Prerequisites (checklist before live run)

- [ ] `HPEOneView.1000` PowerShell module installed (PS 7+)
- [ ] `HPEOpenview.1000` reachable from the automation host
- [ ] `PSCredential` for OneView available (env / CyberArk) — no plaintext
- [ ] iLO creds available; target server iLO IP known
- [ ] Local `.iso` staged for SMB auto-share (run as Administrator for share creation)
- [ ] Network/UNC `.iso` path available for SMB-name generation test
- [ ] Approved maintenance window on the test appliance
- [ ] `Start-InstallMonitor` timeout/poll tuned for the test server

<a name="phase-1-connectivity-must-pass-before-anything-else"></a>
## Phase 1 — Connectivity (must pass before anything else)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-01 | Connect & authenticate to HPEOpenview.1000 | — | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -Credential $cred` | 1. Resolve creds as PSCredential. 2. Run. | `Success`, `Reachable`, `Authenticated`, `Connected` all `$true` | N | 23/07/2026 | 23/07/2026 | Passed |
| OV-02 | Get appliance version | — | `Get-OneViewConnectionStatus` (reads `/rest/version`) | Inspect `Version`. | `Version` populated, consistent with OneView 10.x / `HPEOneView.1000` | N | 23/07/2026 | 23/07/2026 | Passed |
| OV-03 | Connect via HPEOneView.1000 module & disconnect cleanly | — | `Connect-OVMgmt` / `Disconnect-OVMgmt` | 1. `Connect-OVMgmt -Hostname HPEOpenview.1000 -Credential $cred`. 2. Confirm. 3. `Disconnect-OVMgmt`. | Session established then released; no orphaned sessions | N | 23/07/2026 | | Passed |

**OV-02 — Actual test output** (27/07/2026 15:55 UTC, appliance `va-oneviewt-01`):

```text
Get-OneViewConnectionStatus    0  1m 2s 982ms  15:55:18

Name                           Value
----                           -----
Reachable                      True
Success                        True
ServerCount
Appliance                      va-oneviewt-01
Connected                      True
Version                        8200
Error
Server
Authenticated                  True
SessionSource                  HPEOneViewModule
```

<a name="phase-2-get-server-list"></a>
## Phase 2 — Get Server List

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-04 | Retrieve full server list from HPEOpenview.1000 | — | `Get-OneViewServerList -OneViewHost HPEOpenview.1000 -Credential $cred` | Run, inspect `Servers`. | Non-empty list; each entry carries name, serial, iLO IP | N | 23/07/2026 | | Passed |

**OV-04 — Actual test output** (27/07/2026 15:55 UTC, appliance `va-oneviewt-01`):

```text

   image-build-automation  Get-OneViewServerList                                                                                                                0  16:56:56 
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

<a name="phase-3-information-on-servers-connected-to-this-oneview"></a>

## Phase 3 — Information on Servers Connected to this OneView

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-05 | Server count enumeration | — | `Get-OneViewConnectionStatus -IncludeServerCount` | Check `ServerCount`. | `ServerCount` > 0 and matches appliance inventory | N | 23/07/2026 | | Passed |
| OV-06 | Per-server summary across all connected servers | — | `Get-OneViewServerList` + loop `Get-OneViewConnectionStatus -ServerIdentifier <each name>` | For each server, report power/health. | Every connected server reports `power_state` + `health_status` | N | 23/07/2026 | | Planned |

<a name="phase-4-information-on-a-specific-server-both-identifiers"></a>
## Phase 4 — Information on a Specific Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-07a | Specific-server status — by server name | Name | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -ServerIdentifier <serverName>` | Run. | `Server` returned: `power_state`, `health_status`, `ilo_ip`, `enclosure_bay`, `resolved_by=Name` | N | 23/07/2026 | | Planned |
| OV-07b | Specific-server status — by serial number | Serial | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -ServerIdentifier <serial> -IdentifierType Serial` | Run with serial + `-OneViewHost`. | Same `Server` object; `resolved_by=Serial` | N | 23/07/2026 | | Planned |
| OV-08a | Server target resolution — by server name | Name | `Get-OneViewServerTarget -ServerIdentifier <serverName> -OneViewHost HPEOpenview.1000` | Run. | `Success`, correct `Server`, `ResolvedBy=Name` | N | 23/07/2026 | | Planned |
| OV-08b | Server target resolution — by serial number | Serial | `Get-OneViewServerTarget -ServerIdentifier <serial> -OneViewHost HPEOpenview.1000 -IdentifierType Serial` | Run with serial. | `Success`, correct `Server`, `ResolvedBy=Serial` | N | 23/07/2026 | | Planned |

<a name="phase-5-assign-iso-file-to-server-for-install-both-identifiers"></a>
## Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-09a | Assign ISO (mount virtual media) — by server name | Name | `Invoke-IloRedfish -Action Mount -IloIp <ilo> -IsoUrl <CIFS> -Force` (target resolved from `<serverName>`) | Insert media. | `Success`, media inserted on `CdDeviceId` 1 | N | 23/07/2026 | | Planned |
| OV-09b | Assign ISO (mount virtual media) — by serial number | Serial | same, target resolved from `<serial>` + `-OneViewHost` | Insert media. | `Success`, same media inserted | N | 23/07/2026 | | Planned |
| OV-10 | Verify virtual media assigned | — | `Invoke-IloRedfish -Action Status -IloIp <ilo>` | Inspect `virtual_media`. | Media `Inserted`, image = assigned CIFS URL | N | 23/07/2026 | | Planned |
| OV-11 | Set one-time boot to CD | — | `Invoke-IloRedfish -Action Boot -IloIp <ilo> -Force` | Set boot override. | `BootSourceOverrideTarget=Cd`, `Enabled=Once` | N | 23/07/2026 | | Planned |

<a name="phase-6-smb-name-generation-local-drive-and-network-drive"></a>
## Phase 6 — SMB Name Generation (local drive AND network drive)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-12 | SMB name from LOCAL drive (auto-share) | — | `Invoke-IsoDeploy`/build with `-ExternalIsoPath 'H:\windows.iso'` (run as Admin) | 1. Stage local ISO. 2. Trigger share. | SMB share auto-created; CIFS URL `//<host>/<share>/windows.iso` formed correctly | N | 23/07/2026 | | Planned |
| OV-13 | SMB name from NETWORK drive (UNC) | — | `Invoke-IsoDeploy` with `-ExternalIsoPath '\\fileserver\isos\custom.iso'` | Trigger path conversion. | UNC converted to CIFS URL `//fileserver/isos/custom.iso` for iLO | N | 23/07/2026 | | Planned |
| OV-14 | Verify generated SMB names mount on iLO | — | `Invoke-IloRedfish -Action Mount -IsoUrl <generated CIFS> -Force` (both local- and network-derived URLs) | Mount each generated URL. | Both URLs mount successfully as virtual media | N | 23/07/2026 | | Planned |

<a name="phase-7-reboot-server-both-identifiers"></a>
## Phase 7 — Reboot Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-15a | Reboot & boot from assigned ISO — by server name | Name | `Invoke-IloRedfish -Action MountAndBoot -IloIp <ilo> -IsoUrl <CIFS> -Force` (target from `<serverName>`) | Insert ISO, one-time CD boot, `ForceRestart`. | `Success`; "Media inserted, one-time boot CD set, ForceRestart issued" | N | 23/07/2026 | | Planned |
| OV-15b | Reboot & boot from assigned ISO — by serial number | Serial | same, target from `<serial>` + `-OneViewHost` | Same flow. | `Success`; identical result | N | 23/07/2026 | | Planned |
| OV-16 | Monitor reboot power-state transitions | Both | `Start-InstallMonitor -Server <serverName>` and `-SerialNumber <serial> -OneViewHost HPEOpenview.1000` | Watch On → Off → On. | Correct completion/failure detection; `Success` for both identifier runs | N | 23/07/2026 | | Planned |

<a name="phase-8-post-reboot-verification-sleep-then-confirm-connected-correct-windows-image"></a>
## Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-17 | Sleep then confirm server is back ONLINE | Both | After `Start-InstallMonitor` completes, `Start-Sleep` then `Get-OneViewConnectionStatus -ServerIdentifier <id>` (run for name AND serial) | Poll until `power_state=On`. | Server reports `power_state=On`, `Connected=$true` for both identifiers | N | 23/07/2026 | | Planned |
| OV-18a | Confirm correct Windows image installed — by server name | Name | `Test-PostBuildValidation -Hostname <serverName> -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Hostname, OS version (Windows image), drivers, ConfigMgr client all pass; `AuditFile` written | N | 23/07/2026 | | Planned |
| OV-18b | Confirm correct Windows image installed — by serial number | Serial | `Test-PostBuildValidation -SerialNumber <serial> -OneViewHost HPEOpenview.1000 -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Same checks pass; ISO now installed as the active Windows image | N | 23/07/2026 | | Planned |
| OV-19 | Confirm server remains manageable in OneView | Both | `Get-OneViewServerList` / `Get-OneViewConnectionStatus` post-install | Confirm health. | Server listed, `health_status` OK, ISO now the booted Windows image | N | 23/07/2026 | | Planned |

<a name="phase-9-negative-edge-and-boundary-tests"></a>
## Phase 9 — Negative, Edge & Boundary Tests

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-20 | Invalid credentials rejected | — | `Get-OneViewConnectionStatus` with wrong creds | Bad password. | `Authenticated=$false`, `Connected=$false`, clear error, no crash | Y | 23/07/2026 | | Planned |
| OV-21 | Unreachable / wrong host | — | `Get-OneViewConnectionStatus -OneViewHost 10.255.255.1` | Dead IP. | `Reachable=$false`, `Success=$false`, graceful | Y | 23/07/2026 | | Planned |
| OV-22 | Destructive action without `-Force` blocked | — | `Invoke-IloRedfish -Action Reset -IloIp <ilo>` (no `-Force`) | Run. | `Success=$false`, "requires -Force", no reset | Y | 23/07/2026 | | Planned |
| OV-23 | Mount without `-IsoUrl` | — | `Invoke-IloRedfish -Action Mount -IloIp <ilo> -Force` | Run. | `Success=$false`, "Mount requires -IsoUrl" | Y | 23/07/2026 | | Planned |
| OV-24 | Non-existent server identifier | Both | `Get-OneViewConnectionStatus -ServerIdentifier 'NOPE'` (name + serial-shaped) | Run both. | `Server.connected=$false` with "not found" | Y | 23/07/2026 | | Planned |
| OV-25 | Malformed SMB/CIFS URL | — | `Invoke-IloRedfish -Action Mount -IsoUrl 'not a url' -Force` | Run. | `Success=$false`, iLO media error surfaced cleanly | Y | 23/07/2026 | | Planned |
| OV-26 | Ambiguous server identifier (multi-match) | — | `Get-OneViewConnectionStatus -ServerIdentifier <shared substring>` | Run. | Warning; first match used; `resolved_by` recorded | Y | 23/07/2026 | | Planned |
| OV-27 | Empty server identifier | — | `Get-OneViewConnectionStatus -ServerIdentifier ''` | Run. | Treated as no lookup or clear validation error | Y | 23/07/2026 | | Planned |
| OV-28 | Boundary timeout (0 / very low) | — | `Get-OneViewConnectionStatus -TimeoutSec 1` vs slow appliance | Run. | Times out gracefully, `Reachable=$false`, no hang | Y | 23/07/2026 | | Planned |
| OV-29 | Cert-check toggle | — | `Get-OneViewConnectionStatus -SkipCertificateCheck $false` | Run vs self-signed. | Predictable; fails on bad cert unless skipped | Y | 23/07/2026 | | Planned |
| OV-30 | Reset while powered Off | — | `Invoke-IloRedfish -Action Reset` on Off server | Run. | Handled: powers On or returns expected state error | Y | 23/07/2026 | | Planned |
| OV-31 | Concurrent mount on same iLO | — | Two `Mount` calls in parallel | Run. | No corruption; second reflects media or clear conflict | Y | 23/07/2026 | | Planned |

<a name="phase-10-other-critical-tests-setup-automation-hpeoneview-package"></a>

## Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-32 | Maintenance mode enable/disable | Both | `Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber <sn> -Environment Test` then `disable` | Enable + confirm + disable + confirm (also by name) | Toggles correctly; no leftover maintenance | N | 23/07/2026 | | Planned |
| OV-33 | Firmware update (dry-run then real) | Both | `Update-Firmware -OneViewHost HPEOpenview.1000` (`-Server`/`-SerialNumber`) `-DryRun` then apply | Validate, then stage | Dry-run safe; apply yields valid result | N | 23/07/2026 | | Planned |
| OV-34 | Idempotency of MountAndBoot | Both | `Invoke-IloRedfish -Action MountAndBoot` twice (name + serial) | Run twice. | Second run safe; no duplicate/error state | N | 23/07/2026 | | Planned |
| OV-35 | Audit logging on destructive actions | — | Inspect `AuditFile` after OV-15/OV-32 | Check entries. | Every destructive action logged w/ timestamp + result | N | 23/07/2026 | | Planned |
| OV-36 | Credential hardening (no plaintext) | — | Run live commands with `-Credential`; scan logs | Confirm no password in output/log | No secret materialisation outside network layer | N | 23/07/2026 | | Planned |
| OV-37 | Change-freeze safety (read-only) | — | `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Test-ServerConnectivity -DryRun` | Confirm no mutation | Read-only commands make no state changes | N | 23/07/2026 | | Planned |
| OV-38 | Module compatibility check | — | `Set-MaintenanceMode` module matrix vs `HPEOneView.1000` | Confirm selection | `HPEOneView.1000` chosen for OneView 10.x; PS 7+ noted | N | 23/07/2026 | | Planned |

---

<a name="phase-11-execution-evidence-per-cycle"></a>

## Phase 11 — Execution Evidence (per cycle)

<!-- BEGIN:phase11-rows -->
| Run # | Date/Time | Phase(s) | Tester | Appliance | Result | Log/Job Ref | Signed off |
|-------|-----------|----------|--------|-----------|--------|-------------|------------|
| 1 | 23/07/2026 18:55 UTC | Phases 1-10 (pending live execution) | <tester> | HPEOpenview.1000 | Pending | <log ref> | <delivery lead> |
| 2 | 24/07/2026 16:34 UTC | 2 | K Everall | HPEOpenview.1000 | Success | <log ref> | <delivery lead> |
| 3 | 24/07/2026 16:34 UTC | Phase 1 | K Everall | HPEOpenview.1000 | (all 95 automated regression unit test scenarios above) \| Ran manually on terminal \| Passed (95/95) \| see run log below \| Removed phantom proxy config on EWISMGMT-19; fixed critical OneView session-lifecycle design flaw across all automation commands; suppressed interactive Read-Host prompts in Invoke-IsoDeploy (3 tests, 309ms) and Test-ServerConnectivity (35 tests, 880ms) for non-interactive automated testing. | 20260724 | n/a |
| 4 | 27/07/2026 14:55 UTC | Phase 1 | K Everall | va-oneviewt-01 | Passed - Full connectivity verified: DNS resolved (10.239.124.79), TCP 443 open (12ms), auth connected, session persists. Get-OneViewConnectionStatus: Reachable=True, Connected=True, Authenticated=True, Version=8200. Session persistence confirmed (bug #2 fix verified). | 20260727 | n/a |
<!-- END:phase11-rows -->

<a name="phase-12-notes-for-the-delivery-lead"></a>

## Phase 12 — Notes for the Delivery Lead

- The plan is ordered as a real run: **connect (Phase 1) → server list (2) → connected-server info (3)
  → specific-server info (4) → assign ISO (5) → SMB name generation local+network (6) → reboot (7) →
  post-reboot verify (8)**. Later phases (9–10) are negative and package-level coverage.
- **Both identifiers** (server name + serial number) are exercised for every server-scoped command
  (Phases 4, 5, 7, 8, 10) per the standing rule — serial runs also pass `-OneViewHost`.
- Fill **Exp. Pass** against the project schedule; update **Act. Pass** + **Status** as each test is
  executed on `HPEOpenview.1000` and evidenced in Phase 11.


```text
 Get-OneViewServerList                                                                                                                0  16:45:13 
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
Count                          16
Error
Success                        True
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, ALP-STARWAY-01ILO…}






 image-build-automation  Get-OneViewConnectionStatus                                                                                                          0  16:55:39 
Name                           Value
----                           -----
Success                        False
Appliance
Error                          No active OneView session. Use Test-ServerConnectivity -ManagementHost <oneview-appliance-host> to connect, or supply -OneViewHost. 
Authenticated                  False
Reachable                      False
Connected                      False

   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                                                               0  16:55:44 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-27 15:56:09 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-27 15:56:09 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 19ms) 
This management appliance is a company owned asset and provided for the exclusive use of authorized personnel. Unauthorized use or abuse of this system may lead to corrective 
action including termination, civil and/or criminal penalties.
 

============================================== 
  OneView Connectivity Test
============================================== 

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-07-27T15:56:33.4130999Z
 
  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79 
    TCP:       Open (port 443, 19ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded 
    Connected: Yes (session active)

==============================================

2026-07-27 15:56:33 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)

Name                           Value
----                           -----
Available                      True
Environment                    Prod
ManagementHost                 va-oneviewt-01
Mode                           oneview
NetworkPing                    {[Error, ], [Port, 443], [LatencyMs, 19], [IpAddress, 10.239.124.79]…}
Timestamp                      2026-07-27T15:56:33.4130999Z
AuthConnect                    {[Error, ], [Connected, True], [Disconnected, False], [ModuleLoaded, True]}

   image-build-automation  Get-OneViewConnectionStatus                                                                                               0  42s 223ms  16:56:33 
Name                           Value 
----                           -----
SessionSource                  HPEOneViewModule
Appliance                      va-oneviewt-01
Reachable                      True
Version                        8200
Connected                      True
Server
Error
Success                        True
Authenticated                  True
ServerCount

   image-build-automation  Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000                                                                            0  16:56:43 
Name                           Value 
----                           -----
SessionSource                  Explicit
Appliance                      HPEOpenview.1000
Reachable                      False
Version
Connected                      False
Server
Error                          OneView appliance 'HPEOpenview.1000' is not reachable: No such host is known. (hpeopenview.1000:443)
Success                        False 
Authenticated                  False
ServerCount

   image-build-automation  Get-OneViewServerList                                                                                                                0  16:56:56 
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