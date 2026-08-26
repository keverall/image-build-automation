---
source:  ./src/powershell/Automation/Public/New-IsoBuild.ps1
generated: 2026-08-26
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# New-IsoBuild

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

Auto-detects a ConfigMgr PowerShell context (local module or PSRemoting to the site server) and invokes New-CMBootableMedia to produce a WinPE bootable ISO that can be mounted via iLO Redfish and used to run a task sequence against a freshly-racked HPE ProLiant server.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OutputPath` | Full path (including filename) for the output ISO.  When omitted a versioned filename is generated under the local output directory. |
| `-VersionMajor` | Major version number embedded in the filename (default 1). |
| `-VersionMinor` | Minor version number embedded in the filename (default 0). |
| `-SiteCode` | ConfigMgr site code (e.g. P01). Required. |
| `-ManagementPoint` | FQDN of the Management Point (e.g. mp01.ad.example.com). Required. |
| `-DistributionPoint` | FQDN of the Distribution Point (e.g. dp01.ad.example.com). Required. |
| `-BootImageName` | Name of the boot image to embed (e.g. 'WinPE x64 - HPE'). |
| `-TaskSequenceName` | Optional task sequence name (informational; TS selection happens at boot). |
| `-SiteServer` | FQDN of the ConfigMgr site server for PSRemoting fallback (e.g. cm01.ad.example.com). |
| `-SiteServerUser` | Site server admin username for PSRemoting. If omitted (with password), prompted interactively. Never read from environment. |
| `-SiteServerPassword` | Site server admin password. If omitted, prompted interactively. Never read from environment. |
| `-MediaPassword` | Optional boot media password (env: CM_MEDIA_PASSWORD). |
| `-AllowUnknownMachine` | Pass -AllowUnknownMachine to New-CMBootableMedia (default true). |
| `-AllowUnattended` | Pass -AllowUnattended to New-CMBootableMedia (default true). |
| `-SkipCertificateCheck` | Skip SSL cert verification (default true). |
| `-MockIso` | Create a 0-byte placeholder ISO without calling ConfigMgr (used by tests). |
| `-DryRun` | Validate inputs and print plan without creating the ISO. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable report. When omitted, the command writes a human-readable report to the host (terminal / transcript / logs) and does NOT dump a raw hashtable. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = New-IsoBuild -PassThru`, for scripting. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' ` -DistributionPoint 'dp01.ad.example.com' -BootImageName 'WinPE x64 - HPE' ` -SiteServer 'cm01.ad.example.com'
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Build a ConfigMgr bootable media ISO (WinPE) for physical server deployment.
        Callable from the module Router.

    .DESCRIPTION
        Auto-detects a ConfigMgr PowerShell context (local module or PSRemoting
        to the site server) and invokes New-CMBootableMedia to produce a WinPE
        bootable ISO that can be mounted via iLO Redfish and used to run a task
        sequence against a freshly-racked HPE ProLiant server.

    .PARAMETER OutputPath
        Full path (including filename) for the output ISO.  When omitted a
        versioned filename is generated under the local output directory.

    .PARAMETER VersionMajor
        Major version number embedded in the filename (default 1).

    .PARAMETER VersionMinor
        Minor version number embedded in the filename (default 0).

    .PARAMETER SiteCode
        ConfigMgr site code (e.g. P01). Required.

    .PARAMETER ManagementPoint
        FQDN of the Management Point (e.g. mp01.ad.example.com). Required.

    .PARAMETER DistributionPoint
        FQDN of the Distribution Point (e.g. dp01.ad.example.com). Required.

    .PARAMETER BootImageName
        Name of the boot image to embed (e.g. 'WinPE x64 - HPE').

    .PARAMETER TaskSequenceName
        Optional task sequence name (informational; TS selection happens at boot).

    .PARAMETER SiteServer
        FQDN of the ConfigMgr site server for PSRemoting fallback (e.g. cm01.ad.example.com).

    .PARAMETER SiteServerUser
        Site server admin username for PSRemoting. If omitted (with password),
        prompted interactively. Never read from environment.

    .PARAMETER SiteServerPassword
        Site server admin password. If omitted, prompted interactively. Never
        read from environment.

    .PARAMETER MediaPassword
        Optional boot media password (env: CM_MEDIA_PASSWORD).

    .PARAMETER AllowUnknownMachine
        Pass -AllowUnknownMachine to New-CMBootableMedia (default true).

    .PARAMETER AllowUnattended
        Pass -AllowUnattended to New-CMBootableMedia (default true).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER MockIso
        Create a 0-byte placeholder ISO without calling ConfigMgr (used by tests).

    .PARAMETER DryRun
        Validate inputs and print plan without creating the ISO.

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
        `$r = New-IsoBuild -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with Success, IsoPath, Metadata. With -Json, a JSON
        [string] representation of the same data.

    .EXAMPLE
        New-IsoBuild -SiteCode 'P01' -ManagementPoint 'mp01.ad.example.com' `
            -DistributionPoint 'dp01.ad.example.com' -BootImageName 'WinPE x64 - HPE' `
            -SiteServer 'cm01.ad.example.com'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
