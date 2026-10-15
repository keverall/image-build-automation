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
        $r = Get-OneViewVersion -PassThru -Quiet
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
        $r = Get-OneViewVersion -OneViewHost 'oneview.example.com' -PassThru -Quiet
        $r.Appliance          | Should -Be 'oneview.example.com'
        $r.ApplianceReachable | Should -Be $true
        $r.ApplianceVersion   | Should -Be 8200
    }

    It 'Reports unreachable appliance without throwing' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                throw 'No such host is known.'
            }
        }
        $r = Get-OneViewVersion -OneViewHost 'HPEOpenview.1000' -PassThru -Quiet
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
            $r = Get-OneViewVersion -PassThru -Quiet
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

Describe 'Resolve-OneViewModuleLoadAction - single HPE library per console' {
    It 'Reuses an already-loaded module that matches the pinned name and version' {
        InModuleScope Automation {
            $loaded = @([pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221' })
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion '10.0.4265.2221' -LoadedModules $loaded
            $d.Action | Should -Be 'Reuse'
            $d.Module.Version | Should -Be '10.0.4265.2221'
        }
    }

    It 'Reuses when the installed version cannot be determined' {
        InModuleScope Automation {
            $loaded = @([pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221' })
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion $null -LoadedModules $loaded
            $d.Action | Should -Be 'Reuse'
        }
    }

    It 'Refuses when a different version of the pinned library is already loaded' {
        InModuleScope Automation {
            $loaded = @([pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.0.0' })
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion '10.0.4265.2221' -LoadedModules $loaded
            $d.Action   | Should -Be 'Error'
            $d.Error    | Should -Match 'already loaded in this console'
            $d.Error    | Should -Match 'Remove-Module'
        }
    }

    It 'Refuses when a different HPE OneView library is already loaded' {
        InModuleScope Automation {
            $loaded = @([pscustomobject]@{ Name = 'HPEOneView.860'; Version = [version]'8.60' })
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion '10.0.4265.2221' -LoadedModules $loaded
            $d.Action | Should -Be 'Error'
            $d.Error  | Should -Match 'HPEOneView\.860'
        }
    }

    It 'Ignores the legacy HPEOneView.830 library when deciding' {
        InModuleScope Automation {
            $loaded = @([pscustomobject]@{ Name = 'HPEOneView.830'; Version = [version]'8.30' })
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion '10.0.4265.2221' -LoadedModules $loaded
            $d.Action | Should -Be 'Import'
        }
    }

    It 'Imports when nothing is loaded' {
        InModuleScope Automation {
            $d = Resolve-OneViewModuleLoadAction -Pinned 'HPEOneView.1000' -InstalledVersion '10.0.4265.2221' -LoadedModules @()
            $d.Action | Should -Be 'Import'
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

    It 'Errors when an older module is pinned against a newer appliance' {
        InModuleScope Automation {
            Mock Resolve-PinnedOneViewModule { return 'HPEOneView.800' }
            Mock Get-OneViewApplianceMajorVersion { return 10 }
            $cred = [System.Management.Automation.PSCredential]::new(
                'u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
            $r = Connect-OneViewSession -Appliance 'ov.test' -Credential $cred
            $r.Connected | Should -Be $false
            $r.Error     | Should -Match 'OLDER'
        }
    }

    It 'Reuses an already-loaded matching OneView module instead of re-importing it' {
        InModuleScope Automation {
            $cred = [System.Management.Automation.PSCredential]::new(
                'u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
            Mock Resolve-PinnedOneViewModule { return 'HPEOneView.1000' }
            Mock Get-OneViewApplianceMajorVersion { return 10 }
            Mock Get-Module { $null }
            Mock Get-Module -ParameterFilter { $ListAvailable } {
                [pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221'; Path = 'C:\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1' }
            }
            Mock Get-Module -ParameterFilter { $Name -like 'HPEOneView*' -and -not $ListAvailable } {
                [pscustomobject]@{ Name = 'HPEOneView.1000'; Version = [version]'10.0.4265.2221' }
            }
            # Re-importing a loaded HPE library throws in the vendor module; a reuse
            # path must never reach Import-Module at all.
            Mock Import-Module { throw 'Import-Module must not be called when the module is already loaded.' }
            Mock Connect-OVMgmt { $null }
            $r = Connect-OneViewSession -Appliance 'ov.test' -Credential $cred
            $r.Error | Should -Not -Match 'Failed to import'
            Should -Invoke Import-Module -Times 0 -Exactly
        }
    }

    It 'Reports a refused conflicting library without re-importing it' {
        InModuleScope Automation {
            $cred = [System.Management.Automation.PSCredential]::new(
                'u', (ConvertTo-SecureString 'p' -AsPlainText -Force))
            Mock Resolve-PinnedOneViewModule { return 'HPEOneView.1000' }
            Mock Get-OneViewApplianceMajorVersion { return 10 }
            # A stray library of a different name is already loaded in this console.
            Mock Get-Module -ParameterFilter { $Name -like 'HPEOneView*' -and -not $ListAvailable } {
                @([pscustomobject]@{ Name = 'HPEOneView.860'; Version = [version]'8.60' })
            }
            Mock Import-Module { }
            $r = Connect-OneViewSession -Appliance 'ov.test' -Credential $cred
            $r.Connected | Should -Be $false
            # The module-compliance guard refuses before any import is attempted.
            $r.Error | Should -Match 'HPEOneView\.860'
            Should -Invoke Import-Module -Times 0 -Exactly
        }
    }
}
