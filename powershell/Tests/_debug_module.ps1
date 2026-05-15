$ErrorActionPreference = 'Stop'
$AbsPath = Resolve-Path 'powershell/Automation/Automation.psd1'

Import-Module $AbsPath -Force -ErrorAction Stop -DisableNameChecking
$m = Get-Module -Name 'Automation'
Write-Host "Module name: $($m.Name)"
Write-Host "Exported functions count: $($m.ExportedFunctions.Count)"
$m.ExportedFunctions.Keys | Sort-Object | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }

# Also check what's in the module scope directly
$m.ExportedCommands.Keys | Sort-Object | Select-Object -First 30 | ForEach-Object { Write-Host " CMD: $_" }

# Check if functions exist at module level
$defFns = Get-Command -Module Automation | Sort-Object Name | Select-Object -First 30
Write-Host "Get-Command -Module: $($defFns.Count) functions"
$defFns | ForEach-Object { Write-Host "  $($_.Name)" }
