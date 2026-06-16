# HPE ProLiant Windows Server ISO Automation — PowerShell Module

## Overview

**PowerShell** provides the end-to-end automation — firmware/driver ISO builds, Windows security patching, ISO deployment to iLO, installation monitoring, SCOM maintenance-mode orchestration, and OpsRamp telemetry — implemented as a native PowerShell module.

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
- `Pester` (v5.7.1, bundled) — for testing
- Posh-SSH — for SSH-based integrations (not yet implemented)

---

## Directory Layout

```
hpe-windows-iso-automation/
├── src/powershell/Automation/     # Module root
│   ├── Public/                    # Exported cmdlets
│   ├── Private/                   # Internal helpers
│   └── Automation.psd1            # Module manifest
└── tests/powershell/              # Pester test suite (Pester 5+)
    ├── Tests.Tests.ps1            # Shared BeforeAll/AfterAll
    └── *.Unit.Tests.ps1           # Test files per module
```

---

## Quick Start

### Import the Module

```powershell
Import-Module 'C:\path\to\powershell\Automation\Automation.psd1'
```

### Auto-Generated Documentation

A complete reference for all PowerShell cmdlets is auto-generated and available at:
- **[Auto-Generated Cmdlet Reference](dynamic-code-docs/INDEX.md)** — Full parameter tables, examples, and source locations

---

### Generate a Deterministic UUID

```powershell
New-Uuid -ServerName 'srv01.corp.local'
```

### Build ISOs for All Servers

```powershell
New-IsoBuild -BaseIsoPath 'C:\ISOs\WinServer2022.iso'
```

### Deploy ISOs via iLO

```powershell
Invoke-IsoDeploy -Method ilo -Server 'srv01.corp.local' -DryRun
```

### Maintenance Mode

```powershell
# Enable immediately (start=now; end computed from cluster schedule)
Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom -Start now

# Enable with explicit timestamps
Set-MaintenanceMode -Action enable `
    -TargetId 'CLU-CLUSTER-01' `
    -Mode scom `
    -Start   '2026-05-16 22:00' `
    -End     '2026-05-17 06:00'

# Disable immediately
Set-MaintenanceMode -Action disable -TargetId 'CLU-CLUSTER-01' -Mode scom

# Dry-run — no SCOM/iLO/OneView changes
Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' `
    -Mode scom `
    -Start '2026-05-16 22:00' -End '2026-05-17 06:00' -DryRun
```

For architecture, prerequisites, configuration, scheduling, audit logging, OpsRamp integration, environment variables, and troubleshooting see [maintenance_mode.md](maintenance_mode.md).

---

## Orchestrator API Reference

The orchestrator/routing layer is the **primary programmatic entry point** for all automation integrations.

| Concept | PowerShell Symbol |
|---------|-------------------|
| Orchestrator | `Start-AutomationOrchestrator` |
| Router / dispatcher | `Invoke-RoutedRequest` |
| Route table | `$script:RouteMap` |
| Request validator | `_Validate-Request` |

### Request Types

| RequestType | Handler | Required Params |
|-------------|---------|-----------------|
| `build_iso` | `New-IsoBuild` | `generated/base_iso` |
| `update_firmware` | `Update-Firmware` | — |
| `patch_windows` | `Update-WindowsSecurity` | `generated/base_iso` |
| `deploy` | `Invoke-IsoDeploy` | — |
| `monitor` | `Start-InstallMonitor` | — |
| `maintenance_enable` | `Set-MaintenanceMode` | `cluster_id` |
| `maintenance_disable` | `Set-MaintenanceMode` | `cluster_id` |
| `maintenance_validate` | `Set-MaintenanceMode` | `cluster_id` |
| `opsramp_report` | `Invoke-OpsRampClient` | — |
| `generate_uuid` | `New-Uuid` | — |

### Orchestrator Signature

```powershell
$result = Start-AutomationOrchestrator -RequestType '<type>' -Params @{ ... }
```

### Common Return Schema

```powershell
# Success
@{
    Success     = $true
    Output      = "...handler output text..."
    RequestType = "maintenance_enable"
    Timestamp   = "2026-05-16T17:50:00Z"
}

# Validation Failure
@{
    Success     = $false
    Errors      = @("Missing required parameter: cluster_id")
    RequestType = "build_iso"
    Timestamp   = "..."
}
```

### Request Flow

```text
Caller
  │
  ▼
Start-AutomationOrchestrator(RequestType, Params)
  │
  ├─► _Validate-Request(RequestType, Params)
  │       │
  │       └── errors?  YES → return validation-failure envelope
  │                     NO  → continue
  ▼
Invoke-RoutedRequest(RequestType, Params)
  │
  ├─► Route table lookup → handler name
  │
  ▼
& $handlerName @Params
  │
  ▼
Result envelope  ──► Orchestrator stamps RequestType + Timestamp  ──► Caller
```

---

## Running Tests

```powershell
# Install Pester if necessary
# Note: Pester 5.7.1 is bundled under vendor/modules/Pester/5.7.1/
# The setup script (make setup) installs it automatically
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck -Force

# Run all tests
pwsh -File scripts/run-tests.ps1

# Run maintenance mode tests only
pwsh -File scripts/run-maint-mode-tests.ps1

# Run a subset
Invoke-Pester -Path 'tests/powershell/New-Uuid.Unit.Tests.ps1'
```

See [testing.md](testing.md) for the full Pester guide.

---

## See Also

- [CI Run Requirements](powershell_ci.md)
- [Maintenance Mode](maintenance_mode.md)
- [Code Quality & Security](code_quality.md)