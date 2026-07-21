# Get-OneViewServerList.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewServerList.
# No live OneView appliance is required: the REST layer is either bypassed via
# -MockResult / -DryRun, or intercepted with an InModuleScope mock of Invoke-RestMethod
# to exercise the real pagination and -Filter logic.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
    $Script:TestCred = [System.Management.Automation.PSCredential]::new(
        'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
}

Describe 'Get-OneViewServerList - basic invocation' {
    It 'Function is exported' {
        Get-Command Get-OneViewServerList -ErrorAction SilentlyContinue | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Get-OneViewServerList
        foreach ($p in @('OneViewHost','Credential','OneViewUser','OneViewPassword','Filter','PageSize','MockResult','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Returns MockResult without network call' {
        $r = Get-OneViewServerList -OneViewHost 'h' -MockResult @{
            Success = $true; Count = 2; Servers = @(@{ name = 's1' }, @{ name = 's2' }); Error = $null
        }
        $r.Success | Should -Be $true
        $r.Count   | Should -Be 2
    }

    It 'Fails when OneViewHost missing and no MockResult' {
        $prevAuto = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $r = Get-OneViewServerList -Credential $Script:TestCred
            $r.Success | Should -Be $false
            $r.Error   | Should -Match 'OneViewHost'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }

    It 'DryRun succeeds' {
        $r = Get-OneViewServerList -OneViewHost 'h' -Credential $Script:TestCred -DryRun
        $r.Success | Should -Be $true
        $r.DryRun  | Should -Be $true
    }

    It 'Rejects an unsupported -Filter' {
        $r = Get-OneViewServerList -OneViewHost 'h' -Credential $Script:TestCred -Filter 'foo:bar'
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'Filter'
    }
}

Describe 'Get-OneViewServerList - pagination & filtering (mocked REST)' {
    BeforeAll {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                if ($Uri -match 'start=(\d+)') { $s = [int]$Matches[1] } else { $s = 0 }
                if ($s -eq 0) {
                    return @{ total = 3; members = @(
                        [pscustomobject]@{ name = 's1'; serialNumber = 'A'; model = 'DL380'; powerState = 'On';  status = 'OK';       mpIpAddresses = @('10.0.0.1'); enclosureName = 'Enc1'; position = 'Bay 1'; uri = '/rest/x'; romVersion = '1.0' },
                        [pscustomobject]@{ name = 's2'; serialNumber = 'B'; model = 'DL380'; powerState = 'Off'; status = 'Critical'; mpIpAddresses = @('10.0.0.2'); enclosureName = 'Enc1'; position = 'Bay 2'; uri = '/rest/y'; romVersion = '1.0' }
                    )}
                } else {
                    return @{ total = 3; members = @(
                        [pscustomobject]@{ name = 's3'; serialNumber = 'C'; model = 'DL380'; powerState = 'On'; status = 'Warning'; mpIpAddresses = @('10.0.0.3'); enclosureName = 'Enc1'; position = 'Bay 3'; uri = '/rest/z'; romVersion = '1.0' }
                    )}
                }
            }
        }
    }

    It 'Enumerates every page (Count = 3)' {
        $r = Get-OneViewServerList -OneViewHost 'h' -Credential $Script:TestCred -PageSize 2
        $r.Success | Should -Be $true
        $r.Count   | Should -Be 3
    }

    It 'Filters by health:Critical' {
        $r = Get-OneViewServerList -OneViewHost 'h' -Credential $Script:TestCred -PageSize 2 -Filter 'health:Critical'
        $r.Success | Should -Be $true
        $r.Count   | Should -Be 1
        $r.Servers[0].name | Should -Be 's2'
    }

    It 'Filters by power:Off' {
        $r = Get-OneViewServerList -OneViewHost 'h' -Credential $Script:TestCred -PageSize 2 -Filter 'power:Off'
        $r.Success | Should -Be $true
        $r.Count   | Should -Be 1
        $r.Servers[0].name | Should -Be 's2'
    }
}
