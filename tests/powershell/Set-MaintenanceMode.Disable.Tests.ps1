# Set-MaintenanceMode.Disable.Tests.ps1
# High-priority disable action tests for Set-MaintenanceMode.ps1

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # Prevent interactive prompts during tests
    $env:AUTOMATED_MODE = 'true'
    
    if (-not $env:TEMP) {
        $env:TEMP = '/tmp' 
    }
    $Script:TempDir = (Join-Path $env:TEMP "MMDisTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\', '/')
    if (-not (Test-Path -Path $Script:TempDir)) {
        New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null 
    }

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null

    Copy-Item (Join-Path $Script:ModuleRoot 'configs/clusters_catalogue.examples-only.json') (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Force
    Copy-Item (Join-Path $Script:ModuleRoot 'configs/connection_hosts.json') (Join-Path $Script:ConfigDir 'connection_hosts.json') -Force
    @{ management_server = 'localhost'; powershell_module = 'OperationsManager'; use_winrm = $false } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ oneview = @{ appliance = 'oneview.example.com'; module_name = 'HPEOneView.860'; use_winrm = $false } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'oneview_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')

    $Script:TestTargetId = 'CLU-CLUSTER-01'
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-MaintenanceMode — Disable action' {
    It 'Should reject with invalid cluster ID' {
        $result = Set-MaintenanceMode -Action disable -TargetId 'UNKNOWN-CLUSTER' -Mode scom -ConfigDir $Script:ConfigDir
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue'
    }

    It 'Should succeed with valid cluster ID in dry-run mode' {
        $result = Set-MaintenanceMode -Action disable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun
        $result.Success | Should -Be $true
    }
}

Describe 'Set-MaintenanceMode — PostDisableWaitSeconds parameter' {
    It 'Should accept default PostDisableWaitSeconds (120s) on disable' {
        $result = Set-MaintenanceMode -Action disable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun
        $result.Success | Should -Be $true
    }

    It 'Should accept custom PostDisableWaitSeconds value' {
        $result = Set-MaintenanceMode -Action disable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -PostDisableWaitSeconds 60
        $result.Success | Should -Be $true
    }

    It 'Should accept PostDisableWaitSeconds=0 to skip wait' {
        $result = Set-MaintenanceMode -Action disable -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun -PostDisableWaitSeconds 0
        $result.Success | Should -Be $true
    }
}
