# Setup Guide - PowerShell Profile & Maintenance Mode

## Quick Setup (5 Minutes)

### Step 1: Install PowerShell Module

```powershell
# From the project root directory
make setup
```

This installs required PowerShell modules and configures your profile.

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

### Step 3: Verify Installation

```powershell
# Check if Set-MaintenanceMode is available
Get-Command Set-MaintenanceMode

# Test with a dry run
Set-MaintenanceMode -Action validate -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -DryRun
```

---

## What Gets Installed

### Profile Features
- ✅ **oh-my-posh theme** (cross-platform: Windows/Linux/macOS)
- ✅ **Automation module** auto-import
- ✅ **Set-MaintenanceMode** command for maintenance mode
- ✅ **Git integration** (posh-git)
- ✅ **Terminal icons** and enhanced UX

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `Set-MaintenanceMode` | Full maintenance mode control | `Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod` |

---

## Manual Setup (If make setup Fails)

### 1. Import the Module

Add this to your PowerShell profile (`$PROFILE`):

```powershell
$AutomationModulePath = '/home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $AutomationModulePath) {
    Import-Module $AutomationModulePath -WarningAction SilentlyContinue
}
```

### 2. Import the Module

Add this to your PowerShell profile (`$PROFILE`):

```powershell
$AutomationModulePath = '/home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $AutomationModulePath) {
    Import-Module $AutomationModulePath -WarningAction SilentlyContinue
}
```

### 3. Find Your Profile Path

```powershell
# Shows the path to your PowerShell profile
echo $PROFILE
```

### 4. Edit Your Profile

```powershell
# Open profile in your editor
code $PROFILE        # VS Code
notepad $PROFILE     # Windows Notepad
nano $PROFILE        # Linux/Mac terminal editor
```



## Manual Installation

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

## Uninstall

To remove the functions from your profiles:

```bash
pwsh -File scripts/Setup-Profile.ps1 -Uninstall
```---

## Troubleshooting

### Profile Not Loading

```powershell
# Check if profile exists
Test-Path $PROFILE

# Create profile if it doesn't exist
New-Item -ItemType File -Path $PROFILE -Force

# View profile content
Get-Content $PROFILE
```

### Module Not Found

```powershell
# Check module path
Test-Path /home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1

# Import manually
Import-Module /home/keverall/repos/image-build-automation/src/powershell/Automation/Automation.psd1 -Force
```

### Set-MaintenanceMode Command Not Available

```powershell
# Reload profile
. $PROFILE

# Check if Set-MaintenanceMode is available
Get-Command Set-MaintenanceMode -ErrorAction SilentlyContinue
```

### Wrong Terminal Type

Make sure you're using **PowerShell**, not bash/fish:

```powershell
# Check current shell
echo $SHELL        # Should show pwsh or powershell

# Start PowerShell if in bash
pwsh
```

---

## Next Steps

- Read [MAINTENANCE_MODE_SHORTCUTS.md](MAINTENANCE_MODE_SHORTCUTS.md) for usage examples
- See [MAINTENANCE_MODE_SHORTCUTS.md](MAINTENANCE_MODE_SHORTCUTS.md) for all options
- Check [README.md](../README.md) for project overview
