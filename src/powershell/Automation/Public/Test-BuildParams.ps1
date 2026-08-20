#
# Public/Test-BuildParams.ps1 - Validate and resolve build parameters.
#

function Test-BuildParams {
    <#
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
        Configure-PhysicalBuild and Start-PhysicalServerBuild.

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
        paths are not supported by iLO.

    .PARAMETER FirmwareFolders
        One or more firmware component source locations (directories or .zip files) passed
        to Update-Firmware for post-OS firmware updates via HPE SUT. Each is resolved and
        validated with the same shared helper as the ISO. Local drive paths are not
        supported.

    .PARAMETER DryRun
        Resolve and validate the path format(s) without checking that the file(s) exist.

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'
        # $r.Success -> $true ; $r.IsoUrl -> 'cifs://fileserver/isos/WinSrv2025.iso'

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath '//fileserver/share/WinSrv2025.iso'
        # $r.Success -> $true ; $r.IsoUrl -> 'cifs://fileserver/share/WinSrv2025.iso'

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath 'https://artifacts/isos/WinSrv2025.iso'
        # $r.Success -> $true ; $r.IsoUrl -> 'https://artifacts/isos/WinSrv2025.iso'

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' `
            -FirmwareFolders @('\\fileserver\fw\BIOS', 'Y:\fw\iLO5')
        # Validates the ISO and both firmware locations through the shared resolver.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $BaseIsoPath = $null,
        [string[]] $FirmwareFolders = @(),
        [bool]  $DryRun      = $false
    )

    $result = [ordered]@{
        Success         = $false
        BaseIsoPath     = $BaseIsoPath
        IsoUrl          = $null
        ResolvedPath    = $null
        FirmwareResults = @()
        Errors          = @()
    }

    # A URL scheme cannot be probed with Test-Path; the iLO/SUT fetches it at mount time.
    function _IsUrl([string]$p) { return ($null -ne $p -and $p -match '^(https?|nfs|cifs|smb)://') }

    # ── ISO validation ────────────────────────────────────────────────────────
    if ($BaseIsoPath) {
        try {
            $isoUrl = Resolve-ExternalIsoPath -IsoPath $BaseIsoPath
            $result.IsoUrl = $isoUrl
            $result.ResolvedPath = $BaseIsoPath
        } catch {
            $result.Errors += $_.Exception.Message
        }

        if (-not $DryRun -and $result.IsoUrl -and -not (_IsUrl $BaseIsoPath)) {
            if (-not (Test-PathEx -Path $BaseIsoPath)) {
                $result.Errors += "Base ISO not found or not accessible: $BaseIsoPath"
            }
        }
    } else {
        $result.Errors += 'BaseIsoPath is required (UNC/SMB share, HTTPS, NFS, CIFS/SMB URL, or a mapped network drive to the Windows ISO).'
    }

    # ── Firmware location validation (same shared resolver for consistency) ────
    foreach ($fw in $FirmwareFolders) {
        $fwEntry = [ordered]@{
            Location    = $fw
            ResolvedUrl = $null
            Exists      = $null
            Error       = $null
        }

        try {
            $fwUrl = Resolve-ExternalIsoPath -IsoPath $fw
            $fwEntry.ResolvedUrl = $fwUrl
        } catch {
            $fwEntry.Error = $_.Exception.Message
            $result.Errors += "Firmware location '$fw': $($_.Exception.Message)"
            $result.FirmwareResults += $fwEntry
            continue
        }

        if (-not $DryRun -and -not (_IsUrl $fw)) {
            $exists = Test-PathEx -Path $fw -PathType Any
            $fwEntry.Exists = $exists
            if (-not $exists) {
                $fwEntry.Error = "Firmware location not found or not accessible: $fw"
                $result.Errors += "Firmware location not found or not accessible: $fw"
            }
        }

        $result.FirmwareResults += $fwEntry
    }

    $result.Success = ($result.Errors.Count -eq 0)
    return $result
}
