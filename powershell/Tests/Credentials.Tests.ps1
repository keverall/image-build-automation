# Credentials.Tests.ps1 — Tests for Credentials.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Get-CredentialSecret' {
    It 'Returns environment variable value when set' {
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_CRED', 'mypassword', 'Process')
        $val = Get-CredentialSecret -EnvVarName '_TEST_PS_UTILS_CRED'
        $val | Should -Be 'mypassword'
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_CRED', $null, 'Process')
    }

    It 'Returns default value when env var not set and not required' {
        $val = Get-CredentialSecret -EnvVarName '_TEST_PS_UTILS_NONEXISTENT' -Default 'mypassword' -Required:$false
        $val | Should -Be 'mypassword'
    }

    It 'Throws when env var missing and required' {
        { Get-CredentialSecret -EnvVarName '_TEST_PS_UTILS_NONEXISTENT_REQ_$$$' -Required:$true } | Should -Throw
    }
}

Describe 'get_ilo_credentials / Get-IloCredentials' {
    It 'Returns defaults when env vars are absent' {
        $uCred = Get-IloCredentials
        $uCred[0] | Should -Be 'Administrator'
        $uCred[1] | Should -Be ''
    }

    It 'Respects env var overrides' {
        [System.Environment]::SetEnvironmentVariable('ILO_USER', 'iloadmin', 'Process')
        [System.Environment]::SetEnvironmentVariable('ILO_PASSWORD', 'ilopass', 'Process')
        $uCred = Get-IloCredentials
        $uCred[0] | Should -Be 'iloadmin'
        $uCred[1] | Should -Be 'ilopass'
        [System.Environment]::SetEnvironmentVariable('ILO_USER', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('ILO_PASSWORD', $null, 'Process')
    }
}

Describe 'get_scom_credentials / Get-ScomCredentials' {
    It 'Returns empty strings for absent env vars (not required)' {
        $uCred = Get-ScomCredentials -UsernameEnv '_TEST_PS_UTILS_NONEXISTENT_SCOM1_$$$' `
                                      -PasswordEnv '_TEST_PS_UTILS_NONEXISTENT_SCOM2_$$$'
        $uCred[0] | Should -Be ''
        $uCred[1] | Should -Be ''
    }
}
