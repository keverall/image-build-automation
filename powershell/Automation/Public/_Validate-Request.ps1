#
# Public/_Validate-Request.ps1 — Private request validator (underscore-prefixed, not exported).
#

function _Validate-Request {
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
