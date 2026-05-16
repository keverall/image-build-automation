# Validators.Tests.ps1 — Tests for Invoke-Validator.psm1

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot        = $PSScriptRoot

    # TempDir — guard against $env:TEMP / $pwd being null in Pester discovery context
    if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
    if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
    $Script:TempDir   = (Join-Path $env:TEMP "AutomationTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir))  { New-Item -ItemType Directory -Path $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null | Out-Null }

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
