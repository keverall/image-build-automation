#
# Public/New-ScomConnection.ps1 — Returns a PowerShell command string for a SCOM 2015 management-group connection.
#

function New-ScomConnection {
    <#
    .SYNOPSIS
        Returns a PowerShell command string that creates an SCOM 2015 management-group connection.

    .PARAMETER ManagementServer
        SCOM management server hostname / IP.

    .EXAMPLE
        $script = New-ScomConnection -ManagementServer 'scom01.corp.local'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ManagementServer
    )
    return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$ManagementServer" -ErrorAction Stop
"@
}
