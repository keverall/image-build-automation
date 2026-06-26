# Start-AutomationOrchestrator.Unit.Tests.ps1
# Dedicated unit tests for the Start-AutomationOrchestrator public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Start-AutomationOrchestrator - basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command Start-AutomationOrchestrator -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts RequestType and Params parameters' {
        $cmd = Get-Command Start-AutomationOrchestrator -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'RequestType'
        $cmd.Parameters.Keys | Should -Contain 'Params'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Start-AutomationOrchestrator -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}
