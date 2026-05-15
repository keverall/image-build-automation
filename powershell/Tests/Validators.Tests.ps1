# Validators.Tests.ps1 — Tests for Invoke-Validator.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Test-ClusterId' {
    It 'Returns definition for a valid cluster ID' {
        $def = Test-ClusterId -ClusterId 'TEST-CLUSTER' -CataloguePath (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
        $null -ne $def | Should -Be $true
        $def['display_name'] | Should -Be 'Test Cluster'
    }

    It 'Returns $null for empty cluster_id' {
        $def = Test-ClusterId -ClusterId ''
        $null -eq $def | Should -Be $true
    }

    It 'Returns $null for a missing catalogue file' {
        $def = Test-ClusterId -ClusterId 'X' -CataloguePath 'C:\nonexistent.json'
        $null -eq $def | Should -Be $true
    }

    It 'Returns $null for a cluster not in the catalogue' {
        $def = Test-ClusterId -ClusterId 'NONEXISTENT-CLUSTER' -CataloguePath (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
        $null -eq $def | Should -Be $true
    }
}

Describe 'Test-ServerList' {
    It 'Returns a non-empty list for a valid server list' {
        $servers = Test-ServerList -ServerListPath (Join-Path $Script:ConfigDir 'server_list.txt')
        $servers.Count | Should -BeGreaterThan 0
        $servers[0] | Should -BeOfType [string]
    }

    It 'Returns empty array for a missing file' {
        $servers = Test-ServerList -ServerListPath 'C:\nonexistent_servers.txt'
        $servers.Count | Should -Be 0
    }
}

Describe 'Test-BuildParams' {
    It 'Returns no errors for a valid (or absent) ISO path' {
        $errors = Test-BuildParams -BaseIsoPath $null
        $errors.Count | Should -Be 0
    }

    It 'Reports an error for a non-existent ISO path' {
        # Assumes no file at this abstract path
        $errors = Test-BuildParams -BaseIsoPath 'C:\nonexistent_iso.iso'
        $errors | Should -Match 'Base ISO not found'
    }
}
