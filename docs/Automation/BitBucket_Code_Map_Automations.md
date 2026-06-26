# Automation Code Map

## TOC

- [Automation Code Map](#automation-code-map)
  - [TOC](#toc)
  - [1. Module Loading \& Bootstrap](#1-module-loading-bootstrap)
    - [1.1 - Root Module Loader](#1-1-root-module-loader)
    - [1.2 - Private Script Load Order](#1-2-private-script-load-order)
    - [1.3 - Public Function Load Order](#1-3-public-function-load-order)
  - [2. Request Routing \& Control Surfaces](#2-request-routing-control-surfaces)
    - [2.1 - Request Router](#2-1-request-router)
    - [2.2 - Unified Orchestrator Entry Point](#2-2-unified-orchestrator-entry-point)
    - [2.3 - Request Validation](#2-3-request-validation)
    - [2.4 - CI Pipeline Surface](#2-4-ci-pipeline-surface)
    - [2.5 - iRequest/ISAPI Surface](#2-5-irequest-isapi-surface)
    - [2.6 - Scheduled Task Surface](#2-6-scheduled-task-surface)
    - [2.7 - GitLab CI/CD Surface](#2-7-gitlab-ci-cd-surface)
  - [3. Physical Server Build Pipeline](#3-physical-server-build-pipeline)
    - [3.1 - End-to-End Build Orchestrator](#3-1-end-to-end-build-orchestrator)
    - [3.2 - ConfigMgr Bootable ISO Builder](#3-2-configmgr-bootable-iso-builder)
    - [3.3 - ISO Publisher](#3-3-iso-publisher)
  - [4. Firmware ISO Builder (Standalone)](#4-firmware-iso-builder-standalone)
    - [4.1 - Firmware Update Function](#4-1-firmware-update-function)
    - [4.2 - FirmwareUpdater Class](#4-2-firmwareupdater-class)
  - [5. Windows Security Patching](#5-windows-security-patching)
    - [5.1 - Invoke-WindowsSecurityUpdate](#5-1-invoke-windowssecurityupdate)
    - [5.2 - WindowsPatcher Class](#5-2-windowspatcher-class)
  - [6. ISO Deployment](#6-iso-deployment)
    - [6.1 - Invoke-IsoDeploy](#6-1-invoke-isodeploy)
    - [6.2 - ISODeployer Class](#6-2-isodeployer-class)
  - [7. iLO Redfish Integration](#7-ilo-redfish-integration)
    - [7.1 - Invoke-IloRedfish](#7-1-invoke-iloredfish)
    - [7.2 - IloRedfishSession Class](#7-2-iloredfishsession-class)
  - [8. Installation Monitoring](#8-installation-monitoring)
    - [8.1 - Start-InstallMonitor](#8-1-start-installmonitor)
    - [8.2 - InstallationMonitor Class](#8-2-installationmonitor-class)
  - [9. Pre \& Post Build Validation](#9-pre-post-build-validation)
    - [9.1 - Test-PreBuildValidation](#9-1-test-prebuildvalidation)
    - [9.2 - Test-PostBuildValidation](#9-2-test-postbuildvalidation)
    - [9.3 - Test-ServerConnectivity](#9-3-test-serverconnectivity)
  - [10. PowerShell Execution Utilities](#10-powershell-execution-utilities)
    - [10.1 - Local PowerShell Execution](#10-1-local-powershell-execution)
    - [10.2 - Remote PowerShell via WinRM](#10-2-remote-powershell-via-winrm)
  - [11. OpsRamp Integration](#11-opsramp-integration)
    - [11.1 - OpsRamp\_Client Class](#11-1-opsramp-client-class)
    - [11.2 - OpsRamp Entry Points](#11-2-opsramp-entry-points)
  - [12. Credential Resolution](#12-credential-resolution)
  - [13. Inventory \& Configuration](#13-inventory-configuration)
    - [13.1 - Inventory Functions](#13-1-inventory-functions)
    - [13.2 - Configuration Functions](#13-2-configuration-functions)
    - [13.3 - Validator Functions](#13-3-validator-functions)
  - [14. Process Execution \& Retry](#14-process-execution-retry)
  - [15. File I/O \& Path Resolution](#15-file-i-o-path-resolution)
    - [15.1 - File I/O Functions](#15-1-file-i-o-functions)
    - [15.2 - Path Resolution](#15-2-path-resolution)
  - [16. Logging \& Audit](#16-logging-audit)
    - [16.1 - Logging Functions](#16-1-logging-functions)
    - [16.2 - Audit Logger](#16-2-audit-logger)
    - [16.3 - Timestamp Helpers](#16-3-timestamp-helpers)
  - [17. Script Helpers](#17-script-helpers)
    - [17.1 - PowerShell Profile Setup](#17-1-powershell-profile-setup)
    - [17.2 - CI/Security \& Lint Scripts](#17-2-ci-security-lint-scripts)
    - [17.3 - Setup \& Bootstrap Scripts](#17-3-setup-bootstrap-scripts)
    - [17.4 - Documentation \& Coverage Scripts](#17-4-documentation-coverage-scripts)
  - [18. Configuration Files](#18-configuration-files)
  - [19. Testing](#19-testing)
    - [19.1 - Pester Unit Tests](#19-1-pester-unit-tests)
    - [19.2 - Test Execution Scripts](#19-2-test-execution-scripts)
    - [19.3 - Coverage \& Lint](#19-3-coverage-lint)
  - [20. Quick Navigation](#20-quick-navigation)


This document maps every code location in the automation module **excluding** maintenance mode (which is fully documented in [`BitBucket_Code_Map_Maitenance_Mode.md`](BitBucket_Code_Map_Maitenance_Mode.md)). It is organized in the **chronological order a user or caller encounters each feature** - from module loading, through request routing, physical server builds, firmware/Windows patching, deployment, monitoring, validation, and OpsRamp reporting.

> **Source root**: [`src/powershell/Automation/`](../src/powershell/Automation/)
> **Module manifest**: [`Automation.psd1`](../src/powershell/Automation/Automation.psd1)
> **Module loader**: [`Automation.psm1`](../src/powershell/Automation/Automation.psm1) (652 lines)

---

## 1. Module Loading & Bootstrap

Before any function can be called, the `Automation` module must be loaded. This loads all shared types, private helpers (in dependency order), and public functions.

### 1.1 - Root Module Loader

**[`Automation.psm1`](../src/powershell/Automation/Automation.psm1)** - 652 lines

| Section | Lines | Content |
|---------|-------|---------|
| Shared value type | [L19–33](../src/powershell/Automation/Automation.psm1##19-33) | `CommandResult` class - holds `ReturnCode`, `StandardOutput`, `StandardError`, `Success` |
| Shared reference type | [L38–106](../src/powershell/Automation/Automation.psm1#38-106) | `AuditLogger` class - timestamped JSON audit log with `Log()`, `Save()`, `AppendToMaster()` |
| OpsRamp REST client | [L136–335](../src/powershell/Automation/Automation.psm1#136-335) | `OpsRamp_Client` class - OAuth2 token management, REST calls, metric/alert/event senders |
| iLO Redfish session | [L340–471](../src/powershell/Automation/Automation.psm1#340-471) | `IloRedfishSession` class - Redfish session login/logout, virtual media, boot override, system reset |
| Base class | [L476–528](../src/powershell/Automation/Automation.psm1#476-528) | `AutomationBase` class - config dir, output dir, dry-run flag, audit, `RunCommand()` |
| Private script load | [L530–557](../src/powershell/Automation/Automation.psm1#530-557) | Dot-sources `Private/*.ps1` in dependency order (see §1.2) |
| Public script load | [L559–565](../src/powershell/Automation/Automation.psm1#559-565) | Dot-sources `Public/*.ps1` alphabetically |
| Export surface | [L569–648](../src/powershell/Automation/Automation.psm1#569-648) | `Export-ModuleMember` - explicit public API |

### 1.2 - Private Script Load Order

Dot-sourced in dependency order by [`Automation.psm1`](../src/powershell/Automation/Automation.psm1#538-549):

| Order | File | Purpose |
|-------|------|---------|
| 1 | [`Audit.ps1`](../src/powershell/Automation/Private/Audit.ps1) | `New-AuditLogger` factory (20 lines) |
| 2 | [`Config.ps1`](../src/powershell/Automation/Private/Config.ps1) | `Import-JsonConfig`, `Import-YamlConfig`, `_PS_ConvertTo-Hashtable`, env-var substitution (126 lines) |
| 3 | [`Credentials.ps1`](../src/powershell/Automation/Private/Credentials.ps1) | `Get-EnvCredential`, `Get-IloCredentials`, `Get-ScomCredentials`, `Get-OneViewCredentials`, CyberArk CCP fallback (201 lines) |
| 4 | [`Executor.ps1`](../src/powershell/Automation/Private/Executor.ps1) | `Invoke-NativeCommand`, `Invoke-NativeCommandWithRetry`, `New-CommandResult` (108 lines) |
| 5 | [`FileIO.ps1`](../src/powershell/Automation/Private/FileIO.ps1) | `Ensure-DirectoryExists`, `Save-Json`, `Load-Json`, `Save-JsonResult`, `Test-PathEx` (116 lines) |
| 6 | [`PathResolver.ps1`](../src/powershell/Automation/Private/PathResolver.ps1) | `Get-ProjectRoot`, `Get-LogDirectory` (53 lines) |
| 7 | [`Inventory.ps1`](../src/powershell/Automation/Private/Inventory.ps1) | `Load-ServerList`, `Load-ClusterCatalogue`, `Test-ClusterDefinition`, `New-ServerInfo` (99 lines) |
| 8 | [`Logging.ps1`](../src/powershell/Automation/Private/Logging.ps1) | `Initialize-Logging`, `Get-Logger` (97 lines) |
| 9 | [`Router.ps1`](../src/powershell/Automation/Private/Router.ps1) | `Invoke-RoutedRequest` - dispatches by `request_types.json` (66 lines) |
| 10 | [`Base.ps1`](../src/powershell/Automation/Private/Base.ps1) | `New-AutomationBase`, timestamp helpers (91 lines) |

### 1.3 - Public Function Load Order

Loaded alphabetically by [`Automation.psm1`](../src/powershell/Automation/Automation.psm1#559-565). Order:

1. [`_Validate-Request.ps1`](../src/powershell/Automation/Public/_Validate-Request.ps1) - request validation (underscore-prefixed, not exported)
2. [`Control.ps1`](../src/powershell/Automation/Public/Control.ps1) - central control surface
3. [`Get-OneViewServerTarget.ps1`](../src/powershell/Automation/Public/Get-OneViewServerTarget.ps1) - OneView server identity query
4. [`Get-RouteMap.ps1`](../src/powershell/Automation/Public/Get-RouteMap.ps1) - routing introspection
5. [`Invoke-GitLabMaintenanceTrigger.ps1`](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1) - GitLab CI/CD trigger
6. [`Invoke-IloRedfish.ps1`](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1) - iLO Redfish virtual media / boot
7. [`Invoke-IsoDeploy.ps1`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1) - ISO deployer orchestrator
8. [`Invoke-OpsRampClient.ps1`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1) - OpsRamp client
9. [`Invoke-PowerShellScript.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1) - local PS execution
10. [`Invoke-PowerShellWinRM.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1) - remote WinRM execution
11. [`New-IsoBuild.ps1`](../src/powershell/Automation/Public/New-IsoBuild.ps1) - ConfigMgr bootable ISO builder
12. [`New-OneViewMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1) - generate OneView maintenance scripts
13. [`New-ScomConnection.ps1`](../src/powershell/Automation/Public/New-ScomConnection.ps1) - SCOM connection scripts
14. [`New-ScomMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1) - generate SCOM maintenance scripts
15. [`New-Uuid.ps1`](../src/powershell/Automation/Public/New-Uuid.ps1) - deterministic UUID generator
16. [`Publish-BootIso.ps1`](../src/powershell/Automation/Public/Publish-BootIso.ps1) - publish ISO to HTTPS repository
17. [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1) - *see BitBucket_Code_Map_Maitenance_Mode.md*
18. [`Start-AutomationOrchestrator.ps1`](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1) - unified entry point
19. [`Start-InstallMonitor.ps1`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1) - installation progress monitor
20. [`Start-PhysicalServerBuild.ps1`](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1) - end-to-end physical server build
21. [`Test-BuildParams.ps1`](../src/powershell/Automation/Public/Test-BuildParams.ps1) - build parameter validation
22. [`Test-ClusterId.ps1`](../src/powershell/Automation/Public/Test-ClusterId.ps1) - cluster ID validation
23. [`Test-PostBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1) - post-build validation
24. [`Test-PreBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1) - pre-build validation
25. [`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1) - SCOM/OneView connectivity check
26. [`Test-ServerList.ps1`](../src/powershell/Automation/Public/Test-ServerList.ps1) - server list validation
27. [`Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1) - standalone firmware ISO builder
28. [`Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1) - Windows security patcher

---

## 2. Request Routing & Control Surfaces

After module load, requests arrive from one of four surfaces: CI pipeline, iRequest/ISAPI, Scheduled tasks, or GitLab CI/CD. All surfaces converge on the central router.

### 2.1 - Request Router

**[`configs/request_types.json`](../configs/request_types.json)** - Single source of truth for all request types and their handler mappings.

| Request Type | Handler Function | CI Stage |
|--------------|-----------------|----------|
| `build_iso` | `New-IsoBuild` | `all` |
| `update_firmware` | `Update-Firmware` | `firmware` |
| `patch_windows` | `Invoke-WindowsSecurityUpdate` | `windows` |
| `deploy` | `Invoke-IsoDeploy` | `deploy` |
| `monitor` | `Start-InstallMonitor` | null |
| `maintenance_enable` | `Set-MaintenanceMode` | null |
| `maintenance_disable` | `Set-MaintenanceMode` | null |
| `maintenance_validate` | `Set-MaintenanceMode` | null |
| `opsramp_report` | `Invoke-OpsRampClient` | `scan` |
| `generate_uuid` | `New-Uuid` | null |
| `connectivity_check` | `Test-ServerConnectivity` | null |
| `gitlab_maintenance` | `Invoke-GitLabMaintenanceTrigger` | null |
| `physical_server_build` | `Start-PhysicalServerBuild` | `all` |
| `query_oneview_server` | `Get-OneViewServerTarget` | null |
| `prebuild_validation` | `Test-PreBuildValidation` | null |
| `postbuild_validation` | `Test-PostBuildValidation` | null |
| `publish_iso` | `Publish-BootIso` | `deploy` |
| `ilo_redfish_mount` | `Invoke-IloRedfish` | `deploy` |

**[`Router.ps1`](../src/powershell/Automation/Private/Router.ps1#20)** - [`Invoke-RoutedRequest()`](../src/powershell/Automation/Private/Router.ps1#20)
- Loads routing table from `request_types.json` at [L9–13](../src/powershell/Automation/Private/Router.ps1#9-13)
- Dispatches by calling handler with `@Params` splat at [L54](../src/powershell/Automation/Private/Router.ps1#54)
- Returns `Success=false` for unknown types at [L43–49](../src/powershell/Automation/Private/Router.ps1#43-49)

### 2.2 - Unified Orchestrator Entry Point

**[`Start-AutomationOrchestrator.ps1`](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#5)** - [`Start-AutomationOrchestrator()`](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#5)
- Validates request via [`_Validate-Request()`](../src/powershell/Automation/Public/_Validate-Request.ps1#5) at [L37](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#37)
- Routes via [`Invoke-RoutedRequest()`](../src/powershell/Automation/Private/Router.ps1#20) at [L46](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#46)
- Adds `Timestamp` and `RequestType` to result at [L47–48](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#47-48)

### 2.3 - Request Validation

**[`_Validate-Request.ps1`](../src/powershell/Automation/Public/_Validate-Request.ps1#5)** - [`_Validate-Request()`](../src/powershell/Automation/Public/_Validate-Request.ps1#5)

| Check | Lines | Logic |
|-------|-------|-------|
| Build params | [L31–33](../src/powershell/Automation/Public/_Validate-Request.ps1#31-33) | Calls `Test-BuildParams` for `build_iso` / `patch_windows` |
| Maintenance target | [L34–39](../src/powershell/Automation/Public/_Validate-Request.ps1#34-39) | Calls `Test-ClusterId` for `maintenance_*` requests |

### 2.4 - CI Pipeline Surface

**[`Control.ps1`](../src/powershell/Automation/Public/Control.ps1#193)** - [`Run-CIPipeline()`](../src/powershell/Automation/Public/Control.ps1#193)
- Builds CI params via [`_Build-CIParams()`](../src/powershell/Automation/Public/Control.ps1#27) mapping:
  - `firmware` → `update_firmware`
  - `windows` → `patch_windows`
  - `deploy` → `deploy`
  - `scan` → `opsramp_report`
  - `all` → `build_iso`
- Executes via [`_Execute()`](../src/powershell/Automation/Public/Control.ps1#164)

### 2.5 - iRequest/ISAPI Surface

**[`Control.ps1`](../src/powershell/Automation/Public/Control.ps1#207)** - [`Run-IRequest()`](../src/powershell/Automation/Public/Control.ps1#207)
- Builds params via [`_Build-IRequestParams()`](../src/powershell/Automation/Public/Control.ps1#64) mapping `cluster_id` + `action` → `maintenance_{action}`
- Executes via [`_Execute()`](../src/powershell/Automation/Public/Control.ps1#164)

### 2.6 - Scheduled Task Surface

**[`Control.ps1`](../src/powershell/Automation/Public/Control.ps1#232)** - [`Run-Scheduler()`](../src/powershell/Automation/Public/Control.ps1#232)
- Builds params via [`_Build-SchedulerParams()`](../src/powershell/Automation/Public/Control.ps1#92) mapping:
  - `maintenance_disable` → `maintenance_disable`
  - `build_firmware` → `update_firmware`
  - `build_windows` → `patch_windows`

### 2.7 - GitLab CI/CD Surface

**[`Control.ps1`](../src/powershell/Automation/Public/Control.ps1#289)** - [`Run-GitLab()`](../src/powershell/Automation/Public/Control.ps1#289)
- Builds params via [`_Build-GitLabParams()`](../src/powershell/Automation/Public/Control.ps1#256)
- Routes to `gitlab_maintenance` request type
- Factory: [`New-GitLabCtrl()`](../src/powershell/Automation/Public/Control.ps1#275)

**[`Invoke-GitLabMaintenanceTrigger.ps1`](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#7)** - [`Invoke-GitLabMaintenanceTrigger()`](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#7)
- Dot-sources [`Send-GitLabMaintenanceRequest.ps1`](../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1) at [L84–94](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#84-94)
- Calls [`Send-GitLabMaintenanceRequest()`](../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1) at [L97–100](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#97-100)
- Returns pipeline ID and URL on success at [L102–110](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#102-110)

**[`scripts/gitlab/Send-GitLabMaintenanceRequest.ps1`](../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1)**
- Triggers GitLab pipeline via trigger API (`POST /api/v4/projects/{id}/trigger/pipeline`)
- Monitors pipeline completion via GitLab API with timeout
- Sends web callback with results on completion

**[`scripts/gitlab/Invoke-GitLabMaintenance.ps1`](../scripts/gitlab/Invoke-GitLabMaintenance.ps1)**
- GitLab CI/CD pipeline entry point - executed by pipeline runner
- Wraps `Set-MaintenanceMode` with GitLab-specific logging and callback support

**[`scripts/gitlab/Send-WebCallback.ps1`](../scripts/gitlab/Send-WebCallback.ps1)** - [`Send-WebCallback()`](../scripts/gitlab/Send-WebCallback.ps1)
- POST JSON to HTTPS callback URL with optional API key
- Validates HTTPS-only at [L28–31](../scripts/gitlab/Send-WebCallback.ps1#28-31)

---

## 3. Physical Server Build Pipeline

The end-to-end physical server build pipeline orchestrates the full runbook workflow.

### 3.1 - End-to-End Build Orchestrator

**[`Start-PhysicalServerBuild.ps1`](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#18)** - [`Start-PhysicalServerBuild()`](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#18)

One-call orchestrator for new HPE ProLiant server deployments. Steps:
1. **Pre-build validation** - `Test-PreBuildValidation` at [L189](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#189)
2. **Build ConfigMgr bootable ISO** - `New-IsoBuild` at [L173](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#173)
3. **Publish ISO to HTTPS** - `Publish-BootIso` at [L183](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#183)
4. **Resolve iLO via OneView** - `Get-OneViewServerTarget` at [L203](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#203)
5. **Mount ISO + force boot via iLO Redfish** - `Invoke-IloRedfish` at [L231](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#231)
6. **Monitor installation** - `Start-InstallMonitor` at [L239](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#239)
7. **Post-build validation** - `Test-PostBuildValidation` at [L247](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#247)
8. **Audit log entry** at [L266](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1#266)

Skip switches: `-SkipPreBuild`, `-SkipIsoBuild`, `-SkipPublish`, `-SkipOneView`, `-SkipMount`, `-SkipMonitor`, `-SkipPostBuild`

### 3.2 - ConfigMgr Bootable ISO Builder

**[`New-IsoBuild.ps1`](../src/powershell/Automation/Public/New-IsoBuild.ps1#13)** - [`New-IsoBuild()`](../src/powershell/Automation/Public/New-IsoBuild.ps1#13)

Builds ConfigMgr bootable WinPE media (replaces old DSC/DISM firmware+patching pipeline). Uses `New-CMBootableMedia` from the ConfigurationManager module.

- Auto-detects ConfigMgr context: local module or PSRemoting to site server at [L249](../src/powershell/Automation/Public/New-IsoBuild.ps1#249)
- Output naming: `WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso`
- Auto-increments version from existing ISOs at [L114](../src/powershell/Automation/Public/New-IsoBuild.ps1#114)
- DryRun mode at [L155](../src/powershell/Automation/Public/New-IsoBuild.ps1#155)
- Mock mode for tests at [L144](../src/powershell/Automation/Public/New-IsoBuild.ps1#144)
- Writes `deployment_metadata.json` at [L239](../src/powershell/Automation/Public/New-IsoBuild.ps1#239)

### 3.3 - ISO Publisher

**[`Publish-BootIso.ps1`](../src/powershell/Automation/Public/Publish-BootIso.ps1#12)** - [`Publish-BootIso()`](../src/powershell/Automation/Public/Publish-BootIso.ps1#12)
- Copies bootable ISO to HTTPS repository for iLO Redfish consumption
- Verifies reachability with HTTP HEAD at [L114](../src/powershell/Automation/Public/Publish-BootIso.ps1#114)
- `RepoBaseUrl` from `$env:ISO_REPO_BASE_URL` at [L61](../src/powershell/Automation/Public/Publish-BootIso.ps1#61)
- `-ForceOverwrite` to replace existing ISOs at [L97](../src/powershell/Automation/Public/Publish-BootIso.ps1#97)

---

## 4. Firmware ISO Builder (Standalone)

Standalone firmware ISO generation via HPE SUT. Not part of the ConfigMgr end-to-end workflow.

### 4.1 - Firmware Update Function

**[`Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1#19)** - [`Update-Firmware()`](../src/powershell/Automation/Public/Update-Firmware.ps1#19)
- Default config: `configs/hpe_firmware_drivers_nov2025.json`
- Default output: `output/firmware`
- Delegates to [`FirmwareUpdater`](../src/powershell/Automation/Public/Update-Firmware.ps1#82) class at [L67](../src/powershell/Automation/Public/Update-Firmware.ps1#67)
- Saves per-server result JSON at [L73](../src/powershell/Automation/Public/Update-Firmware.ps1#73)

### 4.2 - FirmwareUpdater Class

**[`Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1#82)** - class starts at [L82](../src/powershell/Automation/Public/Update-Firmware.ps1#82)

| Property | Line | Purpose |
|----------|------|---------|
| `$ConfigPath` | 83 | Path to `hpe_firmware_drivers_nov2025.json` |
| `$OutputDir` | 84 | Output directory for firmware ISOs |
| `$Config` | 85 | Parsed config hashtable |
| `$SutPath` | 86 | Path to `hpe_sut` binary |
| `$DownloadCreds` | 87 | HPE repository download credentials from config |
| `$BuildLog` | 88 | ArrayList of build log entries |
| `$MaxRetryAttempts` | 91 | SUT retry limit (default: 3) |
| `$RetryDelaySeconds` | 92 | SUT base retry delay (default: 5.0) |

| Method | Line | Purpose |
|--------|------|---------|
| `FirmwareUpdater()` | [L94](../src/powershell/Automation/Public/Update-Firmware.ps1#94) | Constructor: loads config, finds SUT binary, reads download credentials |
| `_FindSut()` | [L110](../src/powershell/Automation/Public/Update-Firmware.ps1#110) | Locates `hpe_sut` in `tools/`, Program Files, or PATH |
| `_DetectGen()` | [L126](../src/powershell/Automation/Public/Update-Firmware.ps1#126) | Detects Gen10 vs Gen10+ from server name |
| `_ComponentsForGen()` | [L132](../src/powershell/Automation/Public/Update-Firmware.ps1#132) | Resolves firmware/driver components for server generation |
| `_Log()` | [L147](../src/powershell/Automation/Public/Update-Firmware.ps1#147) | Adds timestamped build log entry |
| `_RunSut()` | [L154](../src/powershell/Automation/Public/Update-Firmware.ps1#154) | Invokes `hpe_sut create` via [`Invoke-NativeCommandWithRetry()`](../src/powershell/Automation/Private/Executor.ps1#68) |
| `Build()` | [L171](../src/powershell/Automation/Public/Update-Firmware.ps1#171) | Full firmware ISO build: detect gen → resolve components → invoke SUT |

**SUT command** at [L201–202](../src/powershell/Automation/Public/Update-Firmware.ps1#201-202):
```
hpe_sut create --server-generation {gen} --repository {url} --output {iso} --components {list} --include-drivers
```

---

## 5. Windows Security Patching

### 5.1 - Invoke-WindowsSecurityUpdate

**[`Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#8)** - [`Invoke-WindowsSecurityUpdate()`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#8)
- Default patches config: `configs/windows_patches.json`
- Default output: `output/patched`
- Creates [`WindowsPatcher`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#88) instance at [L74](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#74) (3 params: config, baseIsoDir, outputDir)
- Calls `Build()` at [L75](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#75)
- Saves patch result JSON at [L78](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#78)

### 5.2 - WindowsPatcher Class

**[`Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#88)** - class starts at [L88](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#88)

| Property | Line | Purpose |
|----------|------|---------|
| `$PatchesConfigPath` | 89 | Path to `windows_patches.json` |
| `$BaseIsoDir` | 90 | Base ISO directory |
| `$OutputDir` | 91 | Patched ISO output directory |
| `$PatchesConfig` | 92 | Parsed patch config hashtable |
| `$PatchDir` | 93 | Directory containing MSU patch files |
| `$BuildLog` | 94 | ArrayList of build log entries |

| Method | Line | Purpose |
|--------|------|---------|
| `WindowsPatcher()` | [L96](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#96) | Constructor: loads patch config, creates patch directory |
| `_LoadConfig()` | [L106](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#106) | Returns parsed patches config |
| `_Log()` | [L108](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#108) | Adds timestamped build log entry |
| `_SetupBaseIso()` | [L113](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#113) | Mounts Windows ISO via `Mount-DiskImage` (Windows) or extracts directory |
| `_ApplyPatchesDism()` | [L138](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#138) | Applies MSU patches via `dism /Add-Package` |
| `_ApplyPatchesPowerShell()` | [L156](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#156) | Applies patches via `Add-WindowsPackage` cmdlet |
| `Build()` | [L175](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#175) | Full patch pipeline: mount ISO → apply patches → export patched ISO |

---

## 6. ISO Deployment

### 6.1 - Invoke-IsoDeploy

**[`Invoke-IsoDeploy.ps1`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#20)** - [`Invoke-IsoDeploy()`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#20)
- Default ISO directory: `output/bootable_media`
- Only supports `Method`: `redfish`
- Creates [`ISODeployer`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#89) at [L72](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#72)
- Single-server mode via `Deploy()` at [L182](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#182)
- Bulk mode via `DeployAll()` at [L199](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#199)
- Delegates actual mount+boot to `Invoke-IloRedfish` at [L175](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#175)

### 6.2 - ISODeployer Class

**[`Invoke-IsoDeploy.ps1`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#89)** - class starts at [L89](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#89)

| Property | Line | Purpose |
|----------|------|---------|
| `$ServerListPath` | 90 | Path to `server_list.txt` |
| `$IsoDir` | 91 | Path to deployment packages |
| `$DefaultIsoUrl` | 92 | Override ISO URL |
| `$RepoBaseUrl` | 93 | HTTPS base URL for URL construction |
| `$ServerDetails` | 94 | `[ServerInfo[]]` loaded from server list |
| `$DeployLog` | 95 | ArrayList of deployment log entries |

| Method | Line | Purpose |
|--------|------|---------|
| `ISODeployer()` | [L97](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#97) | Constructor: loads server list via `Load-ServerList()` |
| `_FindServerPackage()` | [L106](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#106) | Resolves server name to `output/bootable_media/` subdirectory |
| `_ResolveIsoUrl()` | [L125](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#125) | Resolves ISO URL from metadata + RepoBaseUrl |
| `_Log()` | [L151](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#151) | Adds timestamped deploy log entry |
| `_DeployViaRedfish()` | [L159](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#159) | Delegates to `Invoke-IloRedfish -Action MountAndBoot` |
| `Deploy()` | [L182](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#182) | Dispatches to Redfish method |
| `DeployAll()` | [L199](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#199) | Iterates all servers, saves deployment summary JSON |

---

## 7. iLO Redfish Integration

### 7.1 - Invoke-IloRedfish

**[`Invoke-IloRedfish.ps1`](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#19)** - [`Invoke-IloRedfish()`](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#19)
- Actions: `Mount`, `MountAndBoot`, `Boot`, `Reset`, `Eject`, `Status`
- Uses `IloRedfishSession` class for Redfish API calls
- `-Force` required for destructive actions (`MountAndBoot`, `Boot`, `Reset`) at [L87–93](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#87-93)
- Credentials from `Get-IloCredentials` at [L107](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#107)
- Redfish session at [L113](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#113)
- Session logout in `finally` block at [L155](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#155)

**Redfish API endpoints** (documented at [L11–16](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1#11-16)):
- `POST /redfish/v1/SessionService/Sessions` - login → `X-Auth-Token`
- `POST /redfish/v1/Managers/1/VirtualMedia/1/Actions/VirtualMedia.InsertMedia`
- `PATCH /redfish/v1/Systems/1` - BootSourceOverrideTarget=Cd, Enabled=Once
- `POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset` - ResetType=ForceRestart

### 7.2 - IloRedfishSession Class

**[`Automation.psm1`](../src/powershell/Automation/Automation.psm1#340)** - class starts at [L340](../src/powershell/Automation/Automation.psm1#340)

| Property | Line | Purpose |
|----------|------|---------|
| `$BaseUrl` | 341 | Redfish base URL |
| `$User` | 342 | iLO username |
| `$Password` | 343 | iLO password |
| `$SkipCert` | 344 | Skip SSL cert check |
| `$TimeoutSec` | 345 | Per-call timeout |
| `$AuthToken` | 346 | X-Auth-Token from login |
| `$SessionUri` | 347 | Session URI for logout |

| Method | Line | Purpose |
|--------|------|---------|
| `IloRedfishSession()` | [L349](../src/powershell/Automation/Automation.psm1#349) | Constructor: stores params, calls `_Login()` |
| `_Login()` | [L361](../src/powershell/Automation/Automation.psm1#361) | POST session login → extracts token |
| `_Headers()` | [L372](../src/powershell/Automation/Automation.psm1#372) | Returns `X-Auth-Token` header dict |
| `_Post()` | [L385](../src/powershell/Automation/Automation.psm1#385) | POST JSON with auth |
| `_Patch()` | [L376](../src/powershell/Automation/Automation.psm1#376) | PATCH JSON with auth |
| `_Get()` | [L394](../src/powershell/Automation/Automation.psm1#394) | GET with auth |
| `GetSystem()` | [L401](../src/powershell/Automation/Automation.psm1#401) | Returns power state, boot source, model, serial |
| `ListVirtualMedia()` | [L413](../src/powershell/Automation/Automation.psm1#413) | Enumerates virtual media devices |
| `InsertMedia()` | [L433](../src/powershell/Automation/Automation.psm1#433) | Mounts ISO URL into virtual media device |
| `EjectMedia()` | [L439](../src/powershell/Automation/Automation.psm1#439) | Ejects virtual media |
| `SetOneTimeBootCd()` | [L445](../src/powershell/Automation/Automation.psm1#445) | One-time boot override to CD |
| `ResetSystem()` | [L455](../src/powershell/Automation/Automation.psm1#455) | System reset (ForceRestart) |
| `Logout()` | [L460](../src/powershell/Automation/Automation.psm1#460) | DELETE session |

---

## 8. Installation Monitoring

### 8.1 - Start-InstallMonitor

**[`Start-InstallMonitor.ps1`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#8)** - [`Start-InstallMonitor()`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#8)
- Polls iLO Redfish + WinRM to track Windows installation phases
- Sends progress metrics and alerts to OpsRamp
- Default timeout: 7200s (2 hours), poll interval: 30s
- Creates [`InstallationMonitor`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#94) at [L49](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#49)
- Single server at [L53](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#53), bulk at [L57](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#57)

**Phase mapping** at [L88–91](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#88-91):
```
0 = Not Started → 1 = Generalize → 2 = Specialize → 3 = Running Windows → 4 = RunPhase
```

### 8.2 - InstallationMonitor Class

**[`Start-InstallMonitor.ps1`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#94)** - class starts at [L94](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#94)

| Property | Line | Purpose |
|----------|------|---------|
| `$ServerListPath` | 95 | Path to `server_list.txt` |
| `$OpsRampConfigPath` | 96 | Path to `opsramp_config.json` |
| `$Servers` | 97 | `[ServerInfo[]]` loaded from server list |
| `$Sessions` | 98 | Hashtable of monitoring sessions |
| `$MonitorLog` | 99 | ArrayList of monitoring log entries |
| `$OpsRampClient` | 100 | `OpsRamp_Client` instance for metrics |

| Method | Line | Purpose |
|--------|------|---------|
| `InstallationMonitor()` | [L106](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#106) | Constructor: loads server list, initializes OpsRamp client |
| `_InitOpsRampClient()` | [L115](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#115) | Creates `OpsRamp_Client` from config path |
| `_Log()` | [L121](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#121) | Adds timestamped monitoring log entry |
| `CheckIloStatus()` | [L126](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#126) | Ping + Redfish query → power state, boot source |
| `CheckWinRM()` | [L147](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#147) | Tests WSMan accessibility via `Test-WSMan` |
| `QueryInstallProgressWinRM()` | [L156](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#156) | Reads `HKLM:\SYSTEM\Setup` registry + Setup event log via WinRM |
| `_SendOpsRampMetric()` | [L191](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#191) | Sends progress metrics to OpsRamp |
| `_SendOpsRampAlert()` | [L198](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#198) | Sends alerts on timeout/failure/completion |
| `MonitorServer()` | [L204](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#204) | Polling loop: iLO + WinRM → progress tracking |
| `MonitorAll()` | [L285](../src/powershell/Automation/Public/Start-InstallMonitor.ps1#285) | Monitors all servers, writes summary JSON |

---

## 9. Pre & Post Build Validation

### 9.1 - Test-PreBuildValidation

**[`Test-PreBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#15)** - [`Test-PreBuildValidation()`](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#15)

Pre-build checks from the runbook:
1. OneView target identified (via `Get-OneViewServerTarget`) at [L106](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#106)
2. ISO URL reachable (HTTP HEAD) at [L120](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#120)
3. iLO credentials verified (Redfish session test) at [L131](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#131)
4. Management Point / Distribution Point reachability at [L150](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#150)
5. Audit entry recorded at [L162](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1#162)

Skip switches: `-SkipOneView`, `-SkipIlo`, `-SkipDpMp`, `-SkipIsoUrl`

### 9.2 - Test-PostBuildValidation

**[`Test-PostBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#16)** - [`Test-PostBuildValidation()`](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#16)

Post-build checks via WinRM:
1. WinRM reachable at [L89](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#89)
2. Expected hostname assigned at [L124](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#124)
3. OS version + edition verified at [L125–126](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#125-126)
4. Domain join successful at [L127](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#127)
5. HPE device drivers present at [L129](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#129)
6. ConfigMgr client healthy at [L132–133](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#132-133)
7. RDP operational at [L135](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#135)
8. Audit entry recorded at [L156](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1#156)

Skip switches: `-SkipCmClient`, `-SkipDrivers`, `-SkipRemote`

### 9.3 - Test-ServerConnectivity

**[`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#157)** - [`Test-ServerConnectivity()`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#157)

Read-only connectivity test safe during change freezes (694 lines):
- **Phase 1: Network Ping** - DNS resolution + TCP port probe at [L448–497](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#448-497)
- **Phase 2: Auth Connect** - Full authentication via module (SCOM or OneView) + immediate disconnect at [L502–583](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#502-583)
- Host resolution: `-ManagementHost` → `$env:MAINTENANCE_HOST` → `connection_hosts.json` → interactive prompt
- `-DryRun` returns mock data at [L393](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#393)
- `-Json` for API integration at [L598](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#598)

---

## 10. PowerShell Execution Utilities

### 10.1 - Local PowerShell Execution

**[`Invoke-PowerShellScript.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#5)** - [`Invoke-PowerShellScript()`](../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#5)
- Spawns `powershell.exe` (Windows) or `pwsh` (Linux) as a new process via `System.Diagnostics.Process`
- Parameters: `Script`, `CaptureOutput`, `TimeoutSeconds`, `ExecutionPolicy`
- Configurable timeout (default: 300s), execution policy (default: `Bypass`)
- Returns `@{ Success, Output }`

### 10.2 - Remote PowerShell via WinRM

**[`Invoke-PowerShellWinRM.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#5)** - [`Invoke-PowerShellWinRM()`](../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#5)
- Creates `New-PSSession` with NTLM authentication
- Executes script block remotely via `Invoke-Command`
- Cleans up session after execution
- Parameters: `Script`, `Server`, `Username`, `Password` (SecureString), `Transport`, `TimeoutSeconds`
- Returns `@{ Success, Output }`

---

## 11. OpsRamp Integration

### 11.1 - OpsRamp_Client Class

Defined in [`Automation.psm1`](../src/powershell/Automation/Automation.psm1#136), fully documented in [§11.2 of this document](#markdown-header-112-opsramp-entry-points).

| Member | Line | Purpose |
|--------|------|---------|
| `OpsRamp_Client()` | [L150](../src/powershell/Automation/Automation.psm1#150) | Constructor: loads config, creates HttpClient |
| `_LoadConfig()` | [L161](../src/powershell/Automation/Automation.psm1#161) | Loads config, overrides credentials from env vars |
| `EnsureToken()` | [L177](../src/powershell/Automation/Automation.psm1#177) | OAuth2 client_credentials flow, token caching with 90% TTL |
| `_MakeRequest()` | [L209](../src/powershell/Automation/Automation.psm1#209) | Generic HTTP request with auth |
| `SendMetric()` | [L240](../src/powershell/Automation/Automation.psm1#240) | POST metric gauge |
| `SendAlert()` | [L257](../src/powershell/Automation/Automation.psm1#257) | POST alert |
| `SendEvent()` | [L271](../src/powershell/Automation/Automation.psm1#271) | POST event |
| `BatchSendMetrics()` | [L284](../src/powershell/Automation/Automation.psm1#284) | Batch POST metrics |
| `ReportBuildStatus()` | [L289](../src/powershell/Automation/Automation.psm1#289) | Build status metric + failure alert |
| `ReportDeploymentStatus()` | [L301](../src/powershell/Automation/Automation.psm1#301) | Deploy status metric + failure alert |
| `ReportInstallationProgress()` | [L313](../src/powershell/Automation/Automation.psm1#313) | Progress percent + elapsed seconds |
| `ReportVulnerabilityScan()` | [L322](../src/powershell/Automation/Automation.psm1#322) | Vuln counts + critical alert |

### 11.2 - OpsRamp Entry Points

**[`Invoke-OpsRampClient.ps1`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1)**

| Function | Line | Purpose |
|----------|------|---------|
| [`Invoke-OpsRampClient()`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1#5) | L5 | Factory: creates `OpsRamp_Client` instance from config path |
| [`Invoke-OpsRamp()`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1#29) | L29 | Quick connectivity test - returns boolean from `EnsureToken()` |

---

## 12. Credential Resolution

**[`Credentials.ps1`](../src/powershell/Automation/Private/Credentials.ps1)** - 201 lines

**Resolution order** (documented at [L5–14](../src/powershell/Automation/Private/Credentials.ps1#5-14)):
1. Environment variable (CI pre-fetches from CyberArk)
2. CyberArk CCP CLI (`ark_ccl` / `ark_cc` / `CyberArk.CLI` on PATH)
3. CyberArk AIM REST API (`$env:AIM_WEBSERVICE_URL` or `$env:CYBERARK_CCP_URL`)
4. Safe default / empty string

| Function | Line | Resolves |
|----------|------|----------|
| [`_Resolve-Credential()`](../src/powershell/Automation/Private/Credentials.ps1#17) | L17 | Core resolver - env → CLI → REST → default |
| [`Get-EnvCredential()`](../src/powershell/Automation/Private/Credentials.ps1#127) | L127 | Generic env-var credential |
| [`Get-IloCredentials()`](../src/powershell/Automation/Private/Credentials.ps1#145) | L145 | `ILO_USER` / `ILO_PASSWORD` |
| [`Get-ScomCredentials()`](../src/powershell/Automation/Private/Credentials.ps1#158) | L158 | `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` |
| [`Get-OpenViewCredentials()`](../src/powershell/Automation/Private/Credentials.ps1#173) | L173 | OpenView legacy credentials |
| [`Get-OneViewCredentials()`](../src/powershell/Automation/Private/Credentials.ps1#183) | L183 | `ONEVIEW_USER` / `ONEVIEW_PASSWORD` |
| [`Get-SmtpCredentials()`](../src/powershell/Automation/Private/Credentials.ps1#193) | L193 | SMTP email credentials |

---

## 13. Inventory & Configuration

### 13.1 - Inventory Functions

**[`Inventory.ps1`](../src/powershell/Automation/Private/Inventory.ps1)** - 99 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Load-ServerList()`](../src/powershell/Automation/Private/Inventory.ps1#5) | L5 | Reads `server_list.txt` → `ServerInfo[]` or plain strings |
| [`Load-ClusterCatalogue()`](../src/powershell/Automation/Private/Inventory.ps1#46) | L46 | Loads `clusters_catalogue.json` → inner `clusters` hashtable |
| [`Test-ClusterDefinition()`](../src/powershell/Automation/Private/Inventory.ps1#62) | L62 | Validates cluster definition fields: `display_name`, `servers`, `scom_group`, `environment` |
| [`New-ServerInfo()`](../src/powershell/Automation/Private/Inventory.ps1#83) | L83 | Factory for `ServerInfo` objects |

### 13.2 - Configuration Functions

**[`Config.ps1`](../src/powershell/Automation/Private/Config.ps1)** - 126 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Import-JsonConfig()`](../src/powershell/Automation/Private/Config.ps1#5) | L5 | Reads JSON file, converts to hashtable, substitutes `${VAR}` env references |
| [`Import-YamlConfig()`](../src/powershell/Automation/Private/Config.ps1#44) | L44 | Reads YAML file, converts to hashtable |
| [`_PS_ConvertTo-Hashtable()`](../src/powershell/Automation/Private/Config.ps1#64) | L64 | Recursively converts PSCustomObject → hashtable |
| [`_PS_ReplaceEnvVars()`](../src/powershell/Automation/Private/Config.ps1#88) | L88 | Replaces `${VAR}` placeholders with environment variable values |
| [`_PS_SubstituteEnvVars()`](../src/powershell/Automation/Private/Config.ps1#108) | L108 | Recursive env-var substitution across all nested hashtables |

### 13.3 - Validator Functions

| Function | File | Purpose |
|----------|------|---------|
| [`Test-BuildParams()`](../src/powershell/Automation/Public/Test-BuildParams.ps1#5) | Validates base ISO path exists |
| [`Test-ClusterId()`](../src/powershell/Automation/Public/Test-ClusterId.ps1#5) | Validates cluster ID in catalogue, checks required fields |
| [`Test-ServerList()`](../src/powershell/Automation/Public/Test-ServerList.ps1#5) | Validates server list file, strips comments and empty lines |

---

## 14. Process Execution & Retry

**[`Executor.ps1`](../src/powershell/Automation/Private/Executor.ps1)** - 108 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Invoke-NativeCommand()`](../src/powershell/Automation/Private/Executor.ps1#5) | L5 | Executes external program via `System.Diagnostics.Process`, captures stdout/stderr |
| [`Invoke-NativeCommandWithRetry()`](../src/powershell/Automation/Private/Executor.ps1#68) | L68 | Exponential back-off retry wrapper (default: 3 attempts, 5s base delay) |
| [`New-CommandResult()`](../src/powershell/Automation/Private/Executor.ps1#99) | L99 | Factory for `CommandResult` objects |

**Used by**: [`FirmwareUpdater._RunSut()`](../src/powershell/Automation/Public/Update-Firmware.ps1#154), [`WindowsPatcher._ApplyPatchesDism()`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#138)

---

## 15. File I/O & Path Resolution

### 15.1 - File I/O Functions

**[`FileIO.ps1`](../src/powershell/Automation/Private/FileIO.ps1)** - 116 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Ensure-DirectoryExists()`](../src/powershell/Automation/Private/FileIO.ps1#5) | L5 | Creates directory tree if missing |
| [`Save-Json()`](../src/powershell/Automation/Private/FileIO.ps1#18) | L18 | Serializes object to JSON file |
| [`Load-Json()`](../src/powershell/Automation/Private/FileIO.ps1#35) | L35 | Deserializes JSON file |
| [`Save-JsonResult()`](../src/powershell/Automation/Private/FileIO.ps1#53) | L53 | Saves to `{outputDir}/{category}/{basename}_{timestamp}.json` |
| [`Test-PathEx()`](../src/powershell/Automation/Private/FileIO.ps1#77) | L77 | Enhanced Test-Path with better error messages |
| [`_FileIO_DeepHashtable()`](../src/powershell/Automation/Private/FileIO.ps1#94) | L94 | Internal: deep conversion of PSCustomObject tree to hashtable |

### 15.2 - Path Resolution

**[`PathResolver.ps1`](../src/powershell/Automation/Private/PathResolver.ps1)** - 53 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Get-ProjectRoot()`](../src/powershell/Automation/Private/PathResolver.ps1#5) | L5 | Walks up from cwd looking for `kilo.json` or `Makefile` |
| [`Get-LogDirectory()`](../src/powershell/Automation/Private/PathResolver.ps1#32) | L32 | Returns `{projectRoot}/generated/logs/{category}` |

---

## 16. Logging & Audit

### 16.1 - Logging Functions

**[`Logging.ps1`](../src/powershell/Automation/Private/Logging.ps1)** - 97 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Initialize-Logging()`](../src/powershell/Automation/Private/Logging.ps1#6) | L6 | Sets up log directory, creates timestamped log file |
| [`Get-Logger()`](../src/powershell/Automation/Private/Logging.ps1#59) | L59 | Returns logger object with Info/Warning/Error/Debug methods |

### 16.2 - Audit Logger

**[`Audit.ps1`](../src/powershell/Automation/Private/Audit.ps1#5)** - [`New-AuditLogger()`](../src/powershell/Automation/Private/Audit.ps1#5)
- Factory for `AuditLogger` class instances (20 lines)

Also defined as class in [`Automation.psm1`](../src/powershell/Automation/Automation.psm1#38) (documented in [§1.1](#markdown-header-11-root-module-loader)):
- [`AuditLogger.Log()`](../src/powershell/Automation/Automation.psm1#66) - adds entry with action, status, server, details
- [`AuditLogger.Save()`](../src/powershell/Automation/Automation.psm1#82) - writes JSON file
- [`AuditLogger.AppendToMaster()`](../src/powershell/Automation/Automation.psm1#99) - appends to master log

### 16.3 - Timestamp Helpers

**[`Base.ps1`](../src/powershell/Automation/Private/Base.ps1)** - 91 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Get-UtcTimestamp()`](../src/powershell/Automation/Private/Base.ps1#5) | L5 | ISO-8601 UTC timestamp |
| [`Get-LocalTimestamp()`](../src/powershell/Automation/Private/Base.ps1#13) | L13 | ISO-8601 local timestamp |
| [`Get-UtcFileTimestamp()`](../src/powershell/Automation/Private/Base.ps1#21) | L21 | `yyyy-MM-ddTHH-mm-ssZ` (filesystem-safe) |
| [`Get-UtcApiTimestamp()`](../src/powershell/Automation/Private/Base.ps1#29) | L29 | SCOM REST API format |
| [`Convert-ToUtcIso8601()`](../src/powershell/Automation/Private/Base.ps1#37) | L37 | Converts arbitrary datetime to UTC ISO-8601 |
| [`Get-LogTimestamp()`](../src/powershell/Automation/Private/Base.ps1#51) | L51 | Log-friendly timestamp |
| [`Get-FileTimestamp()`](../src/powershell/Automation/Private/Base.ps1#59) | L59 | File-safe timestamp |
| [`Get-DateFileTimestamp()`](../src/powershell/Automation/Private/Base.ps1#67) | L67 | Date-only file timestamp |
| [`New-AutomationBase()`](../src/powershell/Automation/Private/Base.ps1#75) | L75 | Factory for `AutomationBase` class |

---

## 17. Script Helpers

### 17.1 - PowerShell Profile Setup

**[`scripts/Setup-Profile.ps1`](../scripts/Setup-Profile.ps1)** - 294 lines

Configures PowerShell profiles to auto-import the Automation module:
- Copies WIP profile templates to live profile locations (Terminal, VS Code)
- Injects Automation module import block with machine-specific absolute path
- Supports `-Merge` (preserve user customizations), `-Uninstall`, `-DryRun`
- Platform-aware: `windowspsprofile.ps1` (Windows) / `psprofile.ps1` (Linux)

### 17.2 - CI/Security & Lint Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`ci-security-check.ps1`](../scripts/ci-security-check.ps1) | 143 lines | PSScriptAnalyzer security scan + secrets detection + JSON validation |
| [`lint.ps1`](../scripts/lint.ps1) | 246 lines | Two-phase lint: syntax validation → PSScriptAnalyzer code quality |
| [`lint-make.ps1`](../scripts/lint-make.ps1) | 70 lines | Checkmake Makefile validation (Windows-compatible) |
| [`run-checkmake.ps1`](../scripts/run-checkmake.ps1) | 57 lines | Standalone checkmake runner |
| [`prune-logs.ps1`](../scripts/prune-logs.ps1) | 152 lines | Prunes excess log files, keeps max per type |

### 17.3 - Setup & Bootstrap Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`setup-runner.ps1`](../scripts/setup-runner.ps1) | 436 lines | Full offline-capable runner setup: modules (Pester, PSScriptAnalyzer, PlatyPS) + binaries (Oh My Posh, make, checkmake) |
| [`setup-scom.ps1`](../scripts/setup-scom.ps1) | 70 lines | Validates SCOM setup: module, credentials, config file |
| [`setup-oneview.ps1`](../scripts/setup-oneview.ps1) | 89 lines | Validates OneView setup: module, credentials, config file |
| [`cyberark-bootstrap.ps1`](../scripts/cyberark-bootstrap.ps1) | 139 lines | Fetches secrets from CyberArk CCP, exports as env vars for CI |

### 17.4 - Documentation & Coverage Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`Generate-PSDocs.ps1`](../scripts/Generate-PSDocs.ps1) | 269 lines | Auto-generates Markdown API reference from comment-based help blocks |
| [`coverage-report.ps1`](../scripts/coverage-report.ps1) | 327 lines | Runs Pester with code coverage, generates Cobertura XML + Markdown report |
| [`CoverageSummary.ps1`](../scripts/CoverageSummary.ps1) | 121 lines | Converts Cobertura XML to human-readable table |
| [`Show-Help.ps1`](../scripts/Show-Help.ps1) | 35 lines | Displays Makefile documented targets |

---

## 18. Configuration Files

All configs loaded from `configs/` directory:

| File | Purpose | Loaded By |
|------|---------|-----------|
| **`request_types.json`** | Request type → handler mapping, CI stage map | [`Router.ps1`](../src/powershell/Automation/Private/Router.ps1#9) |
| **`server_list.txt`** | Server hostnames with optional IPMI/iLO IPs | [`Inventory.ps1`](../src/powershell/Automation/Private/Inventory.ps1#5) |
| **`clusters_catalogue.json`** | Cluster definitions with servers, SCOM groups, OneView scopes | [`Inventory.ps1`](../src/powershell/Automation/Private/Inventory.ps1#46) |
| **`hpe_firmware_drivers_nov2025.json`** | HPE SUT firmware/driver component manifest | [`Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1#97) |
| **`windows_patches.json`** | Windows security patch KB list (MSU packages) | [`Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#100) |
| **`opsramp_config.json`** | OpsRamp API credentials + base URL | [`OpsRamp_Client`](../src/powershell/Automation/Automation.psm1#161) |
| **`connection_hosts.json`** | SCOM/OneView management hosts per environment | [`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#281) |
| **`scom_config.json`** | SCOM connection config (module, WinRM, credentials) | [`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#347) |
| **`oneview_config.json`** | OneView connection config (module, WinRM, credentials) | [`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1#353) |
| **`clusters_catalogue.scom.json`** | SCOM cluster definitions | Maintenance mode |
| **`clusters_catalogue.examples-only.json`** | Example cluster definitions | Reference |
| **`servers_catalogue.oneview.json`** | OneView server definitions | OneView queries |
| **`configmgr_config.json`** | ConfigMgr site connection details | Build pipeline |
| **`email_distribution_lists.json`** | Maintenance notification recipients | Notifications |
| ~~maintenance-only configs~~ | *See [BitBucket_Code_Map_Maitenance_Mode.md §11](BitBucket_Code_Map_Maitenance_Mode.md)* | - |

---

## 19. Testing

### 19.1 - Pester Unit Tests

| Test File | Tests |
|-----------|-------|
| [`Audit.Unit.Tests.ps1`](../tests/powershell/Audit.Unit.Tests.ps1) | AuditLogger class |
| [`Config.Unit.Tests.ps1`](../tests/powershell/Config.Unit.Tests.ps1) | Import-JsonConfig, Import-YamlConfig, ConvertTo-Hashtable, env-var substitution |
| [`Credentials.Unit.Tests.ps1`](../tests/powershell/Credentials.Unit.Tests.ps1) | Credential resolution, CyberArk fallback |
| [`Executor.Unit.Tests.ps1`](../tests/powershell/Executor.Unit.Tests.ps1) | Invoke-NativeCommand, Invoke-NativeCommandWithRetry, New-CommandResult |
| [`FileIO.Unit.Tests.ps1`](../tests/powershell/FileIO.Unit.Tests.ps1) | Ensure-DirectoryExists, Save-Json, Load-Json, Save-JsonResult |
| [`Get-OneViewServerTarget.Unit.Tests.ps1`](../tests/powershell/Get-OneViewServerTarget.Unit.Tests.ps1) | OneView server query, identifier resolution |
| [`Inventory.Unit.Tests.ps1`](../tests/powershell/Inventory.Unit.Tests.ps1) | Load-ServerList, Load-ClusterCatalogue, Test-ClusterDefinition, New-ServerInfo |
| [`Invoke-IloRedfish.Unit.Tests.ps1`](../tests/powershell/Invoke-IloRedfish.Unit.Tests.ps1) | iLO Redfish actions (Mount, MountAndBoot, Eject, Status) |
| [`Invoke-IsoDeploy.Unit.Tests.ps1`](../tests/powershell/Invoke-IsoDeploy.Unit.Tests.ps1) | ISO deployment orchestrator |
| [`Invoke-OpsRampClient.Unit.Tests.ps1`](../tests/powershell/Invoke-OpsRampClient.Unit.Tests.ps1) | OpsRamp client, token management |
| [`New-IsoBuild.Unit.Tests.ps1`](../tests/powershell/New-IsoBuild.Unit.Tests.ps1) | ConfigMgr bootable ISO builder |
| [`New-OneViewMaintenanceScript.Unit.Tests.ps1`](../tests/powershell/New-OneViewMaintenanceScript.Unit.Tests.ps1) | OneView maintenance script generation |
| [`New-ScomConnection.Unit.Tests.ps1`](../tests/powershell/New-ScomConnection.Unit.Tests.ps1) | SCOM connection, REST connection |
| [`New-ScomMaintenanceScript.Unit.Tests.ps1`](../tests/powershell/New-ScomMaintenanceScript.Unit.Tests.ps1) | SCOM maintenance script generation |
| [`New-Uuid.Unit.Tests.ps1`](../tests/powershell/New-Uuid.Unit.Tests.ps1) | Deterministic UUID generation |
| [`Publish-BootIso.Unit.Tests.ps1`](../tests/powershell/Publish-BootIso.Unit.Tests.ps1) | ISO publish to HTTPS repo |
| [`Router.Unit.Tests.ps1`](../tests/powershell/Router.Unit.Tests.ps1) | Invoke-RoutedRequest, Get-RouteMap, request type dispatch |
| [`Set-MaintenanceMode.Unit.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1) | *See GitHub maintenance mode code map* |
| [`Start-AutomationOrchestrator.Unit.Tests.ps1`](../tests/powershell/Start-AutomationOrchestrator.Unit.Tests.ps1) | Orchestrator entry point |
| [`Start-InstallMonitor.Unit.Tests.ps1`](../tests/powershell/Start-InstallMonitor.Unit.Tests.ps1) | Installation monitoring |
| [`Start-PhysicalServerBuild.Unit.Tests.ps1`](../tests/powershell/Start-PhysicalServerBuild.Unit.Tests.ps1) | End-to-end build orchestrator |
| [`Test-PostBuildValidation.Unit.Tests.ps1`](../tests/powershell/Test-PostBuildValidation.Unit.Tests.ps1) | Post-build validation checks |
| [`Test-PreBuildValidation.Unit.Tests.ps1`](../tests/powershell/Test-PreBuildValidation.Unit.Tests.ps1) | Pre-build validation checks |
| [`Test-ServerConnectivity.Tests.ps1`](../tests/powershell/Test-ServerConnectivity.Tests.ps1) | SCOM/OneView connectivity |
| [`Update-Firmware.Unit.Tests.ps1`](../tests/powershell/Update-Firmware.Unit.Tests.ps1) | Firmware ISO builder |
| [`Update-WindowsSecurity.Unit.Tests.ps1`](../tests/powershell/Update-WindowsSecurity.Unit.Tests.ps1) | Windows patcher |
| [`Validators.Unit.Tests.ps1`](../tests/powershell/Validators.Unit.Tests.ps1) | Test-BuildParams, Test-ClusterId, Test-ServerList |

### 19.2 - Test Execution Scripts

| Script | Purpose |
|--------|---------|
| [`run-tests.ps1`](../scripts/run-tests.ps1) | Main test runner: auto-repairs Pester, runs all Pester tests with summary |
| [`run-automation-mode-tests.ps1`](../scripts/run-automation-mode-tests.ps1) | Automation mode tests |
| [`run-maint-mode-tests.ps1`](../scripts/run-maint-mode-tests.ps1) | High-priority maintenance mode tests only |
| [`run-maintenance-tests.ps1`](../scripts/run-maintenance-tests.ps1) | Full maintenance test suite with environment/DateTime/connection filters |
| [`test-maintenance-connection.ps1`](../scripts/test-maintenance-connection.ps1) | Connectivity test for SCOM/OneView |
| [`validate-maintenance-config.ps1`](../scripts/validate-maintenance-config.ps1) | Configuration file + module validation |

### 19.3 - Coverage & Lint

| Script | Purpose |
|--------|---------|
| [`coverage-report.ps1`](../scripts/coverage-report.ps1) | Cobertura XML coverage + Markdown report |
| [`CoverageSummary.ps1`](../scripts/CoverageSummary.ps1) | Human-readable coverage table |
| [`lint.ps1`](../scripts/lint.ps1) | Syntax validation + PSScriptAnalyzer |
| [`ci-security-check.ps1`](../scripts/ci-security-check.ps1) | Security scan: PSScriptAnalyzer + secrets detection + JSON validation |

---

## 20. Quick Navigation

| User Journey | Entry Point | Handler | Key File | Lines |
|--------------|-------------|---------|----------|-------|
| **End-to-end build** | `Start-PhysicalServerBuild` | Full runbook orchestrator | [`Start-PhysicalServerBuild.ps1`](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1) | L18–272 |
| **Build ISO** | `New-IsoBuild` | ConfigMgr bootable media | [`New-IsoBuild.ps1`](../src/powershell/Automation/Public/New-IsoBuild.ps1) | L13–247 |
| **Publish ISO** | `Publish-BootIso` | HTTPS repo publish | [`Publish-BootIso.ps1`](../src/powershell/Automation/Public/Publish-BootIso.ps1) | L12–132 |
| **iLO Redfish** | `Invoke-IloRedfish` | iLO Redfish actions | [`Invoke-IloRedfish.ps1`](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1) | L19–161 |
| **Deploy ISO** | `Invoke-IsoDeploy` | Bulk deploy orchestrator | [`Invoke-IsoDeploy.ps1`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1) | L20–244 |
| **Update firmware** | `Update-Firmware` | `FirmwareUpdater` | [`Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1) | L19–244 |
| **Patch Windows** | `Invoke-WindowsSecurityUpdate` | `WindowsPatcher` | [`Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1) | L8–235 |
| **Pre-build check** | `Test-PreBuildValidation` | Validation checklist | [`Test-PreBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1) | L15–182 |
| **Post-build check** | `Test-PostBuildValidation` | Validation via WinRM | [`Test-PostBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1) | L16–178 |
| **Connectivity test** | `Test-ServerConnectivity` | Network + auth check | [`Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1) | L157–694 |
| **Monitor install** | `Start-InstallMonitor` | `InstallationMonitor` | [`Start-InstallMonitor.ps1`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1) | L8–324 |
| **OpsRamp metric** | `Invoke-OpsRampClient` | `OpsRamp_Client` | [`Invoke-OpsRampClient.ps1`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1) | L5–50 |
| **Local script** | `Invoke-PowerShellScript` | New process | [`Invoke-PowerShellScript.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1) | L5–74 |
| **Remote WinRM** | `Invoke-PowerShellWinRM` | `New-PSSession` | [`Invoke-PowerShellWinRM.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1) | L5–60 |
| **Generate UUID** | `New-Uuid` | SHA-256 hash | [`New-Uuid.ps1`](../src/powershell/Automation/Public/New-Uuid.ps1) | L8–64 |
| **OneView query** | `Get-OneViewServerTarget` | REST /rest/server-hardware | [`Get-OneViewServerTarget.ps1`](../src/powershell/Automation/Public/Get-OneViewServerTarget.ps1) | L14–172 |
