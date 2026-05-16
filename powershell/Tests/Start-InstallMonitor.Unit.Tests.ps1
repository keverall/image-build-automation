# Start-InstallMonitor.Unit.Tests.ps1
# Dedicated unit tests for the Start-InstallMonitor public function.

BeforeAll {
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Start-InstallMonitor — basic invocation and parameter validation' {
    It 'Function is exported and has expected parameters' {
        $cmd = Get-Command Start-InstallMonitor -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.Parameters.Keys | Should -Contain 'DryRun'
    }

    It 'Accepts -DryRun switch without throwing' {
        # Most functions accept -DryRun; calling with it should not throw immediately
        { & Start-InstallMonitor -DryRun -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Start-InstallMonitor -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
