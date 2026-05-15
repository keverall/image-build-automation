#
# Public/Test-ClusterId.ps1 — Validate that a cluster ID exists in the cluster catalogue.
#

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
    $required = @('servers','scom_group','ilo_addresses')
    foreach ($f in $required) {
        if (-not $def.ContainsKey($f)) {
            Write-Error "Cluster '$ClusterId' missing required field '$f'."
            return $null
        }
    }
    return $def
}
