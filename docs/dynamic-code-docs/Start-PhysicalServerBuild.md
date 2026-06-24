---
source:  ./src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1
generated: 2026-06-24 16:59 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Start-PhysicalServerBuild

## Description

One-call orchestrator for new HPE ProLiant server deployments.  Each step's parameters are exposed individually with sensible defaults; skip switches allow re-running individual phases (e.g. -SkipIsoBuild to retry the deploy against an already-built ISO).

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
| `-MonitorTimeoutSeconds` | Install monitor timeout (default 7200). |
| `-MonitorPollSeconds` | Install monitor poll interval (default 30). |
| `-Mock` | Run with mocked calls — no network calls are made; useful for CI smoke tests. |
| `-DryRun` | Validate inputs and print plan without performing any destructive action. |

## Examples

### Example 1
```powershell
Start-PhysicalServerBuild ` -ServerIdentifier 'PROD-SERVER-01' ` -OneViewHost 'oneview.ad.aib.pri' ` -IloIp '192.168.1.101' ` -SiteCode 'P01' -ManagementPoint 'mp01.ad.aib.pri' -DistributionPoint 'dp01.ad.aib.pri' ` -SiteServer 'cm01.ad.aib.pri' -BootImageName 'WinPE x64 - HPE' ` -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' ` -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.aib.pri'
```

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
        Run with mocked calls — no network calls are made; useful for CI smoke tests.

    .PARAMETER DryRun
        Validate inputs and print plan without performing any destructive action.

    .RETURNS
        [hashtable] with Success, Steps (ordered list of step results), AuditFile.

    .EXAMPLE
        Start-PhysicalServerBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.aib.pri' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' -ManagementPoint 'mp01.ad.aib.pri' -DistributionPoint 'dp01.ad.aib.pri' `
            -SiteServer 'cm01.ad.aib.pri' -BootImageName 'WinPE x64 - HPE' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -RepoLocalPath 'C:\osdrepo\' -Domain 'ad.aib.pri'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` — do not edit manually.*
