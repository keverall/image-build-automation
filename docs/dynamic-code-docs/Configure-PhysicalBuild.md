---
source:  ./src/powershell/Automation/Public/Configure-PhysicalBuild.ps1
generated: 2026-08-26
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Configure-PhysicalBuild

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

Gathers full server identity from OneView, resolves the ISO URL, runs pre-build validation, and prints a comprehensive summary of all destructive actions that will be performed. Designed for a second operator to review and approve before Start-PhysicalBuild is run. This command performs NO destructive actions — no ISO attach, no reboot, no firmware update. It is read-only / dry-run only.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-ServerIdentifier` _(Aliases: -SrvrId)_ | Target server identifier (hostname, serial, OneView name, iLO IP, bay). |
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP. |
| `-IloIp` _(Aliases: -Ilo)_ | iLO IPv4 address / hostname for the target server (if known). |
| `-IloCredential` | PSCredential for the iLO Redfish check. If omitted, prompted interactively. |
| `-ExpectedHostname` | Hostname that should result from the build (defaults to SrvrId). |
| `-Domain` | AD domain to verify in post-build validation. |
| `-SiteCode` | ConfigMgr site code (for ISO build / pre-build validation). |
| `-ManagementPoint` | ConfigMgr Management Point FQDN. |
| `-DistributionPoint` | ConfigMgr Distribution Point FQDN. |
| `-SiteServer` | ConfigMgr site server FQDN. |
| `-BootImageName` | ConfigMgr boot image name to verify. |
| `-TaskSequenceName` | ConfigMgr task sequence name to verify. |
| `-RepoBaseUrl` | HTTPS base URL of the ISO repository. |
| `-RepoLocalPath` | Local filesystem path mirrored to RepoBaseUrl. |
| `-ExternalIsoPath` _(Aliases: -ExtIso)_ | Use a client-supplied ISO instead of building one. Resolved by the single shared Resolve-ExternalIsoPath helper. Accepts an UNC/SMB path (incl. '//server/share'), a 'cifs://'/'smb://' URL, an HTTPS/NFS URL, or a mapped network drive. Local paths are not supported. |
| `-FirmwareFolders` | Firmware component source directories that will be applied post-OS-install. Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5') |
| `-FirmwareConfig` | Firmware manifest JSON for Update-Firmware. |
| `-AllowUnknownIsoUrl` | Skip the head-verify check on the ISO URL (offline scenarios). |
| `-InMaintenanceWindow` | Acknowledge the target server is in an approved maintenance window. |
| `-SkipPreBuild` | Skip pre-build validation checks. |
| `-SkipOneView` | Skip OneView target resolution. |
| `-SkipIlo` | Skip iLO credential / Redfish check. |
| `-SkipDpMp` | Skip Management Point / Distribution Point reachability check. |
| `-SkipIsoUrl` | Skip ISO URL reachability check. |
| `-Force` | Acknowledge server power state is On (informational only — this command does not perform any reboot; included for parity with Start-PhysicalBuild). |
| `-SkipConfirmation` _(Aliases: -SkipConf)_ | Skip the interactive confirmation prompt. When set, the function returns the plan hashtable without waiting for operator input. |
| `-GuardRail` | MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE REGULAR EXPRESSION the resolved target server name must match before the build plan is even produced. If it is OMITTED the review is aborted early with an expressive, logged error. If it does NOT match, the review is aborted. Example (regex): -GuardRail 'quickview\.ilo0' matches server 'quickview.ilo03.alp'. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Configure-PhysicalBuild ` -ServerIdentifier 'PROD-SERVER-01' ` -OneViewHost 'oneview.ad.example.com' ` -IloIp '192.168.1.101' ` -SiteCode 'P01' ` -ManagementPoint 'mp01.ad.example.com' ` -DistributionPoint 'dp01.ad.example.com' ` -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' ` -Domain 'ad.example.com' ` -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')
```

<a id="example-2"></a>

### Example 2

```powershell
Configure-PhysicalBuild -ServerIdentifier 'srv01' -OneViewHost 'oneview.ad.example.com' -ExternalIsoPath 'https://artifacts/isos/Win2025.iso' -SkipConfirmation
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Review and validate a physical server build plan before deployment.
        4-eye validation gate for production imaging.

    .DESCRIPTION
        Gathers full server identity from OneView, resolves the ISO URL, runs
        pre-build validation, and prints a comprehensive summary of all
        destructive actions that will be performed. Designed for a second
        operator to review and approve before Start-PhysicalBuild is run.

        This command performs NO destructive actions — no ISO attach, no
        reboot, no firmware update. It is read-only / dry-run only.

    .PARAMETER ServerIdentifier
        Target server identifier (hostname, serial, OneView name, iLO IP, bay).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP.

    .PARAMETER IloIp
        iLO IPv4 address / hostname for the target server (if known).

    .PARAMETER IloCredential
        PSCredential for the iLO Redfish check. If omitted, prompted interactively.

    .PARAMETER ExpectedHostname
        Hostname that should result from the build (defaults to SrvrId).

    .PARAMETER Domain
        AD domain to verify in post-build validation.

    .PARAMETER SiteCode
        ConfigMgr site code (for ISO build / pre-build validation).

    .PARAMETER ManagementPoint
        ConfigMgr Management Point FQDN.

    .PARAMETER DistributionPoint
        ConfigMgr Distribution Point FQDN.

    .PARAMETER SiteServer
        ConfigMgr site server FQDN.

    .PARAMETER BootImageName
        ConfigMgr boot image name to verify.

    .PARAMETER TaskSequenceName
        ConfigMgr task sequence name to verify.

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository.

    .PARAMETER RepoLocalPath
        Local filesystem path mirrored to RepoBaseUrl.

    .PARAMETER ExternalIsoPath
        Use a client-supplied ISO instead of building one. Resolved by the single
        shared Resolve-ExternalIsoPath helper. Accepts an UNC/SMB path
        (incl. '//server/share'), a 'cifs://'/'smb://' URL, an HTTPS/NFS URL, or a
        mapped network drive. Local paths are not supported.

    .PARAMETER FirmwareFolders
        Firmware component source directories that will be applied post-OS-install.
        Example: -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER FirmwareConfig
        Firmware manifest JSON for Update-Firmware.

    .PARAMETER AllowUnknownIsoUrl
        Skip the head-verify check on the ISO URL (offline scenarios).

    .PARAMETER InMaintenanceWindow
        Acknowledge the target server is in an approved maintenance window.

    .PARAMETER SkipPreBuild
        Skip pre-build validation checks.

    .PARAMETER SkipOneView
        Skip OneView target resolution.

    .PARAMETER SkipIlo
        Skip iLO credential / Redfish check.

    .PARAMETER SkipDpMp
        Skip Management Point / Distribution Point reachability check.

    .PARAMETER SkipIsoUrl
        Skip ISO URL reachability check.

    .PARAMETER Force
        Acknowledge server power state is On (informational only — this command
        does not perform any reboot; included for parity with Start-PhysicalBuild).

    .PARAMETER SkipConfirmation
        Skip the interactive confirmation prompt. When set, the function returns
        the plan hashtable without waiting for operator input.

    .PARAMETER GuardRail
        MANDATORY safety gate for shared/production networks. A CASE-INSENSITIVE
        REGULAR EXPRESSION the resolved target server name must match before the
        build plan is even produced. If it is OMITTED the review is aborted early
        with an expressive, logged error. If it does NOT match, the review is
        aborted. Example (regex): -GuardRail 'quickview\.ilo0' matches server
        'quickview.ilo03.alp'.

    .RETURNS
        [hashtable] with Success, ServerIdentity, IsoDetails, FirmwareDetails,
        DestructiveActions, ValidationChecks, and Plan (for piping to Start-PhysicalBuild).

    .EXAMPLE
        Configure-PhysicalBuild `
            -ServerIdentifier 'PROD-SERVER-01' `
            -OneViewHost 'oneview.ad.example.com' `
            -IloIp '192.168.1.101' `
            -SiteCode 'P01' `
            -ManagementPoint 'mp01.ad.example.com' `
            -DistributionPoint 'dp01.ad.example.com' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/' `
            -Domain 'ad.example.com' `
            -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .EXAMPLE
        Configure-PhysicalBuild -ServerIdentifier 'srv01' -OneViewHost 'oneview.ad.example.com' -ExternalIsoPath 'https://artifacts/isos/Win2025.iso' -SkipConfirmation
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
