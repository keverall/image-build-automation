#
# Private/Router.ps1 — Request routing equivalent of Python core/router.py
#

function Invoke-RoutedRequest {
    <#
    .SYNOPSIS
        Routes a request to the appropriate handler function based on request type.
        Mirrors Python route_request(request_type, params).

    .PARAMETER RequestType
        One of the known request types (e.g. 'build_iso', 'maintenance_enable').

    .PARAMETER Params
        Hashtable of additional parameters forwarded to the handler.

    .RETURNS
        [hashtable] with at least keys: Success (bool), Output (string).

    .EXAMPLE
        Invoke-RoutedRequest -RequestType 'build_iso' -Params @{ BaseIsoPath = 'C:\ISOs\base.iso' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $RequestType,
        [hashtable] $Params = @{}
    )
    if (-not $script:RouteMap.ContainsKey($RequestType)) {
        Write-Error "Unknown request type: $RequestType"
        return @{
            Success        = $false
            Error          = "Unknown request type: $RequestType"
            AvailableTypes = @($script:RouteMap.Keys)
        }
    }
    $handlerName = $script:RouteMap[$RequestType]
    Write-Verbose "Routing $RequestType → $handlerName"
    if (Get-Command $handlerName -ErrorAction SilentlyContinue) {
        try {
            $result = & $handlerName @Params
            if ($result -is [hashtable]) {
                $result['request_type'] = $RequestType
                return $result
            }
            return @{ Success = $true; Output = ($result | Out-String) }
        }
        catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    }
    return @{ Success = $false; Error = "Handler '$handlerName' not found. Is the module loaded?" }
}
