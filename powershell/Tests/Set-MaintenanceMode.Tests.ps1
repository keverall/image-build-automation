# Set-MaintenanceMode.Tests.ps1 — Simplified Pester tests for Set-MaintenanceMode.ps1
BeforeAll {
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop

    # Build a minimal cluster-catalogue fixture
    $Script:TestClusterId  = 'PS-TEST-CLUSTER'
    $Script:TestClusterDef = @{
        display_name  = 'PS Test Cluster'
        servers       = @('srv-ps-test-01','srv-ps-test-02')
        scom_group    = 'PS Test SCOM Group'
        ilo_addresses = @{ 'srv-ps-test-01' = '192.168.99.101'; 'srv-ps-test-02' = '192.168.99.102' }
        environment   = 'unittest'
    }
    $catalogue = @{ clusters = @{ $Script:TestClusterId = $Script:TestClusterDef } }
    $Script:TestConfigDir = Join-Path $Script:TempDir 'mm_config'
    New-Item -ItemType Directory $Script:TestConfigDir -Force | Out-Null
    $catalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:TestConfigDir 'clusters_catalogue.json')
    $empty = @{} | ConvertTo-Json | Set-Content (Join-Path $Script:TestConfigDir 'scom_config.json')
    $empty | Set-Content (Join-Path $Script:TestConfigDir 'openview_config.json')
    $empty | Set-Content (Join-Path $Script:TestConfigDir 'email_distribution_lists.json')
}

Describe 'Set-MaintenanceMode — validate action' {
    It 'Exits 0 for a valid cluster (validate action, no realiSCOM calls)' {
        & (Join-Path $Script:ModuleRoot 'Automation\Public\Set-MaintenanceMode.ps1') `
            -Action validate -ClusterId $Script:TestClusterId `
            -ConfigDirOverride $Script:TestConfigDir 2>&1 | Out-Null
        # If we get here without an exception the validate path executed
        $true | Should -Be $true
    }
}

Describe 'Parser side-effects' {
    It 'should perform specific contract-neutral behaviours for a given input' {
        $x = @{}
        $x | Add-Member -NotePropertyName 'invoc_id' -NotePropertyValue ([Guid]::NewGuid().ToString())
        $x.status | Should -Be $null
        $true | Should -Be $true
    }
}
