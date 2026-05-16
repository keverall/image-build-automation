# PowerShell Module — API Reference: Orchestrator & Routing Layer

> **Generic architecture documentation** (request types, orchestration flow,
> adding new handler types) is in [`../api_reference.md`](../api_reference.md).
> This page documents PowerShell-specific types, return schemas, and dispatch
> behaviour for each symbol in the routing layer.

---

## Symbols

| Symbol | File | Exported |
|---|---|---|
| `Start-AutomationOrchestrator` | `Public/Start-AutomationOrchestrator.ps1` | yes |
| `Invoke-RoutedRequest` | `Private/Router.ps1` | yes |
| `$script:RouteMap` | `Private/_RouteMap.ps1` | no |
| `_Validate-Request` | `Public/_Validate-Request.ps1` | no |

**Source equivalence** (Python): `AutomationOrchestrator.execute()`, `router.py`,
`_ROUTE_MAP`, `_VALIDATORS`.

---

## Route Map

`$script:RouteMap` is a `[hashtable]` whose keys are the request-type strings
accepted by the orchestrator and whose values are the **function-name strings**
of the handler to invoke. Defined before `Router.ps1` is dot-sourced so the
table exists at parse time.

```powershell
$script:RouteMap = @{
    'build_iso'            = 'New-IsoBuild'
    'update_firmware'      = 'Update-Firmware'
    'patch_windows'        = 'Invoke-WindowsSecurityUpdate'
    'deploy'               = 'Invoke-IsoDeploy'
    'monitor'              = 'Start-InstallMonitor'
    'maintenance_enable'   = 'Set-MaintenanceMode'
    'maintenance_disable'  = 'Set-MaintenanceMode'
    'maintenance_validate' = 'Set-MaintenanceMode'
    'opsramp_report'       = 'Invoke-OpsRamp'
    'generate_uuid'        = 'Test-Uuid'
}
```

**Module:** `powershell/Automation/Private/_RouteMap.ps1`
**Exported:** no (`$script:`-scoped data variable)

To add a new request type:

1. Add the key/value pair to `$script:RouteMap` in `_RouteMap.ps1`.
2. Export or expose the handler in `Automation.psd1`.
3. Optionally add a validation branch in `_Validate-Request.ps1`.

---

## 1 · Start-AutomationOrchestrator

```powershell
Start-AutomationOrchestrator -RequestType <string> -Params <hashtable>
```

**Module:** `powershell/Automation/Public/Start-AutomationOrchestrator.ps1`
**Exported:** yes

### Parameters

| Name | Type | Mandatory | Description |
|---|---|---|---|
| `RequestType` | `string` | yes | One of the request-type strings in `$script:RouteMap` |
| `Params` | `hashtable` | no | Optional parameters forwarded to the handler; defaults to `@{}` |

### Return schema

```powershell
# Success — keys merged from handler result
@{
    Success     = [bool]       # true
    Output      = [string]     # handler output text
    RequestType = [string]     # the RequestType passed in
    Timestamp   = [string]     # ISO 8601 timestamp (ToString('o'))
}

# Validation failure — returned before routing
@{
    Success     = [bool]       # false
    Errors      = [string[]]   # validation-error strings
    RequestType = [string]
    Timestamp   = [string]
}

# Unknown request type — returned by Invoke-RoutedRequest
@{
    Success        = [bool]    # false
    Error          = [string]  # "Unknown request type: <type>"
    AvailableTypes = [string[]]# all keys of $script:RouteMap
    RequestType    = [string]
    Timestamp      = [string]
}
```

### Flow

1. Calls `_Validate-Request` with the supplied `RequestType` and `Params`.
2. If validation returns errors, the error envelope is returned immediately (no routing).
3. Otherwise `Invoke-RoutedRequest` dispatches to the handler in `$script:RouteMap`.
4. `Timestamp` and `RequestType` are stamped onto the handler result before it is returned.

```powershell
$result = Start-AutomationOrchestrator -RequestType 'maintenance_enable' `
               -Params @{ cluster_id = 'PROD-CLUSTER-01'; start = 'now' }

if (-not $result.Success) {
    Write-Error "Failed: $($result.Errors -join '; ')"
}
```

---

## 2 · Invoke-RoutedRequest

```powershell
Invoke-RoutedRequest -RequestType <string> -Params <hashtable>
```

**Module:** `powershell/Automation/Private/Router.ps1`
**Exported:** yes
**Note:** normally called only by `Start-AutomationOrchestrator`; direct callers are responsible for their own validation.

### Parameters

| Name | Type | Mandatory | Description |
|---|---|---|---|
| `RequestType` | `string` | yes | One of the request-type strings in `$script:RouteMap` |
| `Params` | `hashtable` | no | Parameters forwarded to the handler via splatting; defaults to `@{}` |

### Return schema

| Condition | Returned hashtable keys |
|---|---|
| Handler returns a `[hashtable]` | `Success`, handler-specific keys, `request_type` |
| Handler returns a non-hashtable value | `Success` = `$true`, `Output` = Out-String of the result |
| `RequestType` not in `$script:RouteMap` | `Success` = `$false`, `Error`, `AvailableTypes` |
| Handler function not found at runtime | `Success` = `$false`, `Error` |
| Handler throws | `Success` = `$false`, `Error` = exception message |

### Dispatch flow

```
Invoke-RoutedRequest ($RequestType, $Params)
  ├─ $script:RouteMap.ContainsKey($RequestType)?
  │     NO  → { Success: false, Error: "Unknown request type: …",
  │              AvailableTypes: [...] }
  │     YES → $handlerName = $script:RouteMap[$RequestType]
  │
  ├─ Get-Command $handlerName
  │     NOT FOUND → { Success: false, Error: "Handler '$handlerName' not found." }
  │     FOUND   → try { $result = & $handlerName @Params
  │                    if ($result -is [hashtable]) {
  │                        $result['request_type'] = $RequestType; return $result }
  │                    else {
  │                        return { Success: true; Output: ($result | Out-String) } }
  │                }
  │                catch { return { Success: false; Error: $_.Exception.Message } }
```

---

## 3 · _Validate-Request

```powershell
_Validate-Request -RequestType <string> -Params <hashtable>
```

**Module:** `powershell/Automation/Public/_Validate-Request.ps1`
**Exported:** no (private; underscore-prefixed)
**Called by:** `Start-AutomationOrchestrator`

### Parameters

| Name | Type | Mandatory | Description |
|---|---|---|---|
| `RequestType` | `string` | yes | Request type string |
| `Params` | `hashtable` | yes | Parameters supplied by the caller |

### Return schema

```powershell
# No errors — empty array
[string[]]   # always non-null; empty means "pass"
```

### Validation rules

| RequestType pattern | Check |
|---|---|
| `build_iso` | `Test-BuildParams -BaseIsoPath $Params['base_iso']` |
| `patch_windows` | `Test-BuildParams -BaseIsoPath $Params['base_iso']` |
| `maintenance_*` | `Test-ClusterId -ClusterId $Params['cluster_id']`; rejects unknown IDs |
| anything else | returns empty error array (no-op) |

If any check appends to `$errors`, the full array is returned and
`Start-AutomationOrchestrator` treats it as a validation failure before
attempting to route the request.

---

## Call sequence

```
Caller
  │
  ▼
Start-AutomationOrchestrator(RequestType, Params)
  │
  ├─► _Validate-Request(RequestType, Params) ──► errors?
  │                                               YES → return error envelope
  │                                               NO  → continue
  ▼
Invoke-RoutedRequest(RequestType, Params)
  │
  ├─► $script:RouteMap[$RequestType] → handlerName
  │
  ▼
& $handlerName @Params
  │
  ▼
Handler result (hashtable or scalar)
  │
  ▼
Invoke-RoutedRequest wraps/returns  ──► Start-AutomationOrchestrator stamps
                                    RequestType + Timestamp  ──► Caller
```
