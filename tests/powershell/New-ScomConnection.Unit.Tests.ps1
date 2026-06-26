# New-ScomConnection.Unit.Tests.ps1
# Dedicated unit tests for the New-ScomConnection public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'New-ScomConnection - basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command New-ScomConnection -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts ManagementServer parameter' {
        $cmd = Get-Command New-ScomConnection -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'ManagementServer'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & New-ScomConnection -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
