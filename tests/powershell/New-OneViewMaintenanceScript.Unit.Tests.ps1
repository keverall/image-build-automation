# New-OneViewMaintenanceScript.Unit.Tests.ps1
# Dedicated unit tests for the New-OneViewMaintenanceScript public function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'New-OneViewMaintenanceScript — basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command New-OneViewMaintenanceScript -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Accepts required parameters Appliance, ScopeName, Operation' {
        $cmd = Get-Command New-OneViewMaintenanceScript -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'Appliance'
        $cmd.Parameters.Keys | Should -Contain 'ScopeName'
        $cmd.Parameters.Keys | Should -Contain 'Operation'
    }

    It 'Returns a string script block for enable operation with configurable module name' {
        $result = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'TestScope' -Operation 'enable' -ModuleName 'HPEOneView.840'
        $result | Should -BeOfType [string]
        $result | Should -Match 'Import-Module HPEOneView.840'
        $result | Should -Match 'Connect-OVMgmt'
        $result | Should -Match 'Get-OVScope'
        $result | Should -Match 'Enable-OVMaintenanceMode'
    }

    It 'Accepts ModuleName parameter with custom value' {
        $result = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'TestScope' -Operation 'enable' -ModuleName 'HPEOneView.910'
        $result | Should -Match 'Import-Module HPEOneView.910'
    }

    It 'Returns a string script block for disable operation with configurable module name' {
        $result = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'TestScope' -Operation 'disable' -ModuleName 'HPEOneView.840'
        $result | Should -BeOfType [string]
        $result | Should -Match 'Import-Module HPEOneView.840'
        $result | Should -Match 'Disable-OVMaintenanceMode'
    }

    It 'Includes Async parameter when Async is true' {
        $result = New-OneViewMaintenanceScript -Appliance 'oneview.example.com' -ScopeName 'TestScope' -Operation 'enable' -Async $true -ModuleName 'HPEOneView.840'
        $result | Should -Match '\-Async'
    }

    It 'Rejects unknown parameters (strict mode)' {
        { & New-OneViewMaintenanceScript -NonExistentParam 2>&1 } | Should -Not -Be $null
    }
}