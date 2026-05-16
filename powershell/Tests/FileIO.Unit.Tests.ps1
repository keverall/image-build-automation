# FileIO.Tests.ps1 — Tests for FileIO.psm1

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
    $Script:TestDir = Join-Path $Script:TempDir 'fileio'
    if (-not (Test-Path -Path $Script:TestDir))  { New-Item -ItemType Directory -Path $Script:TestDir -Force -ErrorAction SilentlyContinue | Out-Null }
}

Describe 'Ensure-DirectoryExists' {
    It 'Returns the given path' {
        $p = Join-Path $Script:TestDir 'subdir'
        $r = Ensure-DirectoryExists -Path $p
        $r | Should -Be $p
    }

    It 'Does not throw when directory already exists' {
        $p = Join-Path $Script:TestDir 'subdir'
        { Ensure-DirectoryExists -Path $p } | Should -Not -Throw
    }
}

Describe 'Save-Json / Load-Json' {
    It 'Saves and loads a hashtable round-trip' {
        $data = @{ hello='world'; number=42; nested=@{ a=1; b=@(2,3) } }
        $f    = Join-Path $Script:TestDir 'roundtrip.json'
        Save-Json -Data $data -Path $f
        $loaded = Load-Json -Path $f
        $loaded['hello']   | Should -Be 'world'
        $loaded['number']  | Should -Be 42
    }

    It 'Throws for missing required file' {
        { Load-Json -Path 'C:\nonexistent_file_xyz.json' -Required:$true } | Should -Throw
    }

    It 'Returns empty hashtable for missing non-required file' {
        $r = Load-Json -Path 'C:\nonexistent_file_xyz.json' -Required:$false
        $r.Count | Should -Be 0
    }
}

Describe 'Save-JsonResult' {
    It 'Creates a timestamped file in the right directory' {
        $r = Save-JsonResult -Data @{ ok=$true } -BaseName 'test_result' -OutputDir $Script:TestDir
        Split-Path $r -Leaf | Should -Match '^test_result_\d+\.json$'
        Test-Path $r | Should -Be $true
    }

    It 'Places file under category sub-directory when given' {
        $r = Save-JsonResult -Data @{ ok=$true } -BaseName 'cat_test' -OutputDir $Script:TestDir -Category 'sub'
        $r | Should -Match 'sub\\\\cat_test_\d+\.json$'
    }
}

Describe 'Test-PathEx' {
    It 'Returns $true for an existing file' {
        $f = Join-Path $Script:TestDir 'dummy.txt'
        'dummy' | Set-Content $f
        Test-PathEx -Path $f | Should -Be $true
    }

    It 'Returns $false for a non-existent file' {
        Test-PathEx -Path 'C:\nonexistent_xyz.txt' | Should -Be $false
    }

    It 'Returns $true for an existing directory with PathType=Container' {
        Test-PathEx -Path $Script:TestDir -PathType 'Container' | Should -Be $true
    }
}
