# Get-OneViewConnectionStatus.Unit.Tests.ps1
# Mocked unit tests for Get-OneViewConnectionStatus.
# No live OneView appliance is required: the REST layer is either bypassed via
# -MockResult / -DryRun, or intercepted with an InModuleScope mock of Invoke-RestMethod.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
    $Script:TestCred = [System.Management.Automation.PSCredential]::new(
        'admin', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))
}

Describe 'Get-OneViewConnectionStatus - basic invocation' {
    It 'Function is exported' {
        Get-Command Get-OneViewConnectionStatus -ErrorAction SilentlyContinue | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Get-OneViewConnectionStatus
        foreach ($p in @('OneViewHost','ServerIdentifier','IdentifierType','Credential','OneViewUser','OneViewPassword','IncludeServerCount','MockResult','DryRun')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Returns MockResult without network call' {
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -MockResult @{
            Success = $true; Connected = $true; Reachable = $true; Authenticated = $true
            Appliance = 'h'; Version = '10.00'; ServerCount = 5; Server = $null; Error = $null
        }
        $r.Connected   | Should -Be $true
        $r.ServerCount | Should -Be 5
    }

    It 'Fails when OneViewHost missing and no MockResult' {
        $prevAuto = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $r = Get-OneViewConnectionStatus -Credential $Script:TestCred
            $r.Success | Should -Be $false
            $r.Connected | Should -Be $false
            $r.Error   | Should -Match 'OneViewHost'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }

    It 'DryRun succeeds' {
        $r = Get-OneViewConnectionStatus -OneViewHost 'oneview.test.local' -Credential $Script:TestCred -DryRun
        $r.Success   | Should -Be $true
        $r.Connected | Should -Be $true
        $r.DryRun    | Should -Be $true
    }
}

Describe 'Get-OneViewConnectionStatus - parsing (mocked REST)' {
    BeforeAll {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                @{ currentVersion = '10.00' }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' -and $Uri -notlike '*filter*' } -MockWith {
                @{ total = 7; members = @() }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' -and $Uri -like '*filter*' } -MockWith {
                @{ count = 1; members = @(
                    [pscustomobject]@{ name = 's1'; serialNumber = 'A'; model = 'DL380'; powerState = 'On'; status = 'OK'; mpIpAddresses = @('10.0.0.1'); enclosureName = 'Enc1'; position = 'Bay 1'; uri = '/rest/x'; romVersion = '1.0' }
                ) }
            }
        }
    }

    It 'Reports connected + version + server count from mocked probes' {
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -Credential $Script:TestCred -IncludeServerCount
        $r.Connected      | Should -Be $true
        $r.Reachable      | Should -Be $true
        $r.Authenticated  | Should -Be $true
        $r.Version        | Should -Be '10.00'
        $r.VersionCompliant | Should -Be $true
        $r.ServerCount    | Should -Be 7
        $r.Error          | Should -Be $null
    }

    It 'Resolves a server when -ServerIdentifier is supplied' {
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -Credential $Script:TestCred -ServerIdentifier 'A' -IdentifierType Serial
        $r.Server              | Should -Not -Be $null
        $r.Server.name         | Should -Be 's1'
        $r.Server.serial_number| Should -Be 'A'
        $r.Server.connected    | Should -Be $true
    }
}

Describe 'Get-OneViewConnectionStatus - version guard (HPEOneView.1000 / OneView 10.x)' {
    BeforeAll {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                $Script:CurrentVersionProbe
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' -and $Uri -notlike '*filter*' } -MockWith {
                @{ total = 0; members = @() }
            }
        }
    }

    It 'Flags a compliant OneView 10.x version (string "10.00") as compliant' {
        InModuleScope Automation { $Script:CurrentVersionProbe = @{ currentVersion = '10.00' } }
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -Credential $Script:TestCred
        $r.Version          | Should -Be '10.00'
        $r.VersionCompliant | Should -Be $true
        $r.VersionWarning   | Should -Be $null
    }

    It 'Flags a compliant OneView 10.x version (integer 10000) as compliant' {
        InModuleScope Automation { $Script:CurrentVersionProbe = @{ currentVersion = 10000 } }
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -Credential $Script:TestCred
        $r.VersionCompliant | Should -Be $true
        $r.VersionWarning   | Should -Be $null
    }

    It 'Fails loudly (warns) on a non-compliant version (integer 8200 = 8.20)' {
        InModuleScope Automation { $Script:CurrentVersionProbe = @{ currentVersion = 8200 } }
        $r = Get-OneViewConnectionStatus -OneViewHost 'va-oneviewt-01' -Credential $Script:TestCred -WarningAction SilentlyContinue
        $r.Version          | Should -Be 8200
        $r.VersionCompliant | Should -Be $false
        $r.VersionWarning   | Should -Not -Be $null
        $r.VersionWarning   | Should -Match 'OneView 10.x'
    }

    It 'Fails loudly (warns) on a non-compliant dotted version (string "8.20")' {
        InModuleScope Automation { $Script:CurrentVersionProbe = @{ currentVersion = '8.20' } }
        $r = Get-OneViewConnectionStatus -OneViewHost 'h' -Credential $Script:TestCred -WarningAction SilentlyContinue
        $r.VersionCompliant | Should -Be $false
        $r.VersionWarning   | Should -Not -Be $null
    }
}

Describe 'Get-OneViewConnectionStatus - HPEOneView module session (parameterless)' {
    BeforeAll {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/version*' } -MockWith {
                @{ currentVersion = '10.00' }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' -and $Uri -notlike '*filter*' } -MockWith {
                @{ total = 3; members = @() }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/rest/server-hardware*' -and $Uri -like '*filter*' } -MockWith {
                @{ count = 0; members = @() }
            }
        }
    }

    It 'Reports not-connected (no connect/disconnect) when no session and no -OneViewHost' {
        $prevAuto = $env:AUTOMATED_MODE
        try {
            $env:AUTOMATED_MODE = 'true'
            $global:ConnectedSessions = $null
            $r = Get-OneViewConnectionStatus
            $r.Success   | Should -Be $false
            $r.Connected | Should -Be $false
            $r.Appliance | Should -Be $null
            $r.Error     | Should -Match 'No active OneView session'
        } finally {
            $global:ConnectedSessions = $null
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }

    It 'Reuses the active HPEOneView session when -OneViewHost is omitted' {
        try {
            $global:ConnectedSessions = @(
                [pscustomobject]@{ Name = 'ov-session.local'; SessionID = 'token-abc'; Connected = $true }
            )
            $r = Get-OneViewConnectionStatus
            $r.Connected     | Should -Be $true
            $r.Appliance     | Should -Be 'ov-session.local'
            $r.SessionSource | Should -Be 'HPEOneViewModule'
        } finally {
            $global:ConnectedSessions = $null
        }
    }

    It 'Reports SessionSource Explicit when -OneViewHost is supplied' {
        $r = Get-OneViewConnectionStatus -OneViewHost 'explicit.local' -Credential $Script:TestCred
        $r.Connected     | Should -Be $true
        $r.Appliance     | Should -Be 'explicit.local'
        $r.SessionSource | Should -Be 'Explicit'
    }

    It 'Never invokes Connect-OVMgmt or Disconnect-OVMgmt (read-only check only)' {
        try {
            $global:ConnectedSessions = @(
                [pscustomobject]@{ Name = 'ov-session.local'; SessionID = 'token-abc'; Connected = $true }
            )
            # The HPEOneView module is not loaded in tests; mock both cmdlets so
            # any erroneous call would throw, proving the command never connects
            # or disconnects an existing session.
            InModuleScope Automation {
                Mock Connect-OVMgmt    { throw 'Connect-OVMgmt was called erroneously' }
                Mock Disconnect-OVMgmt { throw 'Disconnect-OVMgmt was called erroneously' }
            }
            { Get-OneViewConnectionStatus } | Should -Not -Throw
        } finally {
            $global:ConnectedSessions = $null
        }
    }
}
