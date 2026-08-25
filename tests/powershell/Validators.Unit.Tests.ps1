# Validators.Tests.ps1 - Tests for Invoke-Validator.psm1

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    $Script:TestRoot = $PSScriptRoot

    # TempDir - guard against $env:TEMP / $pwd being null in Pester discovery context
    if (-not $env:TEMP) { $env:TEMP = '/tmp' }
    if (-not $env:TMP) { $env:TMP = '/tmp' }
    $Script:TempDir = (Join-Path $env:TEMP "AutomationTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\', '/')
    if (-not (Test-Path -Path $Script:TempDir)) { New-Item -ItemType Directory -Path $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null | Out-Null }

    # Minimal config fixtures
    $Script:SampleConfig = @{ name = 'test'; version = '1.0'; items = @(@{ id = 1; enabled = $true }) }
    $Script:SampleServerList = @"
# Test server list
srv01.corp.local,192.168.1.101,192.168.1.201
srv02.corp.local,192.168.1.102,192.168.1.202
srv03
"@
    $Script:SampleClusterCatalogue = @{ clusters = @{
            'TEST-CLUSTER' = @{
                display_name  = 'Test Cluster'
                servers       = @('srv01.corp.local', 'srv02.corp.local')
                scom_group    = 'Test SCOM Group'
                ilo_addresses = @{ 'srv01.corp.local' = '192.168.1.201'; 'srv02.corp.local' = '192.168.1.202' }
                environment   = 'test'
            }
        }
    }

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir)) { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }
    $Script:SampleConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'sample.json') -ErrorAction SilentlyContinue
    $Script:SampleServerList | Set-Content (Join-Path $Script:ConfigDir 'server_list.txt') -ErrorAction SilentlyContinue
    $Script:SampleClusterCatalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -ErrorAction SilentlyContinue

    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'

    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Test-ClusterId' {
    It 'Returns definition for a valid cluster ID' {
        $result = Test-ClusterId -TargetId 'TEST-CLUSTER' -CataloguePath (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
        $result.Success | Should -Be $true
        $null -ne $result.Cluster | Should -Be $true
        $result.Cluster['display_name'] | Should -Be 'Test Cluster'
    }

    It 'Returns failure for a missing catalogue file' {
        $result = Test-ClusterId -TargetId 'X' -CataloguePath 'C:\nonexistent.json'
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found'
    }

    It 'Returns failure for a cluster not in the catalogue' {
        $result = Test-ClusterId -TargetId 'NONEXISTENT-CLUSTER' -CataloguePath (Join-Path $Script:ConfigDir 'clusters_catalogue.json')
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found'
    }
}

Describe 'Test-ServerList' {
    It 'Returns a non-empty list for a valid server list' {
        $result = Test-ServerList -ServerListPath (Join-Path $Script:ConfigDir 'server_list.txt') -PassThru
        $result.Success | Should -Be $true
        $result.Servers.Count | Should -BeGreaterThan 0
        $result.Servers[0] | Should -BeOfType [string]
    }

    It 'Returns failure for a missing file' {
        $result = Test-ServerList -ServerListPath 'C:\nonexistent_servers.txt' -PassThru
        $result.Success | Should -Be $false
        $result.Servers.Count | Should -Be 0
    }
}

Describe 'Test-BuildParams' {
    It 'Fails when no ISO path is supplied' {
        $result = Test-BuildParams -BaseIsoPath $null -PassThru
        $result.Success | Should -Be $false
        $result.Errors | Should -Match 'required'
    }

    It 'Rejects a local drive path (iLO cannot reach local drives)' {
        $result = Test-BuildParams -BaseIsoPath 'C:\nonexistent_iso.iso' -PassThru
        $result.Success | Should -Be $false
        $result.IsoUrl | Should -BeNullOrEmpty
        $result.Errors.Count | Should -BeGreaterThan 0
        $result.Errors | Should -Match 'not supported|not found'
    }

    It 'Resolves a UNC/SMB share to a cifs:// URL iLO can mount' {
        # Dry run skips existence check so the resolution is what we verify
        $result = Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' -DryRun $true -PassThru
        $result.Success | Should -Be $true
        $result.IsoUrl | Should -Be 'cifs://fileserver/isos/WinSrv2025.iso'
    }

    It 'Reports an error for a non-existent network ISO path' {
        # Assumes no file at this abstract share
        $result = Test-BuildParams -BaseIsoPath '\\fileserver\isos\nonexistent.iso' -PassThru
        $result.Success | Should -Be $false
        $result.IsoUrl | Should -Be 'cifs://fileserver/isos/nonexistent.iso'
        $result.Errors | Should -Match 'not found or not accessible'
    }

    It 'Classifies errors as ISO-related vs firmware-file-related' {
        $result = Test-BuildParams -BaseIsoPath 'C:\bad.iso' `
            -FirmwareFolders @('C:\fw') -PassThru -DryRun $true
        ($result.Errors | Where-Object { $_ -match '^Base ISO:' }).Count | Should -BeGreaterThan 0
        ($result.Errors | Where-Object { $_ -match '^Firmware file:' }).Count | Should -BeGreaterThan 0
    }
}
