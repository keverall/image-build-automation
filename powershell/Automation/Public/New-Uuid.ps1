#
# New-Uuid.ps1 — Deterministic UUID generator
# Mirrors Python cli/generate_uuid.py (SHA-256 seed → UUID)
#
# Usage:  pwsh -File New-Uuid.ps1 -ServerName 'srv01.corp.local'
#         pwsh -File New-Uuid.ps1 -ServerName 'srv01' -OutputPath 'output\srv01.uuid'
#

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string] $ServerName,
    [Parameter(Mandatory = $false)][string] $OutputPath = $null,
    [Parameter(Mandatory = $false)][string] $Timestamp  = $null
)

# ──────────────────────────────────────────────────────────────────────────────
#  Test-Uuid — public function (also dot-sourceable from other scripts)
# ──────────────────────────────────────────────────────────────────────────────
function Test-Uuid {
    <#
    .SYNOPSIS
        Generate a deterministic UUID from server name + timestamp using SHA-256.
        Mirrors Python generate_unique_uuid().

    .PARAMETER ServerName
        Server hostname / identifier.

    .PARAMETER Timestamp
        ISO-8601 timestamp (defaults to current UTC time).

    .EXAMPLE
        Test-Uuid -ServerName 'srv01.corp.local'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ServerName,
        [string] $Timestamp = $null
    )

    if (-not $Timestamp) { $Timestamp = [DateTimeOffset]::UtcNow.ToString('o') }

    # SHA-256 hash of "hostname-timestamp"
    $inputBytes = [System.Text.Encoding]::UTF8.GetBytes("$ServerName-$Timestamp")
    $sha256     = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes  = $sha256.ComputeHash($inputBytes)
    $sha256.Dispose()

    # Take first 16 bytes, apply RFC-4122 version 4 / variant 1 masks
    $guidBytes = $hashBytes[0..15]
    $guidBytes[6] = [byte](($guidBytes[6] -band 0x0F) -bor 0x40)   # version 4
    $guidBytes[8] = [byte](($guidBytes[8] -band 0x3F) -bor 0x80)   # variant 1

    return [Guid]::new($guidBytes).ToString()
}

# vim: ts=4 sw=4 et
