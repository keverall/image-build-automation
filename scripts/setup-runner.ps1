<#
.SYNOPSIS
    Setup-Runner.ps1 — PowerShell runner environment setup.

.DESCRIPTION
    Fully offline-capable setup script that installs required PowerShell modules
    (Pester, PSScriptAnalyzer, PlatyPS) and binary tools (Oh My Posh, GNU make,
    checkmake). Bundled copies live in scripts/modules/; if absent it attempts
    a PSGallery download via Save-Module with no admin rights needed.

.EXAMPLE
    pwsh -File scripts/setup-runner.ps1
#>

# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Runner Setup
# =============================================================================
# Fully offline-capable.  Bundled copies live in scripts/modules/; if absent we
# attempt a PSGallery download via Save-Module (no admin rights needed).
# =============================================================================

using namespace System

# ── Configuration ────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'
$PROJECT_ROOT    = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$LOG_FILE        = Join-Path (${env:TEMP} ?? '/tmp') "hpe-automation-pwsh-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$VENDOR_MODULES_DIR = Join-Path $PSScriptRoot 'modules'
$BIN_DIR         = Join-Path $PROJECT_ROOT 'bin'

# Bundled module manifest — name + minimum version (version is the *requested*
# floor; the actual installed version may be higher for modules like
# OperationsManager that ship with SCOM in arbitrary versions).
$REQUIRED_MODULES = @(
    @{ Name = 'Pester';           Version = '5.7.1' },
    @{ Name = 'PSScriptAnalyzer'; Version = '1.21.0' },
    @{ Name = 'PlatyPS';          Version = '0.14.0' },
    @{ Name = 'HPEOneView.860';   Version = '8.60' },
    @{ Name = 'OperationsManager';Version = '1.0' }   # floor only; real SCOM versions are 10.x
)

# Colours (ANSI — works in all hosts that support colour)
$C_RESET  = "`e[0m"
$C_CYAN   = "`e[36m"
$C_GREEN  = "`e[32m"
$C_YELLOW = "`e[33m"
$C_RED    = "`e[31m"

# ── Log helpers ──────────────────────────────────────────────────────────────
function _WL { param($tag, $colour, $msg)
    Write-Host "${colour}${tag}${C_RESET} $msg"
    Add-Content $LOG_FILE "${tag} $msg" }
function Write-Log  { param($m) _WL '[INFO]'  $C_CYAN   $m }
function Write-OK   { param($m) _WL '[OK]'    $C_GREEN  $m }
function Write-Warn { param($m) _WL '[WARN]'  $C_YELLOW $m }
function Write-Err  { param($m) _WL '[ERROR]' $C_RED    $m }

# ── Utility: user PS module path (OS-aware) ─────────────────────────────────
function Get-UserModulePath {
    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
    $base  = if ($isWin) { [Environment]::GetFolderPath('MyDocuments') } else { $HOME }
    $rel   = if ($isWin) { 'PowerShell\Modules' }         else { '.local/share/powershell/Modules' }
    return Join-Path $base $rel
}

# ── Utility: add directory to session + persistent user PATH ─────────────────
function Add-BinToPath {
    param([string]$Dir)
    if ($env:PATH -notlike "*$Dir*") { $env:PATH = "$Dir;$env:PATH" }
    $persisted = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($persisted -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable('PATH', "$Dir;$persisted", 'User')
        Write-Log "Added $Dir to user PATH (persistent)"
    }
}

# =============================================================================
# PREREQUISITES
# =============================================================================

function Test-PowerShellVersion {
    $v = $PSVersionTable.PSVersion
    if ($v.Major -lt 7) {
        Write-Err "PowerShell 7+ required. Current: $($v.ToString())"
        Write-Err "Install via: winget install Microsoft.PowerShell  ·  brew install pwsh"
        exit 1
    }
    Write-OK "PowerShell $($v.ToString())"
}

# =============================================================================
# MODULE INSTALLATION (offline-first, PSGallery fallback via Save-Module)
# =============================================================================

function Get-BundledModulePath {
    param([string]$Name, [string]$Version)

    $parent = Get-ChildItem -Path $VENDOR_MODULES_DIR -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if (-not $parent) { return $null }

    # Helper: resolve highest version from a directory containing version sub-dirs
    function _HighestVersion([string]$Dir) {
        Get-ChildItem -Path $Dir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1
    }

    # Layout A (canonical): scripts/modules/<Name>/<version>/
    $exact = Join-Path $parent.FullName $Version
    if (Test-Path $exact) { return @{ Path = $exact; ActualVersion = $Version } }

    $highest = _HighestVersion $parent.FullName
    if ($highest) {
        Write-Warn "Exact version $Version of $Name not found. Using $($highest.Name)."
        return @{ Path = $highest.FullName; ActualVersion = $highest.Name }
    }

    # Layout B (legacy nesting): Save-Module into <Name>/ subfolder creates
    #   scripts/modules/<Name>/<Name>/<version>/  — handle for backwards compat.
    $inner = Get-ChildItem -Path $parent.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if ($inner) {
        $innerExact = Join-Path $inner.FullName $Version
        if (Test-Path $innerexact) { return @{ Path = $innerexact; ActualVersion = $Version } }
        $innerHighest = _HighestVersion $inner.FullName
        if ($innerHighest) {
            Write-Warn "Exact version $Version of $Name not found (nested layout). Using $($innerHighest.Name)."
            return @{ Path = $innerHighest.FullName; ActualVersion = $innerHighest.Name }
        }
    }
    return $null
}

function Copy-ModuleToUserPath {
    param([string]$Name, [string]$Version, [string]$SrcDir)
    
    # Extract the actual module name from the .psd1 file in the source
    # This ensures the directory name matches the manifest (case-sensitive on Linux)
    $psd1File = Get-ChildItem -Path $SrcDir -Filter "*.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1
    $actualName = if ($psd1File) { $psd1File.BaseName } else { $Name }
    
    $dest = Join-Path (Get-UserModulePath) "$actualName/$Version"
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    
    # Copy CONTENTS of source directory, not the directory itself
    Get-ChildItem -Path $SrcDir | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
    }
    Write-OK "$actualName $Version installed"
}

function Install-RequiredModule {
    param([string]$Name, [string]$Version)

    # 1. Already installed and importable?
    $existing = Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($existing -and $existing.Version -ge [version]$Version) {
        try {
            Import-Module $Name -RequiredVersion $existing.Version -ErrorAction Stop -WarningAction SilentlyContinue
            if ($Name -eq 'Pester') {   # well-known silent corruption
                $dll = Join-Path (Split-Path $existing.Path) 'bin\netstandard2.0\Pester.dll'
                if (-not (Test-Path $dll)) { throw "Pester.dll missing" }
            }
            Write-OK "$Name $($existing.Version) already verified"
            return
        } catch {
            Write-Warn "$Name $($existing.Version) corrupt — removing and reinstalling"
            # Safely calculate the module directory (2 levels up from .psd1)
            $versionDir = Split-Path $existing.Path -Parent
            $moduleDir = Split-Path $versionDir -Parent
            # Verify this is actually a module directory before deleting
            $containsPsd1 = Get-ChildItem -Path $versionDir -Filter "*.psd1" -ErrorAction SilentlyContinue
            if ($containsPsd1 -and (Test-Path $moduleDir -PathType Container)) {
                Write-Log "Removing corrupt module directory: $moduleDir"
                Remove-Item -Recurse -Force $moduleDir -ErrorAction SilentlyContinue
            } else {
                Write-Warn "Cannot verify module directory structure, skipping removal: $moduleDir"
            }
        }
    }

    # 2. Bundled copy in scripts/modules/ ?
    $bundled = Get-BundledModulePath -Name $Name -Version $Version
    if ($bundled) {
        Write-Log "Installing $Name $($bundled.ActualVersion) from bundle"
        Copy-ModuleToUserPath -Name $Name -Version $bundled.ActualVersion -SrcDir $bundled.Path
        return
    }

    # 3. PSGallery fallback (Save-Module → no admin rights required)
    Write-Log "No bundled $Name $Version. Downloading from PSGallery…"
    try {
        Save-Module -Name $Name -MinimumVersion $Version -Path $VENDOR_MODULES_DIR `
            -Force -Repository PSGallery -ErrorAction Stop
        Write-OK "$Name saved to scripts/modules/$Name/"
        $bundled = Get-BundledModulePath -Name $Name -Version $Version
        if ($bundled) {
            Copy-ModuleToUserPath -Name $Name -Version $bundled.ActualVersion -SrcDir $bundled.Path
            return
        }
    } catch {
        Write-Err "PSGallery download failed: $($_.Exception.Message)"
    }
    Write-Err "To fix: copy '$Name' from a SCOM server / connected machine to scripts/modules/$Name/<version>/"
}

function Install-RequiredModules {
    Write-Log "Installing PowerShell modules…"
    foreach ($m in $REQUIRED_MODULES) { Install-RequiredModule -Name $m.Name -Version $m.Version }
}

# =============================================================================
# BINARY TOOLS (Oh My Posh, GNU make, checkmake)
# =============================================================================

# Generic helper: locate a binary in the project bin/ dir or system PATH.
# If found, ensures it's on PATH (both session and persistent).  Returns $true.
function Find-LocalBinary {
    param([string]$BinaryName)            # e.g. 'checkmake.exe'
    # 1. Already in PATH?
    if (Get-Command $BinaryName -ErrorAction SilentlyContinue) { return $true }
    # 2. Project bin/?
    $binPath = Join-Path $BIN_DIR $BinaryName
    if (Test-Path $binPath) { Add-BinToPath -Dir $BIN_DIR; return $true }
    return $false
}

function Install-OhMyPosh {
    $bin = 'oh-my-posh.exe'
    if (Find-LocalBinary -BinaryName $bin) {
        $src = Join-Path $BIN_DIR $bin
        if (Test-Path $src) {
            $destDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'bin'
            $dest    = Join-Path $destDir $bin
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                Copy-Item -Path $src -Destination $dest -Force
                Write-OK "Oh My Posh installed to $dest"
            }
        }
        return
    }
    Write-Warn "Oh My Posh binary not found in bin/. Skipping."
    Write-Warn "If .exe execution is blocked (AppLocker etc.), add oh-my-posh.exe to bin/ or use a pure-PS profile prompt."
}

function Install-Make {
    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or
             $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $PSVersionTable.Platform
    if (-not $isWin) { Write-Log "Non-Windows platform — skipping make detection"; return }

    if (Find-LocalBinary -BinaryName 'make.exe') {
        Write-OK "make: $((make --version 2>$null | Select-Object -First 1))"
        return
    }

    # Search known Git-for-Windows install locations
    $candidates = @(
        'C:\Program Files\Git\usr\bin\make.exe',
        'C:\Program Files (x86)\Git\usr\bin\make.exe',
        'C:\Program Files\Git\mingw64\bin\make.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) {
            Add-BinToPath -Dir (Split-Path $p)
            Write-OK "make available from Git for Windows"
            return
        }
    }

    Write-Warn "make not found. Install Git for Windows or place make.exe in $BIN_DIR"
}

function Install-Checkmake {
    if (Find-LocalBinary -BinaryName 'checkmake.exe') { Write-OK "checkmake found"; return }

    $isWin = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
    $os    = if ($isWin)   { 'windows' }
             elseif ($IsLinux)  { 'linux' }
             elseif ($IsMacOS)  { 'darwin' } else { 'windows' }
    $arch  = if ($isWin) {
        if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { 'arm64' }
        elseif ($env:PROCESSOR_ARCHITECTURE -match 'X86') { '386' } else { 'amd64' }
    } else {
        try { if ((& uname -m 2>$null) -match 'aarch64|arm64') { 'arm64' } else { 'amd64' } } catch { 'amd64' }
    }
    $ver  = '0.2.2'
    $exe  = if ($os -eq 'windows') { 'checkmake.exe' } else { 'checkmake' }
    $dest = Join-Path $BIN_DIR $exe

    New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null
    try {
        $url = "https://github.com/mrtazz/checkmake/releases/download/$ver/checkmake-$ver.$os.$arch"
        Write-Log "Downloading checkmake v$ver for $os/$arch…"
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        if ($os -ne 'windows') { chmod +x $dest }
        Add-BinToPath -Dir $BIN_DIR
        Write-OK "checkmake v$ver downloaded"
    } catch {
        Write-Warn "checkmake download failed (404 / offline). Manual install: $dest"
    }
}

# =============================================================================
# SUMMARY + MAIN
# =============================================================================

function Show-Summary {
    $ok = ($REQUIRED_MODULES | ForEach-Object {
        $m = Get-Module $_.Name -ListAvailable -ErrorAction SilentlyContinue |
             Sort-Object Version -Descending | Select-Object -First 1
        [pscustomobject]@{ Name = $_.Name; Version = if ($m) { $m.Version } else { '— MISSING' } }
    })
    Write-Host ""
    Write-Host "${C_GREEN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    Write-Host "${C_GREEN}║  ${C_CYAN}HPE ProLiant ISO Automation — Setup Complete${C_GREEN}         ║${C_RESET}"
    Write-Host "${C_GREEN}╚══════════════════════════════════════════════════════╝${C_RESET}"
    Write-Host ""
    foreach ($item in $ok) {
        $icon = if ($item.Version -eq '— MISSING') { "${C_RED}✗${C_RESET}" } else { "${C_GREEN}✓${C_RESET}" }
        Write-Host "  $icon $($item.Name) $($item.Version)"
    }
    Write-Host ""
    Write-Host "  Log file : $LOG_FILE"
    Write-Host "  Tests    : make test"
    Write-Host "  Lint     : make lint"
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        Write-Host "  ${C_YELLOW}make not installed — run scripts directly:${C_RESET} pwsh -File scripts/run-tests.ps1"
    }
}

function Main {
    Write-Host ""
    Write-Host "${C_CYAN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    Write-Host "${C_CYAN}║  HPE ProLiant ISO Automation — PowerShell Setup     ║${C_RESET}"
    Write-Host "${C_CYAN}╚══════════════════════════════════════════════════════╝${C_RESET}"
    Write-Host ""
    Test-PowerShellVersion
    Install-RequiredModules
    Install-OhMyPosh
    Install-Make
    Install-Checkmake
    Show-Summary
    Write-OK 'Setup complete'
}

Main
