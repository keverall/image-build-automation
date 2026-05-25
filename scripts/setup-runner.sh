#!/usr/bin/env bash
# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Runner Setup Script
# =============================================================================
# PowerShell environment setup for CI/CD runners.
#
# Usage:
#   chmod +x scripts/setup-runner.sh && ./scripts/setup-runner.sh
# =============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  HPE ProLiant ISO Automation — PowerShell Setup      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for PowerShell
if command -v pwsh &>/dev/null; then
    PWSH_VERSION=$(pwsh --version)
    echo -e "${GREEN}OK${NC} PowerShell is available: ${PWSH_VERSION}"
else
    echo -e "${RED}ERROR${NC} PowerShell 7+ is required but not found."
    echo "Install PowerShell: https://learn.microsoft.com/powershell/scripting/install/installing-powershell"
    exit 1
fi

# Install required PowerShell modules
echo ""
echo "Installing PowerShell modules..."
pwsh -NoProfile -Command "
    Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Write-Host 'Installing Pester...'
    Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -AllowClobber
    Write-Host 'Installing PSScriptAnalyzer...'
    Install-Module PSScriptAnalyzer -Force -SkipPublisherCheck -AllowClobber
    Write-Host 'Installing PlatyPS...'
    Install-Module PlatyPS -Force -SkipPublisherCheck -AllowClobber
    Write-Host 'PowerShell modules installed successfully'
"

# Verify installation
echo ""
echo "Verifying PowerShell module installation..."
pwsh -NoProfile -Command "
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module PlatyPS -ErrorAction Stop
    Write-Host 'All PowerShell modules verified'
"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  PowerShell setup complete!                           ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  To run tests: pwsh -File scripts/run-pwsh-tests.ps1"
echo "  To lint code: pwsh -Command \"Invoke-ScriptAnalyzer -Path src/powershell -Recurse\""