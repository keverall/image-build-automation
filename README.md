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

**Local Execution** ([`src/automation/utils/powershell.py`](src/automation/utils/powershell.py)):

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

**Remote Execution via WinRM** ([`src/automation/utils/powershell.py`](src/automation/utils/powershell.py)):

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

The `SCOMManager` class ([`src/automation/cli/maintenance_mode.py`](src/automation/cli/maintenance_mode.py)) encapsulates all SCOM 2015 operations and generates the PowerShell scripts dynamically:

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
| **No `requests` import in SCOM code** | `src/automation/cli/maintenance_mode.py` only imports `requests` inside `ILOManager` and `OpenViewClient` methods — **never** in `SCOMManager` |
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
