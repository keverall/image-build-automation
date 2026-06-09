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
- **Running tests:** see [testing.md](testing.md)
- **CI integration:** see [powershell_ci.md](powershell_ci.md)

---

## Document Index

### PowerShell Module

| Document | Description |
|---|---|
| [PowerShell API Reference](powershell_api_reference.md) | Module overview, requirements, quick-start, cmdlet usage, orchestrator API |
| [Auto-Generated Cmdlet Reference](dynamic-code-docs/INDEX.md) | Generated documentation for all PowerShell functions with parameters and examples |
| [CI Run Requirements](powershell_ci.md) | Prerequisites, CyberArk bootstrap, CI examples for GitLab/Jenkins |
| [Testing Guide](testing.md) | Full Pester v5 guide, runner commands, mocking, CI integration, maint-mode-tests |
| [Code Quality & Security](code_quality.md) | PSScriptAnalyzer, gitleaks — configuration, usage, CI pipeline integration |
| [Maintenance Mode](maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables |
| [GitLab CI/CD Integration](gitlab.md) | REST API pipeline triggers, webhook configuration, polling |

---

## Contributing

1. Add or update unit tests mirroring the module structure in `tests/powershell/`
2. Update the relevant doc page in `docs/`
3. Run linting: `pwsh -Command "Invoke-ScriptAnalyzer -Path src/powershell -Recurse"`
4. Ensure Pester passes: `pwsh -File scripts/run-tests.ps1`
5. PR description must link to any documentation changes