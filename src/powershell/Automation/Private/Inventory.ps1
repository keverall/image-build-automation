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
# Resolve-OneViewTarget - THE central single-server resolver for OneView tasks.
#
# This is the common module every OneView automation command that acts on ONE
# server (ISO attach/deploy, reboot, firmware, OS build, post-build validation)
# must use to turn operator input into a single, unambiguous target. It accepts
# EITHER a server name OR a serial number and resolves it - via the shared
# Get-OneViewServerTarget query (which connects through Resolve-OneViewSession and
# enforces exactly one match) - to the server hostname and iLO IP for downstream
# use. Because Get-OneViewServerTarget fails hard on an ambiguous (multi-match)
# result, this resolver inherits that strict single-server guarantee.
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
        number. In BOTH cases the target is resolved to its OneView server record
        (hostname + iLO IP) via Get-OneViewServerTarget, so destructive operations
        always deploy to / reboot / build the confirmed OneView server and never a
        free-floating name.

    .PARAMETER SerialNumber
        Hardware serial number. When supplied, -OneViewHost is required to
        resolve it. Takes precedence over -ServerName.

    .PARAMETER ServerName
        Server hostname / OneView name. Resolved against OneView (requires
        -OneViewHost) to confirm the target and obtain its iLO IP.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP. Required to resolve EITHER a serial or a
        server name, because both must be confirmed against OneView.

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
            -SrvrId $SerialNumber -IdentifierType Serial -DryRun:$DryRun
        if (-not $r.Success) {
            return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $SerialNumber; ResolvedBy = $null; Error = "Serial '$SerialNumber' not resolved in OneView: $($r.Error)" }
        }
        $name = if ($r.Details -and $r.Details.name) { $r.Details.name } else { $SerialNumber }
        $ilo  = if ($r.Details -and $r.Details.ilo_ip) { $r.Details.ilo_ip } else { '' }
        return @{ Success = $true; Identifier = $name; IloIp = $ilo; SerialNumber = $SerialNumber; ResolvedBy = 'Serial'; Error = $null }
    }

    if ($ServerName) {
        if (-not $OneViewHost) {
            return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $null; ResolvedBy = $null; Error = "OneViewHost is required to confirm -ServerName '$ServerName' against OneView." }
        }
        $r = Get-OneViewServerTarget -OneViewHost $OneViewHost `
            -SrvrId $ServerName -IdentifierType Name -DryRun:$DryRun
        if (-not $r.Success) {
            return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $null; ResolvedBy = $null; Error = "Server name '$ServerName' not confirmed in OneView: $($r.Error)" }
        }
        $ilo = if ($r.Details -and $r.Details.ilo_ip) { $r.Details.ilo_ip } else { '' }
        return @{ Success = $true; Identifier = $r.Server; IloIp = $ilo; SerialNumber = $null; ResolvedBy = 'Name'; Error = $null }
    }

    return @{ Success = $false; Identifier = $null; IloIp = ''; SerialNumber = $null; ResolvedBy = $null; Error = "Either -SerialNumber or -ServerName must be supplied." }
}
