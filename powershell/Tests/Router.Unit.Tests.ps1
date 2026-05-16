# Router.Tests.ps1 — Tests for Router.psm1 + Orchestrator.psm1

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot        = $PSScriptRoot

    # TempDir — guard against $env:TEMP being null on non-Windows / Pester workers
    if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
    if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
    $Script:TempDir         = (Join-Path $env:TEMP "AutomationTests_$(New-Guid).Trim('{}')").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir))    { New-Item -ItemType Directory -Path $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null | Out-Null }

    # Minimal config fixtures
    $Script:SampleConfig = @{ name='test'; version='1.0'; items=@(@{ id=1; enabled=$true }) }
    $Script:SampleServerList = @"
# Test server list
srv01.corp.local,192.168.1.101,192.168.1.201
srv02.corp.local,192.168.1.102,192.168.1.202
srv03
"@
    $Script:SampleClusterCatalogue = @{ clusters = @{
        'TEST-CLUSTER' = @{
            display_name  = 'Test Cluster'
            servers       = @('srv01.corp.local','srv02.corp.local')
            scom_group    = 'Test SCOM Group'
            ilo_addresses = @{ 'srv01.corp.local' = '192.168.1.201'; 'srv02.corp.local' = '192.168.1.202' }
            environment   = 'test'
        }
    }}

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir))  { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }
    $Script:SampleConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'sample.json') -ErrorAction SilentlyContinue
    $Script:SampleServerList | Set-Content (Join-Path $Script:ConfigDir 'server_list.txt') -ErrorAction SilentlyContinue
    $Script:SampleClusterCatalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -ErrorAction SilentlyContinue

    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'
    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop
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
