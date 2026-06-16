#
# Public/Test-ClusterId.ps1 — Validate that a cluster ID exists in the cluster catalogue.
#

function Test-ClusterId {
    <#
    .SYNOPSIS
        Validate that a cluster ID exists in the cluster catalogue and return its definition.

    .DESCRIPTION
        Checks the cluster catalogue JSON file for the specified TargetId and
        validates that required fields (servers, scom_group, ilo_addresses) are
        present. Returns a hashtable with Success and Cluster properties on
        success, or Success=false with Error on failure.

        This function is intended for SCOM mode requests only. It validates that
        the supplied TargetId is a cluster ID (not a server name) and that the
        cluster definition has the correct structure in the catalogue. OneView mode
        requests should NOT call this function — they use OneViewClient.ResolveTarget()
        instead to validate server names or scopes against the OneView appliance.

    .PARAMETER TargetId
        Cluster identifier string. Must be a cluster ID as defined in
        clusters_catalogue.json. Server names are not accepted — use
        OneViewClient.ResolveTarget() for OneView server validation.

    .PARAMETER CataloguePath
        Path to clusters_catalogue.json (default: configs\clusters_catalogue.json).

    .EXAMPLE
        $def = Test-ClusterId -TargetId 'CLU-CLUSTER-01'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $TargetId,
        [string] $CataloguePath = 'configs\clusters_catalogue.json'
    )
    if (-not $TargetId) {
        return @{
            Success = $false
            Error   = 'Cluster ID is empty.'
        }
    }
    if (-not (Test-Path $CataloguePath)) {
        return @{
            Success = $false
            Error   = "Cluster catalogue not found: $CataloguePath"
        }
    }
    $catalogue = Import-JsonConfig -Path $CataloguePath
    $clusters = $catalogue.Get_Item('clusters')
    if (-not $clusters -or -not $clusters.ContainsKey($TargetId)) {
        return @{
            Success = $false
            Error   = "Cluster '$TargetId' not found in catalogue. Available: $($clusters.Keys -join ', ')"
        }
    }
    $def = $clusters[$TargetId]
    $required = @('servers', 'scom_group', 'ilo_addresses')
    foreach ($f in $required) {
        if (-not $def.ContainsKey($f)) {
            return @{
                Success = $false
                Error   = "Cluster '$TargetId' missing required field '$f'."
            }
        }
    }
    return @{
        Success = $true
        Cluster = $def
    }
}
