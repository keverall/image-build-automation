param()

<#
.SYNOPSIS
    Display available Makefile commands and targets.

.DESCRIPTION
    Parses Makefile for documented targets and displays them in a formatted table.
    Shows all available 'make' commands with their descriptions from inline comments.

    Uses Write-Output with ANSI escape codes (not Write-Host) so that the
    PSScriptAnalyzer AvoidUsingWriteHost rule is not triggered, while still
    rendering colored output in a supporting terminal.

.EXAMPLE
    pwsh -File scripts/Show-Help.ps1
    
.EXAMPLE
    ./scripts/Show-Help.ps1
#>

# ANSI color escape codes (safe with Write-Output; avoids AvoidUsingWriteHost)
$Cyan = "$([char]27)[36m"
$Green = "$([char]27)[32m"
$Reset = "$([char]27)[0m"

Write-Output ''
Write-Output "${Cyan}╔══════════════════════════════════════════════════════════╗${Reset}"
Write-Output "${Cyan}║  HPE ProLiant ISO Automation - Available Commands         ║${Reset}"
Write-Output "${Cyan}╚══════════════════════════════════════════════════════════╝${Reset}"
Write-Output ''

$makefile = Join-Path $PSScriptRoot '..' 'Makefile'
Select-String -Path $makefile -Pattern '^[a-zA-Z_-]+:.*?## .*$' | ForEach-Object {
    $parts = $_.Line -split ':.*?## '
    Write-Output ("${Green}  {0,-15} {1}${Reset}" -f $parts[0].Trim(), $parts[1].Trim())
}

Write-Output ''
