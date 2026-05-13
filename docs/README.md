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
│   └── opsramp_integration.py                  # OpsRamp API integration
├── configs/
│   ├── server_list.txt                         # Target servers (one per line)
│   ├── hpe_firmware_drivers_nov2025.json       # Firmware/driver manifests
│   ├── windows_patches.json                    # Security patch specifications
│   └── opsramp_config.json                     # OpsRamp API configuration
├── tools/
│   ├── hpe_sut.exe                             # HPE Smart Update Tool (external)
│   └── dism.exe                                # Windows DISM (system tool)
├── logs/
│   ├── audit_trail.log                         # Comprehensive audit logging
│   └── build_reports/                          # Daily build reports
├── docs/
│   ├── README.md                               # This file
│   ├── audit_process.md                        # Detailed audit procedures
│   └── gdpr_compliance.md                      # GDPR compliance documentation
├── Dockerfile                                  # Containerized build environment
└── requirements.txt                            # Python dependencies
```

## Prerequisites

- **Access to HPE repositories** for November 2025 firmware and driver updates
- **Windows Server 2022/2025 base ISO** (evaluation or licensed)
- **OpsRamp account** with API access for monitoring and alerting
- **CI/CD runner** with Windows Server support (Jenkins with self-hosted agents, GitLab CI, or Azure DevOps)
- **Tools**:
  - Python 3.9+ (all platforms)
  - HPE Smart Update Tool (SUT) for firmware/driver integration
  - Windows DISM (Deployment Image Servicing and Management)
  - Packer (optional, for advanced ISO builds)
  - Nessus or OpenVAS (for vulnerability scanning)
  - Git for version control

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
# configs/hpe_firmware_drivers_nov2025.json - set HPE repo credentials
# configs/windows_patches.json - adjust patch list as needed
# configs/opsramp_config.json - set OpsRamp API credentials
```

### 3. Set Environment Variables
```bash
export HPE_DOWNLOAD_USER="your_hpe_username"
export HPE_DOWNLOAD_PASS="your_hpe_password"
export ILO_USER="Administrator"
export ILO_PASSWORD="your_ilo_password"
export OPSRAMP_CLIENT_ID="your_client_id"
export OPSRAMP_CLIENT_SECRET="your_client_secret"
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

### 7. CI/CD Pipelines
Enable GitHub Actions workflows:
- Push to `main` or `develop` triggers automated builds
- Scheduled daily builds at 2 AM (firmware) and 4 AM (Windows)
- Manual triggering via GitHub UI with custom inputs

## Key Features

### Firmware/Driver ISO Builds
- Uses **HPE Smart Update Tool (SUT)** to create bootable ISO with November 2025 firmware and drivers
- Supports HPE Gen10 and Gen10 Plus ProLiant servers
- Downloads latest components from HPE repositories
- Generates unique deterministic UUID per server: `hash(server_name + timestamp)[:32]`
- Creates combined firmware/driver media for offline deployment

### Windows Security Patching
- Applies November 2025 security updates to base Windows Server ISO
- Uses **DISM** (Deployment Image Servicing and Management) for offline servicing
- Mounts base ISO, applies MSU patches, creates new patched ISO
- Supports Windows Server 2022 and 2025
- Patch metadata includes CVE IDs, severity, KB numbers for tracking

### Automated Deployment
- **iLO Virtual Media**: Mount ISOs via HPE iLO REST API
- **PXE Boot**: Configure network boot with iPXE/UNDI
- **Redfish API**: Modern HPE iLO 5+ REST-based deployment
- Unattended installation with embedded computer name and UUID

### Installation Monitoring
- Real-time progress tracking via:
  - **iLO**: Power state, boot source, health sensors
  - **WinRM/PowerShell**: Windows Setup registry and event logs
  - **SNMP** (optional): Hardware event traps
- Progress phases: Not Started → Initializing → Copying Files → Installing Features → Configuring → Complete
- Sends metrics to OpsRamp for dashboards

### Vulnerability Scanning
- Integrated scanning at multiple stages:
  - Base ISO scan (before customization)
  - Patched ISO scan (after security updates)
  - Post-install server scan (via network)
- Uses Nessus CLI or OpenVAS for scanning
- Reports CVEs with remediation steps
- Fail builds on critical vulnerabilities

### Audit Trail & Reporting
- Comprehensive logging in `logs/audit_trail.log`
- Per-server JSON build logs in `output/results/`
- Daily audit reports in `logs/build_reports/`
- Git commits for each successful build (with [skip ci])
- Structured logs for OpsRamp integration

### OpsRamp Integration
- Sends metrics: build status, deployment progress, installation % elapsed time
- Alerts for failures: build errors, patch failures, scan findings
- Events for build completion, deployment status changes
- Dashboards: real-time visibility into pipeline health

## Configuration

### Server List (`configs/server_list.txt`)
```
# Format: hostname or hostname,ipmi_ip,ilo_ip
server1.example.com,192.168.1.101,192.168.1.201
server2.example.com,192.168.1.102,192.168.1.202
```

### HPE Firmware Config (`configs/hpe_firmware_drivers_nov2025.json`)
```json
{
  "firmware_drivers_version": "November 2025",
  "hpe_repository_url": "https://downloads.hpe.com/repo/nov2025/",
  "components": {
    "gen10_plus": {
      "firmware": [
        {"component": "HPE_BIOS", "version": "2.80"},
        {"component": "HPE_ILO5", "version": "2.70"}
      ],
      "drivers": [...]
    }
  }
}
```

### Windows Patches (`configs/windows_patches.json`)
```json
{
  "patches": [
    {
      "kb_number": "KB5041234",
      "severity": "Critical",
      "cve_ids": ["CVE-2025-12345"],
      "description": "Security update for Windows Kernel"
    }
  ]
}
```

### OpsRamp Config (`configs/opsramp_config.json`)
```json
{
  "opsramp_api": {
    "base_url": "https://api.opsramp.com",
    "version": "v2"
  },
  "integration": {
    "send_metrics": true,
    "send_alerts": true
  }
}
```

**Security**: Store secrets in environment variables or CI/CD secret stores, not in config files.

## CI/CD Workflows

### Jenkins Pipeline (`Jenkinsfile`)

The repository includes a declarative Jenkins pipeline designed for self-hosted Windows agents.

**Pipeline Stages:**
1. **Setup** - Installs Python dependencies, validates scripts and configs
2. **Generate UUIDs** - Creates deterministic UUIDs for all servers
3. **Build Firmware ISOs** - Downloads HPE firmware/drivers, creates bootable ISOs
4. **Build Windows ISOs** - Applies security patches to base Windows ISO
5. **Combine Deployment Packages** - Bundles firmware + Windows ISOs per server
6. **Deploy** - Deploys ISOs via iLO/PXE/Redfish
7. **Vulnerability Scan** - Scans ISOs and deployed servers
8. **OpsRamp Reporting** - Sends metrics and alerts
9. **Audit & Reporting** - Generates compliance reports, archives artifacts

**Pipeline Parameters:**
- `BUILD_STAGE` - Select which stage(s) to run (`firmware`, `windows`, `deploy`, `scan`, `all`)
- `SERVER_FILTER` - Comma-separated list of specific servers (default: all)
- `BASE_ISO_PATH` - Path to Windows Server base ISO
- `DRY_RUN` - Simulate without making changes (for testing)
- `DEPLOY_METHOD` - `ilo`, `pxe`, or `redfish`
- `SKIP_DOWNLOAD` - Skip firmware/driver downloads

**Triggers:**
- Manual: Click "Build with Parameters" in Jenkins UI
- Scheduled: Configure in Jenkins (e.g., nightly at 2 AM for firmware builds)
- API: Trigger via Jenkins REST API

**Credentials (configure in Jenkins):**
- `hpe-download-user` / `hpe-download-pass` - HPE repository access
- `ilo-user` / `ilo-password` - iLO access for deployment
- `opsramp-client-id` / `opsramp-client-secret` / `opsramp-tenant-id` - OpsRamp integration

**Artifacts:**
- ISOs: `output/firmware/**/*.iso`, `output/patched/**/*.iso`
- Build logs: `output/**/*.json`
- Deployment packages: `output/combined/*.zip`
- Audit reports: `logs/build_reports/**`

**Example Jenkins Job:**
```groovy
pipelineJob('hpe-iso-automation') {
    definition {
        cpsScm {
            scm {
                git {
                    remote { url('git@bitbucket.example.com:team/hpe-windows-iso-automation.git') }
                    branch('*/main')
                }
            }
            scriptPath('Jenkinsfile')
        }
    }
    triggers {
        cron('H 2 * * *')  // Daily at 2 AM
    }
}
```

## Docker Support

Build container image:
```bash
docker build -t hpe-iso-automation .
```

Run containerized build:
```bash
docker run --rm \
  -v /path/to/isos:/app/isos \
  -v /path/to/output:/app/output \
  -e HPE_DOWNLOAD_USER=xxx \
  -e HPE_DOWNLOAD_PASS=yyy \
  hpe-iso-automation \
  python scripts/build_iso.py --server-list configs/server_list.txt
```

Note: Windows-specific operations (DISM, HPE SUT) may require Windows containers or host tool access.

## Troubleshooting

### Common Issues

**1. Jenkins pipeline fails early**
```
Error: Pipeline aborted due to step failure
Solution: Check Jenkins console output. Ensure Jenkins agents have Windows Server and required tools installed
```

**2. Windows DISM errors**
```
Error: Failed to mount image
Solution: Ensure running with Administrator privileges on Windows
```

**3. iLO connection failures**
```
Error: ILO connection failed
Solution: Verify ILO_USER/ILO_PASSWORD credentials in Jenkins, check network connectivity
```

**4. Base ISO not found**
```
Error: Base ISO not found
Solution: Mount Windows ISO to Jenkins agent filesystem or provide HTTP URL accessible to agent
```

### Debug Mode
Enable verbose logging:
```bash
python scripts/build_iso.py --server test-server --dry-run --verbose
```

Check logs:
```bash
# View orchestrator log
tail -f logs/build_orchestrator.log

# View per-server results
cat output/results/build_result_server1_*.json
```

### Running Locally
```bash
# Ensure Windows environment for patching (or use WSL2 with DISM through PowerShell)
powershell -Command "Build-ISO.ps1"  # Alternative PowerShell wrapper
```

## Development

### Adding New Features
1. Create/modify scripts in `scripts/` directory
2. Update unit tests (if present)
3. Update documentation
4. Run linting: `pylint scripts/`
5. Test in development environment before PR

### Code Style
- Follow PEP 8 for Python code
- Include docstrings for all functions and classes
- Log all actions using Python `logging` module (not `print`)
- Return consistent result dictionaries

### Testing
```bash
# Run a single test script
python scripts/generate_uuid.py test-server

# Dry run entire pipeline
python scripts/build_iso.py --dry-run --server test-server

# Check configuration syntax
python -c "import json; json.load(open('configs/hpe_firmware_drivers_nov2025.json'))"
```

## Security Considerations

- **Credentials**: Store in environment variables or CI/CD secret stores (Jenkins Credentials, GitLab CI Variables). Never commit to repository.
- **Network Access**: HPE repositories, OpsRamp API require outbound HTTPS. Whitelist IPs in firewalls if needed.
- **iLO Access**: Use dedicated service account with minimum required privileges. Rotate credentials regularly.
- **ISO Storage**: Protect ISOs containing embedded credentials or sensitive metadata.
- **Audit**: All actions are logged. Review `audit_trail.log` regularly.

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
- Reference build ID from `logs/build_reports/`
- For Jenkins pipeline issues: Check Jenkins console output and agent logs

## License

MIT License - See LICENSE file for details.

## Contributors

- Platform Engineering Team
- Infrastructure Automation Group