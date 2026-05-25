# HPE ProLiant Windows Server ISO Automation — Documentation Index (Docs Root Readme)

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
└── logs/                                        # Audit trails & build reports
```

---

## Quick Start

- **PowerShell** module import and first command: see [powershell/powershell_api_reference.md](powershell/powershell_api_reference.md#quick-start)

---

## Document Index

### PowerShell

| Document | Description |
|---|---|
| [PowerShell API Reference — Generic](api_reference.md) | Orchestrator & routing layer — request types, flow, adding new handlers, return schema |
| [PowerShell API Reference](powershell/api_reference.md) | Orchestrator & routing layer — PS-specific types, return schemas, `$script:RouteMap`, `_Validate-Request` |
| [GitLab REST API Reference](api/gitlab.md) | Pipeline trigger architecture, REST endpoint, `trigger/pipeline` payload, callbacks, polling, cluster config, network/firewall notes |
| [PowerShell Module Overview](powershell_api_reference.md) | Module overview, directory layout, requirements, quick-start |
| [PowerShell Generated Cmdlets](powershell/generated/INDEX.md) | Auto-generated reference for all PowerShell cmdlets — `New-Uuid`, `Update-Firmware`, `Set-MaintenanceMode`, `Invoke-IsoDeploy`, `Invoke-OpsRampClient`, `Start-AutomationOrchestrator`, etc. |
| [PowerShell Testing Guide](powershell/powershell_testing.md) | Full Pester v5 guide — runner commands, BDD keywords, mocking, CI integration, writing new tests, troubleshooting |
| [PowerShell Testing Quick Start](powershell/powershell_testing_quickstart.md) | Pester one-liners — install, run-all, run-one-file, tag filter, JUnit XML, module export smoke-test |
| [PowerShell Code Quality & Security](powershell/code_quality.md) | PSScriptAnalyzer, gitleaks — configuration, usage, GitLab CI pipeline integration |
| [Maintenance Mode](maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables |
| [Maintenance Mode — PowerShell](powershell/maintenance_mode.md) | PowerShell usage: CmdletBinding params, module import, `pwsh.exe` integration |

---

## Contributing

1. Add or update unit tests mirroring the module structure in `tests/powershell/`
2. Update the relevant doc page in `docs/powershell/`
3. Run linting: `pwsh -Command "Invoke-ScriptAnalyzer -Path src/powershell -Recurse"`
4. Ensure Pester passes: `pwsh -Command "Invoke-Pester"`
5. PR description must link to any documentation changes