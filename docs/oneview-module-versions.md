# HPE OneView PowerShell Module Version Compatibility

This table helps you select the correct PowerShell module for your OneView appliance version.

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

**Important:** `HPOneView.Managed` is NOT a standard HPE OneView module name. Use `HPEOneView.860`, `HPEOneView.900`, etc.

## Quick Selection Guide

### For OneView 8.x+ appliances (recommended)
```powershell
Install-Module HPEOneView.860 -Scope AllUsers
```

### For OneView 7.x appliances (PowerShell 5.1 compatibility)
```powershell
Install-Module HPEOneView.720 -Scope AllUsers
```

## Installation Commands

```powershell
# Install for current user
Install-Module HPEOneView.860 -Scope CurrentUser

# Install for all users (requires elevation)
Install-Module HPEOneView.860 -Scope AllUsers

# Offline install: save module to share
Save-Module HPEOneView.860 -Path C:\temp\oneview-modules

# Import the module
Import-Module HPEOneView.860
```

## Connection Command

All module versions use the same connection pattern:

```powershell
# Connect using hostname
Connect-OVMgmt -Hostname oneview.example.com -Credential $cred

# Note: -Appliance is an alias for -Hostname in newer modules
Connect-OVMgmt -Appliance oneview.example.com -Credential $cred
```

## How the Automation Selects Modules

1. **Explicit config**: `oneview_config.json` → `module_name` setting
2. **Auto-detect**: Scans installed modules, picks highest version
3. **Fallback**: Defaults to `HPEOneView.860` if none found

## Module Validation

When `Set-MaintenanceMode` runs (non-dry-run), it validates:
- Module exists on the target system
- PowerShell version compatibility (warns if PS 7+ required but running PS 5.1)
- Logs the selected module name

## Related Documentation

- [HPE OneView POSH Library](https://github.com/HewlettPackard/POSH-HPEOneView)
- [HPE OneView PowerShell Samples](https://github.com/HewlettPackard/oneview-powershell-samples)
- [Module Documentation](https://hpe-docs.gitbook.io/posh-hpeoneview/)
- [HPE OneView PowerShell Module Docs](https://hewlettpackard.github.io/POSH-HPEOneView-docs/latest/)