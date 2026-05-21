# HPE ProLiant Windows Server ISO Automation (Root Readme)

Automated build pipelines for creating customized Windows Server installation ISOs tailored for HPE ProLiant hardware. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

---

## Table of Contents

### Internal docs index
| Document | Description |
|---|---|
| [📚 Documentation Index](docs/README.md) | Complete documentation overview with repository structure, quick start, and full feature catalog |
| [🧪 Testing Guide](docs/python/testing.md) | Comprehensive unit testing & code coverage guide — manual pytest commands, Jenkins CI/CD integration, PR incremental testing (turbo-style), coverage report interpretation, and troubleshooting |
| [⚡ Testing Quick Start](docs/python/testing_quickstart.md) | Concise cheat sheet for running tests locally and in Jenkins, common commands, and quick troubleshooting reference |
| [🔍 Code Quality & Security](docs/python/code_quality.md) | Automated linting (ruff), complexity analysis (radon), security scanning (bandit, safety, gitleaks) embedded in Jenkins pipeline with configuration details |
| [🔧 Maintenance Mode](docs/maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables — language-agnostic |
| [🔧 Maintenance Mode — Python](docs/python/maintenance_mode.md) | Python script usage: CLI args, `clusters_catalogue.json`, `pip install`, and Python-specific troubleshooting |
| [🔧 Maintenance Mode — PowerShell](docs/src/powershell/maintenance_mode.md) | PowerShell cmdlet usage: `[CmdletBinding()]` params, module import, `pwsh.exe` auto-disable scheduling, PSScriptAnalyzer Jenkins snippet |
| [📦 Utilities Package](docs/python/utils.md) | Complete reference for the shared utilities package (`automation/utils/`) including logging, config, inventory, audit, executor, credentials, PowerShell, and base classes |
| [📋 Audit Process](docs/audit_process.md) | Detailed audit logging procedures, structured JSON records, master log format, retention policies, and GDPR-compliant data handling |
| [🛡️ GDPR Compliance](docs/gdpr_compliance.md) | GDPR-by-design implementation: data minimization, retention policies, encryption, residency, and user rights handling |
| [📡 Orchestrator & Routing](docs/api_reference.md) | Language-agnostic: request types, call sequence, adding new handlers, rotor and `ROUTE_MAP`/`$script:RouteMap`, return schemas for both Python `dict` and PowerShell `[hashtable]` |
| [📡 Orchestrator & Routing — Python](docs/python/api_reference.md) | `AutomationOrchestrator`, `validate_build_params()`, `validate_cluster_id()`, source paths, return dicts |
| [📡 Orchestrator & Routing — PowerShell](docs/powershell/api_reference.md) | `Start-AutomationOrchestrator`, `Invoke-RoutedRequest`, `$script:RouteMap`, `_Validate-Request`, source paths, return schemas |
| [🔌 PowerShell Generated Cmdlets](docs/powershell/generated/INDEX.md) | Auto-generated reference for all PowerShell cmdlets — `New-Uuid`, `Update-Firmware`, `Set-MaintenanceMode`, `Invoke-IsoDeploy`, etc. |
| [🔌 Python Generated CLI](docs/python/generated/INDEX.md) | Auto-generated reference for all Python CLI commands — `build-iso`, `deploy-server`, `maintenance-mode`, etc. |
| [🧪 PowerShell Testing (Pester)](docs/powershell/powershell_testing.md) | Pester v5 BDD testing guide — equivalent to pytest for the PowerShell module |
| [⚙️ PowerShell Testing Quick Start](docs/powershell/powershell_testing_quickstart.md) | Pester one-liners — install, run-all, run-one-file, tag filter, JUnit XML, smoke-test |

### In this document
- [HPE ProLiant Windows Server ISO Automation (Root Readme)](#hpe-proliant-windows-server-iso-automation-root-readme)
  - [Table of Contents](#table-of-contents)
    - [Internal docs index](#internal-docs-index)
    - [In this document](#in-this-document)
  - [Project Architecture](#project-architecture)
  - [Quick Links for Common Tasks](#quick-links-for-common-tasks)
  - [Jenkins Pipeline Files](#jenkins-pipeline-files)
    - [Pipeline Stages (both flavours)](#pipeline-stages-both-flavours)
  - [Makefile \& Local Development](#makefile--local-development)
    - [Quick Start](#quick-start)
    - [Virtual Environment](#virtual-environment)
    - [Makefile Command Reference](#makefile-command-reference)
    - [Makefile + Jenkinsfile Integration](#makefile--jenkinsfile-integration)
  - [CI Runner Setup](#ci-runner-setup)
    - [Supported Platforms](#supported-platforms)
    - [What It Installs](#what-it-installs)
    - [Usage](#usage)
    - [One-Liner for Remote Provisioning](#one-liner-for-remote-provisioning)
    - [Idempotency](#idempotency)
    - [Jenkinsfile Integration](#jenkinsfile-integration)
  - [SCOM 2015 Compliance](#scom-2015-compliance)
    - [Why Not REST?](#why-not-rest)
    - [How SCOM Integration Works](#how-scom-integration-works)
    - [Step 1: The HPE PowerShell Wrapper Scripts](#step-1-the-hpe-powershell-wrapper-scripts)
    - [Step 2: The Python SCOMManager Class](#step-2-the-python-scommanager-class)
    - [Step 3: Ensuring REST API Is Not Used for SCOM 2015](#step-3-ensuring-rest-api-is-not-used-for-scom-2015)
    - [Upgrade Path: SCOM 2025 with REST API](#upgrade-path-scom-2025-with-rest-api)
      - [Migration Complexity: **Low** (10–17 hours for REST, 30–45 hours with FastAPI/GraphQL)](#migration-complexity-low-1017-hours-for-rest-3045-hours-with-fastapigraphql)
      - [Phase 1: Add REST Backend (Opt-In)](#phase-1-add-rest-backend-opt-in)
      - [Phase 2-4: Progressive Rollout](#phase-2-4-progressive-rollout)
      - [API Options for SCOM 2025](#api-options-for-scom-2025)
      - [Benefits Comparison](#benefits-comparison)
  - [Contributing](#contributing)
  - [Support](#support)
  - [License](#license)

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
│   │   ├── audit_trail.log
│   │   ├── maintenance_audit.log
│   │   ├── maintenance_<action>_<cluster>_<ts>.json
│   │   └── build_reports/
│   └── htmlcov/                       # Coverage reports (make coverage-html)
├── configs/                           # Server/cluster/patch JSON configs
│   ├── server_list.txt                # Target servers (one per line)
│   ├── clusters_catalogue.json        # Cluster/SCOM/iLO definitions
│   ├── hpe_firmware_drivers_nov2025.json  # Firmware/driver manifests from HPE
│   ├── windows_patches.json           # Security patch specifications
│   ├── scom_config.json               # SCOM 2015 server and group config
│   ├── openview_config.json           # HPE OpenView integration settings
│   ├── email_distribution_lists.json  # SMTP and distribution list recipients
│   └── maintenance_distribution_list.txt  # Override email list for maintenance events
├── docker-compose.yml                 # Containerised build environment
├── Dockerfile                         # Docker image for build agents
├── docker-entrypoint.ps1              # Windows-container entrypoint
├── docs/                              # Full documentation set
│   └── (see Documentation Index above)
├── jenkins/                           # CI/CD pipeline definitions
│   ├── Jenkinsfile                    # ← PowerShell  pipeline (Windows agent)
│   └── Jenkinsfile.python             # ← Python pipeline (x86_64-linux agent)
├── src/powershell/                        # PowerShell module (target implementation)
│   ├── Automation/                    # Module root (mirrors src/python/automation/)
│   │   ├── Public/                    # Exported cmdlets
│   │   │   ├── New-Uuid.ps1
│   │   │   ├── New-IsoBuild.ps1
│   │   │   ├── Update-Firmware.ps1
│   │   │   ├── Update-WindowsSecurity.ps1
│   │   │   ├── Invoke-IsoDeploy.ps1
│   │   │   ├── Start-InstallMonitor.ps1
│   │   │   ├── Invoke-OpsRampClient.psm1
│   │   │   ├── Set-MaintenanceMode.ps1
│   │   │   ├── _Validate-Request.ps1
│   │   │   ├── Invoke-PowerShellScript.ps1
│   │   │   ├── Invoke-PowerShellWinRM.ps1
│   │   │   ├── Start-AutomationOrchestrator.ps1
│   │   │   ├── Test-BuildParams.ps1
│   │   │   ├── Test-ClusterId.ps1
│   │   │   ├── Test-ServerList.ps1
│   │   │   ├── New-ScomConnection.ps1
│   │   │   └── New-ScomMaintenanceScript.ps1
│   │   └── Private/                    # Internal helpers (mirrors src/python/automation/utils/)
│   │       ├── Config.psm1
│   │       ├── Credentials.psm1
│   │       ├── Executor.psm1
│   │       ├── FileIO.psm1
│   │       ├── Inventory.psm1
│   │       ├── Audit.psm1
│   │       ├── Logging.psm1
│   │       ├── Base.psm1
│   │       ├── Router.psm1
│   │       └── Automation.psd1         # Module manifest
│   └── Tests/                          # Pester v5 test suite  ←  mirrors tests/python/
│       ├── Tests.Tests.ps1
│       ├── Config.Unit.Tests.ps1
│       ├── Credentials.Unit.Tests.ps1
│       ├── Executor.Unit.Tests.ps1
│       ├── FileIO.Unit.Tests.ps1
│       ├── Inventory.Unit.Tests.ps1
│       ├── Validators.Unit.Tests.ps1
│       ├── Router.Unit.Tests.ps1
│       ├── New-Uuid.Unit.Tests.ps1
│       ├── Audit.Unit.Tests.ps1
│       └── Set-MaintenanceMode.Unit.Tests.ps1
├── scripts/                            # CI runner provisioning and helpers
│   └── setup-runner.sh
├── src/python/automation/                     # Python package (reference implementation)
│   ├── __init__.py
│   ├── cli/                             # CLI entry points
│   │   ├── build_iso.py
│   │   ├── update_firmware_drivers.py
│   │   ├── patch_windows_security.py
│   │   ├── deploy_to_server.py
│   │   ├── monitor_install.py
│   │   ├── opsramp_integration.py
│   │   ├── maintenance_mode.py
│   │   └── generate_uuid.py
│   ├── core/                            # Core orchestration and routing layer
│   │   ├── __init__.py
│   │   ├── orchestrator.py
│   │   ├── router.py
│   │   └── validators.py
│   └── utils/                           # Shared utilities
│       ├── __init__.py
│       ├── logging_setup.py
│       ├── config.py
│       ├── inventory.py
│       ├── audit.py
│       ├── file_io.py
│       ├── executor.py
│       ├── credentials.py
│       ├── powershell.py
│       └── base.py
├── tests/python/                              # Python / pytest tests  ←  mirrors tests/powershell/
│   ├── conftest.py
│   ├── cli/
│   ├── core/
│   └── utils/
├── tools/                              # External tools bundled or fetched at build time
│   ├── hpe_sut.exe
│   └── dism.exe
├── pyproject.toml                      # Package + pytest / ruff / mypy / bandit config
├── .ruff.toml                          # Ruff linter configuration
├── requirements.txt                    # Python runtime dependencies
└── uv.lock                             # Python lock file (uv)
```

## Quick Links for Common Tasks

| Task | Manual Command | Pipeline Stage |
|---|---|---|
| Run all tests locally | `pytest -v` | Unit Tests & Coverage |
| Generate coverage report | `pytest --cov=automation --cov-report=html` | Same (publishes `coverage.xml`) |
| Lint code | `ruff check src/python/automation/ --fix` | Code Quality & Security Scan |
| Build complete ISO pipeline | `python -m automation.cli.build_iso` | Generate UUIDs → Build Firmware → Build Windows → Combine |
| Enable maintenance mode | `python -m automation.cli.maintenance_mode --cluster-id CLUSTER --start now` | Maintenance Mode (manual) |
| Validate configuration | `python -c "import json; json.load(open('configs/clusters_catalogue.json'))"` | Setup stage (automated) |

---

## Jenkins Pipeline Files

Both pipelines live in **`jenkins/`** and are architecturally identical. They share the same parameters, stages, and environment. The only difference is the implementation language and agent label.

| File | Language | Agent | Script Path (job config) |
|---|---|---|---|
| `jenkins/Jenkinsfile` | **PowerShell** | `windows` | `jenkins/Jenkinsfile` |
| `jenkins/Jenkinsfile.python` | **Python** | `any` (Linux) | `jenkins/Jenkinsfile.python` |

Each file is self-contained — no references to the other language.

### Pipeline Stages (both flavours)

1. **Setup** — Install dependencies, validate config JSONs, create directory structure
2. **CyberArk Bootstrap** — Fetch secrets from vault; inject as process-scope env vars
3. **Code Quality & Security Scan** — PSScriptAnalyzer (PS) / ruff+pylint+bandit+safety (Python) + gitleaks
4. **Pester / pytest Unit Tests** — PS: `tests/powershell/` via Pester v5; Python: `tests/python/` via pytest
5. **Generate UUIDs** — Deterministic UUID per server (`New-Uuid` / `python -m automation.cli.generate_uuid`)
6. **Build Firmware ISOs** — HPE SUT integration; firmware-only ISOs
7. **Build Windows ISOs** — Security patching via DISM
8. **Combine Deployment Packages** — Merges firmware drivers into Windows ISOs
9. **OpsRamp Reporting** *(optional)* — API sync for monitoring/alerting
10. **Monitor Install** *(PS only)* — Real-time install tracking via `Start-InstallMonitor`
11. **Deploy to Server** *(manual/parameterized)* — iLO Virtual Media or Redfish push
12. **Vulnerability Scan** *(optional stub)* — Configure Nessus / OpenVAS per environment
13. **Audit & Reporting** — JSON summary + archive of all build result files

---

## Makefile & Local Development

This project includes a `Makefile` that wraps common development, testing, and CI/CD tasks into single commands. It uses `uv` under the hood for fast Python environment management.

### Quick Start

```bash
# 1. Create and activate the virtual environment
make setup
source .venv/bin/activate

# 2. Run tests
make test

# 3. Lint and format
make lint-fix
```

### Virtual Environment

The project uses `uv` (fast Python package manager) instead of pyenv or pip directly:

```bash
# Activate the venv (required before running any commands)
source .venv/bin/activate

# Verify Python version and package
python --version                    # Should show Python 3.12+
python -c "import automation; print(automation.__version__)"

# Deactivate when done
deactivate
```

### Makefile Command Reference

**Setup & Environment:**

| Command | Description |
|---|---|
| `make help` | List all available commands with descriptions |
| `make setup` | Create venv + install all runtime and dev dependencies |
| `make install` | Install automation package in editable mode (after setup) |
| `make deps` | Install runtime dependencies only |
| `make fresh` | Clean everything and rebuild from scratch |

**Testing:**

| Command | Description |
|---|---|
| `make test` | Run full test suite with coverage (generates `htmlcov/`, `coverage.xml`) |
| `make test-fast` | Run tests without coverage (faster feedback) |
| `make test-unit` | Run unit tests only (pytest `-m unit`) |
| `make test-integration` | Run integration tests only |
| `make coverage-html` | Generate interactive HTML coverage report → `htmlcov/index.html` |
| `make coverage-xml` | Generate Cobertura XML coverage report for CI |

**Linting & Quality:**

| Command | Description |
|---|---|
| `make lint` | Run ruff, mypy, radon complexity analysis |
| `make lint-fix` | Auto-fix ruff issues and format code |
| `make lint-test` | Check test file formatting and imports |
| `make format` | Format all Python files (src + tests) |

**Security:**

| Command | Description |
|---|---|
| `make security` | Run bandit, safety, and gitleaks scans |
| `make security-quick` | Run bandit only (fastest) |
| `make install-gitleaks` | Download and install gitleaks binary |

**Build & Package:**

| Command | Description |
|---|---|
| `make build` | Build distribution packages (`dist/`) |
| `make clean` | Remove build artifacts, cache, venv, and logs |

**CI/CD:**

| Command | Description |
|---|---|
| `make all` | Full pipeline: setup + lint + test + security |
| `make ci` | Run full CI pipeline locally (lint + test + security) |
| `make pr-check` | Quick pre-PR checks (lint + test only) |

**CLI Helpers:**

| Command | Description |
|---|---|
| `make run-build-iso` | Run build_iso CLI in dry-run mode |
| `make run-generate-uuid SERVER=server1` | Generate deterministic UUID for a server |
| `make run-maintenance CLUSTER=PROD-CLUSTER-01` | Enable SCOM maintenance mode for a cluster |

### Makefile + Jenkinsfile Integration

The `Makefile` simplifies Jenkins pipeline stages. Replace long shell blocks with:

```groovy
stage('Unit Tests & Coverage') {
    steps {
        sh '''
            source .venv/bin/activate
            make test
        '''
    }
}

stage('Code Quality') {
    steps {
        sh '''
            source .venv/bin/activate
            make lint
        '''
    }
}
```

---

## CI Runner Setup

The `scripts/setup-runner.sh` script automates provisioning of CI/CD runner environments. It installs Python 3.14 (via `uv`), all project dependencies, and required tooling in a single pass.

### Supported Platforms

| Platform | Status |
|---|---|
| Ubuntu 20.04 / 22.04 / 24.04 | ✅ Tested |
| Debian 11 / 12 | ✅ Tested |
| Amazon Linux 2 / 2023 | ✅ Tested |
| RHEL 8 / 9 / Rocky / AlmaLinux | ✅ Tested |
| Alpine Linux | ✅ Tested |

### What It Installs

| Component | Method | Purpose |
|---|---|---|
| **uv** | Official installer | Fast Python package manager (replaces pyenv) |
| **Python 3.14** | `uv python install` | Isolated Python version, no system conflicts |
| **Runtime deps** | `uv pip install -r requirements.txt` | All 11 runtime packages |
| **Dev deps** | `uv pip install ruff radon bandit safety mypy pytest` | Linting, security, testing tools |
| **Automation package** | `uv pip install -e .` | Editable install for live development |
| **gitleaks** | GitHub releases binary | Secret detection for CI pipeline |
| **System deps** | apt/yum/apk | Build tools, SSL, SQLite, FFI libs |

### Usage

```bash
# On a fresh runner/jumpbox:
git clone <repo-url>
cd hpe-windows-iso-automation
chmod +x scripts/setup-runner.sh
./scripts/setup-runner.sh

# Then activate the environment:
source .venv/bin/activate

# Verify everything works:
make pr-check
```

### One-Liner for Remote Provisioning

```bash
curl -sSL https://raw.githubusercontent.com/<org>/<repo>/main/scripts/setup-runner.sh | bash
```

### Idempotency

The script is safe to run multiple times:
- Skips `uv` installation if already present
- Skips Python install if version already installed via uv
- Skips venv creation if `.venv` exists with correct Python
- Skips gitleaks download if already in PATH

### Jenkinsfile Integration

```groovy
stage('Runner Setup') {
    steps {
        sh '''
            if [ ! -f ".venv/bin/python" ]; then
                chmod +x scripts/setup-runner.sh
                ./scripts/setup-runner.sh
            fi
            source .venv/bin/activate
        '''
    }
}
```

---

## SCOM 2015 Compliance

> **Important:** This repository is fully compatible with **System Center Operations Manager (SCOM) 2015**, which does **not** support REST API access. All SCOM interactions use PowerShell cmdlets via the `OperationsManager` module — the only officially supported automation method for SCOM 2015.

### Why Not REST?

SCOM 2015 provides **no REST API endpoint** for maintenance mode, alert management, or group operations. Attempting HTTP/REST calls against a SCOM 2015 server will fail. The SCOM 2022/2025 releases introduced limited REST endpoints, but for SCOM 2015 environments, **PowerShell is mandatory**.

### How SCOM Integration Works

The implementation uses a clean **Python → PowerShell bridge** pattern that dynamically generates HPE-compatible PowerShell scripts at runtime:

```
Python orchestrator (maintenance_mode.py)
    │
    ├── SCOMManager class
    │   │
    │   ├── Local execution:  run_powershell()        → subprocess.run(["powershell", "-Command", ...])
    │   └── Remote execution: run_powershell_winrm()  → pywinrm.Session().run_ps()
    │
    └── PowerShell scripts (generated dynamically at runtime via f-strings)
        ├── Import-Module OperationsManager -ErrorAction Stop
        ├── New-SCOMManagementGroupConnection -ComputerName "<server>" -ErrorAction Stop
        ├── Get-SCOMGroup -DisplayName "<group>" -ErrorAction Stop
        ├── Get-SCOMClassInstance -Group $group
        ├── Start-SCOMMaintenanceMode -Instance $inst -Duration $duration -Comment $comment
        └── Stop-SCOMMaintenanceMode -Instance $inst -ErrorAction Stop
```

### Step 1: The HPE PowerShell Wrapper Scripts

All SCOM automation is built on the **HPE OperationsManager PowerShell module**, which ships with SCOM 2015. The module provides cmdlets for every maintenance mode operation. Our Python code generates PowerShell scripts dynamically using f-strings, injecting parameters like group names, durations, and comments at runtime.

**Local Execution** ([`src/python/automation/utils/powershell.py`](src/python/automation/utils/powershell.py)):

```python
def run_powershell(script: str, capture_output: bool = True, timeout: int = 300):
    """Execute a PowerShell script locally on the Windows agent."""
    cmd = [
        "powershell",
        "-ExecutionPolicy", "Bypass",
        "-NoProfile",
        "-NonInteractive",
        "-Command", script
    ]
    result = subprocess.run(cmd, capture_output=capture_output, text=True, timeout=timeout)
    return (result.returncode == 0, result.stdout + result.stderr)
```

This runs `powershell.exe -Command "<generated script>"` directly on the Windows Jenkins agent. The agent must have the SCOM 2015 OperationsManager PowerShell module installed and the executing user must have SCOM admin rights.

**Remote Execution via WinRM** ([`src/python/automation/utils/powershell.py`](src/python/automation/utils/powershell.py)):

```python
def run_powershell_winrm(script, server, username, password, transport="ntlm", timeout=300):
    """Execute PowerShell script on SCOM management server via WinRM (port 5985/5986)."""
    import winrm
    session = winrm.Session(server, auth=(username, password), transport=transport)
    result = session.run_ps(script)
    return (result.status_code == 0, (result.std_out + result.std_err).decode())
```

This connects to the SCOM management server via Windows Remote Management (WinRM) — a SOAP-based protocol over HTTP/HTTPS, **not REST**. WinRM is the standard remote management protocol for Windows Server 2012 R2/2016, which SCOM 2015 runs on.

**Note:** WinRM uses SOAP over HTTP(S) on ports 5985 (HTTP) or 5986 (HTTPS). This is **not** the SCOM REST API — it is the Windows remote execution channel used to run PowerShell on a remote server.

### Step 2: The Python SCOMManager Class

The `SCOMManager` class ([`src/python/automation/cli/maintenance_mode.py`](src/python/automation/cli/maintenance_mode.py)) encapsulates all SCOM 2015 operations and generates the PowerShell scripts dynamically:

```python
class SCOMManager:
    """Manages SCOM 2015 maintenance mode via PowerShell cmdlets."""

    def __init__(self, config: dict):
        self.mgmt_server = config.get("management_server", "localhost")
        self.module_name = config.get("powershell_module", "OperationsManager")
        self.use_winrm = config.get("use_winrm", False)

    def _run_ps(self, script: str):
        """Execute PowerShell locally or via WinRM based on config."""
        if self.use_winrm:
            return run_powershell_winrm(script, self.mgmt_server, ...)
        return run_powershell(script)

    def enter_maintenance(self, group_display_name, duration, comment, dry_run=False):
        """Place all computers in the SCOM group into maintenance mode."""
        total_seconds = int(duration.total_seconds())
        safe_comment = comment.replace("'", "''")  # Escape for PowerShell
        script = f"""
Import-Module {self.module_name} -ErrorAction Stop
$conn = New-SCOMManagementGroupConnection -ComputerName "{self.mgmt_server}" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "{group_display_name}" -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
$duration = New-TimeSpan -Seconds {total_seconds}
$comment = '{safe_comment}'
foreach ($inst in $instances) {{
    Start-SCOMMaintenanceMode -Instance $inst -Duration $duration -Comment $comment -ErrorAction Stop
}}
"""
        return self._run_ps(script)
```

Key design decisions:

- **Dynamic script generation**: PowerShell code is generated at runtime using Python f-strings, making it easy to inject parameters and handle edge cases
- **Error handling**: Each cmdlet uses `-ErrorAction Stop` so failures propagate as non-zero exit codes
- **Dry-run support**: `dry_run=True` skips execution and logs intended actions
- **Credential separation**: SCOM admin credentials are read from environment variables (`SCOM_ADMIN_USER`, `SCOM_ADMIN_PASSWORD`) via the credentials utility
- **Module flexibility**: The `OperationsManager` module name is configurable, allowing future updates to target different SCOM versions

### Step 3: Ensuring REST API Is Not Used for SCOM 2015

We take explicit steps to guarantee SCOM operations never attempt REST calls:

| Safeguard | Detail |
|---|---|
| **No `requests` import in SCOM code** | `src/python/automation/cli/maintenance_mode.py` only imports `requests` inside `ILOManager` and `OpenViewClient` methods — **never** in `SCOMManager` |
| **No `urllib`/`httplib` imports** | The `powershell.py` helper imports only `subprocess` and `winrm` — zero HTTP libraries |
| **All SCOM calls route through `_run_ps()`** | Every SCOM operation calls `self._run_ps(script)` which dispatches to either `run_powershell()` (subprocess) or `run_powershell_winrm()` (pywinrm) — both are non-REST |
| **WinRM uses SOAP, not REST** | `pywinrm.Session` communicates via SOAP envelope over HTTP/HTTPS — this is the Windows remote management protocol, not a SCOM REST API |
| **Code review enforcement** | CI pipeline includes `bandit` security scanning and `ruff` lint checks; any new `import requests` in SCOM files would be flagged |
| **Test isolation** | Unit tests for `SCOMManager` mock `run_powershell` — confirming the expected execution path is PowerShell, not HTTP |

**Where REST IS used (separate from SCOM):**

| Component | API Type | Endpoint |
|---|---|---|
| **iLO** | REST (iLO 4+) | `https://<ilo_ip>/rest/v1/maintenancewindows` |
| **OpenView** | REST (custom) | Configurable `base_url/api_version/endpoint` |
| **OpsRamp** | REST | `https://<tenant>.opsramp.com/api/v2/...` |

These are completely independent services with separate classes and credential stores.

### Upgrade Path: SCOM 2025 with REST API

When SCOM 2025 becomes available with native REST API support, migration is **simple and low-risk** because the architecture cleanly separates execution backends.

#### Migration Complexity: **Low** (10–17 hours for REST, 30–45 hours with FastAPI/GraphQL)

The `SCOMManager` class uses a single private method `_run_ps(script)` for all execution. Adding a REST backend means:

1. Add an `api_mode` config option (`powershell` or `rest`)
2. Implement `_enter_maintenance_rest()` method alongside the existing `_enter_maintenance_powershell()`
3. Add a simple conditional in `enter_maintenance()` to choose the backend
4. Write unit tests for the REST path (mock `requests.Session`)

**No breaking changes** to existing deployments — PowerShell mode remains the default.

#### Phase 1: Add REST Backend (Opt-In)

```python
class SCOMManager:
    def __init__(self, config: dict):
        self.mode = config.get('api_mode', 'powershell')  # 'powershell' or 'rest'
        if self.mode == 'rest':
            self.base_url = config['api_url']  # https://scom2025/api/v1
            self.session = requests.Session()
            self.session.headers.update({'Authorization': f'Bearer {config["api_token"]}'})

    def enter_maintenance(self, group_name, duration, comment, dry_run=False):
        if self.mode == 'rest':
            return self._enter_maintenance_rest(group_name, duration, comment)
        return self._enter_maintenance_powershell(group_name, duration, comment)

    def _enter_maintenance_rest(self, group_name, duration, comment):
        """SCOM 2025 REST API endpoint."""
        payload = {
            "group": group_name,
            "duration": int(duration.total_seconds()),
            "comment": comment,
            "reason": "PlannedMaintenance"
        }
        resp = self.session.post(f"{self.base_url}/maintenance", json=payload)
        return (resp.status_code == 200, resp.json())
```

#### Phase 2-4: Progressive Rollout

| Phase | Action | Risk Level |
|---|---|---|
| **1** | Add REST backend as opt-in (`api_mode: 'rest'` in config) | **Zero** — existing deployments unchanged |
| **2** | Dual-run: execute both backends, compare results | **Low** — instant fallback to PowerShell |
| **3** | Switch default to REST for SCOM 2025 servers only | **Medium** — requires validation testing |
| **4** | Deprecate PowerShell mode entirely | **Low** — only after Phase 3 is proven stable |

#### API Options for SCOM 2025

| Approach | Complexity | Best For |
|---|---|---|
| **`requests` + SCOM REST** | **Simple** (4-6h) | Quick migration, minimal code changes, synchronous workflows |
| **FastAPI wrapper service** | **Medium** (8-12h) | Async support, auto-generated OpenAPI docs, type validation, team collaboration |
| **GraphQL (Ariadne/Strawberry)** | **Medium-Complex** (12-16h) | Complex querying needs, single endpoint for multiple operations, flexible field selection |

#### Benefits Comparison

| Benefit | PowerShell Mode (Current) | REST Mode (Future) |
|---|---|---|
| **Speed** | ~2-5s per call (process spawn overhead) | ~100-300ms (HTTP keep-alive) |
| **Concurrency** | Sequential (subprocess locks) | Parallel (async requests, connection pooling) |
| **Error Handling** | Parse stdout/stderr text | Structured JSON responses, HTTP status codes |
| **Monitoring** | Limited (log file only) | Prometheus metrics, OpenTelemetry tracing |
| **Testing** | Requires PowerShell environment | Mockable HTTP, contract testing with OpenAPI |
| **Cross-Platform** | Windows-only | Any platform with Python (Linux agents, containers) |
| **CI/CD** | Jenkins Windows agents only | Any CI/CD system, Kubernetes, serverless |
| **Authentication** | Windows account / WinRM credentials | OAuth2, API tokens, mTLS |

## Contributing

All changes should include:

1. **Unit tests** mirroring the module structure in `tests/python/`
2. **Documentation** updated in `docs/`
3. **Linting** passing: `ruff check src/ tests/python/ --fix`
4. **Coverage** maintained or improved: `pytest --cov=automation --cov-report=term-missing`
5. **PR description** linking relevant documentation updates

See [Code Quality](docs/python/code_quality.md) for scanning details.

---

## Support

- Create an issue or pull request in the repository
- Contact **Kev Everall**
- Reference build ID from `logs/build_reports/` or `logs/maintenance_audit.log`
- For Jenkins issues: check agent logs and console output
- For testing questions: see [Testing Guide](docs/python/testing.md)

---

## License

MIT License — see `LICENSE` file for details.
