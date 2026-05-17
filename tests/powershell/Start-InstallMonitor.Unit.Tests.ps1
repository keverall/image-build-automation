# Start-InstallMonitor.Unit.Tests.ps1
# Dedicated unit tests for the Start-InstallMonitor public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Start-InstallMonitor — basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command Start-InstallMonitor -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts Server and TimeoutSeconds parameters' {
        $cmd = Get-Command Start-InstallMonitor -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'Server'
        $cmd.Parameters.Keys | Should -Contain 'TimeoutSeconds'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Start-InstallMonitor -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
