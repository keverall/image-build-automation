# Pester Integration Tests — combined run
Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\powershell\Automation\Automation.psd1') -RequiredVersion 1.0.0 -Force -ErrorAction Stop -WarningAction SilentlyContinue
Invoke-Pester @{    PassThru = $true
    Tag                      = 'Integration' 
}
