param()

$ErrorActionPreference = 'SilentlyContinue'

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║  HPE ProLiant ISO Automation — Available Commands         ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

$makefile = Join-Path $PSScriptRoot '..' 'Makefile'
Select-String -Path $makefile -Pattern '^[a-zA-Z_-]+:.*?## .*$' | ForEach-Object {
    $parts = $_.Line -split ':.*?## '
    Write-Host ('  {0,-15} {1}' -f $parts[0].Trim(), $parts[1].Trim()) -ForegroundColor Green
}

Write-Host ''
