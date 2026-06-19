# Maintenance Mode (mm) Command — Complete Code Map

## TOC

- [Maintenance Mode (mm) Command — Complete Code Map](markdown-header-maintenance-mode-mm-command-complete-code-map)
  - [TOC](markdown-header-toc)
  - [1. Signon & Connect](markdown-header-1-signon-connect)
    - [1.1 — Parameter Binding & Input Validation](markdown-header-11-parameter-binding-input-validation)
    - [1.2 — SCOM Connect (by -TargetId)](markdown-header-12-scom-connect-by-targetid)
    - [1.3 — OneView Connect (by -TargetId cluster scope)](markdown-header-13-oneview-connect-by-targetid-cluster-scope)
    - [1.4 — OneView Connect (by -SerialNumber)](markdown-header-14-oneview-connect-by-serialnumber)
  - [2. Target Resolution (Shared)](markdown-header-2-target-resolution-shared)
  - [3. Connection Validation](markdown-header-3-connection-validation)
    - [SCOM Connection Test](markdown-header-scom-connection-test)
    - [OneView Connection Test](markdown-header-oneview-connection-test)
  - [4. Enable Maintenance Mode](markdown-header-4-enable-maintenance-mode)
    - [4.1 — Pre-Check: Already Enabled?](markdown-header-41-pre-check-already-enabled)
    - [4.2 — Start/End Time Resolution](markdown-header-42-startend-time-resolution)
    - [4.3 — SCOM: Enter Maintenance](markdown-header-43-scom-enter-maintenance)
    - [4.4 — OneView: Set Maintenance](markdown-header-44-oneview-set-maintenance)
  - [5. Enable — Post-Operation Actions](markdown-header-5-enable-post-operation-actions)
    - [5.1 — SCOM: Schedule Auto-Disable Task](markdown-header-51-scom-schedule-auto-disable-task)
    - [5.2 — Email Notification (Enable)](markdown-header-52-email-notification-enable)
    - [5.3 — OpsRamp Metrics & Alerts (Enable)](markdown-header-53-opsramp-metrics-alerts-enable)
  - [6. Disable Maintenance Mode](markdown-header-6-disable-maintenance-mode)
    - [6.1 — Pre-Check: Already Disabled?](markdown-header-61-pre-check-already-disabled)
    - [6.2 — SCOM: Exit Maintenance](markdown-header-62-scom-exit-maintenance)
    - [6.3 — SCOM: Post-Disable Stabilization Wait](markdown-header-63-scom-post-disable-stabilization-wait)
    - [6.4 — OneView: Disable Maintenance](markdown-header-64-oneview-disable-maintenance)
    - [6.5 — Email Notification (Disable)](markdown-header-65-email-notification-disable)
    - [6.6 — OpsRamp Metrics & Alerts (Disable)](markdown-header-66-opsramp-metrics-alerts-disable)
  - [7. Validate Action (Read-Only)](markdown-header-7-validate-action-read-only)
    - [DryRun Validation](markdown-header-dryrun-validation)
    - [SCOM Validation](markdown-header-scom-validation)
    - [OneView Validation](markdown-header-oneview-validation)
    - [Status Computation](markdown-header-status-computation)
    - [Result Assembly](markdown-header-result-assembly)
  - [8. Audit Record & Output](markdown-header-8-audit-record-output)
    - [8.1 — Audit Initialization](markdown-header-81-audit-initialization)
    - [8.2 — Audit Finalization & Save](markdown-header-82-audit-finalization-save)
    - [8.3 — Response Construction](markdown-header-83-response-construction)
    - [8.4 — CLI Output (Script-Mode Only)](markdown-header-84-cli-output-script-mode-only)
  - [9. Helper Functions (Shared)](markdown-header-9-helper-functions-shared)
  - [10. Class Reference](markdown-header-10-class-reference)
    - [SCOMManager](markdown-header-scommanager)
    - [OneViewClient](markdown-header-oneviewclient)
    - [EmailNotifier](markdown-header-emailnotifier)
  - [11. Configuration Files](markdown-header-11-configuration-files)
  - [12. Module Loading](markdown-header-12-module-loading)
  - [13. Testing](markdown-header-13-testing)
    - [Pester Test Files](markdown-header-pester-test-files)
    - [Test Scripts](markdown-header-test-scripts)
  - [14. Quick Navigation](markdown-header-14-quick-navigation)
  - [15. Documentation References](markdown-header-15-documentation-references)


This document maps every code location executed by the `Set-MaintenanceMode` command, organized in the **chronological order that code actually runs** — from initial signon through connection, enable, disable, notification, and audit.

> **Source file**: [`Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1) — 3,803 lines total.

---

## 1. Signon & Connect

This phase covers everything from the moment the command is invoked until a verified connection is established with the target management system. **Precision at this stage is critical for production environments and change freezes.**

> **IMPORTANT**: During a change freeze, the `Set-MaintenanceMode` command must target **only** the specific server, cluster, or serial number that has been approved. An incorrect `-TargetId` or `-SerialNumber` value will either:
> - Place the **wrong infrastructure object** into maintenance mode (suppressing alerting for unintended targets), or
> - Return an error and fail to protect the approved change window.
>
> Always verify the target identifier against `clusters_catalogue.json` (for cluster-level operations) or `servers_catalogue.oneview.json` (for serial-number lookups) **before** execution.

### 1.1 — Parameter Binding & Input Validation

The command accepts two mutually-exclusive targeting parameters depending on the integration mode:

| Parameter | Mode | Purpose | Code Location |
|-----------|------|---------|---------------|
| `-TargetId` | SCOM | Cluster ID (`CLU-CLUSTER-01`) or direct server hostname | [Line 309](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L309) |
| `-SerialNumber` | OneView | Hardware serial number (e.g. `MXQ1234567`) | [Line 313](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L313) |
| `-Mode` | Both | `scom` or `oneview` — selects the integration path | [Line 310](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L310) |

**Full `param()` block**: [`Lines 306–321`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L306-L321)

**Validation logic**: [`Lines 326–341`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L326-L341)
- [Lines 326–331](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L326-L331): Normalize `-Mode` (lowercase) and reject if empty
- [Lines 333–341](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L333-L341): Validate `-TargetId` — required for SCOM mode; for OneView mode, `-SerialNumber` alone is accepted (line 335)

### 1.2 — SCOM Connect (by `-TargetId`)

Used for SCOM-managed Windows clusters and servers. The target is a cluster ID from `clusters_catalogue.json`.

```powershell
# --- SCOM: Connect and enable maintenance for a cluster by TargetId ---
Set-MaintenanceMode -Action enable `
    -TargetId 'CLU-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+4hours'
```

**What executes (in order):**

1. **Config loading**: [`Lines 365–372`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L365-L372) — Loads `clusters_catalogue.json`, `scom_config.json`, `clusters_catalogue.scom.json`
2. **Hostname lookup**: [`Lines 374–389`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L374-L389) — Builds `$scomHostnameLookup` from `clusters_catalogue.scom.json`
3. **Target resolution**: [`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655) — Resolves `CLU-CLUSTER-01` → cluster definition + server list:
   - `scom_group` = `"SCOM_Prod_Cluster_01"`
   - `servers` = `["prod-server-01.example.com", "prod-server-02.example.com", "prod-server-03.example.com"]`
4. **Environment host resolution**: [`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699) — Selects SCOM management server from `connection_hosts.json` based on `-Environment Prod`
5. **Credential resolution**: [`Lines 986–1050`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L986-L1050):
   - [Lines 992–995](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L992-L995): SCOM username from `$env:SCOM_ADMIN_USER`
   - [Lines 1002–1003](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1002-L1003): SCOM password from `$env:SCOM_ADMIN_PASSWORD`
   - [Lines 1010–1033](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1010-L1033): Interactive prompt fallback if env vars not set
6. **SCOMManager instantiation**: [`Lines 1097–1108`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1097-L1108) — `[SCOMManager]::new($scomCfgCopy)` with credential injection
7. **Connection test**: [`Lines 1166–1177`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1166-L1177) — Calls [`Test-ScomConnection`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846):
   - [`Lines 1846–1868`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846-L1868): Imports `OperationsManager` module, creates `New-SCOMManagementGroupConnection`, verifies `"CONNECTED"`
   - If the connection fails → returns `Success = $false` with an error message (lines 1170–1174)

### 1.3 — OneView Connect (by `-TargetId` cluster scope)

Used for OneView-managed server scopes (clusters). The target is a scope name or server name from `clusters_catalogue.json`.

```powershell
# --- OneView: Connect and enable maintenance for a cluster scope by TargetId ---
Set-MaintenanceMode -Action enable `
    -TargetId 'CLU-CLUSTER-01' `
    -Mode oneview `
    -Environment Prod `
    -Start 'now' `
    -End '+4hours'
```

**What executes (in order):**

1. **Config loading**: [`Lines 365–372`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L365-L372) — Loads `clusters_catalogue.json`, `oneview_config.json`, `servers_catalogue.oneview.json`
2. **Server catalogue lookup**: [`Lines 391–420`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L391-L420) — Builds `$serialLookup` and `$nameLookup` tables from `servers_catalogue.oneview.json`
3. **Target resolution**: [`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655) — Resolves `CLU-CLUSTER-01` → cluster definition with `oneview_scope`
4. **Environment host resolution**: [`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699) — Selects OneView appliance from `connection_hosts.json`
5. **Credential resolution**: [`Lines 986–1050`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L986-L1050):
   - [Lines 996–997](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L996-L997): OneView user from `$env:ONEVIEW_USER`
   - [Lines 1004–1005](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1004-L1005): OneView password from `$env:ONEVIEW_PASSWORD`
6. **OneViewClient instantiation**: [`Lines 1111–1151`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1111-L1151) — Includes:
   - [Line 2790](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2790): Module auto-detection via [`_DetectRecommendedModule`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2822)
   - [Line 2794](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2794): Module compatibility validation via [`_ValidateModuleCompat`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2842)
   - [Lines 1126–1146](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1126-L1146): Target resolution via [`OneViewClient.ResolveTarget()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112) (server vs. scope)
7. **Connection test**: [`Lines 1179–1198`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1179-L1198) — Calls [`Test-OneViewConnection`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870):
   - [`Lines 1870–1894`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870-L1894): Imports `HPEOneView.xxx` module, connects via `Connect-OVMgmt`, verifies `"CONNECTED"`
   - If the connection fails → returns error with `-TargetId` and `-SerialNumber` context (lines 1190–1195)

### 1.4 — OneView Connect (by `-SerialNumber`)

OneView supports direct hardware serial number targeting — **only the single server with that serial number is placed into maintenance mode**. This is the safest mode for change freezes because it cannot accidentally affect other servers in a scope.

```powershell
# --- OneView: Connect and enable maintenance for a SINGLE server by serial number ---
#    No -TargetId needed — only this specific physical server is affected
Set-MaintenanceMode -Action enable `
    -Mode oneview `
    -SerialNumber 'MXQ1234567' `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours'
```

**What executes differently from cluster targeting:**

1. **TargetId bypass**: [`Lines 333–341`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L333-L341) — Validation allows empty `TargetId` when `-SerialNumber` is provided with OneView mode (line 335)
2. **Local serial lookup**: [`Lines 415–420`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L415-L420) — `_Resolve-ServerNameFromSerial` maps serial → OneView server name via `servers_catalogue.oneview.json`
3. **Remote serial resolution**: [`Lines 1127–1133`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1127-L1133) — Calls [`OneViewClient.ResolveServerBySerial()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282):
   - [`Lines 3326–3363`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3326-L3363): REST API serial lookup via `GET /rest/server-hardware?filter=serialNumber='...'` (API v200+)
   - [`Lines 3365–3393`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3365-L3393): Cmdlet fallback via `Get-OVServer -SerialNumber` or full server enumeration
4. **Result**: Only the resolved single server is set into maintenance mode (target type = `ServerHardware`), no scope is affected

> **Change freeze safeguard**: The serial-number lookup verifies the server exists in the OneView appliance **before** any enable/disable call. If the serial number does not match any server, the command fails immediately with an error at [line 1130](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1130).

---

## 2. Target Resolution (Shared)

After signon, the command identifies exactly which infrastructure objects will be affected. This determines the scope of maintenance mode operations.

**Primary resolution logic**: [`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655)

| Scenario | SCOM Behavior | OneView Behavior |
|----------|---------------|------------------|
| `-TargetId` = cluster ID | Resolves `scom_group` + server list from catalogue | Resolves `oneview_scope` → iterates scope members |
| `-TargetId` = server hostname | Direct server mode — single SCOM group object | `Get-OVServer` → `ServerHardware` target |
| `-SerialNumber` = hardware serial | N/A (rejected) | `ResolveServerBySerial()` → `ServerHardware` target |

**Environment host resolution**: [`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699)
- [`Lines 666–672`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L666-L672): Environment priority — parameter > `$env:ENVIRONMENT` > `'Prod'`
- [`Lines 677–692`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L677-L692): Host resolution from `connection_hosts.json` → SCOM management server or OneView appliance
- [`Lines 680–692`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L680-L692): Override via `-ManagementHost` or `$env:MAINTENANCE_HOST`

---

## 3. Connection Validation

**Pre-flight check before any state-changing operation**: [`Lines 1164–1199`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1164-L1199)

This step is skipped in DryRun mode — no credentials are needed when simulating.

### SCOM Connection Test
- **Call site**: [`Lines 1166–1177`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1166-L1177)
- **Implementation**: [`Test-ScomConnection` — Lines 1846–1868](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846-L1868)
- **Actions**: Imports `OperationsManager` module → `New-SCOMManagementGroupConnection` → verifies `"CONNECTED"` in output
- **On failure**: Returns `Success = $false` immediately (lines 1170–1174)

### OneView Connection Test
- **Call site**: [`Lines 1179–1198`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1179-L1198)
- **Implementation**: [`Test-OneViewConnection` — Lines 1870–1894](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870-L1894)
- **Actions**: Imports `HPEOneView.xxx` module → `Connect-OVMgmt` → verifies `"CONNECTED"` in output
- **On failure**: Returns error with full target context (lines 1190–1195)

---

## 4. Enable Maintenance Mode

### 4.1 — Pre-Check: Already Enabled?

Before issuing enable commands, the function checks whether the target is **already** in maintenance mode. If enabled, the operation is aborted to avoid duplicate entries.

- **Call site**: [`Lines 1242–1284`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1242-L1284)
  - [Lines 1244–1249](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1244-L1249): SCOM pre-check via [`SCOMManager.GetMaintenanceStatus()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578)
  - [Lines 1250–1264](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1250-L1264): OneView pre-check via [`OneViewClient.GetMaintenanceStatus()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178)
- **On duplicate**: Returns error `"Server is already in maintenance mode."` (lines 1267–1284)

### 4.2 — Start/End Time Resolution

- **[`Lines 1055–1090`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1055-L1090)**: Applies catalogue-based default end time and schedule adjustments
- **[`Lines 1896–1954`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896-L1954)**: `_Parse-Datetime` — parses `now`, `+Xhours`, `+Xminutes`, `+Xdays`, `YYYY-MM-DD HH:MM`

### 4.3 — SCOM: Enter Maintenance

- **Call site**: [`Lines 1289–1361`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1289-L1361)
- **Implementation entry**: [`SCOMManager.EnterMaintenance()` — Line 1343 → Line 2132](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132)

**Execution within `EnterMaintenance`** ([`Lines 2132–2262`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132-L2262)):

```
EnterMaintenance($scom_group, $duration, $comment, $DryRun, $servers, $useClusterMode)
    │
    ├─ DryRun? → Return mock per-object status (lines 2137–2174)
    │
    ├─ _DetectVersion() (line 2176)
    │   └─ Lines 2075–2114: Run Get-SCOMManagementServer + REST /authenticate probe
    │
    ├─ SCOM 2019 UR1+ / 2025 (REST API path):
    │   └─ _EnterMaintenanceRest() (line 2448)
    │       ├─ Authenticate via POST /authenticate (lines 2476–2483)
    │       ├─ Resolve monitoring object IDs (lines 2486–2506)
    │       └─ POST /ScheduleMaintenance with OneTimeSchedule (lines 2508–2533)
    │
    └─ SCOM 2012/2016/2019-classic (PowerShell cmdlet path):
        ├─ Generate script via New-ScomMaintenanceScript (line 2188)
        ├─ Execute via _RunPs() → Invoke-PowerShellScript or WinRM (lines 2063–2073)
        └─ Parse OBJECT_STATUS: and SUMMARY: JSON lines from output (lines 2197–2251)
```

**Per-object result structure** ([`Lines 2197–2251`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2197-L2251)):
```json
{ "name": "prod-server-01.example.com", "type": "WindowsComputer",
  "action": "enable", "status": "success|already_in_maintenance|failed",
  "message": "...", "nack_reason": "...", "resolution": "..." }
```

### 4.4 — OneView: Set Maintenance

- **Call site**: [`Lines 1363–1443`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1363-L1443)
- **Implementation entry**: [`OneViewClient.SetMaintenance()` — Line 1432 → Line 2864](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864)

**Execution within `SetMaintenance`** ([`Lines 2864–2982`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864-L2982)):

```
SetMaintenance($targetName, $targetType, $startDt, $endDt, $DryRun)
    │
    ├─ $this.UseWinRM?
    │   └─ _SetViaWinRM() (line 2984) → delegates to _SetViaModule()
    │
    └─ _SetViaModule() (line 2871):
        ├─ Import-Module HPEOneView.xxx
        ├─ Connect-OVMgmt with credentials
        │
        ├─ TargetType = 'ServerHardware':
        │   ├─ Get-OVServer -Name $target (line 2887)
        │   ├─ If MaintenanceModeEnabled → 'already_in_maintenance'
        │   └─ Else → Enable-OVMaintenanceMode -InputObject $server (line 2900)
        │
        └─ TargetType = 'Scope':
            ├─ Get-OVScope -Name $target → iterate scope members (line 2914)
            ├─ For each member: Get-OVServer → Enable-OVMaintenanceMode
            └─ Accumulate per-server success/failure counts
```

**OneView serial-number targeting** — When `-SerialNumber` was used in Section 1.4, `$targetType` is `ServerHardware`, so **only a single `Enable-OVMaintenanceMode` call** is issued for the resolved server.

---

## 5. Enable — Post-Operation Actions

### 5.1 — SCOM: Schedule Auto-Disable Task

After SCOM maintenance is enabled, a Windows Scheduled Task is created to automatically run the `disable` action at the scheduled end time.

- **[`Lines 1480–1493`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1480-L1493)**: Creates `schtasks /Create` entry
  - Task name: `MaintenanceDisable-$TargetId`
  - Command: `pwsh.exe Set-MaintenanceMode.ps1 -Action disable -TargetId $TargetId -NoSchedule`
  - Scheduled for `$endDt` (the maintenance window end)

### 5.2 — Email Notification (Enable)

- **Call site**: [`Line 1446`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1446)
- **Implementation**: [`EmailNotifier.SendMaintenanceNotification()` — Lines 3473–3566](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473-L3566)

**Execution flow**:
1. [`Lines 3462–3471`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3462-L3471): `_GetRecipients('enabled')` — resolves from `email_distribution_lists.json` key `maintenance_enabled` or flat distribution list file
2. [`Lines 3500–3528`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3500-L3528): Template variable substitution (`{cluster_name}`, `{environment}`, `{servers}`, etc.)
3. [`Lines 3538–3565`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3538-L3565): `System.Net.Mail.SmtpClient` send to all recipients

### 5.3 — OpsRamp Metrics & Alerts (Enable)

- **[`Lines 1452–1478`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1452-L1478)**:
  - [Line 1466](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1466): `SendMetric($server, 'maintenance.mode', 1, ...)` for each server
  - [Line 1468](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1468): `SendAlert($TargetId, 'maintenance.enabled', 'INFO', ...)`
  - [Line 1473](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1473): `SendEvent($TargetId, 'maintenance.enabled', ...)`

---

## 6. Disable Maintenance Mode

### 6.1 — Pre-Check: Already Disabled?

- **Call site**: [`Lines 1496–1538`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1496-L1538)
  - [Lines 1498–1503](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1498-L1503): SCOM pre-check via `GetMaintenanceStatus()` — if no objects are in maintenance, aborts
  - [Lines 1504–1518](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1504-L1518): OneView pre-check via `GetMaintenanceStatus()`
- **On duplicate**: Returns error `"Server is already out of maintenance mode."` (lines 1521–1538)

### 6.2 — SCOM: Exit Maintenance

- **Call site**: [`Lines 1540–1573`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1540-L1573)
- **Implementation**: [`SCOMManager.ExitMaintenance()` — Line 1546 → Line 2264](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264)

**Execution within `ExitMaintenance`** ([`Lines 2264–2442`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264-L2442)):

```
ExitMaintenance($scom_group, $DryRun, $servers, $useClusterMode)
    │
    ├─ DryRun? → Return mock per-object status (lines 2268–2304)
    │
    ├─ _DetectVersion() (line 2306)
    │
    ├─ SCOM 2019 UR1+ / 2025 (REST API path):
    │   └─ _ExitMaintenanceRest() (line 2538)
    │       └─ Generates PowerShell cmdlet script for exit
    │          (REST API lacks direct maintenance-stop endpoint)
    │
    └─ SCOM 2012/2016/2019-classic (PowerShell cmdlet path):
        ├─ Generate script via New-ScomMaintenanceScript (line 2372)
        ├─ Execute via _RunPs()
        └─ Parse OBJECT_STATUS: and SUMMARY: JSON lines (lines 2381–2438)
```

### 6.3 — SCOM: Post-Disable Stabilization Wait

After disabling SCOM maintenance, a **stabilization sleep** prevents false alerts while servers reboot and restart services.

- **[`Lines 1557–1572`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1557-L1572)**:
  - `Start-Sleep -Seconds $PostDisableWaitSeconds` (default 120 seconds)
  - Controlled by `-PostDisableWaitSeconds` parameter ([line 315](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L315))
  - Skip if DryRun or `PostDisableWaitSeconds = 0`

### 6.4 — OneView: Disable Maintenance

- **Call site**: [`Lines 1575–1596`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1575-L1596)
- **Implementation**: [`OneViewClient.DisableMaintenance()` — Line 1588 → Line 2988](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988)

**Execution within `_DisableViaModule`** ([`Lines 2995–3107`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2995-L3107)):

```
DisableMaintenance($targetName, $targetType, $DryRun)
    │
    ├─ $this.UseWinRM? → _DisableViaWinRM() (line 3108) → delegates
    │
    └─ _DisableViaModule() (line 2995):
        ├─ Import-Module HPEOneView.xxx → Connect-OVMgmt
        │
        ├─ TargetType = 'ServerHardware':
        │   ├─ Get-OVServer -Name $target
        │   ├─ If NOT in maintenance → 'not_in_maintenance'
        │   └─ Else → Disable-OVMaintenanceMode -InputObject $server (line 3024)
        │
        └─ TargetType = 'Scope':
            ├─ Get-OVSCOPE → iterate scope members
            ├─ For each member: Get-OVServer → Disable-OVMaintenanceMode
            └─ Accumulate per-server success/failure counts
```

### 6.5 — Email Notification (Disable)

- **Call site**: [`Line 1600`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1600)
- Uses same [`EmailNotifier.SendMaintenanceNotification()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473) with action `'disabled'`

### 6.6 — OpsRamp Metrics & Alerts (Disable)

- **[`Lines 1607–1639`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1607-L1639)**:
  - [Line 1620](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1620): `SendMetric($server, 'maintenance.mode', 0, ...)` for each server
  - [Line 1622](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1622): `SendAlert($TargetId, 'maintenance.disabled', 'INFO', ...)`
  - [Line 1627](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1627): `SendEvent($TargetId, 'maintenance.disabled', ...)`

---

## 7. Validate Action (Read-Only)

The validate action queries current maintenance status **without making any changes**. It runs after signon, connection, and target resolution but before any enable/disable logic.

- **Entry point**: [`Line 702`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L702)
- **Full implementation**: [`Lines 702–983`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L702-L983)

### DryRun Validation

- **[`Lines 716–810`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L716-L810)**: Returns mock status data without connecting to any management system

### SCOM Validation

- **[`Lines 812–847`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L812-L847)**:
  - [Line 824](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L824): Calls `SCOMManager.GetMaintenanceStatus()` → [`Line 2578`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578)
  - [Line 2582](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2582): Routes to REST API if SCOM 2019+ with REST ready
  - [`Lines 2587–2657`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2587-L2657): PowerShell cmdlet path for older versions

### OneView Validation

- **[`Lines 848–897`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L848-L897)**:
  - [Line 861](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L861): Serial-number resolve via `ResolveServerBySerial()` if applicable
  - [Line 884](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L884): Calls `OneViewClient.GetMaintenanceStatus()` → [`Line 3178`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178)

### Status Computation

- **[`_Compute-OverallStatus()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1989)** (line 1989): `fully_in_maintenance` | `partially_in_maintenance` | `not_in_maintenance`
- **[`_Format-StatusState()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1995)** (line 1995): Maps to `enabled` | `partially enabled` | `disabled`
- **[`_Format-StatusMessage()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2003)** (line 2003): Builds detail message string

### Result Assembly

- **[`Lines 899–983`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L899-L983)**: Constructs read-only result with status, per-object details, and mode-specific summaries

---

## 8. Audit Record & Output

### 8.1 — Audit Initialization

- **[`Lines 1222–1239`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1222-L1239)**: Creates `$audit` hashtable with action, mode, environment, target_id, serial_number, timestamps, steps, success flag

### 8.2 — Audit Finalization & Save

- **[`Lines 1641–1712`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1641-L1712)**: Finalizes audit record with success status, timestamps, message
- **[`_Save-AuditRecord()`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012)** ([`Lines 2012–2028`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012-L2028)):
  - Writes JSON audit record to `generated/logs/audit/`
  - Appends to master log file `maintenance_audit_*.log`
  - Includes GitLab context enrichment if available (line 2019)

### 8.3 — Response Construction

- **[`Lines 1720–1800`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1720-L1800)**: Builds response hashtable
  - [`Lines 1734–1769`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1734-L1769): Core fields — Success, Message, Action, Mode, StartTimeUtc, EndTimeUtc, TargetId, SerialNumber, ServerCount, DryRun, AuditFile, FailedObjects
  - [`Lines 1772–1790`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1772-L1790): Mode-specific fields — ScomObjects/ScomSummary or OneViewObjects/OneViewSummary

### 8.4 — CLI Output (Script-Mode Only)

- **[`Lines 3569–3803`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3569-L3803)**:
  - [`Lines 3634–3640`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3634-L3640): JSON output mode (`-Json` flag)
  - [`Lines 3643–3794`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3643-L3794): Human-readable output with per-object status tables, NACK summary, and final result

---

## 9. Helper Functions (Shared)

Functions called at various points throughout the execution flow:

| Function | Line | Purpose | Called During |
|----------|------|---------|---------------|
| [`_Parse-Datetime`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896) | L1896 | Parses `now`, `+Xhours`, `YYYY-MM-DD HH:MM` to UTC DateTime | Enable action, time resolution |
| [`_Compute-DefaultEnd`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1956) | L1956 | Default end = 7am UTC next Monday | Enable action |
| [`_Compute-NextWorkStart`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1971) | L1971 | Next work-start from schedule config | Enable action |
| [`_Compute-OverallStatus`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1989) | L1989 | `fully_in_maintenance` / `partially` / `not_in_maintenance` | Validate action |
| [`_Format-StatusState`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1995) | L1995 | Maps status → human-readable state | Validate action |
| [`_Format-StatusMessage`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2003) | L2003 | Builds detail status message string | Validate action |
| [`_Save-AuditRecord`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012) | L2012 | Writes JSON audit + appends to master log | All actions |
| [`_Resolve-ServerNameFromSerial`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L415) | L415 | Serial → OneView server name from local catalogue | OneView serial targeting |
| [`Initialize-Logging`](../src/powershell/Automation/Private/Logging.ps1) | — | Sets up log directories and formats | Module load |

---

## 10. Class Reference

### SCOMManager

**Location**: [`Lines 2031–2775`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2031-L2775)

| Member | Line | Description |
|--------|------|-------------|
| Properties | [2032–2038](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2032-L2038) | Config, MgmtServer, ModuleName, UseWinRM, Cred, ScomVersion, RestApiReady |
| Constructor | [2040–2061](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2040-L2061) | Init + credential load from env vars |
| `_RunPs` | [2063–2073](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2063-L2073) | Execute PS locally or via WinRM |
| `_DetectVersion` | [2075–2114](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2075-L2114) | Auto-detect SCOM version + REST readiness |
| `GetGroupMembers` | [2116–2130](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2116-L2130) | Enumerate SCOM group instances |
| `EnterMaintenance` | [2132–2262](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132-L2262) | Enable (REST or cmdlet path) |
| `ExitMaintenance` | [2264–2442](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264-L2442) | Disable (REST or cmdlet path) |
| `_EnterMaintenanceRest` | [2448–2536](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2448-L2536) | REST POST /ScheduleMaintenance |
| `_ExitMaintenanceRest` | [2538–2576](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2538-L2576) | REST exit (PS cmdlet fallback) |
| `GetMaintenanceStatus` | [2578–2658](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578-L2658) | Query status (REST or cmdlet) |
| `_GetMaintenanceStatusRest` | [2660–2775](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2660-L2775) | REST status query |

### OneViewClient

**Location**: [`Lines 2777–3431`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2777-L3431)

| Member | Line | Description |
|--------|------|-------------|
| Properties | [2778–2784](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2778-L2784) | Config, Appliance, ModuleName, UseWinRM, WinRMServer, Username, Password |
| Constructor | [2786–2807](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2786-L2807) | Init + module detection + credential load |
| `OneViewModuleApplianceMap` | [2809–2820](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2809-L2820) | Static module → firmware → PS version map |
| `_DetectRecommendedModule` | [2822–2840](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2822-L2840) | Auto-detect installed HPEOneView module |
| `_ValidateModuleCompat` | [2842–2862](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2842-L2862) | PS version compatibility check |
| `SetMaintenance` | [2864–2869](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864-L2869) | Enable (dispatch) |
| `_SetViaModule` | [2871–2982](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2871-L2982) | Enable via `Enable-OVMaintenanceMode` |
| `_SetViaWinRM` | [2984–2986](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2984-L2986) | WinRM delegate |
| `DisableMaintenance` | [2988–2993](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988-L2993) | Disable (dispatch) |
| `_DisableViaModule` | [2995–3107](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2995-L3107) | Disable via `Disable-OVMaintenanceMode` |
| `_DisableViaWinRM` | [3108–3110](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3108-L3110) | WinRM delegate |
| `ResolveTarget` | [3112–3176](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112-L3176) | Server/scope name → OneView target |
| `GetMaintenanceStatus` | [3178–3183](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178-L3183) | Query status (dispatch) |
| `_GetMaintenanceStatusViaModule` | [3185–3276](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3185-L3276) | Module-based status check |
| `_GetMaintenanceStatusViaWinRM` | [3278–3280](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3278-L3280) | WinRM delegate |
| `ResolveServerBySerial` | [3282–3430](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282-L3430) | Serial → server (REST primary + cmdlet fallback) |

### EmailNotifier

**Location**: [`Lines 3434–3567`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3434-L3567)

| Member | Line | Description |
|--------|------|-------------|
| Properties | [3435–3444](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3435-L3444) | Config, SmtpServer, SmtpPort, UseTls, UseSsl, FromAddr, Templates, DistLists |
| Constructor | [3446–3460](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3446-L3460) | Load SMTP config, templates, distribution lists |
| `_GetRecipients` | [3462–3471](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3462-L3471) | Resolve recipients by action key |
| `SendMaintenanceNotification` | [3473–3566](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473-L3566) | Template-based SMTP email send |

---

## 11. Configuration Files

All configurations loaded from `configs/` directory, in load order:

| File | Load Line | Purpose |
|------|-----------|---------|
| **`clusters_catalogue.json`** | [366](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L366) | Cluster definitions with servers, SCOM groups, OneView scopes |
| **`scom_config.json`** | [367](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L367) | SCOM management server settings, PowerShell module, maintenance defaults |
| **`oneview_config.json`** | [368](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L368) | OneView appliance config, module detection, credentials |
| **`email_distribution_lists.json`** | [369](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L369) | Email recipients per action (`maintenance_enabled` / `maintenance_disabled`) |
| **`opsramp_config.json`** | [370](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L370) | OpsRamp integration for metrics and alerting |
| **`servers_catalogue.oneview.json`** | [371](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L371) | Serial number / display name / OneView name mapping |
| **`clusters_catalogue.scom.json`** | [372](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L372) | SCOM hostname → cluster key mapping |
| **`connection_hosts.json`** | [659](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L659) | Environment-based host resolution (Test/Prod) |
| **`request_types.json`** | — | Routes maintenance requests from the Router |

---

## 12. Module Loading

- **Root module**: [`Automation.psm1`](../src/powershell/Automation/Automation.psm1) (509 lines)
  - **[Lines 397–421](../src/powershell/Automation/Automation.psm1#L397-L421):** Private script loading (dependency order): `Audit.ps1` → `Config.ps1` → `Credentials.ps1` → `Executor.ps1` → `FileIO.ps1` → `PathResolver.ps1` → `Inventory.ps1` → `Logging.ps1` → `Router.ps1` → `Base.ps1`
  - **[Lines 424–429](../src/powershell/Automation/Automation.psm1#L424-L429):** Public script loading (alphabetical)
  - **[Lines 433–505](../src/powershell/Automation/Automation.psm1#L433-L505):** `Export-ModuleMember` — [`Set-MaintenanceMode` at line 449](../src/powershell/Automation/Automation.psm1#L449)
- **Request Router**: [`Invoke-RoutedRequest`](../src/powershell/Automation/Private/Router.ps1#L20) — Routes from `request_types.json`
- **PowerShell Profile**: [`Setup-Profile.ps1`](../scripts/Setup-Profile.ps1) — Adds module import

---

## 13. Testing

### Pester Test Files

| Test File | Coverage |
|-----------|----------|
| [`Set-MaintenanceMode.Unit.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Unit.Tests.ps1) | Core function unit tests |
| [`Set-MaintenanceMode.Enable.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Enable.Tests.ps1) | Enable action tests |
| [`Set-MaintenanceMode.Disable.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Disable.Tests.ps1) | Disable action tests |
| [`Set-MaintenanceMode.Validation.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Validation.Tests.ps1) | Validate action tests |
| [`Set-MaintenanceMode.Environment.Tests.ps1`](../tests/powershell/Set-MaintenanceMode.Environment.Tests.ps1) | Environment resolution tests |

### Test Scripts

| Script | Purpose |
|--------|---------|
| [`test-maintenance-connection.ps1`](../scripts/test-maintenance-connection.ps1) | Connection testing |
| [`validate-maintenance-config.ps1`](../scripts/validate-maintenance-config.ps1) | Configuration validation |
| [`run-maintenance-tests.ps1`](../scripts/run-maintenance-tests.ps1) | Full maintenance test suite |
| [`run-maint-mode-tests.ps1`](../scripts/run-maint-mode-tests.ps1) | Alternative maintenance mode test runner |

---

## 14. Quick Navigation

| Functionality | SCOM Code | OneView Code |
|---------------|-----------|--------------|
| **Parameter binding** | [`-TargetId` L309](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L309) | [`-SerialNumber` L313](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L313) |
| **Target validation** | [`Lines 333–341`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L333-L341) | [`Lines 333–341`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L333-L341) |
| **Config loading** | [`Lines 365–389`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L365-L389) | [`Lines 365–420`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L365-L420) |
| **Target resolution** | [`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655) | [`Lines 422–655`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L422-L655) |
| **Environment host** | [`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699) | [`Lines 657–699`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L657-L699) |
| **Credential resolution** | [`Lines 986–1050`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L986-L1050) | [`Lines 986–1050`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L986-L1050) |
| **Manager instantiation** | [`Lines 1097–1108`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1097-L1108) | [`Lines 1111–1151`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1111-L1151) |
| **Connection test** | [`Test-ScomConnection` L1846](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1846) | [`Test-OneViewConnection` L1870](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1870) |
| **Serial lookup** | N/A | [`ResolveServerBySerial` L3282](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3282) |
| **Target resolution** | N/A (SCOM groups) | [`ResolveTarget` L3112](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3112) |
| **Enable** | [`EnterMaintenance` L2132](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2132) | [`SetMaintenance` L2864](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2864) |
| **Disable** | [`ExitMaintenance` L2264](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2264) | [`DisableMaintenance` L2988](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2988) |
| **Validate status** | [`GetMaintenanceStatus` L2578](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2578) | [`GetMaintenanceStatus` L3178](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3178) |
| **REST enable** | [`_EnterMaintenanceRest` L2448](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2448) | N/A |
| **REST disable** | [`_ExitMaintenanceRest` L2538](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2538) | N/A |
| **Email notify** | [`SendMaintenanceNotification` L3473](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473) | [`SendMaintenanceNotification` L3473](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L3473) |
| **Audit save** | [`_Save-AuditRecord` L2012](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012) | [`_Save-AuditRecord` L2012](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L2012) |
| **Datetime parsing** | [`_Parse-Datetime` L1896](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896) | [`_Parse-Datetime` L1896](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1#L1896) |

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
