# Tests.Tests.ps1
BeforeAll {
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot    = $PSScriptRoot

    # A temp directory for test artefacts
    $Script:TempDir = Join-Path $env:TEMP "AutomationTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Script:TempDir -Force | Out-Null

    # Minimal config JSONs the tests may need
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

    # Write config files to TempDir
    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    New-Item -ItemType Directory $Script:ConfigDir -Force | Out-Null
    $Script:SampleConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'sample.json')
    $Script:SampleServerList | Set-Content (Join-Path $Script:ConfigDir 'server_list.txt')
    $Script:SampleClusterCatalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json')

    $Script:LogDir  = Join-Path $Script:TempDir 'logs'
    $Script:OutDir  = Join-Path $Script:TempDir 'output'
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
