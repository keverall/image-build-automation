# Automation Test Plan — Physical Server Build & ISO Pipeline

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

## 1. ISO Build, Patching, Deployment & Monitoring

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ISO-01 | `New-IsoBuild` | Bootable ISO creation from ConfigMgr MP/DP; versioning; dry-run | `tests/powershell/New-IsoBuild.Unit.Tests.ps1` | ISO produced at expected path with correct metadata | | | Planned | Y |
| AT-ISO-02 | `Publish-BootIso` | Publish to HTTPS repo; overwrite; HEAD verification; dry-run | `tests/powershell/Publish-BootIso.Unit.Tests.ps1` | Public URL returned and verified | | | Planned | Y |
| AT-ISO-03 | `Invoke-IsoDeploy` | Redfish mount by host / serial (OneView resolve); external ISO paths (HTTP/SMB/NFS/local); bulk; dry-run | `tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1` | Correct server targeted, summary returned | | | Planned | Y |
| AT-ISO-04 | `Start-InstallMonitor` | Polling loop, timeout, per-server status; serial resolution | `tests/powershell/Start-InstallMonitor.Unit.Tests.ps1` | Correct completion/failure detection | | | Planned | Y |
| AT-ISO-05 | `Update-Firmware` | Firmware manifest build; download skip; dry-run; serial target | `tests/powershell/Update-Firmware.Unit.Tests.ps1` | Firmware package produced/validated | | | Planned | Y |
| AT-ISO-06 | `Invoke-WindowsSecurityUpdate` | DISM/PowerShell patch methods; dry-run; serial naming | `tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1` | Patched ISO produced | | | Planned | Y |
| AT-ISO-07 | End-to-end `Start-PhysicalServerBuild` | Full runbook: pre-build → ISO → publish → OneView → iLO → monitor → post-build; dry-run / `-Mock` / skip-phase variants | `tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1` | `Success=$true`, all `Steps` recorded, `AuditFile` written | | | Planned | Y |

## 2. OneView & iLO Connectivity / Targeting

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-OV-01 | `Get-OneViewServerTarget` | Resolve by name/serial/iLO IP/bay; `-DryRun` | `tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1` | Correct server + `ResolvedBy` returned | | | Planned | Y |
| AT-OV-02 | `Resolve-OneViewTarget` | Underlying resolver used by targeting | `tests/powershell/Resolve-OneViewTarget.Unit.Tests.ps1` | Correct mapping resolved | | | Planned | Y |
| AT-OV-03 | `Get-OneViewConnectionStatus` | Connection status with `PSCredential` param (env/CyberArk fallback) | `tests/powershell/Get-OneViewConnectionStatus.Unit.Tests.ps1` | Status object returned without plaintext creds | | | Planned | Y |
| AT-OV-04 | `Get-OneViewServerList` | Server enumeration, credential hardening | `tests/powershell/Get-OneViewServerList.Unit.Tests.ps1` | Server list returned | | | Planned | Y |
| AT-OV-05 | `Test-ServerConnectivity` | Live OneView ping + auth (interactive/`-Credential`); config-based dry-run | `tests/powershell/Test-ServerConnectivity.Tests.ps1` | `Available`, `NetworkPing`, `AuthConnect` populated | | | Planned | Y |
| AT-OV-06 | `Invoke-IloRedfish` | Mount / MountAndBoot / Boot / Reset / Eject / Status; `-Force`; dry-run | `tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1` | Correct action result per iLO | | | Planned | Y |
| AT-OV-07 | OneView live reachability (integration) | Real appliance auth against Test env | `tests/powershell/Pester.Integration.ps1` | Authenticates and enumerates | | | Planned | Y |

## 3. Pre/Post Build Validation

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-VAL-01 | `Test-PreBuildValidation` | OneView/iLO/MP/DP/ISO-URL checks; skip flags; dry-run | `tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1` | `Checks` all pass for a valid target | | | Planned | Y |
| AT-VAL-02 | `Test-PostBuildValidation` | Hostname/domain/OS/driver/CM-client checks; serial resolve; `-SkipRemote`; dry-run | `tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1` | `Checks` reflect built state | | | Planned | Y |
| AT-VAL-03 | `Test-ServerList` | Validate server inventory list | (to be added — not yet covered) | `Success` and valid `Servers` | | | Planned | N |
| AT-VAL-04 | `Test-BuildParams` | Validate build parameters against a base ISO | (to be added — not yet covered) | Empty array when valid, errors otherwise | | | Planned | N |

## 4. Maintenance Mode (OneView / SCOM)

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-MM-01 | `Set-MaintenanceMode` (unit) | Parameter/state logic | `tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1` | Correct state transitions | | | Planned | Y |
| AT-MM-02 | `Set-MaintenanceMode` (enable) | Enable on OneView/SCOM | `tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1` | Mode enabled | | | Planned | Y |
| AT-MM-03 | `Set-MaintenanceMode` (disable) | Disable / restore | `tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1` | Mode disabled | | | Planned | Y |
| AT-MM-04 | `Set-MaintenanceMode` (validation) | Input validation paths | `tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1` | Invalid input rejected | | | Planned | Y |
| AT-MM-05 | `Set-MaintenanceMode` (environment) | Test vs Prod behaviour | `tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1` | Env-specific routing correct | | | Planned | Y |
| AT-MM-06 | `New-OneViewMaintenanceScript` | Script generation | `tests/powershell/New-OneViewMaintenanceScript.Unit.Tests.ps1` | Valid script emitted | | | Planned | Y |
| AT-MM-07 | `New-ScomConnection` / `New-ScomMaintenanceScript` | SCOM connection & script | `tests/powershell/New-ScomConnection.Unit.Tests.ps1`, `New-ScomMaintenanceScript.Unit.Tests.ps1` | Connection + script valid | | | Planned | Y |

## 5. Orchestration, Routing & Utility

| Test ID | Component / Command | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|---------------------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-ORC-01 | `Start-AutomationOrchestrator` | Unified entry dispatch by request type | `tests/powershell/Start-AutomationOrchestrator.Unit.Tests.ps1` | Correct handler invoked | | | Planned | Y |
| AT-ORC-02 | `Get-RouteMap` / routing | Route map + router resolution | `tests/powershell/Router.Unit.Tests.ps1` | Routes resolve to handlers | | | Planned | Y |
| AT-ORC-03 | `New-Uuid` | Deterministic UUID from server name | `tests/powershell/New-Uuid.Unit.Tests.ps1` | Stable UUID per input | | | Planned | Y |
| AT-ORC-04 | `Invoke-OpsRampClient` | OpsRamp API client | `tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1` | Client constructed/called | | | Planned | Y |
| AT-ORC-05 | `Invoke-PowerShellScript` (local) | Local script exec, timeout, capture | (to be added — not yet covered) | Output captured, timeout honoured | | | Planned | N |
| AT-ORC-06 | `Invoke-PowerShellWinRM` (remote) | Remote WinRM script exec | (to be added — not yet covered) | Remote output returned | | | Planned | N |

## 6. Shared / Infrastructure Modules

| Test ID | Component | Test Scope | Test File (existing) | Expected Result | Expected Pass Date | Actual Pass Date | Status | CI? |
|---------|-----------|------------|----------------------|-----------------|--------------------|-----------------|--------|-----|
| AT-INF-01 | `Audit` | Audit log write/read | `tests/powershell/Audit.Unit.Tests.ps1` | Audit entries persisted | | | Planned | Y |
| AT-INF-02 | `Config` | Config load/resolve | `tests/powershell/Config.Unit.Tests.ps1` | Config resolved correctly | | | Planned | Y |
| AT-INF-03 | `Credentials` | `PSCredential` handling, secure materialisation | `tests/powershell/Credentials.Unit.Tests.ps1` | No plaintext leakage | | | Planned | Y |
| AT-INF-04 | `Executor` | Command execution wrapper | `tests/powershell/Executor.Unit.Tests.ps1` | Commands executed/timed | | | Planned | Y |
| AT-INF-05 | `FileIO` | File read/write helpers | `tests/powershell/FileIO.Unit.Tests.ps1` | IO ops correct | | | Planned | Y |
| AT-INF-06 | `Inventory` | Inventory parsing | `tests/powershell/Inventory.Unit.Tests.ps1` | Inventory parsed | | | Planned | Y |
| AT-INF-07 | `Validators` | Input validators | `tests/powershell/Validators.Unit.Tests.ps1` | Validation rules enforced | | | Planned | Y |

---

## 7. Execution Evidence (to be filled per cycle)

Record each execution run here so the lead can trace sign-off to a build/CI job.

| Run # | Date/Time | Command / Suite | Environment | Result | CI Job / Log Ref | Signed off by |
|-------|-----------|-----------------|-------------|--------|------------------|---------------|
| | | | | | | |

## 8. Coverage Gaps (action items for the team)

These commands are documented but **lack automated test files** and need new Pester tests before sign-off:

- `Test-ServerList` (AT-VAL-03)
- `Test-BuildParams` (AT-VAL-04)
- `Invoke-PowerShellScript` (AT-ORC-05)
- `Invoke-PowerShellWinRM` (AT-ORC-06)

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
