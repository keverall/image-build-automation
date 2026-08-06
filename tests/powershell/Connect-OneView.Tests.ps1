#
# Connect-OneView.Tests.ps1 - Pester tests for the Connect-OneView wrapper.
#

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psm1'
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    $script:cred = [System.Management.Automation.PSCredential]::new('svc', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
    $Script:prevAutomatedMode = $env:AUTOMATED_MODE
    $env:AUTOMATED_MODE = 'true'
}

AfterAll {
    if ($Script:prevAutomatedMode) { $env:AUTOMATED_MODE = $Script:prevAutomatedMode } else { $env:AUTOMATED_MODE = $null }
}

Describe 'Connect-OneView - Parameter Validation' {

    It 'Should accept a DryRun with host and not throw' {
        { Connect-OneView -ManagementHost 'localhost' -DryRun } | Should -Not -Throw
    }

    It 'Should accept a DryRun without host (config-based, no live connection)' {
        # DryRun resolves host from connection_hosts.json config, so no
        # -ManagementHost is required and no interactive prompt fires.
        { Connect-OneView -DryRun } | Should -Not -Throw
    }
}

Describe 'Connect-OneView - Delegation to Test-ServerConnectivity' {

    It 'Should return Available = false for an unreachable host (no credential supplied in automated mode)' {
        $result = Connect-OneView -ManagementHost '192.0.2.1'
        $result.Available | Should -Be $false
        $result.Message   | Should -Match 'failed'
    }

    It 'Should set a success Message when connection succeeds' {
        # Mock Test-ServerConnectivity to simulate a successful connection.
        Mock -ModuleName Automation Test-ServerConnectivity {
            param($ManagementHost, $DryRun)
            return @{
                Available       = $true
                Mode            = 'oneview'
                ManagementHost  = $ManagementHost
                Environment     = 'Prod'
                NetworkPing     = @{ DnsResolved = $true; TcpPortOpen = $true; LatencyMs = 1 }
                AuthConnect     = @{ Connected = $true; ModuleLoaded = $true; Error = $null }
                Timestamp       = '2026-01-01T00:00:00Z'
            }
        }

        $result = Connect-OneView -ManagementHost 'localhost'
        $result.Available | Should -Be $true
        $result.Message    | Should -Match 'Connected to'

        Should -Invoke -ModuleName Automation Test-ServerConnectivity -Times 1 -Exactly -ParameterFilter {
            $ManagementHost -eq 'localhost'
        }
    }
}
