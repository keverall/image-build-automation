# Get-OneViewServerTarget.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewServerTarget.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Get-OneViewServerTarget - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Get-OneViewServerTarget -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Get-OneViewServerTarget
        foreach ($p in @('ServerIdentifier','OneViewHost','IdentifierType','MockResult','DryRun','PassThru')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Returns MockResult without network call' {
        $r = Get-OneViewServerTarget -SrvrId 'TEST' -MockResult @{
            Success = $true; Server = 'TEST'; Details = @{ serial_number = 'MXQ0000' }
        } -PassThru
        $r.Success          | Should -Be $true
        $r.Details.serial_number | Should -Be 'MXQ0000'
    }

    It 'Fails when OneViewHost missing and no MockResult' {
        $prevAuto = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $r = Get-OneViewServerTarget -SrvrId 'TEST' -PassThru
            $r.Success | Should -Be $false
            $r.Error   | Should -Match 'OneViewHost'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }

    It 'DryRun succeeds' {
        $r = Get-OneViewServerTarget -OneViewHost 'oneview.test.local' -SrvrId 'TEST' -DryRun -PassThru
        $r.Success | Should -Be $true
        $r.DryRun  | Should -Be $true
    }

    It 'Rejects unknown IdentifierType' {
        { & Get-OneViewServerTarget -SrvrId 'TEST' -IdentifierType 'Bogus' -ErrorAction SilentlyContinue } |
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
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'DUP' -IdentifierType Serial -Credential $Script:TargetCred -PassThru
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
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'UNIQUE' -IdentifierType Serial -Credential $Script:TargetCred -PassThru
        $r.Success              | Should -Be $true
        $r.Details.serial_number | Should -Be 'UNIQUE'
    }
}

Describe 'Get-OneViewServerTarget - parameter aliases & single-parameter targeting' {
    BeforeAll {
        $Script:TargetCred = [System.Management.Automation.PSCredential]::new(
            'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                $member = [pscustomobject]@{ name = 'PROD-SRV-01'; serialNumber = 'MXQ1234567'; model = 'DL380'; powerState = 'On'; status = 'OK'; mpIpAddresses = @('10.0.0.1'); enclosureName = 'Enc1'; position = 'Bay 1'; uri = '/rest/x'; romVersion = '1.0' }
                if ($Uri -like "*name='PROD-SRV-01'*") { return @{ count = 1; members = @($member) } }
                if ($Uri -like "*serialNumber='MXQ1234567'*") { return @{ count = 1; members = @($member) } }
                return @{ count = 0; members = @() }
            }
        }
    }

    It 'Exposes canonical -ServerIdentifier (alias -SrvrId) and -IdentifierType (alias -IdTyp)' {
        $cmd = Get-Command Get-OneViewServerTarget
        $cmd.Parameters.ContainsKey('ServerIdentifier') | Should -Be $true
        $cmd.Parameters['ServerIdentifier'].Aliases -contains 'SrvrId' | Should -Be $true
        $cmd.Parameters.ContainsKey('IdentifierType') | Should -Be $true
        $cmd.Parameters['IdentifierType'].Aliases -contains 'IdTyp' | Should -Be $true
    }

    It 'Resolves via canonical -ServerIdentifier -IdentifierType Serial' {
        $r = Get-OneViewServerTarget -OneViewHost 'h' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial -Credential $Script:TargetCred -PassThru
        $r.Success | Should -Be $true
        $r.ResolvedBy | Should -Be 'Serial'
        $r.Details.serial_number | Should -Be 'MXQ1234567'
    }

    It 'Resolves via short aliases -SrvrId -IdTyp (proves aliases bind)' {
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'MXQ1234567' -IdTyp Serial -Credential $Script:TargetCred -PassThru
        $r.Success | Should -Be $true
        $r.ResolvedBy | Should -Be 'Serial'
        $r.Details.serial_number | Should -Be 'MXQ1234567'
    }

    It 'Resolves with a single -ServerIdentifier (Auto detects Name)' {
        $r = Get-OneViewServerTarget -OneViewHost 'h' -ServerIdentifier 'PROD-SRV-01' -Credential $Script:TargetCred -PassThru
        $r.Success | Should -Be $true
        $r.ResolvedBy | Should -Be 'Name'
        $r.Details.name | Should -Be 'PROD-SRV-01'
    }

    It 'Rejects the invalid -SrvId alias (typo, missing r)' {
        { & Get-OneViewServerTarget -SrvId 'X' -ErrorAction Stop } | Should -Throw
    }
}

Describe 'Get-OneViewServerTarget - output rendering (no raw hashtable dump)' {
    BeforeAll {
        $Script:TargetCred = [System.Management.Automation.PSCredential]::new(
            'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                return @{ count = 1; members = @(
                    [pscustomobject]@{ name = 'srv-x'; serialNumber = 'X1'; model = 'DL380'; powerState = 'On'; status = 'OK'; mpIpAddresses = @('10.0.0.1'); enclosureName = 'Enc1'; position = 'Bay 1'; uri = '/rest/x'; romVersion = '1.0' }
                )}
            }
        }
    }

    It 'Renders a clean Details sentence (not a { [...] } hashtable dump)' {
        $hostRecords = $null
        $null = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'X1' -IdentifierType Serial -Credential $Script:TargetCred -InformationVariable hostRecords
        $rendered = ($hostRecords | ForEach-Object { $_.MessageData }) -join "`n"
        $rendered | Should -Match 'OneView Server Target'
        $rendered | Should -Match 'Details:'
        $rendered | Should -Match 'name=srv-x'
        $rendered | Should -Not -Match 'System\.Collections\.Hashtable'
        $rendered | Should -Not -Match '^\s*Details\s*:\s*\{'
    }
}

Describe 'Get-OneViewServerTarget - honest error classification' {
    BeforeAll {
        $Script:TargetCred = [System.Management.Automation.PSCredential]::new(
            'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
        }
    }

    It 'Reports a plain "No connection" message when the appliance cannot be reached' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                throw [System.Net.Http.HttpRequestException]::new('No such host is known.')
            }
        }
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'X1' -IdentifierType Serial -Credential $Script:TargetCred -PassThru
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'No connection to OneView'
        $r.Error   | Should -Not -Match 'query failed'
    }

    It 'Does not leak the raw "Response status code" exception text' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                throw [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
            }
        }
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'X1' -IdentifierType Serial -Credential $Script:TargetCred -PassThru
        $r.Success | Should -Be $false
        $r.Error   | Should -Not -Match 'Response status code does not indicate success'
        $r.Error   | Should -Match 'HTTP 400'
    }

    It 'Auto mode falls through a 400 on one type and resolves via the next type' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' } -MockWith {
                if ($Uri -like "*serialNumber='alp-srv'*") {
                    throw [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                }
                if ($Uri -like "*name='alp-srv'*") {
                    return @{ count = 1; members = @(
                        [pscustomobject]@{ name = 'alp-srv'; serialNumber = 'SN1'; model = 'DL380'; powerState = 'On'; status = 'OK'; mpIpAddresses = @('10.0.0.1'); uri = '/rest/x'; romVersion = '1.0' }
                    )}
                }
                return @{ count = 0; members = @() }
            }
        }
        $r = Get-OneViewServerTarget -OneViewHost 'h' -SrvrId 'alp-srv' -Credential $Script:TargetCred -PassThru
        $r.Success     | Should -Be $true
        $r.ResolvedBy | Should -Be 'Name'
    }
}
