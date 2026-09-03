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
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $BaseIsoPath = $null,
        [string[]] $FirmwareFolders = @(),
        [bool]  $DryRun      = $false,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
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
            $result.Errors += "Base ISO: $($_.Exception.Message)"
        }

        if (-not $DryRun -and $result.IsoUrl -and -not (_IsUrl $BaseIsoPath)) {
            if (-not (Test-PathEx -Path $BaseIsoPath)) {
                $result.Errors += "Base ISO: not found or not accessible: $BaseIsoPath"
            }
        }
    } else {
        $result.Errors += 'Base ISO: BaseIsoPath is required (UNC/SMB share, HTTPS, NFS, CIFS/SMB URL, or a mapped network drive to the Windows ISO).'
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
            $fwEntry.Error = "Firmware file: '$fw': $($_.Exception.Message)"
            $result.Errors += $fwEntry.Error
            $result.FirmwareResults += $fwEntry
            continue
        }

        if (-not $DryRun -and -not (_IsUrl $fw)) {
            $exists = Test-PathEx -Path $fw -PathType Any
            $fwEntry.Exists = $exists
            if (-not $exists) {
                $fwEntry.Error = "Firmware file: not found or not accessible: $fw"
                $result.Errors += $fwEntry.Error
            }
        }

        $result.FirmwareResults += $fwEntry
    }

    $result.Success = ($result.Errors.Count -eq 0)

    _Emit-BuildParamsResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet
}

# ── Result emission ───────────────────────────────────────────────────────────
function _Emit-BuildParamsResult {
    <#
    .SYNOPSIS
        Emits the Test-BuildParams result via the shared, DRY _Publish-Result helper.
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-BuildParamsResult -Result $r
    }
}

# ── Output formatting ─────────────────────────────────────────────────────────
function _Format-BuildParamsResult {
    <#
    .SYNOPSIS
        Formats the build parameter validation result as a readable report.

    .DESCRIPTION
        Converts the structured result (including the FirmwareResults OrderedDictionary
        entries) into a plain, human-readable list/table. Errors are grouped and shown
        clearly as either ISO-related or firmware-file-related.
    #>
    param([hashtable]$Result)

    $ok = $Result.Success
    $hasErrors = ($Result.Errors -and $Result.Errors.Count -gt 0)
    $dryRunTag = if ($Result.DryRun) { ' [DRY-RUN]' } else { '' }

    $boldRed = "$([char]27)[1;31m"
    $reset   = "$([char]27)[0m"
    $green   = 'Green'
    $cyan    = 'Cyan'
    $yellow  = 'Yellow'

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor $cyan
    Write-Host "  Build Parameter Validation" -ForegroundColor $cyan
    Write-Host "==============================================" -ForegroundColor $cyan
    Write-Host ""

    Write-Host "  Result:    $(if ($ok) { 'VALID' } else { 'INVALID' })${dryRunTag}" `
        -ForegroundColor $(if ($ok) { $green } else { 'Red' })
    Write-Host "  Base ISO:  $(if ($Result.BaseIsoPath) { $Result.BaseIsoPath } else { '(none)' })"
    if ($Result.IsoUrl) {
        Write-Host "  Resolved:  $($Result.IsoUrl)"
    }

    # ── Firmware results (one readable entry per location) ──
    if ($Result.FirmwareResults -and $Result.FirmwareResults.Count -gt 0) {
        Write-Host ""
        Write-Host "  Firmware locations:" -ForegroundColor $yellow
        $idx = 1
        foreach ($fw in $Result.FirmwareResults) {
            Write-Host "    [$idx] $($fw.Location)"
            if ($fw.ResolvedUrl) { Write-Host "        Resolved: $($fw.ResolvedUrl)" }
            if ($null -ne $fw.Exists) {
                $existsColor = if ($fw.Exists) { $green } else { 'Red' }
                Write-Host "        Exists:   $($fw.Exists)" -ForegroundColor $existsColor
            }
            if ($fw.Error) {
                Write-Host "        ${boldRed}Error:    $($fw.Error)${reset}"
            }
            $idx++
        }
    }

    # ── PROMINENT ERROR BANNER ───────────────────────────────────────────────
    # Only emitted when there really are errors, so a clean run shows nothing
    # about Errors (no confusing empty "Errors {}" line).
    if ($hasErrors) {
        $isoErrors   = @($Result.Errors | Where-Object { $_ -match '^Base ISO' })
        $fwErrors    = @($Result.Errors | Where-Object { $_ -match '^Firmware file' })
        $otherErrors = @($Result.Errors | Where-Object { $_ -notmatch '^(Base ISO|Firmware file)' })

        $bar = '############################################################'
        Write-Host ""
        Write-Host "${boldRed}${bar}${reset}"
        Write-Host "${boldRed}#${reset}"
        Write-Host "${boldRed}#  BUILD PARAMETER VALIDATION FAILED${reset}"
        Write-Host "${boldRed}#${reset}"
        if ($isoErrors.Count -gt 0) {
            Write-Host "${boldRed}#  ISO-related errors:${reset}"
            foreach ($e in $isoErrors) { Write-Host "${boldRed}#    - $($e -replace '^Base ISO:\s*', '')${reset}" }
        }
        if ($fwErrors.Count -gt 0) {
            Write-Host "${boldRed}#  Firmware file errors:${reset}"
            foreach ($e in $fwErrors) { Write-Host "${boldRed}#    - $($e -replace '^Firmware file:\s*', '')${reset}" }
        }
        if ($otherErrors.Count -gt 0) {
            Write-Host "${boldRed}#  Other errors:${reset}"
            foreach ($e in $otherErrors) { Write-Host "${boldRed}#    - $e${reset}" }
        }
        Write-Host "${boldRed}#${reset}"
        Write-Host "${boldRed}${bar}${reset}"
        Write-Host ""
    }
}
