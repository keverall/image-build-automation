# Start-PhysicalServerBuild.Unit.Tests.ps1
# Mocked unit tests for the end-to-end orchestrator.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Start-PhysicalServerBuild - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Start-PhysicalServerBuild -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Start-PhysicalServerBuild
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','SiteCode','ManagementPoint',
                         'DistributionPoint','RepoBaseUrl','DryRun','ExternalIsoPath')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with everything skipped returns Success' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -GuardRail '.*' -DryRun -PassThru -Quiet `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $true
        $r.server  | Should -Be 'TEST'
        $r.audit_file | Should -Not -Be $null
    }

    It 'Fails early (graceful, logged) when -GuardRail is omitted' {
        $r = Start-PhysicalServerBuild -SrvrId 'TEST' -DryRun -PassThru -Quiet `
            -ExternalIsoPath 'https://artifacts/isos/win.iso' `
            -SkipPreBuild -SkipOneView -SkipMount -SkipMonitor -SkipPostBuild
        $r.Success | Should -Be $false
        $r.GuardRailRequired | Should -Be $true
        $r.Error | Should -Match 'GUARD RAIL REQUIRED'
    }
}

Describe 'Start-PhysicalServerBuild - aborts when OneView resolution fails' {
    BeforeAll {
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
            Mock Get-OneViewServerTarget {
                return [hashtable]@{
                    Success = $false
                    Server  = 'alp-qlikview-03ilo'
                    Error   = "No connection to OneView at 'h'. could not reach the appliance (check host, network/VPN, and that OneView is online)."
                }
            }
            # If the orchestrator fails to abort on a bad OneView resolution it would
            # fall through to the guard rail - this throws to prove the abort stops it.
            Mock Assert-GuardRail { throw 'Assert-GuardRail must NOT run when OneView resolution failed' }
        }
    }

    It 'Returns failure and never reaches the guard rail / destructive steps when OneView target resolution fails' {
        $prevAuto = $env:AUTOMATED_MODE
        $env:AUTOMATED_MODE = 'true'
        try {
            $r = Start-PhysicalServerBuild -SrvrId 'alp-qlikview-03ilo' -OneViewHost 'h' -GuardRail '.*' -PassThru -Quiet `
                -ExternalIsoPath 'https://artifacts/isos/win.iso' `
                -SkipPreBuild -SkipMount -SkipMonitor -SkipPostBuild
            $r.Success | Should -Be $false
            $r.error   | Should -Match 'OneView resolution failed'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }
}

Describe 'Start-PhysicalServerBuild - tolerates array return from -PassThru upstream calls' {
    BeforeAll {
        InModuleScope Automation {
            Mock Resolve-ExternalIsoPath { return 'cifs://host/share/win.iso' }
            Mock Test-PreBuildValidation {
                # Simulate the buggy upstream behaviour: a -PassThru call that
                # emits an array instead of a single result hashtable.
                return [System.Object[]]@(
                    [hashtable]@{ Success = $true; Server = 'srv01'; Checks = @{} }
                )
            }
            Mock Get-OneViewServerTarget {
                return [System.Object[]]@(
                    [hashtable]@{
                        Success = $true
                        Server  = 'srv01'
                        Details = [hashtable]@{ name = 'srv01'; serial_number = 'SN1'; ilo_ip = '1.2.3.4' }
                    }
                )
            }
            Mock Assert-GuardRail { return $true }
            Mock Invoke-IloRedfish { return [hashtable]@{ Success = $true } }
            # The array-return bug also drives member-access enumeration that
            # reaches the maintenance-mode path; mock it so the test stays
            # self-contained and never triggers an interactive credential prompt.
            Mock Set-MaintenanceMode { return [hashtable]@{ Success = $true } }
        }
    }

    It 'Does not throw the hashtable parameter-binding error and records a single object per step' {
        # The reported crash was: "Cannot process argument transformation on
        # parameter 'r'. Cannot convert the System.Object[] value ...". The
        # call must complete, and each recorded step must be a single object
        # (the first element of the array), not the raw array.
        $r = Start-PhysicalServerBuild -SrvrId 'srv01' -OneViewHost 'h' -IloIp '1.2.3.4' -GuardRail '.*' -PassThru -Quiet `
            -ExternalIsoPath 'cifs://host/share/win.iso' `
            -SkipMount -SkipMonitor -SkipPostBuild -SkipConfirmation

        $r | Should -Not -Be $null
        $r.steps.pre_build_validation | Should -Not -BeOfType ([System.Array])
        $r.steps.oneview_target       | Should -Not -BeOfType ([System.Array])
        $r.steps.oneview_target.Success | Should -Be $true
    }
}

Describe 'Start-PhysicalServerBuild - skips maintenance-mode enable when already in maintenance' {
    # Regression test for Fix 3: when OneView resolution returns maintenance_mode='Yes',
    # the orchestrator must NOT call _Enable-OneViewMaintenanceMode again (no redundant API call).
    BeforeAll {
        InModuleScope Automation {
            $Script:EnableCalled = $false
            Mock Resolve-ExternalIsoPath { return 'cifs://host/share/win.iso' }
            Mock Test-PreBuildValidation { return @{ Success = $true; Server = 'srv01'; Checks = @{} } }
            Mock Get-OneViewServerTarget {
                return @{
                    Success = $true
                    Server  = 'omg-qlikview-03ilo'
                    Details = [hashtable]@{
                        name            = 'omg-qlikview-03ilo'
                        serial_number   = 'CZ22420JCN'
                        ilo_ip          = '1.2.3.4'
                        maintenance_mode = 'Yes'   # <-- already in maintenance mode
                    }
                }
            }
            Mock Assert-GuardRail { return $true }
            Mock Invoke-IloRedfish { return [hashtable]@{ Success = $true } }
            Mock _Enable-OneViewMaintenanceMode {
                $Script:EnableCalled = $true
                throw 'should not reach _Enable-OneViewMaintenanceMode when already in maintenance mode'
            }
            Mock _Disable-OneViewMaintenanceMode { return [hashtable]@{ Success = $true } }
            Mock Set-MaintenanceMode { return [hashtable]@{ Success = $true } }
        }
    }

    It 'Does not call _Enable-OneViewMaintenanceMode when server is already in maintenance mode' {
        $r = Start-PhysicalServerBuild -SrvrId 'omg-qlikview-03ilo' -OneViewHost 'h' -IloIp '1.2.3.4' -GuardRail '.*' -PassThru -Quiet `
            -ExternalIsoPath 'cifs://host/share/win.iso' `
            -SkipMount -SkipMonitor -SkipPostBuild -SkipConfirmation

        $r.Success | Should -Be $true
        # Verify _Enable-OneViewMaintenanceMode was never called
        $enableCalled = InModuleScope Automation { $Script:EnableCalled }
        $enableCalled | Should -Be $false
        # Verify the step was recorded as successful
        $r.steps.oneview_maintenance_enable.Success | Should -Be $true
    }
}
