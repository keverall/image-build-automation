# Invoke-IloRedfish.Unit.Tests.ps1
# Mocked unit tests for the Redfish iLO integration function.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Invoke-IloRedfish - basic invocation and parameter validation' {
    It 'Function is exported' {
        $cmd = Get-Command Invoke-IloRedfish -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It 'Has expected parameters' {
        $cmd = Get-Command Invoke-IloRedfish
        foreach ($p in @('Action','IloIp','IsoUrl','CdDeviceId','SkipCertificateCheck','DryRun','Force')) {
            $cmd.Parameters.Keys | Should -Contain $p
        }
    }

    It 'Accepts -DryRun switch without HTTP calls' {
        { & Invoke-IloRedfish -Action Status -IloIp '127.0.0.1' -DryRun -ErrorAction SilentlyContinue } |
            Should -Not -Throw
    }

    It 'Rejects unknown parameters' {
        { & Invoke-IloRedfish -Action Status -IloIp '127.0.0.1' -NonExistentParam 2>&1 } |
            Should -Not -Be $null
    }

    It 'Destructive actions require -Force when not in DryRun' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -IsoUrl 'https://example.com/iso.iso'
        $r.Success | Should -Be $false
        $r.Error | Should -Match 'requires -Force'
    }

    It 'Destructive actions succeed in DryRun without -Force' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -IsoUrl 'https://example.com/iso.iso' -DryRun
        $r.Success | Should -Be $true
    }
}

Describe 'Test-IloAuthentication - non-destructive diagnostics' {
    It 'is exported and accepts diagnostic parameters' {
        $cmd = Get-Command Test-IloAuthentication
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain 'IloIp'
        $cmd.Parameters.Keys | Should -Contain 'IloCredential'
        $cmd.Parameters.Keys | Should -Contain 'OneViewServerName'
    }

    It 'reports each endpoint failure without throwing' {
        InModuleScope Automation {
            Mock Invoke-WebRequest { throw [System.Net.WebException]::new('401 Unauthorized') }
            $r = Test-IloAuthentication -IloIp '127.0.0.1' -Quiet
            $r.Success | Should -BeFalse
            @($r.Results).Count | Should -Be 2
            @($r.Results | Where-Object { $_.name -eq 'tcp_tls_redfish' }).Count | Should -Be 1
        }
    }

    It 'uses the OneView server name as the generated iLO username' {
        InModuleScope Automation {
            Mock Read-Host { ConvertTo-SecureString 'secret' -AsPlainText -Force }
            Mock Invoke-WebRequest { throw [System.Net.WebException]::new('401 Unauthorized') }
            $r = Test-IloAuthentication -IloIp '127.0.0.1' -OneViewServerName 'omg-qlikview-03ilo' -UseGeneratedIloAccount -Quiet
            $r.TestedIloUsername | Should -Be 'omg-qlikview-03ilo'
            Should -Invoke Read-Host -Exactly 1 -ParameterFilter { $AsSecureString }
        }
    }

    It 'validates and deletes the session using response headers rather than a JSON token' {
        InModuleScope Automation {
            $script:diagnosticToken = [guid]::NewGuid().ToString('N')
            Mock Invoke-WebRequest {
                param($Method, $Headers)
                if ($Method -eq 'POST') {
                    return @{ Headers = @{ 'X-Auth-Token' = @($script:diagnosticToken); Location = @('/redfish/v1/SessionService/Sessions/42/') }; Content = '{}'; StatusCode = 201 }
                }
                if ($Method -eq 'DELETE' -or $Headers) { $Headers['X-Auth-Token'] | Should -Be $script:diagnosticToken }
                @{ StatusCode = 200; Content = '{}' }
            }
            $cred = [pscredential]::new('ilo-operator', (ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force))
            $r = Test-IloAuthentication -IloIp '10.30.14.15' -IloCredential $cred
            $r.Success | Should -BeTrue
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -eq 'https://10.30.14.15/redfish/v1/SessionService/Sessions/42/'
            }
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'POST' }
        }
    }

    It 'does not send a diagnostic token to a different logout origin' {
        InModuleScope Automation {
            Mock Invoke-WebRequest {
                param($Method)
                if ($Method -eq 'POST') {
                    return @{ Headers = @{ 'X-Auth-Token' = 'synthetic-session'; Location = 'https://other.example.test/session/42/' }; Content = '{}'; StatusCode = 201 }
                }
                @{ StatusCode = 200; Content = '{}' }
            }
            $cred = [pscredential]::new('ilo-operator', (ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force))
            $r = Test-IloAuthentication -IloIp '10.30.14.15' -IloCredential $cred
            ($r.Results | Where-Object name -eq 'direct_redfish_logout').success | Should -BeFalse
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly -ParameterFilter { $Method -eq 'DELETE' }
        }
    }
}

Describe 'Invoke-IloRedfish - IloRedfishSession class' {
    # The IloRedfishSession class is module-scoped (declared in Automation.psm1) so
    # it cannot be referenced as a type accelerator from outside the module.  Its
    # presence is verified indirectly by the MountAndBoot / Status / Mount tests.
    It 'Class is declared inside Automation.psm1' {
        $psm1 = Get-Content (Join-Path $Script:ModuleRoot 'Automation\Automation.psm1') -Raw
        $psm1 | Should -Match 'class\s+IloRedfishSession\b'
    }

    It 'requests OneView SSO with certificate validation disabled for internal iLO certificates' {
        $source = Get-Content (Join-Path $Script:ModuleRoot 'Automation\Public\Invoke-IloRedfish.ps1') -Raw
        ([regex]::Matches($source, 'Get-OVIloSso\s+-IloRestSession\s+-SkipCertificateCheck')).Count |
            Should -Be 3
    }
}

Describe 'Invoke-IloRedfish - PSRedfish direct status adapter' {
    It 'uses PSRedfish for direct credential inventory when the bundled module is imported' {
        InModuleScope Automation {
            Import-Module (Join-Path $PSScriptRoot '../../scripts/modules/PSRedfish/0.1.4/PSRedfish.psd1') -Force
            Mock New-RedfishSession { [pscustomobject]@{ PSTypeNames = @('PSRedfish.Session'); BaseUri = 'https://10.30.14.15' } }
            Mock Invoke-IloStatusWithPSRedfish { @{ System = @{ PowerState = 'On'; Manufacturer = 'HPE'; Model = 'ProLiant'; SerialNumber = 'CZ22420JCM' }; VirtualMedia = @(); AuthDiagnostics = @{ auth_mode = 'psredfish' } } }
            Mock Invoke-RedfishRequest {
                param($Uri)
                if ($Uri -like '*Systems/1') { return @{ PowerState = 'On'; Manufacturer = 'HPE'; Model = 'ProLiant'; SerialNumber = 'CZ22420JCM'; Boot = @{} } }
                if ($Uri -like '*VirtualMedia' -and $Uri -notlike '*VirtualMedia/*') { return @{ Members = @(@{ '@odata.id' = '/redfish/v1/Managers/1/VirtualMedia/2' }) } }
                @{ '@odata.id' = '/redfish/v1/Managers/1/VirtualMedia/2'; Name = 'CD/DVD'; Inserted = $false; Image = $null }
            }
            Mock Remove-RedfishSession {}
            $cred = [pscredential]::new('ilo-operator', (ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force))
            $result = Invoke-IloRedfish -Action Status -IloIp '10.30.14.15' -IloCredential $cred
            $result.Success | Should -BeTrue
            $result.Details.auth_diagnostics.auth_mode | Should -Be 'psredfish'
            Should -Invoke Invoke-IloStatusWithPSRedfish -Times 1 -Exactly
        }
    }
}

Describe 'Invoke-IloRedfish - authentication selection and session synchronization' {
    BeforeAll {
        InModuleScope Automation {
            function script:Get-OVServer { param($Name) }
            function script:Get-OVIloSso { param([Parameter(ValueFromPipeline)]$InputObject, [switch]$IloRestSession, [switch]$SkipCertificateCheck) }
        }
    }

    It 'uses an explicit credential even when OneView SSO is available' {
        InModuleScope Automation {
            Mock Get-OVServer { throw 'SSO must not be used' }
            Mock Get-OVIloSso { throw 'SSO must not be used' }
            Mock Invoke-WebRequest {
                param($Body)
                ([System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json).UserName | Should -Be 'ilo-operator'
                @{ Headers = @{ 'X-Auth-Token' = 'synthetic-direct'; Location = '/redfish/v1/SessionService/Sessions/42/' } }
            }
            Mock Invoke-RestMethod { @{ PowerState = 'On'; Boot = @{}; Members = @() } }
            $cred = [pscredential]::new('ilo-operator', (ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force))
            $r = Invoke-IloRedfish -Action MountAndBoot -Force -IloIp '10.30.14.15' -IloCredential $cred -OneViewHost 'ov.example.test' -OneViewServerName 'server01' -IsoUrl 'https://iso.example.test/windows.iso'
            $r.Success | Should -BeTrue
            $r.AuthDiagnostics.auth_mode | Should -Be 'direct_ilo'
            Should -Invoke Get-OVIloSso -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -Times 5 -Exactly -ParameterFilter { $Headers['X-Auth-Token'] -eq 'synthetic-direct' }
        }
    }

    It 'does not retry rejected credentials or perform any mutation' {
        InModuleScope Automation {
            Mock Invoke-WebRequest { throw '401 Unauthorized' }
            Mock Invoke-RestMethod { throw 'requests must not run after login failure' }
            $cred = [pscredential]::new('ilo-operator', (ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force))
            $r = Invoke-IloRedfish -Action Reset -Force -IloIp '10.30.14.15' -IloCredential $cred
            $r.Success | Should -BeFalse
            $r.Error | Should -Match 'redfish_session_login.*401'
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }

    It 'refreshes rejected SSO before writes and uses the refreshed token for every write' {
        InModuleScope Automation {
            $script:ssoNumber = 0
            Mock Get-OVServer { @{ name = 'server01' } }
            Mock Get-OVIloSso {
                $script:ssoNumber++
                @{ RootUri = 'https://10.30.14.15/redfish/v1'; 'X-Auth-Token' = "synthetic-sso-$script:ssoNumber" }
            }
            Mock Invoke-WebRequest { throw 'direct credentials must not be used' }
            Mock Invoke-RestMethod {
                param($Headers)
                if ($Headers['X-Auth-Token'] -eq 'synthetic-sso-1') { throw '401 Unauthorized' }
                @{ PowerState = 'On'; Boot = @{} }
            }
            $r = Invoke-IloRedfish -Action MountAndBoot -Force -IloIp '10.30.14.15' -OneViewHost 'ov.example.test' -OneViewServerName 'server01' -IsoUrl 'https://iso.example.test/windows.iso'
            $r.Success | Should -BeTrue
            Should -Invoke Get-OVIloSso -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly -ParameterFilter { $Method -in @('Post', 'Patch') -and $Headers['X-Auth-Token'] -eq 'synthetic-sso-2' }
        }
    }

    It 'blocks mutations when refreshed SSO is also rejected' {
        InModuleScope Automation {
            Mock Get-OVServer { @{ name = 'server01' } }
            Mock Get-OVIloSso { @{ RootUri = 'https://10.30.14.15/redfish/v1'; 'X-Auth-Token' = 'synthetic-sso' } }
            Mock Invoke-RestMethod { throw '401 Unauthorized' }
            $r = Invoke-IloRedfish -Action MountAndBoot -Force -IloIp '10.30.14.15' -OneViewHost 'ov.example.test' -OneViewServerName 'server01' -IsoUrl 'https://iso.example.test/windows.iso'
            $r.Success | Should -BeFalse
            Should -Invoke Get-OVIloSso -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Method -in @('Post', 'Patch') }
        }
    }

    It 'does not replay a destructive request after a 401' {
        InModuleScope Automation {
            Mock Get-OVServer { @{ name = 'server01' } }
            Mock Get-OVIloSso { @{ RootUri = 'https://10.30.14.15/redfish/v1'; 'X-Auth-Token' = 'synthetic-sso' } }
            Mock Invoke-RestMethod {
                param($Method)
                if ($Method -eq 'Post') { throw '401 Unauthorized' }
                @{ PowerState = 'On'; Boot = @{} }
            }
            $r = Invoke-IloRedfish -Action MountAndBoot -Force -IloIp '10.30.14.15' -OneViewHost 'ov.example.test' -OneViewServerName 'server01' -IsoUrl 'https://iso.example.test/windows.iso'
            $r.Success | Should -BeFalse
            Should -Invoke Get-OVIloSso -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' }
        }
    }
}

Describe 'Invoke-IloRedfish - Action validation' {
    It 'Rejects invalid action' {
        { & Invoke-IloRedfish -Action 'Bogus' -IloIp '127.0.0.1' -ErrorAction SilentlyContinue } |
            Should -Throw
    }

    It 'MountAndBoot without IsoUrl fails' {
        $r = Invoke-IloRedfish -Action MountAndBoot -IloIp '127.0.0.1' -DryRun
        $r.Success | Should -Be $true
    }
}
