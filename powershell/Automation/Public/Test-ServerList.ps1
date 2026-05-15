#
# Public/Test-ServerList.ps1 — Validate and load the server list text file.
#

function Test-ServerList {
    <#
    .SYNOPSIS
        Validate and load the server list text file.

    .PARAMETER ServerListPath
        Path to server_list.txt (default: configs\server_list.txt).

    .EXAMPLE
        $servers = Test-ServerList
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $ServerListPath = 'configs\server_list.txt'
    )
    if (-not (Test-Path $ServerListPath)) {
        Write-Error "Server list not found: $ServerListPath"
        return @()
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
    return $servers
}
