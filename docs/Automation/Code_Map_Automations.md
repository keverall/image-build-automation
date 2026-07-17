# Automation Code Map

## Table of Contents

- [1. Module Loading & Bootstrap](#1-module-loading-and-bootstrap)
  - [1.1 - Root Module Loader](#11---root-module-loader)
  - [1.1 - Root Module Loader](#11---root-module-loader-1)
  - [1.2 - Private Script Load Order](#12---private-script-load-order)
  - [1.2 - Private Script Load Order](#12---private-script-load-order-1)
  - [1.3 - Public Function Load Order](#13---public-function-load-order)
  - [1.3 - Public Function Load Order](#13---public-function-load-order-1)
- [2. Request Routing & Control Surfaces](#2-request-routing-and-control-surfaces)
  - [2.1 - Request Router](#21---request-router)
  - [2.1 - Request Router](#21---request-router-1)
  - [2.2 - Unified Orchestrator Entry Point](#22---unified-orchestrator-entry-point)
  - [2.2 - Unified Orchestrator Entry Point](#22---unified-orchestrator-entry-point-1)
  - [2.3 - Request Validation](#23---request-validation)
  - [2.3 - Request Validation](#23---request-validation-1)
  - [2.4 - CI Pipeline Surface](#24---ci-pipeline-surface)
  - [2.4 - CI Pipeline Surface](#24---ci-pipeline-surface-1)
  - [2.5 - iRequest/ISAPI Surface](#25---irequestisapi-surface)
  - [2.5 - iRequest/ISAPI Surface](#25---irequestisapi-surface-1)
  - [2.6 - Scheduled Task Surface](#26---scheduled-task-surface)
  - [2.6 - Scheduled Task Surface](#26---scheduled-task-surface-1)
  - [2.7 - GitLab CI/CD Surface](#27---gitlab-cicd-surface)
  - [2.7 - GitLab CI/CD Surface](#27---gitlab-cicd-surface-1)
- [3. ISO Build Pipeline](#3-iso-build-pipeline)
  - [3.1 - ISO Build Orchestrator](#31---iso-build-orchestrator)
  - [3.1 - ISO Build Orchestrator](#31---iso-build-orchestrator-1)
  - [3.2 - UUID Generation](#32---uuid-generation)
  - [3.2 - UUID Generation](#32---uuid-generation-1)
- [4. Firmware ISO Builder](#4-firmware-iso-builder)
  - [4.1 - Firmware Update Function](#41---firmware-update-function)
  - [4.1 - Firmware Update Function](#41---firmware-update-function-1)
  - [4.2 - FirmwareUpdater Class](#42---firmwareupdater-class)
  - [4.2 - FirmwareUpdater Class](#42---firmwareupdater-class-1)
- [5. Windows Security Patching](#5-windows-security-patching)
  - [5.1 - Invoke-WindowsSecurityUpdate](#51---invoke-windowssecurityupdate)
  - [5.1 - Invoke-WindowsSecurityUpdate](#51---invoke-windowssecurityupdate-1)
  - [5.2 - WindowsPatcher Class](#52---windowspatcher-class)
  - [5.2 - WindowsPatcher Class](#52---windowspatcher-class-1)
- [6. ISO Deployment](#6-iso-deployment)
  - [6.1 - Invoke-IsoDeploy](#61---invoke-isodeploy)
  - [6.1 - Invoke-IsoDeploy](#61---invoke-isodeploy-1)
  - [6.2 - ISODeployer Class](#62---isodeployer-class)
  - [6.2 - ISODeployer Class](#62---isodeployer-class-1)
- [7. Installation Monitoring](#7-installation-monitoring)
  - [7.1 - Start-InstallMonitor](#71---start-installmonitor)
  - [7.1 - Start-InstallMonitor](#71---start-installmonitor-1)
  - [7.2 - InstallationMonitor Class](#72---installationmonitor-class)
  - [7.2 - InstallationMonitor Class](#72---installationmonitor-class-1)
- [8. PowerShell Execution Utilities](#8-powershell-execution-utilities)
  - [8.1 - Local PowerShell Execution](#81---local-powershell-execution)
  - [8.1 - Local PowerShell Execution](#81---local-powershell-execution-1)
  - [8.2 - Remote PowerShell via WinRM](#82---remote-powershell-via-winrm)
  - [8.2 - Remote PowerShell via WinRM](#82---remote-powershell-via-winrm-1)
- [9. OpsRamp Integration](#9-opsramp-integration)
  - [9.1 - OpsRamp_Client Class](#91---opsramp_client-class)
  - [9.1 - OpsRamp_Client Class](#91---opsramp_client-class-1)
  - [9.2 - OpsRamp Entry Points](#92---opsramp-entry-points)
  - [9.2 - OpsRamp Entry Points](#92---opsramp-entry-points-1)
- [10. Credential Resolution](#10-credential-resolution)
- [11. Inventory & Configuration](#11-inventory-and-configuration)
  - [11.1 - Inventory Functions](#111---inventory-functions)
  - [11.1 - Inventory Functions](#111---inventory-functions-1)
  - [11.2 - Configuration Functions](#112---configuration-functions)
  - [11.2 - Configuration Functions](#112---configuration-functions-1)
  - [11.3 - Validator Functions](#113---validator-functions)
  - [11.3 - Validator Functions](#113---validator-functions-1)
- [12. Process Execution & Retry](#12-process-execution-and-retry)
- [13. File I/O & Path Resolution](#13-file-io-and-path-resolution)
  - [13.1 - File I/O Functions](#131---file-io-functions)
  - [13.1 - File I/O Functions](#131---file-io-functions-1)
  - [13.2 - Path Resolution](#132---path-resolution)
  - [13.2 - Path Resolution](#132---path-resolution-1)
- [14. Logging & Audit](#14-logging-and-audit)
  - [14.1 - Logging Functions](#141---logging-functions)
  - [14.1 - Logging Functions](#141---logging-functions-1)
  - [14.2 - Audit Logger](#142---audit-logger)
  - [14.2 - Audit Logger](#142---audit-logger-1)
  - [14.3 - Timestamp Helpers](#143---timestamp-helpers)
  - [14.3 - Timestamp Helpers](#143---timestamp-helpers-1)
- [15. Script Helpers](#15-script-helpers)
  - [15.1 - PowerShell Profile Setup](#151---powershell-profile-setup)
  - [15.1 - PowerShell Profile Setup](#151---powershell-profile-setup-1)
  - [15.2 - CI/Security & Lint Scripts](#152---cisecurity-and-lint-scripts)
  - [15.2 - CI/Security & Lint Scripts](#152---cisecurity-and-lint-scripts-1)
  - [15.3 - Setup & Bootstrap Scripts](#153---setup-and-bootstrap-scripts)
  - [15.3 - Setup & Bootstrap Scripts](#153---setup-and-bootstrap-scripts-1)
  - [15.4 - Documentation & Coverage Scripts](#154---documentation-and-coverage-scripts)
  - [15.4 - Documentation & Coverage Scripts](#154---documentation-and-coverage-scripts-1)
- [16. Configuration Files](#16-configuration-files)
- [17. Testing](#17-testing)
  - [17.1 - Pester Unit Tests](#171---pester-unit-tests)
  - [17.1 - Pester Unit Tests](#171---pester-unit-tests-1)
  - [17.2 - Test Execution Scripts](#172---test-execution-scripts)
  - [17.2 - Test Execution Scripts](#172---test-execution-scripts-1)
  - [17.3 - Coverage & Lint](#173---coverage-and-lint)
  - [17.3 - Coverage & Lint](#173---coverage-and-lint-1)
- [18. Quick Navigation](#18-quick-navigation)


<a id="top"></a>
This document maps every code location in the automation module **excluding** maintenance mode (which is fully documented in [`Code_Map_Maitenance_Mode.md`](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)). It is organized in the **chronological order a user or caller encounters each feature** - from module loading, through request routing, ISO builds, firmware/Windows patching, deployment, monitoring, and OpsRamp reporting.
This document maps every code location in the automation module **excluding** maintenance mode (which is fully documented in [`Code_Map_Maitenance_Mode.md`](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)). It is organized in the **chronological order a user or caller encounters each feature** - from module loading, through request routing, ISO builds, firmware/Windows patching, deployment, monitoring, and OpsRamp reporting.

> **Source root**: [`src/powershell/Automation/`](../../src/powershell/Automation/)
> **Module manifest**: [`Automation.psd1`](../../src/powershell/Automation/Automation.psd1)
> **Module loader**: [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1) (509 lines)

---

<a name="1-module-loading-and-bootstrap"></a>
## 1. Module Loading & Bootstrap

Before any function can be called, the `Automation` module must be loaded. This loads all shared types, private helpers (in dependency order), and public functions.

<a name="11---root-module-loader"></a>
### 1.1 - Root Module Loader
<a name="11---root-module-loader-1"></a>
### 1.1 - Root Module Loader

**[`Automation.psm1`](../../src/powershell/Automation/Automation.psm1)** - 509 lines
**[`Automation.psm1`](../../src/powershell/Automation/Automation.psm1)** - 509 lines

| Section | Lines | Content |
|---------|-------|---------|
| Shared value type | [L19–33](../../src/powershell/Automation/Automation.psm1#L19-L33) | `CommandResult` class - holds `ReturnCode`, `StandardOutput`, `StandardError`, `Success` |
| Shared reference type | [L38–106](../../src/powershell/Automation/Automation.psm1#L38-L106) | `AuditLogger` class - timestamped JSON audit log with `Log()`, `Save()`, `AppendToMaster()` |
| Shared HTTP client | [L136–335](../../src/powershell/Automation/Automation.psm1#L136-L335) | `OpsRamp_Client` class - OAuth2 token management, REST calls, metric/alert/event senders |
| Base class | [L340–392](../../src/powershell/Automation/Automation.psm1#L340-L392) | `AutomationBase` class - config dir, output dir, dry-run flag, audit, `RunCommand()` |
| Shared value type | [L19–33](../../src/powershell/Automation/Automation.psm1#L19-L33) | `CommandResult` class - holds `ReturnCode`, `StandardOutput`, `StandardError`, `Success` |
| Shared reference type | [L38–106](../../src/powershell/Automation/Automation.psm1#L38-L106) | `AuditLogger` class - timestamped JSON audit log with `Log()`, `Save()`, `AppendToMaster()` |
| Shared HTTP client | [L136–335](../../src/powershell/Automation/Automation.psm1#L136-L335) | `OpsRamp_Client` class - OAuth2 token management, REST calls, metric/alert/event senders |
| Base class | [L340–392](../../src/powershell/Automation/Automation.psm1#L340-L392) | `AutomationBase` class - config dir, output dir, dry-run flag, audit, `RunCommand()` |
| Private script load | [L397–421](../../src/powershell/Automation/Automation.psm1#L397-L421) | Dot-sources `Private/*.ps1` in dependency order (see §1.2) |
| Public script load | [L424–429](../../src/powershell/Automation/Automation.psm1#L424-L429) | Dot-sources `Public/*.ps1` alphabetically |
| Export surface | [L433–505](../../src/powershell/Automation/Automation.psm1#L433-L505) | `Export-ModuleMember` - explicit public API (55 functions) |
| Export surface | [L433–505](../../src/powershell/Automation/Automation.psm1#L433-L505) | `Export-ModuleMember` - explicit public API (55 functions) |

<a name="12---private-script-load-order"></a>
### 1.2 - Private Script Load Order
<a name="12---private-script-load-order-1"></a>
### 1.2 - Private Script Load Order

Dot-sourced in dependency order by [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1#L402-L413):

| Order | File | Purpose |
|-------|------|---------|
| 1 | [`Audit.ps1`](../../src/powershell/Automation/Private/Audit.ps1) | `New-AuditLogger` factory |
| 2 | [`Config.ps1`](../../src/powershell/Automation/Private/Config.ps1) | `Import-JsonConfig`, `Import-YamlConfig`, `_PS_ConvertTo-Hashtable`, env-var substitution |
| 3 | [`Credentials.ps1`](../../src/powershell/Automation/Private/Credentials.ps1) | `Get-EnvCredential`, `Get-IloCredentials`, `Get-ScomCredentials`, `Get-OneViewCredentials`, CyberArk CCP fallback |
| 4 | [`Executor.ps1`](../../src/powershell/Automation/Private/Executor.ps1) | `Invoke-NativeCommand`, `Invoke-NativeCommandWithRetry`, `New-CommandResult` |
| 5 | [`FileIO.ps1`](../../src/powershell/Automation/Private/FileIO.ps1) | `Ensure-DirectoryExists`, `Save-Json`, `Load-Json`, `Save-JsonResult`, `Test-PathEx` |
| 6 | [`PathResolver.ps1`](../../src/powershell/Automation/Private/PathResolver.ps1) | `Get-ProjectRoot`, `Get-LogDirectory` |
| 7 | [`Inventory.ps1`](../../src/powershell/Automation/Private/Inventory.ps1) | `Load-ServerList`, `Load-ClusterCatalogue`, `Test-ClusterDefinition`, `New-ServerInfo` |
| 8 | [`Logging.ps1`](../../src/powershell/Automation/Private/Logging.ps1) | `Initialize-Logging`, `Get-Logger` |
| 9 | [`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1) | `Invoke-RoutedRequest` - dispatches by `request_types.json` |
| 9 | [`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1) | `Invoke-RoutedRequest` - dispatches by `request_types.json` |
| 10 | [`Base.ps1`](../../src/powershell/Automation/Private/Base.ps1) | `AutomationBase` class (legacy), `New-AutomationBase`, timestamp helpers |

<a name="13---public-function-load-order"></a>
### 1.3 - Public Function Load Order
<a name="13---public-function-load-order-1"></a>
### 1.3 - Public Function Load Order

Loaded alphabetically by [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1#L424-L429). Order:

1. [`_Validate-Request.ps1`](../../src/powershell/Automation/Public/_Validate-Request.ps1) - request validation (underscore-prefixed, not exported)
2. [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) - central control surface
3. [`Get-RouteMap.ps1`](../../src/powershell/Automation/Public/Get-RouteMap.ps1) - routing introspection
4. [`Invoke-GitLabMaintenanceTrigger.ps1`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1) - GitLab CI/CD trigger
5. [`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1) - ISO deployer (iLO/Redfish)
6. [`Invoke-OpsRampClient.ps1`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1) - OpsRamp client
7. [`Invoke-PowerShellScript.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1) - local PS execution
8. [`Invoke-PowerShellWinRM.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1) - remote WinRM execution
9. [`New-IsoBuild.ps1`](../../src/powershell/Automation/Public/New-IsoBuild.ps1) - ISO build orchestrator
10. [`New-OneViewMaintenanceScript.ps1`](../../src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1) - generate OneView maintenance scripts
11. [`New-ScomConnection.ps1`](../../src/powershell/Automation/Public/New-ScomConnection.ps1) - SCOM connection scripts
12. [`New-ScomMaintenanceScript.ps1`](../../src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1) - generate SCOM maintenance scripts
13. [`New-Uuid.ps1`](../../src/powershell/Automation/Public/New-Uuid.ps1) - deterministic UUID generator
14. [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1) - *see Code_Map_Maitenance_Mode.md*
15. [`Start-AutomationOrchestrator.ps1`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1) - unified entry point
16. [`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1) - installation progress monitor
17. [`Test-BuildParams.ps1`](../../src/powershell/Automation/Public/Test-BuildParams.ps1) - build parameter validation
18. [`Test-ClusterId.ps1`](../../src/powershell/Automation/Public/Test-ClusterId.ps1) - cluster ID validation
19. [`Test-ServerList.ps1`](../../src/powershell/Automation/Public/Test-ServerList.ps1) - server list validation
20. [`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1) - firmware ISO builder
21. [`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1) - Windows security patcher
1. [`_Validate-Request.ps1`](../../src/powershell/Automation/Public/_Validate-Request.ps1) - request validation (underscore-prefixed, not exported)
2. [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) - central control surface
3. [`Get-RouteMap.ps1`](../../src/powershell/Automation/Public/Get-RouteMap.ps1) - routing introspection
4. [`Invoke-GitLabMaintenanceTrigger.ps1`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1) - GitLab CI/CD trigger
5. [`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1) - ISO deployer (iLO/Redfish)
6. [`Invoke-OpsRampClient.ps1`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1) - OpsRamp client
7. [`Invoke-PowerShellScript.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1) - local PS execution
8. [`Invoke-PowerShellWinRM.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1) - remote WinRM execution
9. [`New-IsoBuild.ps1`](../../src/powershell/Automation/Public/New-IsoBuild.ps1) - ISO build orchestrator
10. [`New-OneViewMaintenanceScript.ps1`](../../src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1) - generate OneView maintenance scripts
11. [`New-ScomConnection.ps1`](../../src/powershell/Automation/Public/New-ScomConnection.ps1) - SCOM connection scripts
12. [`New-ScomMaintenanceScript.ps1`](../../src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1) - generate SCOM maintenance scripts
13. [`New-Uuid.ps1`](../../src/powershell/Automation/Public/New-Uuid.ps1) - deterministic UUID generator
14. [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1) - *see Code_Map_Maitenance_Mode.md*
15. [`Start-AutomationOrchestrator.ps1`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1) - unified entry point
16. [`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1) - installation progress monitor
17. [`Test-BuildParams.ps1`](../../src/powershell/Automation/Public/Test-BuildParams.ps1) - build parameter validation
18. [`Test-ClusterId.ps1`](../../src/powershell/Automation/Public/Test-ClusterId.ps1) - cluster ID validation
19. [`Test-ServerList.ps1`](../../src/powershell/Automation/Public/Test-ServerList.ps1) - server list validation
20. [`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1) - firmware ISO builder
21. [`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1) - Windows security patcher

---

<a name="2-request-routing-and-control-surfaces"></a>
## 2. Request Routing & Control Surfaces

After module load, requests arrive from one of four surfaces: CI pipeline, iRequest/ISAPI, Scheduled tasks, or GitLab CI/CD. All surfaces converge on the central router.

<a name="21---request-router"></a>
### 2.1 - Request Router
<a name="21---request-router-1"></a>
### 2.1 - Request Router

**[`configs/request_types.json`](../../configs/request_types.json)** - Single source of truth for all request types and their handler mappings.
**[`configs/request_types.json`](../../configs/request_types.json)** - Single source of truth for all request types and their handler mappings.

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
| `gitlab_maintenance` | `Invoke-GitLabMaintenanceTrigger` | null |

**[`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1#L20)** - [`Invoke-RoutedRequest()`](../../src/powershell/Automation/Private/Router.ps1#L20)
**[`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1#L20)** - [`Invoke-RoutedRequest()`](../../src/powershell/Automation/Private/Router.ps1#L20)
- Loads routing table from `request_types.json` at [L7–18](../../src/powershell/Automation/Private/Router.ps1#L7-L18)
- Dispatches by calling the handler with `@Params` splat at [L52–58](../../src/powershell/Automation/Private/Router.ps1#L52-L58)
- Returns `Success=false` for unknown types at [L43–49](../../src/powershell/Automation/Private/Router.ps1#L43-L49)

<a name="22---unified-orchestrator-entry-point"></a>
### 2.2 - Unified Orchestrator Entry Point
<a name="22---unified-orchestrator-entry-point-1"></a>
### 2.2 - Unified Orchestrator Entry Point

**[`Start-AutomationOrchestrator.ps1`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L5)** - [`Start-AutomationOrchestrator()`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L5)
**[`Start-AutomationOrchestrator.ps1`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L5)** - [`Start-AutomationOrchestrator()`](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L5)
- Validates request via [`_Validate-Request()`](../../src/powershell/Automation/Public/_Validate-Request.ps1#L5) at [L37](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L37)
- Routes via [`Invoke-RoutedRequest()`](../../src/powershell/Automation/Private/Router.ps1#L20) at [L46](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L46)
- Adds `Timestamp` and `RequestType` to result at [L47–49](../../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1#L47-L49)

<a name="23---request-validation"></a>
### 2.3 - Request Validation
<a name="23---request-validation-1"></a>
### 2.3 - Request Validation

**[`_Validate-Request.ps1`](../../src/powershell/Automation/Public/_Validate-Request.ps1#L5)** - [`_Validate-Request()`](../../src/powershell/Automation/Public/_Validate-Request.ps1#L5)
**[`_Validate-Request.ps1`](../../src/powershell/Automation/Public/_Validate-Request.ps1#L5)** - [`_Validate-Request()`](../../src/powershell/Automation/Public/_Validate-Request.ps1#L5)

| Check | Lines | Logic |
|-------|-------|-------|
| Build params | [L31–33](../../src/powershell/Automation/Public/_Validate-Request.ps1#L31-L33) | Calls `Test-BuildParams` for `build_iso` / `patch_windows` |
| Maintenance target | [L34–39](../../src/powershell/Automation/Public/_Validate-Request.ps1#L34-L39) | Calls `Test-ClusterId` for `maintenance_*` requests |

<a name="24---ci-pipeline-surface"></a>
### 2.4 - CI Pipeline Surface
<a name="24---ci-pipeline-surface-1"></a>
### 2.4 - CI Pipeline Surface

**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L193)** - [`Run-CIPipeline()`](../../src/powershell/Automation/Public/Control.ps1#L193)
**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L193)** - [`Run-CIPipeline()`](../../src/powershell/Automation/Public/Control.ps1#L193)
- Builds CI params via [`_Build-CIParams()`](../../src/powershell/Automation/Public/Control.ps1#L27) mapping:
  - `firmware` → `update_firmware`
  - `windows` → `patch_windows`
  - `deploy` → `deploy`
  - `scan` → `opsramp_report`
  - `all` → `build_iso`
- Executes via [`_Execute()`](../../src/powershell/Automation/Public/Control.ps1#L164)

<a name="25---irequestisapi-surface"></a>
### 2.5 - iRequest/ISAPI Surface
<a name="25---irequestisapi-surface-1"></a>
### 2.5 - iRequest/ISAPI Surface

**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L207)** - [`Run-IRequest()`](../../src/powershell/Automation/Public/Control.ps1#L207)
**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L207)** - [`Run-IRequest()`](../../src/powershell/Automation/Public/Control.ps1#L207)
- Builds params via [`_Build-IRequestParams()`](../../src/powershell/Automation/Public/Control.ps1#L64) mapping `cluster_id` + `action` → `maintenance_{action}`
- Executes via [`_Execute()`](../../src/powershell/Automation/Public/Control.ps1#L164)

<a name="26---scheduled-task-surface"></a>
### 2.6 - Scheduled Task Surface
<a name="26---scheduled-task-surface-1"></a>
### 2.6 - Scheduled Task Surface

**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L232)** - [`Run-Scheduler()`](../../src/powershell/Automation/Public/Control.ps1#L232)
**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L232)** - [`Run-Scheduler()`](../../src/powershell/Automation/Public/Control.ps1#L232)
- Builds params via [`_Build-SchedulerParams()`](../../src/powershell/Automation/Public/Control.ps1#L92) mapping:
  - `maintenance_disable` → `maintenance_disable`
  - `build_firmware` → `update_firmware`
  - `build_windows` → `patch_windows`

<a name="27---gitlab-cicd-surface"></a>
### 2.7 - GitLab CI/CD Surface
<a name="27---gitlab-cicd-surface-1"></a>
### 2.7 - GitLab CI/CD Surface

**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L289)** - [`Run-GitLab()`](../../src/powershell/Automation/Public/Control.ps1#L289)
**[`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1#L289)** - [`Run-GitLab()`](../../src/powershell/Automation/Public/Control.ps1#L289)
- Builds params via [`_Build-GitLabParams()`](../../src/powershell/Automation/Public/Control.ps1#L256)
- Routes to `gitlab_maintenance` request type

**[`Invoke-GitLabMaintenanceTrigger.ps1`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L7)** - [`Invoke-GitLabMaintenanceTrigger()`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L7)
**[`Invoke-GitLabMaintenanceTrigger.ps1`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L7)** - [`Invoke-GitLabMaintenanceTrigger()`](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L7)
- Dot-sources [`Send-GitLabMaintenanceRequest.ps1`](../../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1) at [L84–94](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L84-L94)
- Calls [`Send-GitLabMaintenanceRequest()`](../../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1) at [L97–100](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L97-L100)
- Returns pipeline ID and web URL on success at [L102–110](../../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1#L102-L110)

**[`scripts/gitlab/Send-GitLabMaintenanceRequest.ps1`](../../scripts/gitlab/Send-GitLabMaintenanceRequest.ps1)**
- Triggers GitLab pipeline via trigger API
- Monitors pipeline completion with timeout
- Sends web callback with results on completion

**[`scripts/gitlab/Invoke-GitLabMaintenance.ps1`](../../scripts/gitlab/Invoke-GitLabMaintenance.ps1)**
- GitLab CI entry point - executed by pipeline runner
- GitLab CI entry point - executed by pipeline runner
- Wraps `Set-MaintenanceMode` with GitLab-specific logging and callback support

**[`scripts/gitlab/Send-WebCallback.ps1`](../../scripts/gitlab/Send-WebCallback.ps1)** - [`Send-WebCallback()`](../../scripts/gitlab/Send-WebCallback.ps1)
**[`scripts/gitlab/Send-WebCallback.ps1`](../../scripts/gitlab/Send-WebCallback.ps1)** - [`Send-WebCallback()`](../../scripts/gitlab/Send-WebCallback.ps1)
- POST JSON to HTTPS callback URL with optional API key
- Validates HTTPS-only at [L28–31](../../scripts/gitlab/Send-WebCallback.ps1#L28-L31)

---

<a name="3-iso-build-pipeline"></a>
## 3. ISO Build Pipeline

The `build_iso` request type orchestrates the full server customization pipeline: firmware ISO → Windows patching → combined package.

<a name="31---iso-build-orchestrator"></a>
### 3.1 - ISO Build Orchestrator
<a name="31---iso-build-orchestrator-1"></a>
### 3.1 - ISO Build Orchestrator

**[`New-IsoBuild.ps1`](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L5)** - [`New-IsoBuild()`](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L5)
**[`New-IsoBuild.ps1`](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L5)** - [`New-IsoBuild()`](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L5)

**Required config files** (verified at [L57–62](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L57-L62)):
- `configs/hpe_firmware_drivers_nov2025.json`
- `configs/windows_patches.json`
- `configs/server_list.txt`

**Per-server build** at [L65–66](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L65-L66):
1. Calls [`New-Uuid()`](../../src/powershell/Automation/Public/New-Uuid.ps1#L8) for server ID at [L107](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L107)
2. Creates [`FirmwareUpdater`](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L76) → builds firmware ISO at [L113](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L113)
3. Creates [`WindowsPatcher`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88) → patches Windows ISO at [L123](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L123)
4. Combines artifacts in `output/combined/{ServerName}/` at [L132–145](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L132-L145)
5. Writes `deployment_metadata.json` at [L139–144](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L139-L144)

**Summary** returned at [L69–78](../../src/powershell/Automation/Public/New-IsoBuild.ps1#L69-L78) with per-server results.

<a name="32---uuid-generation"></a>
### 3.2 - UUID Generation
<a name="32---uuid-generation-1"></a>
### 3.2 - UUID Generation

**[`New-Uuid.ps1`](../../src/powershell/Automation/Public/New-Uuid.ps1#L8)** - [`New-Uuid()`](../../src/powershell/Automation/Public/New-Uuid.ps1#L8)
**[`New-Uuid.ps1`](../../src/powershell/Automation/Public/New-Uuid.ps1#L8)** - [`New-Uuid()`](../../src/powershell/Automation/Public/New-Uuid.ps1#L8)
- Computes SHA-256 hash of `{ServerName}-{Timestamp}` at [L50–53](../../src/powershell/Automation/Public/New-Uuid.ps1#L50-L53)
- Takes first 16 bytes → UUID format at [L56–57](../../src/powershell/Automation/Public/New-Uuid.ps1#L56-L57)
- Optionally writes to file at [L59–61](../../src/powershell/Automation/Public/New-Uuid.ps1#L59-L61)

---

<a name="4-firmware-iso-builder"></a>
## 4. Firmware ISO Builder

<a name="41---firmware-update-function"></a>
### 4.1 - Firmware Update Function
<a name="41---firmware-update-function-1"></a>
### 4.1 - Firmware Update Function

**[`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L13)** - [`Update-Firmware()`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L13)
**[`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L13)** - [`Update-Firmware()`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L13)
- Default config: `configs/hpe_firmware_drivers_nov2025.json`
- Default output: `output/firmware`
- Delegates to [`FirmwareUpdater`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L76) class at [L61–62](../../src/powershell/Automation/Public/Update-Firmware.ps1#L61-L62)
- Saves per-server result JSON at [L67](../../src/powershell/Automation/Public/Update-Firmware.ps1#L67)

<a name="42---firmwareupdater-class"></a>
### 4.2 - FirmwareUpdater Class
<a name="42---firmwareupdater-class-1"></a>
### 4.2 - FirmwareUpdater Class

**[`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L76)** - class starts at [L76](../../src/powershell/Automation/Public/Update-Firmware.ps1#L76)
**[`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L76)** - class starts at [L76](../../src/powershell/Automation/Public/Update-Firmware.ps1#L76)

| Property | Line | Purpose |
|----------|------|---------|
| `$ConfigPath` | 77 | Path to `hpe_firmware_drivers_nov2025.json` |
| `$OutputDir` | 78 | Output directory for firmware ISOs |
| `$Config` | 79 | Parsed config hashtable |
| `$SutPath` | 80 | Path to `hpe_sut` binary |
| `$DownloadCreds` | 81 | HPE repository download credentials from config |
| `$BuildLog` | 82 | ArrayList of build log entries |
| `$MaxRetryAttempts` | 85 | SUT retry limit (default: 3) |
| `$RetryDelaySeconds` | 86 | SUT base retry delay (default: 5.0) |

| Method | Line | Purpose |
|--------|------|---------|
| `FirmwareUpdater()` | [L88](../../src/powershell/Automation/Public/Update-Firmware.ps1#L88) | Constructor: loads config, finds SUT binary, reads download credentials |
| `_FindSut()` | [L104](../../src/powershell/Automation/Public/Update-Firmware.ps1#L104) | Locates `hpe_sut` in `tools/`, Program Files, or PATH |
| `_DetectGen()` | [L120](../../src/powershell/Automation/Public/Update-Firmware.ps1#L120) | Detects Gen10 vs Gen10+ from server name |
| `_ComponentsForGen()` | [L126](../../src/powershell/Automation/Public/Update-Firmware.ps1#L126) | Resolves firmware/driver components for server generation |
| `_Log()` | [L141](../../src/powershell/Automation/Public/Update-Firmware.ps1#L141) | Adds timestamped build log entry |
| `_RunSut()` | [L148](../../src/powershell/Automation/Public/Update-Firmware.ps1#L148) | Invokes `hpe_sut create` via [`Invoke-NativeCommandWithRetry()`](../../src/powershell/Automation/Private/Executor.ps1#L68) |
| `Build()` | [L165](../../src/powershell/Automation/Public/Update-Firmware.ps1#L165) | Full firmware ISO build: detect gen → resolve components → invoke SUT |

**SUT command** at [L195–196](../../src/powershell/Automation/Public/Update-Firmware.ps1#L195-L196):
```
hpe_sut create --server-generation {gen} --repository {url} --output {iso} --components {list}
```

---

<a name="5-windows-security-patching"></a>
## 5. Windows Security Patching

<a name="51---invoke-windowssecurityupdate"></a>
### 5.1 - Invoke-WindowsSecurityUpdate
<a name="51---invoke-windowssecurityupdate-1"></a>
### 5.1 - Invoke-WindowsSecurityUpdate

**[`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L8)** - [`Invoke-WindowsSecurityUpdate()`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L8)
**[`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L8)** - [`Invoke-WindowsSecurityUpdate()`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L8)
- Default patches config: `configs/windows_patches.json`
- Default output: `output/patched`
- Creates [`WindowsPatcher`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88) instance at [L74](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L74)
- Calls `Build()` at [L75](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L75)
- Saves patch result JSON at [L78](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L78)

<a name="52---windowspatcher-class"></a>
### 5.2 - WindowsPatcher Class
<a name="52---windowspatcher-class-1"></a>
### 5.2 - WindowsPatcher Class

**[`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88)** - class starts at [L88](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88)
**[`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88)** - class starts at [L88](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L88)

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
| `WindowsPatcher()` | [L96](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L96) | Constructor: loads patch config, creates patch directory |
| `_LoadConfig()` | [L106](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L106) | Returns parsed patches config |
| `_Log()` | [L108](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L108) | Adds timestamped build log entry |
| `_SetupBaseIso()` | [L113](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L113) | Mounts Windows ISO via `Mount-DiskImage` (Windows) or extracts directory |
| `_ApplyPatchesDism()` | [L138](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L138) | Applies MSU patches via `dism.exe /Add-Package` (iterates `patches[]`) |
| `_ApplyPatchesPowerShell()` | [L156](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L156) | Applies patches via `Add-WindowsPackage` cmdlet |
| `Build()` | [L175](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L175) | Full patch pipeline: mount ISO → apply patches → export patched ISO |

**DISM patch application** at [L145–153](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L145-L153):
```
dism /Image:{mounted_iso} /Add-Package /PackagePath:{kb.msu} /LimitAccess /NoRestart
```

---

<a name="6-iso-deployment"></a>
## 6. ISO Deployment

<a name="61---invoke-isodeploy"></a>
### 6.1 - Invoke-IsoDeploy
<a name="61---invoke-isodeploy-1"></a>
### 6.1 - Invoke-IsoDeploy

**[`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L22)** - [`Invoke-IsoDeploy()`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L22)
**[`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L22)** - [`Invoke-IsoDeploy()`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L22)
- Default ISO directory: `output/combined`
- Deploys `output/combined/{ServerName}/` packages to target servers
- Supports `Method`: `ilo` (default) or `redfish`
- Creates [`ISODeployer`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L82) at [L65](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L65)
- Single-server mode via `Deploy()` at [L69](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L69)
- Bulk mode via `DeployAll()` at [L300](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L300)

<a name="62---isodeployer-class"></a>
### 6.2 - ISODeployer Class
<a name="62---isodeployer-class-1"></a>
### 6.2 - ISODeployer Class

**[`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L82)** - class starts at [L82](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L82)
**[`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L82)** - class starts at [L82](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L82)

| Property | Line | Purpose |
|----------|------|---------|
| `$ServerListPath` | 83 | Path to `server_list.txt` |
| `$IsoDir` | 84 | Path to deployment packages |
| `$ServerDetails` | 85 | `[ServerInfo[]]` loaded from server list |
| `$DeployLog` | 86 | ArrayList of deployment log entries |

| Method | Line | Purpose |
|--------|------|---------|
| `ISODeployer()` | [L88](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L88) | Constructor: loads server list via [`Load-ServerList()`](../../src/powershell/Automation/Private/Inventory.ps1#L5) |
| `_FindServerPackage()` | [L95](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L95) | Resolves server name to `output/combined/` subdirectory (by hostname variants + metadata fallback) |
| `_Log()` | [L113](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L113) | Adds timestamped deploy log entry |
| `_DeployViaIlo()` | [L148](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L148) | iLO REST session login + virtual media mount (stub - awaiting ISO serving URL) |
| `_DeployViaRedfish()` | [L255](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L255) | Redfish boot-from-ISO (stub - same pre-condition) |
| `_DeployViaIlo()` | [L148](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L148) | iLO REST session login + virtual media mount (stub - awaiting ISO serving URL) |
| `_DeployViaRedfish()` | [L255](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L255) | Redfish boot-from-ISO (stub - same pre-condition) |
| `Deploy()` | [L282](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L282) | Dispatches to iLO or Redfish method |
| `DeployAll()` | [L300](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L300) | Iterates all servers, saves deployment summary JSON |

**iLO REST sequence** (documented at [L119–146](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1#L119-L146)):
1. `POST /rest/v1/sessions` - session login with iLO credentials
1. `POST /rest/v1/sessions` - session login with iLO credentials
2. `X-Redfish-Session` header from sessionKey
3. `POST .../InsertVirtualMedia` - mount ISO (stub, requires reachable ISO URL)
3. `POST .../InsertVirtualMedia` - mount ISO (stub, requires reachable ISO URL)
4. Optional: PATCH boot order + `ForceRestart`

---

<a name="7-installation-monitoring"></a>
## 7. Installation Monitoring

<a name="71---start-installmonitor"></a>
### 7.1 - Start-InstallMonitor
<a name="71---start-installmonitor-1"></a>
### 7.1 - Start-InstallMonitor

**[`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L8)** - [`Start-InstallMonitor()`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L8)
**[`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L8)** - [`Start-InstallMonitor()`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L8)
- Polls iLO Redfish + WinRM to track Windows installation phases
- Sends progress metrics and alerts to OpsRamp
- Default timeout: 7200s (2 hours), poll interval: 30s
- Creates [`InstallationMonitor`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L94) at [L49](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L49)
- Single server at [L53](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L53), bulk at [L57](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L57)

**Phase mapping** at [L88–91](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L88-L91):
```
0 = Not Started → 1 = Generalize → 2 = Specialize → 3 = Running Windows → 4 = RunPhase
```

<a name="72---installationmonitor-class"></a>
### 7.2 - InstallationMonitor Class
<a name="72---installationmonitor-class-1"></a>
### 7.2 - InstallationMonitor Class

**[`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L94)** - class starts at [L94](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L94)
**[`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L94)** - class starts at [L94](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L94)

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
| `InstallationMonitor()` | [L106](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L106) | Constructor: loads server list, initializes OpsRamp client |
| `_InitOpsRampClient()` | [L115](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L115) | Creates `OpsRamp_Client` from config path |
| `_Log()` | [L121](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L121) | Adds timestamped monitoring log entry |
| `CheckIloStatus()` | [L126](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L126) | Ping + Redfish query → power state, boot source |
| `CheckWinRM()` | [L147](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L147) | Tests WSMan accessibility via `Test-WSMan` |
| `QueryInstallProgressWinRM()` | [L156](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L156) | Reads `HKLM:\SYSTEM\Setup` registry + Setup event log via WinRM |
| `_SendOpsRampMetric()` | [L191](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L191) | Sends progress metrics to OpsRamp |
| `_SendOpsRampAlert()` | [L198](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L198) | Sends alerts on timeout/failure/completion |
| `MonitorServer()` | [L204](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L204) | Polling loop: iLO + WinRM → progress tracking, exits at 100% or timeout |
| `MonitorAll()` | [L285](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1#L285) | Monitors all servers, writes summary JSON |

---

<a name="8-powershell-execution-utilities"></a>
## 8. PowerShell Execution Utilities

<a name="81---local-powershell-execution"></a>
### 8.1 - Local PowerShell Execution
<a name="81---local-powershell-execution-1"></a>
### 8.1 - Local PowerShell Execution

**[`Invoke-PowerShellScript.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#L5)** - [`Invoke-PowerShellScript()`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#L5)
**[`Invoke-PowerShellScript.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#L5)** - [`Invoke-PowerShellScript()`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1#L5)
- Spawns `powershell.exe` (Windows) or `pwsh` (Linux) as a new process via `System.Diagnostics.Process`
- Parameters: `Script`, `CaptureOutput`, `TimeoutSeconds`, `ExecutionPolicy`
- Configurable timeout (default: 300s), execution policy (default: `Bypass`)
- Returns `@{ Success, Output }`

<a name="82---remote-powershell-via-winrm"></a>
### 8.2 - Remote PowerShell via WinRM
<a name="82---remote-powershell-via-winrm-1"></a>
### 8.2 - Remote PowerShell via WinRM

**[`Invoke-PowerShellWinRM.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L5)** - [`Invoke-PowerShellWinRM()`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L5)
**[`Invoke-PowerShellWinRM.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L5)** - [`Invoke-PowerShellWinRM()`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L5)
- Creates `New-PSSession` with NTLM authentication at [L52](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L52)
- Executes script block remotely via `Invoke-Command` at [L53](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L53)
- Cleans up session after execution at [L54](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1#L54)
- Parameters: `Script`, `Server`, `Username`, `Password` (SecureString), `Transport`, `TimeoutSeconds`
- Returns `@{ Success, Output }`

---

<a name="9-opsramp-integration"></a>
## 9. OpsRamp Integration

<a name="91---opsramp_client-class"></a>
### 9.1 - OpsRamp_Client Class
<a name="91---opsramp_client-class-1"></a>
### 9.1 - OpsRamp_Client Class

Defined in [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1#L136), fully documented in [§9.2 of this document](#markdown-header-92-opsramp-entry-points).

| Member | Line | Purpose |
|--------|------|---------|
| `EnsureToken()` | [L177](../../src/powershell/Automation/Automation.psm1#L177) | OAuth2 client_credentials flow, token caching with 90% TTL |
| `SendMetric()` | [L240](../../src/powershell/Automation/Automation.psm1#L240) | POST metric gauge |
| `SendAlert()` | [L257](../../src/powershell/Automation/Automation.psm1#L257) | POST alert |
| `SendEvent()` | [L271](../../src/powershell/Automation/Automation.psm1#L271) | POST event |
| `ReportBuildStatus()` | [L289](../../src/powershell/Automation/Automation.psm1#L289) | Build status metric + failure alert |
| `ReportDeploymentStatus()` | [L301](../../src/powershell/Automation/Automation.psm1#L301) | Deploy status metric + failure alert |
| `ReportInstallationProgress()` | [L313](../../src/powershell/Automation/Automation.psm1#L313) | Progress percent + elapsed seconds |
| `ReportVulnerabilityScan()` | [L322](../../src/powershell/Automation/Automation.psm1#L322) | Vuln counts + critical alert |

<a name="92---opsramp-entry-points"></a>
### 9.2 - OpsRamp Entry Points
<a name="92---opsramp-entry-points-1"></a>
### 9.2 - OpsRamp Entry Points

**[`Invoke-OpsRampClient.ps1`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1)**

| Function | Line | Purpose |
|----------|------|---------|
| [`Invoke-OpsRampClient()`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1#L5) | L5 | Factory: creates `OpsRamp_Client` instance from config path |
| [`Invoke-OpsRamp()`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1#L29) | L29 | Quick connectivity test - returns boolean from `EnsureToken()` |
| [`Invoke-OpsRamp()`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1#L29) | L29 | Quick connectivity test - returns boolean from `EnsureToken()` |

---

<a name="10-credential-resolution"></a>
## 10. Credential Resolution

**[`Credentials.ps1`](../../src/powershell/Automation/Private/Credentials.ps1)** - 201 lines
**[`Credentials.ps1`](../../src/powershell/Automation/Private/Credentials.ps1)** - 201 lines

**Resolution order** (documented at [L5–14](../../src/powershell/Automation/Private/Credentials.ps1#L5-L14)):
1. Environment variable (CI pre-fetches from CyberArk)
2. CyberArk CCP CLI (`ark_ccl` / `ark_cc` on PATH)
3. CyberArk AIM REST API (`$env:CYBERARK_CCP_URL`)
4. Safe default / empty string

| Function | Line | Resolves |
|----------|------|----------|
| [`_Resolve-Credential()`](../../src/powershell/Automation/Private/Credentials.ps1#L17) | L17 | Core resolver - env → CLI → REST → default |
| [`_Resolve-Credential()`](../../src/powershell/Automation/Private/Credentials.ps1#L17) | L17 | Core resolver - env → CLI → REST → default |
| [`Get-EnvCredential()`](../../src/powershell/Automation/Private/Credentials.ps1#L127) | L127 | Generic env-var PSCredential |
| [`Get-IloCredentials()`](../../src/powershell/Automation/Private/Credentials.ps1#L145) | L145 | `ILO_USER` / `ILO_PASSWORD` |
| [`Get-ScomCredentials()`](../../src/powershell/Automation/Private/Credentials.ps1#L158) | L158 | `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` |
| [`Get-OpenViewCredentials()`](../../src/powershell/Automation/Private/Credentials.ps1#L173) | L173 | OpenView legacy credentials |
| [`Get-OneViewCredentials()`](../../src/powershell/Automation/Private/Credentials.ps1#L183) | L183 | `ONEVIEW_USER` / `ONEVIEW_PASSWORD` |
| [`Get-SmtpCredentials()`](../../src/powershell/Automation/Private/Credentials.ps1#L193) | L193 | SMTP email credentials |

---

<a name="11-inventory-and-configuration"></a>
## 11. Inventory & Configuration

<a name="111---inventory-functions"></a>
### 11.1 - Inventory Functions
<a name="111---inventory-functions-1"></a>
### 11.1 - Inventory Functions

**[`Inventory.ps1`](../../src/powershell/Automation/Private/Inventory.ps1)** - 99 lines
**[`Inventory.ps1`](../../src/powershell/Automation/Private/Inventory.ps1)** - 99 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Load-ServerList()`](../../src/powershell/Automation/Private/Inventory.ps1#L5) | L5 | Reads `server_list.txt` → `ServerInfo[]` or plain strings |
| [`Load-ClusterCatalogue()`](../../src/powershell/Automation/Private/Inventory.ps1#L46) | L46 | Loads `clusters_catalogue.json` → inner `clusters` hashtable |
| [`Test-ClusterDefinition()`](../../src/powershell/Automation/Private/Inventory.ps1#L62) | L62 | Validates cluster definition fields: `display_name`, `servers`, `scom_group`, `environment` |
| [`New-ServerInfo()`](../../src/powershell/Automation/Private/Inventory.ps1#L83) | L83 | Factory for `ServerInfo` objects |

<a name="112---configuration-functions"></a>
### 11.2 - Configuration Functions
<a name="112---configuration-functions-1"></a>
### 11.2 - Configuration Functions

**[`Config.ps1`](../../src/powershell/Automation/Private/Config.ps1)** - 128 lines
**[`Config.ps1`](../../src/powershell/Automation/Private/Config.ps1)** - 128 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Import-JsonConfig()`](../../src/powershell/Automation/Private/Config.ps1#L5) | L5 | Reads JSON file, converts to hashtable, substitutes `${VAR}` env references |
| [`Import-YamlConfig()`](../../src/powershell/Automation/Private/Config.ps1#L44) | L44 | Reads YAML file, converts to hashtable |
| [`_PS_ConvertTo-Hashtable()`](../../src/powershell/Automation/Private/Config.ps1#L64) | L64 | Recursively converts PSCustomObject → hashtable |
| [`_PS_ReplaceEnvVars()`](../../src/powershell/Automation/Private/Config.ps1#L88) | L88 | Replaces `${VAR}` placeholders with environment variable values |
| [`_PS_SubstituteEnvVars()`](../../src/powershell/Automation/Private/Config.ps1#L108) | L108 | Recursive env-var substitution across all nested hashtables |

<a name="113---validator-functions"></a>
### 11.3 - Validator Functions
<a name="113---validator-functions-1"></a>
### 11.3 - Validator Functions

| Function | File | Purpose |
|----------|------|---------|
| [`Test-BuildParams()`](../../src/powershell/Automation/Public/Test-BuildParams.ps1#L5) | 35 lines | Validates base ISO path exists |
| [`Test-ClusterId()`](../../src/powershell/Automation/Public/Test-ClusterId.ps1#L5) | 73 lines | Validates cluster ID in catalogue, checks required fields |
| [`Test-ServerList()`](../../src/powershell/Automation/Public/Test-ServerList.ps1#L5) | 46 lines | Validates server list file, strips comments and empty lines |

---

<a name="12-process-execution-and-retry"></a>
## 12. Process Execution & Retry

**[`Executor.ps1`](../../src/powershell/Automation/Private/Executor.ps1)** - 108 lines
**[`Executor.ps1`](../../src/powershell/Automation/Private/Executor.ps1)** - 108 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Invoke-NativeCommand()`](../../src/powershell/Automation/Private/Executor.ps1#L5) | L5 | Executes external program via `System.Diagnostics.Process`, captures stdout/stderr |
| [`Invoke-NativeCommandWithRetry()`](../../src/powershell/Automation/Private/Executor.ps1#L68) | L68 | Exponential back-off retry wrapper (default: 3 attempts, 5s base delay) |
| [`New-CommandResult()`](../../src/powershell/Automation/Private/Executor.ps1#L99) | L99 | Factory for `CommandResult` objects |

**Used by**: [`FirmwareUpdater._RunSut()`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L148), [`WindowsPatcher._ApplyPatchesDism()`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L138)

---

<a name="13-file-io-and-path-resolution"></a>
## 13. File I/O & Path Resolution

<a name="131---file-io-functions"></a>
### 13.1 - File I/O Functions
<a name="131---file-io-functions-1"></a>
### 13.1 - File I/O Functions

**[`FileIO.ps1`](../../src/powershell/Automation/Private/FileIO.ps1)** - 102 lines
**[`FileIO.ps1`](../../src/powershell/Automation/Private/FileIO.ps1)** - 102 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Ensure-DirectoryExists()`](../../src/powershell/Automation/Private/FileIO.ps1#L5) | L5 | Creates directory tree if missing |
| [`Save-Json()`](../../src/powershell/Automation/Private/FileIO.ps1#L18) | L18 | Serializes object to JSON file |
| [`Load-Json()`](../../src/powershell/Automation/Private/FileIO.ps1#L35) | L35 | Deserializes JSON file |
| [`Save-JsonResult()`](../../src/powershell/Automation/Private/FileIO.ps1#L53) | L53 | Saves to `{outputDir}/{category}/{basename}_{timestamp}.json` |
| [`Test-PathEx()`](../../src/powershell/Automation/Private/FileIO.ps1#L77) | L77 | Enhanced Test-Path with better error messages |
| [`_FileIO_DeepHashtable()`](../../src/powershell/Automation/Private/FileIO.ps1#L94) | L94 | Internal: deep conversion of PSCustomObject tree to hashtable |

<a name="132---path-resolution"></a>
### 13.2 - Path Resolution
<a name="132---path-resolution-1"></a>
### 13.2 - Path Resolution

**[`PathResolver.ps1`](../../src/powershell/Automation/Private/PathResolver.ps1)** - 53 lines
**[`PathResolver.ps1`](../../src/powershell/Automation/Private/PathResolver.ps1)** - 53 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Get-ProjectRoot()`](../../src/powershell/Automation/Private/PathResolver.ps1#L5) | L5 | Walks up from cwd looking for `kilo.json` or `Makefile` |
| [`Get-LogDirectory()`](../../src/powershell/Automation/Private/PathResolver.ps1#L32) | L32 | Returns `{projectRoot}/generated/logs/{env}` |

---

<a name="14-logging-and-audit"></a>
## 14. Logging & Audit

<a name="141---logging-functions"></a>
### 14.1 - Logging Functions
<a name="141---logging-functions-1"></a>
### 14.1 - Logging Functions

**[`Logging.ps1`](../../src/powershell/Automation/Private/Logging.ps1)** - 97 lines
**[`Logging.ps1`](../../src/powershell/Automation/Private/Logging.ps1)** - 97 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Initialize-Logging()`](../../src/powershell/Automation/Private/Logging.ps1#L6) | L6 | Sets up log directory, creates log file |
| [`Get-Logger()`](../../src/powershell/Automation/Private/Logging.ps1#L59) | L59 | Returns logger object with Write-{Level} methods |

<a name="142---audit-logger"></a>
### 14.2 - Audit Logger
<a name="142---audit-logger-1"></a>
### 14.2 - Audit Logger

**[`Audit.ps1`](../../src/powershell/Automation/Private/Audit.ps1#L5)** - [`New-AuditLogger()`](../../src/powershell/Automation/Private/Audit.ps1#L5)
**[`Audit.ps1`](../../src/powershell/Automation/Private/Audit.ps1#L5)** - [`New-AuditLogger()`](../../src/powershell/Automation/Private/Audit.ps1#L5)
- Factory for `AuditLogger` class instances

Also defined as class in [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1#L38) (documented in [§1.1](#markdown-header-11-root-module-loader)):
- [`AuditLogger.Log()`](../../src/powershell/Automation/Automation.psm1#L66) - adds entry with action, status, server, details
- [`AuditLogger.Save()`](../../src/powershell/Automation/Automation.psm1#L82) - writes JSON file
- [`AuditLogger.AppendToMaster()`](../../src/powershell/Automation/Automation.psm1#L99) - appends to master log
- [`AuditLogger.Log()`](../../src/powershell/Automation/Automation.psm1#L66) - adds entry with action, status, server, details
- [`AuditLogger.Save()`](../../src/powershell/Automation/Automation.psm1#L82) - writes JSON file
- [`AuditLogger.AppendToMaster()`](../../src/powershell/Automation/Automation.psm1#L99) - appends to master log

<a name="143---timestamp-helpers"></a>
### 14.3 - Timestamp Helpers
<a name="143---timestamp-helpers-1"></a>
### 14.3 - Timestamp Helpers

**[`Base.ps1`](../../src/powershell/Automation/Private/Base.ps1)** - 86 lines
**[`Base.ps1`](../../src/powershell/Automation/Private/Base.ps1)** - 86 lines

| Function | Line | Purpose |
|----------|------|---------|
| [`Get-UtcTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L5) | L5 | ISO-8601 UTC timestamp |
| [`Get-LocalTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L13) | L13 | ISO-8601 local timestamp |
| [`Get-UtcFileTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L21) | L21 | `yyyyMMdd-HHmmss` (filesystem-safe) |
| [`Get-UtcApiTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L29) | L29 | OpsRamp API format |
| [`Convert-ToUtcIso8601()`](../../src/powershell/Automation/Private/Base.ps1#L37) | L37 | Converts arbitrary datetime to UTC ISO-8601 |
| [`Get-LogTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L51) | L51 | Log-friendly timestamp |
| [`Get-FileTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L59) | L59 | File-safe timestamp |
| [`Get-DateFileTimestamp()`](../../src/powershell/Automation/Private/Base.ps1#L67) | L67 | Date-only file timestamp |
| [`New-AutomationBase()`](../../src/powershell/Automation/Private/Base.ps1#L75) | L75 | Factory for `AutomationBase` class |

---

<a name="15-script-helpers"></a>
## 15. Script Helpers

<a name="151---powershell-profile-setup"></a>
### 15.1 - PowerShell Profile Setup
<a name="151---powershell-profile-setup-1"></a>
### 15.1 - PowerShell Profile Setup

**[`scripts/Setup-Profile.ps1`](../../scripts/Setup-Profile.ps1)** - 294 lines
**[`scripts/Setup-Profile.ps1`](../../scripts/Setup-Profile.ps1)** - 294 lines

Configures PowerShell profiles to auto-import the Automation module:
- Copies WIP profile templates to live profile locations (Terminal, VS Code)
- Injects Automation module import block with machine-specific absolute path
- Supports `-Merge` (preserve user customizations), `-Uninstall`, `-DryRun`
- Platform-aware: `windowspsprofile.ps1` (Windows) / `psprofile.ps1` (Linux)

<a name="152---cisecurity-and-lint-scripts"></a>
### 15.2 - CI/Security & Lint Scripts
<a name="152---cisecurity-and-lint-scripts-1"></a>
### 15.2 - CI/Security & Lint Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`ci-security-check.ps1`](../../scripts/ci-security-check.ps1) | 143 lines | PSScriptAnalyzer security scan + secrets detection + JSON validation |
| [`lint.ps1`](../../scripts/lint.ps1) | 246 lines | Two-phase lint: syntax validation → PSScriptAnalyzer code quality |
| [`lint-make.ps1`](../../scripts/lint-make.ps1) | 70 lines | Checkmake Makefile validation (Windows-compatible) |
| [`run-checkmake.ps1`](../../scripts/run-checkmake.ps1) | 57 lines | Standalone checkmake runner |
| [`prune-logs.ps1`](../../scripts/prune-logs.ps1) | 152 lines | Prunes excess log files, keeps max per type |

<a name="153---setup-and-bootstrap-scripts"></a>
### 15.3 - Setup & Bootstrap Scripts
<a name="153---setup-and-bootstrap-scripts-1"></a>
### 15.3 - Setup & Bootstrap Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`setup-runner.ps1`](../../scripts/setup-runner.ps1) | 436 lines | Full offline-capable runner setup: modules (Pester, PSScriptAnalyzer, PlatyPS) + binaries (Oh My Posh, make, checkmake) |
| [`setup-scom.ps1`](../../scripts/setup-scom.ps1) | 70 lines | Validates SCOM setup: module, credentials, config file |
| [`setup-oneview.ps1`](../../scripts/setup-oneview.ps1) | 89 lines | Validates OneView setup: module, credentials, config file |
| [`cyberark-bootstrap.ps1`](../../scripts/cyberark-bootstrap.ps1) | 139 lines | Fetches secrets from CyberArk CCP, exports as env vars for GitLab CI |

<a name="154---documentation-and-coverage-scripts"></a>
### 15.4 - Documentation & Coverage Scripts
<a name="154---documentation-and-coverage-scripts-1"></a>
### 15.4 - Documentation & Coverage Scripts

| Script | File | Purpose |
|--------|------|---------|
| [`Generate-PSDocs.ps1`](../../scripts/Generate-PSDocs.ps1) | 269 lines | Auto-generates Markdown API reference from comment-based help blocks |
| [`coverage-report.ps1`](../../scripts/coverage-report.ps1) | 327 lines | Runs Pester with code coverage, generates Cobertura XML + Markdown report |
| [`CoverageSummary.ps1`](../../scripts/CoverageSummary.ps1) | 121 lines | Converts Cobertura XML to human-readable table |
| [`Show-Help.ps1`](../../scripts/Show-Help.ps1) | 35 lines | Displays Makefile documented targets |

---

<a name="16-configuration-files"></a>
## 16. Configuration Files

All configs loaded from `configs/` directory:

| File | Purpose | Loaded By |
|------|---------|-----------|
| **`request_types.json`** | Request type → handler mapping, CI stage map | [`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1#L7) |
| **`server_list.txt`** | Server hostnames with optional IPMI/iLO IPs | [`Inventory.ps1`](../../src/powershell/Automation/Private/Inventory.ps1#L5) |
| **`clusters_catalogue.json`** | Cluster definitions with servers, SCOM groups, OneView scopes | [`Inventory.ps1`](../../src/powershell/Automation/Private/Inventory.ps1#L46) |
| **`hpe_firmware_drivers_nov2025.json`** | HPE SUT firmware/driver component manifest | [`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1#L91) |
| **`windows_patches.json`** | Windows security patch KB list (MSU packages) | [`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1#L100) |
| **`opsramp_config.json`** | OpsRamp API credentials + base URL | [`OpsRamp_Client`](../../src/powershell/Automation/Automation.psm1#L161) |
| ~~maintenance-only configs~~ | *See [Code_Map_Maitenance_Mode.md §11](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)* | - |
| ~~maintenance-only configs~~ | *See [Code_Map_Maitenance_Mode.md §11](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)* | - |

---

<a name="17-testing"></a>
## 17. Testing

<a name="171---pester-unit-tests"></a>
### 17.1 - Pester Unit Tests
<a name="171---pester-unit-tests-1"></a>
### 17.1 - Pester Unit Tests

| Test File | Tests |
|-----------|-------|
| [`Audit.Unit.Tests.ps1`](../../tests/powershell/Audit.Unit.Tests.ps1) | AuditLogger class |
| [`Config.Unit.Tests.ps1`](../../tests/powershell/Config.Unit.Tests.ps1) | Import-JsonConfig, Import-YamlConfig, ConvertTo-Hashtable, env-var substitution |
| [`Credentials.Unit.Tests.ps1`](../../tests/powershell/Credentials.Unit.Tests.ps1) | Credential resolution, CyberArk fallback |
| [`Executor.Unit.Tests.ps1`](../../tests/powershell/Executor.Unit.Tests.ps1) | Invoke-NativeCommand, Invoke-NativeCommandWithRetry, New-CommandResult |
| [`FileIO.Unit.Tests.ps1`](../../tests/powershell/FileIO.Unit.Tests.ps1) | Ensure-DirectoryExists, Save-Json, Load-Json, Save-JsonResult |
| [`Inventory.Unit.Tests.ps1`](../../tests/powershell/Inventory.Unit.Tests.ps1) | Load-ServerList, Load-ClusterCatalogue, Test-ClusterDefinition, New-ServerInfo |
| [`New-ScomConnection.Unit.Tests.ps1`](../../tests/powershell/New-ScomConnection.Unit.Tests.ps1) | New-ScomConnection, REST connection |
| [`New-ScomMaintenanceScript.Unit.Tests.ps1`](../../tests/powershell/New-ScomMaintenanceScript.Unit.Tests.ps1) | SCOM maintenance script generation |
| [`New-Uuid.Unit.Tests.ps1`](../../tests/powershell/New-Uuid.Unit.Tests.ps1) | Deterministic UUID generation |
| [`Router.Unit.Tests.ps1`](../../tests/powershell/Router.Unit.Tests.ps1) | Invoke-RoutedRequest, Get-RouteMap, request type dispatch |
| [`Set-MaintenanceMode.Unit.Tests.ps1`](../../tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1) | *See maintenance mode code map* |
| [`Validators.Unit.Tests.ps1`](../../tests/powershell/Validators.Unit.Tests.ps1) | Test-BuildParams, Test-ClusterId, Test-ServerList |

<a name="172---test-execution-scripts"></a>
### 17.2 - Test Execution Scripts
<a name="172---test-execution-scripts-1"></a>
### 17.2 - Test Execution Scripts

| Script | Purpose |
|--------|---------|
| [`run-tests.ps1`](../../scripts/run-tests.ps1) | Main test runner: auto-repairs Pester, runs all Pester tests with summary |
| [`run-maint-mode-tests.ps1`](../../scripts/run-maint-mode-tests.ps1) | High-priority maintenance mode tests only |
| [`run-maintenance-tests.ps1`](../../scripts/run-maintenance-tests.ps1) | Full maintenance test suite with environment/DateTime/connection filters |
| [`test-maintenance-connection.ps1`](../../scripts/test-maintenance-connection.ps1) | Connectivity test for SCOM/OneView |
| [`validate-maintenance-config.ps1`](../../scripts/validate-maintenance-config.ps1) | Configuration file + module validation |

<a name="173---coverage-and-lint"></a>
### 17.3 - Coverage & Lint
<a name="173---coverage-and-lint-1"></a>
### 17.3 - Coverage & Lint

| Script | Purpose |
|--------|---------|
| [`coverage-report.ps1`](../../scripts/coverage-report.ps1) | Cobertura XML coverage + Markdown report |
| [`CoverageSummary.ps1`](../../scripts/CoverageSummary.ps1) | Human-readable coverage table |
| [`lint.ps1`](../../scripts/lint.ps1) | Syntax validation + PSScriptAnalyzer |
| [`ci-security-check.ps1`](../../scripts/ci-security-check.ps1) | Security scan: PSScriptAnalyzer + secrets detection + JSON validation |

---

<a name="18-quick-navigation"></a>
## 18. Quick Navigation

| User Journey | Entry Point | Handler | Key File | Lines |
|--------------|-------------|---------|----------|-------|
| **Build ISO** | `New-IsoBuild` | `FirmwareUpdater` + `WindowsPatcher` | [`New-IsoBuild.ps1`](../../src/powershell/Automation/Public/New-IsoBuild.ps1) | L5–82 |
| **Update firmware** | `Update-Firmware` | `FirmwareUpdater` | [`Update-Firmware.ps1`](../../src/powershell/Automation/Public/Update-Firmware.ps1) | L13–73 |
| **Patch Windows** | `Invoke-WindowsSecurityUpdate` | `WindowsPatcher` | [`Update-WindowsSecurity.ps1`](../../src/powershell/Automation/Public/Update-WindowsSecurity.ps1) | L8–84 |
| **Deploy ISO** | `Invoke-IsoDeploy` | `ISODeployer` | [`Invoke-IsoDeploy.ps1`](../../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1) | L22–80 |
| **Monitor install** | `Start-InstallMonitor` | `InstallationMonitor` | [`Start-InstallMonitor.ps1`](../../src/powershell/Automation/Public/Start-InstallMonitor.ps1) | L8–64 |
| **OpsRamp metric** | `Invoke-OpsRampClient` | `OpsRamp_Client` | [`Invoke-OpsRampClient.ps1`](../../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1) | L5–50 |
| **Local script** | `Invoke-PowerShellScript` | New process | [`Invoke-PowerShellScript.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1) | L5–74 |
| **Remote WinRM** | `Invoke-PowerShellWinRM` | `New-PSSession` | [`Invoke-PowerShellWinRM.ps1`](../../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1) | L5–60 |
| **Generate UUID** | `New-Uuid` | SHA-256 hash | [`New-Uuid.ps1`](../../src/powershell/Automation/Public/New-Uuid.ps1) | L8–64 |
| **CI pipeline** | `Run-CIPipeline` | `_Build-CIParams` | [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) | L193–201 |
| **iRequest handler** | `Run-IRequest` | `_Build-IRequestParams` | [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) | L207–226 |
| **Scheduler task** | `Run-Scheduler` | `_Build-SchedulerParams` | [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) | L232–251 |
| **GitLab maintenance** | `Run-GitLab` | `Invoke-GitLabMaintenanceTrigger` | [`Control.ps1`](../../src/powershell/Automation/Public/Control.ps1) | L289–308 |
| **Validate build** | `Test-BuildParams` | File validation | [`Test-BuildParams.ps1`](../../src/powershell/Automation/Public/Test-BuildParams.ps1) | L5–35 |
| **Validate cluster** | `Test-ClusterId` | Catalogue lookup | [`Test-ClusterId.ps1`](../../src/powershell/Automation/Public/Test-ClusterId.ps1) | L5–73 |
| **Validate servers** | `Test-ServerList` | File parse | [`Test-ServerList.ps1`](../../src/powershell/Automation/Public/Test-ServerList.ps1) | L5–46 |

---

*Document updated: 2026-06-19*
*Maintenance mode excluded - see [`Code_Map_Maitenance_Mode.md`](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)*
*Maintenance mode excluded - see [`Code_Map_Maitenance_Mode.md`](../Maintenance-Mode/Code_Map_Maitenance_Mode.md#top)*



