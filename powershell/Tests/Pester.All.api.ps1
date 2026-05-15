# Pester Integration Tests — combined run
Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\Automation.psd1') -RequiredVersion 1.0.0 -Force -ErrorAction Stop
Invoke-Pester @{    PassThru = $true
    Tag = 'Integration' }
