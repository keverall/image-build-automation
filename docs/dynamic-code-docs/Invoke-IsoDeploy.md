---
source:  ./src/powershell/Automation/Public/Invoke-IsoDeploy.ps1
generated: 2026-07-21 15:48 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Invoke-IsoDeploy

<a id="top"></a>
## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
- [Original Comment-Based Help](#original-comment-based-help)


<a name="description"></a>
## Description

Bulk deployment orchestrator.  Looks up each server's iLO IP from server_list.txt, resolves the bootable ISO under -IsoDir, and delegates the actual virtual-media mount + boot to Invoke-IloRedfish.

<a name="parameters"></a>
## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Method` | Deployment method (only 'redfish' supported). |
| `-Server` | Deploy to a single named server only. Mutually exclusive with -SerialNumber. |
| `-SerialNumber` | Deploy to a server identified by its HPE serial number. Resolved to the server hostname (and iLO IP) via OneView; requires -OneViewHost. |
| `-OneViewHost` | OneView appliance hostname/IP used to resolve -SerialNumber. |
| `-ServerList` | Path to server_list.txt. Only used for -DryRun mock targeting. |
| `-IsoDir` | Directory containing bootable ISO packages. |
| `-IsoUrl` | Override the ISO URL (otherwise derived from bootable_iso in deployment_metadata.json joined with -RepoBaseUrl). |
| `-ExternalIsoPath` | Path to a client-supplied ISO for deployment (skip package resolution). Accepts the following formats: - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso') - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso') - NFS path: Used directly (e.g. 'nfs://server/export/win.iso') - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso') - Local path: REQUIRES ADMINISTRATOR PRIVILEGES - automatically creates SMB share IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'): The iLO BMC cannot access local drives. When a local path is supplied: - If running as Administrator: Creates SMB share automatically - If NOT running as Administrator: Command will FAIL with instructions to either run as Administrator or obtain an SMB path from your admin When supplied, -IsoUrl is ignored and package resolution is skipped. For non-Administrator users, obtain the SMB path from your IT admin: - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone' - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso' |
| `-RepoBaseUrl` | HTTPS base URL of the ISO repository. Combined with the bootable_iso filename from deployment_metadata.json to construct the full URL when -IsoUrl is not given. Also used when -ExternalIsoPath is a local file that needs to be copied. |
| `-RepoLocalPath` | Local filesystem path of the ISO repository. Required when -ExternalIsoPath is a local file that needs to be copied to make it network-accessible. |
| `-DryRun` | Simulate - no actual deployment. |
| `-SkipConfirmation` | Skip the interactive confirmation prompt before deployment. |

<a name="examples"></a>
## Examples

<a name="example-1"></a>
### Example 1
```powershell
Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'
```

<a name="example-2"></a>
### Example 2
```powershell
Invoke-IsoDeploy -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.example.com' -ExternalIsoPath 'H:\windows.iso' -RepoLocalPath 'C:\osdrepo' -RepoBaseUrl 'https://artifacts/isos'
```

<a name="original-comment-based-help"></a>
## Original Comment-Based Help
```powershell
.SYNOPSIS
        Deploy a bootable ISO to HPE ProLiant servers via iLO Redfish.
        Callable from the module Router.

    .DESCRIPTION
        Bulk deployment orchestrator.  Looks up each server's iLO IP from
        server_list.txt, resolves the bootable ISO under -IsoDir, and delegates
        the actual virtual-media mount + boot to Invoke-IloRedfish.

    .PARAMETER Method
        Deployment method (only 'redfish' supported).

    .PARAMETER Server
        Deploy to a single named server only. Mutually exclusive with -SerialNumber.

    .PARAMETER SerialNumber
        Deploy to a server identified by its HPE serial number. Resolved to the
        server hostname (and iLO IP) via OneView; requires -OneViewHost.

    .PARAMETER OneViewHost
        OneView appliance hostname/IP used to resolve -SerialNumber.

    .PARAMETER ServerList
        Path to server_list.txt. Only used for -DryRun mock targeting.

    .PARAMETER IsoDir
        Directory containing bootable ISO packages.

    .PARAMETER IsoUrl
        Override the ISO URL (otherwise derived from bootable_iso in deployment_metadata.json
        joined with -RepoBaseUrl).

    .PARAMETER ExternalIsoPath
        Path to a client-supplied ISO for deployment (skip package resolution).
        Accepts the following formats:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso')
          - Local path: REQUIRES ADMINISTRATOR PRIVILEGES - automatically creates SMB share
        
        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives. When a local path is supplied:
            - If running as Administrator: Creates SMB share automatically
            - If NOT running as Administrator: Command will FAIL with instructions
              to either run as Administrator or obtain an SMB path from your admin
        
        When supplied, -IsoUrl is ignored and package resolution is skipped.
        For non-Administrator users, obtain the SMB path from your IT admin:
          - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone'
          - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso'

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository. Combined with the bootable_iso filename
        from deployment_metadata.json to construct the full URL when -IsoUrl is not given.
        Also used when -ExternalIsoPath is a local file that needs to be copied.

    .PARAMETER RepoLocalPath
        Local filesystem path of the ISO repository. Required when -ExternalIsoPath
        is a local file that needs to be copied to make it network-accessible.

    .PARAMETER DryRun
        Simulate - no actual deployment.

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt before deployment.

    .RETURNS
        [hashtable] with Success, Server, Summary.

    .EXAMPLE
        Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'

    .EXAMPLE
        Invoke-IsoDeploy -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.example.com' -ExternalIsoPath 'H:\windows.iso' -RepoLocalPath 'C:\osdrepo' -RepoBaseUrl 'https://artifacts/isos'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
