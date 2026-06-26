param()

<#
.SYNOPSIS
    Display available Makefile commands and targets.

.DESCRIPTION
    Parses Makefile for documented targets and displays them in a formatted table.
    Shows all available 'make' commands with their descriptions from inline comments.

.EXAMPLE
    pwsh -File scripts/Show-Help.ps1
    
.EXAMPLE
    ./scripts/Show-Help.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║  HPE ProLiant ISO Automation - Available Commands         ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

$makefile = Join-Path $PSScriptRoot '..' 'Makefile'
Select-String -Path $makefile -Pattern '^[a-zA-Z_-]+:.*?## .*$' | ForEach-Object {
    $parts = $_.Line -split ':.*?## '
    Write-Host ('  {0,-15} {1}' -f $parts[0].Trim(), $parts[1].Trim()) -ForegroundColor Green
}

Write-Host ''
