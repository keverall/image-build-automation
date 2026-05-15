#
# Audit.psm1 — Audit helper functions
# NOTE: AuditLogger class is defined in Automation.psm1 (root) for type-visibility.
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

# vim: ts=4 sw=4 et
