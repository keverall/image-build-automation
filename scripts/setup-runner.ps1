# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Runner Setup Script
# =============================================================================
# Installs PowerShell 7+, all required modules, and project tooling.
# Designed for: Windows runners, Linux with PowerShell, CI/CD pipelines.
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
# =============================================================================

using namespace System

# ─── Configuration ───────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$LOG_FILE = Join-Path (${env:TEMP} ?? '/tmp') "hpe-automation-pwsh-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# PowerShell Gallery configuration
$REQUIRED_MODULES = @(
    @{ Name = 'Pester';        Version = '5.0.0';         Scope = 'CurrentUser' },
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0';    Scope = 'CurrentUser' },
    @{ Name = 'PlatyPS';       Version = '0.14.0';        Scope = 'CurrentUser' }
)

# Colors for terminal output (Windows/Linux compatible)
$COLOR_GREEN = "`e[32m"
$COLOR_CYAN  = "`e[36m"
$COLOR_YELLOW = "`e[33m"
$COLOR_RED   = "`e[31m"
$COLOR_RESET = "`e[0m"

# ─── Helper Functions ────────────────────────────────────────────────────────
function Write-Log   { param($msg) Write-Host "${COLOR_CYAN}[INFO]${COLOR_RESET} $msg" ; Add-Content $LOG_FILE "[INFO] $msg" }
function Write-OK    { param($msg) Write-Host "${COLOR_GREEN}[OK]${COLOR_RESET} $msg" ; Add-Content $LOG_FILE "[OK] $msg" }
function Write-Warn  { param($msg) Write-Host "${COLOR_YELLOW}[WARN]${COLOR_RESET} $msg" ; Add-Content $LOG_FILE "[WARN] $msg" }
function Write-Err   { param($msg) Write-Host "${COLOR_RED}[ERROR]${COLOR_RESET} $msg" ; Add-Content $LOG_FILE "[ERROR] $msg" }

# ─── Prerequisites Check ─────────────────────────────────────────────────────
function Test-PowerShellVersion {
    $ver = $PSVersionTable.PSVersion
    if ($ver.Major -lt 7) {
        Write-Err "PowerShell 7+ required. Current: $($ver.ToString())"
        Write-Err "Install via: winget install Microsoft.PowerShell; or: brew install pwsh"
        exit 1
    }
    Write-Log "PowerShell version: $($ver.ToString())"
    Write-OK "PowerShell version check passed"
}

# ─── PowerShell Modules Installation ─────────────────────────────────────────
function Install-PowerShellModule {
    param(
        [string]$Name,
        [string]$Version,
        [string]$Scope
    )
    $installed = Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1

    if ($installed -and $installed.Version -ge [version]$Version) {
        Write-Log "$Name $($installed.Version) already installed"
        return
    }

    Write-Log "Installing $Name $Version..."
    try {
        Install-Module -Name $Name -RequiredVersion $Version -Scope $Scope -Force -AllowClobber -Repository PSGallery 2>&1 | Tee-Object -FilePath $LOG_FILE
        Write-OK "$Name installed"
    } catch {
        Write-Err "Failed to install ${Name}: $($_)"
        Write-Err "Try: Set-PSRepository PSGallery -InstallationPolicy Trusted"
        exit 1
    }
}

function Install-RequiredModules {
    Write-Log "Configuring PowerShell Gallery..."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

    foreach ($mod in $REQUIRED_MODULES) {
        Install-PowerShellModule -Name $mod.Name -Version $mod.Version -Scope $mod.Scope
    }

    # Update Help files
    Write-Log "Updating PowerShell help..."
    Update-Help -Force -ErrorAction SilentlyContinue 2>$null
    Write-OK "Help updated"
}

# ─── Verify Installation ───────────────────────────────────────────────────────
function Test-PowerShellTools {
    Write-Log "Verifying PowerShell tools..."

    foreach ($mod in $REQUIRED_MODULES) {
        $installed = Get-Module $mod.Name -ListAvailable -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1

        if ($installed) {
            Write-OK "$($mod.Name) $($installed.Version)"
        } else {
            Write-Err "$($mod.Name) NOT FOUND"
        }
    }

    # Verify Pester can run tests
    $pester = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($pester) {
        Write-Log "Verifying Pester test discovery..."
        $testCount = (Get-ChildItem -Path (Join-Path $PROJECT_ROOT 'tests/powershell') -Filter '*.ps1' -Recurse | Measure-Object).Count
        Write-OK "Found $testCount PowerShell test files"
    }
}

# ─── Print Summary ─────────────────────────────────────────────────────────────
function Show-Summary {
    Write-Host ""
    Write-Host "${COLOR_GREEN}╔══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    Write-Host "${COLOR_GREEN}║${COLOR_RESET}  ${COLOR_CYAN}HPE ProLiant ISO Automation — PowerShell Setup Complete${COLOR_RESET}   ${COLOR_GREEN}║${COLOR_RESET}"
    Write-Host "${COLOR_GREEN}╚══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    Write-Host ""
    Write-Host "  Project root: $PROJECT_ROOT"
    Write-Host "  Log file:     $LOG_FILE"
    Write-Host ""
    Write-Host "${COLOR_YELLOW}To run PowerShell tests:${COLOR_RESET}"
    Write-Host "    cd $PROJECT_ROOT"
    Write-Host "    pwsh -File scripts/run-pwsh-tests.ps1"
    Write-Host ""
    Write-Host "${COLOR_YELLOW}To lint PowerShell files:${COLOR_RESET}"
    Write-Host "    pwsh -NoProfile -Command 'Invoke-ScriptAnalyzer -Path src/powershell -Recurse'"
    Write-Host ""
    Write-Host "${COLOR_CYAN}Makefile integration:${COLOR_RESET}"
    Write-Host "    make pwsh-setup   # Run this script"
    Write-Host "    make pwsh-test    # Run Pester tests"
    Write-Host "    make pwsh-lint    # Lint PowerShell code"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
function Main {
    Write-Host ""
    Write-Host "${COLOR_CYAN}╔══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    Write-Host "${COLOR_CYAN}║${COLOR_RESET}  HPE ProLiant ISO Automation — PowerShell Setup       ${COLOR_RESET}║${COLOR_RESET}"
    Write-Host "${COLOR_CYAN}╚══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    Write-Host ""

    Test-PowerShellVersion
    Install-RequiredModules
    Test-PowerShellTools
    Show-Summary

    Write-OK "Setup complete!"
}

Main