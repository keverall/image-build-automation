#
# Public/Start-AutomationOrchestrator.ps1 - Unified orchestrator entry point.
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

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Start-AutomationOrchestrator -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with at least: Success (bool), Output (string). With
        -Json, a JSON [string] representation of the same data.

    .EXAMPLE
        Start-AutomationOrchestrator -RequestType 'build_iso' -Params @{ BaseIsoPath = 'C:\ISOs\base.iso' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $RequestType,
        [hashtable] $Params = @{},
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )
    Write-Verbose "Executing $RequestType"
    $errors = _Validate-Request $RequestType $Params
    if ($errors) {
        return (_Publish-Result -Result @{
            Success     = $false
            Errors      = ,$errors
            Timestamp   = Get-UtcTimestamp
            RequestType = $RequestType
        } -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
    }
    $result            = Invoke-RoutedRequest -RequestType $RequestType -Params $Params
    $result['Timestamp'] = Get-UtcTimestamp
    $result['RequestType'] = $RequestType
    return (_Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}
