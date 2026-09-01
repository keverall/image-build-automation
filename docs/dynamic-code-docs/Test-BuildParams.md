---
source:  ./src/powershell/Automation/Public/Test-BuildParams.ps1
generated: 2026-09-01
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Test-BuildParams

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
  - [Example 4](#example-4)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

Takes a Windows ISO image path and/or one or more firmware component locations, resolves each to the network address the iLO BMC (and HPE SUT for firmware) can mount/access as virtual media, and verifies the files are present and usable. On success the resolved iLO URLs are returned (IsoUrl / FirmwareResults[*].ResolvedUrl) so callers can pass them straight to a deploy command. On failure the Errors array describes what is wrong. Local drive paths (C:\, etc.) are rejected because the iLO BMC cannot reach local drives on the automation host. Every location is resolved through the single shared Resolve-ExternalIsoPath helper, so the path-format handling is identical across Test-BuildParams, Invoke-IsoDeploy, Configure-PhysicalBuild and Invoke-PhysicalServerBuild. Output is rendered through the shared _Publish-Result helper: a clean, human-readable report is written to the host (no truncated raw hashtable / OrderedDictionary dump), while the structured object is still returned when captured or when -PassThru is used. Use -Json to receive a JSON string for automation/API consumers. Accepted location formats (see Resolve-ExternalIsoPath for the full list): - HTTP/HTTPS URL : 'https://artifacts/win.iso'      (used directly) - NFS path       : 'nfs://server/export/win.iso'    (used directly) - CIFS/SMB URL   : 'cifs://server/share/win.iso'    (used directly; round-trips the scheme this module emits) - SMB URL alias  : 'smb://server/share/win.iso'     (normalised to cifs://) - UNC/SMB path   : '\\server\share\win.iso'         (converted to cifs://) - UNC/SMB path   : '//server/share/win.iso'         (Posix-style forward slashes; equivalent to '\\server\share\win.iso' on Windows) - Mapped drive   : 'H:\win.iso' (where H: maps to a network share) -> expanded to its UNC share, then converted to cifs:// For filesystem locations (UNC/SMB, mapped drive) the file's existence is verified. For URL locations (http/https/nfs/cifs/smb) the path cannot be probed locally, so the existence check is skipped — the iLO/SUT fetches the file at mount time.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-BaseIsoPath` | Path to the base Windows ISO (required for ISO builds). Accepts an UNC/SMB share (\\server\share\file.iso or //server/share/file.iso), an HTTPS/NFS/CIFS/SMB URL, or a mapped network drive (H:\file.iso that maps to a network share). Local drive paths are not supported by iLO. See ../PathParameterFormats.md for the full list of accepted formats. |
| `-FirmwareFolders` | One or more firmware component source locations (directories or .zip files) passed to Update-Firmware for post-OS firmware updates via HPE SUT. Each is resolved and validated with the same shared helper as the ISO. Local drive paths are not supported. See ../PathParameterFormats.md for the accepted path formats. |
| `-DryRun` | Resolve and validate the path format(s) without checking that the file(s) exist. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable report. |
| `-PassThru` | Also return the structured result object on the success stream (for scripting / capture into a variable). Without this, nothing is returned on the success stream so the operator only sees the readable report. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru or -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' # Prints a readable report; IsoUrl -> 'cifs://fileserver/isos/WinSrv2025.iso'
```

<a id="example-2"></a>

### Example 2

```powershell
Test-BuildParams -BaseIsoPath '//fileserver/share/WinSrv2025.iso'
```

<a id="example-3"></a>

### Example 3

```powershell
Test-BuildParams -BaseIsoPath 'https://artifacts/isos/WinSrv2025.iso'
```

<a id="example-4"></a>

### Example 4

```powershell
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' ` -FirmwareFolders @('\\fileserver\fw\BIOS', 'Y:\fw\iLO5') # Validates the ISO and both firmware locations through the shared resolver.
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Validate the base Windows ISO path(s) and firmware location(s) and resolve the iLO boot URL(s).

    .DESCRIPTION
        Takes a Windows ISO image path and/or one or more firmware component
        locations, resolves each to the network address the iLO BMC (and HPE SUT for
        firmware) can mount/access as virtual media, and verifies the files are present
        and usable.

        On success the resolved iLO URLs are returned (IsoUrl / FirmwareResults[*].ResolvedUrl)
        so callers can pass them straight to a deploy command. On failure the Errors array
        describes what is wrong. Local drive paths (C:\, etc.) are rejected because the iLO
        BMC cannot reach local drives on the automation host.

        Every location is resolved through the single shared Resolve-ExternalIsoPath helper,
        so the path-format handling is identical across Test-BuildParams, Invoke-IsoDeploy,
        Configure-PhysicalBuild and Invoke-PhysicalServerBuild.

        Output is rendered through the shared _Publish-Result helper: a clean, human-readable
        report is written to the host (no truncated raw hashtable / OrderedDictionary dump),
        while the structured object is still returned when captured or when -PassThru is used.
        Use -Json to receive a JSON string for automation/API consumers.

        Accepted location formats (see Resolve-ExternalIsoPath for the full list):
          - HTTP/HTTPS URL : 'https://artifacts/win.iso'      (used directly)
          - NFS path       : 'nfs://server/export/win.iso'    (used directly)
          - CIFS/SMB URL   : 'cifs://server/share/win.iso'    (used directly; round-trips
                             the scheme this module emits)
          - SMB URL alias  : 'smb://server/share/win.iso'     (normalised to cifs://)
          - UNC/SMB path   : '\\server\share\win.iso'         (converted to cifs://)
          - UNC/SMB path   : '//server/share/win.iso'         (Posix-style forward slashes;
                             equivalent to '\\server\share\win.iso' on Windows)
          - Mapped drive   : 'H:\win.iso' (where H: maps to a network share)
                             -> expanded to its UNC share, then converted to cifs://

        For filesystem locations (UNC/SMB, mapped drive) the file's existence is verified.
        For URL locations (http/https/nfs/cifs/smb) the path cannot be probed locally, so
        the existence check is skipped — the iLO/SUT fetches the file at mount time.

    .PARAMETER BaseIsoPath
        Path to the base Windows ISO (required for ISO builds). Accepts an UNC/SMB share
        (\\server\share\file.iso or //server/share/file.iso), an HTTPS/NFS/CIFS/SMB URL,
        or a mapped network drive (H:\file.iso that maps to a network share). Local drive
        paths are not supported by iLO. See ../PathParameterFormats.md for the full
        list of accepted formats.

    .PARAMETER FirmwareFolders
        One or more firmware component source locations (directories or .zip files) passed
        to Update-Firmware for post-OS firmware updates via HPE SUT. Each is resolved and
        validated with the same shared helper as the ISO. Local drive paths are not
        supported. See ../PathParameterFormats.md for the accepted path formats.

    .PARAMETER DryRun
        Resolve and validate the path format(s) without checking that the file(s) exist.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report.

    .PARAMETER PassThru
        Also return the structured result object on the success stream (for scripting /
        capture into a variable). Without this, nothing is returned on the success stream
        so the operator only sees the readable report.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru or -Json when the caller
        handles display itself).

    .EXAMPLE
        Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'
        # Prints a readable report; IsoUrl -> 'cifs://fileserver/isos/WinSrv2025.iso'

    .EXAMPLE
        Test-BuildParams -BaseIsoPath '//fileserver/share/WinSrv2025.iso'

    .EXAMPLE
        Test-BuildParams -BaseIsoPath 'https://artifacts/isos/WinSrv2025.iso'

    .EXAMPLE
        Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' `
            -FirmwareFolders @('\\fileserver\fw\BIOS', 'Y:\fw\iLO5')
        # Validates the ISO and both firmware locations through the shared resolver.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
