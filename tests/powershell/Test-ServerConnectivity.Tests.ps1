#
# Test-ServerConnectivity.Tests.ps1 — Pester tests for the connectivity check function
#

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    $testConfigDir = Join-Path $PSScriptRoot '../../configs'
}

Describe 'Test-ServerConnectivity - Parameter Validation' {

    It 'Should reject invalid Mode values' {
        { Test-ServerConnectivity -Mode 'invalid' } | Should -Throw
    }

    It 'Should reject invalid Environment values' {
        { Test-ServerConnectivity -Mode scom -Environment 'Invalid' -JsonConfig } | Should -Throw
    }

    It 'Should accept scom mode without throwing parameter errors' {
        { Test-ServerConnectivity -Mode scom -Environment Test -ManagementHost 'localhost' -PingTimeoutMs 1 } |
            Should -Not -Throw
    }

    It 'Should accept oneview mode without throwing parameter errors' {
        { Test-ServerConnectivity -Mode oneview -Environment Test -ManagementHost 'localhost' -PingTimeoutMs 1 } |
            Should -Not -Throw
    }
}

Describe 'Test-ServerConnectivity - Host Resolution' {

    It 'Should resolve host from connection_hosts.json for scom Test environment with -JsonConfig' {
        $result = Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig -PingTimeoutMs 1
        $result.Mode | Should -Be 'scom'
        $result.Environment | Should -Be 'Test'
        $result.ManagementHost | Should -Not -BeNullOrEmpty
    }

    It 'Should resolve host from connection_hosts.json for oneview Prod environment with -JsonConfig' {
        $result = Test-ServerConnectivity -Mode oneview -Environment Prod -JsonConfig -PingTimeoutMs 1
        $result.Mode | Should -Be 'oneview'
        $result.Environment | Should -Be 'Prod'
        $result.ManagementHost | Should -Not -BeNullOrEmpty
    }

    It 'Should use ManagementHost override when provided' {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost 'override-server.local' -PingTimeoutMs 1
        $result.ManagementHost | Should -Be 'override-server.local'
    }

    It 'Should use ENVIRONMENT env var when -JsonConfig and parameter specified' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = 'Test'
            $result = Test-ServerConnectivity -Mode scom -JsonConfig -PingTimeoutMs 1
            $result.Environment | Should -Be 'Test'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should default to Prod when no environment is specified with -JsonConfig' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = $null
            $result = Test-ServerConnectivity -Mode scom -JsonConfig -PingTimeoutMs 1
            $result.Environment | Should -Be 'Prod'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should fail without host when no -JsonConfig and no -ManagementHost in automated mode' {
        $original = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $result = Test-ServerConnectivity -Mode scom -PingTimeoutMs 1
            $result.Available | Should -Be $false
            $result.ManagementHost | Should -Be $null
        } finally {
            $env:AUTOMATED_MODE = $original
        }
    }
}

Describe 'Test-ServerConnectivity - Result Structure' {

    BeforeAll {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost 'nonexistent.invalid.test' -PingTimeoutMs 500
    }

    It 'Should return a hashtable' {
        $result | Should -BeOfType [hashtable]
    }

    It 'Should contain Available key' {
        $result.ContainsKey('Available') | Should -Be $true
    }

    It 'Should contain Mode key' {
        $result.ContainsKey('Mode') | Should -Be $true
        $result.Mode | Should -Be 'scom'
    }

    It 'Should contain ManagementHost key' {
        $result.ContainsKey('ManagementHost') | Should -Be $true
    }

    It 'Should contain Environment key' {
        $result.ContainsKey('Environment') | Should -Be $true
    }

    It 'Should contain NetworkPing key' {
        $result.ContainsKey('NetworkPing') | Should -Be $true
    }

    It 'Should contain AuthConnect key' {
        $result.ContainsKey('AuthConnect') | Should -Be $true
    }

    It 'Should contain Timestamp key' {
        $result.ContainsKey('Timestamp') | Should -Be $true
        $result.Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'Should report host as unavailable for nonexistent hostname' {
        $result.Available | Should -Be $false
    }

    It 'Should have NetworkPing sub-structure with expected keys' {
        $np = $result.NetworkPing
        $np.ContainsKey('DnsResolved') | Should -Be $true
        $np.ContainsKey('TcpPortOpen') | Should -Be $true
        $np.ContainsKey('LatencyMs') | Should -Be $true
    }

    It 'Should fail DNS for nonexistent hostname' {
        $result.NetworkPing.DnsResolved | Should -Be $false
    }

    It 'Should have AuthConnect sub-structure with expected keys' {
        $ac = $result.AuthConnect
        $ac.ContainsKey('Connected') | Should -Be $true
        $ac.ContainsKey('Disconnected') | Should -Be $true
        $ac.ContainsKey('ModuleLoaded') | Should -Be $true
    }

    It 'Should skip auth when network ping fails' {
        $result.AuthConnect.Connected | Should -Be $false
        $result.AuthConnect.Error | Should -Match 'Skipped'
    }
}

Describe 'Test-ServerConnectivity - Unreachable Host' {

    It 'Should report scom as unavailable for unreachable host' {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost '192.0.2.1' -PingTimeoutMs 500
        $result.Available | Should -Be $false
        $result.NetworkPing.TcpPortOpen | Should -Be $false
    }

    It 'Should report oneview as unavailable for unreachable host' {
        $result = Test-ServerConnectivity -Mode oneview -ManagementHost '192.0.2.1' -PingTimeoutMs 500
        $result.Available | Should -Be $false
        $result.NetworkPing.TcpPortOpen | Should -Be $false
    }

    It 'Should report DNS failure for nonexistent domain' {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost 'this-does-not-exist-zzz.invalid' -PingTimeoutMs 500
        $result.NetworkPing.DnsResolved | Should -Be $false
        $result.NetworkPing.Error | Should -Match 'DNS'
    }
}

Describe 'Test-ServerConnectivity - Missing Config' {

    It 'Should handle missing config directory gracefully' {
        $result = Test-ServerConnectivity -Mode scom -ConfigDir '/tmp/nonexistent-configs' -ManagementHost '192.0.2.1' -PingTimeoutMs 100
        $result.Available | Should -Be $false
        $result.ManagementHost | Should -Be '192.0.2.1'
    }
}

Describe 'Test-ServerConnectivity - DryRun' {

    It 'Should return mock data for SCOM DryRun with -JsonConfig' {
        $result = Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig -DryRun
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.Mode | Should -Be 'scom'
        $result.ManagementHost | Should -Be 'VR-OPM19T1-7382.ad.example.com'
    }

    It 'Should return mock data for OneView DryRun with -JsonConfig' {
        $result = Test-ServerConnectivity -Mode oneview -Environment Prod -JsonConfig -DryRun
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.Mode | Should -Be 'oneview'
        $result.ManagementHost | Should -Be 'oneview.ad.example.com'
    }

    It 'Should include MockData with DryRun configuration' {
        $result = Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig -DryRun
        $result.MockData | Should -Not -BeNullOrEmpty
        $result.MockData.PowerShellModule | Should -Be 'OperationsManager'
        $result.MockData.WinRM | Should -Be $true
        $result.MockData.TargetPorts | Should -Contain 5985
        $result.MockData.Note | Should -Match 'Mock data'
    }

    It 'Should include OneView module in MockData' {
        $result = Test-ServerConnectivity -Mode oneview -Environment Prod -JsonConfig -DryRun
        $result.MockData.PowerShellModule | Should -Be 'HPEOneView.860'
        $result.MockData.TargetPorts | Should -Contain 443
    }

    It 'Should include credential env vars in MockData' {
        $result = Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig -DryRun
        $result.MockData.CredentialUserEnv | Should -Be 'SCOM_ADMIN_USER'
        $result.MockData.CredentialPassEnv | Should -Be 'SCOM_ADMIN_PASSWORD'
    }

    It 'Should resolve host from config in DryRun mode with -JsonConfig' {
        $result = Test-ServerConnectivity -Mode scom -Environment Test -JsonConfig -DryRun
        $result.ManagementHost | Should -Not -BeNullOrEmpty
        $result.Environment | Should -Be 'Test'
    }

    It 'Should respect ManagementHost override in DryRun mode' {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost 'override-server.local' -DryRun
        $result.ManagementHost | Should -Be 'override-server.local'
        $result.DryRun | Should -Be $true
    }

    It 'Should not require network access in DryRun mode' {
        $result = Test-ServerConnectivity -Mode scom -ManagementHost 'nonexistent.invalid.test' -DryRun
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.NetworkPing.DnsResolved | Should -Be $true
        $result.NetworkPing.TcpPortOpen | Should -Be $true
    }
}
