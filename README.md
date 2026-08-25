# HPE ProLiant Windows Server ISO Automation (Root Readme)

<a id="top"></a>

## Table of Contents

- [Summary](#summary)
- [🚀 Quick Start - Setup & Installation](#quick-start-setup-installation)
  - [TL;DR - One-Line Setup](#tldr-one-line-setup)
  - [Internal docs index](#internal-docs-index)
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

<a id="summary"></a>

## Summary

Automated build pipelines for creating customized Windows Server installation ISOs and for orchestrating physical HPE ProLiant server deployments using Microsoft Configuration Manager bootable media, HPE OneView, and HPE iLO Redfish. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

---

<a id="quick-start-setup-installation"></a>

## 🚀 Quick Start - Setup & Installation

**New to this project?** Start here:

1. **[📖 Setup Guide](docs/SETUP-GUIDE.md#top)** - Complete setup instructions for PowerShell profile and maintenance mode
2. **[🔧 Quick Client Setup](docs/Maintenance-Mode/MAINTENANCE_MODE_SHORTCUTS.md#top)** - 5-minute setup for using maintenance mode commands

<a id="tldr-one-line-setup"></a>

### TL;DR - One-Line Setup

```powershell
make setup && . $PROFILE
```

Then use:

```powershell
# 1. Connect to OneView and establish a persistent session
Connect-OneView -ManagementHost oneview.example.com -Environment Prod

# 2. Run OneView commands while the session is active
#    Get-OneViewServerList shows, per server: MaintMode (Yes/No), lifecycle State,
#    State Reason, Health, Power, iLO IP, ROM, and Model (HPE model code, last column).
Get-OneViewServerList
Get-OneViewConnectionStatus

# 3. Disconnect from OneView when finished
Disconnect-OneView

# 4. Enable maintenance mode
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

> **Tip — short parameter aliases:** the OneView commands accept short aliases so they are faster to type. For example: `Get-OneViewConnectionStatus -SrvrId MXQ1234567 -IdTyp Serial` is equivalent to `Get-OneViewConnectionStatus -ServerIdentifier MXQ1234567 -IdentifierType Serial`. The long and short forms are interchangeable (see the [Automation Command Reference](docs/Automation/automation_commands.md#top) for the full alias table).

```powershell

# 5. Disable maintenance mode
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

---

<a id="internal-docs-index"></a>

### Internal docs index

#### Core Documentation

| Document | Description |
|---|---|
| [📚 Documentation Index](docs/README.md#top) | Complete documentation overview |
| [🚀 Setup Guide](docs/SETUP-GUIDE.md#top) | **START HERE** - Profile setup, module installation, quick start |
| [📡 PowerShell API Reference](docs/Generic/powershell_api_reference.md#top) | Module overview, cmdlet usage, orchestrator API |
| [📗 Automation Command Reference](docs/Automation/automation_commands.md#top) | **All automation commands with full parameter tables** - functional reference linking to source |
| [📘 PowerShell Function Reference](docs/dynamic-code-docs/INDEX.md#top) | **Complete coverage of ALL PowerShell functions and cmdlets** - comprehensive parameter documentation, examples, and usage for every function in src/powershell/Automation/. Auto-generated from source code. |
| [🔌 CI Run Requirements](docs/Generic/powershell_ci.md#top) | Prerequisites, CyberArk bootstrap, GitLab/Jenkins examples |
| [🧪 PowerShell Testing (Pester)](docs/Generic/testing.md#top) | Pester v6 BDD testing guide, test commands, mocking |
| [⚙️ Code Quality & Security](docs/Generic/code_quality.md#top) | PSScriptAnalyzer, gitleaks configuration |
| [🔗 GitLab CI/CD Integration](docs/Generic/gitlab.md#top) | REST API pipeline triggers, webhook configuration |

#### Physical Server Build & Runbooks

| Document | Description |
|---|---|
| [📋 Runbook Requirements](docs/Automation/runbook-requirements.md#top) | Operational runbook for physical HPE server builds via ConfigMgr + OneView + iLO Redfish |
| [📋 Runbook Changes](docs/Automation/runbook-changes.md#top) | Implementation plan and design decisions for the ConfigMgr bootable-media workflow |
| [📗 Automation Command Reference](docs/Automation/automation_commands.md#top) | Command-level reference for the physical server build functions |

#### Maintenance Mode & Scheduling

| Document | Description |
|---|---|
| [🔧 Quick Start Guide](docs/SETUP-GUIDE.md#top) | **NEW USERS** - Complete setup and first steps |
| [⚡ Maintenance Mode Shortcuts](docs/Maintenance-Mode/MAINTENANCE_MODE_SHORTCUTS.md#top) | `mm` command reference and examples |
| [🔧 Maintenance Mode Architecture](docs/Maintenance-Mode/maintenance_mode.md#top) | Architecture, scheduling, audit, OpsRamp integration |
| [🔧 Maintenance Mode Environment Config](docs/Maintenance-Mode/maintenance-mode-environment-config.md#top) | Environment variable configuration |
| [🔧 Maintenance Mode Code Map](docs/Maintenance-Mode/Code_Map_Maitenance_Mode.md#top) | Complete code map with links to all mm command functionality |

#### Integration & Authentication

| Document | Description |
|---|---|
| [🔐 SCOM Authentication](docs/Generic/scom-auth.md#top) | SCOM authentication setup and configuration |
| [🔐 OneView Authentication](docs/Generic/oneview-auth.md#top) | HPE OneView authentication details |
| [🔐 Authentication Overview](docs/Generic/auth-doc.md#top) | General authentication documentation |
| [📊 Audit Process](docs/Generic/audit_process.md#top) | Audit trail and compliance process |
| [📊 GDPR Compliance](docs/Generic/gdpr_compliance.md#top) | GDPR compliance documentation |

#### Developer Resources

| Document | Description |
|---|---|
| [📖 DevOps Guide to HPE Terms](docs/devops-guide-to-HPe-Terms.md#top) | HPE terminology guide |

<a id="in-this-document"></a>

### In this document

- [HPE ProLiant Windows Server ISO Automation (Root Readme)](#hpe-proliant-windows-server-iso-automation-root-readme)
  - [Table of Contents](#table-of-contents)
  - [Summary](#summary)
  - [🚀 Quick Start - Setup \& Installation](#-quick-start---setup--installation)
    - [TL;DR - One-Line Setup](#tldr---one-line-setup)
    - [Internal docs index](#internal-docs-index)
      - [Core Documentation](#core-documentation)
      - [Physical Server Build \& Runbooks](#physical-server-build--runbooks)
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

<a id="project-architecture"></a>

## Project Architecture

```
image-build-automation/
├── bin/                               # Bundled binaries (checkmake, make, oh-my-posh)
├── configs/                           # Server/cluster/patch JSON configs
├── docs/                              # Documentation (see Documentation Index above)
├── generated/                         # Generated output (gitignored)
│   └── logs/                          # Audit trails and build reports
├── scripts/                           # CI runner provisioning and helpers
├── src/powershell/Automation/         # PowerShell module
│   ├── Public/                        # Exported cmdlets (30+)
│   ├── Private/                       # Internal helpers (12 modules)
│   └── Automation.psd1                # Module manifest
├── tests/powershell/                  # Pester v6 test suite (47 test files)
├── vendor/                            # Vendored PowerShell modules
├── .gitlab-ci.yml                     # GitLab CI/CD pipeline
├── docker-compose.yml                 # Containerised build environment
├── Dockerfile                         # Docker image for build agents
├── Makefile                           # Build automation targets
└── README.md                          # This file
```

<a id="generated-audit-logs-json"></a>

## Generated Audit Logs (JSON)

During both normal operations and unit testing (e.g. `make test`), you will notice a significant number of structured `.json` log files generated in the `generated/logs/` subdirectories (such as `generated/logs/testing/enable_UNIT-TEST-CLUSTER_...json`). 

These files are the definitive, machine-readable execution records generated by the `AuditLogger`. They are designed to be ingested programmatically by external monitoring and compliance systems (like OpsRamp and ServiceNow) to confirm state changes, durations, and metadata without parsing plain text logs.

**Important Note on Testing:** During test execution, these JSON logs are intentionally written to `generated/logs/testing/` to validate that the audit mechanics work end-to-end without polluting the production audit trails. **Do not change their filenames or suppress their generation** in the test runner, as doing so breaks the execution record structure required for GDPR compliance and external system integrations. A log pruning script (`scripts/prune-logs.ps1`) automatically manages retention to prevent these from bloating the repository.

---

<a id="quick-links-for-common-tasks"></a>

## Quick Links for Common Tasks

| Task | Manual Command | Pipeline Stage |
|---|---|---|
| Run all tests locally | `pwsh -File scripts/run-tests.ps1` | Unit Tests |
| Run maintenance mode tests | `make maint-mode-tests` | Unit Tests |
| Generate test coverage | `make coverage` | Test |
| Test OneView connectivity | `Connect-OneView -ManagementHost oneview-appliance` <br> *(or `Test-ServerConnectivity` for diagnostics)* | Connectivity Check |
| Disconnect from OneView | `Disconnect-OneView` | Session Cleanup |
| Enable maintenance mode | `Set-MaintenanceMode -Action enable -TargetId CLUSTER -Mode scom -Environment Prod -Start now -End +2hours` | Maintenance Mode |
| Build physical server | `Start-PhysicalServerBuild -ServerIdentifier SERVER -OneViewHost ... -SiteCode P01 ... -DryRun` | Physical Server Build |
| Validate configuration | `pwsh -Command "Get-Content configs/clusters_catalogue.json \| ConvertFrom-Json"` | Setup |

---

<a id="gitlab-pipeline-files"></a>

## GitLab Pipeline Files

The GitLab CI pipeline lives in `.gitlab-ci.yml` at the repository root using PowerShell 7.4 containers.

<a id="pipeline-activation"></a>

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

<a id="contributing"></a>

## Contributing

All changes should include:
1. Unit tests mirroring the module structure in `tests/powershell/`
2. Documentation updated in `docs/`

---

<a id="support"></a>

## Support

- Create an issue or pull request in the repository
- Contact **Kev Everall**
- Reference build ID from `generated/logs/build_reports/` or `generated/logs/audit/maintenance_audit.log`

---

<a id="license"></a>

## License

MIT License - see `LICENSE` file for details.

<a id="hpe-doc"></a>

## HPe Doc

[oneview-powershell-samples](https://github.com/HewlettPackard/oneview-powershell-samples/tree/master/Server%20Hardware/Creator-iLO)

[community.hpe.com](https://community.hpe.com/t5/hpe-oneview/bd-p/oneview)

[HPE OneView PowerShell Library](https://hpe-docs.gitbook.io/posh-hpeoneview)

[HPE OneView Support Centre links](https://support.hpe.com/connect/s/product?language=en_US&tab=manuals&kmpmoid=5410258&manualsAndGuidesFilter=66000015%2C66000035&manualsFilter=66000002%2C66000003%2C66000004%2C66000006%2C66000008%2C66000033)

[HPE OneView Powershell Library Guide and Versions](https://hpe-docs.gitbook.io/posh-hpeoneview)

[HPE OneView PS releases](https://github.com/HewlettPackard/POSH-HPEOneView/releases)
