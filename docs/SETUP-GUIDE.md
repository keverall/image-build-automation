# Setup Guide - PowerShell Profile & Maintenance Mode

## Table of Contents

- [Quick Setup (5 Minutes)](#quick-setup-5-minutes)
  - [Step 1: Install PowerShell Module](#step-1-install-powershell-module)
  - [Step 2: Load the Profile](#step-2-load-the-profile)
  - [Step 3: Verify Installation](#step-3-verify-installation)
- [What Gets Installed](#what-gets-installed)
  - [Profile Features](#profile-features)
  - [Available Commands](#available-commands)
- [Manual Setup (If make setup Fails)](#manual-setup-if-make-setup-fails)
  - [1. Import the Module](#1-import-the-module)
  - [2. Import the Module](#2-import-the-module)
  - [3. Find Your Profile Path](#3-find-your-profile-path)
  - [4. Edit Your Profile](#4-edit-your-profile)
- [Manual Installation](#manual-installation)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
  - [Profile Not Loading](#profile-not-loading)
  - [Module Not Found](#module-not-found)
  - [Set-MaintenanceMode Command Not Available](#set-maintenancemode-command-not-available)
  - [Wrong Terminal Type](#wrong-terminal-type)
- [Next Steps](#next-steps)


<a name="quick-setup-5-minutes"></a>
## Quick Setup (5 Minutes)

<a name="step-1-install-powershell-module"></a>
### Step 1: Install PowerShell Module

```powershell
# From the project root directory
make setup
```

This installs required PowerShell modules and configures your profile.

<a name="step-2-load-the-profile"></a>
### Step 2: Load the Profile

#### Option A: VS Code Users (Recommended)

1. Copy the VS Code profile to your PowerShell config:
   ```powershell
   cp wip/vscodeprofile.ps1 ~/.config/powershell/Microsoft.VSCode_profile.ps1
   ```

2. In VS Code, open a **PowerShell terminal** (not bash/fish):
   - Press `Ctrl+Shift+P`
   - Type "Terminal: Select Default Profile"
   - Choose "PowerShell"

3. Reload the terminal or run:
   ```powershell
   . $PROFILE
   ```

#### Option B: Regular PowerShell (Outside VS Code)

1. Copy the PowerShell profile:
   ```powershell
   cp wip/psprofile.ps1 ~/.config/powershell/Microsoft.PowerShell_profile.ps1
   ```

2. Reload your profile:
   ```powershell
   . $PROFILE
   ```

<a name="step-3-verify-installation"></a>
### Step 3: Verify Installation

```powershell
# Check if Set-MaintenanceMode is available
Get-Command Set-MaintenanceMode

# Test with a dry run
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -DryRun
```

---

<a name="what-gets-installed"></a>
## What Gets Installed

<a name="profile-features"></a>
### Profile Features
- ✅ **oh-my-posh theme** (cross-platform: Windows/Linux/macOS)
- ✅ **Automation module** auto-import
- ✅ **Set-MaintenanceMode** command for maintenance mode
- ✅ **Git integration** (posh-git)
- ✅ **Terminal icons** and enhanced UX

<a name="available-commands"></a>
### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `Set-MaintenanceMode` | Full maintenance mode control | `Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod` |

---

<a name="manual-setup-if-make-setup-fails"></a>
## Manual Setup (If make setup Fails)

<a name="1-import-the-module"></a>
### 1. Import the Module

Add this to your PowerShell profile (`$PROFILE`):

```powershell
$AutomationModulePath = '/home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $AutomationModulePath) {
    Import-Module $AutomationModulePath -WarningAction SilentlyContinue
}
```

<a name="2-import-the-module"></a>
### 2. Import the Module

Add this to your PowerShell profile (`$PROFILE`):

```powershell
$AutomationModulePath = '/home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $AutomationModulePath) {
    Import-Module $AutomationModulePath -WarningAction SilentlyContinue
}
```

<a name="3-find-your-profile-path"></a>
### 3. Find Your Profile Path

```powershell
# Shows the path to your PowerShell profile
echo $PROFILE
```

<a name="4-edit-your-profile"></a>
### 4. Edit Your Profile

```powershell
# Open profile in your editor
code $PROFILE        # VS Code
notepad $PROFILE     # Windows Notepad
nano $PROFILE        # Linux/Mac terminal editor
```



<a name="manual-installation"></a>
## Manual Installation

If you prefer to add the functions manually:

```powershell
# Add to your profile
$automationModulePath = '/path/to/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $automationModulePath) {
    Import-Module $automationModulePath -WarningAction SilentlyContinue
}
```

---

<a name="uninstall"></a>
## Uninstall

To remove the functions from your profiles:

```bash
pwsh -File scripts/Setup-Profile.ps1 -Uninstall
```---

<a name="troubleshooting"></a>
## Troubleshooting

<a name="profile-not-loading"></a>
### Profile Not Loading

```powershell
# Check if profile exists
Test-Path $PROFILE

# Create profile if it doesn't exist
New-Item -ItemType File -Path $PROFILE -Force

# View profile content
Get-Content $PROFILE
```

<a name="module-not-found"></a>
### Module Not Found

```powershell
# Check module path
Test-Path /home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1

# Import manually
Import-Module /home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1 -Force
```

<a name="set-maintenancemode-command-not-available"></a>
### Set-MaintenanceMode Command Not Available

```powershell
# Reload profile
. $PROFILE

# Check if Set-MaintenanceMode is available
Get-Command Set-MaintenanceMode -ErrorAction SilentlyContinue
```

<a name="wrong-terminal-type"></a>
### Wrong Terminal Type

Make sure you're using **PowerShell**, not bash/fish:

```powershell
# Check current shell
echo $SHELL        # Should show pwsh or powershell

# Start PowerShell if in bash
pwsh
```

---

<a name="next-steps"></a>
## Next Steps

- Read [MAINTENANCE_MODE_SHORTCUTS.md](Maintenance-Mode/MAINTENANCE_MODE_SHORTCUTS.md) for usage examples
- See [MAINTENANCE_MODE_SHORTCUTS.md](Maintenance-Mode/MAINTENANCE_MODE_SHORTCUTS.md) for all options
- Check [README.md](../README.md) for project overview

