#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup-Profile.ps1 — Configure PowerShell profiles with Automation module.

.DESCRIPTION
    Copies the correct WIP profile template to the live profile location
    (platform-aware: windowspsprofile.ps1 on Windows, psprofile.ps1 on
    Linux/macOS, vscodeprofile.ps1 for the VS Code profile), then injects
    the Automation module import block (with the machine-specific absolute
    path) into the live profile(s).
    Can be run from anywhere - uses the script's repo root as the base path.

.PARAMETER SkipTemplateCopy
    Skip copying the WIP template over the live profile. Only inject/refresh
    the Automation module import block. Useful if the live profile has been
    manually customised and should not be overwritten.

.PARAMETER Uninstall
    Remove the Automation module block from profiles instead of installing.

.PARAMETER DryRun
    Simulate changes without actually modifying profile files.

.EXAMPLE
    pwsh -File scripts/Setup-Profile.ps1
    pwsh -File scripts/Setup-Profile.ps1 -SkipTemplateCopy
    pwsh -File scripts/Setup-Profile.ps1 -Uninstall
#>

# =============================================================================
# Setup-Profile.ps1 — Configure PowerShell profiles with Automation module
# =============================================================================
# 1. Copies the platform-appropriate WIP profile template to the live
#    profile location (Windows Terminal/PowerShell + VS Code).
# 2. Injects the Automation module import block (machine-specific path) into
#    the live profile(s).
# Can be run from anywhere - uses the script's repo root as the base path.
# =============================================================================

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$DryRun,
    [switch]$SkipTemplateCopy,
    [switch]$Merge,
    [switch]$ForceOverwrite
)

$ErrorActionPreference = 'Stop'

# Colors for output
$Green = "`e[0;32m"
$Cyan = "`e[0;36m"
$Yellow = "`e[1;33m"
$Red = "`e[0;31m"
$Reset = "`e[0m"

function Write-Color {
    param([string]$Color, [string]$Message)
    Write-Host "${Color}${Message}${Reset}"
}

# Determine repo root from script location
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path $ScriptDir -Parent
$AutomationPath = Join-Path $RepoRoot 'src/powershell/Automation'
$AutomationModule = Join-Path $AutomationPath 'Automation.psd1'

if (-not (Test-Path $AutomationModule)) {
    Write-Color $Red "ERROR: Automation module not found at: $AutomationModule"
    exit 1
}

Write-Color $Cyan "[setup] Configuring PowerShell profiles with Automation module..."

# ─── Determine platform-appropriate WIP template paths ───────────────────────
$isWin = $IsWindows -or $null -eq $IsWindows

# Primary terminal profile template (Windows Terminal / pwsh console)
$TerminalTemplate = if ($isWin) {
    Join-Path $RepoRoot 'wip/windowspsprofile.ps1'
} else {
    Join-Path $RepoRoot 'wip/psprofile.ps1'
}
# VS Code profile template (cross-platform, identical regardless of OS)
$VsCodeTemplate = Join-Path $RepoRoot 'wip/vscodeprofile.ps1'

# ─── Determine live profile destination paths ────────────────────────────────
$LiveProfiles = @{}

if ($isWin) {
    # PowerShell 7+ ("Core") profile location
    $LiveProfiles['Terminal'] = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    $LiveProfiles['VsCode'] = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.VSCode_profile.ps1'
    # Windows PowerShell 5.1 profile location (separate directory)
    $LiveProfiles['Terminal51'] = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
} else {
    $LiveProfiles['Terminal'] = Join-Path $HOME '.config/powershell/Microsoft.PowerShell_profile.ps1'
    $LiveProfiles['VsCode'] = Join-Path $HOME '.config/powershell/Microsoft.VSCode_profile.ps1'
}

# ─── Copy WIP templates to live profile locations ────────────────────────────
if (-not $Uninstall -and -not $SkipTemplateCopy) {
    Write-Color $Cyan "[setup] Copying WIP profile templates to live profile locations..."

    if (Test-Path $TerminalTemplate) {
        $dest = $LiveProfiles['Terminal']
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        if ($DryRun) {
            Write-Color $Yellow "[setup] DRY RUN: Would copy $(Split-Path $TerminalTemplate -Leaf) -> $dest"
        } else {
            # Backup existing profile before overwrite (preserves user customisations/secrets)
            if (Test-Path $dest) {
                $backup = "$dest.bak.$(Get-Date -Format yyyyMMddHHmmss)"
                Copy-Item $dest $backup -Force
                Write-Color $Cyan "[setup]   Backed up existing profile to $(Split-Path $backup -Leaf)"
            }
            Copy-Item -Path $TerminalTemplate -Destination $dest -Force
            Write-Color $Green "[setup] ✓ Copied $(Split-Path $TerminalTemplate -Leaf) -> $(Split-Path $dest -Leaf)"
        }
    } else {
        Write-Color $Yellow "[setup] WIP template not found: $TerminalTemplate"
    }

    # Windows PowerShell 5.1 profile (only if that profile dir already exists —
    # avoid creating Documents\WindowsPowerShell\ on PS 7-only machines)
    if ($isWin -and (Test-Path $TerminalTemplate)) {
        $ps51Path = $LiveProfiles['Terminal51']
        $ps51Dir = Split-Path $ps51Path -Parent
        if (Test-Path $ps51Dir) {
            if ($DryRun) {
                Write-Color $Yellow "[setup] DRY RUN: Would copy $(Split-Path $TerminalTemplate -Leaf) -> $ps51Path (PS 5.1)"
            } else {
                # Backup existing before overwrite (see backup logic below)
                $backup = "$ps51Path.bak.$(Get-Date -Format yyyyMMddHHmmss)"
                if (Test-Path $ps51Path) { Copy-Item $ps51Path $backup -Force }
                Copy-Item -Path $TerminalTemplate -Destination $ps51Path -Force
                Write-Color $Green "[setup] ✓ Copied $(Split-Path $TerminalTemplate -Leaf) -> $(Split-Path $ps51Path -Leaf) (PS 5.1)"
            }
        }
    }

    # VS Code profile (only if VS Code profile dir exists — avoid creating it
    # on machines where VS Code isn't installed)
    $vsCodeDir = Split-Path $LiveProfiles['VsCode'] -Parent
    if ((Test-Path $VsCodeTemplate) -and (Test-Path $vsCodeDir)) {
        $dest = $LiveProfiles['VsCode']
        if ($DryRun) {
            Write-Color $Yellow "[setup] DRY RUN: Would copy $(Split-Path $VsCodeTemplate -Leaf) -> $dest"
        } else {
            # Backup existing before overwrite
            if (Test-Path $dest) {
                $backup = "$dest.bak.$(Get-Date -Format yyyyMMddHHmmss)"
                Copy-Item $dest $backup -Force
            }
            Copy-Item -Path $VsCodeTemplate -Destination $dest -Force
            Write-Color $Green "[setup] ✓ Copied $(Split-Path $VsCodeTemplate -Leaf) -> $(Split-Path $dest -Leaf)"
        }
    } elseif (-not (Test-Path $vsCodeDir)) {
        Write-Color $Cyan "[setup] VS Code profile dir not found — skipping VS Code profile"
    }
} elseif ($SkipTemplateCopy -and -not $Uninstall) {
    Write-Color $Cyan "[setup] -SkipTemplateCopy: leaving existing profiles, only refreshing module import"
}

# The block to add to profiles.
# NOTE: This block intentionally does NOT define a prompt function. The
# oh-my-posh prompt is configured by the WIP profile templates themselves,
# and the Powerline fallback prompt lives in each WIP template
# (windowspsprofile/psprofile/vscodeprofile), wrapped in an `else` branch
# so it only activates when oh-my-posh is unavailable. Injecting a
# global:prompt here would override oh-my-posh on every platform.
$ProfileBlock = @"

# Image Build Automation module
`$automationModulePath = '$AutomationModule'
if (Test-Path `$automationModulePath) {
    Import-Module `$automationModulePath -WarningAction SilentlyContinue
}
"@

# Find all profile paths to update (live profiles only — not WIP templates).
$ProfilePaths = @()

# Add the live profiles we identified above (if they exist or were just copied)
foreach ($key in @('Terminal', 'Terminal51', 'VsCode')) {
    $p = $LiveProfiles[$key]
    if ($p -and (Test-Path $p)) {
        $ProfilePaths += $p
    }
}

# Also pick up $PROFILE in case it points somewhere unexpected
if ($PROFILE -and ($ProfilePaths -notcontains $PROFILE) -and (Test-Path $PROFILE)) {
    $ProfilePaths += $PROFILE
}

if ($ProfilePaths.Count -eq 0) {
    Write-Color $Yellow "[setup] WARNING: No PowerShell profiles found. Creating default profile..."
    $DefaultProfile = if (($IsLinux -or $IsMacOS)) {
        '~/.config/powershell/Microsoft.PowerShell_profile.ps1'
    } else {
        Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    }
    $ProfileDir = Split-Path $DefaultProfile -Parent
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    $ProfilePaths += $DefaultProfile
}

Write-Color $Cyan "[setup] Found $($ProfilePaths.Count) profile(s) to update"

foreach ($ProfilePath in $ProfilePaths) {
    $ProfileName = Split-Path $ProfilePath -Leaf
    
    if ($Uninstall) {
        # Remove the automation block from profile
        if (Test-Path $ProfilePath) {
            Write-Color $Yellow "[setup] Removing Automation module from $ProfileName..."
            $Content = Get-Content $ProfilePath -Raw
            if ($Content -match '# Image Build Automation module') {
                if (-not $DryRun) {
                    $NewContent = $Content -replace '(?s)# Image Build Automation module.*?(?=\n\n#|\n$|$)', ''
                    $NewContent | Set-Content $ProfilePath -Encoding UTF8
                    Write-Color $Green "[setup] ✓ Removed from $ProfileName"
                } else {
                    Write-Color $Yellow "[setup] DRY RUN: Would remove from $ProfileName"
                }
            } else {
                Write-Color $Yellow "[setup] $ProfileName does not contain Automation module"
            }
        }
    } else {
        # Add the automation block to profile
        $Content = if (Test-Path $ProfilePath) {
            Get-Content $ProfilePath -Raw
        } else {
            ''
        }
        
        if ($Content -match '# Image Build Automation module') {
            Write-Color $Yellow "[setup] Updating Automation module path in $ProfileName..."
            if (-not $DryRun) {
                # Replace the old block with the new one to ensure paths are updated if the repo was moved
                $NewContent = $Content -replace '(?s)# Image Build Automation module.*?(?=\n\n#|\n$|$)', $ProfileBlock.Trim()
                $NewContent | Set-Content $ProfilePath -Encoding UTF8
                Write-Color $Green "[setup] ✓ Updated in $ProfileName"
            } else {
                Write-Color $Yellow "[setup] DRY RUN: Would update $ProfileName"
            }
        } else {
            Write-Color $Green "[setup] Adding Automation module to $ProfileName..."
            if (-not $DryRun) {
                $Content += $ProfileBlock
                $Content | Set-Content $ProfilePath -Encoding UTF8
                Write-Color $Green "[setup] ✓ Added to $ProfileName"
            } else {
                Write-Color $Yellow "[setup] DRY RUN: Would add to $ProfileName"
            }
        }
    }
}

Write-Host ""
if ($Uninstall) {
    Write-Color $Green "[setup] ✓ Uninstall complete"
} else {
    Write-Color $Green "[setup] ✓ Profile configuration complete"
    Write-Color $Yellow "[setup] Restart your PowerShell session or run '. `$PROFILE' to load"
}
Write-Host ""
