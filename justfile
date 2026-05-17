# Justfile - Local DevOps Engine

# Enforce clean terminal variables with default fallback overrides
target_node := "TargetNode01"
ilo_ip      := "10.0.0.50"
iso_image   := "SPP2026.iso"

# Run the full automated maintenance and deployment workflow
default:
    just maintenance-enable
    just hardware-deploy
    just maintenance-disable

# Target: Put Windows OS node into SCOM Maintenance Mode
maintenance-enable:
    pwsh ./scripts/ManageScomMM.ps1 -Action Enable -ComputerName "{{target_node}}"

# Target: Run isolated Python environment directly via uv context
hardware-deploy:
    uv run ./scripts/deploy_firmware.py --target "{{ilo_ip}}" --iso "{{iso_image}}"

# Target: Strip node out of SCOM maintenance mode post-flash
maintenance-disable:
    pwsh ./scripts/ManageScomMM.ps1 -Action Disable -ComputerName "{{target_node}}"
