# Get-OneViewServerTarget.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewServerTarget.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Get-OneViewServerTarget - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Get-OneViewServerTarget -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Get-OneViewServerTarget
        foreach ($p in @('ServerIdentifier','OneViewHost','IdentifierType','MockResult','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Returns MockResult without network call' {
        $r = Get-OneViewServerTarget -ServerIdentifier 'TEST' -MockResult @{
            Success = $true; Server = 'TEST'; Details = @{ serial_number = 'MXQ0000' }
        }
        $r.Success          | Should -Be $true
        $r.Details.serial_number | Should -Be 'MXQ0000'
    }

    It 'Fails when OneViewHost missing and no MockResult' {
        $prevAuto = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $r = Get-OneViewServerTarget -ServerIdentifier 'TEST'
            $r.Success | Should -Be $false
            $r.Error   | Should -Match 'OneViewHost'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }

    It 'DryRun succeeds' {
        $r = Get-OneViewServerTarget -OneViewHost 'oneview.test.local' -ServerIdentifier 'TEST' -DryRun
        $r.Success | Should -Be $true
        $r.DryRun  | Should -Be $true
    }

    It 'Rejects unknown IdentifierType' {
        { & Get-OneViewServerTarget -ServerIdentifier 'TEST' -IdentifierType 'Bogus' -ErrorAction SilentlyContinue } |
            Should -Throw
    }
}

Describe 'Get-OneViewServerTarget - strict single-server matching (mocked REST)' {
    BeforeAll {
        $Script:TargetCred = [System.Management.Automation.PSCredential]::new(
            'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
        InModuleScope Automation {
            # Reuse an active session so Resolve-OneViewSession does not attempt a real connect.
            Mock Get-OneViewActiveSession {
                [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true }
            }
        }
    }

    It 'Fails hard when a query matches more than one server' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                return @{ count = 2; members = @(
                    [pscustomobject]@{ name = 's1'; serialNumber = 'DUP'; status = 'OK'; mpIpAddresses = @('10.0.0.1') },
                    [pscustomobject]@{ name = 's2'; serialNumber = 'DUP'; status = 'OK'; mpIpAddresses = @('10.0.0.2') }
                )}
            }
        }
        $r = Get-OneViewServerTarget -OneViewHost 'h' -ServerIdentifier 'DUP' -IdentifierType Serial -Credential $Script:TargetCred
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'Ambiguous'
    }

    It 'Succeeds when a query matches exactly one server' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                return @{ count = 1; members = @(
                    [pscustomobject]@{ name = 's1'; serialNumber = 'UNIQUE'; model = 'DL380'; powerState = 'On'; status = 'OK'; mpIpAddresses = @('10.0.0.1'); uri = '/rest/x' }
                )}
            }
        }
        $r = Get-OneViewServerTarget -OneViewHost 'h' -ServerIdentifier 'UNIQUE' -IdentifierType Serial -Credential $Script:TargetCred
        $r.Success              | Should -Be $true
        $r.Details.serial_number | Should -Be 'UNIQUE'
    }
}
