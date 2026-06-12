# HPE ProLiant Windows Server ISO Automation — Documentation Index

Complete documentation for the PowerShell automation module (`src/powershell/Automation/`).

---

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

## Quick Start

- **PowerShell** module import and first command: see [powershell_api_reference.md](powershell_api_reference.md#quick-start)
- **Configuration files reference:** see [configs/README.md](../configs/README.md)
- **Running tests:** see [testing.md](testing.md)
- **CI integration:** see [powershell_ci.md](powershell_ci.md)

---

## Document Index

### Core Documentation

| Document | Description |
|---|---|
| [PowerShell API Reference](powershell_api_reference.md) | Module overview, requirements, quick-start, cmdlet usage, orchestrator API |
| [Auto-Generated Cmdlet Reference](dynamic-code-docs/INDEX.md) | Generated documentation for all PowerShell functions with parameters and examples |
| [Testing Guide](testing.md) | Full Pester v5 guide, runner commands, mocking, CI integration, maint-mode-tests |
| [CI Run Requirements](powershell_ci.md) | Prerequisites, CyberArk bootstrap, CI examples for GitLab/Jenkins |
| [Code Quality & Security](code_quality.md) | PSScriptAnalyzer, gitleaks — configuration, usage, CI pipeline integration |
| [GitLab CI/CD Integration](gitlab.md) | REST API pipeline triggers, webhook configuration, polling |

### Maintenance Mode & Scheduling

| Document | Description |
|---|---|
| [Maintenance Mode Architecture](maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables |
| [Maintenance Mode Environment Config](maintenance-mode-environment-config.md) | Environment variable configuration for maintenance mode |
| [Set-MaintenanceMode Help](SET-MAINTENANCEMODE-HELP.md) | Detailed help for Set-MaintenanceMode cmdlet |
| [Maintenance Mode Testing Guide](MAINTENANCE_MODE_TESTING.md) | Comprehensive testing guide for maintenance mode |
| [Maintenance Mode Initial Testing](maint-mode-initial-testing.md) | Initial testing notes and validation |

### Integration & Authentication

| Document | Description |
|---|---|
| [SCOM Authentication](scom-auth.md) | SCOM authentication setup and configuration |
| [OneView Authentication](oneview-auth.md) | HPE OneView authentication details |
| [Authentication Overview](auth-doc.md) | General authentication documentation |
| [Audit Process](audit_process.md) | Audit trail and compliance process |
| [GDPR Compliance](gdpr_compliance.md) | GDPR compliance documentation |

### Developer Resources

| Document | Description |
|---|---|
| [Quick Reference](QUICK_REFERENCE.md) | Quick reference guide for common tasks |
| [Help System](HELP_SYSTEM.md) | Documentation for the built-in help system |
| [Testing Quick Start](TESTING_QUICK_START.md) | Quick start guide for testing |
| [Test Implementation Complete](TEST_IMPLEMENTATION_COMPLETE.md) | Test implementation status and summary |
| [DevOps Guide to HPE Terms](devops-guide-to-HPe-Terms.md) | HPE terminology guide for DevOps engineers |

---

## Contributing

1. Add or update unit tests mirroring the module structure in `tests/powershell/`
2. Update the relevant doc page in `docs/`
3. Run linting: `pwsh -Command "Invoke-ScriptAnalyzer -Path src/powershell -Recurse"`
4. Ensure Pester passes: `pwsh -File scripts/run-tests.ps1`
5. PR description must link to any documentation changes