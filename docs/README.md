# HPE ProLiant Windows Server ISO Automation

Automated build pipelines for creating customized Windows Server installation ISOs tailored for HPE ProLiant hardware. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

## Repository Structure

```
hpe-windows-iso-automation/
├── Jenkinsfile                                  # CI/CD pipeline definition
├── scripts/
│   ├── generate_uuid.py                        # Generates deterministic UUIDs
│   ├── update_firmware_drivers.py              # HPE SUT firmware/driver integration
│   ├── patch_windows_security.py               # DISM-based Windows patching
│   ├── build_iso.py                            # Main orchestrator
│   ├── deploy_to_server.py                     # ISO deployment (PXE/iLO)
│   ├── monitor_install.py                      # Installation monitoring
│   ├── opsramp_integration.py                  # OpsRamp API integration
│   ├── maintenance_mode.py                     # SCOM/iLO/OpenView maintenance orchestration
│   └── utils/                                  # Shared utilities package (DRY)
│       ├── __init__.py                         # Package exports
│       ├── logging_setup.py                    # Centralized logging configuration
│       ├── config.py                           # JSON config loading with env var substitution
│       ├── inventory.py                        # Cluster catalogue and server inventory loading
│       ├── audit.py                            # Structured audit logging (JSON)
│       ├── file_io.py                          # Directory creation, JSON persistence
│       ├── executor.py                         # Subprocess wrapper with retry logic
│       ├── credentials.py                      # Credential retrieval from environment
│       ├── powershell.py                       # PowerShell execution (local + WinRM)
│       └── base.py                             # AutomationBase common class
├── configs/
│   ├── server_list.txt                         # Target servers (one per line)
│   ├── clusters_catalogue.json                 # Cluster definitions (SCOM groups, iLO IPs, schedules)
│   ├── hpe_firmware_drivers_nov2025.json       # Firmware/driver manifests
│   ├── windows_patches.json                    # Security patch specifications
│   ├── scom_config.json                        # SCOM 2015 connection details
│   ├── openview_config.json                    # HPE OpenView integration settings
│   ├── email_distribution_lists.json           # SMTP and distribution lists for notifications
│   ├── opsramp_config.json                     # OpsRamp API configuration
│   └── maintenance_distribution_list.txt       # Override email list for maintenance events (optional)
├── tools/
│   ├── hpe_sut.exe                             # HPE Smart Update Tool (external)
│   └── dism.exe                                # Windows DISM (system tool)
├── logs/
│   ├── audit_trail.log                         # Comprehensive audit logging
│   ├── maintenance_audit.log                   # Maintenance-specific audit (line-delimited JSON)
│   ├── maintenance_<action>_<cluster>_<ts>.json # Per-action maintenance records
│   └── build_reports/                          # Daily build reports
├── docs/
│   ├── README.md                               # This file
│   ├── maintenance_mode.md                     # Maintenance orchestration guide
│   ├── audit_process.md                        # Detailed audit procedures
│   ├── gdpr_compliance.md                      # GDPR compliance documentation
│   └── utils.md                                # Shared utilities package reference (NEW)
├── Dockerfile                                  # Containerized build environment
├── requirements.txt                            # Python dependencies
├── .python-version                             # Pinned Python version (3.9+ recommended)
├── pyproject.toml                              # Project metadata and tool config (ruff, radon)
├── .ruff.toml                                  # Ruff linter configuration
└── Jenkinsfile                                 # CI/CD pipeline definition
```

## Prerequisites

- **Access to HPE repositories** for November 2025 firmware and driver updates
- **Windows Server 2022/2025 base ISO** (evaluation or licensed)
- **OpsRamp account** with API access for monitoring and alerting
- **CI/CD runner** with Windows Server support (Jenkins with self-hosted agents, GitLab CI, or Azure DevOps)
- **Tools**:
  - Python 3.9+ (all platforms). On Windows Server 2016, install backport: `pip install python -m pip install "backports.zoneinfo[tzdata]"`
  - HPE Smart Update Tool (SUT) for firmware/driver integration
  - Windows DISM (Deployment Image Servicing and Management)
  - Packer (optional, for advanced ISO builds)
  - Nessus or OpenVAS (for vulnerability scanning)
  - Git for version control
- **SCOM 2015** (optional): OperationsManager PowerShell module installed if maintenance_mode.py is used

## Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd hpe-windows-iso-automation
```

### 2. Configure Environment
```bash
# Copy example configurations (if provided)
cp configs/opsramp_config.json.example configs/opsramp_config.json

# Edit configuration files
# configs/server_list.txt - one server per line (e.g., server1.example.com)
# configs/clusters_catalogue.json - define clusters, SCOM groups, iLO IPs, schedules
# configs/hpe_firmware_drivers_nov2025.json - set HPE repo credentials
# configs/windows_patches.json - adjust patch list as needed
# configs/scom_config.json - SCOM management server settings
# configs/openview_config.json - HPE OpenView API/CLI details (optional)
# configs/email_distribution_lists.json - SMTP and email recipients
```

### 3. Set Environment Variables
```bash
export HPE_DOWNLOAD_USER="your_hpe_username"
export HPE_DOWNLOAD_PASS="your_hpe_password"
export ILO_USER="Administrator"
export ILO_PASSWORD="your_ilo_password"
export OPSRAMP_CLIENT_ID="your_client_id"
export OPSRAMP_CLIENT_SECRET="your_client_secret"
# Optional: SCOM, OpenView, SMTP credentials as needed
```

### 4. Install Dependencies
```bash
pip install -r requirements.txt
```

### 5. Manual Build (Single Server)
```bash
# Generate UUID
python scripts/generate_uuid.py server1.example.com --output output/server1.uuid

# Build firmware/driver ISO
python scripts/update_firmware_drivers.py --server server1.example.com

# Build patched Windows ISO (requires base Windows ISO)
python scripts/patch_windows_security.py \
  --base-iso /path/to/Windows_Server_2022.iso \
  --server server1.example.com

# Or use orchestrator for complete build
python scripts/build_iso.py \
  --base-iso /path/to/Windows_Server_2022.iso \
  --server server1.example.com

# Deploy to server (via iLO)
python scripts/deploy_to_server.py --server server1.example.com --method ilo

# Monitor installation
python scripts/monitor_install.py --server server1.example.com --timeout 7200
```

### 6. Build for All Servers
```bash
# Complete pipeline for all servers in server_list.txt
python scripts/build_iso.py --base-iso /isos/Windows_Server_2022.iso

# With dry-run to test without making changes
python scripts/build_iso.py --base-iso /isos/Windows_Server_2022.iso --dry-run
```

### 7. Maintenance Mode (SCOM/iLO/OpenView)
```bash
# Enable maintenance for a cluster
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --start now

# Validate cluster configuration
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --action validate

# Disable maintenance manually (scheduled task auto-disables at end time)
python scripts/maintenance_mode.py --cluster-id PROD-CLUSTER-01 --disable
```

## Code Quality & DRY Architecture

This project follows **DRY (Don't Repeat Yourself)** principles through a shared utilities package:

- `scripts/utils/` — Common functionality extracted from all automation scripts:
  - **logging_setup** — Centralized logging with console + file handlers
  - **config** — `load_json_config()` with environment variable substitution for secrets
  - **inventory** — `load_server_list()`, `load_cluster_catalogue()`, `ServerInfo` dataclass
  - **audit** — `AuditLogger` class for structured JSON audit trails + master log append
  - **file_io** — `ensure_dir()`, `save_json()` helpers
  - **executor** — `run_command()` wrapper with `run_with_retry()` for flaky operations
  - **credentials** — `get_ilo_credentials()`, `get_scom_credentials()`, generic `get_credential()`
  - **powershell** — `run_powershell()`, `run_powershell_winrm()`, SCOM script builders
  - **base** — `AutomationBase` class for common initialization, config loading, server loading, result saving

All main scripts (`build_iso.py`, `update_firmware_drivers.py`, `patch_windows_security.py`, `deploy_to_server.py`, `monitor_install.py`, `opsramp_integration.py`, `maintenance_mode.py`) inherit from or import utilities, eliminating code duplication and ensuring consistent behavior.

### Linting & Formatting

```bash
# Fast linting with auto-fix
ruff check scripts/ --fix

# Format code
ruff format scripts/

# Complexity analysis
radon mi scripts/ -s        # maintainability index (A–F)
radon cc scripts/ -nc       # cyclomatic complexity (warn >10)

# Type checking (optional)
mypy scripts/ --ignore-missing-imports
```

### Pre-commit (optional)

```bash
pre-commit install
pre-commit run --all-files
```

## Development

### Adding New Features

1. **Prefer utils first**: Check if functionality fits existing utils module before writing new code
2. Create/modify scripts in `scripts/` directory
3. Update unit tests (if present)
4. Update documentation (`docs/`)
5. Run linting: `ruff check scripts/ --fix`
6. Run complexity check: `radon cc scripts/ -nc` (functions >10 require refactoring)
7. Test in development environment before PR

### Code Style

- PEP 8 compliance enforced via `ruff`
- Comprehensive docstrings (Google-style) for all public functions, classes, methods
- Type hints on all function signatures
- Centralized logging via `logging` module (never `print`)
- Result dictionaries standardized: `{"success": bool, "details": str, ...}`
- Exit codes: 0 for success, non-zero for failures

### Testing

```bash
# Run a single test script
python scripts/generate_uuid.py test-server

# Dry run entire pipeline
python scripts/build_iso.py --dry-run --server test-server

# Validate all configurations
python scripts/maintenance_mode.py --cluster-id TEST --action validate

# Check configuration syntax
python -c "import json; json.load(open('configs/clusters_catalogue.json'))"
```

## Security Considerations

- **Credentials**: Store in environment variables or CI/CD secret stores (Jenkins Credentials, GitLab CI Variables). Never commit to repository.
- **Network Access**: HPE repositories, OpsRamp API require outbound HTTPS. Whitelist IPs in firewalls if needed.
- **iLO Access**: Use dedicated service account with minimum required privileges. Rotate credentials regularly.
- **ISO Storage**: Protect ISOs containing embedded credentials or sensitive metadata.
- **Audit**: All actions are logged. Review `logs/audit_trail.log` and `logs/maintenance_audit.log` regularly.
- **SCOM**: Run under account with least privileges needed for maintenance mode operations.

## Compliance

- Follow HPE licensing terms for Smart Update Tool and firmware/driver downloads
- Microsoft Windows licensing applies to ISO creation and distribution
- Adhere to organizational change management procedures for production deployments
- **GDPR Compliance:** This repository implements GDPR-by-design principles. See [GDPR Compliance](./gdpr_compliance.md) for full details. Key measures:
  - No personal data processed (server hostnames are technical identifiers)
  - Data minimization: logs stored with 30-day retention, encrypted at rest
  - Docker image uses non-root user, no secrets in layers
  - All data residency maintained within EEA

## Support

For issues, questions, or feature requests:
- Create a pull request or issue in the repository (Bitbucket Server/GitStash)
- Contact platform engineering team
- Reference build ID from `logs/build_reports/` or `logs/maintenance_audit.log`
- For Jenkins pipeline issues: Check Jenkins console output and agent logs
- For maintenance mode issues: See [Maintenance Mode](./maintenance_mode.md) troubleshooting section

## License

MIT License - See LICENSE file for details.

## Contributors

- Platform Engineering Team
- Infrastructure Automation Group

## Changelog

### 2026-05-15 — DRY Refactor & Maintenance Mode
- Added `scripts/utils/` package (9 modules) to eliminate code duplication across all automation scripts
- Refactored all main scripts to use shared utilities (logging, config, audit, executor, credentials, PowerShell)
- Fixed import errors and unused code across `opsramp_integration.py`, `patch_windows_security.py`, `utils/file_io.py`, `utils/inventory.py`
- Implemented `maintenance_mode.py` orchestrator for SCOM 2015, HPE iLO, and OpenView with scheduled auto-disable
- Integrated OpsRamp metrics and alerts for maintenance mode transitions
- Added comprehensive audit logging with JSON per-action records and master log
- Migrated linting from `pylint` to `ruff` (faster, auto-fixable)
- Updated documentation to reflect DRY architecture and new configuration files
