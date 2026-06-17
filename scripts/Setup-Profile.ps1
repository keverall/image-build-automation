#!/usr/bin/env pwsh
# =============================================================================
# Setup-Profile.ps1 — Configure PowerShell profiles with Automation module
# =============================================================================
# Adds maintenance mode convenience functions to PowerShell profiles.
# Can be run from anywhere - uses the script's repo root as the base path.
# =============================================================================

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$DryRun
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

# The block to add to profiles
$ProfileBlock = @"

# Image Build Automation module
`$automationModulePath = '$AutomationModule'
if (Test-Path `$automationModulePath) {
    Import-Module `$automationModulePath -WarningAction SilentlyContinue
    
    # Maintenance mode convenience functions
    function mm { Set-MaintenanceMode @args }
    
    function mmenable {
        param(
            [Parameter(Position=0,Mandatory)][string]`$TargetId,
            [Parameter(Position=1)][ValidateSet('scom','oneview')][string]`$Mode = 'scom',
            [Parameter(Position=2)][ValidateSet('Test','Prod')][string]`$Environment = 'Prod',
            [string]`$Start = 'now',
            [string]`$End = '+2hours',
            [switch]`$DryRun
        )
        `$p = @{
            Action = 'enable'
            TargetId = `$TargetId
            Mode = `$Mode
            Environment = `$Environment
            Start = `$Start
            End = `$End
        }
        if (`$DryRun) { `$p['DryRun'] = `$true }
        Set-MaintenanceMode @p
    }
    
    function mmdisable {
        param(
            [Parameter(Position=0,Mandatory)][string]`$TargetId,
            [Parameter(Position=1)][ValidateSet('scom','oneview')][string]`$Mode = 'scom',
            [Parameter(Position=2)][ValidateSet('Test','Prod')][string]`$Environment = 'Prod'
        )
        Set-MaintenanceMode -Action disable -TargetId `$TargetId -Mode `$Mode -Environment `$Environment
    }
    
    function mmvalidate {
        param(
            [Parameter(Position=0,Mandatory)][string]`$TargetId,
            [Parameter(Position=1)][ValidateSet('scom','oneview')][string]`$Mode = 'scom',
            [Parameter(Position=2)][ValidateSet('Test','Prod')][string]`$Environment = 'Prod'
        )
        Set-MaintenanceMode -Action validate -TargetId `$TargetId -Mode `$Mode -Environment `$Environment
    }
}

# Offline, no-.exe fallback prompt (Powerline-style, bypasses Oh-My-Posh AppLocker blocks)
function global:prompt {
    `$host.UI.RawUI.WindowTitle = "Automation: `$(Get-Location)"
    
    `$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # Path normalization
    `$path = `$PWD.Path
    if (`$env:USERPROFILE -and `$path.StartsWith(`$env:USERPROFILE, "CurrentCultureIgnoreCase")) {
        `$path = "~" + `$path.Substring(`$env:USERPROFILE.Length)
    }
    `$path = `$path -replace '\\\\', '/'
    
    # Git branch detection
    `$gitBranch = `$null
    if (Test-Path .git) {
        `$gitBranch = & git branch --show-current 2>`$null
    }
    
    # Segment 1: Admin/User Indicator
    if (`$isAdmin) {
        Write-Host " ⚡ ADMIN " -NoNewline -BackgroundColor DarkRed -ForegroundColor White
    } else {
        Write-Host " 👤 USER " -NoNewline -BackgroundColor DarkGray -ForegroundColor White
    }
    
    # Separator to Path
    if (`$isAdmin) {
        Write-Host "" -NoNewline -BackgroundColor DarkRed -ForegroundColor Blue
    } else {
        Write-Host "" -NoNewline -BackgroundColor DarkGray -ForegroundColor Blue
    }
    
    # Segment 2: Current Path
    Write-Host " `$path " -NoNewline -BackgroundColor Blue -ForegroundColor White
    
    # Segment 3: Git Branch (if in a repository)
    if (`$gitBranch) {
        Write-Host "" -NoNewline -BackgroundColor Blue -ForegroundColor DarkYellow
        Write-Host "  `$gitBranch " -NoNewline -BackgroundColor DarkYellow -ForegroundColor Black
        `$lastBg = "DarkYellow"
    } else {
        `$lastBg = "Blue"
    }
    
    # Final Prompt Character
    Write-Host "" -NoNewline -BackgroundColor `$lastBg -ForegroundColor Black
    if (`$isAdmin) {
        Write-Host " # " -NoNewline -ForegroundColor Red
    } else {
        Write-Host " ❯ " -NoNewline -ForegroundColor Cyan
    }
    
    return " "
}
"@

# Find all profile paths to update
$ProfilePaths = @()

# Standard PowerShell profile locations
if ($PROFILE) {
    $ProfilePaths += $PROFILE
}

# Cross-platform profile locations
if ($IsLinux -or $IsMacOS) {
    $LinuxProfile = '~/.config/powershell/Microsoft.PowerShell_profile.ps1'
    if (Test-Path $LinuxProfile) {
        $ProfilePaths += $LinuxProfile
    }
} elseif ($IsWindows -or $null -eq $IsWindows) {
    $WindowsProfile = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
    if (Test-Path $WindowsProfile) {
        $ProfilePaths += $WindowsProfile
    }
}

# Add WIP profiles if they exist in the repo
$WipProfiles = @(
    (Join-Path $RepoRoot 'wip/psprofile.ps1'),
    (Join-Path $RepoRoot 'wip/vscodeprofile.ps1')
)
foreach ($wip in $WipProfiles) {
    if (Test-Path $wip) {
        $ProfilePaths += $wip
    }
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
