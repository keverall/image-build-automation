---
source:  ./src/powershell/Automation/Public/Invoke-IsoDeploy.ps1
generated: 2026-08-20
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

<a id="description"></a>

## Description

Bulk deployment orchestrator.  Looks up each server's iLO IP from server_list.txt, resolves the bootable ISO under -IsoDir, and delegates the actual virtual-media mount + boot to Invoke-IloRedfish.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Method` | Deployment method (only 'redfish' supported). |
| `-Server` _(Aliases: -Srvr)_ | Deploy to a single named server only. Mutually exclusive with -SerialNumber. |
| `-SerialNumber` _(Aliases: -Srl)_ | Deploy to a server identified by its HPE serial number. Resolved to the server hostname (and iLO IP) via OneView; requires -OneViewHost. |
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname/IP used to resolve -SerialNumber. |
| `-ServerList` _(Aliases: -SrvrList)_ | Path to server_list.txt. Only used for -DryRun mock targeting. |
| `-IsoDir` | Directory containing bootable ISO packages. |
| `-IsoUrl` _(Aliases: -Iso)_ | Override the ISO URL (otherwise derived from bootable_iso in deployment_metadata.json joined with -RepoBaseUrl). |
| `-ExternalIsoPath` _(Aliases: -ExtIso)_ | Path to a client-supplied ISO for deployment (skip package resolution). Resolved by the single shared Resolve-ExternalIsoPath helper. Accepts: - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso') - NFS path: Used directly (e.g. 'nfs://server/export/win.iso') - UNC/SMB path (backslash): Converted to CIFS URL (e.g. '\\server\share\win.iso') - UNC/SMB path (forward slash): Same as above (e.g. '//server/share/win.iso') - CIFS/SMB URL: Used directly, round-trips the emitted URL (e.g. 'cifs://server/share/win.iso') - SMB URL alias: Normalised to cifs:// (e.g. 'smb://server/share/win.iso') - Mapped drive: Auto-resolved to its UNC share if mapped to a network drive (e.g. 'H:\win.iso') - Local path: NOT supported — iLO cannot access local drives. Supply an SMB/UNC, CIFS/SMB URL, or HTTPS path instead. This module never creates SMB shares or requires Administrator privileges (regulated banking env). IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'): The iLO BMC cannot access local drives on the automation host. This module does NOT auto-create SMB shares and does NOT require Administrator privileges. Supply an already-shared path instead. When supplied, -IsoUrl is ignored and package resolution is skipped. |
| `-RepoBaseUrl` _(Aliases: -RepoUrl)_ | HTTPS base URL of the ISO repository. Combined with the bootable_iso filename from deployment_metadata.json to construct the full URL when -IsoUrl is not given. Also used when -ExternalIsoPath is a local file that needs to be copied. |
| `-RepoLocalPath` _(Aliases: -RepoPath)_ | Local filesystem path of the ISO repository. Required when -ExternalIsoPath is a local file that needs to be copied to make it network-accessible. |
| `-DryRun` _(Aliases: -Dry)_ | Simulate - no actual deployment. |
| `-SkipConfirmation` _(Aliases: -SkipConf)_ | Skip the interactive confirmation prompt before deployment. |
| `-GuardRail` | MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE REGULAR EXPRESSION the resolved target server name must match before any deployment. If it is OMITTED the command fails early with an expressive, logged error and performs no deployment. If it does NOT match the target, the deployment is aborted with no changes. When it matches, a destructive confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server 'quickview.ilo03.alp'. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable report. When omitted, the command writes a human-readable report to the host (terminal / transcript / logs) and does NOT dump a raw hashtable. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = Invoke-IsoDeploy -PassThru`, for scripting. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'
```

<a id="example-2"></a>

### Example 2

```powershell
Invoke-IsoDeploy -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.example.com' -ExternalIsoPath 'H:\windows.iso' -RepoLocalPath 'C:\osdrepo' -RepoBaseUrl 'https://artifacts/isos'
```

<a id="original-comment-based-help"></a>

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
        Resolved by the single shared Resolve-ExternalIsoPath helper. Accepts:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - UNC/SMB path (backslash): Converted to CIFS URL (e.g. '\\server\share\win.iso')
          - UNC/SMB path (forward slash): Same as above (e.g. '//server/share/win.iso')
          - CIFS/SMB URL: Used directly, round-trips the emitted URL (e.g. 'cifs://server/share/win.iso')
          - SMB URL alias: Normalised to cifs:// (e.g. 'smb://server/share/win.iso')
          - Mapped drive: Auto-resolved to its UNC share if mapped to a network drive (e.g. 'H:\win.iso')
          - Local path: NOT supported — iLO cannot access local drives. Supply
            an SMB/UNC, CIFS/SMB URL, or HTTPS path instead. This module never creates SMB
            shares or requires Administrator privileges (regulated banking env).

        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives on the automation host. This
          module does NOT auto-create SMB shares and does NOT require
          Administrator privileges. Supply an already-shared path instead.

        When supplied, -IsoUrl is ignored and package resolution is skipped.

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

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        deployment. If it is OMITTED the command fails early with an expressive,
        logged error and performs no deployment. If it does NOT match the target,
        the deployment is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun
        are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report. When omitted, the command writes a
        human-readable report to the host (terminal / transcript / logs) and
        does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Invoke-IsoDeploy -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with Success, Server, Method (single-target) or Summary
        (bulk). With -Json, a JSON [string] representation of the same data.

    .EXAMPLE
        Invoke-IsoDeploy -Server 'srv01.corp.local' -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'

    .EXAMPLE
        Invoke-IsoDeploy -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.example.com' -ExternalIsoPath 'H:\windows.iso' -RepoLocalPath 'C:\osdrepo' -RepoBaseUrl 'https://artifacts/isos'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
