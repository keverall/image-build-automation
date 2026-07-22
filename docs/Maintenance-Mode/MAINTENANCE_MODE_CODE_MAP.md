# Maintenance Mode (mm) Command - Complete Code Map

<a id="top"></a>
## Table of Contents

- [1. Entry Points & User Interface](#1-entry-points-and-user-interface)
  - [PowerShell Profile Functions](#powershell-profile-functions)
- [2. Core Implementation](#2-core-implementation)
  - [Main Function](#main-function)
- [3. SCOM Integration](#3-scom-integration)
  - [SCOMManager Class](#scommanager-class)
- [4. HPE OneView Integration](#4-hpe-oneview-integration)
  - [OneViewClient Class](#oneviewclient-class)
- [5. Email Notifications](#5-email-notifications)
  - [EmailNotifier Class](#emailnotifier-class)
- [6. Helper Functions](#6-helper-functions)
  - [Datetime Parsing](#datetime-parsing)
  - [Scheduling](#scheduling)
  - [Audit & Logging](#audit-and-logging)
- [7. Configuration Files](#7-configuration-files)
- [8. Module Loading & Routing](#8-module-loading-and-routing)
  - [Module Structure](#module-structure)
  - [Request Router](#request-router)
- [9. Testing & Validation](#9-testing-and-validation)
  - [Test Scripts](#test-scripts)
  - [Test Files](#test-files)
- [11. Documentation References](#11-documentation-references)
- [10. Execution Flow Summary](#10-execution-flow-summary)
- [Quick Navigation for Clients](#quick-navigation-for-clients)
This document provides a complete map of all code locations hit by the `Set-MaintenanceMode` command, with direct links to source files for client review.

---

<a name="1-entry-points-and-user-interface"></a>
## 1. Entry Points & User Interface

<a name="powershell-profile-functions"></a>
### PowerShell Profile Functions
- **`Set-MaintenanceMode`**: [`Setup-Profile.ps1`](../../scripts/Setup-Profile.ps1) - Adds module import to profile
- **Command Syntax**:
```powershell
Set-MaintenanceMode -Action <enable|disable|validate> -TargetId <cluster-id> -Mode <scom|oneview> [-Environment <Test|Prod>] [options]
```

---

<a name="2-core-implementation"></a>
## 2. Core Implementation

<a name="main-function"></a>
### Main Function
- **`Set-MaintenanceMode`**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1)
  - **Lines 306-321**: Parameter definitions (Action, TargetId, Mode, Environment, etc.)
  - **Lines 323-339**: Mode validation and normalization
  - **Lines 762-800**: Environment-based host resolution from `connection_hosts.json`
  - **Lines 803-858**: Credential resolution (environment variables → parameters → interactive)
  - **Lines 954-979**: Connection validation before execution
  - **Lines 985-1064**: Enable action execution
  - **Lines 1065-1136**: Disable action execution
  - **Lines 464-761**: Validate action (check maintenance status)

---

<a name="3-scom-integration"></a>
## 3. SCOM Integration

<a name="scommanager-class"></a>
### SCOMManager Class
**Location**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1364)

#### Key Methods:
- **`EnterMaintenance`** (line 1450): Enable maintenance mode for SCOM groups/clusters
  - Lines 1455-1488: Dry-run mock data
  - Lines 1490-1499: Version detection and REST API routing
  - Lines 1502-1551: PowerShell cmdlet execution for older SCOM versions
  - Lines 1683-1769: REST API implementation for SCOM 2019 UR1+ and 2025

- **`ExitMaintenance`** (line 1553): Disable maintenance mode
  - Lines 1557-1589: Dry-run mock data
  - Lines 1591-1636: REST API and PowerShell cmdlet execution

- **`GetMaintenanceStatus`** (line 1805): Query current maintenance status
  - Lines 1810-1885: PowerShell cmdlet-based status check
  - Lines 1887-1998: REST API-based status check

- **`_DetectVersion`** (line 1405): Auto-detect SCOM version and REST API readiness

#### Connection Validation:
- **`Test-ScomConnection`**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1235)

---

<a name="4-hpe-oneview-integration"></a>
## 4. HPE OneView Integration

<a name="oneviewclient-class"></a>
### OneViewClient Class
**Location**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2002)

#### Key Methods:
- **`SetMaintenance`** (line 2030): Enable maintenance mode
  - Lines 2037-2149: Module-based implementation
  - Lines 2052-2111: Server hardware mode
  - Lines 2112-2148: Scope (cluster) mode

- **`DisableMaintenance`** (line 2155): Disable maintenance mode
  - Lines 2162-2274: Module-based disable implementation

- **`GetMaintenanceStatus`** (line 2337): Query maintenance status
  - Lines 2344-2436: Status check via OneView PowerShell module

- **`ResolveTarget`** (line 2280): Resolve server name or serial number to OneView target
  - Lines 2281-2289: Dry-run mock data
  - Lines 2290-2334: Server and scope resolution

#### Connection Validation:
- **`Test-OneViewConnection`**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1259)

---

<a name="5-email-notifications"></a>
## 5. Email Notifications

<a name="emailnotifier-class"></a>
### EmailNotifier Class
**Location**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2444)

- **`SendMaintenanceNotification`** (line 2479): Send enable/disable notifications
- Distribution list management from `email_distribution_lists.json`
- Template-based email formatting

---

<a name="6-helper-functions"></a>
## 6. Helper Functions

<a name="datetime-parsing"></a>
### Datetime Parsing
- **`_Parse-Datetime`**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1285)
  - Supports: `now`, `+Xhours`, `+Xminutes`, `+Xdays`, `YYYY-MM-DD HH:MM`

<a name="scheduling"></a>
### Scheduling
- **`_Compute-NextWorkStart`**: Line 1332 - Calculate next maintenance window end time
- **`_Compute-DefaultEnd`**: Line 1321 - Default end time calculation

<a name="audit-and-logging"></a>
### Audit & Logging
- **`_Save-AuditRecord`**: [`Set-MaintenanceMode.ps1`](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1347)
- **`Initialize-Logging`**: [`Logging.ps1`](../../src/powershell/Automation/Private/Logging.ps1)

---

<a name="7-configuration-files"></a>
## 7. Configuration Files

All configurations loaded from `configs/` directory:

- **`clusters_catalogue.json`**: Cluster definitions with servers, SCOM groups, OneView scopes
- **`scom_config.json`**: SCOM management server settings and PowerShell module configuration
- **`oneview_config.json`**: OneView appliance configuration and credentials
- **`connection_hosts.json`**: Environment-based host resolution (Test/Prod environments)
- **`email_distribution_lists.json`**: Email notification recipients per action
- **`opsramp_config.json`**: OpsRamp integration settings for metrics and alerting

---

<a name="8-module-loading-and-routing"></a>
## 8. Module Loading & Routing

<a name="module-structure"></a>
### Module Structure
- **Root module**: [`Automation.psm1`](../../src/powershell/Automation/Automation.psm1)
  - Lines 397-421: Private script loading (dependency-ordered)
  - Lines 424-429: Public script loading (alphabetical)
  - Line 449: `Set-MaintenanceMode` export

<a name="request-router"></a>
### Request Router
- **`Invoke-RoutedRequest`**: [`Router.ps1`](../../src/powershell/Automation/Private/Router.ps1)
  - Routes maintenance requests from `request_types.json` configuration

---

<a name="9-testing-and-validation"></a>
## 9. Testing & Validation

<a name="test-scripts"></a>
### Test Scripts
- **Connection testing**: [`test-maintenance-connection.ps1`](../../scripts/test-maintenance-connection.ps1)
- **Configuration validation**: [`validate-maintenance-config.ps1`](../../scripts/validate-maintenance-config.ps1)
- **Test runner**: [`run-maintenance-tests.ps1`](../../scripts/run-maintenance-tests.ps1)

<a name="test-files"></a>
### Test Files
- **PowerShell tests**: Search for `*.Tests.ps1` in `src/powershell/Tests/`

---

<a name="11-documentation-references"></a>
## 11. Documentation References

- **Architecture overview**: [`maintenance_mode.md`](maintenance_mode.md#top)
- **Quick start guide**: [`MAINTENANCE_MODE_SHORTCUTS.md`](MAINTENANCE_MODE_SHORTCUTS.md#top)
- **Environment configuration**: [`maintenance-mode-environment-config.md`](maintenance-mode-environment-config.md#top)
- **Command shortcuts**: [`MAINTENANCE_MODE_SHORTCUTS.md`](MAINTENANCE_MODE_SHORTCUTS.md#top)
- **Setup guide**: [`SETUP-GUIDE.md`](../SETUP-GUIDE.md#top)
- **PowerShell API reference**: [`powershell_api_reference.md`](../Generic/powershell_api_reference.md#top)

---

<a name="10-execution-flow-summary"></a>
## 10. Execution Flow Summary

```
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
    ↓
PowerShell Profile (module import via Setup-Profile.ps1)
    ↓
Set-MaintenanceMode (Public/Set-MaintenanceMode.ps1:174)
    ↓
├─ Load configs (clusters_catalogue.json, scom_config.json, etc.)
├─ Resolve environment & management host (connection_hosts.json)
├─ Resolve credentials (env vars or prompt)
├─ Validate connection (Test-ScomConnection / Test-OneViewConnection)
    ↓
├─ SCOM Mode:
│   ├─ SCOMManager.EnterMaintenance() (line 1450)
│   ├─ SCOMManager.ExitMaintenance() (line 1553)
│   └─ SCOMManager.GetMaintenanceStatus() (line 1805)
│
├─ OneView Mode:
│   ├─ OneViewClient.SetMaintenance() (line 2030)
│   ├─ OneViewClient.DisableMaintenance() (line 2155)
│   └─ OneViewClient.GetMaintenanceStatus() (line 2337)
    ↓
├─ EmailNotifier.SendMaintenanceNotification() (line 2479)
├─ OpsRamp metrics/alerts (if configured)
└─ Save audit record (_Save-AuditRecord, line 1347)
```

---

<a name="quick-navigation-for-clients"></a>
## Quick Navigation for Clients

| Functionality | SCOM | OneView |
|--------------|------|---------|
| **Enable Maintenance** | [SCOMManager.EnterMaintenance](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1450) | [OneViewClient.SetMaintenance](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2030) |
| **Disable Maintenance** | [SCOMManager.ExitMaintenance](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1553) | [OneViewClient.DisableMaintenance](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2155) |
| **Validate Status** | [SCOMManager.GetMaintenanceStatus](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1805) | [OneViewClient.GetMaintenanceStatus](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2337) |
| **Connection Test** | [Test-ScomConnection](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1235) | [Test-OneViewConnection](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1259) |
| **Target Resolution** | N/A (uses SCOM groups) | [OneViewClient.ResolveTarget](../../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2280) |

---

*Document generated: 2026-06-12*
*For questions about specific code locations, refer to the line numbers provided in the links above.*



