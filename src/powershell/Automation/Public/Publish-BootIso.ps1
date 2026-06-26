#
# Public/Publish-BootIso.ps1 - Publish ConfigMgr bootable ISO to HTTPS repository
#
# The iLO Redfish virtual-media endpoint requires an HTTP-accessible ISO URL.
# This function copies (or symlinks) the locally-generated bootable ISO to an
# HTTPS-reachable location so that iLO can fetch it during mount.
#
# Connection details (repository base URL, credentials) are runtime parameters
# - no JSON config required.  Defaults read from $env:ISO_REPO_BASE_URL.
#

function Publish-BootIso {
    <#
    .SYNOPSIS
        Publish a ConfigMgr bootable ISO to an HTTPS repository that iLO can reach.
        Callable from the module Router.

    .DESCRIPTION
        Validates the local ISO, copies it to the configured HTTPS repository root,
        and returns the public URL for the Redfish InsertMedia action.  Verifies
        reachability with an HTTP HEAD request.

    .PARAMETER IsoPath
        Local path to the bootable ISO file (output of New-IsoBuild).

    .PARAMETER RepoBaseUrl
        HTTPS base URL of the ISO repository. Defaults to $env:ISO_REPO_BASE_URL.

    .PARAMETER RepoLocalPath
        Local filesystem path mirrored to RepoBaseUrl (for https_copy mode).
        Defaults to $env:ISO_REPO_LOCAL_PATH.

    .PARAMETER ForceOverwrite
        Allow overwriting an existing ISO with the same filename in the repository.
        Default refuses to overwrite without this switch.

    .PARAMETER SkipVerify
        Skip HTTPS HEAD reachability check.

    .PARAMETER DryRun
        Simulate without copying or verifying.

    .RETURNS
        [hashtable] with Success, PublicUrl, RepoPath, Verified.

    .EXAMPLE
        Publish-BootIso -IsoPath 'C:\osdmedia\WinSrv2025_BootableMedia_v1.0.iso' `
            -RepoBaseUrl 'https://artifacts.internal.example.com/isos/'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string] $IsoPath,
        [string] $RepoBaseUrl  = $null,
        [string] $RepoLocalPath = $null,
        [switch] $ForceOverwrite,
        [switch] $SkipVerify,
        [switch] $DryRun
    )

    if (-not $RepoBaseUrl)  { $RepoBaseUrl   = [System.Environment]::GetEnvironmentVariable('ISO_REPO_BASE_URL') }
    if (-not $RepoLocalPath) { $RepoLocalPath = [System.Environment]::GetEnvironmentVariable('ISO_REPO_LOCAL_PATH') }

    if (-not (Test-Path $IsoPath -PathType Leaf)) {
        return @{ Success = $false; Error = "ISO not found: $IsoPath" }
    }

    if (-not $RepoBaseUrl) {
        return @{ Success = $false; Error = "RepoBaseUrl not provided and \$env:ISO_REPO_BASE_URL is empty" }
    }

    $isoName = Split-Path $IsoPath -Leaf
    $baseTrim = $RepoBaseUrl.TrimEnd('/')
    $publicUrl = "$baseTrim/$isoName"

    $result = @{
        Success   = $false
        IsoPath   = $IsoPath
        PublicUrl = $publicUrl
        RepoPath  = $null
        Verified  = $false
        Timestamp = Get-UtcTimestamp
    }

    if ($DryRun) {
        $result.Success  = $true
        $result.RepoPath = if ($RepoLocalPath) { Join-Path $RepoLocalPath $isoName } else { $publicUrl }
        $result.Verified = $false
        $result.DryRun   = $true
        return $result
    }

    try {
        if ($RepoLocalPath) {
            Ensure-DirectoryExists -Path $RepoLocalPath
            $destPath = Join-Path $RepoLocalPath $isoName
            if (Test-Path $destPath -PathType Leaf -and -not $ForceOverwrite -and -not $DryRun) {
                return @{
                    Success = $false
                    Error   = "Destination already exists: $destPath - pass -ForceOverwrite to replace."
                    RepoPath = $destPath
                    Verified = $false
                    PublicUrl = $publicUrl
                    Timestamp = Get-UtcTimestamp
                }
            }
            Copy-Item -Path $IsoPath -Destination $destPath -Force
            $result.RepoPath = $destPath
            Write-Host "Copied $IsoPath → $destPath"
        }

        if (-not $SkipVerify) {
            try {
                $head = Invoke-WebRequest -Uri $publicUrl -Method Head -UseBasicParsing `
                    -TimeoutSec 10 -ErrorAction Stop
                if ($head.StatusCode -ge 200 -and $head.StatusCode -lt 400) {
                    $result.Verified = $true
                }
            } catch {
                Write-Warning "HTTPS HEAD verify failed for $publicUrl - $($_.Exception.Message)"
                $result.Verified = $false
            }
        }

        $result.Success = $true
        return $result
    }
    catch {
        $result.Error = $_.Exception.Message
        return $result
    }
}

# vim: ts=4 sw=4 et
