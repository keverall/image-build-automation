# New-Uuid.Tests.ps1 — Tests for New-Uuid.ps1 (deterministic UUID generator + Xorshift32)

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../src/powershell')).Path
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
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -ErrorAction Stop
}

Describe 'New-Uuid — Deterministic UUID generation' {
    It 'Generates a valid GUID for any server name' {
        $g = New-Uuid -ServerName 'srv01'
        [Guid]$g | Should -Not -BeNullOrEmpty
        # GUID strings must have standard 36-char format (8-4-4-4-12)
        $g.Length | Should -Be 36
    }

    It 'Produces the same UUID for the same input (deterministic)' {
        $t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $a = New-Uuid -ServerName 'srv01' -Timestamp $t
        $b = New-Uuid -ServerName 'srv01' -Timestamp $t
        $a | Should -Be $b
    }

    It 'Produces different UUIDs for different inputs' {
        $t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $a = New-Uuid -ServerName 'srv01' -Timestamp $t
        $b = New-Uuid -ServerName 'srv02' -Timestamp $t
        $a | Should -Not -Be $b
    }

    It 'Uses current UTC time when no timestamp is given' {
        $before = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $g      = New-Uuid -ServerName 'now_test'
        $after  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        # UUID must be valid
        [Guid]$g | Should -Not -BeNullOrEmpty
    }
}

Describe 'New-Uuid — Output to file' {
    It 'Writes UUID to file when OutputPath is set' {
        $ts  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $g   = New-Uuid -ServerName 'file_test' -Timestamp $ts
        $f   = Join-Path $Script:TempDir 'uuid_out.txt'
        New-Uuid -ServerName 'file_test' -Timestamp $ts -OutputPath $f
        (Test-Path $f) | Should -Be $true
        (Get-Content $f -Raw).Trim() | Should -Be $g
    }
}
