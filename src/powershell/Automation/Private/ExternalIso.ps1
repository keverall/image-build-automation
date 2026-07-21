<#
.SYNOPSIS
    Resolve an external ISO path to a URL accessible by the iLO BMC.

.DESCRIPTION
    The iLO virtual media controller requires network-accessible ISO sources.
    Supported formats:
      - HTTP/HTTPS URL: Used directly (e.g. 'https://artifacts/win.iso')
      - UNC/SMB path: Converted to CIFS URL for iLO (e.g. '\\server\share\win.iso')
      - NFS path: Used directly (e.g. 'nfs://server/export/win.iso')
      - Local file path: Auto-shared via an SMB share when run as Administrator
        (otherwise an existing SMB/HTTP path must be supplied)

    iLO does NOT support local filesystem paths (e.g. 'H:\windows.iso' or
    'C:\isos\win.iso'). The iLO BMC is a separate management controller on
    the physical server and cannot access local drives on your workstation.

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

        # It's a local drive - requires Administrator to create SMB share
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  WARNING: Local Drive Path Detected                              ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Path: $IsoPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  The iLO BMC is a separate physical controller on the server." -ForegroundColor Yellow
        Write-Host "  It CANNOT access local drives (H:\, C:\, etc.) on this machine." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To use this ISO, you need an SMB (network share) path." -ForegroundColor Cyan
        Write-Host ""

        if (-not (Test-Path $IsoPath)) {
            throw "ISO file not found: $IsoPath"
        }

        $fileInfo = Get-Item $IsoPath
        $isoDirectory = Split-Path $IsoPath -Parent
        $isoFileName = $fileInfo.Name
        $computerName = $env:COMPUTERNAME

        # Check if running as Administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            # Auto-create SMB share
            $shareName = "isos_" + ($isoDirectory -replace '[^a-zA-Z0-9]', '_').Substring(0, [Math]::Min(20, ($isoDirectory -replace '[^a-zA-Z0-9]', '_').Length))

            Write-Host "  [OK] Running as Administrator - creating SMB share automatically..." -ForegroundColor Green
            Write-Host ""
            Write-Host "  Share name:   $shareName" -ForegroundColor Gray
            Write-Host "  Share path:   $isoDirectory" -ForegroundColor Gray
            Write-Host "  Computer:     $computerName" -ForegroundColor Gray

            try {
                $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue

                if ($existingShare) {
                    Write-Host "  [OK] Share already exists" -ForegroundColor Green
                } else {
                    New-SmbShare -Name $shareName -Path $isoDirectory -ReadAccess 'Everyone' -ErrorAction Stop | Out-Null
                    Write-Host "  [OK] Share created successfully" -ForegroundColor Green
                }

                $uncPath = "\\$computerName\$shareName\$isoFileName"
                Write-Host "  [OK] UNC path: $uncPath" -ForegroundColor Green

                $cifsUrl = $uncPath -replace '\\\\', 'cifs://' -replace '\\', '/'
                Write-Host "  [OK] CIFS URL for iLO: $cifsUrl" -ForegroundColor Green

                return $cifsUrl

            } catch {
                throw "Failed to create SMB share: $($_.Exception.Message)"
            }
        } else {
            # Not running as Administrator - show instructions
            Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "  ║  Administrator Privileges Required                               ║" -ForegroundColor Yellow
            Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  You are NOT running PowerShell as Administrator." -ForegroundColor Red
            Write-Host "  Creating an SMB share requires Administrator privileges." -ForegroundColor Red
            Write-Host ""
            Write-Host "  OPTION 1: Run as Administrator (if you have access)" -ForegroundColor Cyan
            Write-Host "    1. Close this PowerShell window" -ForegroundColor Gray
            Write-Host "    2. Right-click PowerShell -> Run as Administrator" -ForegroundColor Gray
            Write-Host "    3. Re-run your command with the same local path" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  OPTION 2: Ask your Administrator to create the share" -ForegroundColor Cyan
            Write-Host "    Ask your IT admin to run this command on $computerName`:" -ForegroundColor Gray
            Write-Host ""
            Write-Host "    New-SmbShare -Name 'isos' -Path '$isoDirectory' -ReadAccess 'Everyone'" -ForegroundColor White
            Write-Host ""
            Write-Host "    Then use this SMB path in your command:" -ForegroundColor Gray
            Write-Host "    -ExternalIsoPath '\\$computerName\isos\$isoFileName'" -ForegroundColor White
            Write-Host ""
            Write-Host "  OPTION 3: Use an existing SMB/HTTP path" -ForegroundColor Cyan
            Write-Host "    If the ISO is already on a network share or web server, use that path:" -ForegroundColor Gray
            Write-Host "    -ExternalIsoPath '\\fileserver\share\$isoFileName'" -ForegroundColor White
            Write-Host "    -ExternalIsoPath 'https://webserver/isos/$isoFileName'" -ForegroundColor White
            Write-Host ""

            throw "Local drive path '$IsoPath' requires Administrator privileges to create SMB share, or an existing SMB/HTTP path must be provided."
        }
    }

    # Unknown format
    throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTTPS URL, NFS path, UNC/SMB path (\\server\share\file.iso), or a local path (e.g. H:\file.iso) which is auto-shared as an SMB share when run as Administrator."
}
