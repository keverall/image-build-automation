# Orchestrator & Routing Layer — API Reference

> **Language-agnostic reference.** For PowerShell types and return schemas, see
> [src/powershell/api_reference.md](src/powershell/api_reference.md).

---

## Overview

The orchestrator/routing layer is the **primary programmatic entry point** for
all automation integrations. Callers interact only with the top-level
orchestrator function; the router selects the handler for each request type, and
an optional validator enforces pre-conditions before routing occurs.

| Concept | PowerShell equivalent |
|---------|-----------------------|
| Orchestrator | `Start-AutomationOrchestrator` |
| Router / dispatcher | `Router.ps1` / `Invoke-RoutedRequest` |
| Route table | `$script:RouteMap` hashtable |
| Request validator | `_Validate-Request.ps1` |

---

## Request Types

Every orchestrator call specifies a `RequestType` /
`-RequestType` string (PowerShell). Each is bound 1-to-1 to a handler function.

| RequestType | Handler (PowerShell) | Required Params |
|---|---|---|---|
| `build_iso` | `NewIsoBuild` | `New-IsoBuild` | `base_iso` |
| `update_firmware` | `UpdateFirmwareDrivers` | `Update-Firmware` | — |
| `patch_windows` | `PatchWindowsSecurity` | `Update-WindowsSecurityUpdate` | `base_iso` |
| `deploy` | `DeployToServer` | `Invoke-IsoDeploy` | — |
| `monitor` | `MonitorInstall` | `Start-InstallMonitor` | — |
| `maintenance_enable` | `SetMaintenanceMode` | `Set-MaintenanceMode` | `cluster_id` |
| `maintenance_disable` | `SetMaintenanceMode` | `Set-MaintenanceMode` | `cluster_id` |
| `maintenance_validate` | `SetMaintenanceMode` | `Set-MaintenanceMode` | `cluster_id` |
| `opsramp_report` | `InvokeOpsRamp` | `Invoke-OpsRamp` | — |
| `generate_uuid` | `GenerateUuid` | `New-Uuid` | — |

---

## Orchestrator Signature

```powershell
# PowerShell
$result = Start-AutomationOrchestrator -RequestType '<type>' -Params @{ ... }
```

`params` / `-Params` is a dict / hashtable forwarded to the handler.

---

## Common Return Schema

All orchestrators return a uniform result envelope regardless of outcome.
PowerShell uses a `[hashtable]`.

### Success

```powershell
@{
    Success     = $true
    Output      = "...handler output text..."
    RequestType = "maintenance_enable"
    Timestamp   = "2026-05-16T17:50:00Z"
}
```

### Validation Failure (returned before routing)

Triggered when request-specific preconditions fail (e.g., missing or invalid
params).

```powershell
@{
    Success     = $false
    Errors      = @(
        "Missing required parameter: base_iso",
        "Invalid cluster_id: UNKNOWN"
    )
    RequestType = "build_iso"
    Timestamp   = "..."
}
```

### Unknown Request Type

Returned when the `RequestType` string does not match any route table entry.

```powershell
@{
    Success        = $false
    Error          = "Unknown request type: foobar"
    AvailableTypes = @("build_iso", "deploy", ...)
    RequestType    = "foobar"
    Timestamp      = "..."
}
```

---

## Request Flow

```
Caller
  │
  ▼
Orchestrator.execute(request_type, params)
  │
  ├─► Validate(request_type, params)
  │       │
  │       └── errors?  YES → return validation-failure envelope
  │                     NO  → continue
  ▼
Router.dispatch(request_type, params)
  │
  ├─► Route table lookup → handler name
  │
  ▼
Handler(params)
  │
  ▼
Result envelope  ──► Orchestrator stamps RequestType + Timestamp  ──► Caller
```

---

## Adding a New Request Type

1. Add the key/value pair to the **route table**:
    - PowerShell: `$script:RouteMap` in `_RouteMap.ps1`
2. Add a corresponding validation branch in the **request validator** if the
    new type requires mandatory parameters:
    - PowerShell: `_Validate-Request.ps1`
3. Export the handler function in the module manifest.

---

## Request Validation

Validation runs before any handler executes. Each `RequestType` may declare its
own validator. No request is dispatched or mutated when validation reports
errors — the validation-failure envelope is returned immediately.

### Validation rules by RequestType

| RequestType pattern | Check |
|---|---|
| `build_iso` | `base_iso` path is present and non-empty |
| `patch_windows` | `base_iso` path is present and non-empty |
| `maintenance_*` | `cluster_id` is present and resolveable in the cluster catalogue |
| anything else | no validation (passes through to handler) |

---

## Additional Language-Specific Detail

- For the PowerShell view of each symbols — module paths, `[hashtable]` return
  types for every dispatcher branch, and `$script:RouteMap` docs — see
  [`src/powershell/api_reference.md`](src/powershell/api_reference.md).
