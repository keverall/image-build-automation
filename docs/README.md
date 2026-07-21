# HPE ProLiant Windows Server ISO Automation - Documentation Index

<a id="top"></a>
## Table of Contents

- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Document Index](#document-index)
  - [Core Documentation](#core-documentation)
  - [Physical Server Build & Runbooks](#physical-server-build-and-runbooks)
  - [Maintenance Mode & Scheduling](#maintenance-mode-and-scheduling)
  - [Integration & Authentication](#integration-and-authentication)
  - [Developer Resources](#developer-resources)
- [Contributing](#contributing)
Complete documentation for the PowerShell automation module (`src/powershell/Automation/`).

---

<a name="repository-structure"></a>
## Repository Structure

```
hpe-windows-iso-automation/
├── .gitlab-ci.yml                              # GitLab CI pipeline
├── src/powershell/Automation                        # PowerShell module
│   ├── Public/                                   # Exported cmdlets
│   ├── Private/                                  # Internal helpers
│   └── Automation.psd1                           # Module manifest
├── tests/powershell/                             # PowerShell / Pester tests
├── configs/                                     # Server/cluster/patch JSON configs
├── docs/                                        # This directory
└── generated/logs/                            # Audit trails & build reports
```

---

<a name="quick-start"></a>
## Quick Start

- **PowerShell** module import and first command: see [powershell_api_reference.md](Generic/powershell_api_reference.md#quick-start)
- **Configuration files reference:** see [configs/README.md](../configs/README.md#top)
- **Running tests:** see [testing.md](Generic/testing.md#top)
- **CI integration:** see [powershell_ci.md](Generic/powershell_ci.md#top)

---

<a name="document-index"></a>
## Document Index

<a name="core-documentation"></a>
### Core Documentation

| Document | Description |
|---|---|
| [PowerShell API Reference](Generic/powershell_api_reference.md#top) | Module overview, requirements, quick-start, cmdlet usage, orchestrator API |
| [Automation Command Reference](Automation/automation_commands.md#top) | Concise functional reference with every parameter for all automation commands |
| [📘 Auto-Generated Function Reference](dynamic-code-docs/INDEX.md#top) | **Comprehensive coverage of ALL PowerShell functions and cmdlets** - complete parameter documentation, examples, and usage for every function in the codebase. Auto-generated from source code. |
| [Testing Guide](Generic/testing.md#top) | Comprehensive Pester v5 guide, runner commands, mocking, CI integration, maintenance mode testing |
| [CI Run Requirements](Generic/powershell_ci.md#top) | Prerequisites, CyberArk bootstrap, CI examples for GitLab/Jenkins |
| [Code Quality & Security](Generic/code_quality.md#top) | PSScriptAnalyzer, gitleaks - configuration, usage, CI pipeline integration |
| [GitLab CI/CD Integration](Generic/gitlab.md#top) | REST API pipeline triggers, webhook configuration, polling |

<a name="physical-server-build-and-runbooks"></a>
### Physical Server Build & Runbooks

| Document | Description |
|---|---|
| [Runbook Requirements](Automation/runbook-requirements.md#top) | Operational runbook for automating physical HPE server builds with ConfigMgr + OneView + iLO Redfish |
| [Runbook Changes](Automation/runbook-changes.md#top) | Implementation plan and design decisions for the ConfigMgr bootable-media workflow |
| [Automation Command Reference](Automation/automation_commands.md#top) | Command-level reference for the physical server build functions |
| [PowerShell API Reference](Generic/powershell_api_reference.md#top) | Orchestrator and workflow overview for the physical server build |

<a name="maintenance-mode-and-scheduling"></a>
### Maintenance Mode & Scheduling

| Document | Description |
|---|---|
| [Maintenance Mode Architecture](Maintenance-Mode/maintenance_mode.md#top) | Architecture, scheduling, audit, OpsRamp, environment variables |
| [Maintenance Mode Environment Config](Maintenance-Mode/maintenance-mode-environment-config.md#top) | Environment variable configuration for maintenance mode |
| [Maintenance Mode Code Map](Maintenance-Mode/Code_Map_Maitenance_Mode.md#top) | Complete code map with links to all mm command functionality |

<a name="integration-and-authentication"></a>
### Integration & Authentication

| Document | Description |
|---|---|
| [SCOM Authentication](Generic/scom-auth.md#top) | SCOM authentication setup and configuration |
| [OneView Authentication](Generic/oneview-auth.md#top) | HPE OneView authentication details |
| [OneView Module Versions](Generic/oneview-module-versions.md#top) | HPE OneView PowerShell module version compatibility table |
| [Authentication Overview](Generic/auth-doc.md#top) | General authentication documentation |
| [Audit Process](Generic/audit_process.md#top) | Audit trail and compliance process |
| [GDPR Compliance](Generic/gdpr_compliance.md#top) | GDPR compliance documentation |

<a name="developer-resources"></a>
### Developer Resources

| Document | Description |
|---|---|
| [DevOps Guide to HPE Terms](devops-guide-to-HPe-Terms.md#top) | HPE terminology guide for DevOps engineers |
| [Checkmake Integration](Generic/CHECKMAKE_INTEGRATION.md#top) | Makefile validation with checkmake |

---

<a name="contributing"></a>
## Contributing

1. Add or update unit tests mirroring the module structure in `tests/powershell/`
2. Update the relevant doc page in `docs/`
3. Run linting: `pwsh -Command "Invoke-ScriptAnalyzer -Path src/powershell -Recurse"`
4. Ensure Pester passes: `pwsh -File scripts/run-tests.ps1`
5. PR description must link to any documentation changes



