# Regression coverage for OneView-issued iLO SSO token compatibility.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'IloRedfishSession - direct iLO 5 sessions' {
    It 'uses the header token for reads, writes and logout with a <Location> location' -ForEach @(
        @{ Location = '/redfish/v1/SessionService/Sessions/42/'; HeaderArray = $false }
        @{ Location = 'https://10.30.14.15/redfish/v1/SessionService/Sessions/42/'; HeaderArray = $true }
    ) {
        InModuleScope Automation -Parameters @{ Location = $Location; HeaderArray = $HeaderArray } {
            param($Location, $HeaderArray)
            $script:directToken = [guid]::NewGuid().ToString('N')
            $script:sessionLocation = $Location
            $script:headerArray = $HeaderArray
            Mock Invoke-WebRequest {
                param($Body)
                $payload = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
                $payload.UserName | Should -Be 'DOMAIN\ilo-operator'
                $payload.Password | Should -Be 'synthetic-p@ss'
                @{ Headers = @{
                    'X-Auth-Token' = if ($script:headerArray) { @($script:directToken) } else { $script:directToken }
                    Location = if ($script:headerArray) { @($script:sessionLocation) } else { $script:sessionLocation }
                }; Content = '{"@odata.id":"/redfish/v1/SessionService/Sessions/42/"}' }
            }
            Mock Invoke-RestMethod {
                param($Headers)
                $Headers['X-Auth-Token'] | Should -Be $script:directToken
                $Headers.ContainsKey('X-Redfish-Session') | Should -BeFalse
                @{ PowerState = 'On'; Boot = @{} }
            }

            $session = [IloRedfishSession]::new('https://10.30.14.15/redfish/v1', 'DOMAIN\ilo-operator', 'synthetic-p@ss', $true, 30)
            $session.GetSystem().power_state | Should -Be 'On'
            $null = $session.InsertMedia(1, 'https://iso.example.test/windows.iso')
            $session.SetOneTimeBootCd()
            $session.ResetSystem('ForceRestart')
            $session.Logout()

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $Uri -eq 'https://10.30.14.15/redfish/v1/SessionService/Sessions/'
            }
            Should -Invoke Invoke-RestMethod -Times 5 -Exactly
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Delete' -and $Uri -eq 'https://10.30.14.15/redfish/v1/SessionService/Sessions/42/'
            }
            $session.AuthToken | Should -BeNullOrEmpty
            $session.SessionUri | Should -BeNullOrEmpty
        }
    }

    It 'renews a rejected token once and uses the new token and location thereafter' {
        InModuleScope Automation {
            $script:loginNumber = 0
            Mock Invoke-WebRequest {
                $script:loginNumber++
                @{ Headers = @{ 'X-Auth-Token' = "synthetic-session-$script:loginNumber"; Location = "/redfish/v1/SessionService/Sessions/$script:loginNumber/" } }
            }
            Mock Invoke-RestMethod {
                param($Headers)
                if ($Headers['X-Auth-Token'] -eq 'synthetic-session-1') { throw '401 Unauthorized' }
                $Headers['X-Auth-Token'] | Should -Be 'synthetic-session-2'
                @{ PowerState = 'On'; Boot = @{} }
            }
            $session = [IloRedfishSession]::new('https://10.30.14.15/redfish/v1', 'operator', 'synthetic-password', $true, 30)
            $session.GetSystem().power_state | Should -Be 'On'
            $null = $session.InsertMedia(1, 'https://iso.example.test/windows.iso')
            $session.Logout()

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Delete' -and $Uri -eq 'https://10.30.14.15/redfish/v1/SessionService/Sessions/2/'
            }
        }
    }

    It 'stops after a second 401 instead of retrying indefinitely' {
        InModuleScope Automation {
            Mock Invoke-WebRequest { @{ Headers = @{ 'X-Auth-Token' = 'synthetic-session'; Location = '/redfish/v1/SessionService/Sessions/42/' } } }
            Mock Invoke-RestMethod { throw '401 Unauthorized' }
            $session = [IloRedfishSession]::new('https://10.30.14.15/redfish/v1', 'operator', 'synthetic-password', $true, 30)
            { $session.GetSystem() } | Should -Throw '*401*'
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly
        }
    }

    It 'fails closed if login returns no token header' {
        InModuleScope Automation {
            Mock Invoke-WebRequest { @{ Headers = @{ Location = '/redfish/v1/SessionService/Sessions/42/' }; Content = '{}' } }
            Mock Invoke-RestMethod { throw 'authenticated calls must not run' }
            { [IloRedfishSession]::new('https://10.30.14.15/redfish/v1', 'operator', 'synthetic-password', $true, 30) } |
                Should -Throw '*did not return a Redfish session token*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }

    It 'rejects a session location outside the target iLO origin' {
        InModuleScope Automation {
            Mock Invoke-WebRequest { @{ Headers = @{ 'X-Auth-Token' = 'synthetic-session'; Location = 'https://other.example.test/session/42/' } } }
            Mock Invoke-RestMethod { throw 'token must not be sent' }
            { [IloRedfishSession]::new('https://10.30.14.15/redfish/v1', 'operator', 'synthetic-password', $true, 30) } |
                Should -Throw '*outside the target iLO origin*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }
}

Describe 'IloRedfishSession - OneView SSO token compatibility' {
    It 'retries a 401 with the original sessionKey token form' {
        InModuleScope Automation {
            $script:headersSeen = @()
            Mock Invoke-RestMethod {
                param($Headers)
                $script:headersSeen += "$($Headers['X-Auth-Token'])|$($Headers['X-Redfish-Session'])"
                if ($Headers['X-Auth-Token'] -eq 'abc123') {
                    throw 'Response status code does not indicate success: 401 (Unauthorized).'
                }
                [pscustomobject]@{
                    PowerState = 'On'
                    Boot = @{ BootSourceOverrideTarget = 'None'; BootSourceOverrideEnabled = 'Disabled' }
                    Manufacturer = 'HPE'
                    Model = 'DL360'
                    SerialNumber = 'CZ22420JCM'
                }
            }

            $session = [IloRedfishSession]::new(
                [pscustomobject]@{
                    RootUri = 'https://10.30.14.15/redfish/v1'
                    'X-Auth-Token' = 'sessionKey=abc123'
                },
                $true,
                30)

            $result = $session.GetSystem()

            $result.power_state | Should -Be 'On'
            $script:headersSeen | Should -Be @(
                'abc123|sessionKey=abc123'
                'abc123|sessionKey=abc123'
                'sessionKey=abc123|sessionKey=abc123'
            )
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        }
    }

    It 'accepts the SecurityToken property used by current HPE SSO objects' {
        InModuleScope Automation {
            # Generate a synthetic token instead of embedding a secret-shaped literal.
            $script:expectedSecurityToken = [guid]::NewGuid().ToString('N')
            Mock Invoke-RestMethod {
                param($Headers)
                if ($Headers['X-Auth-Token'] -ne $script:expectedSecurityToken) {
                    throw 'unexpected token property selection'
                }
                [pscustomobject]@{
                    PowerState = 'On'
                    Boot = @{ BootSourceOverrideTarget = 'None'; BootSourceOverrideEnabled = 'Disabled' }
                    Manufacturer = 'HPE'
                    Model = 'DL360'
                    SerialNumber = 'CZ22420JCM'
                }
            }

            $session = [IloRedfishSession]::new(
                [pscustomobject]@{
                    RootUri = 'https://10.30.14.15/redfish/v1'
                    SecurityToken = $script:expectedSecurityToken
                },
                $true,
                30)

            $result = $session.GetSystem()

            $result.power_state | Should -Be 'On'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }

    It 'tries the legacy REST root after a Redfish SSO 401' {
        InModuleScope Automation {
            $script:urisSeen = @()
            Mock Invoke-RestMethod {
                param($Uri)
                $script:urisSeen += $Uri
                if ($Uri -like '*/redfish/v1/*') {
                    throw 'Response status code does not indicate success: 401 (Unauthorized).'
                }
                [pscustomobject]@{
                    PowerState = 'On'
                    Boot = @{ BootSourceOverrideTarget = 'None'; BootSourceOverrideEnabled = 'Disabled' }
                    Manufacturer = 'HPE'
                    Model = 'DL360'
                    SerialNumber = 'CZ22420JCM'
                }
            }

            $session = [IloRedfishSession]::new(
                [pscustomobject]@{
                    RootUri = 'https://10.30.14.15/redfish/v1'
                    'X-Auth-Token' = 'token-123'
                },
                $true,
                30)

            $result = $session.GetSystem()

            $result.power_state | Should -Be 'On'
            $script:urisSeen | Should -Be @(
                'https://10.30.14.15/redfish/v1/Systems/1',
                'https://10.30.14.15/rest/v1/Systems/1'
            )
        }
    }
}
