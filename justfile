# Justfile - Local DevOps Engine for HPE ProLiant ISO Automation

# Enforce clean terminal variables with default fallback overrides
target_node := "TargetNode01"

# Run the full automated maintenance and deployment workflow
default:
    just maintenance-enable
    just maintenance-disable

# Target: Put Windows OS node into SCOM Maintenance Mode
maintenance-enable:
    pwsh ./scripts/ManageScomMM.ps1 -Action Enable -ComputerName "{{target_node}}"

# Target: Update maintenance window settings
maintenance-disable:
    pwsh ./scripts/ManageScomMM.ps1 -Action Disable -ComputerName "{{target_node}}"

# Target: Run PowerShell tests
test:
    pwsh -File ./scripts/run-pwsh-tests.ps1

# Target: Lint PowerShell code
lint:
    pwsh -Command "Invoke-ScriptAnalyzer -Path ./src/powershell -Recurse"