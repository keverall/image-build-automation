# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Runner Setup Script
# =============================================================================
# Fully offline-capable setup script. All dependencies are bundled in the repo.

<#
.SYNOPSIS
    Set up PowerShell automation runner with all dependencies.

.DESCRIPTION
    Installs and configures:
    - PowerShell 7+ version check
    - Required PowerShell modules (Pester, PSScriptAnalyzer, PlatyPS, HPEOneView.860, OperationsManager) from bundled copies
    - Powerline-style custom prompt (offline, no .exe required)
    - GNU make detection (from Git for Windows or bundled)
    
    All dependencies are bundled in scripts/modules/ for offline capability.
    Falls back to PSGallery if bundled copies not found (will warn on air-gapped systems).

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts/setup-runner.ps1
#>

#
# Bundled dependencies:
#   - scripts/modules/ : PowerShell modules (Pester, PSScriptAnalyzer, PlatyPS, HPEOneView.860, OperationsManager)
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
$VENDOR_MODULES_DIR = Join-Path $PSScriptRoot 'modules'

# PowerShell modules bundled in scripts/modules/ (installed into PS module path)
# Add HPEOneView.860 and OperationsManager (SCOM) here to support offline air-gapped environments
$REQUIRED_MODULES = @(
    @{ Name = 'Pester';           Version = '5.7.1' },
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' },
    @{ Name = 'PlatyPS';          Version = '0.14.0' },
    @{ Name = 'HPEOneView.860';   Version = '8.60' },
    @{ Name = 'OperationsManager';Version = '1.0' } # SCOM module base version from PSGallery; script will fallback to highest available (e.g., 10.19.x or 10.22.x)
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

    # Search for the module in scripts/modules/ (case-insensitive)
    $moduleDir = Get-ChildItem -Path $VENDOR_MODULES_DIR -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } |
        Select-Object -First 1

    if ($moduleDir) {
        $versionDir = Join-Path $moduleDir.FullName $Version
        if (Test-Path $versionDir) {
            return @{ Path = $versionDir; ActualVersion = $Version }
        }
        
        # Fallback: If exact version not found, get the highest available version.
        # Useful for modules like OperationsManager where version varies by SCOM environment.
        $availableVersions = Get-ChildItem -Path $moduleDir.FullName -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [version]$_.Name } -Descending | 
            Select-Object -First 1
            
        if ($availableVersions) {
            Write-Warn "Exact version $Version of $Name not found. Using available version $($availableVersions.Name)."
            return @{ Path = $availableVersions.FullName; ActualVersion = $availableVersions.Name }
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
        # Verify the installation is functional by trying to import it
        try {
            Import-Module $Name -RequiredVersion $installed.Version -ErrorAction Stop -WarningAction SilentlyContinue
            # For Pester, also verify the native DLL exists (Add-Type failure not caught by Import-Module)
            if ($Name -eq 'Pester') {
                $moduleBase = Split-Path $installed.Path -Parent
                $dllPath = Join-Path $moduleBase 'bin\netstandard2.0\Pester.dll'
                if (-not (Test-Path $dllPath)) {
                    throw "Pester.dll missing at $dllPath"
                }
            }
            Write-Log "$Name $($installed.Version) already installed and verified"
            return
        } catch {
            Write-Warn "$Name $($installed.Version) found but failed to import (possibly corrupted), reinstalling..."
            # Remove the corrupted installation
            $moduleDir = Split-Path (Split-Path $installed.Path -Parent) -Parent
            if (Test-Path $moduleDir) {
                Remove-Item -Recurse -Force $moduleDir -ErrorAction SilentlyContinue
                Write-Log "Removed corrupted $Name installation"
            }
        }
    }

    # Try to find bundled copy
    $bundledInfo = Get-BundledModulePath -Name $Name -Version $Version
    if ($bundledInfo -and (Test-Path $bundledInfo.Path)) {
        $actualVersion = $bundledInfo.ActualVersion
        $bundledPath = $bundledInfo.Path
        Write-Log "Installing $Name $actualVersion from bundled copy..."

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

        # CRITICAL: Use the ACTUAL version directory name from the bundled source,
        # not the requested version string. PowerShell requires the folder name to
        # match the version declared in the module manifest (.psd1).
        $destVersionPath = Join-Path $destPath $actualVersion
        Copy-Item -Path $bundledPath -Destination $destVersionPath -Recurse -Force
        Write-OK "$Name $actualVersion installed from bundled copy"
        return
    }

    # Fallback: try PSGallery if network available
    Write-Warn "Bundled copy of $Name $Version not found. Attempting PSGallery..."
    $installError = $null
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        # Use -MinimumVersion so we get '8.60.xxxx' for HPEOneView.860 and '>= X.Y.Z' for others
        Install-Module -Name $Name -MinimumVersion $Version -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
        Write-OK "$Name installed from PSGallery"
    } catch {
        $installError = $_.Exception.Message
        Write-Err "Failed to install $Name from PSGallery: $installError"
        Write-Err "To fix: Download or copy '$Name' from a connected machine/SCOM server and place the version folder in:"
        Write-Err "  scripts/modules/$Name/<version-folder>/"
        Write-Err "  (Example: scripts/modules/OperationsManager/10.22.1234.0/)"
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

# ─── Oh My Posh Installation ─────────────────────────────────────────────────
function Install-OhMyPosh {
    $localBinDir = Join-Path $PROJECT_ROOT 'bin'
    $poshBin = Join-Path $localBinDir 'oh-my-posh.exe'
    
    if (Test-Path $poshBin) {
        Write-Log "Found bundled oh-my-posh.exe at $poshBin"
        $installDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'bin'
        $destPath = Join-Path $installDir 'oh-my-posh.exe'
        
        if (-not (Test-Path $destPath)) {
            if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Force -Path $installDir | Out-Null }
            Copy-Item -Path $poshBin -Destination $destPath -Force
            Write-OK "Oh My Posh installed to $destPath"
        }
        
        if ($env:PATH -notlike "*$installDir*") { 
            $env:PATH = "$installDir;$env:PATH" 
        }
        return
    }

    Write-Warn "Oh My Posh binary not found in bin/. Skipping."
    Write-Warn "NOTE: If .exe execution is blocked by admin policy (e.g., AppLocker), using 'git clone' will NOT bypass this,"
    Write-Warn "      because compiling from source still produces an .exe file. To use Oh My Posh, you must either:"
    Write-Warn "      1. Download oh-my-posh.exe and place it in the project's 'bin/' folder (if your IT policy allows it)."
    Write-Warn "      2. Request an IT exception for the oh-my-posh executable."
    Write-Warn "      3. Use a pure PowerShell custom prompt (no .exe required) by adding a prompt function to your `$PROFILE."
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
    Install-OhMyPosh
    Install-Make
    Install-Checkmake
    Test-PowerShellTools
    Show-Summary

    Write-OK "Setup complete!"
}

# ─── Checkmake Installation ──────────────────────────────────────────────────
function Install-Checkmake {
    Write-Log "Checking for checkmake (Makefile linting)..."
    
    $localBinDir = Join-Path $PROJECT_ROOT 'bin'
    
    # Determine OS and Architecture
    $os = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) { 'windows' } 
          elseif ($IsLinux) { 'linux' } 
          elseif ($IsMacOS) { 'darwin' } 
          else { 'windows' }
          
    $arch = 'amd64'
    if ($IsMacOS -or $IsLinux) {
        try {
            $archInfo = & uname -m 2>$null
            if ($archInfo -match 'aarch64|arm64') { $arch = 'arm64' }
        } catch { }
    } else {
        if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { $arch = 'arm64' }
        elseif ($env:PROCESSOR_ARCHITECTURE -match 'X86') { $arch = '386' }
    }
    
    $checkmakeBin = if ($os -eq 'windows') { 'checkmake.exe' } else { 'checkmake' }
    $checkmakeExe = Join-Path $localBinDir $checkmakeBin

    # 1. Check if already installed in bin/
    if (Test-Path $checkmakeExe) {
        Write-Log "Found checkmake at $checkmakeExe"
        if ($env:PATH -notlike "*$localBinDir*") {
            $env:PATH = "$localBinDir;$env:PATH"
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -notlike "*$localBinDir*") {
                [Environment]::SetEnvironmentVariable('PATH', "$localBinDir;$userPath", 'User')
            }
        }
        Write-OK "checkmake available from local bin directory"
        return
    }

    # 2. Check system-wide installation
    if (Get-Command checkmake -ErrorAction SilentlyContinue) {
        Write-OK "checkmake already available in PATH"
        return
    }

    # 3. Attempt download from GitHub Releases
    $version = "0.2.2"
    $url = "https://github.com/mrtazz/checkmake/releases/download/$version/checkmake-$version.$os.$arch"
    
    Write-Log "Downloading checkmake v$version for $os/$arch..."
    try {
        if (-not (Test-Path $localBinDir)) {
            New-Item -ItemType Directory -Force -Path $localBinDir | Out-Null
        }
        
        Invoke-WebRequest -Uri $url -OutFile $checkmakeExe -UseBasicParsing
        
        if ($os -ne 'windows') {
            chmod +x $checkmakeExe
        }
        
        Write-OK "checkmake downloaded successfully to $checkmakeExe"
        
        if ($env:PATH -notlike "*$localBinDir*") {
            $env:PATH = "$localBinDir;$env:PATH"
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -notlike "*$localBinDir*") {
                [Environment]::SetEnvironmentVariable('PATH', "$localBinDir;$userPath", 'User')
            }
        }
    } catch {
        Write-Warn "Failed to download checkmake: $($_.Exception.Message)"
        Write-Warn "To install offline: Download checkmake-$version.$os.$arch from https://github.com/mrtazz/checkmake/releases"
        Write-Warn "and place it in '$localBinDir\$checkmakeBin'"
    }
}

Main