#
# Public/Start-AutomationOrchestrator.ps1 — Unified orchestrator entry point.
#

function Start-AutomationOrchestrator {
    <#
    .SYNOPSIS
Execute an automation request with validation and routing.
         Mirrors AutomationOrchestrator.execute().

    .DESCRIPTION
        Validates the request parameters using _Validate-Request, then routes
        the request to the appropriate handler function based on the
        RequestType parameter. Returns a hashtable with success status and
        output from the handler. This is the unified entry point for all
        automation operations.

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
    $errors = _Validate-Request $RequestType $Params
    if ($errors) {
        return @{
            Success     = $false
            Errors      = ,$errors
            Timestamp   = (Get-Date).ToString('o')
            RequestType = $RequestType
        }
    }
    $result            = Invoke-RoutedRequest -RequestType $RequestType -Params $Params
    $result['Timestamp']   = (Get-Date).ToString('o')
    $result['RequestType'] = $RequestType
    return $result
}
