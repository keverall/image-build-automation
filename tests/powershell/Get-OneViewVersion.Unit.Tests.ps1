# Get-OneViewVersion.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewVersion and the HPEOneView.1000-only
# module-compliance guard. No live appliance or HPEOneView module required.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Get-OneViewVersion - basic invocation' {
    It 'Function is exported' {
        Get-Command Get-OneViewVersion -ErrorAction SilentlyContinue | Should -Not -Be $null
    }

    It 'Reports required module and local module state without an appliance' {
        $global:ConnectedSessions = $null
        $r = Get-OneViewVersion -Quiet
        $r.RequiredModule | Should -Be 'HPEOneView.1000'
        $r.Appliance      | Should -Be $null
        $r.ContainsKey('LoadedModules')    | Should -Be $true
        $r.ContainsKey('InstalledModules') | Should -Be $true
    }

    It 'Probes the appliance version when -OneViewHost is supplied' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                @{ currentVersion = 8200 }
            }
        }
        $r = Get-OneViewVersion -OneViewHost 'va-oneviewt-01' -Quiet
        $r.Appliance          | Should -Be 'va-oneviewt-01'
        $r.ApplianceReachable | Should -Be $true
        $r.ApplianceVersion   | Should -Be 8200
    }

    It 'Reports unreachable appliance without throwing' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                throw 'No such host is known.'
            }
        }
        $r = Get-OneViewVersion -OneViewHost 'HPEOpenview.1000' -Quiet
        $r.ApplianceReachable | Should -Be $false
        $r.Error              | Should -Match 'version probe failed'
    }

    It 'Uses the active session appliance when -OneViewHost is omitted' {
        try {
            InModuleScope Automation {
                Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                    @{ currentVersion = '10.00' }
                }
            }
            $global:ConnectedSessions = @(
                [pscustomobject]@{ Name = 'ov-session.local'; SessionID = 'token-abc'; Connected = $true }
            )
            $r = Get-OneViewVersion -Quiet
            $r.Appliance        | Should -Be 'ov-session.local'
            $r.ApplianceVersion | Should -Be '10.00'
        } finally {
            $global:ConnectedSessions = $null
        }
    }
}

Describe 'Assert-OneViewModuleCompliance - HPEOneView.1000-only policy' {
    It 'Rejects a non-1000 ModuleName' {
        InModuleScope Automation {
            $r = Assert-OneViewModuleCompliance -ModuleName 'HPEOneView.860'
            $r.Ok    | Should -Be $false
            $r.Error | Should -Match 'HPEOneView.1000'
        }
    }

    It 'Accepts HPEOneView.1000 when no other OneView module is loaded' {
        InModuleScope Automation {
            Mock Get-OneViewModuleStatus {
                @{ RequiredModule = 'HPEOneView.1000'; LoadedModules = @(); InstalledModules = @()
                   Compliant = $true; NonCompliantLoaded = @(); NonCompliantInstalled = @() }
            }
            (Assert-OneViewModuleCompliance -ModuleName 'HPEOneView.1000').Ok | Should -Be $true
        }
    }

    It 'Fails when a stray HPEOneView module is already loaded' {
        InModuleScope Automation {
            Mock Get-OneViewModuleStatus {
                @{ RequiredModule = 'HPEOneView.1000'; LoadedModules = @(@{ Name = 'HPEOneView.860'; Version = '8.60'; Path = 'x' })
                   InstalledModules = @(); Compliant = $false
                   NonCompliantLoaded = @('HPEOneView.860'); NonCompliantInstalled = @() }
            }
            $r = Assert-OneViewModuleCompliance -ModuleName 'HPEOneView.1000'
            $r.Ok    | Should -Be $false
            $r.Error | Should -Match 'HPEOneView.860'
            $r.Error | Should -Match 'Remove-Module'
        }
    }

    It 'Warns (but passes) when a stray version is merely installed' {
        InModuleScope Automation {
            Mock Get-OneViewModuleStatus {
                @{ RequiredModule = 'HPEOneView.1000'; LoadedModules = @(); InstalledModules = @()
                   Compliant = $true; NonCompliantLoaded = @(); NonCompliantInstalled = @('HPEOneView.860') }
            }
            $warnings = @()
            $r = Assert-OneViewModuleCompliance -ModuleName 'HPEOneView.1000' -WarningVariable warnings -WarningAction SilentlyContinue
            $r.Ok | Should -Be $true
            "$warnings" | Should -Match 'HPEOneView.860'
        }
    }
}

Describe 'Connect-OneViewSession - module guard integration' {
    It 'Refuses to connect with a non-1000 module name' {
        InModuleScope Automation {
            $cred = [System.Management.Automation.PSCredential]::new(
                'u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
            $r = Connect-OneViewSession -Appliance 'ov.test' -Credential $cred -ModuleName 'HPEOneView.860'
            $r.Connected | Should -Be $false
            $r.Error     | Should -Match "HPEOneView.1000"
        }
    }
}
