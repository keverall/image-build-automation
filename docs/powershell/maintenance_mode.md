# Maintenance Mode Orchestration — PowerShell

> **Language-agnostic documentation** (architecture overview, scheduling
> semantics, audit log format, OpsRamp integration, required environment
> variables, security, and troubleshooting) is in
> [`../maintenance_mode.md`](../maintenance_mode.md).
> This page documents PowerShell-specific parameters, CmdletBinding, module
> dependencies, and `pwsh.exe` integration.

---

## Script Location

`powershell/Automation/Public/Set-MaintenanceMode.ps1`

---

## Shared Utilities (PowerShell)

`Set-MaintenanceMode.ps1` uses the private helpers in `powershell/Automation/Private/`:

- **Config.ps1** — `Import-JsonConfig` with `${VAR}` environment substitution
- **Logging.ps1** — `Initialize-Logging` (file + console via `[TraceSource]`)
- **Audit.ps1** — `_Save-AuditRecord` writes timestamped JSON and appends to
  `logs/maintenance_audit.log`
- **Executor.ps1** — `Invoke-PowerShellScript`, `Invoke-PowerShellWinRM`,
  `Invoke-Command` wrappers
- **Credentials.ps1** — `Get-IloCredentials`, `Get-OpenViewCredentials`,
  `Get-CredentialSecret`
- **Base.ps1** — `AutomationBase` class (shared logic across cmdlets)
- **FileIO.ps1** — `Ensure-DirectoryExists`

---

## Module Import

```powershell
Import-Module .\powershell\Automation\Automation.psd1 -Force
```

All public cmdlets follow the same pattern: import the module manifest once, call
`Initialize-Logging` once, load JSON configs, then execute.

---

## Cmdlet Parameters

`Set-MaintenanceMode` accepts the following parameters (PowerShell `[CmdletBinding()]`):

| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-Action` | `[ValidateSet('enable','disable','validate')]` | yes | `enable` · `disable` · `validate` |
| `-ClusterId` | `[string]` | yes | Cluster ID matching a key in `clusters_catalogue.json` |
| `-Start` | `[string]` | no | Start time; `now` or `'YYYY-MM-DD HH:mm[:ss]'` (local OS time) |
| `-End` | `[string]` | no | End time; `'YYYY-MM-DD HH:mm[:ss]'`; omitted → next `work_start` from schedule |
| `-DryRun` | `[switch]` | no | Validation + audit + email only; no SCOM/iLO/OpenView mutations |
| `-NoSchedule` | `[switch]` | no | Skip Windows Scheduled Task creation on enable; skip task removal on disable |
| `-TimeZone` | `[string]` | no | Override cluster schedule timezone |
| `-Verbose` | `[switch]` | no | DEBUG-level log output |

---

## PowerShell Examples

### Enable — explicit timestamps

```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' `
    -Start '2026-05-16 22:00:00' -End '2026-05-17 06:00:00'
```

### Enable — start now, end from schedule

```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now
```

### Disable

```powershell
Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'
```

### Dry-run

```powershell
Set-MaintenanceMode -Action enable `
    -ClusterId 'PROD-CLUSTER-01' `
    -Start '2026-05-16 22:00' `
    -End   '2026-05-17 06:00' `
    -DryRun
```

### No-schedule (skip Windows Scheduled Task)

```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now -NoSchedule
```

### Orchestrator (iRequest-style call)

```powershell
$result = Start-AutomationOrchestrator -RequestType 'maintenance_enable' `
    -Params @{ cluster_id = 'PROD-CLUSTER-01'; start = 'now' }
```

For orchestrator internals (`$script:RouteMap`, return types per dispatcher
branch, `_Validate-Request` rules) see [`../api_reference.md`](../api_reference.md).

### Scheduled Automatic Disable

On `enable` (unless `-NoSchedule`) a one-time task
`MaintenanceDisable-<ClusterId>` is created via
`[System.Management.Automation.PScheduledJob]` / `schtasks.exe`:

```powershell
pwsh.exe -File Set-MaintenanceMode.ps1 -Action disable -ClusterId PROD-CLUSTER-01 -NoSchedule
```

The task runs as SYSTEM (override via `/RU <user>` / `/RP <password>`).

---

## Configuration Files (`configs/`)

| File | Purpose |
|------|---------|
| `clusters_catalogue.json` | Clusters, servers, SCOM groups, iLO IPs, OpenView node IDs, schedules |
| `scom_config.json` | Management server, module name, WinRM flag, credential env-var names |
| `openview_config.json` | API URL, version, endpoint, auth type, optional CLI path |
| `email_distribution_lists.json` | SMTP settings + distribution lists per event type |
| `opsramp_config.json` | Re-used OpsRamp integration config |
| `maintenance_distribution_list.txt` | Optional one-email-per-line override |

---

## Environment Variables

| Variable | Purpose |
|---|---|
| `SCOM_ADMIN_USER` / `SCOM_ADMIN_PASSWORD` | SCOM connection credentials |
| `ILO_USER` / `ILO_PASSWORD` | Global iLO credentials; per-server overrides via `ilo_credentials` in cluster definition |
| `OPENVIEW_USER` / `OPENVIEW_PASSWORD` | OpenView auth |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP creds (optional; often not required internally) |
| `OPSRAMP_*` | OpsRamp client (shared with other scripts) |

---

## Audit Format

Per run the cmdlet writes *and* appends (same as Python):

- `logs/<action>_<ClusterId>_<unix-ts>.json` — per-action record
- `logs/maintenance_audit.log` — line-delimited JSON (appended)

Record fields: `cluster`, `action`, `dry_run`, per-system results
(`scom`, `ilo`, `openview`, `email`, `opsramp`), `start`, `end`,
`scheduled_disable`, `success`, `errors`.

---

## Module Dependencies

| Requirement | Platform |
|---|---|
| PowerShell 5.1 or 7 | Windows 10 / 11 / Server 2016+ |
| OperationsManager module | SCOM 2015 |
| `powershell-yaml` (optional) | YAML config support |
| Pester (testing only) | `Install-Module Pester` |

---

## Jenkins Pipeline Integration

The root `Jenkinsfile` runs PSScriptAnalyzer on the full module. Extend it for a
dedicated maintenance-mode stage after Pester passes:

```powershell
# Inside the existing 'Code Quality & Security Scan' stage (after other PS tools)
echo [INFO] [8/8] Running PSScriptAnalyzer on maintenance module...
Invoke-ScriptAnalyzer -Path 'powershell\Automation\Public\Set-MaintenanceMode.ps1' `
    -Severity Error,Warning -OutputFormat Json `
    -OutFile 'code_scan_results\psa_maintenance.json'
```

See [`code_quality.md`](code_quality.md) for the full PSScriptAnalyzer /
gitleaks configuration and quality gates.
