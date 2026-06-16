# PowerShell Profile Setup Guide

## Overview

The Image Build Automation module provides convenient maintenance mode functions that can be automatically loaded into your PowerShell profiles.

## Quick Start

### First-Time Setup

Run from anywhere in the repo:

```bash
make setup
```

Or directly:

```bash
pwsh -File scripts/Setup-Profile.ps1
```

This will:
1. Install required PowerShell modules
2. Add maintenance mode functions to all your PowerShell profiles
3. Configure auto-loading of the Automation module

### What Gets Installed

The setup adds these convenience functions to your PowerShell profiles:

- **`mm`** - Full access to `Set-MaintenanceMode` with all parameters
- **`mmenable`** - Quick enable with sensible defaults
- **`mmdisable`** - Quick disable 
- **`mmvalidate`** - Quick validate status

### Usage Examples

```powershell
# Quick enable with defaults (scom, Prod, +2hours)
mmenable CLU-CLUSTER-01

# Enable with custom time window
mmenable CLU-CLUSTER-01 scom Prod -Start now -End +4hours

# Dry run test
mmenable TEST-CLUSTER-01 scom Test -DryRun

# Disable maintenance
mmdisable CLU-CLUSTER-01

# Validate status
mmvalidate CLU-CLUSTER-01

# Full control
mm -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -Start now -End +2hours
```

## Profiles Updated

The setup script updates these profiles (if they exist):

### Windows
- `$PROFILE` (current user, current host)
- `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
- `wip/psprofile.ps1` (in repo)
- `wip/vscodeprofile.ps1` (in repo)

### Linux/macOS
- `~/.config/powershell/Microsoft.PowerShell_profile.ps1`
- `wip/psprofile.ps1` (in repo)
- `wip/vscodeprofile.ps1` (in repo)

## Manual Installation

If you prefer to add the functions manually:

```powershell
# Add to your profile
$automationModulePath = '/path/to/image-build-automation/src/powershell/Automation/Automation.psd1'
if (Test-Path $automationModulePath) {
    Import-Module $automationModulePath -WarningAction SilentlyContinue
    function mm { Set-MaintenanceMode @args }
    function mmenable { 
        param(
            [Parameter(Position=0,Mandatory)][string]$TargetId,
            [Parameter(Position=1)][ValidateSet('scom','oneview')][string]$Mode = 'scom',
            [Parameter(Position=2)][ValidateSet('Test','Prod')][string]$Environment = 'Prod',
            [string]$Start = 'now',
            [string]$End = '+2hours',
            [switch]$DryRun
        )
        $p = @{
            Action = 'enable'
            TargetId = $TargetId
            Mode = $Mode
            Environment = $Environment
            Start = $Start
            End = $End
        }
        if ($DryRun) { $p['DryRun'] = $true }
        Set-MaintenanceMode @p
    }
}
```

## Uninstall

To remove the functions from your profiles:

```bash
pwsh -File scripts/Setup-Profile.ps1 -Uninstall
```

## Features

### Time Format Support

All functions support these time formats:
- `now` - Current UTC time
- `+Xhours` - Relative hours (e.g., `+1hour`, `+2hours`)
- `+Xminutes` - Relative minutes (e.g., `+30minutes`)
- `+Xdays` - Relative days (e.g., `+1day`)
- `YYYY-MM-DD HH:MM` - Absolute UTC time
- `YYYY-MM-DDTHH:MM:SS` - ISO 8601 UTC format

### Output

All commands display:
- Start Time (UTC) in ISO 8601 format
- End Time (UTC) in ISO 8601 format
- Success/Failure status
- Error messages (if any)
- Per-object status details (for successful operations)

### Dry Run Mode

Add `-DryRun` to any command to simulate without making changes:

```powershell
mmenable TEST-CLUSTER-01 scom Test -DryRun
```

## Troubleshooting

### Functions Not Available

1. Reload your profile:
   ```powershell
   . $PROFILE
   ```

2. Or restart your PowerShell session

3. Check if the Automation module loaded:
   ```powershell
   Get-Module Automation
   ```

### Module Path Issues

If the repo was moved, re-run setup:

```bash
make setup
```

This updates the paths in all profiles.

### Profile Not Found

The setup script will create a default profile if none exists. You can also manually create one:

```powershell
New-Item -Path $PROFILE -ItemType File -Force
```

## See Also

- `docs/maintenance-mode-quick-reference.md` - Complete command reference
- `docs/maintenance-mode-environment-config.md` - Environment configuration
- `docs/maint-mode-initial-testing.md` - Testing guide
