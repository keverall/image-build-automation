# HPE OneView 1000 — Live Integration Test Plan

<a id="top"></a>

## Table of Contents

- [**Current OneView Connected Automation Command testing status and progress Summary**](#current-oneview-connected-automation-command-testing-status-and-progress-summary)
- [Major Bugs fixed log](#major-bugs-fixed-log)
  - [1. Phantom proxy configuration on <mgmt-host>](#1-phantom-proxy-configuration-on-mgmt-host)
  - [2. Test-ServerConnectivity was disconnecting the OneView session after connecting](#2-test-serverconnectivity-was-disconnecting-the-oneview-session-after-connecting)
  - [3. Invoke-IsoDeploy Pester tests hanging on interactive prompts](#3-invoke-isodeploy-pester-tests-hanging-on-interactive-prompts)
  - [4. Test-ServerConnectivity Pester tests hanging on interactive credential prompts](#4-test-serverconnectivity-pester-tests-hanging-on-interactive-credential-prompts)
  - [5. Ripgrep JSON record exceeded 65536 bytes exception](#5-ripgrep-json-record-exceeded-65536-bytes-exception)
  - [6. Credential handling security hardened](#6-credential-handling-security-hardened)
- [Phase 0 — Environment Prerequisites (checklist before live run)](#phase-0-environment-prerequisites-checklist-before-live-run)
- [Phase 1 — Connectivity (must pass before anything else)](#phase-1-connectivity-must-pass-before-anything-else)
- [Phase 2 — Get Server List](#phase-2-get-server-list)
- [Phase 3 — Information on Servers Connected to this OneView](#phase-3-information-on-servers-connected-to-this-oneview)
- [Phase 4 — Information on a Specific Server (BOTH identifiers)](#phase-4-information-on-a-specific-server-both-identifiers)
- [Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)](#phase-5-assign-iso-file-to-server-for-install-both-identifiers)
- [Phase 6 — SMB Name Generation (local drive AND network drive)](#phase-6-smb-name-generation-local-drive-and-network-drive)
- [Phase 7 — Reboot Server (BOTH identifiers)](#phase-7-reboot-server-both-identifiers)
- [Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)](#phase-8-post-reboot-verification-sleep-then-confirm-connected-correct-windows-image)
- [Phase 9 — Negative, Edge & Boundary Tests](#phase-9-negative-edge-boundary-tests)
- [Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)](#phase-10-other-critical-tests-setup-automation-hpeoneview-package)
- [Phase 11 — Test Run Summary (filled per cycle)](#phase-11-test-run-summary-filled-per-cycle)
- [Phase 12 — Notes for the Delivery Lead](#phase-12-notes-for-the-delivery-lead)

<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 02/08/2026 01:54 UTC</p>
<!-- END:run-date -->

<a id="current-oneview-connected-automation-command-testing-status-and-progress-summary"></a>

## **Current OneView Connected Automation Command testing status and progress Summary**

<!-- BEGIN:oneview-status-summary -->
- **y**
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
**OneView library:** `HPEOneView.1000` (OneView 10.x) via `Connect-OVMgmt` / `Disconnect-OVMgmt`
**Test appliance:** `oneview.example.com` (Test environment)
**Key commands:** `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`,
`Invoke-IloRedfish`, `Start-InstallMonitor`, `Test-PostBuildValidation`, `Set-MaintenanceMode`,
`Update-Firmware`.

**Standing rule — test BOTH identifiers:** Every command that targets a server MUST be executed
**twice** — once by **server name** and once by **serial number** — to prove both resolution paths
work. Where a test appears below, run the name variant and the serial variant (the serial variant
also requires `-OneViewHost oneview.example.com` so the appliance can resolve the serial to a host/iLO).

**Execution notes:**
- All live calls require an approved **maintenance window** on the test appliance (the reboot/install
  tests are destructive).
- Credentials are supplied as a `PSCredential` (env / CyberArk fallback) — **never** plaintext
  `-User`/`-Password`. Flag any deviation to the security review.
- A local ISO file is shared over SMB and mounted as iLO virtual media; the resulting CIFS URL
  (`//<host>/<share>/<file>.iso`) is what `Invoke-IloRedfish -IsoUrl` consumes. The automation
  auto-creates the SMB share when run as Administrator (see `Invoke-IsoDeploy`/`-ExternalIsoPath`).

**Column legend:** **Exp. Pass** = expected sign-off date (fill per schedule); **Act. Pass** = date/time
the test last passed on `oneview.example.com`; **Status** = `Planned`/`In Progress`/`Passed`/`Failed`/`Blocked`;
**Neg?** = `Y` for negative/edge/boundary tests; **ID-Type** = which identifier the row exercises
(`Name` / `Serial` / `Both` / `—`).

<a id="5-ripgrep-json-record-exceeded-65536-bytes-exception"></a>

### 5. Ripgrep JSON record exceeded 65536 bytes exception

```text

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

I also corrected the stale project memory that claimed the module loads under PowerShell 5.1 — it runs under PS7, so no PS5.1 workarounds should be added going forward. If you want a broader sweep of the rest of the module for other PS5.1-isms, say the word and I'll run it.

All fixes applied and verified. Summary:

Fixed:

✅ SendMetric signature reordered — [hashtable]$Tags now before [datetime]$Timestamp (fixes latent runtime bug)
✅ Dead -Port parameter removed from Connect-OneViewSession
✅ Duplicate Invoke-WindowsSecurityUpdate export removed
✅ SecureString round-trip eliminated — password stays encrypted throughout
✅ _PS_ConvertTo-Hashtable removed — replaced with native ConvertFrom-Json -AsHashtable
✅ Dead else branch in ReportVulnerabilityScan collapsed
✅ All files parse clean. and have been successfully retested.
```

<a id="6-credential-handling-security-hardened"></a>

### 6. Credential handling security hardened

```text
Credential handling hardened as checkov and 

Added a primary -Credential ([PSCredential]) parameter — the secure entry point. Callers pass a PSCredential from a secret store / Get-Credential; the plaintext password is never assigned to a named variable and is only materialised by .NET inside Invoke-RestMethod -Credential at the network layer.
-OneViewUser/-OneViewPassword remain only as an env/CyberArk fallback, kept for compatibility with the sibling OneView commands.
Inline # SuppressMessage attributes document why the -AsPlainText conversion is unavoidable (REST Basic auth), so the suppression is auditable rather than silent.
Verification

PSScriptAnalyzer (project PSScriptAnalyzerSettings.psd1): 0 Errors on both files. Remaining Warnings (WriteHost, PSUseConsistentWhitespace, PlainTextForPassword) exactly match the existing Get-OneViewServerTarget.ps1.
Module imports, routes resolve (oneview_connection_status, oneview_server_list), and both -Credential and fallback paths work in DryRun/Mock.
Two things the security team will likely still flag (your call):

SkipCertificateCheck defaults to $true — for banking you probably want it $false with proper CA trust. I left it as-is to avoid breaking internal-CA appliances; say the word and I'll flip the default or remove the switch.
The same plaintext-param pattern exists in the older Get-OneViewServerTarget.ps1 / Resolve-OneViewTarget — I can retrofit -Credential there too for consistency if you want one standard across all OneView commands.
```

---

<a id="phase-0-environment-prerequisites-checklist-before-live-run"></a>

## Phase 0 — Environment Prerequisites (checklist before live run)

- [ ] `HPEOneView.1000` PowerShell module installed (PS 7+)
- [ ] `oneview.example.com` reachable from the automation host
- [ ] `PSCredential` for OneView available (env / CyberArk) — no plaintext
- [ ] iLO creds available; target server iLO IP known
- [ ] Local `.iso` staged for SMB auto-share (run as Administrator for share creation)
- [ ] Network/UNC `.iso` path available for SMB-name generation test
- [ ] Approved maintenance window on the test appliance
- [ ] `Start-InstallMonitor` timeout/poll tuned for the test server

<a id="phase-1-connectivity-must-pass-before-anything-else"></a>

## Phase 1 — Connectivity (must pass before anything else)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-01</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Connect &amp; authenticate to oneview.example.com</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -OneViewHost oneview.example.com -Credential $cred</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">1. Resolve creds as PSCredential. 2. Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>, <code style="background:#f4f4f4;color:#000000;">Reachable</code>, <code style="background:#f4f4f4;color:#000000;">Authenticated</code>, <code style="background:#f4f4f4;color:#000000;">Connected</code> all <code style="background:#f4f4f4;color:#000000;">$true</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Passed</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-02</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Get appliance version</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus</code> (reads <code style="background:#f4f4f4;color:#000000;">/rest/version</code>)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Inspect <code style="background:#f4f4f4;color:#000000;">Version</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Version</code> populated, consistent with OneView 10.x / <code style="background:#f4f4f4;color:#000000;">HPEOneView.1000</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Passed</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-03</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Connect via HPEOneView.1000 module &amp; disconnect cleanly</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Connect-OVMgmt</code> / <code style="background:#f4f4f4;color:#000000;">Disconnect-OVMgmt</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">1. <code style="background:#f4f4f4;color:#000000;">Connect-OVMgmt -Hostname oneview.example.com -Credential $cred</code>. 2. Confirm. 3. <code style="background:#f4f4f4;color:#000000;">Disconnect-OVMgmt</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Session established then released; no orphaned sessions</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Passed</td>
    </tr>
  </tbody>
</table>

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

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-04</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Retrieve full server list from oneview.example.com</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewServerList -OneViewHost oneview.example.com -Credential $cred</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run, inspect <code style="background:#f4f4f4;color:#000000;">Servers</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Non-empty list; each entry carries name, serial, iLO IP</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Passed</td>
    </tr>
  </tbody>
</table>

**OV-04 — Actual test output** (27/07/2026 15:55 UTC, appliance `oneview.example.com`):

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

<a id="phase-3-information-on-servers-connected-to-this-oneview"></a>

## Phase 3 — Information on Servers Connected to this OneView

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-05</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Server count enumeration</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -IncludeServerCount</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Check <code style="background:#f4f4f4;color:#000000;">ServerCount</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">ServerCount</code> &gt; 0 and matches appliance inventory</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Passed</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-06</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Per-server summary across all connected servers</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewServerList</code> + loop <code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -ServerIdentifier &lt;each name&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">For each server, report power/health.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Every connected server reports <code style="background:#f4f4f4;color:#000000;">power_state</code> + <code style="background:#f4f4f4;color:#000000;">health_status</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-4-information-on-a-specific-server-both-identifiers"></a>

## Phase 4 — Information on a Specific Server (BOTH identifiers)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-07a</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Specific-server status — by server name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier &lt;serverName&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Server</code> returned: <code style="background:#f4f4f4;color:#000000;">power_state</code>, <code style="background:#f4f4f4;color:#000000;">health_status</code>, <code style="background:#f4f4f4;color:#000000;">ilo_ip</code>, <code style="background:#f4f4f4;color:#000000;">enclosure_bay</code>, <code style="background:#f4f4f4;color:#000000;">resolved_by=Name</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-07b</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Specific-server status — by serial number</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Serial</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier &lt;serial&gt; -IdentifierType Serial</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run with serial + <code style="background:#f4f4f4;color:#000000;">-OneViewHost</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Same <code style="background:#f4f4f4;color:#000000;">Server</code> object; <code style="background:#f4f4f4;color:#000000;">resolved_by=Serial</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-08a</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Server target resolution — by server name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewServerTarget -ServerIdentifier &lt;serverName&gt; -OneViewHost oneview.example.com</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>, correct <code style="background:#f4f4f4;color:#000000;">Server</code>, <code style="background:#f4f4f4;color:#000000;">ResolvedBy=Name</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-08b</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Server target resolution — by serial number</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Serial</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewServerTarget -ServerIdentifier &lt;serial&gt; -OneViewHost oneview.example.com -IdentifierType Serial</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run with serial.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>, correct <code style="background:#f4f4f4;color:#000000;">Server</code>, <code style="background:#f4f4f4;color:#000000;">ResolvedBy=Serial</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-5-assign-iso-file-to-server-for-install-both-identifiers"></a>

## Phase 5 — Assign ISO File to Server for Install (BOTH identifiers)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-09a</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Assign ISO (mount virtual media) — by server name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Mount -IloIp &lt;ilo&gt; -IsoUrl &lt;CIFS&gt; -Force</code> (target resolved from <code style="background:#f4f4f4;color:#000000;">&lt;serverName&gt;</code>)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Insert media.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>, media inserted on <code style="background:#f4f4f4;color:#000000;">CdDeviceId</code> 1</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-09b</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Assign ISO (mount virtual media) — by serial number</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Serial</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">same, target resolved from <code style="background:#f4f4f4;color:#000000;">&lt;serial&gt;</code> + <code style="background:#f4f4f4;color:#000000;">-OneViewHost</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Insert media.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>, same media inserted</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-10</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Verify virtual media assigned</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Status -IloIp &lt;ilo&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Inspect <code style="background:#f4f4f4;color:#000000;">virtual_media</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Media <code style="background:#f4f4f4;color:#000000;">Inserted</code>, image = assigned CIFS URL</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-11</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Set one-time boot to CD</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Boot -IloIp &lt;ilo&gt; -Force</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Set boot override.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">BootSourceOverrideTarget=Cd</code>, <code style="background:#f4f4f4;color:#000000;">Enabled=Once</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-6-smb-name-generation-local-drive-and-network-drive"></a>

## Phase 6 — SMB Name Generation (local drive AND network drive)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-12</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">SMB name from LOCAL drive (auto-share)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IsoDeploy</code>/build with <code style="background:#f4f4f4;color:#000000;">-ExternalIsoPath &#x27;H:\windows.iso&#x27;</code> (run as Admin)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">1. Stage local ISO. 2. Trigger share.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">SMB share auto-created; CIFS URL <code style="background:#f4f4f4;color:#000000;">//&lt;host&gt;/&lt;share&gt;/windows.iso</code> formed correctly</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-13</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">SMB name from NETWORK drive (UNC)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IsoDeploy</code> with <code style="background:#f4f4f4;color:#000000;">-ExternalIsoPath &#x27;\\fileserver\isos\custom.iso&#x27;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Trigger path conversion.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">UNC converted to CIFS URL <code style="background:#f4f4f4;color:#000000;">//fileserver/isos/custom.iso</code> for iLO</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-14</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Verify generated SMB names mount on iLO</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Mount -IsoUrl &lt;generated CIFS&gt; -Force</code> (both local- and network-derived URLs)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Mount each generated URL.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both URLs mount successfully as virtual media</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-7-reboot-server-both-identifiers"></a>

## Phase 7 — Reboot Server (BOTH identifiers)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-15a</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Reboot &amp; boot from assigned ISO — by server name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action MountAndBoot -IloIp &lt;ilo&gt; -IsoUrl &lt;CIFS&gt; -Force</code> (target from <code style="background:#f4f4f4;color:#000000;">&lt;serverName&gt;</code>)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Insert ISO, one-time CD boot, <code style="background:#f4f4f4;color:#000000;">ForceRestart</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>; &quot;Media inserted, one-time boot CD set, ForceRestart issued&quot;</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-15b</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Reboot &amp; boot from assigned ISO — by serial number</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Serial</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">same, target from <code style="background:#f4f4f4;color:#000000;">&lt;serial&gt;</code> + <code style="background:#f4f4f4;color:#000000;">-OneViewHost</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Same flow.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success</code>; identical result</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-16</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Monitor reboot power-state transitions</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Start-InstallMonitor -Server &lt;serverName&gt;</code> and <code style="background:#f4f4f4;color:#000000;">-SerialNumber &lt;serial&gt; -OneViewHost oneview.example.com</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Watch On → Off → On.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Correct completion/failure detection; <code style="background:#f4f4f4;color:#000000;">Success</code> for both identifier runs</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-8-post-reboot-verification-sleep-then-confirm-connected-correct-windows-image"></a>

## Phase 8 — Post-Reboot Verification (sleep, then confirm connected + correct Windows image)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-17</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Sleep then confirm server is back ONLINE</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">After <code style="background:#f4f4f4;color:#000000;">Start-InstallMonitor</code> completes, <code style="background:#f4f4f4;color:#000000;">Start-Sleep</code> then <code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -ServerIdentifier &lt;id&gt;</code> (run for name AND serial)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Poll until <code style="background:#f4f4f4;color:#000000;">power_state=On</code>.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Server reports <code style="background:#f4f4f4;color:#000000;">power_state=On</code>, <code style="background:#f4f4f4;color:#000000;">Connected=$true</code> for both identifiers</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-18a</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm correct Windows image installed — by server name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Name</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Test-PostBuildValidation -Hostname &lt;serverName&gt; -Domain &lt;dom&gt; -ExpectedOsVersion &lt;win&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run post-build checks.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Hostname, OS version (Windows image), drivers, ConfigMgr client all pass; <code style="background:#f4f4f4;color:#000000;">AuditFile</code> written</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-18b</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm correct Windows image installed — by serial number</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Serial</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Test-PostBuildValidation -SerialNumber &lt;serial&gt; -OneViewHost oneview.example.com -Domain &lt;dom&gt; -ExpectedOsVersion &lt;win&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run post-build checks.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Same checks pass; ISO now installed as the active Windows image</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-19</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm server remains manageable in OneView</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewServerList</code> / <code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus</code> post-install</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm health.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Server listed, <code style="background:#f4f4f4;color:#000000;">health_status</code> OK, ISO now the booted Windows image</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-9-negative-edge-boundary-tests"></a>

## Phase 9 — Negative, Edge & Boundary Tests

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-20</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Invalid credentials rejected</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus</code> with wrong creds</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Bad password.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Authenticated=$false</code>, <code style="background:#f4f4f4;color:#000000;">Connected=$false</code>, clear error, no crash</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-21</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Unreachable / wrong host</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -OneViewHost 10.255.255.1</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Dead IP.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Reachable=$false</code>, <code style="background:#f4f4f4;color:#000000;">Success=$false</code>, graceful</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-22</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Destructive action without <code style="background:#f4f4f4;color:#000000;">-Force</code> blocked</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Reset -IloIp &lt;ilo&gt;</code> (no <code style="background:#f4f4f4;color:#000000;">-Force</code>)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success=$false</code>, &quot;requires -Force&quot;, no reset</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-23</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Mount without <code style="background:#f4f4f4;color:#000000;">-IsoUrl</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Mount -IloIp &lt;ilo&gt; -Force</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success=$false</code>, &quot;Mount requires -IsoUrl&quot;</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-24</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Non-existent server identifier</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -ServerIdentifier &#x27;NOPE&#x27;</code> (name + serial-shaped)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run both.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Server.connected=$false</code> with &quot;not found&quot;</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-25</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Malformed SMB/CIFS URL</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Mount -IsoUrl &#x27;not a url&#x27; -Force</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Success=$false</code>, iLO media error surfaced cleanly</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-26</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Ambiguous server identifier (multi-match)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -ServerIdentifier &lt;shared substring&gt;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Warning; first match used; <code style="background:#f4f4f4;color:#000000;">resolved_by</code> recorded</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-27</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Empty server identifier</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -ServerIdentifier &#x27;&#x27;</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Treated as no lookup or clear validation error</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-28</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Boundary timeout (0 / very low)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -TimeoutSec 1</code> vs slow appliance</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Times out gracefully, <code style="background:#f4f4f4;color:#000000;">Reachable=$false</code>, no hang</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-29</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Cert-check toggle</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus -SkipCertificateCheck $false</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run vs self-signed.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Predictable; fails on bad cert unless skipped</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-30</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Reset while powered Off</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action Reset</code> on Off server</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Handled: powers On or returns expected state error</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-31</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Concurrent mount on same iLO</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Two <code style="background:#f4f4f4;color:#000000;">Mount</code> calls in parallel</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">No corruption; second reflects media or clear conflict</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Y</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

<a id="phase-10-other-critical-tests-setup-automation-hpeoneview-package"></a>

## Phase 10 — Other Critical Tests (Setup-Automation HPEOneView Package)

<table style="border-collapse:collapse;width:100%;table-layout:auto;">
  <thead>
    <tr>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Test ID</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Title</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">ID-Type</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Command(s)</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Steps</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Expected Result</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Neg?</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Exp. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Act. Pass</th>
      <th style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;background:#e8e8e8;">Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-32</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Maintenance mode enable/disable</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber &lt;sn&gt; -Environment Test</code> then <code style="background:#f4f4f4;color:#000000;">disable</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Enable + confirm + disable + confirm (also by name)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Toggles correctly; no leftover maintenance</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-33</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Firmware update (dry-run then real)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Update-Firmware -OneViewHost oneview.example.com</code> (<code style="background:#f4f4f4;color:#000000;">-Server</code>/<code style="background:#f4f4f4;color:#000000;">-SerialNumber</code>) <code style="background:#f4f4f4;color:#000000;">-DryRun</code> then apply</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Validate, then stage</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Dry-run safe; apply yields valid result</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-34</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Idempotency of MountAndBoot</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Both</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Invoke-IloRedfish -Action MountAndBoot</code> twice (name + serial)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run twice.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Second run safe; no duplicate/error state</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-35</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Audit logging on destructive actions</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Inspect <code style="background:#f4f4f4;color:#000000;">AuditFile</code> after OV-15/OV-32</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Check entries.</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Every destructive action logged w/ timestamp + result</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-36</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Credential hardening (no plaintext)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Run live commands with <code style="background:#f4f4f4;color:#000000;">-Credential</code>; scan logs</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm no password in output/log</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">No secret materialisation outside network layer</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-37</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Change-freeze safety (read-only)</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Get-OneViewConnectionStatus</code>, <code style="background:#f4f4f4;color:#000000;">Get-OneViewServerList</code>, <code style="background:#f4f4f4;color:#000000;">Test-ServerConnectivity -DryRun</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm no mutation</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Read-only commands make no state changes</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
    <tr>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">OV-38</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Module compatibility check</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">—</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">Set-MaintenanceMode</code> module matrix vs <code style="background:#f4f4f4;color:#000000;">HPEOneView.1000</code></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Confirm selection</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"><code style="background:#f4f4f4;color:#000000;">HPEOneView.1000</code> chosen for OneView 10.x; PS 7+ noted</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">N</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">27/07/2026</td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;"></td>
      <td style="border:1px solid #999999;padding:6px 10px;vertical-align:top;color:#000000;background:#ffffff;">Planned</td>
    </tr>
  </tbody>
</table>

---

<a id="phase-11-test-run-summary-filled-per-cycle"></a>

## Phase 11 — Test Run Summary (filled per cycle)

<!-- BEGIN:phase11-rows -->
|Run #|Date/Time|Phase(s)|Tester|Appliance|Result|
|---|---|---|---|---|---|
|1|27/07/2026 18:55 UTC|Phases 1-10 (pending live execution)||oneview.example.com|Pending|
|2|24/07/2026 16:34 UTC|2|K Everall|oneview.example.com|Success|
|3|24/07/2026 16:34 UTC|Phase 1|K Everall|oneview.example.com|Passed (95/95)|
|4|27/07/2026 14:55 UTC|Phase 1|K Everall|oneview.example.com|Passed - Full connectivity verified: DNS resolved (203.0.113.10), TCP 443 open (12ms), auth connected, session persists. Get-OneViewConnectionStatus: Reachable=True, Connected=True, Authenticated=True, Version=8200. Session persistence confirmed (bug #2 fix verified).|
|5|27/07/2026 17:00 UTC|Phase 1|K Everall|oneview.example.com|Passed - Full connectivity verified: DNS resolved (203.0.113.10), TCP 443 open (12ms), auth connected, session persists. Get-OneViewConnectionStatus: Reachable=True, Connected=True, Authenticated=True, Version=8200. Session persistence confirmed (bug #2 fix verified). Server list output correctly, test passed, version shown is incorrect as HPeOneView.840 version shown, will purge powershell env and fix|
|6|31/07/2026 09:14 UTC|Phase 1|K Everall|oneview.example.com|NO TESTING TODAY AS THERE IS A FREEZE UNTIL 31/07/2026|
|7| 02/08/2026 01:54 UTC |Phases 1-10|K Everall|oneview.example.com|Passed (99/99)|
| 8 | 02/08/2026 01:54 UTC | Phases 1-10 | Kev | oneview.example.com | Pending |
<!-- END:phase11-rows -->

<a id="phase-12-notes-for-the-delivery-lead"></a>

## Phase 12 — Notes for the Delivery Lead

- The plan is ordered as a real run: **connect (Phase 1) → server list (2) → connected-server info (3)
  → specific-server info (4) → assign ISO (5) → SMB name generation local+network (6) → reboot (7) →
  post-reboot verify (8)**. Later phases (9–10) are negative and package-level coverage.
- **Both identifiers** (server name + serial number) are exercised for every server-scoped command
  (Phases 4, 5, 7, 8, 10) per the standing rule — serial runs also pass `-OneViewHost`.
- Fill **Exp. Pass** against the project schedule; update **Act. Pass** + **Status** as each test is
  executed on `oneview.example.com` and evidenced in Phase 11.
