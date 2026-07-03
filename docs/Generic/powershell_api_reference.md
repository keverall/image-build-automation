# HPE ProLiant Windows Server ISO Automation - PowerShell Module

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Directory Layout](#directory-layout)
- [Quick Start](#quick-start)
  - [Import the Module](#import-the-module)
  - [Auto-Generated Documentation](#auto-generated-documentation)
  - [Generate a Deterministic UUID](#generate-a-deterministic-uuid)
  - [Build ConfigMgr Bootable Media ISO](#build-configmgr-bootable-media-iso)
  - [Deploy ISOs via iLO Redfish](#deploy-isos-via-ilo-redfish)
  - [Physical Server Build](#physical-server-build)
  - [Maintenance Mode](#maintenance-mode)
- [Physical Server Build Workflow](#physical-server-build-workflow)
- [Orchestrator API Reference](#orchestrator-api-reference)
  - [Request Types](#request-types)
  - [Orchestrator Signature](#orchestrator-signature)
  - [Common Return Schema](#common-return-schema)
  - [Request Flow](#request-flow)
- [Running Tests](#running-tests)
- [See Also](#see-also)


<a name="overview"></a>
## Overview

**PowerShell** provides the end-to-end automation - physical server builds using Configuration Manager bootable media, HPE OneView targeting, and iLO Redfish virtual-media boot; firmware/driver ISO builds; Windows security patching; ISO deployment to iLO; installation monitoring; SCOM maintenance-mode orchestration; and OpsRamp telemetry - implemented as a native PowerShell module.

---

<a name="requirements"></a>
## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 5.1 or PowerShell 7 |
| Windows | Windows 10 / 11 / Server 2016+ (WinRM, DISM, schtasks) |
| HPE SUT | `hpe_sut.exe` on the machine or in `PATH` |
| .NET | .NET Framework 4.7.2 (PS 5.1 hosts) or .NET 6+ (PS 7) |

Optional modules:
- `powershell-yaml` (`Install-Module powershell-yaml`) - for YAML config support
- `Pester` (v5.7.1, bundled) - for testing
- Posh-SSH - for SSH-based integrations (not yet implemented)

---

<a name="directory-layout"></a>
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

<a name="quick-start"></a>
## Quick Start

<a name="import-the-module"></a>
### Import the Module

```powershell
Import-Module 'C:\path\to\powershell\Automation\Automation.psd1'
```

<a name="auto-generated-documentation"></a>
### Auto-Generated Documentation

A complete reference for all PowerShell cmdlets is auto-generated and available at:
- **[Auto-Generated Cmdlet Reference](,,dynamic-code-docs\INDEX.md)** - Full parameter tables, examples, and source locations
- **[Automation Command Reference](..\Automation\automation_commands.md)** - Concise functional command reference with every parameter for all automation commands
docs\dynamic-code-docs\INDEX.md
---

<a name="generate-a-deterministic-uuid"></a>
### Generate a Deterministic UUID

```powershell
New-Uuid -ServerName 'srv01.corp.local'
```

<a name="build-configmgr-bootable-media-iso"></a>
### Build ConfigMgr Bootable Media ISO

```powershell
New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' `
    -DistributionPoint 'dp01.ad.example.com' -BootImageName 'WinPE x64 - HPE'
```

<a name="deploy-isos-via-ilo-redfish"></a>
### Deploy ISOs via iLO Redfish

```powershell
Invoke-IsoDeploy -Method redfish -Server 'srv01.corp.local' -DryRun
```

<a name="physical-server-build"></a>
### Physical Server Build

```powershell
Start-PhysicalServerBuild -ServerIdentifier 'PROD-SERVER-01' `
    -OneViewHost 'oneview.ad.example.com' -IloIp '192.168.1.101' `
    -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' `
    -BootImageName 'WinPE x64 - HPE' -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
    -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com' -DryRun
```

<a name="maintenance-mode"></a>
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

# Dry-run - no SCOM/iLO/OneView changes
Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' `
    -Mode scom `
    -Start '2026-05-16 22:00' -End '2026-05-17 06:00' -DryRun
```

For architecture, prerequisites, configuration, scheduling, audit logging, OpsRamp integration, environment variables, and troubleshooting see [Maintenance Mode](..\Maintenance-Mode\maintenance_mode.md).

<a name="physical-server-build-workflow"></a>
## Physical Server Build Workflow

The runbook workflow (`runbook-requirements.md` / `runbook-changes.md`) is implemented by the commands below. Each step can be run standalone or together through the orchestrator.

| Step | Command | Purpose |
| --- | --- | --- |
| 1. Pre-build validation | `Test-PreBuildValidation` | Verify OneView target, ISO URL, iLO credentials, MP/DP reachability. |
| 2. Build ISO | `New-IsoBuild` | Create a ConfigMgr WinPE bootable media ISO. |
| 3. Publish ISO | `Publish-BootIso` | Copy the ISO to an HTTPS repository reachable by iLO. |
| 4. Resolve target | `Get-OneViewServerTarget` | Query OneView for server identity, health, and iLO IP. |
| 5. Mount and boot | `Invoke-IloRedfish` | Mount the ISO via Redfish, set one-time boot, restart. |
| 6. Monitor | `Start-InstallMonitor` | Poll iLO/WinRM until installation completes or fails. |
| 7. Post-build validation | `Test-PostBuildValidation` | Verify hostname, domain, OS, drivers, ConfigMgr client. |
| 8. Orchestrate | `Start-PhysicalServerBuild` | Run steps 1–7 in a single call with audit logging. |

See [Automation Command Reference](..\Automation\automation_commands.md) for full parameter details.

---

<a name="orchestrator-api-reference"></a>
## Orchestrator API Reference

The orchestrator/routing layer is the **primary programmatic entry point** for all automation integrations.

| Concept | PowerShell Symbol |
|---------|-------------------|
| Orchestrator | `Start-AutomationOrchestrator` |
| Router / dispatcher | `Invoke-RoutedRequest` |
| Route table | `$script:RouteMap` |
| Request validator | `_Validate-Request` |

<a name="request-types"></a>
### Request Types

| RequestType | Handler | Required Params |
|-------------|---------|-----------------|
| `build_iso` | `New-IsoBuild` | `SiteCode`, `ManagementPoint`, `DistributionPoint` |
| `update_firmware` | `Update-Firmware` | - |
| `patch_windows` | `Update-WindowsSecurity` | `BaseIsoPath` |
| `deploy` | `Invoke-IsoDeploy` | - |
| `monitor` | `Start-InstallMonitor` | - |
| `maintenance_enable` | `Set-MaintenanceMode` | `TargetId` |
| `maintenance_disable` | `Set-MaintenanceMode` | `TargetId` |
| `maintenance_validate` | `Set-MaintenanceMode` | `TargetId` |
| `opsramp_report` | `Invoke-OpsRampClient` | - |
| `generate_uuid` | `New-Uuid` | - |
| `connectivity_check` | `Test-ServerConnectivity` | `Mode` |
| `gitlab_maintenance` | `Invoke-GitLabMaintenanceTrigger` | `TargetId`, `Action` |
| `physical_server_build` | `Start-PhysicalServerBuild` | `ServerIdentifier` |
| `query_oneview_server` | `Get-OneViewServerTarget` | `ServerIdentifier` |
| `prebuild_validation` | `Test-PreBuildValidation` | `ServerIdentifier` |
| `postbuild_validation` | `Test-PostBuildValidation` | `Hostname` |
| `publish_iso` | `Publish-BootIso` | `IsoPath` |
| `ilo_redfish_mount` | `Invoke-IloRedfish` | `Action`, `IloIp` |

<a name="orchestrator-signature"></a>
### Orchestrator Signature

```powershell
$result = Start-AutomationOrchestrator -RequestType '<type>' -Params @{ ... }
```

<a name="common-return-schema"></a>
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

<a name="request-flow"></a>
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

<a name="running-tests"></a>
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

<a name="see-also"></a>
## See Also

- [Automation Command Reference](..\Automation\automation_commands.md) - full parameter reference for all automation commands
- [Runbook Requirements](..\Automation\runbook-requirements.md) - operational runbook for physical HPE server builds
- [Runbook Changes](..\Automation\runbook-changes.md) - implementation plan for the ConfigMgr bootable-media workflow
- [CI Run Requirements](..\Generic\powershell_ci.md)
- [Maintenance Mode](..\Maintenance-Mode\maintenance_mode.md)
- [Code Quality & Security](..\Generic\code_quality.md)
