# Audit.Tests.ps1 — Tests for Audit.psm1

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
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'
    Ensure-DirectoryExists -Path $Script:AuditDir
    # Remove any leftover master log
    Remove-Item (Join-Path $Script:AuditDir 'audit.log') -ErrorAction SilentlyContinue
}

Describe 'New-AuditLogger / AuditLogger' {
    $audit = $null
    BeforeEach { $Script:audit = New-AuditLogger -Category 'unittest' -LogDir $Script:AuditDir }

    It 'Creates an AuditLogger with given category' {
        $audit.Category | Should -Be 'unittest'
    }

    It 'Records an entry on Log() call' {
        $entry = $audit.Log('test_action', 'INFO', 'srv01', 'details here')
        $entry.action | Should -Be 'test_action'
        $entry.status | Should -Be 'INFO'
        $entry.server  | Should -Be 'srv01'
        $audit.Entries.Count | Should -Be 1
    }

    It 'Log returns the record that was appended' {
        $e = $audit.Log('action_a', 'SUCCESS', '', 'info')
        $e.action  | Should -Be 'action_a'
        $e.status  | Should -Be 'SUCCESS'
    }

    It 'Save() creates a classified JSON file' {
        $audit.Log('x','INFO','','d')
        $f = $audit.Save('test_audit.json')
        Test-Path $f | Should -Be $true
        (Get-Content $f -Raw) | Should -Match 'category'
    }

    It 'Save() auto-generates filename when none provided' {
        $audit.Log('x','INFO')
        $f = $audit.Save('auto_gen.json')
        $f | Should -Match '^.*unittest_auto_gen\.json$'
    }

    It 'AppendToMaster() appends to the master log file' {
        $audit.Log('master_test','INFO')
        $audit.AppendToMaster()
        $master = Join-Path $Script:AuditDir 'audit.log'
        Test-Path $master | Should -Be $true
        $content = Get-Content $master -Raw
        $content | Should -Match 'master_test'
    }

    It 'Clear() empties the in-memory entries list' {
        $audit.Log('a','INFO'); $audit.Log('b','INFO')
        $audit.Entries.Count | Should -Be 2
        $audit.Clear()
        $audit.Entries.Count | Should -Be 0
    }
}
