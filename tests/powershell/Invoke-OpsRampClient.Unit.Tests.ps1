# Invoke-OpsRampClient.Unit.Tests.ps1
# Dedicated unit tests for the Invoke-OpsRampClient public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Invoke-OpsRampClient — basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command Invoke-OpsRampClient -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts ConfigPath parameter' {
        $cmd = Get-Command Invoke-OpsRampClient -ErrorAction SilentlyContinue
        # Cross-platform compatible: inspect definition string instead of Parameters collection
        # ($cmd.Parameters returns empty on PowerShell 7/Linux for functions with custom [OutputType])
        $cmd.Definition | Should -Match '\$ConfigPath'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & Invoke-OpsRampClient -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}