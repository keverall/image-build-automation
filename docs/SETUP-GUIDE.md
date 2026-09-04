# Setup Guide - PowerShell Profile & Maintenance Mode

<a id="top"></a>

## Table of Contents

- [Quick Start (5 Minutes)](#quick-start-5-minutes)
- [What Gets Installed](#what-gets-installed)
- [Manual Setup (if `make setup` fails)](#manual-setup-if-make-setup-fails)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

<a id="quick-start-5-minutes"></a>

## Quick Start (5 Minutes)

`make setup` installs the required bundled modules and registers the Automation module in your PowerShell profile.

```powershell
# From the project root
make setup
```

Then reload your profile (or restart the terminal):

```powershell
. $PROFILE
```

Verify the commands are available:

```powershell
Get-Command Set-MaintenanceMode
Get-Command Configure-PhysicalBuild   # physical HPE server build (client-supplied ISO + iLO Redfish)
```

---

<a id="what-gets-installed"></a>

## What Gets Installed

- **Automation module** auto-import (provides `Set-MaintenanceMode`, `Connect-OneView`, `Test-ServerConnectivity`, `Disconnect-OneView`, etc.)
- **oh-my-posh** theme and **posh-git** for an enhanced terminal UX
- Convenience wrapper `scripts/Setup-Profile.ps1` that wires the above into `$PROFILE`

---

<a id="manual-setup-if-make-setup-fails"></a>

## Manual Setup (if `make setup` fails)

Add the module import to your PowerShell profile (`$PROFILE`). Use the **absolute**
repo path — `$PSScriptRoot` resolves to the profile's own directory when the snippet
lives in `$PROFILE`, not to the project root (the `make setup` / `Setup-Profile.ps1`
path injects the absolute path for this reason):

```powershell
$ProjectRoot = 'C:\path\to\image-build-automation'   # set to your repo checkout
$AutomationModulePath = Join-Path $ProjectRoot 'src/powershell/Automation/Automation.psd1'
if (Test-Path $AutomationModulePath) {
    Import-Module $AutomationModulePath -WarningAction SilentlyContinue
}
```

Find and edit your profile:

```powershell
echo $PROFILE                 # profile path
code $PROFILE                 # edit (VS Code)
nano $PROFILE                 # edit (terminal)
```

Reload after editing:

```powershell
. $PROFILE
```

---

<a id="uninstall"></a>

## Uninstall

```bash
pwsh -File scripts/Setup-Profile.ps1 -Uninstall
```

---

<a id="troubleshooting"></a>

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Profile not loading | `Test-Path $PROFILE`; create with `New-Item -ItemType File -Path $PROFILE -Force` |
| Module not found | `Test-Path src/powershell/Automation/Automation.psd1`; import manually with `Import-Module .\src\powershell\Automation\Automation.psd1 -Force` |
| `Set-MaintenanceMode` not available | Reload: `. $PROFILE`; then `Get-Command Set-MaintenanceMode -ErrorAction SilentlyContinue` |
| Wrong shell | Use **PowerShell** (`pwsh`/`powershell`), not bash/fish — `echo $SHELL` |

---

<a id="next-steps"></a>

## Next Steps

- [Maintenance Mode Shortcuts](Maintenance-Mode/MAINTENANCE_MODE_SHORTCUTS.md#top) — usage examples
- [Runbook Requirements (current)](Automation/runbook-requirements-v2.md#top) — physical HPE server build (no ConfigMgr)
- [Automation Command Reference](Automation/automation_commands.md#top) — every parameter for the build/firmware commands
- [Project README](../README.md#top) — overview and architecture
