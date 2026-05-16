# Python Package — API Reference: Orchestrator & Routing Layer

> **Generic architecture documentation** (request types, orchestration flow,
> adding new handler types) is in [`../api_reference.md`](../api_reference.md).
> This page documents Python-specific types, return dicts, and dispatch
> behaviour for each symbol in the routing layer.

---

## Symbols

| Symbol | File | Public |
|---|---|---|
| `AutomationOrchestrator` | `src/automation/core/orchestrator.py` | yes |
| `route_request()` | `src/automation/core/router.py` | yes |
| `ROUTE_MAP` | `src/automation/core/router.py` | module-level constant |
| `validate_build_params()` | `src/automation/core/validators.py` | yes |
| `validate_cluster_id()` | `src/automation/core/validators.py` | yes |
| `validate_server_list()` | `src/automation/core/validators.py` | yes |

**Source equivalence** (PowerShell): `Start-AutomationOrchestrator`,
`Invoke-RoutedRequest`, `$script:RouteMap`, `_Validate-Request`.

---

## Route Map

`ROUTE_MAP` is a `dict[str, str]` whose keys are the request-type strings
accepted by `AutomationOrchestrator.execute()` and `route_request()`, and whose
values are the **module-name strings** of the handler to import.

```python
ROUTE_MAP = {
    "build_iso":            "automation.cli.build_iso",
    "update_firmware":      "automation.cli.update_firmware_drivers",
    "patch_windows":        "automation.cli.patch_windows_security",
    "deploy":               "automation.cli.deploy_to_server",
    "monitor":              "automation.cli.monitor_install",
    "maintenance_enable":   "automation.cli.maintenance_mode",
    "maintenance_disable":  "automation.cli.maintenance_mode",
    "maintenance_validate": "automation.cli.maintenance_mode",
    "opsramp_report":       "automation.cli.opsramp_integration",
    "generate_uuid":        "automation.cli.generate_uuid",
}
```

**Module:** `src/automation/core/router.py`

To add a new request type:

1. Add the key/value pair to `ROUTE_MAP` in `router.py`.
2. Ensure the handler module is importable (listed in `src/automation/cli/__init__.py` or `src/automation/__init__.py`).
3. Optionally add a validation branch in `AutomationOrchestrator._validate()` or in `validators.py`.

---

## 1 · AutomationOrchestrator.execute()

```python
from automation.core import AutomationOrchestrator

orch = AutomationOrchestrator(config_dir=Path("configs"), logs_dir=Path("logs"))
result = orch.execute("maintenance_enable", {"cluster_id": "PROD-CLUSTER-01", "start": "now"})
```

**Module:** `src/automation/core/orchestrator.py`
**Public:** yes

### Constructor

| Parameter | Type | Default | Description |
|---|---|---|---|
| `config_dir` | `pathlib.Path` | `Path("configs")` | Directory containing JSON config files |
| `logs_dir` | `pathlib.Path` | `Path("logs")` | Directory for audit and log output |
| `dry_run` | `bool` | `False` | When `True`, injected into every `params` dict as `"dry_run": True` |

### execute() parameters

| Name | Type | Description |
|---|---|---|
| `request_type` | `str` | One of the keys in `ROUTE_MAP` |
| `params` | `dict[str, Any]` | Parameters forwarded to the handler |

### Return dict

```python
# Success — keys merged from handler result
{
    "success":    True,
    "output":     "...handler output text...",
    "request_type": "maintenance_enable",
    "timestamp":  "2026-05-16T17:50:00+00:00",
    # handler-specific keys may also be present
}

# Validation failure — returned before routing
{
    "success": False,
    "errors":  ["Missing required parameter: base_iso", "Invalid cluster_id: UNKNOWN"],
    "timestamp": "2026-05-16T17:50:00+00:00",
    # request_type NOT stamped when validation fails
}

# Unknown request type — returned by route_request()
{
    "success":       False,
    "error":         "Unknown request type: foobar",
    "available_types": ["build_iso", "deploy", ...],
    "timestamp":     "..."
}
```

### Flow

1. `execute()` calls `self._validate(request_type, params)`.
2. If `_validate()` returns a non-empty `errors` list, the validation-failure dict
   is returned immediately (no routing occurs).
3. Otherwise `route_request(request_type, params)` dispatches to the handler
   resolved from `ROUTE_MAP`.
4. `timestamp` and `request_type` are stamped onto the handler result before it
   is returned.

### Usage

```python
from pathlib import Path
from automation.core import AutomationOrchestrator

orch = AutomationOrchestrator(
    config_dir=Path("configs"),
    logs_dir=Path("logs"),
)

# Enable maintenance
result = orch.execute("maintenance_enable", {
    "cluster_id": "PROD-CLUSTER-01",
    "start":      "2026-05-16 22:00",
    "end":        "2026-05-17 06:00",
})

if not result["success"]:
    print(f"Failed: {result.get('errors', result.get('error'))}")

# Build ISO
result = orch.execute("build_iso", {"base_iso": "/mnt/isos/WinServer2022.iso"})
```

---

## 2 · route_request()

```python
from automation.core.router import route_request

result = route_request("build_iso", {"base_iso": "/mnt/isos/WinServer2022.iso"})
```

**Module:** `src/automation/core/router.py`
**Public:** yes

### Parameters

| Name | Type | Description |
|---|---|---|
| `request_type` | `str` | One of the keys in `ROUTE_MAP` |
| `params` | `dict[str, Any]` | Parameters forwarded to the handler module's `main()` via `sys.argv` conversion |

### Return dict

| Condition | Returned dict keys |
|---|---|
| `request_type` found in `ROUTE_MAP`, module imported, `main()` exits 0 | `"success": True`, `"exit_code": 0` |
| `request_type` found in `ROUTE_MAP`, module imported, `main()` exits non-zero | `"success": False`, `"exit_code": <code>` |
| `request_type` **not** in `ROUTE_MAP` | `"success": False`, `"error"`, `"available_types"` |
| Module import fails | `"success": False`, `"error"` |
| `main()` raises `SystemExit` | `"success": <code==0>`, `"exit_code": <code>` |
| `main()` raises other exception | `"success": False`, `"error": str(e)` |
| No `main()` in handler module | `"success": False`, `"error"` |

### Dispatch flow

```
route_request(request_type, params)
  ├─ request_type in ROUTE_MAP?
  │     NO  → { success: False, error: "Unknown request type: …",
  │              available_types: [...] }
  │     YES → module_name = ROUTE_MAP[request_type]
  │
  ├─ importlib.import_module(module_name)
  │     FAIL → { success: False, error: "Module import failed: …" }
  │     OK   → module
  │
  ├─ request_type startswith "maintenance_"?
  │     YES → params["action"] = <enable|disable|validate>
  │           sys.argv = ["maintenance_mode.py", …]
  │           exit_code = module.main()
  │           → { success: exit_code == 0, exit_code }
  │
  ├─ hasattr(module, "main")?
  │     YES → exit_code = module.main()
  │           → { success: exit_code == 0, exit_code }
  │
  └─ → { success: False, error: "No main() in <module>" }
```

> **Note on `maintenance_*` routing:** The `action` key is extracted from the
> `request_type` string (`"maintenance_enable"` → `"enable"`) and injected into
> `params` before `sys.argv` is rewritten so the handler module's `argparse`
> parser picks it up via `--action`.

---

## 3 · _validate() and validators

```python
from automation.core import AutomationOrchestrator
from automation.core.validators import (
    validate_build_params,
    validate_cluster_id,
    validate_server_list,
)

orch = AutomationOrchestrator()

# Called internally by execute(); not typically called directly
errors = orch._validate("build_iso", {"base_iso": "/mnt/isos/WinServer2022.iso"})
```

**Module:** `src/automation/core/orchestrator.py` (`_validate`),  
`src/automation/core/validators.py` (public validators)

### `_validate()` return

```python
# No errors
[]
# One or more errors
["Base ISO not found: /bad/path.iso", "Invalid cluster ID: UNKNOWN"]
```

### Validator functions

#### `validate_build_params(base_iso_path, dry_run)`

```python
# Empty list = valid
errors = validate_build_params(base_iso_path="/mnt/isos/WinServer2022.iso")
if errors:
    print(errors)   # ["Base ISO not found: …"]
```

| Parameter | Type | Description |
|---|---|---|
| `base_iso_path` | `str \| None` | Path to the base Windows ISO; if `None` no file check is made |
| `dry_run` | `bool` | Included for API symmetry; does not suppress the file-existence check |

Returns `list[str]` — empty when valid.

#### `validate_cluster_id(cluster_id, catalogue_path)`

```python
definition = validate_cluster_id("PROD-CLUSTER-01", Path("configs/clusters_catalogue.json"))
if definition is None:
    print("Cluster not found or catalogue missing")
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `cluster_id` | `str` | — | Cluster identifier; must match a top-level key in the catalogue |
| `catalogue_path` | `pathlib.Path` | `Path("configs/clusters_catalogue.json")` | Path to the cluster catalogue JSON |

Returns the cluster definition `dict` on success, `None` on failure (when the
ID is absent, the file is missing, or required fields `servers` /
`scom_group` / `ilo_addresses` are absent).

#### `validate_server_list(server_list_path)`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `server_list_path` | `pathlib.Path` | `Path("configs/server_list.txt")` | Path to a newline-separated server list |

Returns `list[str]` of hostnames. Lines starting with `#` and blank lines are
skipped. Comma-separated `hostname,ipmi,ilo` rows have the hostname extracted
as the first field.

---

## Validation rules by RequestType

| RequestType pattern | Check |
|---|---|
| `build_iso` | `validate_build_params(base_iso_path=params["base_iso"])` |
| `patch_windows` | `validate_build_params(base_iso_path=params["base_iso"])` |
| `maintenance_*` | `validate_cluster_id(cluster_id=params["cluster_id"])` against `configs/clusters_catalogue.json` |
| anything else | no validation (passes through to handler) |

---

## Call sequence

```
Caller
  │
  ▼
AutomationOrchestrator.execute(request_type, params)
  │
  ├─► _validate(request_type, params) ──► errors?
  │                                          YES → return validation-failure dict
  │                                          NO  → continue
  ▼
route_request(request_type, params)
  │
  ├─► request_type in ROUTE_MAP?
  │       NO  → return unknown-type dict
  │       YES → module_name = ROUTE_MAP[request_type]
  │
  ├─► importlib.import_module(module_name)
  │
  ▼
module.main()  ──► exit_code
  │
  ▼
route_request wraps/returns  ──► execute stamps request_type + timestamp  ──► Caller
```
