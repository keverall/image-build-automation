# HPE OneView PowerShell Module Version Compatibility

<a id="top"></a>

## Table of Contents

- [Quick Selection Guide](#quick-selection-guide)
  - [For OneView 8.x+ appliances (recommended)](#for-oneview-8x-appliances-recommended)
  - [For OneView 7.x appliances (legacy)](#for-oneview-7x-appliances-legacy)
- [Installation Commands](#installation-commands)
- [Connection Command](#connection-command)
- [How the Automation Selects Modules](#how-the-automation-selects-modules)
- [Module Validation](#module-validation)
- [Related Documentation](#related-documentation)

> **Project standard:** This automation uses `HPEOneView.1000` and requires **PowerShell 7+** (it does not support Windows PowerShell 5.1). The pre-8.0 rows below are historical only and not used here.

| Module Name | PowerShell | .NET Standard | OneView Appliance Min | Notes |
|-------------|------------|---------------|----------------------|-------|
| `HPEOneView.1000` | 7.0+ | 2.1 | 10.00 | Latest. Requires PowerShell 7+, .NET Standard 2.1 |
| `HPEOneView.910` | 7.0+ | 2.0 | 9.10 | PowerShell Core support |
| `HPEOneView.900` | 7.0+ | 2.0 | 9.00 | PowerShell Core support |
| `HPEOneView.860` | 7.0+ | 2.0 | 8.60 | PowerShell Core support |
| `HPEOneView.840` | 7.0+ | 2.0 | 8.40 | PowerShell Core support |
| `HPEOneView.830` | 7.0+ | 2.0 | 8.30 | PowerShell Core support |
| `HPEOneView.800` | 7.0+ | 2.0 | 8.00 | PowerShell Core support |
| `HPEOneView.720` | 5.1, 7.0+ | 2.0 | 7.20 | Last supporting PS 5.1 |
| `HPEOneView.710` | 5.1, 7.0+ | 2.0 | 7.10 | Last supporting PS 5.1 |
| `HPEOneView.700` | 5.1, 7.0+ | 2.0 | 7.00 | Last supporting PS 5.1 |

**Important:** `HPOneView.Managed` is NOT a standard HPE OneView module name. Use `HPEOneView.1000`, `HPEOneView.900`, etc.

<a id="quick-selection-guide"></a>

## Quick Selection Guide

<a id="for-oneview-8x-appliances-recommended"></a>

### For OneView 8.x+ appliances (recommended)

```powershell
Install-Module HPEOneView.1000 -Scope AllUsers
```

<a id="for-oneview-7x-appliances-legacy"></a>

### For OneView 7.x appliances (legacy)

```powershell
Install-Module HPEOneView.720 -Scope AllUsers
```

<a id="installation-commands"></a>

## Installation Commands

```powershell
Install-Module HPEOneView.1000 -Scope CurrentUser          # current user
Install-Module HPEOneView.1000 -Scope AllUsers             # all users (elevation)
Save-Module HPEOneView.1000 -Path C:\temp\oneview-modules  # offline
Import-Module HPEOneView.1000
```

Only ONE HPE OneView module version can be installed at a time. To switch:

```powershell
Uninstall-Module HPEOneView.1000 -Force -ErrorAction SilentlyContinue
Uninstall-Module HPEOneView.900 -Force -ErrorAction SilentlyContinue
Install-Module HPEOneView.1000 -Scope CurrentUser -AllowClobber -Force
Save-Module HPEOneView.1000 -Path C:\temp\modules -Force
```

If multiple versions exist you may see `Connect-OVMgmt: The term 'Connect-OVMgmt' is not recognized` or cmdlet-name conflicts.

<a id="connection-command"></a>

## Connection Command

All module versions use the same connection pattern:

```powershell
Connect-OVMgmt -Hostname oneview.example.com -Credential $cred
# -Appliance is an alias for -Hostname in newer modules
Connect-OVMgmt -Appliance oneview.example.com -Credential $cred
```

<a id="how-the-automation-selects-modules"></a>

## How the Automation Selects Modules

1. **Explicit config**: `oneview_config.json` → `module_name`
2. **Auto-detect**: scans installed modules, picks highest version
3. **Fallback**: defaults to `HPEOneView.1000` if none found

<a id="module-validation"></a>

## Module Validation

When `Set-MaintenanceMode` runs (non-dry-run) it validates:
- Module exists on the target system
- PowerShell version compatibility (warns if PS 7+ required but unavailable)
- Logs the selected module name

<a id="related-documentation"></a>

## Related Documentation

- [HPE OneView POSH Library](https://github.com/HewlettPackard/POSH-HPEOneView)
- [HPE OneView PowerShell Samples](https://github.com/HewlettPackard/oneview-powershell-samples)
- [Module Documentation](https://hpe-docs.gitbook.io/posh-hpeoneview/)
- [HPE OneView PowerShell Module Docs](https://hewlettpackard.github.io/POSH-HPEOneView-docs/latest/)
