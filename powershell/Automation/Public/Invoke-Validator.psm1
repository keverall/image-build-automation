#
# Invoke-Validator.psm1 — Input validation equivalent of Python core/validators.py
#

<#

.SYNOPSIS
    Input validation functions for request types and cluster / server lists.

#>

function Test-ClusterId {
    <#
    .SYNOPSIS
        Validate that a cluster ID exists in the cluster catalogue and return its definition.

    .PARAMETER ClusterId
        Cluster identifier string.

    .PARAMETER CataloguePath
        Path to clusters_catalogue.json (default: configs\clusters_catalogue.json).

    .EXAMPLE
        $def = Test-ClusterId -ClusterId 'PROD-CLUSTER-01'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ClusterId,
        [string] $CataloguePath = 'configs\clusters_catalogue.json'
    )
    if (-not $ClusterId) {
        Write-Error 'Cluster ID is empty.'
        return $null
    }
    if (-not (Test-Path $CataloguePath)) {
        Write-Error "Cluster catalogue not found: $CataloguePath"
        return $null
    }
    $catalogue = Import-JsonConfig -Path $CataloguePath
    $clusters  = $catalogue.Get_Item('clusters')
    if (-not $clusters -or -not $clusters.ContainsKey($ClusterId)) {
        Write-Error "Cluster '$ClusterId' not found in catalogue. Available: $($clusters.Keys -join ', ')"
        return $null
    }
    $def = $clusters[$ClusterId]
    # Minimal required-fields check
    $required = @('servers','scom_group','ilo_addresses')
    foreach ($f in $required) {
        if (-not $def.ContainsKey($f)) {
            Write-Error "Cluster '$ClusterId' missing required field '$f'."
            return $null
        }
    }
    return $def
}

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

function Test-BuildParams {
    <#
    .SYNOPSIS
        Validate build parameters and return a list of validation errors (empty = valid).

    .PARAMETER BaseIsoPath
        Path to the base Windows ISO (required for ISO builds).

    .PARAMETER DryRun
        Whether the run is a dry run (no additional validation required).

    .EXAMPLE
        $errors = Test-BuildParams -BaseIsoPath 'C:\ISOs\server2022.iso'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $BaseIsoPath = $null,
        [bool]  $DryRun      = $false
    )
    $errors = @()
    if ($BaseIsoPath -and -not (Test-PathEx -Path $BaseIsoPath)) {
        $errors += "Base ISO not found: $BaseIsoPath"
    }
    return ,$errors
}

# vim: ts=4 sw=4 et
