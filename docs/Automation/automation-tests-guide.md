# Automation test guide for process teams and change approvers

<a id="top"></a>
## Table of Contents

- [Purpose of this document](#purpose-of-this-document)
- [Who this is for](#who-this-is-for)
- [What the test suite does](#what-the-test-suite-does)
- [How to read the test results](#how-to-read-the-test-results)
- [Tests by runbook stage](#tests-by-runbook-stage)
  - [1. ISO creation – `New-IsoBuild`](#1-iso-creation--new-isobuild)
  - [2. Publishing the boot ISO – `Publish-BootIso`](#2-publishing-the-boot-iso--publish-bootiso)
  - [3. Identifying the target server – `Get-OneViewServerTarget`](#3-identifying-the-target-server--get-oneviewservertarget)
  - [4. Mounting the ISO and forcing boot – `Invoke-IloRedfish`](#4-mounting-the-iso-and-forcing-boot--invoke-iloredfish)
  - [5. Pre-build checks – `Test-PreBuildValidation`](#5-pre-build-checks--test-prebuildvalidation)
  - [6. Post-build checks – `Test-PostBuildValidation`](#6-post-build-checks--test-postbuildvalidation)
  - [7. Monitoring the install – `Start-InstallMonitor`](#7-monitoring-the-install--start-installmonitor)
  - [8. End-to-end orchestration – `Start-PhysicalServerBuild`](#8-end-to-end-orchestration--start-physicalserverbuild)
  - [9. Deploy command layer – `Invoke-IsoDeploy`](#9-deploy-command-layer--invoke-isodeploy)
  - [10. Firmware updates – `Update-Firmware`](#10-firmware-updates--update-firmware)
  - [11. Windows security updates – `Invoke-WindowsSecurityUpdate`](#11-windows-security-updates--invoke-windowssecurityupdate)
- [Test criticality at a glance](#test-criticality-at-a-glance)
- [What a failed test means for a change request](#what-a-failed-test-means-for-a-change-request)
- [Running the test suite](#running-the-test-suite)
- [Glossary for non-technical readers](#glossary-for-non-technical-readers)
- [Related documents](#related-documents)


<a name="purpose-of-this-document"></a>
## Purpose of this document

This guide explains what the automation test suite for the HPE physical server build process actually does. It is written for:

- **Process team members** who need to understand how the automation is validated before it runs against real servers.
- **Change advisory board (CAB) members and approvers** who need confidence that the automation behaves correctly before a production change is approved.
- **Service desk and operations staff** who may need to interpret a test result and escalate if necessary.

It is intentionally written without requiring scripting or development knowledge.

The companion technical document is the runbook at [docs/Automation/runbook-requirements.md](./runbook-requirements.md). This guide explains the tests; the runbook explains the process the tests are protecting.


<a name="who-this-is-for"></a>
## Who this is for

| Role | What this document helps you do |
| --- | --- |
| Process team member | Understand which stages of the build are covered by automated checks before each release. |
| CAB / change approver | Judge whether the automation is sufficiently tested before approving a production build. |
| Operations / service desk | Interpret a test failure and decide whether it blocks a build or is informational. |
| Auditor | Show that the automation has repeatable, documented quality checks. |

If you need to run or debug the tests, speak to an engineer in the Server Engineering team. This document is for understanding, not operating.


<a name="what-the-test-suite-does"></a>
## What the test suite does

The file `scripts/run-automation-mode-tests.ps1` runs a collection of **automated checks** (called "unit tests" in the industry) that prove the automation behaves as expected. You can think of them as a series of "what would happen if..." simulations covering every stage of the runbook, from creating the boot ISO to checking the server after the build has finished.

Key properties of the suite:

- It **does not touch real servers, real iLO interfaces, or real Configuration Manager sites**. It uses safe "dry-run" and "mock" modes so a failed test cannot damage hardware or cause a real outage.
- It **exits with a failure code if any test fails**, which blocks automated pipelines. A failing test should be treated as a stop/go decision gate for any change request.
- It **produces a log file** in `generated/logs/<environment>/` so the result can be attached to a change record as evidence.
- It **covers 11 test files**, one per major function, each representing a distinct stage of the runbook.

In short: the test suite is the quality gate the runbook is sitting behind. Approving a change when the suite is red means accepting risk. Approving it when green means the automation has been validated against its own specification.


<a name="how-to-read-the-test-results"></a>
## How to read the test results

When the suite runs, it produces a summary block like this:

```
Total Tests    : <number>
Passed         : <number>  ✔
Failed         : <number>  ✔  or  ✘ (CRITICAL)
Skipped        : <number>
Duration       : <seconds>s
```

How to interpret it:

- **Passed** means the automation behaved exactly as the runbook expects for that step. For example, it correctly created an ISO, or refused to operate without a password.
- **Failed** means the automation either behaved unexpectedly or could not complete the step. A single failure flags the whole suite as red. Treat any failure as a stop: do not approve a production change on a red result.
- **Skipped** means a test intentionally did not run, usually because the environment does not support it (for example, a test that needs a live WinRM connection being skipped in a lab without Windows hosts). Skips are not failures.
- **Duration** is how long the suite took. A sudden increase in duration can itself be a warning sign (for example, network timeouts).


<a name="tests-by-runbook-stage"></a>
## Tests by runbook stage

Each test file maps to one stage of the runbook at [docs/Automation/runbook-requirements.md](./runbook-requirements.md). They are listed below in the order the build actually happens.


<a name="1-iso-creation--new-isobuild"></a>
### 1. ISO creation – `New-IsoBuild`

**Test file:** `tests/powershell/New-IsoBuild.Unit.Tests.ps1`
**Runbook step:** *Prepare or update the Windows Server build in Configuration Manager* and *Create bootable media ISO*

**What it tests, in plain language**

The automation must be able to create the bootable Windows Server ISO from Configuration Manager, with the correct site code, management point, distribution point and password, and it must name the file according to the publishing standard (for example `WinSrv2025_HPE_BootableMedia_v1.7.iso`).

The tests check that:

- The create-ISO function is available and accepts the right inputs (site code, distribution point, boot image name, etc.).
- When run in "dry-run" mode, the function returns success and a correctly named file path without actually creating anything.
- When run with a mock ISO source, the function copies the file and writes a deployment metadata record.

**Why this matters**

The bootable ISO is the starting point of the entire build. If the ISO is not created correctly — wrong name, wrong content, no metadata — nothing downstream will work. This test protects against releasing automation that generates invalid or untraceable ISOs.

**Criticality:** HIGH. A failing test here means the ISO cannot be trusted to exist in the right place, with the right name, or with the right audit record.


<a name="2-publishing-the-boot-iso--publish-bootiso"></a>
### 2. Publishing the boot ISO – `Publish-BootIso`

**Test file:** `tests/powershell/Publish-BootIso.Unit.Tests.ps1`
**Runbook step:** *Publish the ISO for iLO consumption*

**What it tests, in plain language**

Once an ISO exists, it must be published to the secured repository that iLO virtual media will read from. The tests verify that:

- The publish function is available and takes the right inputs (local ISO path, repository URL, verification flag).
- If the ISO file does not exist, the function fails cleanly with a "not found" error, rather than silently continuing.
- If no repository URL is provided (and none is configured in the environment), the function refuses to continue, rather than copying the ISO to an unknown location.
- In "dry-run" mode, the function reports what it *would* do without copying anything.

**Why this matters**

Publishing is the hand-off between the Configuration Manager side and the iLO side. If an ISO is published to the wrong place, or if the publish step silently accepts a missing file, iLO will mount nothing and the server will not boot. This test protects the boundary between the two systems.

**Criticality:** HIGH. A failure here means the ISO may not be reachable by iLO when the build starts.


<a name="3-identifying-the-target-server--get-oneviewservertarget"></a>
### 3. Identifying the target server – `Get-OneViewServerTarget`

**Test file:** `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1`
**Runbook step:** *Identify and validate the target server in HPE OneView* (and runbook step 10.4)

**What it tests, in plain language**

Before anything touches a server, the automation must correctly identify *which* server it is building. The tests check that:

- The lookup function is available and accepts server name, serial number, identifier type, OneView host, and a mock result for offline testing.
- With a provided mock result, the function returns the correct server and serial number without making any network call.
- If no OneView host is configured (and it is running in automated mode), the function fails cleanly rather than guessing.
- An unknown identifier type (for example, someone passing "Bogus" instead of "SerialNumber" or "Name") is rejected.

**Why this matters**

This is the "right server, right build" check. Getting it wrong is the highest-severity incident the runbook describes: building the wrong server. The tests cannot cover every failure mode of a live OneView query, but they do confirm that the function refuses to proceed when its input is malformed or missing, which is the most important behaviour.

**Criticality:** CRITICAL. A failure here, or a regression that allowed this function to silently accept bad input, would risk a wrong-server build.


<a name="4-mounting-the-iso-and-forcing-boot--invoke-iloredfish"></a>
### 4. Mounting the ISO and forcing boot – `Invoke-IloRedfish`

**Test file:** `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1`
**Runbook step:** *Mount ISO via HPE iLO and force one-time boot* and the Redfish operations in section 10.5

**What it tests, in plain language**

This is the function that physically tells the server to boot from the ISO. The tests check that:

- The function exists, and accepts the right inputs (action, iLO IP address, ISO URL, CD device ID, certificate checking, force flag).
- Destructive actions — specifically `MountAndBoot`, which actually reboots the physical server — are **refused unless the `-Force` flag is passed**. This is a key safety check: the automation must not accidentally reboot a server.
- In "dry-run" mode, destructive actions are allowed *without* `-Force`, because nothing real will happen, so operators can rehearse the command safely.
- Unknown actions (for example, a typo in the action name) are rejected.
- The internal `IloRedfishSession` class used to talk to iLO is properly declared in the module.

**Why this matters**

Mounting the ISO and rebooting the server is the single most dangerous operation the automation performs. If it runs on the wrong server, or if it is run without the correct safety flag, the operational impact is immediate. These tests are the guard around that guard.

**Criticality:** CRITICAL. A regression here (for example, `-Force` no longer being required) would remove the safety interlock on a destructive operation.


<a name="5-pre-build-checks--test-prebuildvalidation"></a>
### 5. Pre-build checks – `Test-PreBuildValidation`

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


<a name="6-post-build-checks--test-postbuildvalidation"></a>
### 6. Post-build checks – `Test-PostBuildValidation`

**Test file:** `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1`
**Runbook step:** *Validation Checklist – Post-build validation*

**What it tests, in plain language**

After the build finishes, the automation verifies that the server is healthy: correct hostname, correct domain, correct OS version, and that the ConfigMgr client is reporting. The tests check that:

- The function is available, and accepts hostname, expected hostname, expected domain, expected OS version, and a "skip remote checks" flag.
- With remote checks skipped (the safe testing mode), it returns success and reports the skips explicitly.
- When run against a non-existent host, the function degrades gracefully rather than throwing an unhandled error.

**Why this matters**

This is the "did we actually succeed?" check. A server that appears to have built, but has not joined the domain, does not have the right OS version, or whose ConfigMgr client is not reporting, is not a finished build. If the post-build validation function does not work, these problems will be discovered by users, not by the automation, which is exactly the failure mode the runbook exists to prevent.

**Criticality:** HIGH. A failure here means the build is being signed off without evidence that it actually finished correctly.


<a name="7-monitoring-the-install--start-installmonitor"></a>
### 7. Monitoring the install – `Start-InstallMonitor`

**Test file:** `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1`
**Runbook step:** *Task sequence execution* (runbook section 10.6)

**What it tests, in plain language**

While Windows Server is being installed, the automation can be asked to watch the progress and time out if the install stalls. The tests check that:

- The monitoring function is available and accepts a server name and a timeout in seconds.
- Unknown parameters are rejected, so a caller cannot accidentally invoke the function with the wrong inputs.

**Why this matters**

Monitoring is what separates an attended build from a fire-and-forget one. If the monitor does not work, a stalled install will sit indefinitely, or the automation will report success without knowing the install finished. These tests are comparatively light because monitoring is hard to unit-test, but they still block release of a module where the entry point itself is missing.

**Criticality:** MEDIUM. A failure here means the monitoring command is not available, but the build itself may still work; the risk is operational visibility rather than build correctness.


<a name="8-end-to-end-orchestration--start-physicalserverbuild"></a>
### 8. End-to-end orchestration – `Start-PhysicalServerBuild`

**Test file:** `tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1`
**Runbook step:** The complete Standard Operating Procedure

**What it tests, in plain language**

`Start-PhysicalServerBuild` is the wrapper that runs the whole build in order: pre-checks, ISO creation, publishing, OneView lookup, mount and boot, monitoring, post-checks. The tests verify that:

- The orchestrator is available, and accepts identifiers for the server, OneView host, iLO address, site code, management point, distribution point, and repository URL.
- When every individual stage is skipped (the "everything dry-run" mode the test uses), the orchestrator still returns a success result with a server name and an audit file path.

**Why this matters**

This is "the build ran and everything agreed to proceed". If the orchestrator does not return a clean, structured result with an audit reference, no downstream system — logging, reporting, the change record — has evidence the build happened. These tests are the lightest possible proof that the orchestration contract is intact; a failure here is a major red flag.

**Criticality:** CRITICAL. The orchestrator is the single entry point operators and pipelines use. If it does not behave, the whole process is unreliable.


<a name="9-deploy-command-layer--invoke-isodeploy"></a>
### 9. Deploy command layer – `Invoke-IsoDeploy`

**Test file:** `tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1`
**Runbook step:** The combined ISO-mount-and-deploy action referenced from the orchestrator

**What it tests, in plain language**

`Invoke-IsoDeploy` is the inner command that handles the actual act of deploying the ISO to a server. The tests confirm that:

- The function is available and accepts the `DryRun` switch without throwing.
- Unknown parameters are rejected.

**Why this matters**

This is a supporting layer. It exists to keep the orchestrator clean and the deploy step testable in isolation. A failure here tends to be a sign that the interface has changed without the orchestrator being updated.

**Criticality:** MEDIUM. Failures here usually surface as orchestrator failures, but if they do not, a deploy command silently behaving differently from expectation is a real risk.


<a name="10-firmware-updates--update-firmware"></a>
### 10. Firmware updates – `Update-Firmware`

**Test file:** `tests/powershell/Update-Firmware.Unit.Tests.ps1`
**Runbook step:** Out-of-band, referenced from the runbook's assumptions about HPE hardware health

**What it tests, in plain language**

`Update-Firmware` applies HPE server firmware as part of, or alongside, the build. The tests confirm that:

- The function is available and accepts `DryRun`.
- Unknown parameters are rejected.

**Why this matters**

Firmware on HPE servers must be at a known baseline. If the automation that applies firmware is not available, the build may ship a server with outdated or mismatched firmware, which causes subtle stability problems later. The tests are light because firmware is hardware-specific, but they still assert the entry point exists and is well-formed.

**Criticality:** MEDIUM. A failure here means firmware updates cannot be invoked by the automation; servers may still build, but the firmware baseline is no longer guaranteed.


<a name="11-windows-security-updates--invoke-windowssecurityupdate"></a>
### 11. Windows security updates – `Invoke-WindowsSecurityUpdate`

**Test file:** `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1`
**Runbook step:** Post-build security baseline, part of the *Post-build validation* objectives

**What it tests, in plain language**

This function applies Windows security patches into the build, so that the server ships already patched. The tests confirm that:

- The function is available, takes an ISO path and a server name, and accepts `DryRun`.
- Unknown parameters are rejected.

**Why this matters**

A server that builds cleanly but ships without current security patches fails the security baseline defined in the runbook. If this function does not exist or does not accept the inputs the orchestrator expects, the security baseline cannot be enforced by automation.

**Criticality:** MEDIUM. Security patching is a policy control as much as a technical one. A failure here does not stop the build, but it does mean the change request is shipping a server that does not meet the required patch level.


<a name="test-criticality-at-a-glance"></a>
## Test criticality at a glance

| Test file | Stage | Criticality | Blocks a production change if failing? |
| --- | --- | --- | --- |
| `Get-OneViewServerTarget` | Server identification | CRITICAL | Yes |
| `Invoke-IloRedfish` | Mount ISO and force boot | CRITICAL | Yes |
| `Start-PhysicalServerBuild` | End-to-end orchestration | CRITICAL | Yes |
| `New-IsoBuild` | ISO creation | HIGH | Yes |
| `Publish-BootIso` | ISO publishing | HIGH | Yes |
| `Test-PreBuildValidation` | Pre-build checks | HIGH | Yes |
| `Test-PostBuildValidation` | Post-build checks | HIGH | Yes |
| `Start-InstallMonitor` | Install monitoring | MEDIUM | Recommended |
| `Invoke-IsoDeploy` | Deploy command | MEDIUM | Recommended |
| `Update-Firmware` | Firmware updates | MEDIUM | Recommended |
| `Update-WindowsSecurity` | Windows security patches | MEDIUM | Recommended |

As a rule of thumb for **CAB approvers**: any red result in the **CRITICAL** or **HIGH** rows should be treated as a blocker for the change. **MEDIUM** results should be understood and accepted explicitly before approval.


<a name="what-a-failed-test-means-for-a-change-request"></a>
## What a failed test means for a change request

In plain terms:

- If the test suite is **green** (all tests passed), the automation has been verified to behave as expected in each of the areas listed above. It is safe to include in the change request as evidence.
- If the test suite is **red** (any test failed), something the runbook depends on is not behaving as specified. **Do not approve the change** without a root-cause explanation from the engineering team and evidence that the failing test has been fixed.
- If the test suite has **skips** but no failures, the suite ran and passed the tests it was able to run. Skips are expected in some test environments and are not a blocker in themselves, but they should be noted in the change record.

The test log in `generated/logs/<environment>/automation_mode_tests_<timestamp>.log` provides the evidence that can be attached to the change record.


<a name="running-the-test-suite"></a>
## Running the test suite

The suite is run by the operations or engineering team using:

```
pwsh -File scripts/run-automation-mode-tests.ps1
```

The command:

- Loads the automation module.
- Runs all 11 test files through the Pester test framework.
- Prints a summary block showing total, passed, failed, skipped, and duration.
- Exits with code 1 if any test failed.

Process and CAB members do not need to run the suite themselves; they need to see a green result and a log file attached to the change record.


<a name="glossary-for-non-technical-readers"></a>
## Glossary for non-technical readers

| Term | Plain-language meaning |
| --- | --- |
| Unit test | A small, automated check that proves a single piece of the automation works correctly. |
| Pester | The testing framework used by the team — equivalent to a harness that runs the checks and records the results. |
| Dry-run | A mode where the automation says what it *would* do, but does not actually do it. Safe to run anywhere. |
| Mock | A pre-prepared answer given to the automation so it can be tested without needing the real hardware or services. |
| Bootable ISO | The boot disk image that Configuration Manager produces, which is mounted on the server's virtual CD drive to start the build. |
| iLO | HP's "out-of-band" management interface — what lets the automation control the physical server remotely. |
| Redfish | The language iLO speaks. The automation uses Redfish to mount ISOs and set boot order. |
| OneView | HPE's central management system; the source of truth for which HPE servers exist and what state they are in. |
| ConfigMgr / MECM | Microsoft Configuration Manager — the tool that owns the task sequence and deployment content. |
| Orchestration | Running the stages of the build in the correct order, with the correct inputs. |
| Audit file | A record that says "this build was attempted on this server at this time with this ISO". |


<a name="related-documents"></a>
## Related documents

- [Runbook: automating the build of physical HPE servers](./runbook-requirements.md) — the process this test suite protects.
- [Code map of the automations](./Code_Map_Automations.md) — the engineering-level map of the same functions.
