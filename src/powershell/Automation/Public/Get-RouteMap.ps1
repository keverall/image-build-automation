#
# Public/Get-RouteMap.ps1 — Returns the current request routing table.
#

function Get-RouteMap {
    <#
    .SYNOPSIS
        Return the current request-type → handler-function routing table.

    .DESCRIPTION
        Returns a hashtable mapping request type strings to their corresponding
        handler function names. This table is used by Invoke-RoutedRequest to
        dispatch requests to the appropriate handler function.

    .EXAMPLE
        $routes = Get-RouteMap
        # Returns: @{ build_iso = 'New-IsoBuild'; maintenance_enable = 'Set-MaintenanceMode'; ... }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return $script:RouteMap
}