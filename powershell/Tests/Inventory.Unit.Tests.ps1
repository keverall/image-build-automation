# Inventory.Tests.ps1 — Tests for Inventory.psm1

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot        = $PSScriptRoot

    # TempDir — guard against $env:TEMP being null on non-Windows / Pester workers
    if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
    if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
    $Script:TempDir         = (Join-Path $env:TEMP "AutomationTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\','/')
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

Describe 'Load-ServerList' {
    It 'Returns hostname strings when IncludeDetails=$false' {
        $f = Join-Path $Script:ConfigDir 'server_list.txt'
        $servers = Load-ServerList -Path $f -IncludeDetails:$false
        $servers.Count | Should -BeGreaterOrEqual 2
        $servers[0] | Should -BeOfType [string]
    }

    It 'Returns ServerInfo objects when IncludeDetails=$true' {
        $f = Join-Path $Script:ConfigDir 'server_list.txt'
        $servers = Load-ServerList -Path $f -IncludeDetails:$true
        $servers[0] | Should -BeOfType [ServerInfo]
        $servers[0].Hostname | Should -Be 'srv01.corp.local'
        $servers[0].IPMI_IP  | Should -Be '192.168.1.101'
        $servers[0].ILO_IP   | Should -Be '192.168.1.201'
    }

    It 'ServerInfo.Name returns short hostname' {
        $servers = Load-ServerList -Path (Join-Path $Script:ConfigDir 'server_list.txt') -IncludeDetails:$true
        $servers[0].Name | Should -Be 'srv01'
    }
}

Describe 'Load-ClusterCatalogue' {
    It 'Returns clusters hashtable from JSON' {
        $f = Join-Path $Script:ConfigDir 'clusters_catalogue.json'
        $clusters = Load-ClusterCatalogue -Path $f
        $clusters.Count | Should -BeGreaterThan 0
        $clusters['TEST-CLUSTER'].display_name | Should -Be 'Test Cluster'
    }
}

Describe 'Test-ClusterDefinition' {
    It 'Returns empty array for a valid definition' {
        $def  = $Script:SampleClusterCatalogue.clusters['TEST-CLUSTER']
        $errors = Test-ClusterDefinition -ClusterDef $def -ClusterId 'TEST-CLUSTER'
        $errors.Count | Should -Be 0
    }

    It 'Reports missing required fields' {
        $badDef = @{ servers = @('a') }
        $errors = Test-ClusterDefinition -ClusterDef $badDef -ClusterId 'BAD'
        $errors | Should -Match 'display_name'
    }
}
