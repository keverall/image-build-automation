# HPE ProLiant Windows Server ISO Automation

Automated build pipelines for creating customized Windows Server installation ISOs tailored for HPE ProLiant hardware. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

---

## Table of Contents

| Document | Description |
|---|---|
| [📚 Documentation Index](docs/README.md) | Complete documentation overview with repository structure, quick start, and full feature catalog |
| [🧪 Testing Guide](docs/testing.md) | Comprehensive unit testing & code coverage guide — manual pytest commands, Jenkins CI/CD integration, PR incremental testing (turbo-style), coverage report interpretation, and troubleshooting |
| [⚡ Testing Quick Start](docs/TESTING_QUICKSTART.md) | Concise cheat sheet for running tests locally and in Jenkins, common commands, and quick troubleshooting reference |
| [🔍 Code Quality & Security](docs/code_quality.md) | Automated linting (ruff), complexity analysis (radon), security scanning (bandit, safety, gitleaks) embedded in Jenkins pipeline with configuration details |
| [🔧 Maintenance Mode](docs/maintenance_mode.md) | SCOM/iLO/OpenView maintenance orchestration guide — usage, scheduling, SCOM manager integration, and best practices |
| [📦 Utilities Package](docs/utils.md) | Complete reference for the shared utilities package (`automation/utils/`) including logging, config, inventory, audit, executor, credentials, PowerShell, and base classes |
| [📋 Audit Process](docs/audit_process.md) | Detailed audit logging procedures, structured JSON records, master log format, retention policies, and GDPR-compliant data handling |
| [🛡️ GDPR Compliance](docs/gdpr_compliance.md) | GDPR-by-design implementation: data minimization, retention policies, encryption, residency, and user rights handling |

---

## Project Architecture

```
src/automation/
├── cli/                    # CLI entry points
│   ├── build_iso.py       # Main orchestrator (combines firmware + Windows patches)
│   ├── update_firmware_drivers.py  # HPE SUT integration
│   ├── patch_windows_security.py   # DISM-based patching
│   ├── deploy_to_server.py         # iLO virtual media deployment
│   ├── monitor_install.py          # Installation progress monitoring
│   ├── opsramp_integration.py      # OpsRamp API integration
│   ├── maintenance_mode.py         # SCOM/iLO/OpenView orchestration
│   └── generate_uuid.py            # Deterministic UUID generation
└── utils/                 # Shared utilities (DRY)
    ├── logging_setup.py   # Centralized logging configuration
    ├── config.py          # JSON loader + env var substitution
    ├── inventory.py       # Server/cluster loading
    ├── audit.py           # Structured audit logging
    ├── file_io.py         # Directory & JSON helpers
    ├── executor.py        # Subprocess wrapper with retry
    ├── credentials.py     # Environment-based credential retrieval
    ├── powershell.py      # Local + WinRM PowerShell execution
    └── base.py            # AutomationBase common class
```

All CLI scripts import from `utils/` to avoid duplication. See [Utilities Package Reference](docs/utils.md) for full module details.

---

## Quick Links for Common Tasks

| Task | Manual Command | Pipeline Stage |
|---|---|---|
| Run all tests locally | `pytest -v` | Unit Tests & Coverage |
| Generate coverage report | `pytest --cov=automation --cov-report=html` | Same (publishes `coverage.xml`) |
| Lint code | `ruff check src/automation/ --fix` | Code Quality & Security Scan |
| Build complete ISO pipeline | `python -m automation.cli.build_iso` | Generate UUIDs → Build Firmware → Build Windows → Combine |
| Enable maintenance mode | `python -m automation.cli.maintenance_mode --cluster-id CLUSTER --start now` | Maintenance Mode (manual) |
| Validate configuration | `python -c "import json; json.load(open('configs/clusters_catalogue.json'))"` | Setup stage (automated) |

---

## Jenkins Pipeline Stages

1. **Setup** — Install dependencies, validate config JSONs, create directory structure
2. **Code Quality & Security Scan** — ruff lint, pylint, radon CC/MI, bandit, safety, gitleaks
3. **Unit Tests & Coverage** *(new)* — pytest with incremental testing on PRs
4. **Generate UUIDs** — Deterministic UUID for each server (required for later stages)
5. **Build Firmware ISOs** — HPE SUT integration; produces firmware-only ISOs
6. **Build Windows ISOs** — Security patching via DISM
7. **Combine Deployment Packages** — Merges firmware drivers into Windows ISOs
8. **OpsRamp Integration** *(optional)* — API sync for monitoring/alerting
9. **Maintenance Mode** *(optional)* — SCOM/iLO/OpenView orchestration
10. **Deploy to Server** *(manual/parameterized)* — iLO Virtual Media or Redfish push
11. **Monitor Install** *(manual/parameterized)* — Real-time installation tracking

See [Testing Guide](docs/testing.md) for details on PR incremental test execution.

---

## Contributing

All changes should include:

1. **Unit tests** mirroring the module structure in `tests/`
2. **Documentation** updated in `docs/`
3. **Linting** passing: `ruff check src/ tests/ --fix`
4. **Coverage** maintained or improved: `pytest --cov=automation --cov-report=term-missing`
5. **PR description** linking relevant documentation updates

See [Code Quality](docs/code_quality.md) for scanning details.

---

## Support

- Create an issue or pull request in the repository
- Contact **Kev Everall**
- Reference build ID from `logs/build_reports/` or `logs/maintenance_audit.log`
- For Jenkins issues: check agent logs and console output
- For testing questions: see [Testing Guide](docs/testing.md)

---

## License

MIT License — see `LICENSE` file for details.
