#
# Test-ServerConnectivity.Tests.ps1 - Pester tests for the OneView connectivity
# check function (OneView only).
#

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    $testConfigDir = Join-Path $PSScriptRoot '../../configs'
    $script:cred = [System.Management.Automation.PSCredential]::new('svc', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
}

Describe 'Test-ServerConnectivity - Parameter Validation' {

    It 'Should reject invalid Environment values' {
        { Test-ServerConnectivity -Environment 'Invalid' -JsonConfig } | Should -Throw
    }

    It 'Should accept the command without throwing parameter errors' {
        { Test-ServerConnectivity -Environment Test -ManagementHost 'localhost' -PingTimeoutMs 1 -DryRun } |
            Should -Not -Throw
    }
}

Describe 'Test-ServerConnectivity - Host Resolution' {

    It 'Should resolve host from connection_hosts.json for OneView Test environment with -JsonConfig (-DryRun)' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun -PingTimeoutMs 1
        $result.Mode | Should -Be 'oneview'
        $result.Environment | Should -Be 'Test'
        $result.ManagementHost | Should -Not -BeNullOrEmpty
    }

    It 'Should resolve host from connection_hosts.json for OneView Prod environment with -JsonConfig (-DryRun)' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun -PingTimeoutMs 1
        $result.Mode | Should -Be 'oneview'
        $result.Environment | Should -Be 'Prod'
        $result.ManagementHost | Should -Not -BeNullOrEmpty
    }

    It 'Should use ManagementHost override when provided' {
        $result = Test-ServerConnectivity -ManagementHost 'override-server.local' -DryRun -PingTimeoutMs 1
        $result.ManagementHost | Should -Be 'override-server.local'
    }

    It 'Should use ENVIRONMENT env var when -JsonConfig and -DryRun are specified' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = 'Test'
            $result = Test-ServerConnectivity -JsonConfig -DryRun -PingTimeoutMs 1
            $result.Environment | Should -Be 'Test'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should default to Prod when no environment is specified with -JsonConfig (-DryRun)' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = $null
            $result = Test-ServerConnectivity -JsonConfig -DryRun -PingTimeoutMs 1
            $result.Environment | Should -Be 'Prod'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should fail without host when no -JsonConfig and no -ManagementHost in automated mode' {
        $original = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $result = Test-ServerConnectivity -PingTimeoutMs 1
            $result.Available | Should -Be $false
            $result.ManagementHost | Should -Be $null
        } finally {
            $env:AUTOMATED_MODE = $original
        }
    }
}

Describe 'Test-ServerConnectivity - Result Structure' {

    BeforeAll {
        $result = Test-ServerConnectivity -ManagementHost 'nonexistent.invalid.test' -PingTimeoutMs 500 -Credential $cred
    }

    It 'Should return a hashtable' {
        $result | Should -BeOfType [hashtable]
    }

    It 'Should contain Available key' {
        $result.ContainsKey('Available') | Should -Be $true
    }

    It 'Should contain Mode key (always oneview)' {
        $result.ContainsKey('Mode') | Should -Be $true
        $result.Mode | Should -Be 'oneview'
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

    It 'Should report OneView as unavailable for unreachable host' {
        $result = Test-ServerConnectivity -ManagementHost '192.0.2.1' -PingTimeoutMs 500 -Credential $cred
        $result.Available | Should -Be $false
        $result.NetworkPing.TcpPortOpen | Should -Be $false
    }

    It 'Should report DNS failure for nonexistent domain' {
        $result = Test-ServerConnectivity -ManagementHost 'this-does-not-exist-zzz.invalid' -PingTimeoutMs 500 -Credential $cred
        $result.NetworkPing.DnsResolved | Should -Be $false
        $result.NetworkPing.Error | Should -Match 'DNS'
    }
}

Describe 'Test-ServerConnectivity - Missing Config' {

    It 'Should handle missing config directory gracefully' {
        $result = Test-ServerConnectivity -ConfigDir '/tmp/nonexistent-configs' -ManagementHost '192.0.2.1' -PingTimeoutMs 100 -DryRun
        $result.Available | Should -Be $true
        $result.ManagementHost | Should -Be '192.0.2.1'
        $result.DryRun | Should -Be $true
    }
}

Describe 'Test-ServerConnectivity - DryRun' {

    It 'Should return mock data for OneView DryRun with -JsonConfig' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.Mode | Should -Be 'oneview'
        $result.ManagementHost | Should -Be 'oneview.ad.example.com'
    }

    It 'Should include OneView module in MockData' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun
        $result.MockData | Should -Not -BeNullOrEmpty
        $result.MockData.PowerShellModule | Should -Be 'HPEOneView.1000'
        $result.MockData.TargetPorts | Should -Contain 443
    }

    It 'Should include credential env vars in MockData' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun
        $result.MockData.CredentialUserEnv | Should -Be 'ONEVIEW_USER'
        $result.MockData.CredentialPassEnv | Should -Be 'ONEVIEW_PASSWORD'
    }

    It 'Should resolve host from config in DryRun mode with -JsonConfig' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun
        $result.ManagementHost | Should -Not -BeNullOrEmpty
        $result.Environment | Should -Be 'Test'
    }

    It 'Should respect ManagementHost override in DryRun mode' {
        $result = Test-ServerConnectivity -ManagementHost 'override-server.local' -DryRun
        $result.ManagementHost | Should -Be 'override-server.local'
        $result.DryRun | Should -Be $true
    }

    It 'Should not require network access in DryRun mode' {
        $result = Test-ServerConnectivity -ManagementHost 'nonexistent.invalid.test' -DryRun
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.NetworkPing.DnsResolved | Should -Be $true
        $result.NetworkPing.TcpPortOpen | Should -Be $true
    }
}
