#
# Public/Start-AutomationOrchestrator.ps1 — Unified orchestrator entry point.
#

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
