#
# Private/Audit.ps1 — Audit helper helpers
#

function New-AuditLogger {
    <#
    .SYNOPSIS
        Creates an AuditLogger instance.

    .EXAMPLE
        $audit = New-AuditLogger -Category 'maintenance'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Category,
        [string] $LogDir    = 'logs',
        [string] $MasterLog = 'audit.log'
    )
    return [AuditLogger]::new($Category, $LogDir, $MasterLog)
}
