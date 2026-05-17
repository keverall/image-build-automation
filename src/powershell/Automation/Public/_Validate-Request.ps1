#
# Public/_Validate-Request.ps1 — Private request validator (underscore-prefixed, not exported).
#

function _Validate-Request {
    <#
    .SYNOPSIS
        Validate a request type and its parameters before routing.

    .DESCRIPTION
        Performs common validation checks for automation requests including
        build parameters and cluster ID validation. Returns an array of
        error strings (empty array means valid).

    .PARAMETER RequestType
        The request type identifier (e.g. 'build_iso', 'maintenance_enable').

    .PARAMETER Params
        Hashtable of request parameters to validate.

    .EXAMPLE
        $errors = _Validate-Request -RequestType 'build_iso' -Params @{ base_iso = 'C:\ISO.iso' }

    .EXAMPLE
        $errors = _Validate-Request -RequestType 'maintenance_enable' -Params @{ cluster_id = 'PROD-CLUSTER-01' }
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([string]$RequestType, [hashtable]$Params)
    $errors = @()
    if ($RequestType -in @('build_iso','patch_windows')) {
        $errors += Test-BuildParams -BaseIsoPath $Params.Get_Item('base_iso')
    }
    if ($RequestType.StartsWith('maintenance_')) {
        $def = Test-ClusterId -ClusterId $Params.Get_Item('cluster_id')
        if (-not $def) { $errors += "Invalid cluster ID: $($Params.Get_Item('cluster_id'))" }
    }
    return ,$errors
}
