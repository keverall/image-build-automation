<#
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
#>
function Get-SmbPathFromDriveLetter {
    <#
    .SYNOPSIS
        Resolve a Windows drive letter to its UNC/SMB path (if it's a mapped network drive).

    .DESCRIPTION
        Helper used by Resolve-ExternalIsoPath to find the SMB address of a mapped drive.
        Returns the UNC root (e.g. '\\fileserver\isos') or throws if the drive is local
        or does not exist.

    .PARAMETER DriveLetter
        The drive letter to resolve (e.g. 'H', 'Z').
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $DriveLetter
    )

    $DriveLetter = $DriveLetter.TrimEnd(':', '\').ToUpper()

    if ($DriveLetter.Length -ne 1) {
        throw "Invalid drive letter: '$DriveLetter'. Expected a single letter (e.g. 'H')."
    }

    $psDrive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue

    if (-not $psDrive) {
        throw "Drive $DriveLetter`: does not exist."
    }

    if (-not $psDrive.DisplayRoot) {
        throw "Drive $DriveLetter`: is a local drive, not a mapped network drive. iLO cannot access local drives."
    }

    if ($psDrive.DisplayRoot -match '^\\\\') {
        Write-Verbose "Drive $DriveLetter`: maps to: $($psDrive.DisplayRoot)"
        return $psDrive.DisplayRoot
    }

    throw "Drive $DriveLetter`: is not a UNC/SMB mapped drive (root: $($psDrive.DisplayRoot))."
}

function Resolve-ExternalIsoPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $IsoPath,
        [string] $RepoLocalPath,
        [string] $RepoBaseUrl
    )

    # Normalise surrounding quotes/whitespace that can creep in from shells.
    $p = $IsoPath.Trim().Trim('"', '''')

    # HTTP/HTTPS URL - used directly
    if ($p -match '^https?://') {
        Write-Verbose "Media is an HTTP/HTTPS URL: $p"
        Write-Host "  [OK] HTTP/HTTPS URL - iLO will download directly" -ForegroundColor Green
        return $p
    }

    # NFS path - used directly
    if ($p -match '^nfs://') {
        Write-Verbose "Media is an NFS path: $p"
        Write-Host "  [OK] NFS path - iLO will mount directly" -ForegroundColor Green
        return $p
    }

    # Already a cifs:// URL (the scheme this resolver emits) - round-trip safe
    if ($p -match '^cifs://') {
        Write-Verbose "Media is already a CIFS URL: $p"
        Write-Host "  [OK] CIFS URL - iLO will mount directly" -ForegroundColor Green
        return $p
    }

    # smb:// scheme alias - normalise to cifs:// for iLO
    if ($p -match '^smb://') {
        $cifsUrl = 'cifs://' + $p.Substring('smb://'.Length)
        Write-Verbose "Media is an SMB URL, normalised to CIFS: $cifsUrl"
        Write-Host "  [OK] SMB URL converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # UNC/SMB path. Accept BOTH the Windows form ('\\server\share\file.iso') and the
    # Posix-style forward-slash form ('//server/share/file.iso'), which Windows/PowerShell
    # treat as identical. Normalise the forward-slash form to backslashes first.
    $unc = $p
    if ($unc -match '^//') {
        $unc = '\\' + $unc.Substring(2).Replace('/', '\')
    }
    if ($unc -match '^\\\\') {
        Write-Verbose "Media is a UNC/SMB path: $unc"
        # \\server\share\file.iso -> cifs://server/share/file.iso
        $cifsUrl = $unc -replace '\\\\', 'cifs://' -replace '\\', '/'
        Write-Host "  [OK] UNC/SMB path converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # Mapped network drive (e.g. H:\ that maps to \\server\share)
    if ($p -match '^[A-Za-z]:[\\/]') {
        $driveLetter = $p.Substring(0, 1).ToUpper()
        try {
            $uncRoot = Get-SmbPathFromDriveLetter -DriveLetter $driveLetter
        } catch {
            throw "Local drive path '$IsoPath' is not supported. $($_.Exception.Message) Supply an SMB/UNC (\\server\share\file.iso or //server/share/file.iso), CIFS/SMB URL (cifs://... / smb://...), NFS, or HTTPS URL instead. This module does not auto-create shares or require Administrator privileges."
        }

        $relativePath = $p.Substring(2).TrimStart('\', '/')
        $uncPath = Join-Path $uncRoot $relativePath
        Write-Host "  [INFO] Detected mapped drive: $driveLetter`: -> $uncRoot" -ForegroundColor Yellow
        Write-Host "  [INFO] Resolved UNC path: $uncPath" -ForegroundColor Yellow

        $cifsUrl = $uncPath -replace '\\\\', 'cifs://' -replace '\\', '/'
        Write-Host "  [OK] Mapped drive converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # Single-slash UNC form ('/server/share/file.iso'). Windows/PowerShell treat a
    # single leading slash as relative-to-current-drive, but operators frequently
    # type this when they mean the Posix double-slash UNC form ('//server/share/...').
    # Normalise the leading single slash to a double slash and treat it as UNC.
    if ($p -match '^/[^/]+/.+') {
        $unc = '\\' + $p.Substring(1).Replace('/', '\')
        Write-Verbose "Media is a single-slash UNC path (normalised from '$p'): $unc"
        $cifsUrl = $unc -replace '\\\\', 'cifs://' -replace '\\', '/'
        Write-Host "  [OK] UNC/SMB path converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # Unknown format
    throw "Unsupported media path format: '$IsoPath'. Expected HTTP/HTTPS URL, NFS path, UNC/SMB path (\\server\share\file.iso or //server/share/file.iso), CIFS/SMB URL (cifs://... / smb://...), or a mapped network drive."
}
