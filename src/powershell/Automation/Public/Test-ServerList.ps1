#
# Public/Test-ServerList.ps1 - Validate and load the server list text file.
#

function Test-ServerList {
    <#
    .SYNOPSIS
        Validate and load the server list text file.

    .DESCRIPTION
        Reads the server list text file (server_list.txt) and returns a hashtable
        with Success and Servers properties. Skips empty lines and comments
        (lines starting with #). Optionally trims comma-separated metadata from each line.

    .PARAMETER ServerListPath
        Path to server_list.txt (default: configs\server_list.txt).

    .EXAMPLE
        $servers = Test-ServerList
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $ServerListPath = 'configs\server_list.txt'
    )
    if (-not (Test-Path $ServerListPath)) {
        return @{
            Success = $false
            Error   = "Server list not found: $ServerListPath"
            Servers = @()
        }
    }
    $servers = @()
    Get-Content $ServerListPath -Encoding UTF8 | ForEach-Object {
        $hostname = $_.Trim()
        if ($hostname -and -not $hostname.StartsWith('#')) {
            $hostname = $hostname.Split(',')[0].Trim()
            if ($hostname) { $servers += $hostname }
        }
    }
    if (-not $servers) { Write-Warning "No valid servers found in $ServerListPath" }
    return @{
        Success = $true
        Servers = $servers
    }
}
