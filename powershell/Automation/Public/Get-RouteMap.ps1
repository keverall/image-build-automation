#
# Public/Get-RouteMap.ps1 — Returns the current request routing table.
#

function Get-RouteMap {
    <#
    .SYNOPSIS
        Return the current request-type → handler-function routing table.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return $script:RouteMap
}
