#
# Private/Base.ps1 — AutomationBase class helper functions.
#

function New-AutomationBase {
    <#
    .SYNOPSIS
        Factory for AutomationBase (useful for classes that cannot inherit in PS without extra steps).

    .EXAMPLE
        $base = New-AutomationBase -ConfigDir 'configs' -OutputDir 'output'
    #>
    [CmdletBinding()]
    [OutputType([AutomationBase])]
    param(
        [string] $ConfigDir = 'configs',
        [string] $OutputDir = 'output',
        [bool]   $DryRun    = $false
    )
    return [AutomationBase]::new($ConfigDir, $OutputDir, $DryRun)
}
