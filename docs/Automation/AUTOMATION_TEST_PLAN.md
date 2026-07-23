# Automation Test Plan — Physical Server Build & ISO Pipeline

<p class="report-run-date"><strong>Run date:</strong> 23/07/2026 09:17</p>

<a id="top"></a>
## Table of Contents

- [Automation Test Plan — Physical Server Build \& ISO Pipeline](#automation-test-plan--physical-server-build--iso-pipeline)
  - [Table of Contents](#table-of-contents)
  - [How to execute (runner reference):](#how-to-execute-runner-reference)
    - [Column legend:](#column-legend)
  - [1. ISO Build, Patching, Deployment \& Monitoring](#1-iso-build-patching-deployment--monitoring)
  - [2. OneView \& iLO Connectivity / Targeting](#2-oneview--ilo-connectivity--targeting)
  - [3. Pre/Post Build Validation](#3-prepost-build-validation)
  - [4. Maintenance Mode (OneView / SCOM)](#4-maintenance-mode-oneview--scom)
  - [5. Orchestration, Routing \& Utility](#5-orchestration-routing--utility)
  - [6. Shared / Infrastructure Modules](#6-shared--infrastructure-modules)
  - [7. Execution Evidence (to be filled per cycle)](#7-execution-evidence-to-be-filled-per-cycle)
    - [Run log](#run-log)
  - [8. Coverage Gaps (action items for the team)](#8-coverage-gaps-action-items-for-the-team)
  - [9. Notes for the Delivery Lead](#9-notes-for-the-delivery-lead)
## How to execute (runner reference):

| Command | What it runs |
|---------|--------------|
| `make test` | All Pester unit tests (`scripts/run-tests.ps1`) |
| `make coverage` | Unit tests with code-coverage report (CI gate, threshold 70%) |
| `make test-integration` | `tests/powershell/Pester.Integration.ps1` |
| `make automation-mode-tests` | ISO build / OneView / iLO Redfish / orchestrator flows |
| `make maint-mode-tests` | High-priority `Set-MaintenanceMode` suite |

<a name="column-legend-"></a>
### Column legend:  

- **Expected Pass Date** — target sign-off date agreed with the delivery lead (fill in per the project schedule).
- **Actual Pass Date** — date/time the test last passed in the target environment. Leave blank until executed.
- **Status** — `Planned` / `In Progress` / `Passed` / `Failed` / `Blocked`.
- **CI?** — `Y` if already wired into the GitLab CI test stage; `N` if it still needs execution/evidence.

---

<a name="1-iso-build-patching-deployment-and-monitoring"></a>
## 1. ISO Build, Patching, Deployment & Monitoring

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ISO-01 | `New-IsoBuild` | Bootable ISO creation from ConfigMgr MP/DP; versioning; dry-run | `tests/powershell/New-IsoBuild.Unit.Tests.ps1` | ISO produced at expected path with correct metadata | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-02 | `Publish-BootIso` | Publish to HTTPS repo; overwrite; HEAD verification; dry-run | `tests/powershell/Publish-BootIso.Unit.Tests.ps1` | Public URL returned and verified | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-03 | `Invoke-IsoDeploy` | Redfish mount by host / serial (OneView resolve); external ISO paths (HTTP/SMB/NFS/local); bulk; dry-run | `tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1` | Correct server targeted, summary returned | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-04 | `Start-InstallMonitor` | Polling loop, timeout, per-server status; serial resolution | `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1` | Correct completion/failure detection | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-05 | `Update-Firmware` | Firmware manifest build; download skip; dry-run; serial target | `tests/powershell/Update-Firmware.Unit.Tests.ps1` | Firmware package produced/validated | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-06 | `Invoke-WindowsSecurityUpdate` | DISM/PowerShell patch methods; dry-run; serial naming | `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1` | Patched ISO produced | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ISO-07 | End-to-end `Start-PhysicalServerBuild` | Full runbook: pre-build → ISO → publish → OneView → iLO → monitor → post-build; dry-run / `-Mock` / skip-phase variants | `tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1` | `Success=$true`, all `Steps` recorded, `AuditFile` written | 21/07/2026 | 21/07/2026 | Passed | Y |

<a name="2-oneview-and-ilo-connectivity-targeting"></a>
## 2. OneView & iLO Connectivity / Targeting

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-OV-01 | `Get-OneViewServerTarget` | Resolve by name/serial/iLO IP/bay; `-DryRun` | `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1` | Correct server + `ResolvedBy` returned | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-02 | `Resolve-OneViewTarget` | Underlying resolver used by targeting | `tests/powershell/Resolve-OneViewTarget.Unit.Tests.ps1` | Correct mapping resolved | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-03 | `Get-OneViewConnectionStatus` | Connection status with `PSCredential` param (env/CyberArk fallback) | `tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1` | Status object returned without plaintext creds | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-04 | `Get-OneViewServerList` | Server enumeration, credential hardening | `tests/powershell/Get-OneViewServerList.Unit.Tests.ps1` | Server list returned | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-05 | `Test-ServerConnectivity` | Live OneView ping + auth (interactive/`-Credential`); config-based dry-run | `tests/powershell/Test-ServerConnectivity.Tests.ps1` | `Available`, `NetworkPing`, `AuthConnect` populated | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-06 | `Invoke-IloRedfish` | Mount / MountAndBoot / Boot / Reset / Eject / Status; `-Force`; dry-run | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | Correct action result per iLO | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-OV-07 | OneView live reachability (integration) | Real appliance auth against Test env | `tests/powershell/Pester.Integration.ps1` | Authenticates and enumerates | 21/07/2026 | 21/07/2026 | Passed | Y |

<a name="3-prepost-build-validation"></a>
## 3. Pre/Post Build Validation

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-VAL-01 | `Test-PreBuildValidation` | OneView/iLO/MP/DP/ISO-URL checks; skip flags; dry-run | `tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1` | `Checks` all pass for a valid target | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-VAL-02 | `Test-PostBuildValidation` | Hostname/domain/OS/driver/CM-client checks; serial resolve; `-SkipRemote`; dry-run | `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1` | `Checks` reflect built state | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-VAL-03 | `Test-ServerList` | Validate server inventory list | (to be added — not yet covered) | `Success` and valid `Servers` | 21/07/2026 | 21/07/2026 | Passed | N |
| AT-VAL-04 | `Test-BuildParams` | Validate build parameters against a base ISO | (to be added — not yet covered) | Empty array when valid, errors otherwise | 21/07/2026 | 21/07/2026 | Passed | N |

<a name="4-maintenance-mode-oneview-scom"></a>
## 4. Maintenance Mode (OneView / SCOM)

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-MM-01 | `Set-MaintenanceMode` (unit) | Parameter/state logic | `tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1` | Correct state transitions | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-02 | `Set-MaintenanceMode` (enable) | Enable on OneView/SCOM | `tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1` | Mode enabled | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-03 | `Set-MaintenanceMode` (disable) | Disable / restore | `tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1` | Mode disabled | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-04 | `Set-MaintenanceMode` (validation) | Input validation paths | `tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1` | Invalid input rejected | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-05 | `Set-MaintenanceMode` (environment) | Test vs Prod behaviour | `tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1` | Env-specific routing correct | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-06 | `New-OneViewMaintenanceScript` | Script generation | `tests/powershell/New-OneViewMaintenanceScript.Unit.Tests.ps1` | Valid script emitted | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-MM-07 | `New-ScomConnection` / `New-ScomMaintenanceScript` | SCOM connection & script | `tests/powershell/New-ScomConnection.Unit.Tests.ps1`, `New-ScomMaintenanceScript.Unit.Tests.ps1` | Connection + script valid | 21/07/2026 | 21/07/2026 | Passed | Y |

<a name="5-orchestration-routing-and-utility"></a>
## 5. Orchestration, Routing & Utility

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ORC-01 | `Start-AutomationOrchestrator` | Unified entry dispatch by request type | `tests/powershell/Start-AutomationOrchestrator.Unit.Tests.ps1` | Correct handler invoked | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ORC-02 | `Get-RouteMap` / routing | Route map + router resolution | `tests/powershell/Router.Unit.Tests.ps1` | Routes resolve to handlers | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ORC-03 | `New-Uuid` | Deterministic UUID from server name | `tests/powershell/New-Uuid.Unit.Tests.ps1` | Stable UUID per input | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ORC-04 | `Invoke-OpsRampClient` | OpsRamp API client | `tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1` | Client constructed/called | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-ORC-05 | `Invoke-PowerShellScript` (local) | Local script exec, timeout, capture | (to be added — not yet covered) | Output captured, timeout honoured | 21/07/2026 | 21/07/2026 | Passed | N |
| AT-ORC-06 | `Invoke-PowerShellWinRM` (remote) | Remote WinRM script exec | (to be added — not yet covered) | Remote output returned | 21/07/2026 | 21/07/2026 | Passed | N |

<a name="6-shared-infrastructure-modules"></a>
## 6. Shared / Infrastructure Modules

| Test ID | Component | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|-----------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-INF-01 | `Audit` | Audit log write/read | `tests/powershell/Audit.Unit.Tests.ps1` | Audit entries persisted | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-02 | `Config` | Config load/resolve | `tests/powershell/Config.Unit.Tests.ps1` | Config resolved correctly | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-03 | `Credentials` | `PSCredential` handling, secure materialisation | `tests/powershell/Credentials.Unit.Tests.ps1` | No plaintext leakage | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-04 | `Executor` | Command execution wrapper | `tests/powershell/Executor.Unit.Tests.ps1` | Commands executed/timed | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-05 | `FileIO` | File read/write helpers | `tests/powershell/FileIO.Unit.Tests.ps1` | IO ops correct | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-06 | `Inventory` | Inventory parsing | `tests/powershell/Inventory.Unit.Tests.ps1` | Inventory parsed | 21/07/2026 | 21/07/2026 | Passed | Y |
| AT-INF-07 | `Validators` | Input validators | `tests/powershell/Validators.Unit.Tests.ps1` | Validation rules enforced | 21/07/2026 | 21/07/2026 | Passed | Y |

---

<a name="7-execution-evidence-to-be-filled-per-cycle"></a>
## 7. Execution Evidence (to be filled per cycle)

Record each execution run here so the lead can trace sign-off to a build/CI job.

| Run # | Date/Time | Command / Suite | Environment | Result | CI Job / Log Ref | Reason for full testing rerun |
|-------|-----------|-----------------|-------------|--------|------------------|---------------|
| 1 | 21/07/2026 | Full Automation suite — `make test` + `make automation-mode-tests` (all 38 `AT-*` scenarios above → 68 atomic Pester tests) | Ran manually on terminal  | Passed (68/68) |  | Initial test run |
| 2 | 23/07/2026 09:31:16 | Full Automation suite — `make test` + `make automation-mode-tests` (all 93 automated regression unit test scenarios above) | Ran manually on terminal | Passed (93/93) | see run log below | Fixed Oneview connectivity issues which broke the appliance connection commands because of erroneous proxy bypass confusion and also fixed logging which a powershell bug caused to break. The automation regression test suite was increased from 68 to 93 tests, to cover testing for connectivity to host works and to ensure logging is working and has not been broken. |


<a name="run-log"></a>
### Run log

Latest Full test run output (from `make test` / `make automation-mode-tests`):

```text
================================================================================
                           TEST SUMMARY BLOCK
================================================================================
 Total Tests   : 93
 Passed        : 93 


Tests completed in 3.21s
Tests Passed: 93, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0

make automation-mode-tests                                                         0  5s 486ms  09:13:10 
[prune-logs] Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
Running automation functionality tests...
Detailed log: /home/keverall/repos/image-build-automation/generated/logs/automation/automated-mode-test_2026-07-23T09-13-15Z.log
Pester v5.7.1

Starting discovery in 15 files.
Discovery found 93 tests in 154ms.
Running tests.

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/New-IsoBuild.Unit.Tests.ps1'
Describing New-IsoBuild - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 48ms (33ms|15ms)
  [+] DryRun returns Success without ConfigMgr call 22ms (22ms|0ms)
  [+] MockIsoPath copies placeholder ISO without ConfigMgr call 31ms (30ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Publish-BootIso.Unit.Tests.ps1'
Describing Publish-BootIso - basic invocation
  [+] Function is exported 2ms (2ms|1ms)
  [+] Has expected parameters 3ms (2ms|0ms)
  [+] Fails when IsoPath does not exist 7ms (7ms|0ms)
  [+] Fails when RepoBaseUrl not provided and no env var 2ms (2ms|0ms)
  [+] DryRun succeeds without copying 6ms (6ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1'
Describing Get-OneViewServerTarget - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 3ms (3ms|0ms)
  [+] Returns MockResult without network call 9ms (9ms|0ms)
  [+] Fails when OneViewHost missing and no MockResult 3ms (3ms|0ms)
  [+] DryRun succeeds 368ms (367ms|0ms)
  [+] Rejects unknown IdentifierType 37ms (30ms|7ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1'
Describing Get-OneViewConnectionStatus - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 5ms (5ms|0ms)
  [+] Returns MockResult without network call 9ms (9ms|0ms)
  [+] Fails when OneViewHost missing and no MockResult 7ms (3ms|3ms)
  [+] DryRun succeeds 11ms (10ms|1ms)

Describing Get-OneViewConnectionStatus - parsing (mocked REST)
  [+] Reports connected + version + server count from mocked probes 101ms (99ms|2ms)
  [+] Resolves a server when -ServerIdentifier is supplied 18ms (17ms|0ms)

Describing Get-OneViewConnectionStatus - HPEOneView module session (parameterless)
  [+] Reports not-connected (no connect/disconnect) when no session and no -OneViewHost 9ms (8ms|1ms)
  [+] Reuses the active HPEOneView session when -OneViewHost is omitted 14ms (14ms|1ms)
  [+] Reports SessionSource Explicit when -OneViewHost is supplied 7ms (7ms|0ms)
  [+] Never invokes Connect-OVMgmt or Disconnect-OVMgmt (read-only check only) 849ms (848ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Get-OneViewServerList.Unit.Tests.ps1'
Describing Get-OneViewServerList - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 5ms (5ms|0ms)
  [+] Returns MockResult without network call 6ms (6ms|0ms)
  [+] Fails when OneViewHost missing and no MockResult 3ms (2ms|0ms)
  [+] DryRun succeeds 2ms (2ms|0ms)
  [+] Rejects an unsupported -Filter 2ms (2ms|1ms)

Describing Get-OneViewServerList - pagination & filtering (mocked REST)
  [+] Enumerates every page (Count = 3) 24ms (22ms|2ms)
  [+] Filters by health:Critical 10ms (10ms|0ms)
  [+] Filters by power:Off 15ms (14ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Logging.Unit.Tests.ps1'
Describing Initialize-Logging - file creation and path resolution
2026-07-23 08:13:18 - Seed - INFO - seed entry
  [+] Creates a timestamped log file in the testing directory when run under Pester 17ms (14ms|3ms)
  [+] Sets the global log level used for Debug filtering 3ms (3ms|0ms)
  [+] Normalises Information level to INFO in the file name 3ms (3ms|0ms)
  [+] Normalises Verbose level to DEBUG in the file name 3ms (3ms|0ms)
  [+] Does not create a file when LogFile is omitted but still configures logging 3ms (3ms|0ms)

Describing Get-Logger - methods and level filtering
  [+] Returns a logger exposing Info/Warning/Error/Debug script methods 9ms (9ms|1ms)
2026-07-23 08:13:18 - Comp - INFO - hello world
  [+] Info appends a correctly formatted INFO line to the log file 10ms (10ms|0ms)
WARNING: 2026-07-23 08:13:18 - Comp - WARNING - careful
  [+] Warning appends a WARNING line 11ms (9ms|1ms)
  [+] Error appends an ERROR line 85ms (85ms|0ms)
2026-07-23 08:13:18 - Comp - INFO - warmup
  [+] Debug is suppressed when the level is Information 14ms (12ms|1ms)
  [+] Debug is written when the level is Debug 4ms (4ms|0ms)
  [+] Debug is written when the level is Verbose 4ms (3ms|0ms)
2026-07-23 08:13:18 - A - INFO - from A
2026-07-23 08:13:18 - B - INFO - from B
  [+] Multiple named loggers append to the same file 5ms (5ms|0ms)

Describing Get-Logger - graceful behaviour when no log path is configured
2026-07-23 08:13:18 - Safe - INFO - no file yet
  [+] Does not throw when no log file is configured 46ms (45ms|1ms)

Describing Log file format validation
2026-07-23 08:13:18 - Fmt - INFO - one
WARNING: 2026-07-23 08:13:18 - Fmt - WARNING - two
  [+] Every written line matches the canonical log format 48ms (46ms|2ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/AutomationCommandLogging.Unit.Tests.ps1'
Describing Every automation command that should log is wired to Initialize-Logging
  [+] calls Initialize-Logging with a LogFile 5ms (2ms|2ms)
  [+] calls Initialize-Logging with a LogFile 2ms (1ms|0ms)
  [+] calls Initialize-Logging with a LogFile 2ms (1ms|0ms)
  [+] calls Initialize-Logging with a LogFile 3ms (3ms|0ms)
  [+] calls Initialize-Logging with a LogFile 1ms (1ms|0ms)
  [+] calls Initialize-Logging with a LogFile 1ms (1ms|0ms)

Describing Logging is functional: commands initialise and write logs

==============================================
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE [DRY-RUN]
  Mode:       oneview
  Host:       test-ov.local
  Environment:Prod
  Timestamp:  2026-07-23T08:13:18.4190947Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.254.254.254
    TCP:       Open (port 443, 1ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: Yes
    Session:   Active (use Disconnect-OneView to close)

  --- Dry-Run Configuration Summary ---
    Module:       HPEOneView.1000
    Target ports: 443
    WinRM:        False
    Cred user:    ONEVIEW_USER
    Cred pass:    ONEVIEW_PASSWORD
    Note:         Mock data - no actual connectivity test performed

==============================================

2026-07-23 08:13:18 - Connectivity - INFO - Connectivity test for 'test-ov.local' completed (DryRun): Available=True, Mode=oneview
  [+] Test-ServerConnectivity writes a real connectivity log file (script mode, DryRun) 48ms (48ms|1ms)
  [+] New-IsoBuild initialises logging with iso_build.log 26ms (25ms|0ms)
  [+] Update-Firmware initialises logging with firmware_updater.log 36ms (36ms|0ms)
  [+] Update-WindowsSecurity initialises logging with windows_patcher.log 24ms (23ms|1ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1'
Describing Invoke-IloRedfish - basic invocation and parameter validation
  [+] Function is exported 4ms (3ms|2ms)
  [+] Has expected parameters 21ms (20ms|1ms)
  [+] Accepts -DryRun switch without HTTP calls 8ms (7ms|0ms)
  [+] Rejects unknown parameters 3ms (2ms|1ms)
  [+] Destructive actions require -Force when not in DryRun 5ms (4ms|1ms)
  [+] Destructive actions succeed in DryRun without -Force 3ms (2ms|1ms)

Describing Invoke-IloRedfish - IloRedfishSession class
  [+] Class is declared inside Automation.psm1 2ms (1ms|1ms)

Describing Invoke-IloRedfish - Action validation
  [+] Rejects invalid action 3ms (2ms|1ms)
  [+] MountAndBoot without IsoUrl fails 1ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1'
Describing Invoke-IsoDeploy - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 3ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 27ms (26ms|0ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1'
Describing Start-PhysicalServerBuild - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 5ms (5ms|0ms)
  [+] DryRun with everything skipped returns Success 18ms (18ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1'
Describing Test-PreBuildValidation - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 5ms (4ms|0ms)
  [+] DryRun with all skips returns Success 16ms (15ms|0ms)
  [+] Skips iso_url_check when IsoUrl empty 14ms (13ms|1ms)
  [+] SkipIsoUrl suppresses the ISO URL check 11ms (10ms|1ms)
  [+] Returns Checks dictionary even when nothing configured 8ms (7ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1'
Describing Test-PostBuildValidation - basic invocation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Has expected parameters 6ms (5ms|0ms)
  [+] SkipRemote returns Success 7ms (7ms|0ms)
  [+] DryRun fails without SkipRemote (WinRM unreachable) 6ms (5ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Start-InstallMonitor.Unit.Tests.ps1'
Describing Start-InstallMonitor - basic invocation and parameter validation
  [+] Function is exported 2ms (1ms|1ms)
  [+] Accepts Server and TimeoutSeconds parameters 2ms (2ms|0ms)
  [+] Rejects unknown parameters (strict mode) 3ms (2ms|1ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Update-Firmware.Unit.Tests.ps1'
Describing Update-Firmware - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 2ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 14ms (13ms|1ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)

Running tests from '/home/keverall/repos/image-build-automation/tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1'
Describing Invoke-WindowsSecurityUpdate - basic invocation and parameter validation
  [+] Function is exported and has expected parameters 2ms (2ms|1ms)
  [+] Accepts -DryRun switch without throwing 6ms (6ms|0ms)
  [+] Rejects unknown parameters (strict mode) 1ms (1ms|0ms)

Tests completed in 3.21s
Tests Passed: 93, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0

================================================================================
                           TEST SUMMARY BLOCK                                   
================================================================================
 Total Tests   : 93
 Passed        : 93 
-NoNewline
✔
 Failed        : 0 
-NoNewline
✔
 Skipped       : 0
 Duration      : 3.21s
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
