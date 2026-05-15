#
# Public/Test-BuildParams.ps1 — Validate build parameters.
#

function Test-BuildParams {
    <#
    .SYNOPSIS
        Validate build parameters and return a list of validation errors (empty = valid).

    .PARAMETER BaseIsoPath
        Path to the base Windows ISO (required for ISO builds).

    .PARAMETER DryRun
        Whether the run is a dry run (no additional validation required).

    .EXAMPLE
        $errors = Test-BuildParams -BaseIsoPath 'C:\ISOs\server2022.iso'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $BaseIsoPath = $null,
        [bool]  $DryRun      = $false
    )
    $errors = @()
    if ($BaseIsoPath -and -not (Test-PathEx -Path $BaseIsoPath)) {
        $errors += "Base ISO not found: $BaseIsoPath"
    }
    return ,$errors
}
