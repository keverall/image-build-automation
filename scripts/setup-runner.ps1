# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Runner Setup Script
# =============================================================================
# Fully offline-capable setup script. All dependencies are bundled in the repo.
#
# Bundled dependencies:
#   - vendor/modules/  : PowerShell modules (Pester, PSScriptAnalyzer, PlatyPS)
#   - bin/make.exe     : GNU make for Windows (if available)
#   - Git for Windows  : Provides make.exe in usr\bin\ (preferred source)
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
# =============================================================================

using namespace System

# ─── Configuration ───────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$LOG_FILE = Join-Path (${env:TEMP} ?? '/tmp') "hpe-automation-pwsh-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$VENDOR_MODULES_DIR = Join-Path $PROJECT_ROOT 'vendor/modules'

# PowerShell modules bundled in vendor/modules/
$REQUIRED_MODULES = @(
    @{ Name = 'Pester';           Version = '5.7.1' },
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' },
    @{ Name = 'PlatyPS';          Version = '0.14.0' }
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

# ─── PowerShell Modules Installation (Offline from bundled copies) ───────────
function Get-BundledModulePath {
    param([string]$Name, [string]$Version)

    # Search for the module in vendor/modules/ (case-insensitive)
    $moduleDir = Get-ChildItem -Path $VENDOR_MODULES_DIR -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } |
        Select-Object -First 1

    if ($moduleDir) {
        $versionDir = Join-Path $moduleDir.FullName $Version
        if (Test-Path $versionDir) {
            return $versionDir
        }
    }
    return $null
}

function Install-PowerShellModuleOffline {
    param(
        [string]$Name,
        [string]$Version
    )

    # Check if already installed
    $installed = Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1

    if ($installed -and $installed.Version -ge [version]$Version) {
        Write-Log "$Name $($installed.Version) already installed"
        return
    }

    # Try to find bundled copy
    $bundledPath = Get-BundledModulePath -Name $Name -Version $Version
    if ($bundledPath -and (Test-Path $bundledPath)) {
        Write-Log "Installing $Name $Version from bundled copy..."

        # Determine PowerShell module path
        $userModulePath = $null
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
            $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
        } else {
            $userModulePath = Join-Path $HOME '.local/share/powershell/Modules'
        }

        if (-not (Test-Path $userModulePath)) {
            New-Item -ItemType Directory -Force -Path $userModulePath | Out-Null
        }

        $destPath = Join-Path $userModulePath $Name
        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Force -Path $destPath | Out-Null
        }

        $destVersionPath = Join-Path $destPath $Version
        Copy-Item -Path $bundledPath -Destination $destVersionPath -Recurse -Force
        Write-OK "$Name installed from bundled copy"
        return
    }

    # Fallback: try PSGallery if network available
    Write-Warn "Bundled copy of $Name $Version not found. Attempting PSGallery..."
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name $Name -RequiredVersion $Version -Scope CurrentUser -Force -AllowClobber -Repository PSGallery 2>$null
        Write-OK "$Name installed from PSGallery"
    } catch {
        Write-Err "Failed to install $Name. Bundled copy not found and PSGallery unavailable."
        Write-Err "Ensure vendor/modules/$Name/$Version exists."
    }
}

function Install-RequiredModules {
    Write-Log "Installing PowerShell modules from bundled copies..."

    foreach ($mod in $REQUIRED_MODULES) {
        Install-PowerShellModuleOffline -Name $mod.Name -Version $mod.Version
    }

    # Update Help files (skipped offline — not critical)
    Write-Log "Skipping Update-Help (offline mode)"
}

# ─── Make Detection (Windows) ────────────────────────────────────────────────
function Install-Make {
    $runningOnWindows = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    if (-not $runningOnWindows) {
        Write-Log "Non-Windows platform detected, skipping make detection"
        return
    }

    Write-Log "Detecting make for Windows..."

    # Check if make is already in PATH
    if (Get-Command make -ErrorAction SilentlyContinue) {
        $makeVersion = make --version 2>$null | Select-Object -First 1
        Write-Log "make already available: $makeVersion"
        Write-OK "make version check passed"
        return
    }

    function Add-PathPersistent {
        param([string]$PathDir)

        # Add to current session
        if ($env:PATH -notlike "*$PathDir*") {
            $env:PATH = "$PathDir;$env:PATH"
        }

        # Add to user PATH persistently
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($userPath -notlike "*$PathDir*") {
            $newUserPath = "$PathDir;$userPath"
            [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
            Write-Log "Added $PathDir to user PATH (persistent)"
        }
    }

    # Search for make.exe in Git for Windows installation
    $gitMakePaths = @(
        'C:\Program Files\Git\usr\bin\make.exe',
        'C:\Program Files (x86)\Git\usr\bin\make.exe',
        'C:\Program Files\Git\mingw64\bin\make.exe',
        'C:\Program Files\Git\mingw32\bin\make.exe'
    )

    foreach ($gitMakePath in $gitMakePaths) {
        if (Test-Path $gitMakePath) {
            Write-Log "Found make.exe in Git for Windows: $gitMakePath"
            Add-PathPersistent -PathDir (Split-Path $gitMakePath -Parent)
            Write-OK "make available from Git for Windows"
            return
        }
    }

    # Check project-local bin directory (bundled with repo)
    $localBinDir = Join-Path $PROJECT_ROOT 'bin'
    if (Test-Path $localBinDir) {
        $localMakePath = Join-Path $localBinDir 'make.exe'
        if (Test-Path $localMakePath) {
            Write-Log "Found make.exe in project bin directory: $localMakePath"
            Add-PathPersistent -PathDir $localBinDir
            Write-OK "make available from local bin directory"
            return
        }
    }

    # All methods failed — warn but don't fail
    Write-Warn "make not found. It is typically bundled with Git for Windows."
    Write-Warn "Git for Windows: https://git-scm.com/download/win"
    Write-Warn "Alternatively, place make.exe in: $localBinDir\make.exe"
    Write-Warn "You can run PowerShell scripts directly without make:"
    Write-Warn "  pwsh -File scripts/setup-runner.ps1"
    Write-Warn "  pwsh -File scripts/run-tests.ps1"
    Write-Warn "  pwsh -File scripts/lint.ps1"
    Write-Warn "  pwsh -File scripts/coverage-report.ps1"
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
    Write-Host "    pwsh -File scripts/run-tests.ps1"
    Write-Host ""
    Write-Host "${COLOR_YELLOW}To lint PowerShell files:${COLOR_RESET}"
    Write-Host "    pwsh -NoProfile -Command 'Invoke-ScriptAnalyzer -Path src/powershell -Recurse'"
    Write-Host ""
    Write-Host "${COLOR_CYAN}Makefile targets:${COLOR_RESET}"
    Write-Host "    make setup      # Run this setup script"
    Write-Host "    make test       # Run all Pester tests"
    Write-Host "    make lint       # Lint PowerShell with PSScriptAnalyzer"
    Write-Host "    make coverage   # Run tests with code coverage"
    Write-Host "    make clean      # Remove build artifacts"
    Write-Host ""
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        Write-Host "${COLOR_YELLOW}make not found - run PowerShell scripts directly:${COLOR_RESET}"
        Write-Host "    pwsh -File scripts/setup-runner.ps1"
        Write-Host "    pwsh -File scripts/run-tests.ps1"
        Write-Host "    pwsh -File scripts/lint.ps1"
        Write-Host "    pwsh -File scripts/coverage-report.ps1"
    }
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
    Install-Make
    Test-PowerShellTools
    Show-Summary

    Write-OK "Setup complete!"
}

Main