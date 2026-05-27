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

# Make binary configuration (for Windows)
$MAKE_DOWNLOAD_URLS = @(
    'https://eternallybored.org/misc/make/make-4.4.1.zip',
    'https://sourceforge.net/projects/ezwinports/files/make-4.4.1-without-guile-w32-bin.zip/download'
)
$MAKE_DIRECT_URL = 'https://github.com/chocolatey/choco/raw/37575d0f7b3e2e3e5c8b3b1d0e6c1e0b5a4d3c2f/lib/make/tools/make.exe'
$MAKE_EXPECTED_HASH = ''

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

# ─── Make Installation (Windows) ─────────────────────────────────────────────
function Install-Make {
    $runningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5
    if (-not $runningOnWindows) {
        Write-Log "Non-Windows platform detected, skipping make installation"
        return
    }

    # Check if make is already available
    if (Get-Command make -ErrorAction SilentlyContinue) {
        $makeVersion = make --version 2>$null | Select-Object -First 1
        Write-Log "make already installed: $makeVersion"
        Write-OK "make version check passed"
        return
    }

    Write-Log "Installing make for Windows..."

    # Download precompiled binary to project-local bin directory
    $localBinDir = Join-Path $PROJECT_ROOT 'bin'
    if (-not (Test-Path $localBinDir)) {
        New-Item -ItemType Directory -Force -Path $localBinDir | Out-Null
    }
    $localMakePath = Join-Path $localBinDir 'make.exe'

    # Check if already downloaded
    if (Test-Path $localMakePath) {
        Write-Log "make binary found at: $localMakePath"
        $env:PATH = "$localBinDir;$env:PATH"
        Write-OK "make available from local bin directory"
        return
    }

    Write-Log "Downloading make binary..."

    # Configure proxy if environment variables are set
    $proxyParams = @{}
    if ($env:HTTPS_PROXY) {
        $proxyParams['Proxy'] = $env:HTTPS_PROXY
        Write-Log "Using proxy: $env:HTTPS_PROXY"
    } elseif ($env:HTTP_PROXY) {
        $proxyParams['Proxy'] = $env:HTTP_PROXY
        Write-Log "Using proxy: $env:HTTP_PROXY"
    }

    # Try zip archive URLs first
    foreach ($url in $MAKE_DOWNLOAD_URLS) {
        try {
            Write-Log "Trying: $url"
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $downloadPath = Join-Path $localBinDir "make_$($url.GetHashCode()).zip"
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

            Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing -TimeoutSec 30 @proxyParams

            if (Test-Path $downloadPath) {
                try {
                    Expand-Archive -Path $downloadPath -DestinationPath $localBinDir -Force -ErrorAction SilentlyContinue
                    $foundMake = Get-ChildItem -Path $localBinDir -Filter 'make.exe' -Recurse | Select-Object -First 1
                    if ($foundMake) {
                        if ($foundMake.DirectoryName -ne $localBinDir) {
                            Move-Item $foundMake.FullName $localMakePath -Force
                        }
                        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

                        if ($MAKE_EXPECTED_HASH) {
                            $actualHash = (Get-FileHash $localMakePath -Algorithm SHA256).Hash
                            if ($actualHash -ne $MAKE_EXPECTED_HASH) {
                                Remove-Item $localMakePath -Force -ErrorAction SilentlyContinue
                                throw "Hash mismatch for make.exe: expected $MAKE_EXPECTED_HASH, got $actualHash"
                            }
                            Write-Log "SHA-256 hash verified"
                        }

                        $env:PATH = "$localBinDir;$env:PATH"
                        Write-OK "make downloaded and extracted to local bin directory"
                        return
                    }
                } catch {
                    Write-Warn "Extraction failed for $url, trying next URL..."
                }
                Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warn "Download failed from $url : $($_.Exception.Message)"
        }
    }

    # Try direct .exe download as final fallback
    try {
        Write-Log "Trying direct .exe download: $MAKE_DIRECT_URL"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Remove-Item $localMakePath -Force -ErrorAction SilentlyContinue

        Invoke-WebRequest -Uri $MAKE_DIRECT_URL -OutFile $localMakePath -UseBasicParsing -TimeoutSec 30 @proxyParams

        if (Test-Path $localMakePath) {
            if ($MAKE_EXPECTED_HASH) {
                $actualHash = (Get-FileHash $localMakePath -Algorithm SHA256).Hash
                if ($actualHash -ne $MAKE_EXPECTED_HASH) {
                    Remove-Item $localMakePath -Force -ErrorAction SilentlyContinue
                    throw "Hash mismatch for make.exe: expected $MAKE_EXPECTED_HASH, got $actualHash"
                }
                Write-Log "SHA-256 hash verified"
            }
            $env:PATH = "$localBinDir;$env:PATH"
            Write-OK "make downloaded directly to local bin directory"
            return
        }
    } catch {
        Write-Warn "Direct .exe download failed: $($_.Exception.Message)"
    }

    # All methods failed
    Write-Warn "Could not automatically install make."
    Write-Warn "To manually install make:"
    Write-Warn "  1. Download make.exe from: https://eternallybored.org/misc/make/"
    Write-Warn "  2. Place it in: $localBinDir\make.exe"
    Write-Warn "  3. Or add make.exe to your system PATH"
    Write-Warn "Alternatively, you can run PowerShell scripts directly without make:"
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