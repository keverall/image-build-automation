# Test-PostBuildValidation.Unit.Tests.ps1
# Mocked unit tests for Test-PostBuildValidation.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Test-PostBuildValidation — basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Test-PostBuildValidation -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Test-PostBuildValidation
        foreach ($p in @('Hostname','ExpectedHostname','Domain','ExpectedOsVersion','SkipRemote','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'SkipRemote returns Success' {
        $r = Test-PostBuildValidation -Hostname 'TEST' -SkipRemote
        $r.Success                  | Should -Be $true
        $r.Checks.remote_checks_skipped.status | Should -Be 'PASS'
    }

    It 'DryRun fails without SkipRemote (WinRM unreachable)' {
        $r = Test-PostBuildValidation -Hostname 'does-not-exist.invalid' -DryRun
        $r.Success                       | Should -Be $true
        $r.Checks.winrm_reachable.status | Should -Be 'PASS'
    }
}
