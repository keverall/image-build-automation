---
source:  ./src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1
generated: 2026-08-17
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Start-PhysicalServerBuild

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
- [Original Comment-Based Help](#original-comment-based-help)

<a name="description"></a>

## Description

One-call orchestrator for new HPE ProLiant server deployments.  Each step's parameters are exposed individually with sensible defaults; skip switches allow re-running individual phases (e.g. -SkipIsoBuild to retry the deploy against an already-built ISO).

<a name="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-SrvrId` _(Aliases: -ServerIdentifier)_ | Target server identifier (name, serial, OneView name, iLO IP, bay). Required. |
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP. |
| `-IloIp` _(Aliases: -Ilo)_ | iLO IPv4 address / hostname for the target server. |
| `-ExpectedHostname` | Expected post-build hostname. Defaults to ServerIdentifier. |
| `-Domain` | AD domain to verify in post-build validation. |
| `-SiteCode` | ConfigMgr site code (e.g. P01). |
| `-ManagementPoint` | FQDN of the ConfigMgr Management Point. |
| `-DistributionPoint` | FQDN of the ConfigMgr Distribution Point. |
| `-SiteServer` | FQDN of the ConfigMgr site server (for PSRemoting fallback). |
| `-BootImageName` | Name of the boot image to embed (e.g. 'WinPE x64 - HPE'). |
| `-TaskSequenceName` | Optional task sequence name. |
| `-RepoBaseUrl` | HTTPS base URL of the ISO repository (used by Publish-BootIso). |
| `-RepoLocalPath` | Local filesystem path mirrored to RepoBaseUrl. |
| `-ExternalIsoPath` _(Aliases: -ExtIso)_ | Path to a client-supplied ISO for deployment (skip build/publish). Accepts the following formats: - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso') - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso') - NFS path: Used directly (e.g. 'nfs://server/export/win.iso') - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso') - Local path: NOT supported — iLO cannot access local drives. Supply an SMB/UNC or HTTPS path instead. This module never creates SMB shares or requires Administrator privileges (regulated banking env). IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'): The iLO BMC cannot access local drives on the automation host. This module does NOT auto-create SMB shares and does NOT require Administrator privileges. Supply an already-shared path instead. When supplied, -SkipIsoBuild and -SkipPublish are implied. |
| `-MonitorTimeoutSeconds` | Install monitor timeout (default 7200). |
| `-MonitorPollSeconds` | Install monitor poll interval (default 30). |
| `-SkipFirmware` | Skip the post-OS firmware update step. By default, if -FirmwareFolders are supplied (or -FirmwareConfig is provided), Update-Firmware is invoked after post-build validation. |
| `-FirmwareFolders` | Additional firmware component source directories (string array) passed to Update-Firmware for post-OS firmware updates via HPE SUT. Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5') |
| `-FirmwareConfig` | Path to a firmware manifest JSON passed to Update-Firmware. Example: -FirmwareConfig 'configs\hpe_firmware_drivers_nov2025.json' |
| `-Mock` | Run with mocked calls - no network calls are made; useful for CI smoke tests. When -Mock is set, all downstream steps run as if -DryRun was also set. |
| `-DryRun` _(Aliases: -Dry)_ | Validate inputs and print plan without performing any destructive action. |
| `-Force` | Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish. Refuses to proceed without this switch when the server's iLO reports power state On. |
| `-InMaintenanceWindow` | Acknowledge that the target server is in an approved maintenance window. Required when -Force is not supplied and the server is currently On. |
| `-AllowUnknownIsoUrl` | Skip the head-verify check on the ISO URL during pre-build validation (use only when the build pipeline runs offline). |
| `-SkipConfirmation` _(Aliases: -SkipConf)_ | Skip the interactive confirmation prompt before deployment. By default, the operator must type 'YES' to confirm the deployment plan (server details, ISO, and actions). Use -SkipConfirmation for automated/unattended deployments. |
| `-GuardRail` | MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE REGULAR EXPRESSION the resolved target server name must match before any destructive action. If it is OMITTED the command fails early with an expressive, logged error and performs no action. If it does NOT match the target, the build is aborted with no changes. When it matches, a destructive confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server 'quickview.ilo03.alp'. This prevents accidentally overwriting a production server when the client's test server lives on the production network. |

<a name="examples"></a>

## Examples

<a name="example-1"></a>

### Example 1

```powershell
Start-PhysicalServerBuild ` -SrvrId 'PROD-SERVER-01' ` -OneViewHost 'oneview.ad.example.com' ` -IloIp '192.168.1.101' ` -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' ` -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' ` -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' ` -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com'
```

<a name="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Run the full end-to-end physical server build via ConfigMgr + OneView + iLO Redfish.
        Callable from the module Router.

    .DESCRIPTION
        One-call orchestrator for new HPE ProLiant server deployments.  Each step's
        parameters are exposed individually with sensible defaults; skip switches
        allow re-running individual phases (e.g. -SkipIsoBuild to retry the deploy
        against an already-built ISO).

    .PARAMETER SrvrId
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

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository (used by Publish-BootIso).

    .PARAMETER RepoLocalPath
        Local filesystem path mirrored to RepoBaseUrl.

    .PARAMETER ExternalIsoPath
        Path to a client-supplied ISO for deployment (skip build/publish).
        Accepts the following formats:
          - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
          - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
          - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
          - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso')
          - Local path: NOT supported — iLO cannot access local drives. Supply
            an SMB/UNC or HTTPS path instead. This module never creates SMB
            shares or requires Administrator privileges (regulated banking env).

        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives on the automation host. This
          module does NOT auto-create SMB shares and does NOT require
          Administrator privileges. Supply an already-shared path instead.

        When supplied, -SkipIsoBuild and -SkipPublish are implied.

    .PARAMETER MonitorTimeoutSeconds
        Install monitor timeout (default 7200).

    .PARAMETER MonitorPollSeconds
        Install monitor poll interval (default 30).

    .PARAMETER SkipPreBuild
    .PARAMETER SkipIsoBuild
    .PARAMETER SkipPublish
    .PARAMETER SkipOneView
    .PARAMETER SkipMount
    .PARAMETER SkipMonitor
    .PARAMETER SkipPostBuild
    .PARAMETER SkipFirmware
        Skip the post-OS firmware update step. By default, if -FirmwareFolders
        are supplied (or -FirmwareConfig is provided), Update-Firmware is invoked
        after post-build validation.

    .PARAMETER FirmwareFolders
        Additional firmware component source directories (string array) passed
        to Update-Firmware for post-OS firmware updates via HPE SUT.
        Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER FirmwareConfig
        Path to a firmware manifest JSON passed to Update-Firmware.
        Example: -FirmwareConfig 'configs\hpe_firmware_drivers_nov2025.json'

    .PARAMETER Mock
        Run with mocked calls - no network calls are made; useful for CI smoke tests.
        When -Mock is set, all downstream steps run as if -DryRun was also set.

    .PARAMETER DryRun
        Validate inputs and print plan without performing any destructive action.

    .PARAMETER Force
        Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish.
        Refuses to proceed without this switch when the server's iLO reports power state On.

    .PARAMETER InMaintenanceWindow
        Acknowledge that the target server is in an approved maintenance window. Required
        when -Force is not supplied and the server is currently On.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL during pre-build validation (use only
        when the build pipeline runs offline).

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt before deployment. By default, the
        operator must type 'YES' to confirm the deployment plan (server details, ISO,
        and actions). Use -SkipConfirmation for automated/unattended deployments.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before any
        destructive action. If it is OMITTED the command fails early with an
        expressive, logged error and performs no action. If it does NOT match the
        target, the build is aborted with no changes. When it matches, a destructive
        confirmation (typing YES) is still required unless -SkipConfirmation/-DryRun
        are supplied. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'. This prevents accidentally overwriting a production
        server when the client's test server lives on the production network.

    .RETURNS
        [hashtable] with Success, Steps (ordered list of step results), AuditFile.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -SrvrId 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' `
            -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
