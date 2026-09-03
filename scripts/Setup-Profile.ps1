#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup-Profile.ps1 - Configure PowerShell profiles with Automation module.

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

.PARAMETER Merge
    When a profile exists, preserve user customizations (functions, aliases)
    by merging them with the template instead of overwriting. User-added
    functions/aliases that don't exist in the template are preserved.

.PARAMETER ForceOverwrite
    Force overwrite the profile even when -Merge would be used (useful to
    reset to a clean template state).

.PARAMETER Uninstall
    Remove the Automation module block from profiles instead of installing.

.PARAMETER DryRun
    Simulate changes without actually modifying profile files.

.EXAMPLE
    pwsh -File scripts/Setup-Profile.ps1
    pwsh -File scripts/Setup-Profile.ps1 -SkipTemplateCopy
    pwsh -File scripts/Setup-Profile.ps1 -Uninstall
    pwsh -File scripts/Setup-Profile.ps1 -Merge
#>

# =============================================================================
# Setup-Profile.ps1 - Configure PowerShell profiles with Automation module
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
    [switch]$ForceOverwrite,
    [string]$ProfileRoot
)

$ErrorActionPreference = 'Stop'

# Colors for output
$Green = "`e[0;32m"
$Cyan = "`e[0;36m"
$Yellow = "`e[1;33m"
$Red = "`e[0;31m"
$Reset = "`e[0m"

function Write-Color {
    <#
    .SYNOPSIS
        Writes color.
    #>

    param([string]$Color, [string]$Message)
    Write-Output "${Color}${Message}${Reset}"
}

# Determine repo root from script location
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path $ScriptDir -Parent
$AutomationPath = Join-Path $RepoRoot 'src/powershell/Automation'
$AutomationModule = Join-Path $AutomationPath 'Automation.psd1'

# The block to add to profiles (defined early since it's used in Set-ContentProfilePair)
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

# HPE OneView module (locked version, Windows-only) - pre-load so OneView
# commands (Connect-OneView, Test-ServerConnectivity, etc.) are available the
# moment a shell opens on Windows. Only HPEOneView.1000 is permitted; stray
# versions (.820/.860) are rejected by Connect-OneViewSession's module guard.
# Skipped on Linux/macOS where the HPEOneView module cannot load.
if (`$IsWindows) {
    Import-Module HPEOneView.1000 -ErrorAction SilentlyContinue
}
"@

if (-not (Test-Path $AutomationModule)) {
    Write-Color $Red "ERROR: Automation module not found at: $AutomationModule"
    exit 1
}

Write-Color $Cyan "[setup] Configuring PowerShell profiles with Automation module..."

# ─── Determine platform-appropriate WIP template paths ───────────────────────
function Resolve-TerminalTemplate {
    <#
    .SYNOPSIS
        Resolves the PowerShell profile template to apply for a given host.

    .DESCRIPTION
        Selects the correct WIP profile template path based on the target
        computer name. On Windows, the name is normalized (dashes, underscores
        and spaces removed) and matched against known host patterns:

          * EIS19 hosts  -> wip/eis19profile.ps1
          * VDI hosts    -> wip/techvdi-profile.ps1
          * all others   -> wip/windowspsprofile.ps1 (default)

        The normalization prevents hosts like 'eis-19' from falling through to
        the default template and incorrectly inheriting a corporate proxy, which
        breaks Connect-OVMgmt against internal HPE OneView appliances.

        On Linux/macOS a separate template is chosen by the caller (see usage
        of $TerminalTemplate below).

    .PARAMETER ComputerName
        Computer name used to pick the template. Callers pass
        [System.Environment]::MachineName.

    .PARAMETER RepoRoot
        Root path of the repository, used to resolve template file paths.

    .EXAMPLE
        PS> Resolve-TerminalTemplate -ComputerName ([System.Environment]::MachineName) -RepoRoot $RepoRoot

        Returns the EIS19 template path for an 'eis-19' host, otherwise the
        default template.

    .OUTPUTS
        [string] Fully-qualified path to the chosen profile template.
    #>
    param([string]$ComputerName, [string]$RepoRoot)
    $templates = @{
        EIS19   = Join-Path $RepoRoot 'wip/eis19profile.ps1'
        TECHVDI = Join-Path $RepoRoot 'wip/techvdi-profile.ps1'
        DEFAULT = Join-Path $RepoRoot 'wip/windowspsprofile.ps1'
    }
    # Normalize: drop separators (-, _, space) so 'EIS-19' / 'eis_19' both match
    # 'eis19'. Without this the real host 'eis-19' fails the check and falls
    # through to the greedy 'prod' branch below.
    $name = if ($ComputerName) { ($ComputerName -replace '[-_\s]', '').ToLowerInvariant() } else { '' }
    if ($name -match 'eis19' -and (Test-Path $templates.EIS19)) {
        return $templates.EIS19
    }
    # Only route genuine VDI hosts to the techvdi template. The bare 'prod'
    # substring previously also matched unrelated production automation hosts
    # (e.g. eis-19) and wrongly inherited the corporate proxy, which breaks
    # Connect-OVMgmt against internal OneView appliances (504 via proxy tunnel).
    if ($name -match 'vdi' -and (Test-Path $templates.TECHVDI)) {
        return $templates.TECHVDI
    }
    return $templates.DEFAULT
}

$isWin = $IsWindows -or $null -eq $IsWindows

# ─── ProfileRoot (test hook) ──────────────────────────────────────────────────
# When -ProfileRoot is supplied, every live profile path is written under that
# directory instead of the real user profile location. This lets the script be
# exercised by tests without mutating the operator's actual $PROFILE.
$profileBase = if ($ProfileRoot) {
    $ProfileRoot
} elseif ($isWin) {
    $env:USERPROFILE
} else {
    $HOME
}

# Primary terminal profile template (Windows Terminal / pwsh console).
# On Windows the template is chosen per-machine by computer name (see
# Resolve-TerminalTemplate); on Linux/macOS there is a single template.
$TerminalTemplate = if ($isWin) {
    Resolve-TerminalTemplate -ComputerName ([System.Environment]::MachineName) -RepoRoot $RepoRoot
} else {
    Join-Path $RepoRoot 'wip/psprofile.ps1'
}
# VS Code profile template (cross-platform, identical regardless of OS)
$VsCodeTemplate = Join-Path $RepoRoot 'wip/vscodeprofile.ps1'

# ─── Determine live profile destination paths ────────────────────────────────
$LiveProfiles = @{}

if ($isWin) {
    # PowerShell 7+ ("Core") profile location
    $LiveProfiles['Terminal'] = Join-Path $profileBase 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    $LiveProfiles['VsCode'] = Join-Path $profileBase 'Documents\PowerShell\Microsoft.VSCode_profile.ps1'
    # Windows PowerShell 5.1 profile location (separate directory)
    $LiveProfiles['Terminal51'] = Join-Path $profileBase 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
} else {
    $LiveProfiles['Terminal'] = Join-Path $profileBase '.config/powershell/Microsoft.PowerShell_profile.ps1'
    $LiveProfiles['VsCode'] = Join-Path $profileBase '.config/powershell/Microsoft.VSCode_profile.ps1'
}

# ─── Utility: Smart merge profile with template, preserving user customizations ───
function Set-ContentProfilePair {
    <#
    .SYNOPSIS
        Set content profile pair.
    #>

    param(
        [string]$TemplatePath,
        [string]$LivePath,
        [string]$ProfileBlock
    )
    
    # If live profile doesn't exist, just copy template
    if (-not (Test-Path $LivePath)) {
        if (Test-Path $TemplatePath) {
            Copy-Item -Path $TemplatePath -Destination $LivePath -Force
            Write-Color $Green "[setup] ✓ Created $(Split-Path $LivePath -Leaf) from template"
        }
        return
    }
    
    $liveContent = Get-Content $LivePath -Raw
    $templateContent = Get-Content $TemplatePath -Raw
    
    # Check if live profile already has the Automation block - just update if so
    if ($liveContent -match '# Image Build Automation module') {
        Write-Color $Yellow "[setup] Profile already has Automation module - updating path..."
        $NewContent = $liveContent -replace '(?s)# Image Build Automation module.*?(?=\n\n#|\n$|$)', $ProfileBlock.Trim()
        $NewContent | Set-Content $LivePath -Encoding UTF8
        Write-Color $Green "[setup] ✓ Updated Automation module path"
        return
    }
    
    # Merge mode: append Automation block to existing profile (preserve user customizations)
    if ($Merge) {
        Write-Color $Cyan "[setup] Merging Automation module into existing profile..."
        $merged = $liveContent.TrimEnd() + "`n`n# Image Build Automation module`n"
        $merged += " `$automationModulePath = '$AutomationModule'`n"
        $merged += " if (Test-Path `$automationModulePath) {`n"
        $merged += "     Import-Module `$automationModulePath -WarningAction SilentlyContinue`n"
        $merged += " }`n"
        $merged += " if (`$IsWindows) { Import-Module HPEOneView.1000 -ErrorAction SilentlyContinue }`n"
        $merged | Set-Content $LivePath -Encoding UTF8
        Write-Color $Green "[setup] ✓ Added Automation module (existing customizations preserved)"
    } elseif ($ForceOverwrite) {
        # Force overwrite without backup
        Copy-Item -Path $TemplatePath -Destination $LivePath -Force
        Write-Color $Green "[setup] ✓ Forced overwrite: $(Split-Path $TemplatePath -Leaf) -> $(Split-Path $LivePath -Leaf)"
    } else {
        # Default: backup and overwrite
        $backup = "$LivePath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
        Copy-Item $LivePath $backup -Force
        Write-Color $Cyan "[setup]   Backed up existing profile to $(Split-Path $backup -Leaf)"
        Copy-Item -Path $TemplatePath -Destination $LivePath -Force
        Write-Color $Green "[setup] ✓ Installed $(Split-Path $TemplatePath -Leaf) -> $(Split-Path $LivePath -Leaf)"
    }
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
            Write-Color $Yellow "[setup] DRY RUN: Would set up $(Split-Path $TerminalTemplate -Leaf) -> $dest"
        } else {
            Set-ContentProfilePair -TemplatePath $TerminalTemplate -LivePath $dest -ProfileBlock $ProfileBlock
        }
    } else {
        Write-Color $Yellow "[setup] WIP template not found: $TerminalTemplate"
    }

    # Windows PowerShell 5.1 profile (only if that profile dir already exists -
    # avoid creating Documents\WindowsPowerShell\ on PS 7-only machines)
    if ($isWin -and (Test-Path $TerminalTemplate)) {
        $ps51Path = $LiveProfiles['Terminal51']
        $ps51Dir = Split-Path $ps51Path -Parent
        if (Test-Path $ps51Dir) {
            if ($DryRun) {
                Write-Color $Yellow "[setup] DRY RUN: Would set up $(Split-Path $TerminalTemplate -Leaf) -> $ps51Path (PS 5.1)"
            } else {
                Set-ContentProfilePair -TemplatePath $TerminalTemplate -LivePath $ps51Path -ProfileBlock $ProfileBlock
            }
        }
    }

    # VS Code profile (only if VS Code profile dir exists - avoid creating it
    # on machines where VS Code isn't installed)
    $vsCodeDir = Split-Path $LiveProfiles['VsCode'] -Parent
    if ((Test-Path $VsCodeTemplate) -and (Test-Path $vsCodeDir)) {
        $dest = $LiveProfiles['VsCode']
        if ($DryRun) {
            Write-Color $Yellow "[setup] DRY RUN: Would set up $(Split-Path $VsCodeTemplate -Leaf) -> $dest"
        } else {
            # Check for existing Automation block in VS Code profile too
            $vscContent = if (Test-Path $dest) { Get-Content $dest -Raw } else { $null }
            if ($vscContent -match '# Image Build Automation module') {
                Write-Color $Yellow "[setup] VS Code profile already has Automation module - updating path..."
                $NewContent = $vscContent -replace '(?s)# Image Build Automation module.*?(?=\n\n#|\n$|$)', $ProfileBlock.Trim()
                $NewContent | Set-Content $dest -Encoding UTF8
                Write-Color $Green "[setup] ✓ Updated VS Code profile"
            } else {
                Set-ContentProfilePair -TemplatePath $VsCodeTemplate -LivePath $dest -ProfileBlock $ProfileBlock
            }
        }
    } elseif (-not (Test-Path $vsCodeDir)) {
        Write-Color $Cyan "[setup] VS Code profile dir not found - skipping VS Code profile"
    }
} elseif ($SkipTemplateCopy -and -not $Uninstall) {
    Write-Color $Cyan "[setup] -SkipTemplateCopy: leaving existing profiles, only refreshing module import"
}

# Find all profile paths to update (live profiles only - not WIP templates).
$ProfilePaths = @()

# Add the live profiles we identified above (if they exist or were just copied)
foreach ($key in @('Terminal', 'Terminal51', 'VsCode')) {
    $p = $LiveProfiles[$key]
    if ($p -and (Test-Path $p)) {
        $ProfilePaths += $p
    }
}

# Also pick up $PROFILE in case it points somewhere unexpected.
# Skipped when -ProfileRoot is set so tests never touch the real profile.
if (-not $ProfileRoot -and $PROFILE -and ($ProfilePaths -notcontains $PROFILE) -and (Test-Path $PROFILE)) {
    $ProfilePaths += $PROFILE
}

if ($ProfilePaths.Count -eq 0) {
    Write-Color $Yellow "[setup] WARNING: No PowerShell profiles found. Creating default profile..."
    $DefaultProfile = if (($IsLinux -or $IsMacOS)) {
        Join-Path $profileBase '.config/powershell/Microsoft.PowerShell_profile.ps1'
    } else {
        Join-Path $profileBase 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
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

Write-Output ""
if ($Uninstall) {
    Write-Color $Green "[setup] ✓ Uninstall complete"
} else {
    Write-Color $Green "[setup] ✓ Profile configuration complete"
    Write-Color $Yellow "[setup] Restart your PowerShell session or run '. `$PROFILE' to load"
}
Write-Output ""
