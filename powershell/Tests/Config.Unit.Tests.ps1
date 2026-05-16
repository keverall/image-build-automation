# Config.Tests.ps1 — Tests for Config.psm1

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
    if (-not (Test-Path -Path $Script:ConfigDir)) { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }
    $Script:SampleConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'sample.json') -ErrorAction SilentlyContinue
    $Script:SampleServerList | Set-Content (Join-Path $Script:ConfigDir 'server_list.txt') -ErrorAction SilentlyContinue
    $Script:SampleClusterCatalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -ErrorAction SilentlyContinue

    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'

    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Import-JsonConfig' {
    It 'Loads a valid JSON file' {
        $result = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'sample.json')
        $result.name     | Should -Be 'test'
        $result.version  | Should -Be '1.0'
        $result.items.Count | Should -Be 1
    }

    It 'Returns empty hashtable for missing file when not required' {
        $result = Import-JsonConfig -Path 'C:\\nonexistent.json' -Required:$false
        $result.Count | Should -Be 0
    }

    It 'Throws when file is missing and required' {
        { Import-JsonConfig -Path 'C:\\nonexistent.json' -Required:$true } | Should -Throw
    }

    It 'Replaces ${VAR} placeholders with env vars' {
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_VAR', 'replaced_value', 'Process')
        $json  = '{"host":"${_TEST_PS_UTILS_VAR}","port":8080}'
        $fpath = Join-Path $Script:TempDir 'env_test.json'
        $json  | Set-Content $fpath -Encoding UTF8
        $loaded = Import-JsonConfig -Path $fpath
        $loaded['host'] | Should -Be 'replaced_value'
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_VAR', $null, 'Process')
    }
}

