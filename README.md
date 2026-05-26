# HPE ProLiant Windows Server ISO Automation (Root Readme)

Automated build pipelines for creating customized Windows Server installation ISOs tailored for HPE ProLiant hardware. Integrates firmware/driver updates, security patching, vulnerability scanning, complete audit trails, with OpsRamp monitoring and reporting.

---

## Table of Contents

### Internal docs index
| Document | Description |
|---|---|
| [📚 Documentation Index](docs/README.md) | Complete documentation overview |
| [🔧 Maintenance Mode](docs/maintenance_mode.md) | Architecture, scheduling, audit, OpsRamp, environment variables |
| [📡 Orchestrator & Routing](docs/powershell_api_reference.md#orchestrator-api-reference) | Request types, call sequence, adding new handlers, return schemas |
| [🔌 PowerShell Generated Cmdlets](docs/dynamic-code-docs/INDEX.md) | Auto-generated reference for all PowerShell cmdlets — `New-Uuid`, `Update-Firmware`, `Set-MaintenanceMode`, `Invoke-IsoDeploy`, etc. |
| [🧪 PowerShell Testing (Pester)](docs/testing.md) | Pester v5 BDD testing guide |
| [⚙️ Code Quality & Security](docs/code_quality.md) | PSScriptAnalyzer, gitleaks configuration |
| [🔌 CI Run Requirements](docs/powershell_ci.md) | Prerequisites, CyberArk bootstrap, GitLab/Jenkins examples |

### In this document
- [HPE ProLiant Windows Server ISO Automation (Root Readme)](#hpe-proliant-windows-server-iso-automation-root-readme)
  - [Table of Contents](#table-of-contents)
    - [Internal docs index](#internal-docs-index)
    - [In this document](#in-this-document)
  - [Project Architecture](#project-architecture)
  - [Generated Audit Logs (JSON)](#generated-audit-logs-json)
  - [Quick Links for Common Tasks](#quick-links-for-common-tasks)
  - [GitLab Pipeline Files](#gitlab-pipeline-files)

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
│   │   ├── audit/                     # Regulatory compliance & audit trails
│   │   ├── testing/                   # Test execution logs
│   │   ├── production/                # Operational and execution logs
│   │   └── build_reports/             # Build artefacts and output
│   └── coverage-results.xml             # Cobertura XML coverage report (see docs/testing.md)
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
├── Dockerfile                           # Docker image for build agents
├── docker-entrypoint.ps1              # PowerShell entrypoint
├── docs/                              # Full documentation set
│   └── (see Documentation Index above)
├── .gitlab-ci.yml                     # GitLab CI/CD pipeline (REST API triggers)
├── src/powershell/                    # PowerShell module
│   ├── Automation/                    # Module root
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
│   │   └── Private/                    # Internal helpers
│   │       ├── Config.psm1
│   │       ├── Credentials.psm1
│   │       ├── Executor.psm1
│   │       ├── FileIO.psm1
│   │       ├── Inventory.psm1
│   │       ├── Audit.psm1
│   │       ├── Logging.psm1
│   │       ├── Base.psm1
│   │       ├── Router.psm1
│   │       └── Automation.psd1          # Module manifest
├── tests/powershell/                  # Pester v5 test suite
│   ├── Tests.Tests.ps1
│   ├── Config.Unit.Tests.ps1
│   ├── Credentials.Unit.Tests.ps1
│   ├── Executor.Unit.Tests.ps1
│   ├── FileIO.Unit.Tests.ps1
│   ├── Inventory.Unit.Tests.ps1
│   ├── Validators.Unit.Tests.ps1
│   ├── Router.Unit.Tests.ps1
│   ├── New-Uuid.Unit.Tests.ps1
│   ├── Audit.Unit.Tests.ps1
│   └── Set-MaintenanceMode.Unit.Tests.ps1
└── scripts/                            # CI runner provisioning and helpers
    └── setup-runner.sh
```

## Generated Audit Logs (JSON)

During both normal operations and unit testing (e.g. `make test`), you will notice a significant number of structured `.json` log files generated in the `generated/logs/` subdirectories (such as `generated/logs/testing/enable_UNIT-TEST-CLUSTER_...json`). 

These files are the definitive, machine-readable execution records generated by the `AuditLogger`. They are designed to be ingested programmatically by external monitoring and compliance systems (like OpsRamp and ServiceNow) to confirm state changes, durations, and metadata without parsing plain text logs.

**Important Note on Testing:** During test execution, these JSON logs are intentionally written to `generated/logs/testing/` to validate that the audit mechanics work end-to-end without polluting the production audit trails. **Do not change their filenames or suppress their generation** in the test runner, as doing so breaks the execution record structure required for GDPR compliance and external system integrations. A log pruning script (`scripts/prune-logs.ps1`) automatically manages retention to prevent these from bloating the repository.

---

## Quick Links for Common Tasks

| Task | Manual Command | Pipeline Stage |
|---|---|---|
| Run all tests locally | `pwsh -File scripts/run-tests.ps1` | Unit Tests |
| Generate test coverage | `make coverage-report` | Test |
| Enable maintenance mode | `pwsh -Command "Set-MaintenanceMode -ClusterId CLUSTER -Start now"` | Maintenance Mode |
| Validate configuration | `pwsh -Command "Get-Content configs/clusters_catalogue.json \| ConvertFrom-Json"` | Setup |

---

## GitLab Pipeline Files

The GitLab CI pipeline lives in `.gitlab-ci.yml` at the repository root using PowerShell 7.4 containers.

---

## Contributing

All changes should include:
1. Unit tests mirroring the module structure in `tests/powershell/`
2. Documentation updated in `docs/`

---

## Support

- Create an issue or pull request in the repository
- Contact **Kev Everall**
- Reference build ID from `generated/logs/build_reports/` or `generated/logs/audit/maintenance_audit.log`

---

## License

MIT License — see `LICENSE` file for details.