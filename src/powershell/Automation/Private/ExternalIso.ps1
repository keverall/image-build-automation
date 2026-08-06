<#
.SYNOPSIS
    Resolve an external ISO path to a URL accessible by the iLO BMC.

.DESCRIPTION
    The iLO virtual media controller requires network-accessible ISO sources.
    Supported formats:
      - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
      - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
      - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
       - Local file path: Not supported directly — iLO cannot reach local
         drives on the automation host. Supply an SMB/UNC or HTTPS path
         instead. This module never attempts to create SMB shares or
         requires Administrator privileges (regulated banking environments).

     iLO does NOT support local filesystem paths (e.g. 'H:\windows.iso' or
     'C:\isos\win.iso'). The iLO BMC is a separate management controller on
     the physical server and cannot access local drives on your workstation.

     Local paths are intentionally NOT auto-shared — this module never
     requires or attempts Administrator privileges. Supply an SMB/UNC,
     NFS, or HTTPS path instead.

    NOTE: This is a module-internal helper (defined once in Private/) and is
    dot-sourced into the module scope. It is intentionally not exported.

.PARAMETER IsoPath
    Path to the ISO file (UNC/SMB, NFS, or HTTP/HTTPS URL, or a local path).

.PARAMETER RepoLocalPath
    Retained for call-site compatibility. Not used by the resolver.

.PARAMETER RepoBaseUrl
    Retained for call-site compatibility. Not used by the resolver.

.RETURNS
    [string] URL accessible by iLO BMC.
#>
function Resolve-ExternalIsoPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $IsoPath,
        [string] $RepoLocalPath,
        [string] $RepoBaseUrl
    )

    # HTTP/HTTPS URL - use directly
    if ($IsoPath -match '^https?://') {
        Write-Verbose "ISO is an HTTP/HTTPS URL: $IsoPath"
        Write-Host "  [OK] HTTP/HTTPS URL - iLO will download directly" -ForegroundColor Green
        return $IsoPath
    }

    # NFS path - use directly
    if ($IsoPath -match '^nfs://') {
        Write-Verbose "ISO is an NFS path: $IsoPath"
        Write-Host "  [OK] NFS path - iLO will mount directly" -ForegroundColor Green
        return $IsoPath
    }

    # UNC/SMB path - convert to CIFS URL for iLO
    if ($IsoPath -match '^\\\\') {
        Write-Verbose "ISO is a UNC/SMB path: $IsoPath"
        # Convert \\server\share\file.iso -> cifs://server/share/file.iso
        $cifsUrl = $IsoPath -replace '\\\\', 'cifs://' -replace '\\', '/'
        Write-Host "  [OK] UNC/SMB path converted to CIFS URL: $cifsUrl" -ForegroundColor Green
        return $cifsUrl
    }

    # Check if it's a mapped network drive (e.g. H:\ that maps to \\server\share)
    if ($IsoPath -match '^[A-Z]:\\' -or $IsoPath -match '^[a-z]:\\') {
        $driveLetter = $IsoPath.Substring(0, 1)
        $psDrive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue

        if ($psDrive -and $psDrive.DisplayRoot -and $psDrive.DisplayRoot -match '^\\\\') {
            # It's a mapped network drive - construct the UNC path
            $relativePath = $IsoPath.Substring(3) # Remove "H:\"
            $uncPath = Join-Path $psDrive.DisplayRoot $relativePath
            Write-Host "  [INFO] Detected mapped drive: $driveLetter`: -> $($psDrive.DisplayRoot)" -ForegroundColor Yellow
            Write-Host "  [INFO] Resolved UNC path: $uncPath" -ForegroundColor Yellow

            $cifsUrl = $uncPath -replace '\\\\', 'cifs://' -replace '\\', '/'
            Write-Host "  [OK] Mapped drive converted to CIFS URL: $cifsUrl" -ForegroundColor Green
            return $cifsUrl
        }

    # Local drive path - not supported (iLO cannot access local drives, and
    # this environment does not permit Administrator privileges)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ERROR: Local Drive Path Not Supported                           ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Path: $IsoPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The iLO BMC is a separate physical controller on the server." -ForegroundColor Yellow
    Write-Host "  It CANNOT access local drives (H:\, C:\, etc.) on this machine." -ForegroundColor Yellow
    Write-Host "  This module does not create SMB shares or require Administrator" -ForegroundColor Yellow
    Write-Host "  privileges (regulated banking environment)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Supply an already-shared ISO path instead:" -ForegroundColor Cyan
    Write-Host "    -ExternalIsoPath '\\fileserver\share\win2019.iso'" -ForegroundColor Gray
    Write-Host "    -ExternalIsoPath 'https://fileserver/isos/win2019.iso'" -ForegroundColor Gray
    Write-Host ""

    if (-not (Test-Path $IsoPath)) {
        throw "ISO file not found: $IsoPath"
    }

    throw "Local drive path '$IsoPath' is not supported. Supply -ExternalIsoPath as an SMB/UNC (\\server\share\file.iso) or HTTPS URL instead. This module does not auto-create shares or require Administrator privileges."
}

# Unknown format
throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB path (\\server\share\file.iso)."
}
