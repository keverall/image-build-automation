# Inventory.Tests.ps1 — Tests for Inventory.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
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
