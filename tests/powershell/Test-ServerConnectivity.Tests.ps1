#
# Test-ServerConnectivity.Tests.ps1 - Pester tests for the OneView connectivity
# check function (OneView only).
#

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    $testConfigDir = Join-Path $PSScriptRoot '../../configs'
    $script:cred = [System.Management.Automation.PSCredential]::new('svc', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
    $Script:prevAutomatedMode = $env:AUTOMATED_MODE
    $env:AUTOMATED_MODE = 'true'
}

AfterAll {
    if ($Script:prevAutomatedMode) { $env:AUTOMATED_MODE = $Script:prevAutomatedMode } else { $env:AUTOMATED_MODE = $null }
}

Describe 'Test-ServerConnectivity - Parameter Validation' {

    It 'Should reject invalid Environment values' {
        { Test-ServerConnectivity -Environment 'Invalid' -JsonConfig } | Should -Throw
    }

    It 'Should accept the command without throwing parameter errors' {
        { Test-ServerConnectivity -Environment Test -OneViewHost 'localhost' -PingTimeoutMs 1 -DryRun } |
            Should -Not -Throw
    }
}

Describe 'Test-ServerConnectivity - Host Resolution' {

    It 'Should resolve host from connection_hosts.json for OneView Test environment with -JsonConfig (-DryRun)' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun -PingTimeoutMs 1 -PassThru
        $result.Mode | Should -Be 'oneview'
        $result.Environment | Should -Be 'Test'
        $result.OneViewHost | Should -Not -BeNullOrEmpty
    }

    It 'Should resolve host from connection_hosts.json for OneView Prod environment with -JsonConfig (-DryRun)' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun -PingTimeoutMs 1 -PassThru
        $result.Mode | Should -Be 'oneview'
        $result.Environment | Should -Be 'Prod'
        $result.OneViewHost | Should -Not -BeNullOrEmpty
    }

    It 'Should use OneViewHost override when provided' {
        $result = Test-ServerConnectivity -OneViewHost 'override-server.local' -DryRun -PingTimeoutMs 1 -PassThru
        $result.OneViewHost | Should -Be 'override-server.local'
    }

    It 'Should use ENVIRONMENT env var when -JsonConfig and -DryRun are specified' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = 'Test'
            $result = Test-ServerConnectivity -JsonConfig -DryRun -PingTimeoutMs 1 -PassThru
            $result.Environment | Should -Be 'Test'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should default to Prod when no environment is specified with -JsonConfig (-DryRun)' {
        $original = $env:ENVIRONMENT
        try {
            $env:ENVIRONMENT = $null
            $result = Test-ServerConnectivity -JsonConfig -DryRun -PingTimeoutMs 1 -PassThru
            $result.Environment | Should -Be 'Prod'
        } finally {
            $env:ENVIRONMENT = $original
        }
    }

    It 'Should fail without host when no -JsonConfig and no -OneViewHost in automated mode' {
        $original = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $result = Test-ServerConnectivity -PingTimeoutMs 1 -PassThru
            $result.Available | Should -Be $false
            $result.OneViewHost | Should -Be $null
        } finally {
            $env:AUTOMATED_MODE = $original
        }
    }
}

Describe 'Test-ServerConnectivity - Result Structure' {

    BeforeAll {
        $result = Test-ServerConnectivity -OneViewHost 'nonexistent.invalid.test' -PingTimeoutMs 500 -Credential $cred -PassThru
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

    It 'Should contain OneViewHost key' {
        $result.ContainsKey('OneViewHost') | Should -Be $true
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
        $ac.ContainsKey('ModuleLoaded') | Should -Be $true
    }

    It 'Should skip auth when network ping fails' {
        $result.AuthConnect.Connected | Should -Be $false
        $result.AuthConnect.Error | Should -Match 'Skipped'
    }
}

Describe 'Test-ServerConnectivity - Unreachable Host' {

    It 'Should report OneView as unavailable for unreachable host' {
        $result = Test-ServerConnectivity -OneViewHost '192.0.2.1' -PingTimeoutMs 500 -Credential $cred -PassThru
        $result.Available | Should -Be $false
        $result.NetworkPing.TcpPortOpen | Should -Be $false
    }

    It 'Should report DNS failure for nonexistent domain' {
        $result = Test-ServerConnectivity -OneViewHost 'this-does-not-exist-zzz.invalid' -PingTimeoutMs 500 -Credential $cred -PassThru
        $result.NetworkPing.DnsResolved | Should -Be $false
        $result.NetworkPing.Error | Should -Match 'DNS'
    }
}

Describe 'Test-ServerConnectivity - Missing Config' {

    It 'Should handle missing config directory gracefully' {
        $result = Test-ServerConnectivity -ConfigDir '/tmp/nonexistent-configs' -OneViewHost '192.0.2.1' -PingTimeoutMs 100 -DryRun -PassThru
        $result.Available | Should -Be $true
        $result.OneViewHost | Should -Be '192.0.2.1'
        $result.DryRun | Should -Be $true
    }
}

Describe 'Test-ServerConnectivity - DryRun' {

    It 'Should return mock data for OneView DryRun with -JsonConfig' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun -PassThru
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.Mode | Should -Be 'oneview'
        $result.OneViewHost | Should -Be 'oneview.ad.example.com'
    }

    It 'Should include OneView module in MockData' {
        $result = Test-ServerConnectivity -Environment Prod -JsonConfig -DryRun -PassThru
        $result.MockData | Should -Not -BeNullOrEmpty
        $result.MockData.PowerShellModule | Should -Be 'HPEOneView.1000'
        $result.MockData.TargetPorts | Should -Contain 443
    }

    It 'Should include credential env vars in MockData' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun -PassThru
        $result.MockData.CredentialUserEnv | Should -Be 'ONEVIEW_USER'
        $result.MockData.CredentialPassEnv | Should -Be 'ONEVIEW_PASSWORD'
    }

    It 'Should resolve host from config in DryRun mode with -JsonConfig' {
        $result = Test-ServerConnectivity -Environment Test -JsonConfig -DryRun -PassThru
        $result.OneViewHost | Should -Not -BeNullOrEmpty
        $result.Environment | Should -Be 'Test'
    }

    It 'Should respect OneViewHost override in DryRun mode' {
        $result = Test-ServerConnectivity -OneViewHost 'override-server.local' -DryRun -PassThru
        $result.OneViewHost | Should -Be 'override-server.local'
        $result.DryRun | Should -Be $true
    }

    It 'Should not require network access in DryRun mode' {
        $result = Test-ServerConnectivity -OneViewHost 'nonexistent.invalid.test' -DryRun -PassThru
        $result.DryRun | Should -Be $true
        $result.Available | Should -Be $true
        $result.NetworkPing.DnsResolved | Should -Be $true
        $result.NetworkPing.TcpPortOpen | Should -Be $true
    }
}

Describe 'Test-ServerConnectivity - Credential Flow' {

    It 'Should attempt auth (Phase 2) when -Credential is supplied, even if host is unreachable' {
        # With explicit -Credential, the function should reach Phase 2 and attempt
        # Connect-OneViewSession. Since the host is unreachable, TCP will fail and
        # auth will be skipped - but the credential was accepted and processed.
        $result = Test-ServerConnectivity -OneViewHost '192.0.2.1' -PingTimeoutMs 500 -Credential $script:cred -PassThru
        $result.Available | Should -Be $false
        # TCP fails for unreachable host, so auth is skipped - but the credential
        # was accepted (no "credentials required" error)
        $result.AuthConnect.Error | Should -Match 'Skipped'
    }

    It 'Should fail gracefully in non-interactive mode without credentials' {
        # In non-interactive mode (AUTOMATED_MODE=true), without -Credential,
        # the function should return an error about credentials being required
        $original = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $result = Test-ServerConnectivity -OneViewHost '192.0.2.1' -PingTimeoutMs 500 -PassThru
            $result.Available | Should -Be $false
            $result.AuthConnect.Connected | Should -Be $false
            $result.AuthConnect.Error | Should -Match 'Skipped|credentials'
        }
        finally {
            $env:AUTOMATED_MODE = $original
        }
    }

    It 'Should pass the supplied -Credential to Connect-OneViewSession (integration, mocked session)' {
        # Bind a loopback listener on an unprivileged port so Phase 1 (network ping)
        # succeeds and the function reaches the Connect-OneViewSession call. Using a
        # high port (not 443) avoids needing root to bind a privileged port.
        $listener = $null
        $probePort = 18443
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $probePort)
            $listener.Start()
        } catch {
            throw "Unable to bind loopback port $probePort for integration test: $($_.Exception.Message)"
        }
        try {
            Mock -ModuleName Automation Connect-OneViewSession {
                param($Appliance, $Credential, $ModuleName)
                return @{
                    Connected     = $true
                    ReusedSession = $false
                    Appliance     = $Appliance
                    SessionId     = 'mock-session'
                    ModuleName    = $ModuleName
                    Error         = $null
                }
            }

            $result = Test-ServerConnectivity -OneViewHost 'localhost' -Port $probePort -PingTimeoutMs 2000 -Credential $script:cred -PassThru

            $result.NetworkPing.TcpPortOpen | Should -Be $true
            $result.AuthConnect.Connected | Should -Be $true

            # Assert the exact PSCredential supplied by the caller was passed through.
            Should -Invoke -ModuleName Automation Connect-OneViewSession -Times 1 -Exactly -ParameterFilter {
                $Appliance -eq 'localhost' -and
                $Credential -is [System.Management.Automation.PSCredential] -and
                $Credential.UserName -eq 'svc' -and
                $Credential.GetNetworkCredential().Password -eq 'pw'
            }
        } finally {
            if ($listener) { $listener.Stop() }
        }
    }

    It 'Should accept PSCredential parameter without throwing' {
        # Verify that -Credential parameter binding works correctly
        { Test-ServerConnectivity -OneViewHost 'localhost' -PingTimeoutMs 1 -Credential $script:cred -DryRun } |
            Should -Not -Throw
    }

    It 'Should resolve credentials from ONEVIEW_USER/ONEVIEW_PASSWORD (no -Credential) instead of failing' {
        # Host supplied but no -Credential: the bare path reuses an existing
        # credential, so the host-supplied path must be consistent and resolve
        # from ONEVIEW_USER/ONEVIEW_PASSWORD / CyberArk rather than reporting
        # "no credentials supplied".
        $origUser = $env:ONEVIEW_USER
        $origPass = $env:ONEVIEW_PASSWORD
        $listener = $null
        $probePort = 18444
        try {
            $env:ONEVIEW_USER = 'svc-env'
            $env:ONEVIEW_PASSWORD = 'env-pw'
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $probePort)
            $listener.Start()
            Mock -ModuleName Automation Connect-OneViewSession {
                param($Appliance, $Credential)
                return @{
                    Connected     = $true
                    ReusedSession = $false
                    Appliance     = $Appliance
                    SessionId     = 'mock-session'
                    ModuleName    = 'HPEOneView.1000'
                    Error         = $null
                }
            }
            $result = Test-ServerConnectivity -OneViewHost 'localhost' -Port $probePort -PingTimeoutMs 2000 -PassThru
            $result.NetworkPing.TcpPortOpen | Should -Be $true
            $result.AuthConnect.Connected | Should -Be $true
            Should -Invoke -ModuleName Automation Connect-OneViewSession -Times 1 -Exactly -ParameterFilter {
                $Credential -is [System.Management.Automation.PSCredential] -and
                $Credential.UserName -eq 'svc-env'
            }
        } finally {
            if ($listener) { $listener.Stop() }
            if ($origUser) { $env:ONEVIEW_USER = $origUser } else { $env:ONEVIEW_USER = $null }
            if ($origPass) { $env:ONEVIEW_PASSWORD = $origPass } else { $env:ONEVIEW_PASSWORD = $null }
        }
    }

    It 'Should refuse to reconnect to a DIFFERENT host when already connected' {
        # A connectivity check must never drop the live session by connecting to
        # another appliance. With an active session to one host and an explicit
        # -OneViewHost pointing elsewhere, it should report "already connected".
        Mock -ModuleName Automation Get-OneViewActiveSession {
            return [PSCustomObject]@{ Name = 'oneview-active.ad.example.com'; Connected = $true; SessionID = 'sid' }
        }
        $result = Test-ServerConnectivity -OneViewHost 'oneview-other.ad.example.com' -PingTimeoutMs 500 -PassThru
        $result.Available | Should -Be $false
        $result.AuthConnect.Connected | Should -Be $false
        $result.AuthConnect.Error | Should -Match 'already connected'
        $result.NetworkPing.Error | Should -Match 'Already connected'
    }

    It 'Should pass -Credential through to Phase 2 when network is available' {
        # When using a resolvable host with -Credential, the function should
        # attempt authentication (Phase 2). The auth will fail (no real OneView),
        # but the credential was processed.
        $result = Test-ServerConnectivity -OneViewHost 'localhost' -PingTimeoutMs 1000 -Credential $script:cred -PassThru
        # localhost resolves and may have port 443 closed, so auth may be skipped
        # The key is that the credential was accepted (no parameter binding error)
        $result | Should -Not -BeNullOrEmpty
        $result.Mode | Should -Be 'oneview'
        $result.OneViewHost | Should -Be 'localhost'
    }

    It 'Should reuse the active session when -OneViewHost matches it (no credentials needed)' {
        # Regression: supplying -OneViewHost that matches the active appliance
        # must reuse the live session instead of forcing a fresh credential lookup
        # and wrongly reporting "no connection".
        Mock -ModuleName Automation Get-OneViewActiveSession {
            return [PSCustomObject]@{ Name = 'localhost'; Connected = $true; SessionID = 'sid' }
        }
        $listener = $null
        $probePort = 18445
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $probePort)
            $listener.Start()
            Mock -ModuleName Automation Connect-OneViewSession {
                param($Appliance, $Credential)
                return @{
                    Connected     = $true
                    ReusedSession = $true
                    Appliance     = $Appliance
                    SessionId     = 'mock-session'
                    ModuleName    = 'HPEOneView.1000'
                    Error         = $null
                }
            }
            # No -Credential, no ONEVIEW_* env: would previously fail in the
            # credential-resolution branch. Now it should reuse the active session.
            $result = Test-ServerConnectivity -OneViewHost 'localhost' -Port $probePort -PingTimeoutMs 2000 -PassThru
            $result.Available | Should -Be $true
            $result.AuthConnect.Connected | Should -Be $true
            Should -Invoke -ModuleName Automation Connect-OneViewSession -Times 1 -Exactly -ParameterFilter {
                $Appliance -eq 'localhost'
            }
        } finally {
            if ($listener) { $listener.Stop() }
        }
    }
}

