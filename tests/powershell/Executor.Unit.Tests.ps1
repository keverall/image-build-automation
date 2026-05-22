# Executor.Tests.ps1 — Tests for Executor.psm1 (CommandResult, Invoke-Command, New-CommandResult, Invoke-CommandWithRetry)

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    $Script:TestRoot        = $PSScriptRoot

    # TempDir — guard against $env:TEMP being null on non-Windows / Pester workers
    if (-not $env:TEMP)  { $env:TEMP  = '/tmp' }
    if (-not $env:TMP)   { $env:TMP   = '/tmp' }
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

Describe 'New-CommandResult' {
    BeforeAll {
        InModuleScope 'Automation' {
            [CommandResult].GetProperties() | Out-Null
        }
    }
    
    It 'Creates a CommandResult with Success=$true for RC=0' {
        InModuleScope 'Automation' {
            $r = New-CommandResult -ReturnCode 0 -StandardOutput 'ok' -StandardError ''
            $r.Success | Should -Be $true
            $r.ReturnCode  | Should -Be 0
            $r.StandardOutput | Should -Be 'ok'
            $r.Output()   | Should -Be 'ok'
        }
    }

    It 'Creates a CommandResult with Success=$false for RC>0' {
        InModuleScope 'Automation' {
            $r = New-CommandResult -ReturnCode 1 -StandardOutput '' -StandardError 'error'
            $r.Success     | Should -Be $false
            $r.ReturnCode  | Should -Be 1
            $r.Output() | Should -Be 'error'
        }
    }
}

Describe 'CommandResult class' {
    It 'Has Output() method that returns stderr when rc>0' {
        InModuleScope 'Automation' {
            $r = [CommandResult]::new(1, '', 'my_error')
            $r.Output() | Should -Be 'my_error'
        }
    }

    It 'Has Output() method that returns stdout when rc=0' {
        InModuleScope 'Automation' {
            $r = [CommandResult]::new(0, 'my_output', '')
            $r.Output() | Should -Be 'my_output'
        }
    }
}
