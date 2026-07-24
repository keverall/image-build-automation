---
source:  ./src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1
generated: 2026-07-24 09:41 UTC
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
| `-RepoBaseUrl` | HTTPS base URL of the ISO repository (used by Publish-BootIso). |
| `-RepoLocalPath` | Local filesystem path mirrored to RepoBaseUrl. |
| `-ExternalIsoPath` | Path to a client-supplied ISO for deployment (skip build/publish). Accepts the following formats: - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso') - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso') - NFS path: Used directly (e.g. 'nfs://server/export/win.iso') - Mapped drive: Auto-resolved to UNC if mapped to network share (e.g. 'H:\win.iso') - Local path: REQUIRES ADMINISTRATOR PRIVILEGES - automatically creates SMB share IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'): The iLO BMC cannot access local drives. When a local path is supplied: - If running as Administrator: Creates SMB share automatically - If NOT running as Administrator: Command will FAIL with instructions to either run as Administrator or obtain an SMB path from your admin When supplied, -SkipIsoBuild and -SkipPublish are implied. For non-Administrator users, obtain the SMB path from your IT admin: - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone' - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso' |
| `-MonitorTimeoutSeconds` | Install monitor timeout (default 7200). |
| `-MonitorPollSeconds` | Install monitor poll interval (default 30). |
| `-Mock` | Run with mocked calls - no network calls are made; useful for CI smoke tests. When -Mock is set, all downstream steps run as if -DryRun was also set. |
| `-DryRun` | Validate inputs and print plan without performing any destructive action. |
| `-Force` | Required for the destructive Reset action (ForceRestart) issued by Invoke-IloRedfish. Refuses to proceed without this switch when the server's iLO reports power state On. |
| `-InMaintenanceWindow` | Acknowledge that the target server is in an approved maintenance window. Required when -Force is not supplied and the server is currently On. |
| `-AllowUnknownIsoUrl` | Skip the head-verify check on the ISO URL during pre-build validation (use only when the build pipeline runs offline). |
| `-SkipConfirmation` | Skip the interactive confirmation prompt before deployment. By default, the operator must type 'YES' to confirm the deployment plan (server details, ISO, and actions). Use -SkipConfirmation for automated/unattended deployments. |

<a name="examples"></a>
## Examples

<a name="example-1"></a>
### Example 1
```powershell
Start-PhysicalServerBuild ` -ServerIdentifier 'PROD-SERVER-01' ` -OneViewHost 'oneview.ad.example.com' ` -IloIp '192.168.1.101' ` -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' ` -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' ` -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' ` -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com'
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
          - Local path: REQUIRES ADMINISTRATOR PRIVILEGES - automatically creates SMB share
        
        IMPORTANT - Local Drive Paths (e.g. 'H:\windows.iso'):
          The iLO BMC cannot access local drives. When a local path is supplied:
            - If running as Administrator: Creates SMB share automatically
            - If NOT running as Administrator: Command will FAIL with instructions
              to either run as Administrator or obtain an SMB path from your admin
        
        When supplied, -SkipIsoBuild and -SkipPublish are implied.
        For non-Administrator users, obtain the SMB path from your IT admin:
          - Admin runs: New-SmbShare -Name 'isos' -Path 'H:\' -ReadAccess 'Everyone'
          - You use: -ExternalIsoPath '\\SERVERNAME\isos\windows.iso'

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

    .RETURNS
        [hashtable] with Success, Steps (ordered list of step results), AuditFile.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' -DistributionPoint 'dp01.ad.example.com' `
            -SiteServer 'cm01.ad.example.com' -BootImageName 'WinPE x64 - HPE' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.example.com'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
