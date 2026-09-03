# Test-PreBuildValidation.Unit.Tests.ps1
# Mocked unit tests for Test-PreBuildValidation.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Test-PreBuildValidation - basic invocation' {
    It 'Function is exported' {
        $cmd = Get-Command Test-PreBuildValidation -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Test-PreBuildValidation
        foreach ($p in @('ServerIdentifier','OneViewHost','IloIp','IsoUrl','DryRun','SkipOneView','SkipIlo','SkipDpMp','SkipIsoUrl')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'DryRun with all skips returns Success' {
        $r = Test-PreBuildValidation -SrvrId 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        $r.Success       | Should -Be $true
        $r.Server        | Should -Be 'TEST'
        $r.Checks.Keys.Count | Should -BeGreaterThan 0
    }

    It 'Skips iso_url_check when IsoUrl empty' {
        $r = Test-PreBuildValidation -SrvrId 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        ($r.Checks['iso_url_check_skipped'].status) | Should -Be 'SKIP'
        $r.Checks.Keys -notcontains 'iso_url_provided' | Should -Be $true
    }

    It 'SkipIsoUrl suppresses the ISO URL check' {
        $r = Test-PreBuildValidation -SrvrId 'TEST' -IsoUrl 'https://example.com/iso.iso' -DryRun -SkipOneView -SkipIlo -SkipDpMp -SkipIsoUrl
        ($r.Checks['iso_url_check_skipped'].status) | Should -Be 'SKIP'
    }

    It 'Returns Checks dictionary even when nothing configured' {
        $r = Test-PreBuildValidation -SrvrId 'TEST' -DryRun -SkipOneView -SkipIlo -SkipDpMp
        $r.Checks            | Should -Not -Be $null
        $r.Checks.audit_recorded | Should -Not -Be $null
    }
}

Describe 'Test-PreBuildValidation - iLO credential fallback to OneView credentials' {
    BeforeAll {
        $Script:OvCred  = [System.Management.Automation.PSCredential]::new('ovuser',  (ConvertTo-SecureString 'ovpass'  -AsPlainText -Force))
        $Script:IloCred = [System.Management.Automation.PSCredential]::new('ilouser', (ConvertTo-SecureString 'ilopass' -AsPlainText -Force))
        InModuleScope Automation {
            Mock Get-OneViewActiveSession { [pscustomobject]@{ Name = 'h'; SessionID = 'tok'; Connected = $true } }
        }
    }

    It 'Uses -OneViewCredential for the iLO Redfish check when it succeeds' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/redfish/v1/Systems/1' } -MockWith {
                if ($Credential -and $Credential.UserName -eq 'ovuser') { return [pscustomobject]@{ PowerState = 'On' } }
                throw [System.Net.Http.HttpRequestException]::new('401')
            }
        }
        $r = Test-PreBuildValidation -SrvrId 'x' -IloIp '10.0.0.5' -OneViewCredential $Script:OvCred -DryRun:$false -SkipOneView -SkipDpMp -SkipIsoUrl
        $r.Checks['ilo_credentials'].status  | Should -Be 'PASS'
        $r.Checks['ilo_credentials'].details | Should -Match 'OneView credentials'
    }

    It 'Falls back to -IloCredential when -OneViewCredential is rejected by iLO' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/redfish/v1/Systems/1' } -MockWith {
                if ($Credential -and $Credential.UserName -eq 'ilouser') { return [pscustomobject]@{ PowerState = 'On' } }
                throw [System.Net.Http.HttpRequestException]::new('401 Unauthorized')
            }
        }
        $r = Test-PreBuildValidation -SrvrId 'x' -IloIp '10.0.0.5' -OneViewCredential $Script:OvCred -IloCredential $Script:IloCred -DryRun:$false -SkipOneView -SkipDpMp -SkipIsoUrl
        $r.Checks['ilo_credentials'].status | Should -Be 'PASS'
    }

    It 'Fails (and states the reason) when -OneViewCredential is rejected by iLO and no fallback is available' {
        InModuleScope Automation {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/redfish/v1/Systems/1' } -MockWith {
                throw [System.Net.Http.HttpRequestException]::new('401 Unauthorized')
            }
        }
        $prevAuto = $env:AUTOMATED_MODE
        $env:AUTOMATED_MODE = 'true'
        try {
            $r = Test-PreBuildValidation -SrvrId 'x' -IloIp '10.0.0.5' -OneViewCredential $Script:OvCred -DryRun:$false -SkipOneView -SkipDpMp -SkipIsoUrl
            $r.Checks['ilo_credentials'].status | Should -Be 'FAIL'
        } finally {
            if ($prevAuto) { $env:AUTOMATED_MODE = $prevAuto } else { $env:AUTOMATED_MODE = $null }
        }
    }
}
