#
# New-Uuid.ps1 — Deterministic UUID generator
#
# Mirrors Python cli/generate_uuid.py (SHA-256 seed → UUID)
#
# Usage:  pwsh -File New-Uuid.ps1 -ServerName 'srv01.corp.local'
#         pwsh -File New-Uuid.ps1 -ServerName 'srv01' -OutputPath 'output\srv01.uuid'
#

function New-Uuid {
    <#
    .SYNOPSIS
        Generate a deterministic UUID from server name + timestamp using SHA-256.
        Mirrors Python generate_unique_uuid().

    .DESCRIPTION
        Creates a deterministic UUID (GUID) by computing SHA-256 hash of the
        server name combined with a timestamp. The first 16 bytes of the hash
        are converted to a standard UUID format. This ensures the same server
        and timestamp always produce the same UUID.

    .PARAMETER ServerName
        Server hostname / identifier.

    .PARAMETER Timestamp
        ISO-8601 timestamp (defaults to current UTC time).

    .PARAMETER OutputPath
        Optional path to write the UUID to.

    .EXAMPLE
        New-Uuid -ServerName 'srv01.corp.local'

    .EXAMPLE
        $uuid = New-Uuid -ServerName 'srv01' -OutputPath 'C:\temp\srv01.uuid'

    .NOTES
        This function is used for consistent server identification across
        build and deployment operations.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ServerName,
        [string] $Timestamp = $null,
        [string] $OutputPath = $null
    )

    if (-not $Timestamp) { $Timestamp = [DateTimeOffset]::UtcNow.ToString('o') }

    # SHA-256 hash of "hostname-timestamp"
    $inputBytes = [System.Text.Encoding]::UTF8.GetBytes("$ServerName-$Timestamp")
    $sha256     = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes  = $sha256.ComputeHash($inputBytes)
    $sha256.Dispose()

    # Take first 16 bytes, convert to hex string for UUID format
    $hashHex = [System.BitConverter]::ToString($hashBytes[0..15]).Replace('-', '').ToLower()
    $uuid = [Guid]::new($hashHex).ToString()

    if ($OutputPath) {
        Set-Content -Path $OutputPath -Value $uuid -NoNewline -ErrorAction Stop
    }

    return $uuid
}

# vim: ts=4 sw=4 et
