# HPE ProLiant Windows Server ISO Automation — PowerShell Module

## Overview

This is the **PowerShell translation** of the [`hpe-automation`](../README.md) Python
project. It provides the same end-to-end automation — firmware / driver ISO builds,
Windows security patching, ISO deployment to iLO, installation monitoring, SCOM
maintenance-mode orchestration, and OpsRamp telemetry — implemented as a native
PowerShell module.

> **Note:** This is a feasibility implementation. The Python project remains the
> authoritative, production-tested codebase.

---

## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 5.1 or PowerShell 7 |
| Windows | Windows 10 / 11 / Server 2016+ (WinRM, DISM, schtasks) |
| HPE SUT | `hpe_sut.exe` on the machine or in `PATH` |
| .NET | .NET Framework 4.7.2 (PS 5.1 hosts) or .NET 6+ (PS 7) |

Optional modules:
- `powershell-yaml` (`Install-Module powershell-yaml`) — for YAML config support
- `Pester` (`Install-Module Pester`) — for testing
- Posh-SSH — for SSH-based integrations (not yet implemented)

---

## Directory Layout

```
src/powershell/
├── Automation/                    # Module root
├── Tests/                         # Pester test suite (Pester 5+)
    ├── Tests.Tests.ps1            # Shared BeforeAll/AfterAll
    ├── Config.Unit.Tests.ps1
    ├── Credentials.Unit.Tests.ps1
    ├── Executor.Unit.Tests.ps1
    ├── FileIO.Unit.Tests.ps1
    ├── Inventory.Unit.Tests.ps1
    ├── Validators.Unit.Tests.ps1
    ├── Router.Unit.Tests.ps1
    ├── New-Uuid.Unit.Tests.ps1
    ├── Audit.Unit.Tests.ps1
    └── Set-MaintenanceMode.Unit.Tests.ps1
```

---

## Quick Start

### Import the module

```powershell
Import-Module 'C:\path\to\powershell\Automation\Automation.psd1'
```

### Generate a deterministic UUID

```powershell
New-Uuid -ServerName 'srv01.corp.local'
```

### Build ISOs for all servers

```powershell
New-IsoBuild -BaseIsoPath 'C:\ISOs\WinServer2022.iso'
```

### Deploy ISOs via iLO

```powershell
Invoke-IsoDeploy -Method ilo -Server 'srv01.corp.local' -DryRun
```

### Maintenance mode

For architecture, prerequisites, configuration (`clusters_catalogue.json`,
`scom_config.json`, etc.), scheduling, audit logging, OpsRamp integration,
environment variables, and troubleshooting see
[`maintenance_mode.md`](maintenance_mode.md).

```powershell
# Enable immediately (start=now; end computed from cluster schedule)
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now

# Enable with explicit timestamps
Set-MaintenanceMode -Action enable `
    -ClusterId 'PROD-CLUSTER-01' `
    -Start   '2026-05-16 22:00' `
    -End     '2026-05-17 06:00'

# Disable immediately
Set-MaintenanceMode -Action disable -ClusterId 'PROD-CLUSTER-01'

# Dry-run — no SCOM/iLO/OpenView changes
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start '2026-05-16 22:00' -End '2026-05-17 06:00' -DryRun
```

### Orchestrator (iRequest pattern)

For generic orchestrator architecture, request types, and flow see
[`../api_reference.md`](../api_reference.md). To dispatch maintenance mode
through the orchestrator:

```powershell
$result = Start-AutomationOrchestrator -RequestType 'maintenance_enable' `
    -Params @{ cluster_id = 'PROD-CLUSTER-01'; start = 'now' }
```

All orchestrator results use the same envelope: `Success` (bool), `Output` /
`Errors`, `RequestType`, and a UTC `Timestamp`.

---

## Key Design Decisions

| Python pattern | PowerShell equivalent |
|---|---|
| `pathlib.Path` | `[System.IO.Path]` / `Join-Path` |
| Type hints (`str`, `int`, `Optional`) | Comment-based; no runtime enforcement in PS 5.1 |
| `dict[str, Any]` | `[hashtable]` / `[pscustomobject]` |
| `dataclasses.dataclass` | PowerShell `class` with typed properties |
| `subprocess.run()` | `Invoke-Command` / `System.Diagnostics.Process` |
| `pywinrm.Session.run_ps()` | `New-PSSession` + `Invoke-Command -Session` |
| `pytest` (254 tests) | **Pester** BDD framework |
| `argparse` | PowerShell `param()` + `[CmdletBinding()]` |
| `logging` | `[System.Diagnostics.TraceSource]` + `ConsoleTraceListener` |
| `requests.Session()` | `[System.Net.Http.HttpClient]` |
| f-string PS generation | Here-string / interpolated strings |
| `asyncio` | Runspaces / PS Jobs (not needed; kept synchronous for fidelity) |

---

## Key Differences from the Python Version

- **WinRM → native PowerShell remoting**: The Python `run_powershell_winrm` used
  `pywinrm`; PowerShell uses `New-PSSession` and built-in WSMan trust hosts — the
  caller may need `TrustedHosts` set.
- **iLO REST → Invoke-RestMethod**: Python `requests` calls were translated directly
  to `Invoke-RestMethod` / `Invoke-WebRequest` on the .NET `HttpClient`.
- **No async primitives**: PowerShell 5.1 lacks `async`/`await`. Thread-pool
  polling in `Start-InstallMonitor` was reimplemented as a synchronous `foreach`
  loop.
- **Scheduled Tasks**: Python called `schtasks.exe` directly via `run_command`;
  PowerShell does the same via `Invoke-Command`.
- **Logging**: Python `logging` was translated to `[TraceSource]` + `ConsoleTraceListener`.

---

## Running Tests

```powershell
# Install Pester if necessary
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force

# Run all tests
Invoke-Pester -Path 'powershell\Tests' -PassThru

# Run a subset
Invoke-Pester -Path 'powershell\Tests\New-Uuid.Tests.ps1'
```

---

## Status

| Module | Python SLOC | PowerShell SLOC | Status |
|---|---|---|---|
| `powershell.py` → `Invoke-PowerShell.psm1` | 180 | ~220 | ✅ Converted |
| `config.py` → `Config.psm1` | 108 | ~180 | ✅ Converted |
| `credentials.py` → `Credentials.psm1` | 76 | ~180 | ✅ Converted |
| `executor.py` → `Executor.psm1` | 142 | ~220 | ✅ Converted |
| `file_io.py` → `FileIO.psm1` | 96 | ~180 | ✅ Converted |
| `inventory.py` → `Inventory.psm1` | 145 | ~200 | ✅ Converted |
| `audit.py` → `Audit.psm1` | 151 | ~130 | ✅ Converted |
| `logging_setup.py` → `Logging.psm1` | 51 | ~140 | ✅ Converted |
| `base.py` → `Base.psm1` | 118 | ~130 | ✅ Converted |
| `validators.py` → `_Validate-Request.ps1` | 105 | ~140 | ✅ Converted |
| `router.py` → `Router.psm1` | 102 | ~80 | ✅ Converted |
| `orchestrator.py` → `Start-AutomationOrchestrator.ps1` | 162 | ~80 | ✅ Converted |
| `generate_uuid.py` → `New-Uuid.ps1` | 79 | ~130 | ✅ Converted |
| `maintenance_mode.py` → `Set-MaintenanceMode.ps1` | 956 | ~550 | ✅ Converted |
| `deploy_to_server.py` → `Invoke-IsoDeploy.ps1` | 296 | ~280 | ✅ Converted |
| `opsramp_integration.py` → `OpsRampClient.psm1` | 540 | ~300 | ✅ Converted |
| `build_iso.py` → `New-IsoBuild.ps1` | 318 | ~250 | ✅ Converted |
| `update_firmware_drivers.py` → `Update-Firmware.ps1` | 265 | ~260 | ✅ Converted |
| `patch_windows_security.py` → `Update-WindowsSecurity.ps1` | 280 | ~260 | ✅ Converted |
| `monitor_install.py` → `Start-InstallMonitor.ps1` | 481 | ~330 | ✅ Converted |
| **pytest tests** (254) | **3,535** | ~900 | ✅ Pester (25/25 passing on CI) |

---

## See Also

- Python project: [`../README.md`](../README.md)