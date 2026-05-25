# HPE ProLiant Windows Server ISO Automation — PowerShell Module

## Overview

**PowerShell** provides the end-to-end automation — firmware / driver ISO builds,
Windows security patching, ISO deployment to iLO, installation monitoring, SCOM
maintenance-mode orchestration, and OpsRamp telemetry — implemented as a native
PowerShell module.

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

See [New-Uuid (generated reference)](generated/New-Uuid.md) for full parameter documentation.

```powershell
New-Uuid -ServerName 'srv01.corp.local'
```

### Build ISOs for all servers

See [New-IsoBuild (generated reference)](generated/New-IsoBuild.md) for full parameter documentation.

```powershell
New-IsoBuild -BaseIsoPath 'C:\ISOs\WinServer2022.iso'
```

### Deploy ISOs via iLO

See [Invoke-IsoDeploy (generated reference)](generated/Invoke-IsoDeploy.md) for full parameter documentation.

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

  pattern:

- `[System.IO.Path]` / `Join-Path`
- Comment-based; no runtime enforcement in PS 5.1
- `[hashtable]` / `[pscustomobject]` 
- PowerShell `class` with typed properties 
- `Invoke-Command` / `System.Diagnostics.Process`
- `New-PSSession` + `Invoke-Command -Session` 
- **Pester** BDD framework 
- PowerShell `param()` + `[CmdletBinding()]` 
- `[System.Diagnostics.TraceSource]` + `ConsoleTraceListener` 
- `[System.Net.Http.HttpClient]` 
- Here-string / interpolated strings 
- Runspaces / PS Jobs (not needed; kept synchronous for fidelity) 

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

## See Also

- [PowerShell Generated Cmdlets Reference](generated/INDEX.md) — full auto-generated documentation for all cmdlets