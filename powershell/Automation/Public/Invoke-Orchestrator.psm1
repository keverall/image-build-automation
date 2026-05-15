#
# Invoke-Orchestrator.psm1 — Unified orchestrator equivalent of Python core/orchestrator.py
#

<#

.SYNOPSIS
    Unified entry point for all automation requests. Validates parameters, applies
    common settings, and dispatches to the correct handler via the Router.

#>

function Start-AutomationOrchestrator {
    <#
    .SYNOPSIS
        Execute an automation request with validation and routing.
        Mirrors Python AutomationOrchestrator.execute().

    .PARAMETER RequestType
        Request type string (build_iso, maintenance_enable, etc.).

    .PARAMETER Params
        Hashtable of request parameters.

    .RETURNS
        [hashtable] with at least: Success (bool), Output (string).

    .EXAMPLE
        Start-AutomationOrchestrator -RequestType 'build_iso' -Params @{ BaseIsoPath = 'C:\ISOs\base.iso' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $RequestType,
        [hashtable] $Params = @{}
    )

    Write-Verbose "Executing $RequestType"

    # Validate
    $errors = _Validate-Request $RequestType $Params
    if ($errors) {
        return @{
            Success    = $false
            Errors     = ,$errors
            Timestamp  = (Get-Date).ToString('o')
            RequestType = $RequestType
        }
    }

    # Route
    $result = Invoke-RoutedRequest -RequestType $RequestType -Params $Params
    $result['Timestamp']   = (Get-Date).ToString('o')
    $result['RequestType'] = $RequestType
    return $result
}

#region Private validation helper
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
#endregion

# vim: ts=4 sw=4 et
