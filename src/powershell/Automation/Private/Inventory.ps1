#
# Private/Inventory.ps1 - Server inventory and cluster catalogue helpers.
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
            $ipmi = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            $ilo  = if ($parts.Count -gt 2) { $parts[2] } else { '' }
            $results.Add([ServerInfo]::new($parts[0], $ipmi, $ilo, $lineNum))
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
        [Parameter(Mandatory)][string]   $TargetId
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

#
# Resolve-OneViewTarget - Accept a server name OR serial number for any OneView task.
#
# Normalises operator input so every OneView automation command can be targeted by
# either identifier. When -SerialNumber is supplied, it is resolved to the server
# via Get-OneViewServerTarget (-IdentifierType Serial); the resolved hostname (and
# iLO IP when available) is returned for downstream use.
#
# Returns a hashtable:
#   Success      [bool]
#   Identifier   [string] - the value the caller should use as the server name
#   IloIp        [string] - resolved iLO IP (may be empty)
#   SerialNumber [string] - the original serial, if supplied
#   ResolvedBy   [string] - 'Serial' | 'Name' | $null
#   Error         [string]
#
function Resolve-OneViewTarget {
    <#
    .SYNOPSIS
        Normalise a server name or serial number into a OneView target.

    .DESCRIPTION
        Lets any OneView automation task accept EITHER a server name or a serial
        number. A serial is resolved to its OneView server record (hostname + iLO
        IP) via Get-OneViewServerTarget. A name is passed through unchanged.

    .PARAMETER SerialNumber
        Hardware serial number. When supplied, -OneViewHost is required to
        resolve it. Takes precedence over -ServerName.

    .PARAMETER ServerName
        Server hostname / OneView name. Used verbatim when no -SerialNumber.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (required to resolve a serial).

    .PARAMETER DryRun
        Resolve without performing a real OneView query.

    .EXAMPLE
        Resolve-OneViewTarget -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.ad.example.com'
    #>
    [CmdletBinding()]
    param(
        [string] $SerialNumber,
        [string] $ServerName,
        [string] $OneViewHost,
        [switch] $DryRun
    )

    if ($SerialNumber) {
        if (-not $OneViewHost) {
            return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $SerialNumber; ResolvedBy = $null; Error = "OneViewHost is required to resolve -SerialNumber '$SerialNumber'." }
        }
        $r = Get-OneViewServerTarget -OneViewHost $OneViewHost `
            -ServerIdentifier $SerialNumber -IdentifierType Serial -DryRun:$DryRun
        if (-not $r.Success) {
            return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $SerialNumber; ResolvedBy = $null; Error = "Serial '$SerialNumber' not resolved in OneView: $($r.Error)" }
        }
        $name = if ($r.Details -and $r.Details.name) { $r.Details.name } else { $SerialNumber }
        $ilo  = if ($r.Details -and $r.Details.ilo_ip) { $r.Details.ilo_ip } else { '' }
        return @{ Success = $true; Identifier = $name; IloIp = $ilo; SerialNumber = $SerialNumber; ResolvedBy = 'Serial'; Error = $null }
    }

    if ($ServerName) {
        return @{ Success = $true; Identifier = $ServerName; IloIp = ''; SerialNumber = $null; ResolvedBy = 'Name'; Error = $null }
    }

    return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $null; ResolvedBy = $null; Error = "Either -SerialNumber or -ServerName must be supplied." }
}
