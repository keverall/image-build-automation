# Maintenance Mode (mm) Command - Complete Code Map

This document provides a complete map of all code locations hit by the `Set-MaintenanceMode` command, with direct links to source files for client review.

> **Source file**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1) — 3,803 lines total.

---

## 1. Entry Points & User Interface

### Script-Mode Parameter Block
- **Location**: 
- [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L8) (Lines 8–31)
- Supports two invocation modes:
  1. **Human-readable** (default): direct command-line usage
  2. **JSON** (`-Json` flag): iRequest/REST API integration

### Help Flag
- **`-ShowHelp`**: Line 34 — Displays usage summary and exits

### PowerShell Profile Functions
- **`Set-MaintenanceMode`**: [`Setup-Profile.ps1`](../scripts/Setup-Profile.ps1) — Adds module import to profile

### Command Syntax
```powershell
Set-MaintenanceMode -Action <enable|disable|validate> -TargetId <cluster-id> -Mode <scom|oneview>
    [-Environment <Test|Prod>] [-ManagementHost <hostname>]
    [-SerialNumber <serial>] [-Username <user>]
    [-Start <datetime>] [-End <datetime>]
    [-PostDisableWaitSeconds <int>] [-DryRun] [-NoSchedule] [-Json]
```

---

## 2. Core Implementation

### Main Function
- **`Set-MaintenanceMode`**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L173)

#### Parameter Definitions
- **Lines 306–321**: `param()` block — Action, TargetId, Mode, Environment, ManagementHost, SerialNumber, Username, PostDisableWaitSeconds, ConfigDir, Start, End, DryRun, MockMaintenanceState, NoSchedule

#### Mode Validation & Normalization
- **Lines 326–341**: Mode lowercasing and validation; TargetId empty check with OneView SerialNumber bypass

#### Configuration Loading
- **[`Lines 343–363`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L343-L363)**: ConfigDir resolution (parameter > project root fallback)
- **[`Lines 365–372`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L365-L372)**: JSON config file loading:
  - `clusters_catalogue.json` ([line 366](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L366))
  - `scom_config.json` ([line 367](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L367))
  - `oneview_config.json` ([line 368](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L368))
  - `email_distribution_lists.json` ([line 369](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L369))
  - `opsramp_config.json` ([line 370](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L370))
  - `servers_catalogue.oneview.json` ([line 371](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L371))
  - `clusters_catalogue.scom.json` ([line 372](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L372))

#### Lookup Table Construction
- **[`Lines 374–389`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L374-L389)**: SCOM hostname lookup from `clusters_catalogue.scom.json`
- **[`Lines 391–413`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L391-L413)**: Server serial/name lookup from `servers_catalogue.oneview.json`
- **[`Lines 415–420`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L415-L420)**: `_Resolve-ServerNameFromSerial` nested function

#### Target Resolution
- **[`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655)**: Cluster/server target resolution logic
  - Cluster catalogue lookup
  - Direct server mode (single server not in a cluster)
  - OneView serial-number-based server resolution

#### Environment-Based Host Resolution
- **[`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699)**: Environment config loading from `connection_hosts.json`
  - [`Lines 666–672`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L666-L672): Environment determination (parameter > `$env:ENVIRONMENT` > `'Prod'`)
  - [`Lines 677–692`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L677-L692): Host resolution from environment config
  - [`Lines 680–692`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L680-L692): ManagementHost override via parameter or `$env:MAINTENANCE_HOST`

#### Validate Action
- **[`Lines 702–983`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L702-L983)**: Full validate action implementation
  - [`Lines 716–810`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L716-L810): DryRun mock validation
  - [`Lines 812–847`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L812-L847): SCOM validation via `SCOMManager.GetMaintenanceStatus()`
  - [`Lines 848–897`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L848-L897): OneView validation (including `ResolveServerBySerial` at [line 861](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L861))
  - [`Lines 899–983`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L899-L983): Result assembly and return

#### Credential Resolution
- **[`Lines 986–1050`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L986-L1050)**: Parameter > env var > interactive prompt resolution
  - [`Lines 992–1000`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L992-L1000): Username resolution (`SCOM_ADMIN_USER` / `ONEVIEW_USER`)
  - [`Lines 1002–1008`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1002-L1008): Password resolution (`SCOM_ADMIN_PASSWORD` / `ONEVIEW_PASSWORD`)
  - [`Lines 1010–1033`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1010-L1033): Interactive prompt fallback (when `AUTOMATED_MODE` is not `'true'`)

#### Finalize Start/End Times
- **[`Lines 1055–1090`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1055-L1090)**: Catalogue-based default end time and schedule adjustments

#### Manager Instantiation
- **[`Lines 1092–1151`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1092-L1151)**: Initialize SCOMManager / OneViewClient
  - [`Lines 1097–1108`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1097-L1108): SCOMManager construction and credential injection
  - [`Lines 1111–1151`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1111-L1151): OneViewClient construction, credential injection, and target resolution

#### Email & OpsRamp Initialization
- **[`Line 1153`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1153)**: `[EmailNotifier]` construction
- **[`Lines 1155–1162`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1155-L1162)**: `[OpsRamp_Client]` construction (if configured)

#### Connection Validation
- **[`Lines 1164–1199`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1164-L1199)**: Pre-execution connection testing
  - [`Lines 1166–1177`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1166-L1177): `Test-ScomConnection` call
  - [`Lines 1179–1198`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1179-L1198): `Test-OneViewConnection` call

#### Enable Action
- **[`Lines 1241–1493`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1241-L1493)**: Full enable action execution
  - [`Lines 1242–1284`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1242-L1284): Pre-check for already-enabled maintenance
  - [`Lines 1289–1361`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1289-L1361): SCOM enable via `SCOMManager.EnterMaintenance()` ([line 1343](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1343))
  - [`Lines 1363–1443`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1363-L1443): OneView enable via `OneViewClient.SetMaintenance()` ([line 1432](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1432))
  - [`Lines 1445–1450`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1445-L1450): Email notification via `EmailNotifier.SendMaintenanceNotification()` ([line 1446](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1446))
  - [`Lines 1452–1493`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1452-L1493): OpsRamp metrics/alerts/events ([`Lines 1466–1478`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1466-L1478))
  - [`Lines 1480–1493`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1480-L1493): Windows Task Scheduler creation for auto-disable

#### Disable Action
- **[`Lines 1495–1639`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1495-L1639)**: Full disable action execution
  - [`Lines 1496–1538`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1496-L1538): Pre-check for already-disabled maintenance
  - [`Lines 1540–1573`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1540-L1573): SCOM disable via `SCOMManager.ExitMaintenance()` ([line 1546](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1546))
    - [`Lines 1557–1572`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1557-L1572): Post-disable stabilization wait
  - [`Lines 1575–1596`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1575-L1596): OneView disable via `OneViewClient.DisableMaintenance()` ([line 1588](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1588))
  - [`Lines 1598–1605`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1598-L1605): Email notification ([line 1600](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1600))
  - [`Lines 1607–1639`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1607-L1639): OpsRamp metrics/alerts/events ([`Lines 1619–1635`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1619-L1635))

#### Audit & Result Construction
- **[`Lines 1641–1712`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1641-L1712)**: Audit record finalization and detail message assembly
- **[`Lines 1714–1718`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1714-L1718)**: Console output of result summary
- **[`Lines 1720–1800`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1720-L1800)**: Response hashtable with per-mode summaries
  - [`Lines 1734–1769`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1734-L1769): Core result fields
  - [`Lines 1772–1790`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1772-L1790): SCOM/OneView-specific result fields

---

## 3. Connection Validation Helpers

- **`Test-ScomConnection`**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846)
  - [`Lines 1846–1868`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846-L1868): Tests SCOM management group connection via PowerShell cmdlet
  - Default module: `OperationsManager`

- **`Test-OneViewConnection`**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870)
  - [`Lines 1870–1894`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870-L1894): Tests OneView appliance connection via `Connect-OVMgmt`
  - Default module: `HPEOneView.840`

---

## 4. Helper Functions

### Datetime Parsing
- **`_Parse-Datetime`**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896)
  - [`Lines 1896–1954`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896-L1954): Parses datetime from multiple formats
  - Supports: `now`, `+Xseconds`, `+Xminutes`, `+Xhours`, `+Xdays`, `YYYY-MM-DD HH:MM[:SS]`
  - All times treated as UTC

### Scheduling
- **[``_Compute-DefaultEnd``](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1956)**: Line 1956 — Calculates default end time (7am UTC Monday following start)
- **[`_Compute-NextWorkStart`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1971)**: Line 1971 — Calculates next work-start time from maintenance schedule config

### Status Formatting
- **[`_Compute-OverallStatus`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1989)**: Line 1989 — Returns `fully_in_maintenance`, `partially_in_maintenance`, or `not_in_maintenance`
- **[`_Format-StatusState`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1995)**: Line 1995 — Maps overall status to human-readable state text
- **[`_Format-StatusMessage`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2003)**: Line 2003 — Builds detailed status message string

### Audit & Logging
- **`_Save-AuditRecord`**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012)
  - [`Lines 2012–2028`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012-L2028): Saves JSON audit record to file and appends to master log
  - Includes GitLab context enrichment if available
- **`Initialize-Logging`**: [`Logging.ps1`](../src/powershell/Automation/Private/Logging.ps1)

---

## 5. SCOM Integration

### SCOMManager Class
**Location**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2031) ([`Lines 2031–2775`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2031-L2775))

#### Properties
- [`Lines 2032–2038`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2032-L2038): `Config`, `MgmtServer`, `ModuleName`, `UseWinRM`, `Cred`, `ScomVersion`, `RestApiReady`

#### Constructor
- [`SCOMManager([hashtable]$Config)`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2040-L2061): Lines 2040–2061 — Initializes from config, resolves credentials from environment variables

#### Key Methods:

- **[`_RunPs`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2063)** (line 2063): Execute PowerShell locally or via WinRM
  - [`Lines 2063–2073`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2063-L2073): Routes to `Invoke-PowerShellWinRM` or `Invoke-PowerShellScript`

- **[`_DetectVersion`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2075)** (line 2075): Auto-detect SCOM version and REST API readiness
  - [`Lines 2075–2114`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2075-L2114): Queries `Get-SCOMManagementServer` and tests REST `/authenticate` endpoint
  - Sets `$this.ScomVersion` (2012/2016/2019/2025) and `$this.RestApiReady`

- **[`GetGroupMembers`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2116)** (line 2116): Retrieve group member names from SCOM
  - [`Lines 2116–2130`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2116-L2130): PowerShell cmdlet execution to enumerate group instances

- **[`EnterMaintenance`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132)** (line 2132): Enable maintenance mode for SCOM groups/clusters
  - [`Lines 2132–2262`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132-L2262): Full enable implementation
  - [`Lines 2137–2174`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2137-L2174): Dry-run mock data generation
  - [Line 2176](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2176): Version detection via `_DetectVersion()`
  - [`Lines 2182–2184`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2182-L2184): REST API routing (SCOM 2019 UR1+ and 2025)
  - [`Lines 2187–2261`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2187-L2261): PowerShell cmdlet execution for older SCOM versions
  - [`Lines 2197–2251`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2197-L2251): Per-object status parsing (`OBJECT_STATUS:` and `SUMMARY:` JSON lines)

- **[`ExitMaintenance`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264)** (line 2264): Disable maintenance mode
  - [`Lines 2264–2442`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264-L2442): Full disable implementation
  - [`Lines 2268–2304`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2268-L2304): Dry-run mock data generation
  - [`Lines 2306–2368`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2306-L2368): REST API path with per-object status parsing
  - [`Lines 2371–2441`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2371-L2441): PowerShell cmdlet path

- **[`_EnterMaintenanceRest`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2448)** (line 2448): SCOM REST API maintenance enable
  - [`Lines 2448–2536`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2448-L2536): Authenticate, resolve monitoring object IDs, call `POST /ScheduleMaintenance`

- **[`_ExitMaintenanceRest`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2538)** (line 2538): SCOM REST API maintenance disable
  - [`Lines 2538–2576`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2538-L2576): Generates PowerShell cmdlet script (REST API lacks direct maintenance stop endpoint)

- **[`GetMaintenanceStatus`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578)** (line 2578): Query current maintenance status
  - [`Lines 2578–2658`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578-L2658): Full status query implementation
  - [Line 2582](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2582): REST API routing for SCOM 2019+
  - [`Lines 2587–2657`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2587-L2657): PowerShell cmdlet-based status check for older versions

- **[`_GetMaintenanceStatusRest`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2660)** (line 2660): REST API-based status check
  - [`Lines 2660–2775`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2660-L2775): Authenticate via REST, enumerate monitoring objects, check maintenance state

---

## 6. HPE OneView Integration

### OneViewClient Class
**Location**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2777) ([`Lines 2777–3431`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2777-L3431))

#### Properties
- [`Lines 2778–2784`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2778-L2784): `Config`, `Appliance`, `ModuleName`, `UseWinRM`, `WinRMServer`, `Username`, `Password`

#### Constructor
- [`OneViewClient([hashtable]$Config)`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2786-L2807): Lines 2786–2807 — Initializes from config, detects module version, validates compatibility, resolves credentials

#### Module Compatibility
- [`Lines 2809–2820`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2809-L2820): Static `$OneViewModuleApplianceMap` — Maps HPEOneView module versions (700–1000) to minimum appliance firmware and PS version
- **[`_DetectRecommendedModule`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2822)** (line 2822): Auto-detect best module from installed modules
- **[`_ValidateModuleCompat`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2842)** (line 2842): Warns about PS version incompatibilities

#### Key Methods:

- **[`SetMaintenance`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864)** (line 2864): Enable maintenance mode (public dispatch)
  - [`Lines 2864–2869`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864-L2869): Routes to `_SetViaModule` or `_SetViaWinRM`

- **[`_SetViaModule`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2871)** (line 2871): Module-based enable implementation
  - [`Lines 2871–2982`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2871-L2982): Full implementation with `Enable-OVMaintenanceMode`
  - [`Lines 2886–2912`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2886-L2912): ServerHardware mode (single server)
  - [`Lines 2913–2944`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2913-L2944): Scope (cluster) mode — iterates scope members

- **[`_SetViaWinRM`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2984)** (line 2984): WinRM delegate (routes to `_SetViaModule`)

- **[`DisableMaintenance`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988)** (line 2988): Disable maintenance mode (public dispatch)
  - [`Lines 2988–2993`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988-L2993): Routes to `_DisableViaModule` or `_DisableViaWinRM`

- **[`_DisableViaModule`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2995)** (line 2995): Module-based disable implementation
  - [`Lines 2995–3107`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2995-L3107): Full implementation with `Disable-OVMaintenanceMode`
  - [`Lines 3010–3036`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3010-L3036): ServerHardware mode
  - [`Lines 3037–3106`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3037-L3106): Scope (cluster) mode

- **[`_DisableViaWinRM`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3108)** (line 3108): WinRM delegate (routes to `_DisableViaModule`)

- **[`ResolveTarget`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112)** (line 3112): Resolve server name or scope name to OneView target
  - [`Lines 3112–3176`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112-L3176): Full implementation
  - [`Lines 3113–3122`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3113-L3122): DryRun mock data
  - [`Lines 3130–3143`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3130-L3143): Server lookup via `Get-OVServer`, scope lookup via `Get-OVSCOPE`

- **[`GetMaintenanceStatus`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178)** (line 3178): Query maintenance status (public dispatch)
  - [`Lines 3178–3183`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178-L3183): Routes to `_GetMaintenanceStatusViaModule` or `_GetMaintenanceStatusViaWinRM`

- **[`_GetMaintenanceStatusViaModule`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3185)** (line 3185): Module-based status check
  - [`Lines 3185–3276`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3185-L3276): Full implementation
  - [`Lines 3197–3211`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3197-L3211): ServerHardware status check
  - [`Lines 3212–3231`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3212-L3231): Scope status check (iterates members)

- **[`_GetMaintenanceStatusViaWinRM`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3278)** (line 3278): WinRM delegate (routes to `_GetMaintenanceStatusViaModule`)

- **[`ResolveServerBySerial`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282)** (line 3282): Resolve server by serial number
  - [`Lines 3282–3430`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282-L3430): Full implementation with REST API primary and cmdlet fallback
  - [`Lines 3326–3363`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3326-L3363): REST API serial lookup (API v200+)
  - [`Lines 3365–3393`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3365-L3393): `Get-OVServer -SerialNumber` cmdlet fallback

---

## 7. Email Notifications

### EmailNotifier Class
**Location**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3434) ([`Lines 3434–3567`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3434-L3567))

#### Properties
- [`Lines 3435–3444`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3435-L3444): `Config`, `SmtpServer`, `SmtpPort`, `UseTls`, `UseSsl`, `FromAddr`, `Templates`, `UseSimple`, `SimpleRecipients`, `DistLists`

#### Constructor
- [`EmailNotifier([hashtable]$Config)`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3446-L3460): Lines 3446–3460 — Loads SMTP settings, templates, distribution lists; checks for flat distribution list file

#### Key Methods:

- **[`_GetRecipients`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3462)** (line 3462): Resolve email recipients
  - [`Lines 3462–3471`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3462-L3471): Returns simple list or distribution list by action key

- **[`SendMaintenanceNotification`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473)** (line 3473): Send enable/disable email notifications
  - [`Lines 3473–3566`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473-L3566): Full implementation
  - [`Lines 3475–3479`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3475-L3479): Skip if no recipients configured
  - [`Lines 3500–3528`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3500-L3528): Template variable substitution
  - [`Lines 3531–3535`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3531-L3535): DryRun mode (log only, no send)
  - [`Lines 3538–3565`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3538-L3565): SMTP send via `System.Net.Mail.SmtpClient`

---

## 8. Script-Mode CLI Logic

- **Location**: [`Lines 3569–3803`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3569-L3803)
- [`Lines 3572–3591`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3572-L3591): Mode/TargetId/SerialNumber validation for CLI invocation
- [`Lines 3594–3598`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3594-L3598): Debug variable state output
- [Line 3600](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3600): Calls `Set-MaintenanceMode @PSBoundParameters`
- [`Lines 3602–3625`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3602-L3625): Error handling and CLI audit output
- [`Lines 3634–3640`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3634-L3640): JSON output mode (`-Json` flag)
- [`Lines 3643–3800`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3643-L3800): Human-readable output with per-object status tables, NACK summary, and final result

---

## 9. Configuration Files

All configurations loaded from `configs/` directory:

| File | Purpose | Loaded At |
|------|---------|-----------|
| **`clusters_catalogue.json`** | Cluster definitions with servers, SCOM groups, OneView scopes | Line 366 |
| **`clusters_catalogue.scom.json`** | SCOM-specific cluster-to-server hostname mapping | Line 372 |
| **`servers_catalogue.oneview.json`** | Server serial number / display name / OneView name lookup | Line 371 |
| **`scom_config.json`** | SCOM management server settings, PowerShell module config, maintenance settings | Line 367 |
| **`oneview_config.json`** | OneView appliance configuration, module detection, credentials | Line 368 |
| **`connection_hosts.json`** | Environment-based host resolution (Test/Prod SCOM and OneView hosts) | Line 659 |
| **`email_distribution_lists.json`** | Email notification recipients per action | Line 369 |
| **`opsramp_config.json`** | OpsRamp integration settings for metrics and alerting | Line 370 |
| **`request_types.json`** | Routes maintenance requests from the Router | (Router.ps1) |

---

## 10. Module Loading & Routing

### Module Structure
- **Root module**: [`Automation.psm1`](../src/powershell/Automation/Automation.psm1) (509 lines)
  - **[Lines 397–421](../src/powershell/Automation/Automation.psm1#L397-L421):** Private script loading (dependency-ordered)
    - Load order: `Audit.ps1` → `Config.ps1` → `Credentials.ps1` → `Executor.ps1` → `FileIO.ps1` → `PathResolver.ps1` → `Inventory.ps1` → `Logging.ps1` → `Router.ps1` → `Base.ps1`
  - **[Lines 424–429](../src/powershell/Automation/Automation.psm1#L424-L429):** Public script loading (alphabetical, all `*.ps1` in `Public/`)
  - **[Lines 433–505](../src/powershell/Automation/Automation.psm1#L433-L505):** `Export-ModuleMember` — exports public API surface
  - [Line 449](../src/powershell/Automation/Automation.psm1#L449): `Set-MaintenanceMode` export

### Request Router
- **`Invoke-RoutedRequest`**: [`Router.ps1`](../src/powershell/Automation/Private/Router.ps1#L20)
  - Routes maintenance requests from `request_types.json` configuration

### Key Dependencies (Private Scripts)
| Script | Purpose |
|--------|---------|
| `Audit.ps1` | `New-AuditLogger` factory |
| `Config.ps1` | `Import-JsonConfig`, `Import-YamlConfig`, config helpers |
| `Credentials.ps1` | `Get-EnvCredential`, `Get-IloCredentials`, credential helpers |
| `Executor.ps1` | `Invoke-NativeCommand`, `Invoke-NativeCommandWithRetry` |
| `FileIO.ps1` | `Ensure-DirectoryExists`, `Save-Json`, `Load-Json`, `Test-PathEx` |
| `PathResolver.ps1` | `Get-ProjectRoot`, `Get-LogDirectory` |
| `Inventory.ps1` | `Load-ServerList`, `Load-ClusterCatalogue`, `Test-ClusterDefinition` |
| `Logging.ps1` | `Initialize-Logging`, `Get-Logger` |
| `Router.ps1` | `Invoke-RoutedRequest` |
| `Base.ps1` | `AutomationBase` class, `New-AutomationBase` factory |

---

## 11. Testing & Validation

### Test Scripts
| Script | Purpose |
|--------|---------|
| [`test-maintenance-connection.ps1`](../scripts/test-maintenance-connection.ps1) | Connection testing |
| [`validate-maintenance-config.ps1`](../scripts/validate-maintenance-config.ps1) | Configuration validation |
| [`run-maintenance-tests.ps1`](../scripts/run-maintenance-tests.ps1) | Test runner (full maintenance test suite) |
| [`run-maint-mode-tests.ps1`](../scripts/run-maint-mode-tests.ps1) | Alternative maintenance mode test runner |

### Pester Test Files
| Test File | Coverage |
|-----------|----------|
| [`Set-MaintenanceMode.Unit.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1) | Core function unit tests |
| [`Set-MaintenanceMode.Enable.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1) | Enable action tests |
| [`Set-MaintenanceMode.Disable.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1) | Disable action tests |
| [`Set-MaintenanceMode.Validation.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1) | Validate action tests |
| [`Set-MaintenanceMode.Environment.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1) | Environment resolution tests |

---

## 12. Related Scripts and Modules

### Public SCOM/OneView Scripts
| Script | Purpose |
|--------|---------|
| [`New-ScomConnection.ps1`](../src/powershell/Automation/Public/New-ScomConnection.ps1) | SCOM connection factory |
| [`New-ScomMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1) | Generates SCOM maintenance PowerShell scripts |
| [`New-OneViewMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1) | Generates OneView maintenance PowerShell scripts |
| [`Invoke-GitLabMaintenanceTrigger.ps1`](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1) | GitLab CI maintenance trigger integration |
| [`_Validate-Request.ps1`](../src/powershell/Automation/Public/_Validate-Request.ps1) | Request validation (private helper) |

### Private Helper Scripts
| Script | Purpose |
|--------|---------|
| [`Credentials.ps1`](../src/powershell/Automation/Private/Credentials.ps1) | Credential resolution helpers |
| [`Audit.ps1`](../src/powershell/Automation/Private/Audit.ps1) | Audit logging |

---

## 13. Execution Flow Summary

```
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
    ↓
PowerShell Profile (module import via Setup-Profile.ps1)
    ↓
Set-MaintenanceMode function (Public/Set-MaintenanceMode.ps1:173)
    ↓
├─ Validate params (lines 326–341)
├─ Load configs (lines 365–372)
├─ Build lookup tables (lines 374–420)
├─ Resolve target from catalogue (lines 422–655)
├─ Resolve environment & management host (lines 657–699)
    ↓
├─ Validate action? (lines 702–983)
│   └─ Return validation result with status
    ↓
├─ Resolve credentials (lines 986–1050)
├─ Finalize Start/End times (lines 1055–1090)
├─ Initialize managers (lines 1092–1162)
│   ├─ [SCOMManager]::new() (line 1101)
│   ├─ [OneViewClient]::new() (line 1118)
│   ├─ [EmailNotifier]::new() (line 1153)
│   └─ [OpsRamp_Client]::new() (line 1158)
├─ Validate connection (lines 1164–1198)
│   ├─ Test-ScomConnection (line 1168)
│   └─ Test-OneViewConnection (line 1181)
    ↓
├─ Enable action (lines 1241–1493):
│   ├─ Pre-check: already enabled? (lines 1242–1284)
│   ├─ SCOM: SCOMManager.EnterMaintenance() (line 1343)
│   │   ├─ REST API path (2019 UR1+/2025) → _EnterMaintenanceRest() (line 2448)
│   │   └─ PowerShell cmdlet path → New-ScomMaintenanceScript (line 2188)
│   ├─ OneView: OneViewClient.SetMaintenance() (line 1432)
│   │   ├─ _SetViaModule() → Enable-OVMaintenanceMode (line 2871)
│   │   └─ _SetViaWinRM() → delegate (line 2984)
│   ├─ Email: SendMaintenanceNotification('enabled') (line 1446)
│   ├─ OpsRamp: metrics/alerts/events (lines 1454–1478)
│   └─ Schedule auto-disable task (lines 1480–1493)
│
├─ Disable action (lines 1495–1639):
│   ├─ Pre-check: already disabled? (lines 1496–1538)
│   ├─ SCOM: SCOMManager.ExitMaintenance() (line 1546)
│   │   ├─ REST API path → _ExitMaintenanceRest() (line 2538)
│   │   └─ PowerShell cmdlet path → New-ScomMaintenanceScript (line 2372)
│   ├─ OneView: OneViewClient.DisableMaintenance() (line 1588)
│   │   ├─ _DisableViaModule() → Disable-OVMaintenanceMode (line 2995)
│   │   └─ _DisableViaWinRM() → delegate (line 3108)
│   ├─ Post-disable stabilization wait (lines 1557–1572)
│   ├─ Email: SendMaintenanceNotification('disabled') (line 1600)
│   └─ OpsRamp: metrics/alerts/events (lines 1608–1635)
    ↓
├─ Audit record save (lines 1641–1712)
│   └─ _Save-AuditRecord (line 2012)
├─ Response construction (lines 1720–1800)
└─ CLI output formatting (lines 3569–3803)
```

---

## 14. Quick Navigation for Clients

| Functionality | SCOM | OneView |
|---------------|------|---------|
| **Enable Maintenance** | [SCOMManager.EnterMaintenance](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132) | [OneViewClient.SetMaintenance](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864) |
| **Disable Maintenance** | [SCOMManager.ExitMaintenance](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264) | [OneViewClient.DisableMaintenance](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988) |
| **Validate Status** | [SCOMManager.GetMaintenanceStatus](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578) | [OneViewClient.GetMaintenanceStatus](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178) |
| **Connection Test** | [Test-ScomConnection](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846) | [Test-OneViewConnection](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870) |
| **Target Resolution** | N/A (uses SCOM groups) | [OneViewClient.ResolveTarget](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112) |
| **Serial Lookup** | N/A | [OneViewClient.ResolveServerBySerial](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282) |
| **REST Enable** | [_EnterMaintenanceRest](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2448) | N/A |
| **REST Disable** | [_ExitMaintenanceRest](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2538) | N/A |
| **REST Status Check** | [_GetMaintenanceStatusRest](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2660) | N/A |
| **Email Notification** | [EmailNotifier.SendMaintenanceNotification](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473) | [EmailNotifier.SendMaintenanceNotification](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473) |
| **Datetime Parsing** | [_Parse-Datetime](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896) | [_Parse-Datetime](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896) |
| **Audit Record** | [_Save-AuditRecord](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012) | [_Save-AuditRecord](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012) |

---

## 15. Documentation References

- **Architecture overview**: [`maintenance_mode.md`](maintenance_mode.md)
- **Quick start guide**: [`MAINTENANCE_MODE_SHORTCUTS.md`](MAINTENANCE_MODE_SHORTCUTS.md)
- **Environment configuration**: [`maintenance-mode-environment-config.md`](maintenance-mode-environment-config.md)
- **Setup guide**: [`SETUP-GUIDE.md`](SETUP-GUIDE.md)
- **PowerShell API reference**: [`powershell_api_reference.md`](powershell_api_reference.md)
- **OneView authentication**: [`oneview-auth.md`](oneview-auth.md)
- **SCOM authentication**: [`scom-auth.md`](scom-auth.md)
- **OneView module versions**: [`oneview-module-versions.md`](oneview-module-versions.md)
- **Audit process**: [`audit_process.md`](audit_process.md)

---

*Document updated: 2026-06-19*
*Source file total: 3,803 lines*
*For questions about specific code locations, refer to the line numbers provided in the links above.*
