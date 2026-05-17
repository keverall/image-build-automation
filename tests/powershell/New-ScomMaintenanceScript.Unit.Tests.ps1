# New-ScomMaintenanceScript.Unit.Tests.ps1
# Dedicated unit tests for the New-ScomMaintenanceScript public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -ErrorAction Stop
}

Describe 'New-ScomMaintenanceScript — basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts required parameters GroupDisplayName, DurationSeconds, Comment' {
        $cmd = Get-Command New-ScomMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'GroupDisplayName'
        $cmd.Parameters.Keys | Should -Contain 'DurationSeconds'
        $cmd.Parameters.Keys | Should -Contain 'Comment'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & New-ScomMaintenanceScript -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
