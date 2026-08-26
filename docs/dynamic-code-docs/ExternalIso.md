---
source:  ./src/powershell/Automation/Private/ExternalIso.ps1
generated: 2026-08-26
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# ExternalIso

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

The iLO virtual media controller and HPE SUT (firmware) require network-accessible sources. This is the SINGLE shared resolver used by every command that attaches, builds, or deploys images and firmware to HPE OneView connected servers, so path handling stays consistent across the module. Accepted input formats (all equivalent from iLO's point of view): - HTTP/HTTPS URL : 'https://artifacts/win.iso'           -> used directly - NFS path       : 'nfs://server/export/win.iso'         -> used directly - CIFS/SMB URL   : 'cifs://server/share/win.iso'         -> used directly (this is also the scheme this resolver EMITS, so it round-trips) - SMB URL alias  : 'smb://server/share/win.iso'          -> normalised to cifs:// - UNC/SMB path   : '\\server\share\win.iso'              -> converted to cifs:// (Windows form, backslashes) - UNC/SMB path   : '//server/share/win.iso'              -> converted to cifs:// (Posix-style forward slashes; Windows/PowerShell treat this as identical to '\\server\share\win.iso') - UNC/SMB path   : '/server/share/win.iso'               -> also accepted (single leading slash, a common typo for the '//server/share' form); normalised to '//server/share/win.iso' -> cifs:// - Mapped drive   : 'H:\win.iso' where H: maps to a UNC    -> expanded to UNC, then converted to cifs:// iLO does NOT support local filesystem paths (e.g. 'C:\isos\win.iso' or an 'H:\' that maps to a local disk). The iLO BMC is a separate management controller on the physical server and cannot access local drives on your workstation. Local paths are intentionally NOT auto-shared — this module never requires or attempts Administrator privileges (regulated banking environments). Supply an SMB/UNC, NFS, CIFS/SMB URL, or HTTPS path instead. NOTE: This is a module-internal helper (defined once in Private/) and is dot-sourced into the module scope. It is intentionally not exported for direct end-user use, but is exported internally so every command module resolves paths through one code path.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-IsoPath` | Path to the media file (UNC/SMB, NFS, CIFS/SMB URL, HTTP/HTTPS URL, or a mapped network drive). Despite the parameter name, it is path-type agnostic and is also used for firmware component folders/zips. See ../PathParameterFormats.md for the full list of accepted formats (incl. the single-slash /server/share autocorrection). |
| `-RepoLocalPath` | Retained for call-site compatibility. Not used by the resolver. |
| `-RepoBaseUrl` | Retained for call-site compatibility. Not used by the resolver. |

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
    Resolve an external media path (ISO or firmware) to a URL accessible by the iLO BMC.

.DESCRIPTION
    The iLO virtual media controller and HPE SUT (firmware) require network-accessible
    sources. This is the SINGLE shared resolver used by every command that attaches,
    builds, or deploys images and firmware to HPE OneView connected servers, so path
    handling stays consistent across the module.

    Accepted input formats (all equivalent from iLO's point of view):

      - HTTP/HTTPS URL : 'https://artifacts/win.iso'           -> used directly
      - NFS path       : 'nfs://server/export/win.iso'         -> used directly
      - CIFS/SMB URL   : 'cifs://server/share/win.iso'         -> used directly (this is
                         also the scheme this resolver EMITS, so it round-trips)
      - SMB URL alias  : 'smb://server/share/win.iso'          -> normalised to cifs://
      - UNC/SMB path   : '\\server\share\win.iso'              -> converted to cifs://
                         (Windows form, backslashes)
      - UNC/SMB path   : '//server/share/win.iso'              -> converted to cifs://
                          (Posix-style forward slashes; Windows/PowerShell treat this as
                          identical to '\\server\share\win.iso')
      - UNC/SMB path   : '/server/share/win.iso'               -> also accepted (single
                          leading slash, a common typo for the '//server/share' form);
                          normalised to '//server/share/win.iso' -> cifs://
      - Mapped drive   : 'H:\win.iso' where H: maps to a UNC    -> expanded to UNC, then
                         converted to cifs://

    iLO does NOT support local filesystem paths (e.g. 'C:\isos\win.iso' or an 'H:\'
    that maps to a local disk). The iLO BMC is a separate management controller on the
    physical server and cannot access local drives on your workstation. Local paths are
    intentionally NOT auto-shared — this module never requires or attempts Administrator
    privileges (regulated banking environments). Supply an SMB/UNC, NFS, CIFS/SMB URL, or
    HTTPS path instead.

    NOTE: This is a module-internal helper (defined once in Private/) and is dot-sourced
    into the module scope. It is intentionally not exported for direct end-user use, but
    is exported internally so every command module resolves paths through one code path.

.PARAMETER IsoPath
    Path to the media file (UNC/SMB, NFS, CIFS/SMB URL, HTTP/HTTPS URL, or a mapped
    network drive). Despite the parameter name, it is path-type agnostic and is also used
    for firmware component folders/zips. See ../PathParameterFormats.md for the full
    list of accepted formats (incl. the single-slash /server/share autocorrection).

.PARAMETER RepoLocalPath
    Retained for call-site compatibility. Not used by the resolver.

.PARAMETER RepoBaseUrl
    Retained for call-site compatibility. Not used by the resolver.

.RETURNS
    [string] URL accessible by iLO BMC (cifs://, nfs://, or https://).
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
