# Regression coverage for OneView-issued iLO SSO token compatibility.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'src/powershell/Automation/Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
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
            $script:headersSeen | Should -Be @('abc123|sessionKey=abc123', 'sessionKey=abc123|sessionKey=abc123')
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly
        }
    }
}
