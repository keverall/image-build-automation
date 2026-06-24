# HPE ProLiant Windows Server ISO Automation (Root Readme)

Automated build pipelines for creating customized Windows Server installation ISOs and for orchestrating physical HPE ProLiant server deployments using Microsoft Configuration Manager bootable media, HPE OneView, and HPE iLO Redfish. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

---

## 🚀 Quick Start - Setup & Installation

**New to this project?** Start here:

1. **[📖 Setup Guide](docs/SETUP-GUIDE.md)** - Complete setup instructions for PowerShell profile and maintenance mode
2. **[🔧 Quick Client Setup](docs/MAINTENANCE_MODE_SHORTCUTS.md)** - 5-minute setup for using maintenance mode commands
3. **[⚡ Shortcut Reference](docs/MAINTENANCE_MODE_SHORTCUTS.md)** - All `mm` command options and examples

### TL;DR - One-Line Setup

```powershell
make setup && cp wip/vscodeprofile.ps1 ~/.config/powershell/Microsoft.VSCode_profile.ps1 && . $PROFILE
```

Then use:

```powershell
# 1. Test connectivity first (safe during change freeze)
Test-ServerConnectivity -Mode scom -Environment Prod

# 2. Enable maintenance mode
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod

# 3. Disable maintenance mode
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

---

## Table of Contents

### Internal docs index

#### Core Documentation
| Document | Description |
|---|---|
| [📚 Documentation Index](docs/README.md) | Complete documentation overview |
| [🚀 Setup Guide](docs/SETUP-GUIDE.md) | **START HERE** - Profile setup, module installation, quick start |
| [📡 PowerShell API Reference](docs/powershell_api_reference.md) | Module overview, cmdlet usage, orchestrator API |
| [📗 Automation Command Reference](docs/automation_commands.md) | **All automation commands with full parameter tables** — functional reference linking to source |
| [📘 PowerShell Function Reference](docs/dynamic-code-docs/INDEX.md) | **Complete coverage of ALL PowerShell functions and cmdlets** - comprehensive parameter documentation, examples, and usage for every function in src/powershell/Automation/. Auto-generated from source code. |
| [🔌 CI Run Requirements](docs/powershell_ci.md) | Prerequisites, CyberArk bootstrap, GitLab/Jenkins examples |
| [🧪 PowerShell Testing (Pester)](docs/testing.md) | Pester v5 BDD testing guide, test commands, mocking |
| [⚙️ Code Quality & Security](docs/code_quality.md) | PSScriptAnalyzer, gitleaks configuration |
| [🔗 GitLab CI/CD Integration](docs/gitlab.md) | REST API pipeline triggers, webhook configuration |

#### Physical Server Build & Runbooks
| Document | Description |
|---|---|
| [📋 Runbook Requirements](docs/runbook-requirements.md) | Operational runbook for physical HPE server builds via ConfigMgr + OneView + iLO Redfish |
| [📋 Runbook Changes](docs/runbook-changes.md) | Implementation plan and design decisions for the ConfigMgr bootable-media workflow |
| [📗 Automation Command Reference](docs/automation_commands.md) | Command-level reference for the physical server build functions |

#### Maintenance Mode & Scheduling
| Document | Description |
|---|---|
| [🔧 Quick Start Guide](docs/SETUP-GUIDE.md) | **NEW USERS** - Complete setup and first steps |
| [⚡ Maintenance Mode Shortcuts](docs/MAINTENANCE_MODE_SHORTCUTS.md) | `mm` command reference and examples |
| [🔧 Maintenance Mode Architecture](docs/maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp integration |
| [🔧 Maintenance Mode Environment Config](docs/maintenance-mode-environment-config.md) | Environment variable configuration |
| [🔧 Maintenance Mode Code Map](docs/Code_Map_Maitenance_Mode.md) | Complete code map with links to all mm command functionality |

#### Integration & Authentication
| Document | Description |
|---|---|
| [🔐 SCOM Authentication](docs/scom-auth.md) | SCOM authentication setup and configuration |
| [🔐 OneView Authentication](docs/oneview-auth.md) | HPE OneView authentication details |
| [🔐 Authentication Overview](docs/auth-doc.md) | General authentication documentation |
| [📊 Audit Process](docs/audit_process.md) | Audit trail and compliance process |
| [📊 GDPR Compliance](docs/gdpr_compliance.md) | GDPR compliance documentation |

#### Developer Resources
| Document | Description |
|---|---|
| [📖 DevOps Guide to HPE Terms](docs/devops-guide-to-HPe-Terms.md) | HPE terminology guide |

### In this document
- [HPE ProLiant Windows Server ISO Automation (Root Readme)](#hpe-proliant-windows-server-iso-automation-root-readme)
  - [🚀 Quick Start - Setup \& Installation](#-quick-start---setup--installation)
    - [TL;DR - One-Line Setup](#tldr---one-line-setup)
  - [Table of Contents](#table-of-contents)
    - [Internal docs index](#internal-docs-index)
      - [Core Documentation](#core-documentation)
      - [Physical Server Build & Runbooks](#physical-server-build--runbooks)
      - [Maintenance Mode \& Scheduling](#maintenance-mode--scheduling)
      - [Integration \& Authentication](#integration--authentication)
      - [Developer Resources](#developer-resources)
    - [In this document](#in-this-document)
  - [Project Architecture](#project-architecture)
  - [Generated Audit Logs (JSON)](#generated-audit-logs-json)
  - [Quick Links for Common Tasks](#quick-links-for-common-tasks)
  - [GitLab Pipeline Files](#gitlab-pipeline-files)
    - [Pipeline Activation](#pipeline-activation)
  - [Contributing](#contributing)
  - [Support](#support)
  - [License](#license)
  - [HPe Doc](#hpe-doc)

---

## Project Architecture

```
hpe-windows-iso-automation/
├── generated/                         # Generated output (gitignored)
│   ├── base_iso/                      # Base Windows ISOs (mounted in build)
│   │   └── Windows_Server_2022.iso    # Base ISO used by patching pipeline
│   ├── output/                        # Build artefacts
│   │   ├── combined/
│   │   ├── firmware/
│   │   └── patched/
│   ├── patched_iso/                   # Staging for patched Windows ISOs
│   ├── logs/                          # Audit trails and build reports
│   │   ├── audit/                     # Regulatory compliance & audit trails
│   │   ├── testing/                   # Test execution logs
│   │   ├── production/                # Operational and execution logs
│   │   └── build_reports/             # Build artefacts and output
│   └── coverage-results.xml             # Cobertura XML coverage report (see docs/testing.md)
├── configs/                           # Server/cluster/patch JSON configs
│   ├── server_list.txt                # Target servers (one per line)
│   ├── clusters_catalogue.json        # Cluster/SCOM/iLO definitions
│   ├── hpe_firmware_drivers_nov2025.json  # Firmware/driver manifests from HPE
│   ├── windows_patches.json           # Security patch specifications
│   ├── scom_config.json               # SCOM 2015 server and group config
│   ├── oneview_config.json           # HPE OneView integration settings
│   ├── email_distribution_lists.json  # SMTP and distribution list recipients
│   └── maintenance_distribution_list.txt  # Override email list for maintenance events
├── docker-compose.yml                 # Containerised build environment
├── Dockerfile                         # Docker image for build agents
├── docker-entrypoint.ps1              # PowerShell entrypoint
├── docs/                              # Full documentation set
│   └── (see Documentation Index above)
├── .gitlab-ci.yml                     # GitLab CI/CD pipeline (REST API triggers)
├── src/powershell/                    # PowerShell module
│   ├── Automation/                    # Module root
│   │   ├── Public/                    # Exported cmdlets
│   │   │   ├── Get-OneViewServerTarget.ps1
│   │   │   ├── Get-RouteMap.ps1
│   │   │   ├── Invoke-GitLabMaintenanceTrigger.ps1
│   │   │   ├── Invoke-IloRedfish.ps1
│   │   │   ├── Invoke-IsoDeploy.ps1
│   │   │   ├── Invoke-OpsRampClient.ps1
│   │   │   ├── Invoke-PowerShellScript.ps1
│   │   │   ├── Invoke-PowerShellWinRM.ps1
│   │   │   ├── New-IsoBuild.ps1
│   │   │   ├── New-OneViewMaintenanceScript.ps1
│   │   │   ├── New-ScomConnection.ps1
│   │   │   ├── New-ScomMaintenanceScript.ps1
│   │   │   ├── New-Uuid.ps1
│   │   │   ├── Publish-BootIso.ps1
│   │   │   ├── Set-MaintenanceMode.ps1
│   │   │   ├── Start-AutomationOrchestrator.ps1
│   │   │   ├── Start-InstallMonitor.ps1
│   │   │   ├── Start-PhysicalServerBuild.ps1
│   │   │   ├── Test-BuildParams.ps1
│   │   │   ├── Test-ClusterId.ps1
│   │   │   ├── Test-PostBuildValidation.ps1
│   │   │   ├── Test-PreBuildValidation.ps1
│   │   │   ├── Test-ServerConnectivity.ps1
│   │   │   ├── Test-ServerList.ps1
│   │   │   ├── Update-Firmware.ps1
│   │   │   ├── Update-WindowsSecurity.ps1
│   │   │   ├── Control.ps1
│   │   │   └── _Validate-Request.ps1
│   │   └── Private/                    # Internal helpers
│   │       ├── Audit.ps1
│   │       ├── Base.ps1
│   │       ├── Config.ps1
│   │       ├── Credentials.ps1
│   │       ├── Executor.ps1
│   │       ├── FileIO.ps1
│   │       ├── Inventory.ps1
│   │       ├── Logging.ps1
│   │       ├── PathResolver.ps1
│   │       ├── Router.ps1
│   │       └── Automation.psd1          # Module manifest
├── tests/powershell/                  # Pester v5 test suite
│   ├── Tests.Tests.ps1
│   ├── Config.Unit.Tests.ps1
│   ├── Credentials.Unit.Tests.ps1
│   ├── Executor.Unit.Tests.ps1
│   ├── FileIO.Unit.Tests.ps1
│   ├── Inventory.Unit.Tests.ps1
│   ├── Validators.Unit.Tests.ps1
│   ├── Router.Unit.Tests.ps1
│   ├── New-Uuid.Unit.Tests.ps1
│   ├── Audit.Unit.Tests.ps1
│   ├── Set-MaintenanceMode.Unit.Tests.ps1
│   ├── Set-MaintenanceMode.Enable.Tests.ps1
│   ├── Set-MaintenanceMode.Disable.Tests.ps1
│   ├── Set-MaintenanceMode.Validation.Tests.ps1
│   ├── Set-MaintenanceMode.Environment.Tests.ps1
│   ├── Invoke-IsoDeploy.Unit.Tests.ps1
│   ├── Invoke-OpsRampClient.Unit.Tests.ps1
│   ├── New-IsoBuild.Unit.Tests.ps1
│   ├── New-OneViewMaintenanceScript.Unit.Tests.ps1
│   ├── New-ScomConnection.Unit.Tests.ps1
│   ├── New-ScomMaintenanceScript.Unit.Tests.ps1
│   ├── Start-AutomationOrchestrator.Unit.Tests.ps1
│   ├── Start-InstallMonitor.Unit.Tests.ps1
│   ├── Test-ServerConnectivity.Tests.ps1
│   ├── Update-Firmware.Unit.Tests.ps1
│   ├── Update-WindowsSecurity.Unit.Tests.ps1
│   ├── Generate-PSDocs.Unit.Tests.ps1
│   ├── Makefile.Unit.Tests.ps1
│   ├── Pester.Integration.ps1
│   ├── Test-GitLabIntegration.ps1
│   └── Test-GitLabCallback.ps1
└── scripts/                            # CI runner provisioning and helpers
    ├── setup-runner.ps1
    └── test-connectivity.ps1
```

## Generated Audit Logs (JSON)

During both normal operations and unit testing (e.g. `make test`), you will notice a significant number of structured `.json` log files generated in the `generated/logs/` subdirectories (such as `generated/logs/testing/enable_UNIT-TEST-CLUSTER_...json`). 

These files are the definitive, machine-readable execution records generated by the `AuditLogger`. They are designed to be ingested programmatically by external monitoring and compliance systems (like OpsRamp and ServiceNow) to confirm state changes, durations, and metadata without parsing plain text logs.

**Important Note on Testing:** During test execution, these JSON logs are intentionally written to `generated/logs/testing/` to validate that the audit mechanics work end-to-end without polluting the production audit trails. **Do not change their filenames or suppress their generation** in the test runner, as doing so breaks the execution record structure required for GDPR compliance and external system integrations. A log pruning script (`scripts/prune-logs.ps1`) automatically manages retention to prevent these from bloating the repository.

---

## Quick Links for Common Tasks

| Task | Manual Command | Pipeline Stage |
|---|---|---|
| Run all tests locally | `pwsh -File scripts/run-tests.ps1` | Unit Tests |
| Run maintenance mode tests | `make maint-mode-tests` | Unit Tests |
| Generate test coverage | `make coverage` | Test |
| Test SCOM/OneView connectivity | `Test-ServerConnectivity -Mode scom -Environment Test` | Connectivity Check |
| Enable maintenance mode | `Set-MaintenanceMode -Action enable -TargetId CLUSTER -Mode scom -Environment Prod -Start now -End +2hours` | Maintenance Mode |
| Build physical server | `Start-PhysicalServerBuild -ServerIdentifier SERVER -OneViewHost ... -SiteCode P01 ... -DryRun` | Physical Server Build |
| Validate configuration | `pwsh -Command "Get-Content configs/clusters_catalogue.json \| ConvertFrom-Json"` | Setup |

---

## GitLab Pipeline Files

The GitLab CI pipeline lives in `.gitlab-ci.yml` at the repository root using PowerShell 7.4 containers.

### Pipeline Activation

The pipeline is currently **disabled** via a workflow rule to prevent execution on the development GitLab instance. Before deploying to the Bank's GitLab:

1. Remove the `workflow` block from `.gitlab-ci.yml`:

```yaml
    # Remove lines 9-13:
    # workflow:
    #   rules:
    #     - when: never
    ```

1. Ensure `MAINTENANCE_API_KEY` is configured as a masked variable in GitLab CI/CD settings
2. Verify all required secrets are configured in CyberArk for the bootstrap stage

---

## Contributing

All changes should include:
1. Unit tests mirroring the module structure in `tests/powershell/`
2. Documentation updated in `docs/`

---

## Support

- Create an issue or pull request in the repository
- Contact **Kev Everall**
- Reference build ID from `generated/logs/build_reports/` or `generated/logs/audit/maintenance_audit.log`

---

## License

MIT License — see `LICENSE` file for details.

## HPe Doc

[oneview-powershell-samples](https://github.com/HewlettPackard/oneview-powershell-samples/tree/master/Server%20Hardware/Creator-iLO)

[community.hpe.com](https://community.hpe.com/t5/hpe-oneview/bd-p/oneview)

[HPE OneView PowerShell Library](https://hpe-docs.gitbook.io/posh-hpeoneview)

[HPE OneView Support Centre links](https://support.hpe.com/connect/s/product?language=en_US&tab=manuals&kmpmoid=5410258&manualsAndGuidesFilter=66000015%2C66000035&manualsFilter=66000002%2C66000003%2C66000004%2C66000006%2C66000008%2C66000033)

[HPE OneView Powershell Library Guide and Versions](https://hpe-docs.gitbook.io/posh-hpeoneview)

[HPE OneView PS releases](https://github.com/HewlettPackard/POSH-HPEOneView/releases)