# Test-PreBuildValidation.Unit.Tests.ps1
# Mocked unit tests for Test-PreBuildValidation.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Test-PreBuildValidation — basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Test-PreBuildValidation -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Test-PreBuildValidation
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','IsoUrl','DryRun','SkipOneView','SkipIlo','SkipDpMp')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with all skips returns Success' {
        $r = Test-PreBuildValidation -ServerIdentifier 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        $r.Success       | Should -Be $true
        $r.Server        | Should -Be 'TEST'
        $r.Checks.Keys.Count | Should -BeGreaterThan 0
    }

    It 'Fails iso_url_provided when IsoUrl empty' {
        $r = Test-PreBuildValidation -ServerIdentifier 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        ($r.Checks['iso_url_provided'].status) | Should -Be 'FAIL'
    }

    It 'Returns Checks dictionary even when nothing configured' {
        $r = Test-PreBuildValidation -ServerIdentifier 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        $r.Checks            | Should -Not -Be $null
        $r.Checks.audit_recorded | Should -Not -Be $null
    }
}
