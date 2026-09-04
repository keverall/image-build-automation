# Automation test guide for process teams and change approvers

<a id="top"></a>

## Table of Contents

- [Purpose of this document](#purpose-of-this-document)
- [Who this is for](#who-this-is-for)
- [What the test suite does](#what-the-test-suite-does)
- [How to read the test results](#how-to-read-the-test-results)
- [Tests by runbook stage](#tests-by-runbook-stage)
  - [1. Connection & connectivity – `Test-ServerConnectivity` / `Connect-OneView`](#1-connection-connectivity-test-serverconnectivity-connect-oneview)
  - [2. Identifying the target server – `Get-OneViewServerTarget`](#2-identifying-the-target-server-get-oneviewservertarget)
  - [3. Validating the ISO / build path – `Test-BuildParams`](#3-validating-the-iso-build-path-test-buildparams)
  - [4. Pre-build checks – `Test-PreBuildValidation`](#4-pre-build-checks-test-prebuildvalidation)
  - [5. The build (4-eye review + deploy) – `Configure-PhysicalBuild`](#5-the-build-4-eye-review-deploy-configure-physicalbuild)
  - [6. Mounting the ISO and forcing boot – `Invoke-IloRedfish`](#6-mounting-the-iso-and-forcing-boot-invoke-iloredfish)
  - [7. Post-build checks – `Test-PostBuildValidation`](#7-post-build-checks-test-postbuildvalidation)
  - [8. Monitoring the install – `Start-InstallMonitor`](#8-monitoring-the-install-start-installmonitor)
  - [9. Windows security updates (ISO patching) – `Invoke-WindowsSecurityUpdate`](#9-windows-security-updates-iso-patching-invoke-windowssecurityupdate)
- [Test criticality at a glance](#test-criticality-at-a-glance)
- [What a failed test means for a change request](#what-a-failed-test-means-for-a-change-request)
- [Running the test suite](#running-the-test-suite)
- [Glossary for non-technical readers](#glossary-for-non-technical-readers)
- [Related documents](#related-documents)

<a id="purpose-of-this-document"></a>

## Purpose of this document

This guide explains what the automation test suite for the HPE physical server build process actually does. It is written for:

- **Process team members** who need to understand how the automation is validated before it runs against real servers.
- **Change advisory board (CAB) members and approvers** who need confidence that the automation behaves correctly before a production change is approved.
- **Service desk and operations staff** who may need to interpret a test result and escalate if necessary.

It is intentionally written without requiring scripting or development knowledge.

The companion technical document is the runbook at [docs/Automation/runbook-requirements.md](./runbook-requirements.md#top). This guide explains the tests; the runbook explains the process the tests are protecting.

<a id="who-this-is-for"></a>

## Who this is for

| Role | What this document helps you do |
| --- | --- |
| Process team member | Understand which stages of the build are covered by automated checks before each release. |
| CAB / change approver | Judge whether the automation is sufficiently tested before approving a production build. |
| Operations / service desk | Interpret a test failure and decide whether it blocks a build or is informational. |
| Auditor | Show that the automation has repeatable, documented quality checks. |

If you need to run or debug the tests, speak to an engineer in the Server Engineering team. This document is for understanding, not operating.

<a id="what-the-test-suite-does"></a>

## What the test suite does

The file `scripts/run-automation-mode-tests.ps1` runs a collection of **automated checks** (called "unit tests" in the industry) that prove the automation behaves as expected. You can think of them as a series of "what would happen if..." simulations covering every stage of the runbook, from connecting to OneView to checking the server after the build has finished.

Key properties of the suite:

- It **does not touch real servers, real iLO interfaces, or real Configuration Manager sites**. It uses safe "dry-run" and "mock" modes so a failed test cannot damage hardware or cause a real outage. (Separate *live integration* tests against a test appliance exist, but they require an approved maintenance window and are not part of this CI gate.)
- It **exits with a failure code if any test fails**, which blocks automated pipelines. A failing test should be treated as a stop/go decision gate for any change request.
- It **produces a log file** in `generated/logs/<environment>/` so the result can be attached to a change record as evidence.
- It **runs the full set of Pester test files in `tests/powershell/`** — the regression suite grew from 68 to 99 scenarios as OneView connectivity-lifecycle and logging coverage was added. Each public command (connection, lookup, validation, build, iLO, monitoring, maintenance) has its own test file.

In short: the test suite is the quality gate the runbook is sitting behind. Approving a change when the suite is red means accepting risk. Approving it when green means the automation has been validated against its own specification.

<a id="how-to-read-the-test-results"></a>

## How to read the test results

When the suite runs, it produces a summary block like this:

```text
Total Tests    : <number>
Passed         : <number>  ✔
Failed         : <number>  ✔  or  ✘ (CRITICAL)
Skipped        : <number>
Duration       : <seconds>s
```

How to interpret it:

- **Passed** means the automation behaved exactly as the runbook expects for that step. For example, it correctly identified a server, or refused to operate without a guard-rail.
- **Failed** means the automation either behaved unexpectedly or could not complete the step. A single failure flags the whole suite as red. Treat any failure as a stop: do not approve a production change on a red result.
- **Skipped** means a test intentionally did not run, usually because the environment does not support it (for example, a test that needs a live WinRM connection being skipped in a lab without Windows hosts). Skips are not failures.
- **Duration** is how long the suite took. A sudden increase in duration can itself be a warning sign (for example, network timeouts).

<a id="tests-by-runbook-stage"></a>

## Tests by runbook stage

Each test file maps to one stage of the runbook at [docs/Automation/runbook-requirements.md](./runbook-requirements.md#top). They are listed below in the order the build actually happens. The first stage — connection — is the most important to get right, because every later stage reuses that live session; losing it mid-build is an incident.

<a id="1-connection-connectivity-test-serverconnectivity-connect-oneview"></a>

### 1. Connection & connectivity – `Test-ServerConnectivity` / `Connect-OneView`

**Test file:** `tests/powershell/Test-ServerConnectivity.Tests.ps1`, `tests/powershell/Connect-OneView.Tests.ps1`
**Runbook step:** *Connect to and verify HPE OneView* (the first thing every build does)

**What it tests, in plain language**

Before anything else, the automation must confirm the OneView appliance is reachable and that it can establish and hold a session. The tests check that:

- `Test-ServerConnectivity` reports the connection status **without prompting** and degrades gracefully when no session exists.
- `Connect-OneView` establishes a persistent session using credentials entered at the prompt (or a supplied `PSCredential` for automated runs).
- **A second connect while a session is already live does NOT drop the existing connection** — it reuses the session, or warns you to disconnect first if you point at a different appliance. This protects against the exact "lost the live session mid-build" class of incident.
- `Disconnect-OneView` cleanly closes the session (and `Disconnect-OneView -Force` suppresses cleanup errors).
- `Get-OneViewConnectionStatus` reports reachability, authentication, appliance version and managed-server count, and works by name, serial, iLO IP or bay.

**Why this matters**

Every downstream command reuses the OneView session. A dropped, duplicated, or silently-reconnected session is the #1 cause of live-incident bugs. These tests are the guard around the guard.

**Criticality:** CRITICAL. A regression here (for example, a reconnect that drops the live session) can abort an in-flight build and impact a real server.

<a id="2-identifying-the-target-server-get-oneviewservertarget"></a>

### 2. Identifying the target server – `Get-OneViewServerTarget`

**Test file:** `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1`
**Runbook step:** *Identify and validate the target server in HPE OneView*

**What it tests, in plain language**

Before anything touches a server, the automation must correctly identify *which* server it is building. The tests check that:

- The lookup function is available and accepts server name, serial number, identifier type, OneView host, and a mock result for offline testing.
- With a provided mock result, the function returns the correct server and serial number without making any network call.
- If no OneView host is configured (and it is running in automated mode), the function fails cleanly rather than guessing.
- An unknown identifier type (for example, someone passing "Bogus" instead of "Serial" or "Name") is rejected.
- A name or serial that matches **more than one** server is a hard failure — it never silently picks one. This is the most important behaviour, because it underpins every destructive step.

**Why this matters**

This is the "right server, right build" check. Getting it wrong is the highest-severity incident the runbook describes: building the wrong server.

**Criticality:** CRITICAL. A failure here, or a regression that allowed this function to silently accept bad input, would risk a wrong-server build.

<a id="3-validating-the-iso-build-path-test-buildparams"></a>

### 3. Validating the ISO / build path – `Test-BuildParams`

**Test file:** `tests/powershell/Test-BuildParams.Unit.Tests.ps1` *(to be added)*
**Runbook step:** *Validate the boot ISO path before mounting it*

**What it tests, in plain language**

The automation converts a network-share Windows ISO path into the address the iLO BMC can mount as virtual media, and confirms the file is usable. The tests check that:

- Every accepted format resolves correctly: `\\server\share\file.iso` (UNC), `//server/share/file.iso` (forward-slash UNC), `cifs://…`, `smb://…`, `https://…`, `nfs://…`, and a mapped network drive `H:\file.iso`.
- A **local drive** path (`C:\…`) is rejected, because the iLO BMC is a separate controller and cannot read local disks.
- Firmware folder locations are validated by the same resolver.

**Why this matters**

If the ISO path is wrong or points at a local disk, iLO mounts nothing and the build fails late and expensively. This test catches bad media paths before anything is mounted.

**Criticality:** HIGH. A failure here means the build may be pointed at an unreachable or invalid ISO.

<a id="4-pre-build-checks-test-prebuildvalidation"></a>

### 4. Pre-build checks – `Test-PreBuildValidation`

**Test file:** `tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1`
**Runbook step:** *Validation Checklist – Pre-build validation*

**What it tests, in plain language**

Before a build starts, the automation runs a list of "are we ready?" checks: is OneView reachable, is iLO contactable, are the management and distribution points accessible from the build network, is the ISO URL valid? The tests check that:

- The function is available, and accepts flags to skip individual checks (for example, `-SkipOneView`, `-SkipIlo`, `-SkipDpMp`, `-SkipIsoUrl`).
- When run with all checks skipped (which is how the tests run offline), it still returns a structured result with a checks dictionary, meaning downstream automation always gets a consistent shape of answer.
- When no ISO URL is supplied, the ISO-URL check is correctly skipped rather than failing the whole pre-build.
- An explicit audit record is always created, to satisfy the runbook's audit requirements.

**Why this matters**

Pre-build validation is the difference between discovering a missing driver in the first minute of the build and discovering it 40 minutes in after a failed disk step. If the pre-build checks do not run, or silently skip important checks, the build is likely to fail later in an expensive way. These tests prove the pre-check function always produces a complete, structured result.

**Criticality:** HIGH. A failure here undermines the gate that prevents bad builds from starting.

<a id="5-the-build-4-eye-review-deploy-configure-physicalbuild"></a>

### 5. The build (4-eye review + deploy) – `Configure-PhysicalBuild`

**Test file:** `tests/powershell/Configure-PhysicalBuild.Unit.Tests.ps1`
**Runbook step:** The complete Standard Operating Procedure (ISO build/publish, OneView resolution, iLO mount + boot, monitoring, post-build, maintenance mode)

**What it tests, in plain language**

`Configure-PhysicalBuild` is the **single build command** operators run. It performs the full 4-eye review internally and — only after you type `APPROVE` or pass `-Deploy` (alias `-Execute`) — executes the build pipeline: OneView resolution, maintenance-mode enable, iLO mount, OS install, post-build validation, and maintenance-mode disable. The tests verify that:

- The review runs and prints the plan **without making any change** until authorized; a missing or non-matching `-GuardRail` regex aborts the review before anything destructive is even planned.
- `-GuardRail` is mandatory: matching the resolved server name is allowed; a non-matching or omitted guard-rail aborts with a logged error (no deploy).
- External-ISO mode accepts every network path form (`\\`, `//`, `cifs://`, `smb://`, `https://`, mapped drive) and does not require the ConfigMgr build/publish parameters.
- The skip / maintenance-mode flags (`-NoMaintenanceMode`, `-SkipPreBuild`, `-SkipOneView`, `-SkipIlo`, `-SkipDpMp`, `-SkipIsoUrl`, `-Force`) are honoured.
- In "dry-run" mode, the command prints the plan only and performs no action.

> **Note:** `New-IsoBuild`, `Publish-BootIso`, `Invoke-IsoDeploy` and `Start-PhysicalServerBuild` from earlier versions have been **merged into `Configure-PhysicalBuild`** (and firmware is applied as part of the build step). There is no longer a separate end-to-end orchestrator command to test in isolation — the orchestrator entry point is `Start-AutomationOrchestrator`, covered by its own test file.

**Why this matters**

This is "the build ran and everything agreed to proceed". If the authorization gate or guard-rail is not enforced, the automation could wipe or reinstall the wrong server. These tests are the human-interlock and safety-regex checks that make a production build safe.

**Criticality:** CRITICAL. The build command is the only path to a destructive deploy; a regression in its guard-rail or approval gate is the highest risk in the suite.

<a id="6-mounting-the-iso-and-forcing-boot-invoke-iloredfish"></a>

### 6. Mounting the ISO and forcing boot – `Invoke-IloRedfish`

**Test file:** `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1`
**Runbook step:** *Mount ISO via HPE iLO and force one-time boot* and the Redfish operations in section 10.5

**What it tests, in plain language**

This is the function that physically tells the server to boot from the ISO. The tests check that:

- The function exists, and accepts the right inputs (action, iLO IP address, ISO URL, CD device ID, certificate checking, force flag).
- Destructive actions — specifically `MountAndBoot`, which actually reboots the physical server, and `Reset` — are **refused unless the `-Force` flag is passed**. This is a key safety check: the automation must not accidentally reboot a server.
- `Status` and `Eject` are non-destructive and safe to run any time.
- In "dry-run" mode, destructive actions are allowed *without* `-Force`, because nothing real will happen, so operators can rehearse the command safely.
- Unknown actions (for example, a typo in the action name) are rejected.
- The internal `IloRedfishSession` class used to talk to iLO is properly declared in the module.

**Why this matters**

Mounting the ISO and rebooting the server is the single most dangerous operation the automation performs. If it runs on the wrong server, or if it is run without the correct safety flag, the operational impact is immediate. These tests are the guard around that guard.

**Criticality:** CRITICAL. A regression here (for example, `-Force` no longer being required) would remove the safety interlock on a destructive operation.

<a id="7-post-build-checks-test-postbuildvalidation"></a>

### 7. Post-build checks – `Test-PostBuildValidation`

**Test file:** `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1`
**Runbook step:** *Validation Checklist – Post-build validation*

**What it tests, in plain language**

After the build finishes, the automation verifies that the server is healthy: correct hostname, correct domain, correct OS version, and that the ConfigMgr client is reporting. The tests check that:

- The function is available, and accepts hostname, expected hostname, expected domain, expected OS version, and "skip remote checks" / "skip CM client" / "skip drivers" flags.
- With remote checks skipped (the safe testing mode), it returns success and reports the skips explicitly.
- When run against a non-existent host, the function degrades gracefully rather than throwing an unhandled error.

**Why this matters**

This is the "did we actually succeed?" check. A server that appears to have built, but has not joined the domain, does not have the right OS version, or whose ConfigMgr client is not reporting, is not a finished build. If the post-build validation function does not work, these problems will be discovered by users, not by the automation, which is exactly the failure mode the runbook exists to prevent.

**Criticality:** HIGH. A failure here means the build is being signed off without evidence that it actually finished correctly.

<a id="8-monitoring-the-install-start-installmonitor"></a>

### 8. Monitoring the install – `Start-InstallMonitor`

**Test file:** `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1`
**Runbook step:** *Task sequence execution* (runbook section 10.6)

**What it tests, in plain language**

While Windows Server is being installed, the automation can be asked to watch the progress and time out if the install stalls. The tests check that:

- The monitoring function is available and accepts a server name (or serial number + OneView host), a timeout in seconds, and a poll interval.
- Unknown parameters are rejected, so a caller cannot accidentally invoke the function with the wrong inputs.
- It is read-only — it only observes progress; it never reboots, mounts, or changes the server.

**Why this matters**

Monitoring is what separates an attended build from a fire-and-forget one. If the monitor does not work, a stalled install will sit indefinitely, or the automation will report success without knowing the install finished. These tests are comparatively light because monitoring is hard to unit-test, but they still block release of a module where the entry point itself is missing.

**Criticality:** MEDIUM. A failure here means the monitoring command is not available, but the build itself may still work; the risk is operational visibility rather than build correctness.

<a id="9-windows-security-updates-iso-patching-invoke-windowssecurityupdate"></a>

### 9. Windows security updates (ISO patching) – `Invoke-WindowsSecurityUpdate`

**Test file:** `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1`
**Runbook step:** Post-build security baseline, part of the *Post-build validation* objectives

**What it tests, in plain language**

This function injects Windows security patches into a **base ISO file** (offline servicing) so the server ships already patched. Note it writes a file on disk — it does **not** touch a live server. The tests confirm that:

- The function is available, takes a base ISO path and a server name (or serial + OneView host for output naming), and accepts `DryRun`.
- The patching method (`dism` or `powershell`) is accepted.
- Unknown parameters are rejected.

**Why this matters**

A server that builds cleanly but ships without current security patches fails the security baseline defined in the runbook. If this function does not exist or does not accept the inputs the build expects, the security baseline cannot be enforced by automation.

**Criticality:** MEDIUM. Security patching is a policy control as much as a technical one. A failure here does not stop the build, but it does mean the change request is shipping a server that does not meet the required patch level.

<a id="test-criticality-at-a-glance"></a>

## Test criticality at a glance

| Test file | Stage | Criticality | Blocks a production change if failing? |
| --- | --- | --- | --- |
| `Connect-OneView` / `Test-ServerConnectivity` | Connection & session lifecycle | CRITICAL | Yes |
| `Get-OneViewServerTarget` | Server identification | CRITICAL | Yes |
| `Configure-PhysicalBuild` | The build (4-eye review + deploy) | CRITICAL | Yes |
| `Invoke-IloRedfish` | Mount ISO and force boot | CRITICAL | Yes |
| `Test-BuildParams` | ISO / build-path validation | HIGH | Yes |
| `Test-PreBuildValidation` | Pre-build checks | HIGH | Yes |
| `Test-PostBuildValidation` | Post-build checks | HIGH | Yes |
| `Start-InstallMonitor` | Install monitoring | MEDIUM | Recommended |
| `Invoke-WindowsSecurityUpdate` | Windows security patches | MEDIUM | Recommended |

As a rule of thumb for **CAB approvers**: any red result in the **CRITICAL** or **HIGH** rows should be treated as a blocker for the change. **MEDIUM** results should be understood and accepted explicitly before approval.

<a id="what-a-failed-test-means-for-a-change-request"></a>

## What a failed test means for a change request

In plain terms:

- If the test suite is **green** (all tests passed), the automation has been verified to behave as expected in each of the areas listed above. It is safe to include in the change request as evidence.
- If the test suite is **red** (any test failed), something the runbook depends on is not behaving as specified. **Do not approve the change** without a root-cause explanation from the engineering team and evidence that the failing test has been fixed.
- If the test suite has **skips** but no failures, the suite ran and passed the tests it was able to run. Skips are expected in some test environments and are not a blocker in themselves, but they should be noted in the change record.

The test log in `generated/logs/automation/automated-mode-test_<timestamp>.log` provides the evidence that can be attached to the change record.

<a id="running-the-test-suite"></a>

## Running the test suite

The suite is run by the operations or engineering team using:

```
pwsh -File scripts/run-automation-mode-tests.ps1
```

The command:

- Loads the automation module.
- Runs every `tests/powershell/*.Tests.ps1` file through the Pester test framework.
- Prints a summary block showing total, passed, failed, skipped, and duration.
- Exits with code 1 if any test failed.

Process and CAB members do not need to run the suite themselves; they need to see a green result and a log file attached to the change record.

<a id="glossary-for-non-technical-readers"></a>

## Glossary for non-technical readers

| Term | Plain-language meaning |
| --- | --- |
| Unit test | A small, automated check that proves a single piece of the automation works correctly. |
| Pester | The testing framework used by the team — equivalent to a harness that runs the checks and records the results. |
| Dry-run | A mode where the automation says what it *would* do, but does not actually do it. Safe to run anywhere. |
| Mock | A pre-prepared answer given to the automation so it can be tested without needing the real hardware or services. |
| Guard-rail (`-GuardRail`) | A mandatory safety check: the server name the automation resolved must match a pattern you supply, otherwise the destructive build is refused. |
| Bootable ISO | The boot disk image that Configuration Manager produces, which is mounted on the server's virtual CD drive to start the build. |
| iLO | HP's "out-of-band" management interface — what lets the automation control the physical server remotely. |
| Redfish | The language iLO speaks. The automation uses Redfish to mount ISOs and set boot order. |
| OneView | HPE's central management system; the source of truth for which HPE servers exist and what state they are in. |
| ConfigMgr / MECM | Microsoft Configuration Manager — the tool that owns the task sequence and deployment content. |
| Orchestration | Running the stages of the build in the correct order, with the correct inputs. |
| Audit file | A record that says "this build was attempted on this server at this time with this ISO". |

<a id="related-documents"></a>

## Related documents

- [Runbook: automating the build of physical HPE servers](./runbook-requirements.md#top) — the process this test suite protects.
- [Automation test plan](./AUTOMATION_TEST_PLAN.md#top) — the engineer-facing, followable test plan (connection-first ordering, full parameter matrices, highlighted destructive section).
- [HPE OneView commands](./HPE_OpenView_Commands.md#top) — the quick-reference of the public command surface.
- [Code map of the automations](./Code_Map_Automations.md#top) — the engineering-level map of the same functions.
