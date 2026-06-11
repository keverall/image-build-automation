#
# Set-MaintenanceMode.Environment.Tests.ps1 - Tests for environment-based host selection and new parameters
#

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    
    $testConfigDir = Join-Path $PSScriptRoot '../../configs'
    $connectionHostsPath = Join-Path $testConfigDir 'connection_hosts.json'
}

Describe 'Set-MaintenanceMode - Environment Parameter Tests' {
    
    Context 'Environment parameter validation' {
        It 'Should accept Test environment' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'TEST-CLUSTER-01' `
                -Mode scom `
                -Environment Test `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should accept Prod environment' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should reject invalid environment values' {
            { 
                Set-MaintenanceMode `
                    -Action validate `
                    -TargetId 'TEST-CLUSTER-01' `
                    -Mode scom `
                    -Environment 'Invalid' `
                    -DryRun 
            } | Should -Throw
        }
    }
    
    Context 'Environment variable fallback' {
        BeforeEach {
            $originalEnv = $env:ENVIRONMENT
        }
        
        AfterEach {
            $env:ENVIRONMENT = $originalEnv
        }
        
        It 'Should use ENVIRONMENT env var when parameter not specified' {
            $env:ENVIRONMENT = 'Test'
            
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'TEST-CLUSTER-01' `
                -Mode scom `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should default to Prod when no environment specified' {
            $env:ENVIRONMENT = $null
            
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Set-MaintenanceMode - Host Override Tests' {
    
    Context 'ManagementHost parameter' {
        It 'Should accept custom host via parameter for SCOM mode' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -ManagementHost 'custom-server.test.local' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should accept custom host via parameter for OneView mode' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'test-server-01' `
                -Mode oneview `
                -Environment Test `
                -ManagementHost 'custom-oneview.test.local' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should accept host override via MAINTENANCE_HOST environment variable' {
            $originalOverride = $env:MAINTENANCE_HOST
            $env:MAINTENANCE_HOST = 'override-server.test.local'
            
            try {
                $result = Set-MaintenanceMode `
                    -Action validate `
                    -TargetId 'PROD-CLUSTER-01' `
                    -Mode scom `
                    -Environment Prod `
                    -DryRun
                
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:MAINTENANCE_HOST = $originalOverride
            }
        }
    }
}

Describe 'Set-MaintenanceMode - Credential Parameter Tests' {
    
    Context 'Username parameter' {
        BeforeEach {
            $originalUser = $env:SCOM_ADMIN_USER
            $originalPass = $env:SCOM_ADMIN_PASSWORD
            $env:SCOM_ADMIN_USER = 'test_user'
            $env:SCOM_ADMIN_PASSWORD = 'test_pass'
        }
        
        AfterEach {
            $env:SCOM_ADMIN_USER = $originalUser
            $env:SCOM_ADMIN_PASSWORD = $originalPass
        }
        
        It 'Should accept username via parameter' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Username 'param_user' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Set-MaintenanceMode - Date/Time Format Tests' {
    
    Context 'Relative time formats' {
        It 'Should accept +Xhours format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '+2hours' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
        
        It 'Should accept +Xminutes format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '+90minutes' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
        
        It 'Should accept +Xdays format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '+1day' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
        
        It 'Should accept +Xseconds format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '+3600seconds' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
    }
    
    Context 'Absolute time formats' {
        It 'Should accept YYYY-MM-DD HH:MM format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start '2026-06-11 22:00' `
                -End '2026-06-12 02:00' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
        
        It 'Should accept ISO 8601 format' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start '2026-06-11T22:00:00' `
                -End '2026-06-12T02:00:00' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
        
        It 'Should accept mixed relative start and absolute end' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '2026-06-12 02:00' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
    }
}

Describe 'Set-MaintenanceMode - Connection Validation Tests' {
    
    Context 'Connection pre-flight checks' {
        It 'Should validate SCOM connection in dry-run mode' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate OneView connection in dry-run mode' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'test-server-01' `
                -Mode oneview `
                -Environment Test `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Set-MaintenanceMode - Combined Parameter Tests' {
    
    Context 'Multiple new parameters together' {
        It 'Should work with environment, host override, and username' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -ManagementHost 'custom-server.local' `
                -Username 'custom_admin' `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should work with all time and environment parameters' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -Start 'now' `
                -End '+2hours' `
                -PostDisableWaitSeconds 60 `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
    }
}

Describe 'Set-MaintenanceMode - Configuration File Tests' {
    
    Context 'connection_hosts.json structure' {
        It 'Should have valid Test environment configuration' {
            $config = Import-JsonConfig -Path $connectionHostsPath -Required:$false
            $environments = $config.Get_Item('environments')
            
            $environments | Should -Not -BeNullOrEmpty
            $environments.ContainsKey('Test') | Should -BeTrue
            $environments['Test'].ContainsKey('scom') | Should -BeTrue
            $environments['Test'].ContainsKey('oneview') | Should -BeTrue
        }
        
        It 'Should have valid Prod environment configuration' {
            $config = Import-JsonConfig -Path $connectionHostsPath -Required:$false
            $environments = $config.Get_Item('environments')
            
            $environments.ContainsKey('Prod') | Should -BeTrue
            $environments['Prod'].ContainsKey('scom') | Should -BeTrue
            $environments['Prod'].ContainsKey('oneview') | Should -BeTrue
        }
        
        It 'Should have required fields in SCOM config' {
            $config = Import-JsonConfig -Path $connectionHostsPath -Required:$false
            $scomProd = $config.environments.Prod.scom
            
            $scomProd.ContainsKey('management_server') | Should -BeTrue
            $scomProd.management_server | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have required fields in OneView config' {
            $config = Import-JsonConfig -Path $connectionHostsPath -Required:$false
            $oneviewProd = $config.environments.Prod.oneview
            
            $oneviewProd.ContainsKey('appliance') | Should -BeTrue
            $oneviewProd.appliance | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Set-MaintenanceMode - Backward Compatibility Tests' {
    
    Context 'Existing functionality without new parameters' {
        It 'Should work without Environment parameter (backward compatible)' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should work without host override parameters' {
            $result = Set-MaintenanceMode `
                -Action validate `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Environment Prod `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should maintain existing behavior with old parameters' {
            $result = Set-MaintenanceMode `
                -Action enable `
                -TargetId 'PROD-CLUSTER-01' `
                -Mode scom `
                -Start 'now' `
                -End '+1hour' `
                -PostDisableWaitSeconds 120 `
                -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
        }
    }
}

AfterAll {
    Remove-Module Automation -ErrorAction SilentlyContinue
}
