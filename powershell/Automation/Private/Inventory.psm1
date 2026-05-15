#
# Inventory.psm1 — Server inventory and cluster catalogue helpers.
# NOTE: ServerInfo class is defined in Automation.psm1 (root) for type-visibility.
#

function Load-ServerList {
    <#
    .SYNOPSIS
        Load server list from a text file (format: hostname[,ipmi_ip[,ilo_ip]]).

    .PARAMETER Path
        Path to server_list.txt.

    .PARAMETER IncludeDetails
        Return [ServerInfo] objects when $true, plain strings when $false (default).

    .EXAMPLE
        $servers = Load-ServerList 'configs\server_list.txt' -IncludeDetails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Path,
        [switch] $IncludeDetails
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Error "Server list not found: $Path"
        return @()
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $lineNum = 0
    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $lineNum++
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $parts = $line.Split(',') | ForEach-Object { $_.Trim() }
        if ($IncludeDetails) {
            $results.Add([ServerInfo]::new(
                $parts[0],
                (if ($parts.Count -gt 1) { $parts[1] } else { '' }),
                (if ($parts.Count -gt 2) { $parts[2] } else { '' }),
                $lineNum
            ))
        } else {
            $results.Add($parts[0])
        }
    }
    return ,$results.ToArray()
}

function Load-ClusterCatalogue {
    <#
    .SYNOPSIS
        Load cluster catalogue JSON and return the inner 'clusters' hashtable.

    .EXAMPLE
        $clusters = Load-ClusterCatalogue 'configs\clusters_catalogue.json'
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string] $Path)

    $cfg      = Import-JsonConfig -Path $Path -Required $true
    $clusters = $cfg['clusters']
    if (-not $clusters) { Write-Warning "No clusters defined in $Path" }
    return $clusters
}

function Test-ClusterDefinition {
    <#
    .SYNOPSIS
        Validate a cluster definition hashtable. Returns array of error strings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $ClusterDef,
        [Parameter(Mandatory)][string]   $ClusterId
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($f in @('display_name','servers','scom_group','environment')) {
        if (-not $ClusterDef.ContainsKey($f)) { $errors.Add("Missing required field '$f'") }
    }
    $servers = $ClusterDef['servers']
    if (-not $servers -or ($servers | Measure-Object).Count -eq 0) {
        $errors.Add("'servers' must be a non-empty list")
    }
    return ,$errors.ToArray()
}

function New-ServerInfo {
    <#
    .SYNOPSIS
        Factory for ServerInfo objects.

    .EXAMPLE
        $si = New-ServerInfo -Hostname 'srv01.corp.local' -IloIp '10.0.0.10'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Hostname,
        [string] $IpmiIp   = '',
        [string] $IloIp    = '',
        [int]    $LineNumber = 0
    )
    return [ServerInfo]::new($Hostname, $IpmiIp, $IloIp, $LineNumber)
}

# vim: ts=4 sw=4 et
