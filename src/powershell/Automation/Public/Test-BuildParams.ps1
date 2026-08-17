#
# Public/Test-BuildParams.ps1 - Validate and resolve build parameters.
#

function Test-BuildParams {
    <#
    .SYNOPSIS
        Validate the base Windows ISO path and resolve the iLO boot URL.

    .DESCRIPTION
        Takes a Windows ISO image path, resolves it to the network address the iLO
        BMC can mount as virtual media (a UNC/SMB share becomes a cifs:// URL, HTTPS
        and NFS URLs are used directly, and a mapped network drive is expanded to its
        UNC share), and verifies the file is present and usable as a boot ISO.

        On success the resolved iLO URL is returned (IsoUrl) so callers can pass it
        straight to a deploy command. On failure the Errors array describes what is
        wrong. Local drive paths (C:\, etc.) are rejected because the iLO BMC cannot
        reach local drives on the automation host.

    .PARAMETER BaseIsoPath
        Path to the base Windows ISO (required for ISO builds). Accepts a UNC/SMB
        share (\\server\share\file.iso), an HTTPS/NFS URL, or a mapped network drive
        (H:\file.iso that maps to a network share). Local drive paths are not
        supported by iLO.

    .PARAMETER DryRun
        Resolve and validate the path format without checking that the file exists.

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'
        # $r.Success -> $true ; $r.IsoUrl -> 'cifs://fileserver/isos/WinSrv2025.iso'

    .EXAMPLE
        $r = Test-BuildParams -BaseIsoPath 'https://artifacts/isos/WinSrv2025.iso'
        # $r.Success -> $true ; $r.IsoUrl -> 'https://artifacts/isos/WinSrv2025.iso'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $BaseIsoPath = $null,
        [bool]  $DryRun      = $false
    )

    $result = @{
        Success      = $false
        BaseIsoPath  = $BaseIsoPath
        IsoUrl       = $null
        ResolvedPath = $null
        Errors       = @()
    }

    if (-not $BaseIsoPath) {
        $result.Errors += 'BaseIsoPath is required (UNC/SMB share, HTTPS, or NFS path to the Windows ISO).'
        return $result
    }

    # Resolve the path to the address iLO can mount as virtual media.
    try {
        $isoUrl = Resolve-ExternalIsoPath -IsoPath $BaseIsoPath
        $result.IsoUrl = $isoUrl
        $result.ResolvedPath = $BaseIsoPath
    } catch {
        $result.Errors += $_.Exception.Message
        return $result
    }

    # Verify the ISO is present and usable as a boot image.
    if (-not $DryRun) {
        if (-not (Test-PathEx -Path $BaseIsoPath)) {
            $result.Errors += "Base ISO not found or not accessible: $BaseIsoPath"
            return $result
        }
    }

    $result.Success = $true
    return $result
}
