# HPE ProLiant Windows Server ISO Automation — PowerShell Module

## Overview

This is the **PowerShell translation** of the [`hpe-automation`](README.md) Python
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
powershell/
├── Automation/                    # Module root
│   ├── Automation.psd1            # Module manifest
│   ├── Automation.psm1            # Root init (dot-sources all sub-modules)
│   ├── Public/                    # User-visible cmdlets & helper classes
│   │   ├── Invoke-PowerShell.psm1  # Run-PowerShell / WinRM / SCOM templates
│   │   ├── OpsRampClient.psm1     # OpsRamp REST API client class
│   │   ├── Invoke-Validator.psm1  # Cluster / build / server-list validators
│   │   ├── Invoke-Orchestrator.psm1 # Unified request router
│   │   ├── New-Uuid.ps1           # Deterministic UUID generator (Xorshift32 PRNG)
│   │   ├── New-IsoBuild.ps1       # Full ISO build orchestrator
│   │   ├── Update-Firmware.ps1    # HPE SUT firmware / driver ISO builder
│   │   ├── Update-WindowsSecurity.ps1 # DISM / PS security patcher
│   │   ├── Invoke-IsoDeploy.ps1   # iLO virtual media deployer
│   │   └── Start-InstallMonitor.ps1 # Installation progress monitor
│   └── Private/                   # Internal helpers (not exported)
│       ├── Audit.psm1             # Structured JSON audit logger
│       ├── Base.psm1              # AutomationBase class (shared logic)
│       ├── Config.psm1            # JSON / YAML config loader + env-var substitution
│       ├── Credentials.psm1       # Env-var backed credential helpers
│       ├── Executor.psm1          # Invoke-Command / retry / CommandResult class
│       ├── FileIO.psm1            # Save-Json / Load-Json / Ensure-DirectoryExists
│       ├── Inventory.psm1         # ServerInfo / Load-ServerList / ClusterCatalogue
│       ├── Logging.psm1           # Initialize-Logging / Get-Logger
│       └── Router.psm1            # Route-map + Invoke-RoutedRequest
└── Tests/                         # Pester test suite (Pester 5+)
    ├── Tests.Tests.ps1            # Shared BeforeAll/AfterAll
    ├── Config.Tests.ps1
    ├── Credentials.Tests.ps1
    ├── Executor.Tests.ps1
    ├── FileIO.Tests.ps1
    ├── Inventory.Tests.ps1
    ├── Validators.Tests.ps1
    ├── Router.Tests.ps1
    ├── New-Uuid.Tests.ps1
    ├── Audit.Tests.ps1
    └── Set-MaintenanceMode.Tests.ps1
```

---

## Quick Start

### Import the module

```powershell
Import-Module 'C:\path\to\powershell\Automation\Automation.psd1'
```

### Generate a deterministic UUID

```powershell
Test-Uuid -ServerName 'srv01.corp.local'
```

### Build ISOs for all servers

```powershell
New-IsoBuild -BaseIsoPath 'C:\ISOs\WinServer2022.iso'
```

### Enable maintenance mode

```powershell
Set-MaintenanceMode -Action enable -ClusterId 'PROD-CLUSTER-01' -Start now
```

### Deploy ISOs via iLO

```powershell
Invoke-IsoDeploy -Method ilo -Server 'srv01.corp.local' -DryRun
```

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
| `validators.py` → `Invoke-Validator.psm1` | 105 | ~140 | ✅ Converted |
| `router.py` → `Router.psm1` | 102 | ~80 | ✅ Converted |
| `orchestrator.py` → `Invoke-Orchestrator.psm1` | 162 | ~80 | ✅ Converted |
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
- Migration plan: `.kilo/plans/`
