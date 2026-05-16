# HPE ProLiant Windows Server ISO Automation — Documentation Index

Complete documentation for the Python automation package (`src/automation/`) and
PowerShell module (`powershell/Automation/`).

---

## Repository Structure

```
hpe-windows-iso-automation/
├── Jenkinsfile                                  # CI/CD pipeline definition
├── src/automation/                              # Python package
│   ├── cli/                                     # CLI entry points
│   └── utils/                                   # Shared utilities
├── powershell/Automation/                       # PowerShell module
│   ├── Public/                                  # Exported cmdlets
│   ├── Private/                                 # Internal helpers
│   └── Automation.psd1                          # Module manifest
├── tests/                                       # Python / pytest tests
├── powershell/Tests/                            # PowerShell / Pester tests
├── configs/                                     # Server/cluster/patch JSON configs
├── docs/                                        # This directory
└── logs/                                        # Audit trails & build reports
```

---

## Quick Start

- **Python** package setup and first build: see the [top-level README](../README.md#quick-start)
- **PowerShell** module import and first command: see [powershell/powershell_api_reference.md](../powershell/powershell_api_reference.md#quick-start)

---

## Document Index

### Python

| Document | Description |
|---|---|
| [Testing Guide](python/testing.md) | Comprehensive pytest / coverage / CI guide — commands, fixtures, PR incremental testing, coverage reports, troubleshooting |
| [Testing Quick Start](python/testing_quickstart.md) | Cheat sheet for manual pytest runs and Jenkins, common commands, quick-reference table |
| [Code Quality & Security](python/code_quality.md) | ruff, pylint, radon, bandit, safety, gitleaks — configuration, usage, Jenkins pipeline integration |
| [Maintenance Mode](maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables, security — language-agnostic |
| [Maintenance Mode — Python](python/maintenance_mode.md) | Python usage: CLI args, config, `clusters_catalogue.json`, `pip install`, troubleshooting |
| [Maintenance Mode — PowerShell](powershell/maintenance_mode.md) | PowerShell usage: CmdletBinding params, module import, `pwsh.exe` integration, Jenkins PSScriptAnalyzer |
| [Python Utilities](python/utils.md) | Full reference for all modules in `src/automation/utils/` — logging, config, inventory, audit, executor, credentials, PowerShell bridge, base class |

### PowerShell

| Document | Description |
|---|---|
| [PowerShell API Reference — Generic](../api_reference.md) | Orchestrator & routing layer — request types, flow, adding new handlers, return schema |
| [PowerShell API Reference](powershell/api_reference.md) | Orchestrator & routing layer — PS-specific types, return schemas, `$script:RouteMap`, `_Validate-Request` |
| [PowerShell Module Overview](powershell/powershell_api_reference.md) | Module overview, directory layout, requirements, design mapping to Python, quick-start |
| [PowerShell Testing Guide](powershell/powershell_testing.md) | Full Pester v5 guide — runner commands, BDD keywords, shared infrastructure, mocking, CI integration, writing new tests, troubleshooting |
| [PowerShell Testing Quick Start](powershell/powershell_testing_quickstart.md) | Pester one-liners — install, run-all, run-one-file, tag filter, JUnit XML, module export smoke-test |
| [PowerShell Code Quality & Security](powershell/code_quality.md) | PSScriptAnalyzer, gitleaks — configuration, usage, Jenkins pipeline integration, quality gates, comparison with Python tools |
| [PowerShell Jenkins Run Requirements](powershell/powershell_jenkins_run_requirements.md) | Requirements and feasibility for running the PowerShell module in a separate Jenkins `windows` stage — feature parity, SCOM/iLO viability, open items |

---

## Python vs PowerShell Feature Parity

| Feature | Python (`src/automation/`) | PowerShell (`powershell/Automation/`) |
|---|---|---|
| Unit tests | `tests/` · pytest (254 tests) | `powershell/Tests/` · Pester (11 × `*.Tests.ps1`) |
| Test runner | `pytest` | `Invoke-Pester` |
| CI pipeline | Jenkins `Unit Tests & Coverage` stage (only Python) | **No Pester stage yet** — target: add to Jenkinsfile |
| Fakes / mocking | `unittest.mock` | `Mock` keyword (Pester) |
| Coverage | `pytest-cov` → `coverage.xml`, `htmlcov/` | Not yet automated |
| Shared fixture / setup | `tests/conftest.py` | `powershell/Tests/Tests.Tests.ps1` (`BeforeAll`) |

---

## Contributing

1. Add or update unit tests mirroring the module structure (Python → `tests/`, PowerShell → `powershell/Tests/`)
2. Update the relevant doc page in `python/` or `powershell/`
3. Run linting: `ruff check src/automation/ --fix` and `Invoke-ScriptAnalyzer -Path powershell\Automation -Recurse`
4. Ensure pytest / Pester passes: `pytest` (Python) and/or `Invoke-Pester` (PowerShell)
5. PR description must link to any documentation changes

See [Python Code Quality](python/code_quality.md) / [PowerShell Code Quality](powershell/code_quality.md) for full lint/scan details.
