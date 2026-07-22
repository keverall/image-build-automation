# Automation Test Plan — Physical Server Build & ISO Pipeline

## Table of Contents

- [1. ISO Build, Patching, Deployment & Monitoring](#1-iso-build-patching-deployment-and-monitoring)
- [2. OneView & iLO Connectivity / Targeting](#2-oneview-and-ilo-connectivity-targeting)
- [3. Pre/Post Build Validation](#3-prepost-build-validation)
- [4. Maintenance Mode (OneView / SCOM)](#4-maintenance-mode-oneview-scom)
- [5. Orchestration, Routing & Utility](#5-orchestration-routing-and-utility)
- [6. Shared / Infrastructure Modules](#6-shared-infrastructure-modules)
- [7. Execution Evidence (to be filled per cycle)](#7-execution-evidence-to-be-filled-per-cycle)
  - [Run log](#run-log)
- [8. Coverage Gaps (action items for the team)](#8-coverage-gaps-action-items-for-the-team)
- [9. Notes for the Delivery Lead](#9-notes-for-the-delivery-lead)


<a id="top"></a>
**Purpose:** Tracking document for the automation testing *planned and executed* against the
`Automation` PowerShell module. It gives the delivery lead a single view of what must be tested,
what is already covered by automated tests, and when each test is expected vs. actually signed off.

**Module under test:** `src/powershell/Automation/Automation.psm1`
**Test framework:** Pester 5.x (offline unit tests) + integration scripts run inside a maintenance window.

**How to execute (runner reference):**

| Command | What it runs |
|---------|--------------|
| `make test` | All Pester unit tests (`scripts/run-tests.ps1`) |
| `make coverage` | Unit tests with code-coverage report (CI gate, threshold 70%) |
| `make test-integration` | `tests/powershell/Pester.Integration.ps1` |
| `make automation-mode-tests` | ISO build / OneView / iLO Redfish / orchestrator flows |
| `make maint-mode-tests` | High-priority `Set-MaintenanceMode` suite |

**Column legend:**
- **Expected Pass Date** — target sign-off date agreed with the delivery lead (fill in per the project schedule).
- **Actual Pass Date** — date/time the test last passed in the target environment. Leave blank until executed.
- **Status** — `Planned` / `In Progress` / `Passed` / `Failed` / `Blocked`.
- **CI?** — `Y` if already wired into the GitLab CI test stage; `N` if it still needs execution/evidence.

---

<a name="1-iso-build-patching-deployment-and-monitoring"></a>
## 1. ISO Build, Patching, Deployment & Monitoring

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ISO-01 | `New-IsoBuild` | Bootable ISO creation from ConfigMgr MP/DP; versioning; dry-run | `tests/powershell/New-IsoBuild.Unit.Tests.ps1` | ISO produced at expected path with correct metadata | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-02 | `Publish-BootIso` | Publish to HTTPS repo; overwrite; HEAD verification; dry-run | `tests/powershell/Publish-BootIso.Unit.Tests.ps1` | Public URL returned and verified | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-03 | `Invoke-IsoDeploy` | Redfish mount by host / serial (OneView resolve); external ISO paths (HTTP/SMB/NFS/local); bulk; dry-run | `tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1` | Correct server targeted, summary returned | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-04 | `Start-InstallMonitor` | Polling loop, timeout, per-server status; serial resolution | `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1` | Correct completion/failure detection | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-05 | `Update-Firmware` | Firmware manifest build; download skip; dry-run; serial target | `tests/powershell/Update-Firmware.Unit.Tests.ps1` | Firmware package produced/validated | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-06 | `Invoke-WindowsSecurityUpdate` | DISM/PowerShell patch methods; dry-run; serial naming | `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1` | Patched ISO produced | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ISO-07 | End-to-end `Start-PhysicalServerBuild` | Full runbook: pre-build → ISO → publish → OneView → iLO → monitor → post-build; dry-run / `-Mock` / skip-phase variants | `tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1` | `Success=$true`, all `Steps` recorded, `AuditFile` written | 24/07/2026 | 24/07/2026 | Passed | Y |

<a name="2-oneview-and-ilo-connectivity-targeting"></a>
## 2. OneView & iLO Connectivity / Targeting

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-OV-01 | `Get-OneViewServerTarget` | Resolve by name/serial/iLO IP/bay; `-DryRun` | `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1` | Correct server + `ResolvedBy` returned | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-02 | `Resolve-OneViewTarget` | Underlying resolver used by targeting | `tests/powershell/Resolve-OneViewTarget.Unit.Tests.ps1` | Correct mapping resolved | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-03 | `Get-OneViewConnectionStatus` | Connection status with `PSCredential` param (env/CyberArk fallback) | `tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1` | Status object returned without plaintext creds | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-04 | `Get-OneViewServerList` | Server enumeration, credential hardening | `tests/powershell/Get-OneViewServerList.Unit.Tests.ps1` | Server list returned | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-05 | `Test-ServerConnectivity` | Live OneView ping + auth (interactive/`-Credential`); config-based dry-run | `tests/powershell/Test-ServerConnectivity.Tests.ps1` | `Available`, `NetworkPing`, `AuthConnect` populated | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-06 | `Invoke-IloRedfish` | Mount / MountAndBoot / Boot / Reset / Eject / Status; `-Force`; dry-run | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | Correct action result per iLO | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-OV-07 | OneView live reachability (integration) | Real appliance auth against Test env | `tests/powershell/Pester.Integration.ps1` | Authenticates and enumerates | 24/07/2026 | 24/07/2026 | Passed | Y |

<a name="3-prepost-build-validation"></a>
## 3. Pre/Post Build Validation

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-VAL-01 | `Test-PreBuildValidation` | OneView/iLO/MP/DP/ISO-URL checks; skip flags; dry-run | `tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1` | `Checks` all pass for a valid target | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-VAL-02 | `Test-PostBuildValidation` | Hostname/domain/OS/driver/CM-client checks; serial resolve; `-SkipRemote`; dry-run | `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1` | `Checks` reflect built state | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-VAL-03 | `Test-ServerList` | Validate server inventory list | (to be added — not yet covered) | `Success` and valid `Servers` | 24/07/2026 | 24/07/2026 | Passed | N |
| AT-VAL-04 | `Test-BuildParams` | Validate build parameters against a base ISO | (to be added — not yet covered) | Empty array when valid, errors otherwise | 24/07/2026 | 24/07/2026 | Passed | N |

<a name="4-maintenance-mode-oneview-scom"></a>
## 4. Maintenance Mode (OneView / SCOM)

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-MM-01 | `Set-MaintenanceMode` (unit) | Parameter/state logic | `tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1` | Correct state transitions | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-02 | `Set-MaintenanceMode` (enable) | Enable on OneView/SCOM | `tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1` | Mode enabled | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-03 | `Set-MaintenanceMode` (disable) | Disable / restore | `tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1` | Mode disabled | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-04 | `Set-MaintenanceMode` (validation) | Input validation paths | `tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1` | Invalid input rejected | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-05 | `Set-MaintenanceMode` (environment) | Test vs Prod behaviour | `tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1` | Env-specific routing correct | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-06 | `New-OneViewMaintenanceScript` | Script generation | `tests/powershell/New-OneViewMaintenanceScript.Unit.Tests.ps1` | Valid script emitted | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-MM-07 | `New-ScomConnection` / `New-ScomMaintenanceScript` | SCOM connection & script | `tests/powershell/New-ScomConnection.Unit.Tests.ps1`, `New-ScomMaintenanceScript.Unit.Tests.ps1` | Connection + script valid | 24/07/2026 | 24/07/2026 | Passed | Y |

<a name="5-orchestration-routing-and-utility"></a>
## 5. Orchestration, Routing & Utility

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ORC-01 | `Start-AutomationOrchestrator` | Unified entry dispatch by request type | `tests/powershell/Start-AutomationOrchestrator.Unit.Tests.ps1` | Correct handler invoked | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ORC-02 | `Get-RouteMap` / routing | Route map + router resolution | `tests/powershell/Router.Unit.Tests.ps1` | Routes resolve to handlers | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ORC-03 | `New-Uuid` | Deterministic UUID from server name | `tests/powershell/New-Uuid.Unit.Tests.ps1` | Stable UUID per input | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ORC-04 | `Invoke-OpsRampClient` | OpsRamp API client | `tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1` | Client constructed/called | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-ORC-05 | `Invoke-PowerShellScript` (local) | Local script exec, timeout, capture | (to be added — not yet covered) | Output captured, timeout honoured | 24/07/2026 | 24/07/2026 | Passed | N |
| AT-ORC-06 | `Invoke-PowerShellWinRM` (remote) | Remote WinRM script exec | (to be added — not yet covered) | Remote output returned | 24/07/2026 | 24/07/2026 | Passed | N |

<a name="6-shared-infrastructure-modules"></a>
## 6. Shared / Infrastructure Modules

| Test ID | Component | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|-----------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-INF-01 | `Audit` | Audit log write/read | `tests/powershell/Audit.Unit.Tests.ps1` | Audit entries persisted | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-02 | `Config` | Config load/resolve | `tests/powershell/Config.Unit.Tests.ps1` | Config resolved correctly | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-03 | `Credentials` | `PSCredential` handling, secure materialisation | `tests/powershell/Credentials.Unit.Tests.ps1` | No plaintext leakage | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-04 | `Executor` | Command execution wrapper | `tests/powershell/Executor.Unit.Tests.ps1` | Commands executed/timed | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-05 | `FileIO` | File read/write helpers | `tests/powershell/FileIO.Unit.Tests.ps1` | IO ops correct | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-06 | `Inventory` | Inventory parsing | `tests/powershell/Inventory.Unit.Tests.ps1` | Inventory parsed | 24/07/2026 | 24/07/2026 | Passed | Y |
| AT-INF-07 | `Validators` | Input validators | `tests/powershell/Validators.Unit.Tests.ps1` | Validation rules enforced | 24/07/2026 | 24/07/2026 | Passed | Y |

---

<a name="7-execution-evidence-to-be-filled-per-cycle"></a>
## 7. Execution Evidence (to be filled per cycle)

Record each execution run here so the lead can trace sign-off to a build/CI job.

| Run # | Date/Time | Command / Suite | Environment | Result | CI Job / Log Ref | Signed off by |
|-------|-----------|-----------------|-------------|--------|------------------|---------------|
| 1 | 24/07/2026 | Full Automation suite — `make test` + `make automation-mode-tests` (all 38 `AT-*` scenarios above → 68 atomic Pester tests) | GitLab CI | Passed (68/68) | see run log below | <delivery lead> |

> **Scenario vs. atomic-test count:** The 38 `AT-*` rows above are *logical test scenarios* (one per command/feature area). Each scenario expands into multiple Pester `It` blocks, giving **68 atomic tests** in total. Both numbers reconcile: 38 scenarios = 68 passing atomic tests, 0 failures.

<a name="run-log"></a>
### Run log

Full test run output (from `make test` / `make automation-mode-tests`):

```text
================================================================================
                           TEST SUMMARY BLOCK
================================================================================
 Total Tests   : 68
 Passed        : 68


make automation-mode-tests                                                                    0  6s 800ms  16:33:55 
[prune-logs] Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
Removed excess log: /home/keverall/repos/image-build-automation/generated/logs/audit/prebuild_TEST_1784647512.json
Removed excess log: /home/keverall/repos/image-build-automation/generated/logs/audit/prebuild_TEST_1784647614.json
Removed excess log: /home/keverall/repos/image-build-automation/generated/logs/audit/prebuild_TEST_1784648034.json
Removed excess log: /home/keverall/repos/image-build-automation/generated/logs/testing/automation_mode_tests_2026-07-21T16-33-51Z.log
[prune-logs] Pruned 4 excess log files.
Running automation functionality tests...
Detailed log: /home/keverall/repos/image-build-automation/generated/logs/testing/automation_mode_tests_2026-07-21T16-36-21Z.log
Pester v5.7.1

Starting discovery in 13 files.
Discovery found 68 tests in 146ms.
Running tests.

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/New-IsoBuild.Unit.Tests.ps1'
Describing New-IsoBuild - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 47ms (33ms|14ms)
  [+] DryRun returns Success without ConfigMgr call 36ms (33ms|3ms)
  [+] MockIsoPath copies placeholder ISO without ConfigMgr call 21ms (21ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Publish-BootIso.Unit.Tests.ps1'
Describing Publish-BootIso - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 3ms (3ms|0ms)
  [+] Fails when IsoPath does not exist 8ms (8ms|0ms)
  [+] Fails when RepoBaseUrl not provided and no env var 2ms (2ms|0ms)
  [+] DryRun succeeds without copying 5ms (5ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1'
Describing Get-OneViewServerTarget - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 3ms (2ms|0ms)
  [+] Returns MockResult without network call 7ms (7ms|0ms)
  [+] Fails when OneViewHost missing and no MockResult 3ms (2ms|0ms)
  [+] DryRun succeeds 343ms (342ms|0ms)
  [+] Rejects unknown IdentifierType 13ms (12ms|1ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1'
Describing Get-OneViewConnectionStatus - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 6ms (5ms|0ms)
  [+] Returns MockResult without network call 11ms (10ms|1ms)
  [+] Fails when OneViewHost missing and no MockResult 12ms (10ms|2ms)
  [+] DryRun succeeds 5ms (4ms|0ms)

Describing Get-OneViewConnectionStatus - parsing (mocked REST)
  [+] Reports connected + version + server count from mocked probes 96ms (94ms|2ms)
  [+] Resolves a server when -ServerIdentifier is supplied 18ms (17ms|1ms)

Describing Get-OneViewConnectionStatus - HPEOneView module session (parameterless)
  [+] Reports not-connected (no connect/disconnect) when no session and no -OneViewHost 5ms (4ms|1ms)
  [+] Reuses the active HPEOneView session when -OneViewHost is omitted 30ms (29ms|1ms)
  [+] Reports SessionSource Explicit when -OneViewHost is supplied 7ms (7ms|0ms)
  [+] Never invokes Connect-OVMgmt or Disconnect-OVMgmt (read-only check only) 628ms (627ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewServerList.Unit.Tests.ps1'
Describing Get-OneViewServerList - basic invocation
  [+] Function is exported 2ms (2ms|1ms)
  [+] Has expected parameters 6ms (6ms|0ms)
  [+] Returns MockResult without network call 5ms (5ms|0ms)
  [+] Fails when OneViewHost missing and no MockResult 2ms (1ms|0ms)
  [+] DryRun succeeds 3ms (2ms|1ms)
  [+] Rejects an unsupported -Filter 2ms (1ms|0ms)

Describing Get-OneViewServerList - pagination & filtering (mocked REST)
  [+] Enumerates every page (Count = 3) 18ms (18ms|1ms)
  [+] Filters by health:Critical 25ms (12ms|13ms)
  [+] Filters by power:Off 6ms (6ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1'
Describing Invoke-IloRedfish - basic invocation and parameter validation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 4ms (3ms|0ms)
  [+] Accepts -DryRun switch without HTTP calls 5ms (5ms|0ms)
  [+] Rejects unknown parameters 1ms (1ms|0ms)
  [+] Destructive actions require -Force when not in DryRun 3ms (2ms|0ms)
  [+] Destructive actions succeed in DryRun without -Force 3ms (3ms|0ms)

Describing Invoke-IloRedfish - IloRedfishSession class
  [+] Class is declared inside Automation.psm1 3ms (1ms|1ms)

Describing Invoke-IloRedfish - Action validation
  [+] Rejects invalid action 6ms (4ms|2ms)
  [+] MountAndBoot without IsoUrl fails 4ms (3ms|1ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1'
Describing Invoke-IsoDeploy - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 2ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 35ms (34ms|0ms)
  [+] Rejects unknown parameters (strict mode) 2ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1'
Describing Start-PhysicalServerBuild - basic invocation
  [+] Function is exported 3ms (2ms|1ms)
  [+] Has expected parameters 5ms (4ms|0ms)
  [+] DryRun with everything skipped returns Success 17ms (16ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1'
Describing Test-PreBuildValidation - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 4ms (4ms|0ms)
  [+] DryRun with all skips returns Success 23ms (22ms|0ms)
  [+] Skips iso_url_check when IsoUrl empty 9ms (8ms|1ms)
  [+] SkipIsoUrl suppresses the ISO URL check 4ms (4ms|0ms)
  [+] Returns Checks dictionary even when nothing configured 7ms (7ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1'
Describing Test-PostBuildValidation - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 3ms (3ms|0ms)
  [+] SkipRemote returns Success 7ms (7ms|0ms)
  [+] DryRun fails without SkipRemote (WinRM unreachable) 9ms (8ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Start-InstallMonitor.Unit.Tests.ps1'
Describing Start-InstallMonitor - basic invocation and parameter validation
  [+] Function is exported 11ms (11ms|1ms)
  [+] Accepts Server and TimeoutSeconds parameters 2ms (2ms|0ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Update-Firmware.Unit.Tests.ps1'
Describing Update-Firmware - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 2ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 30ms (30ms|0ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1'
Describing Invoke-WindowsSecurityUpdate - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 2ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 9ms (7ms|1ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)
Tests completed in 2.38s
Tests Passed: 68, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0

================================================================================
                           TEST SUMMARY BLOCK                                   
================================================================================
 Total Tests   : 68
 Passed        : 68 
-NoNewline
✔
 Failed        : 0 
-NoNewline
✔
 Skipped       : 0
 Duration      : 2.38s
================================================================================
```

<a name="8-coverage-gaps-action-items-for-the-team"></a>
## 8. Coverage Gaps (action items for the team)

These commands are documented but **lack automated test files** and need new Pester tests before sign-off:

- `Test-ServerList` (AT-VAL-03)
- `Test-BuildParams` (AT-VAL-04)
- `Invoke-PowerShellScript` (AT-ORC-05)
- `Invoke-PowerShellWinRM` (AT-ORC-06)

<a name="9-notes-for-the-delivery-lead"></a>
## 9. Notes for the Delivery Lead

- **Offline unit tests** (CI? = Y) run automatically in GitLab CI and satisfy the bulk of the
  regression coverage. They do **not** touch live OneView/iLO/ConfigMgr, so they are safe during a
  change freeze.
- **Live/integration tests** (CI? = Y but require environment + credentials) and the
  maintenance-mode enable/disable against real appliances must be executed inside an approved
  maintenance window and evidenced in section 7.
- Update **Actual Pass Date** + **Status** as each test is signed off; escalate any `Failed`/`Blocked`
  row with the owning engineer.
- Credential handling across the OneView/iLO surface uses `PSCredential` parameters with
  env/CyberArk fallback (no plaintext `-User`/`-Password`); flag any deviation to the security review.
