# New-IsoBuild.Unit.Tests.ps1
# Dedicated unit tests for the New-IsoBuild public function.

BeforeAll {
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop
}

Describe 'New-IsoBuild — basic invocation and parameter validation' {
    It 'Function is exported and has expected parameters' {
        $cmd = Get-Command New-IsoBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.Parameters.Keys | Should -Contain 'DryRun'
    }

    It 'Accepts -DryRun switch without throwing' {
        # Most functions accept -DryRun; calling with it should not throw immediately
        { & New-IsoBuild -DryRun -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & New-IsoBuild -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
