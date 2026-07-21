# HPE OneView 1000 — Live Integration Test Plan

## Table of Contents

- [Phase 0 — Environment Prerequisites (checklist before live run)](#phase-0-environment-prerequisites-checklist-before-live-run)
- [Phase 1 — Connectivity (must pass before anything else)](#phase-1-connectivity-must-pass-before-anything-else)
- [Phase 2 — Get Server List](#phase-2-get-server-list)
- [Phase 3 — Information on Servers Connected to this OneView](#phase-3-information-on-servers-connected-to-this-oneview)
- [Phase 4 — Information on a Specific Server (BOTH identifiers)](#phase-4-information-on-a-specific-server-both-identifiers)
- [Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)](#phase-5-assign-iso-file-to-server-for-install-both-identifiers)
- [Phase 6 — SMB Name Generation (local drive AND network drive)](#phase-6-smb-name-generation-local-drive-and-network-drive)
- [Phase 7 — Reboot Server (BOTH identifiers)](#phase-7-reboot-server-both-identifiers)
- [Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)](#phase-8-post-reboot-verification-sleep-then-confirm-connected-correct-windows-image)
- [Phase 9 — Negative, Edge & Boundary Tests](#phase-9-negative-edge-and-boundary-tests)
- [Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)](#phase-10-other-critical-tests-setup-automation-hpeoneview-package)
- [Phase 11 — Execution Evidence (per cycle)](#phase-11-execution-evidence-per-cycle)
- [Phase 12 — Notes for the Delivery Lead](#phase-12-notes-for-the-delivery-lead)


**Purpose:** A *separate* test plan covering automation tested **against the test HPE OneView 1000
appliance** (`HPEOpenview.1000`), ordered as a logical end-to-end run: connect → server list →
information on connected servers → information on a specific server → assign ISO → SMB boot-image
name generation → reboot → server comes back and takes the ISO → post-reboot verification.

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
| OV-01 | Connect & authenticate to HPEOpenview.1000 | — | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -Credential $cred` | 1. Resolve creds as PSCredential. 2. Run. | `Success`, `Reachable`, `Authenticated`, `Connected` all `$true` | N | 25/07/2026 | | Planned |
| OV-02 | Get appliance version | — | `Get-OneViewConnectionStatus` (reads `/rest/version`) | Inspect `Version`. | `Version` populated, consistent with OneView 10.x / `HPEOneView.1000` | N | 25/07/2026 | | Planned |
| OV-03 | Connect via HPEOneView.1000 module & disconnect cleanly | — | `Connect-OVMgmt` / `Disconnect-OVMgmt` | 1. `Connect-OVMgmt -Hostname HPEOpenview.1000 -Credential $cred`. 2. Confirm. 3. `Disconnect-OVMgmt`. | Session established then released; no orphaned sessions | N | 25/07/2026 | | Planned |

<a name="phase-2-get-server-list"></a>
## Phase 2 — Get Server List

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-04 | Retrieve full server list from HPEOpenview.1000 | — | `Get-OneViewServerList -OneViewHost HPEOpenview.1000 -Credential $cred` | Run, inspect `Servers`. | Non-empty list; each entry carries name, serial, iLO IP | N | 25/07/2026 | | Planned |

<a name="phase-3-information-on-servers-connected-to-this-oneview"></a>
## Phase 3 — Information on Servers Connected to this OneView

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-05 | Server count enumeration | — | `Get-OneViewConnectionStatus -IncludeServerCount` | Check `ServerCount`. | `ServerCount` > 0 and matches appliance inventory | N | 25/07/2026 | | Planned |
| OV-06 | Per-server summary across all connected servers | — | `Get-OneViewServerList` + loop `Get-OneViewConnectionStatus -ServerIdentifier <each name>` | For each server, report power/health. | Every connected server reports `power_state` + `health_status` | N | 25/07/2026 | | Planned |

<a name="phase-4-information-on-a-specific-server-both-identifiers"></a>
## Phase 4 — Information on a Specific Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-07a | Specific-server status — by server name | Name | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -ServerIdentifier <serverName>` | Run. | `Server` returned: `power_state`, `health_status`, `ilo_ip`, `enclosure_bay`, `resolved_by=Name` | N | 25/07/2026 | | Planned |
| OV-07b | Specific-server status — by serial number | Serial | `Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000 -ServerIdentifier <serial> -IdentifierType Serial` | Run with serial + `-OneViewHost`. | Same `Server` object; `resolved_by=Serial` | N | 25/07/2026 | | Planned |
| OV-08a | Server target resolution — by server name | Name | `Get-OneViewServerTarget -ServerIdentifier <serverName> -OneViewHost HPEOpenview.1000` | Run. | `Success`, correct `Server`, `ResolvedBy=Name` | N | 25/07/2026 | | Planned |
| OV-08b | Server target resolution — by serial number | Serial | `Get-OneViewServerTarget -ServerIdentifier <serial> -OneViewHost HPEOpenview.1000 -IdentifierType Serial` | Run with serial. | `Success`, correct `Server`, `ResolvedBy=Serial` | N | 25/07/2026 | | Planned |

<a name="phase-5-assign-iso-file-to-server-for-install-both-identifiers"></a>
## Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-09a | Assign ISO (mount virtual media) — by server name | Name | `Invoke-IloRedfish -Action Mount -IloIp <ilo> -IsoUrl <CIFS> -Force` (target resolved from `<serverName>`) | Insert media. | `Success`, media inserted on `CdDeviceId` 1 | N | 25/07/2026 | | Planned |
| OV-09b | Assign ISO (mount virtual media) — by serial number | Serial | same, target resolved from `<serial>` + `-OneViewHost` | Insert media. | `Success`, same media inserted | N | 25/07/2026 | | Planned |
| OV-10 | Verify virtual media assigned | — | `Invoke-IloRedfish -Action Status -IloIp <ilo>` | Inspect `virtual_media`. | Media `Inserted`, image = assigned CIFS URL | N | 25/07/2026 | | Planned |
| OV-11 | Set one-time boot to CD | — | `Invoke-IloRedfish -Action Boot -IloIp <ilo> -Force` | Set boot override. | `BootSourceOverrideTarget=Cd`, `Enabled=Once` | N | 25/07/2026 | | Planned |

<a name="phase-6-smb-name-generation-local-drive-and-network-drive"></a>
## Phase 6 — SMB Name Generation (local drive AND network drive)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-12 | SMB name from LOCAL drive (auto-share) | — | `Invoke-IsoDeploy`/build with `-ExternalIsoPath 'H:\windows.iso'` (run as Admin) | 1. Stage local ISO. 2. Trigger share. | SMB share auto-created; CIFS URL `//<host>/<share>/windows.iso` formed correctly | N | 25/07/2026 | | Planned |
| OV-13 | SMB name from NETWORK drive (UNC) | — | `Invoke-IsoDeploy` with `-ExternalIsoPath '\\fileserver\isos\custom.iso'` | Trigger path conversion. | UNC converted to CIFS URL `//fileserver/isos/custom.iso` for iLO | N | 25/07/2026 | | Planned |
| OV-14 | Verify generated SMB names mount on iLO | — | `Invoke-IloRedfish -Action Mount -IsoUrl <generated CIFS> -Force` (both local- and network-derived URLs) | Mount each generated URL. | Both URLs mount successfully as virtual media | N | 25/07/2026 | | Planned |

<a name="phase-7-reboot-server-both-identifiers"></a>
## Phase 7 — Reboot Server (BOTH identifiers)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-15a | Reboot & boot from assigned ISO — by server name | Name | `Invoke-IloRedfish -Action MountAndBoot -IloIp <ilo> -IsoUrl <CIFS> -Force` (target from `<serverName>`) | Insert ISO, one-time CD boot, `ForceRestart`. | `Success`; "Media inserted, one-time boot CD set, ForceRestart issued" | N | 25/07/2026 | | Planned |
| OV-15b | Reboot & boot from assigned ISO — by serial number | Serial | same, target from `<serial>` + `-OneViewHost` | Same flow. | `Success`; identical result | N | 25/07/2026 | | Planned |
| OV-16 | Monitor reboot power-state transitions | Both | `Start-InstallMonitor -Server <serverName>` and `-SerialNumber <serial> -OneViewHost HPEOpenview.1000` | Watch On → Off → On. | Correct completion/failure detection; `Success` for both identifier runs | N | 25/07/2026 | | Planned |

<a name="phase-8-post-reboot-verification-sleep-then-confirm-connected-correct-windows-image"></a>
## Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-17 | Sleep then confirm server is back ONLINE | Both | After `Start-InstallMonitor` completes, `Start-Sleep` then `Get-OneViewConnectionStatus -ServerIdentifier <id>` (run for name AND serial) | Poll until `power_state=On`. | Server reports `power_state=On`, `Connected=$true` for both identifiers | N | 25/07/2026 | | Planned |
| OV-18a | Confirm correct Windows image installed — by server name | Name | `Test-PostBuildValidation -Hostname <serverName> -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Hostname, OS version (Windows image), drivers, ConfigMgr client all pass; `AuditFile` written | N | 25/07/2026 | | Planned |
| OV-18b | Confirm correct Windows image installed — by serial number | Serial | `Test-PostBuildValidation -SerialNumber <serial> -OneViewHost HPEOpenview.1000 -Domain <dom> -ExpectedOsVersion <win>` | Run post-build checks. | Same checks pass; ISO now installed as the active Windows image | N | 25/07/2026 | | Planned |
| OV-19 | Confirm server remains manageable in OneView | Both | `Get-OneViewServerList` / `Get-OneViewConnectionStatus` post-install | Confirm health. | Server listed, `health_status` OK, ISO now the booted Windows image | N | 25/07/2026 | | Planned |

<a name="phase-9-negative-edge-and-boundary-tests"></a>
## Phase 9 — Negative, Edge & Boundary Tests

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-20 | Invalid credentials rejected | — | `Get-OneViewConnectionStatus` with wrong creds | Bad password. | `Authenticated=$false`, `Connected=$false`, clear error, no crash | Y | 25/07/2026 | | Planned |
| OV-21 | Unreachable / wrong host | — | `Get-OneViewConnectionStatus -OneViewHost 10.255.255.1` | Dead IP. | `Reachable=$false`, `Success=$false`, graceful | Y | 25/07/2026 | | Planned |
| OV-22 | Destructive action without `-Force` blocked | — | `Invoke-IloRedfish -Action Reset -IloIp <ilo>` (no `-Force`) | Run. | `Success=$false`, "requires -Force", no reset | Y | 25/07/2026 | | Planned |
| OV-23 | Mount without `-IsoUrl` | — | `Invoke-IloRedfish -Action Mount -IloIp <ilo> -Force` | Run. | `Success=$false`, "Mount requires -IsoUrl" | Y | 25/07/2026 | | Planned |
| OV-24 | Non-existent server identifier | Both | `Get-OneViewConnectionStatus -ServerIdentifier 'NOPE'` (name + serial-shaped) | Run both. | `Server.connected=$false` with "not found" | Y | 25/07/2026 | | Planned |
| OV-25 | Malformed SMB/CIFS URL | — | `Invoke-IloRedfish -Action Mount -IsoUrl 'not a url' -Force` | Run. | `Success=$false`, iLO media error surfaced cleanly | Y | 25/07/2026 | | Planned |
| OV-26 | Ambiguous server identifier (multi-match) | — | `Get-OneViewConnectionStatus -ServerIdentifier <shared substring>` | Run. | Warning; first match used; `resolved_by` recorded | Y | 25/07/2026 | | Planned |
| OV-27 | Empty server identifier | — | `Get-OneViewConnectionStatus -ServerIdentifier ''` | Run. | Treated as no lookup or clear validation error | Y | 25/07/2026 | | Planned |
| OV-28 | Boundary timeout (0 / very low) | — | `Get-OneViewConnectionStatus -TimeoutSec 1` vs slow appliance | Run. | Times out gracefully, `Reachable=$false`, no hang | Y | 25/07/2026 | | Planned |
| OV-29 | Cert-check toggle | — | `Get-OneViewConnectionStatus -SkipCertificateCheck $false` | Run vs self-signed. | Predictable; fails on bad cert unless skipped | Y | 25/07/2026 | | Planned |
| OV-30 | Reset while powered Off | — | `Invoke-IloRedfish -Action Reset` on Off server | Run. | Handled: powers On or returns expected state error | Y | 25/07/2026 | | Planned |
| OV-31 | Concurrent mount on same iLO | — | Two `Mount` calls in parallel | Run. | No corruption; second reflects media or clear conflict | Y | 25/07/2026 | | Planned |

<a name="phase-10-other-critical-tests-setup-automation-hpeoneview-package"></a>
## Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)

| Test ID | Title | ID-Type | Command(s) | Steps | Expected Result | Neg? | Exp. Pass | Act. Pass | Status |
|---------|-------|---------|-----------|-------|-----------------|------|-----------|-----------|--------|
| OV-32 | Maintenance mode enable/disable | Both | `Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber <sn> -Environment Test` then `disable` | Enable + confirm + disable + confirm (also by name) | Toggles correctly; no leftover maintenance | N | 25/07/2026 | | Planned |
| OV-33 | Firmware update (dry-run then real) | Both | `Update-Firmware -OneViewHost HPEOpenview.1000` (`-Server`/`-SerialNumber`) `-DryRun` then apply | Validate, then stage | Dry-run safe; apply yields valid result | N | 25/07/2026 | | Planned |
| OV-34 | Idempotency of MountAndBoot | Both | `Invoke-IloRedfish -Action MountAndBoot` twice (name + serial) | Run twice. | Second run safe; no duplicate/error state | N | 25/07/2026 | | Planned |
| OV-35 | Audit logging on destructive actions | — | Inspect `AuditFile` after OV-15/OV-32 | Check entries. | Every destructive action logged w/ timestamp + result | N | 25/07/2026 | | Planned |
| OV-36 | Credential hardening (no plaintext) | — | Run live commands with `-Credential`; scan logs | Confirm no password in output/log | No secret materialisation outside network layer | N | 25/07/2026 | | Planned |
| OV-37 | Change-freeze safety (read-only) | — | `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Test-ServerConnectivity -DryRun` | Confirm no mutation | Read-only commands make no state changes | N | 25/07/2026 | | Planned |
| OV-38 | Module compatibility check | — | `Set-MaintenanceMode` module matrix vs `HPEOneView.1000` | Confirm selection | `HPEOneView.1000` chosen for OneView 10.x; PS 7+ noted | N | 25/07/2026 | | Planned |

---

<a name="phase-11-execution-evidence-per-cycle"></a>
## Phase 11 — Execution Evidence (per cycle)

| Run # | Date/Time | Phase(s) | Tester | Appliance | Result | Log/Job Ref | Signed off |
|-------|-----------|----------|--------|-----------|--------|-------------|------------|
| | | | | HPEOpenview.1000 | | | |

<a name="phase-12-notes-for-the-delivery-lead"></a>
## Phase 12 — Notes for the Delivery Lead

- The plan is ordered as a real run: **connect (Phase 1) → server list (2) → connected-server info (3)
  → specific-server info (4) → assign ISO (5) → SMB name generation local+network (6) → reboot (7) →
  post-reboot verify (8)**. Later phases (9–10) are negative and package-level coverage.
- **Both identifiers** (server name + serial number) are exercised for every server-scoped command
  (Phases 4, 5, 7, 8, 10) per the standing rule — serial runs also pass `-OneViewHost`.
- Fill **Exp. Pass** against the project schedule; update **Act. Pass** + **Status** as each test is
  executed on `HPEOpenview.1000` and evidenced in Phase 11.
