# Set-MaintenanceMode.Validation.Tests.ps1
# High-priority validation tests for Set-MaintenanceMode.ps1

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # Prevent interactive prompts during tests
    $env:AUTOMATED_MODE = 'true'

    if (-not $env:TEMP) {
        $env:TEMP = '/tmp' 
    }
    $Script:TempDir = (Join-Path $env:TEMP "MMValTests_$([guid]::NewGuid().ToString('N'))").TrimEnd('\', '/')
    if (-not (Test-Path -Path $Script:TempDir)) {
        New-Item -ItemType Directory $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null 
    }

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null

    Copy-Item (Join-Path $Script:ModuleRoot 'configs/clusters_catalogue.examples-only.json') (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -Force
    Copy-Item (Join-Path $Script:ModuleRoot 'configs/connection_hosts.json') (Join-Path $Script:ConfigDir 'connection_hosts.json') -Force
    @{ management_server = 'localhost'; powershell_module = 'OperationsManager'; use_winrm = $false } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'scom_config.json')
    @{ oneview = @{ appliance = 'oneview.example.com'; module_name = 'HPEOneView.1000'; use_winrm = $false } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'oneview_config.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'email_distribution_lists.json')
    @{ } | ConvertTo-Json | Set-Content (Join-Path $Script:ConfigDir 'opsramp_config.json')

    $Script:TestTargetId = 'CLU-CLUSTER-01'
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-MaintenanceMode - Target ID validation' {
    It 'Should return success for valid target ID' {
        $result = Set-MaintenanceMode -Action validate -TargetId $Script:TestTargetId -Mode scom -ConfigDir $Script:ConfigDir -DryRun
        $result.Success | Should -Be $true
    }

    It 'Should reject unknown target ID' {
        $result = Set-MaintenanceMode -Action validate -TargetId 'NONEXISTENT-CLUSTER' -Mode scom -ConfigDir $Script:ConfigDir -DryRun
        $result.Success | Should -Be $false
        $result.Error | Should -Match 'not found in catalogue|does not exist'
    }

    It 'Should reject empty target ID string' {
        { Set-MaintenanceMode -Action validate -TargetId '' -Mode scom -ConfigDir $Script:ConfigDir } | Should -Throw
    }
}

Describe 'Set-MaintenanceMode - Pre-check for mode change validation' {
    Context 'DryRun mode (simulation)' {
        It 'Should allow enable action in DryRun mode regardless of current state' {
            $params = @{
                Action    = 'enable'
                TargetId  = $Script:TestTargetId
                Mode      = 'scom'
                ConfigDir = $Script:ConfigDir
                DryRun    = $true
                Start     = 'now'
                End       = '+1hour'
            }
            $result = Set-MaintenanceMode @params
            $result.Success | Should -Be $true
        }

        It 'Should allow disable action in DryRun mode regardless of current state' {
            $params = @{
                Action    = 'disable'
                TargetId  = $Script:TestTargetId
                Mode      = 'scom'
                ConfigDir = $Script:ConfigDir
                DryRun    = $true
            }
            $result = Set-MaintenanceMode @params
            $result.Success | Should -Be $true
        }
    }

    Context 'MockMaintenanceState simulates pre-existing state' {
        It 'Should show partially enabled state in validate action with MockMaintenanceState=partial' {
            $params = @{
                Action               = 'validate'
                TargetId             = $Script:TestTargetId
                Mode                 = 'scom'
                ConfigDir            = $Script:ConfigDir
                DryRun               = $true
                MockMaintenanceState = 'partial'
            }
            $result = Set-MaintenanceMode @params
            $result.Success | Should -Be $true
            $result.StatusText | Should -Match 'partially'
        }

        It 'Should show fully enabled state in validate action with MockMaintenanceState=enable' {
            $params = @{
                Action               = 'validate'
                TargetId             = $Script:TestTargetId
                Mode                 = 'scom'
                ConfigDir            = $Script:ConfigDir
                DryRun               = $true
                MockMaintenanceState = 'enable'
            }
            $result = Set-MaintenanceMode @params
            $result.Success | Should -Be $true
            $result.StatusText | Should -Match 'enabled'
        }

        It 'Should show disabled state in validate action with MockMaintenanceState=disable' {
            $params = @{
                Action               = 'validate'
                TargetId             = $Script:TestTargetId
                Mode                 = 'scom'
                ConfigDir            = $Script:ConfigDir
                DryRun               = $true
                MockMaintenanceState = 'disable'
            }
            $result = Set-MaintenanceMode @params
            $result.Success | Should -Be $true
            $result.StatusText | Should -Match 'disabled'
        }
    }
}
