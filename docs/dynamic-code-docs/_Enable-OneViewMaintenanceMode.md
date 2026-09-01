---
source:  ./src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1
generated: 2026-09-01
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# _Enable-OneViewMaintenanceMode

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

One-call orchestrator for new HPE ProLiant server deployments. Deploys a client-supplied ISO directly from a network share or HTTPS URL. Each step can be skipped with the -Skip* switches for re-running individual phases.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-ServerIdentifier` | Target server identifier (name, serial, OneView name, iLO IP, bay). Required. |
| `-OneViewHost` | OneView appliance hostname or IP. |
| `-IloIp` | iLO IPv4 address / hostname for the target server. |
| `-ExpectedHostname` | Expected post-build hostname. Defaults to ServerIdentifier. |
| `-Domain` | AD domain to verify in post-build validation. |
| `-SiteCode` | ConfigMgr site code (e.g. P01). |
| `-ManagementPoint` | FQDN of the ConfigMgr Management Point. |
| `-DistributionPoint` | FQDN of the ConfigMgr Distribution Point. |
| `-SiteServer` | FQDN of the ConfigMgr site server (for PSRemoting fallback). |
| `-BootImageName` | Name of the boot image to embed (e.g. 'WinPE x64 - HPE'). |
| `-TaskSequenceName` | Optional task sequence name. |
| `-ExternalIsoPath` | Path to a client-supplied ISO for deployment (skip build/publish). Resolved by the single shared Resolve-ExternalIsoPath helper. Accepts: - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso') - NFS path: Used directly (e.g. 'nfs://server/export/win.iso') - UNC/SMB path (backslash): Converted to CIFS URL (e.g. '\\server\share\win.iso') - UNC/SMB path (forward slash): Same as above (e.g. '//server/share/win.iso') - CIFS/SMB URL: Used directly, round-trips the emitted URL (e.g. 'cifs://server/share/win.iso') - SMB URL alias: Normalised to cifs:// (e.g. 'smb://server/share/win.iso') - Mapped drive: Auto-resolved to its UNC share if mapped to a network drive (e.g. 'H:\win.iso') - Local path: NOT supported — iLO cannot access local drives. Supply an SMB/UNC, CIFS/SMB URL, or HTTPS path instead. This module never creates SMB shares or requires Administrator privileges (regulated banking env). IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'): The iLO BMC cannot access local drives on the automation host. This module does NOT auto-create SMB shares and does NOT require Administrator privileges. Supply an already-shared path instead. When supplied, the ISO build/publish steps are skipped entirely. See ../PathParameterFormats.md for the full list of accepted formats. |
| `-MonitorTimeoutSeconds` | Install monitor timeout (default 7200). |
| `-MonitorPollSeconds` | Install monitor poll interval (default 30). |
| `-DryRun` | Validate inputs and print plan without performing any destructive action. |
| `-Force` | Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish. Refuses to proceed without this switch when the server's iLO reports power state On. |
| `-InMaintenanceWindow` | Acknowledge that the target server is in an approved maintenance window. Required when -Force is not supplied and the server is currently On. |
| `-OneViewMaintenanceMode` | Enable HPE OneView maintenance mode before destructive operations (ISO mount, reboot) and disable it after the build completes. Set to $false to skip maintenance mode orchestration (e.g. when OneView is unavailable or the server is not managed by OneView). Default is $true. |
| `-AllowUnknownIsoUrl` | Skip the head-verify check on the ISO URL during pre-build validation (use only when the build pipeline runs offline). |
| `-GuardRail` | MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE REGULAR EXPRESSION the resolved target server name must match before any destructive action. If it is OMITTED the command fails early with an expressive, logged error and performs no action. If it does NOT match the target, the build is aborted with no changes. When it matches, a destructive confirmation (typing YES) is still required unless -DryRun is supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server 'quickview.ilo03.alp'. This prevents accidentally overwriting a production server when the client's test server lives on the production network. |
| `-Json` | Emit the result as a JSON string on the success stream (for API integration / redirection) instead of the human-readable report. When omitted, the command writes a human-readable report to the host (terminal / transcript / logs) and does NOT dump a raw hashtable. |
| `-PassThru` | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = Start-PhysicalServerBuild -PassThru`, for scripting. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Start-PhysicalServerBuild ` -ServerIdentifier 'PROD-SERVER-01' ` -OneViewHost 'oneview.ad.example.com' ` -IloIp '192.168.1.101' ` -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' ` -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' ` -Domain 'ad.example.com'
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Run the full end-to-end physical server build via ConfigMgr + OneView + iLO Redfish.
        Callable from the module Router.

    .DESCRIPTION
        One-call orchestrator for new HPE ProLiant server deployments. Deploys a
        client-supplied ISO directly from a network share or HTTPS URL. Each step
        can be skipped with the -Skip* switches for re-running individual phases.

    .PARAMETER ServerIdentifier
        Target server identifier (name, serial, OneView name, iLO IP, bay). Required.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server.

    .PARAMETER ExpectedHostname
        Expected post-build hostname. Defaults to ServerIdentifier.

    .PARAMETER Domain
        AD domain to verify in post-build validation.

    .PARAMETER SiteCode
        ConfigMgr site code (e.g. P01).

    .PARAMETER ManagementPoint
        FQDN of the ConfigMgr Management Point.

    .PARAMETER DistributionPoint
        FQDN of the ConfigMgr Distribution Point.

    .PARAMETER SiteServer
        FQDN of the ConfigMgr site server (for PSRemoting fallback).

    .PARAMETER BootImageName
        Name of the boot image to embed (e.g. 'WinPE x64 - HPE').

    .PARAMETER TaskSequenceName
        Optional task sequence name.

    .PARAMETER ExternalIsoPath
        Path to a client-supplied ISO for deployment (skip build/publish).
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

        When supplied, the ISO build/publish steps are skipped entirely.
        See ../PathParameterFormats.md for the full list of accepted formats.

    .PARAMETER MonitorTimeoutSeconds
        Install monitor timeout (default 7200).

    .PARAMETER MonitorPollSeconds
        Install monitor poll interval (default 30).

    .PARAMETER SkipPreBuild
    .PARAMETER SkipOneView
    .PARAMETER SkipMount
    .PARAMETER SkipMonitor
    .PARAMETER SkipPostBuild

    .PARAMETER DryRun
        Validate inputs and print plan without performing any destructive action.

    .PARAMETER Force
        Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish.
        Refuses to proceed without this switch when the server's iLO reports power state On.

    .PARAMETER InMaintenanceWindow
        Acknowledge that the target server is in an approved maintenance window. Required
        when -Force is not supplied and the server is currently On.

    .PARAMETER OneViewMaintenanceMode
        Enable HPE OneView maintenance mode before destructive operations (ISO mount,
        reboot) and disable it after the build completes. Set to $false to skip
        maintenance mode orchestration (e.g. when OneView is unavailable or the server
        is not managed by OneView). Default is $true.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL during pre-build validation (use only
        when the build pipeline runs offline).

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        destructive action. If it is OMITTED the command fails early with an
        expressive, logged error and performs no action. If it does NOT match the
        target, the build is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -DryRun is supplied.
        Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'. This prevents accidentally overwriting a production
        server when the client's test server lives on the production network.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Start-PhysicalServerBuild -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with Success (bool), Steps (ordered list of step
        results), and AuditFile (string). With -Json, a JSON [string]
        representation of the same data.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' `
            -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' `
            -Domain 'ad.example.com'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
