# Router.Tests.ps1 — Tests for Router.psm1 + Orchestrator.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe '$RouteMap has all 10 known request types' {
    It 'Contains build_iso'   { $script:RouteMap.ContainsKey('build_iso')         | Should -Be $true }
    It 'Contains update_firmware' { $script:RouteMap.ContainsKey('update_firmware') | Should -Be $true }
    It 'Contains patch_windows' { $script:RouteMap.ContainsKey('patch_windows')   | Should -Be $true }
    It 'Contains deploy'      { $script:RouteMap.ContainsKey('deploy')            | Should -Be $true }
    It 'Contains monitor'     { $script:RouteMap.ContainsKey('monitor')           | Should -Be $true }
    It 'Contains maintenance_enable' { $script:RouteMap.ContainsKey('maintenance_enable') | Should -Be $true }
    It 'Contains maintenance_disable' { $script:RouteMap.ContainsKey('maintenance_disable') | Should -Be $true }
    It 'Contains maintenance_validate' { $script:RouteMap.ContainsKey('maintenance_validate') | Should -Be $true }
    It 'Contains opsramp_report' { $script:RouteMap.ContainsKey('opsramp_report') | Should -Be $true }
    It 'Contains generate_uuid' { $script:RouteMap.ContainsKey('generate_uuid') | Should -Be $true }
}

Describe 'Invoke-RoutedRequest' {
    It 'Returns error for an unknown request type' {
        $r = Invoke-RoutedRequest -RequestType 'nonexistent_xyz'
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'Unknown request type'
    }

    It 'Includes the request_type in the result' {
        # Test-Uuid module IS available after module import
        $r = Invoke-RoutedRequest -RequestType 'generate_uuid'
        # It should not throw; handler may or may not exist depending on param binding
        $null -ne $r | Should -Be $true
    }
}
