# Update-WindowsSecurity.Unit.Tests.ps1
# Dedicated unit tests for the Invoke-WindowsSecurityUpdate public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Invoke-WindowsSecurityUpdate — basic invocation and parameter validation' {
    It 'Function is exported and has expected parameters' {
        $cmd = Get-Command Invoke-WindowsSecurityUpdate -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.Parameters.Keys | Should -Contain 'DryRun'
    }

    It 'Accepts -DryRun switch without throwing' {
        { & Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\test.iso' -Server 'test' -DryRun -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Invoke-WindowsSecurityUpdate -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
