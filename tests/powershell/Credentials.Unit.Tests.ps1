# Credentials.Unit.Tests.ps1 — Full credential resolver test suite
#
# Covers _Resolve-Credential (env → CLI → REST → default) and every public
# credential getter for all four CyberArk fallback dimensions.

$Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
if (-not $env:TEMP)  { $env:TEMP  = '/tmp' }
if (-not $env:TMP)   { $env:TMP   = '/tmp' }

Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -ErrorAction Stop

BeforeAll {
    # Helper: save / restore env-vars around individual tests
    
    # Helper: save / restore env-vars around individual tests
    $script:_envSnapshot = @{}
    function Record-TestEnv {
        param([string[]]$Names)
        foreach ($n in $Names) {
            $script:_envSnapshot[$n] = [System.Environment]::GetEnvironmentVariable($n, 'Process')
        }
    }
    function Restore-TestEnv {
        param([string[]]$Names)
        foreach ($n in $Names) {
            $prev = $script:_envSnapshot[$n]
            if ($null -eq $prev) {
                [System.Environment]::SetEnvironmentVariable($n, $null, 'Process')
            } else {
                [System.Environment]::SetEnvironmentVariable($n, $prev, 'Process')
            }
        }
    }

    # Fake CLI directory for PATH detection tests
    $script:_fakeCliDir = Join-Path $env:TEMP "fake_cyberark_clis_$(New-Guid)"
    New-Item -ItemType Directory -Path $script:_fakeCliDir -Force | Out-Null
    New-Item -Path (Join-Path $script:_fakeCliDir 'ark_ccl') -ItemType File -Force | Out-Null
    New-Item -Path (Join-Path $script:_fakeCliDir 'ark_cc') -ItemType File -Force | Out-Null
    New-Item -Path (Join-Path $script:_fakeCliDir 'CyberArk.CLI') -ItemType File -Force | Out-Null
    $script:_originalPath = $env:PATH
    $env:PATH = "$script:_fakeCliDir;$env:PATH"
}

AfterAll {
    $env:PATH = $script:_originalPath
    Remove-Item -Recurse -Force -Path $script:_fakeCliDir -ErrorAction SilentlyContinue
}

# =============================================================================
# _Resolve-Credential — Private function tests (InModuleScope required)
# =============================================================================

Describe '_Resolve-Credential – Step 1: Environment variable fast path' {
    InModuleScope 'Automation' {
        It 'Returns the value from the environment variable when set' {
            [System.Environment]::SetEnvironmentVariable('_RES_ENV_FAST_', 'fast_value', 'Process')
            try {
                $result = _Resolve-Credential -EnvVarName '_RES_ENV_FAST_'
                $result | Should -Be 'fast_value'
            } finally {
                [System.Environment]::SetEnvironmentVariable('_RES_ENV_FAST_', $null, 'Process')
            }
        }

        It 'Returns the default when the env var is absent and not required' {
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_DFL_' -Default 'dflt' -Required:$false
            $result | Should -Be 'dflt'
        }

        It 'Returns an empty string when no env var, no default, and not required' {
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_NODFLT_' -Required:$false
            $result | Should -Be ''
        }

        It 'Returns an empty string when no env var, default is null, and not required' {
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_NULL_' -Default '' -Required:$false
            $result | Should -Be ''
        }

        It 'Throws when env var is missing and -Required is set' {
            { _Resolve-Credential -EnvVarName '_RES_MISSING_REQ_$$$' -Required } | Should -Throw
        }

        It 'Returns value when -Required is set and the env var exists' {
            [System.Environment]::SetEnvironmentVariable('_RES_REQ_BNR_', 'here', 'Process')
            try {
                $result = _Resolve-Credential -EnvVarName '_RES_REQ_BNR_' -Required -Default $null
                $result | Should -Be 'here'
            } finally {
                [System.Environment]::SetEnvironmentVariable('_RES_REQ_BNR_', $null, 'Process')
            }
        }
    }
}

Describe '_Resolve-Credential – Step 4: Default / Required fallback' {
    InModuleScope 'Automation' {
        BeforeEach {
            [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
            $env:PATH = (($env:PATH -split ';' | Where-Object {
                $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
            }) -join ';')
        }

        AfterEach {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }

        It 'Returns the Default value when all methods fail' {
            $result = _Resolve-Credential -EnvVarName '_ST4_DEF_' -Default 'step4_def' -Required:$false
            $result | Should -Be 'step4_def'
        }

        It 'Returns empty string default when no Default specified' {
            $result = _Resolve-Credential -EnvVarName '_ST4_ED_' -Required:$false
            $result | Should -Be ''
        }

        It 'Throws when -Required and every method has failed' {
            { _Resolve-Credential -EnvVarName '_ST4_REQ_$$$' -Required } | Should -Throw
        }
    }
}

# =============================================================================
# Get-EnvCredential — generic getter
# =============================================================================

Describe 'Get-EnvCredential' {
    It 'Returns the env var value when set' {
        [System.Environment]::SetEnvironmentVariable('_GEN_UTILS_CRED_', 'genval', 'Process')
        try { Get-EnvCredential -EnvVarName '_GEN_UTILS_CRED_' | Should -Be 'genval' }
        finally { [System.Environment]::SetEnvironmentVariable('_GEN_UTILS_CRED_', $null, 'Process') }
    }

    It 'Returns default when env absent and not required' {
        Get-EnvCredential -EnvVarName '_GEN_ABSENT_' -Default 'gen_dflt' -Required:$false | Should -Be 'gen_dflt'
    }

    It 'Throws when required and env absent' {
        { Get-EnvCredential -EnvVarName '_GEN_ABSENT_REQ_$$$' -Required } | Should -Throw
    }
}

# =============================================================================
# Get-IloCredentials — iLO credential getter
# =============================================================================

Describe 'Get-IloCredentials' {
    It 'Returns (Administrator, empty) when no env is set and all CLIs/REST fail' {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        $cred = Get-IloCredentials
        $cred[0] | Should -Be 'Administrator'
        $cred[1] | Should -Be ''
    }

    It 'Returns env values when ILO_USER / ILO_PASSWORD are present in the environment' {
        [System.Environment]::SetEnvironmentVariable('ILO_USER', 'ilo_admin', 'Process')
        [System.Environment]::SetEnvironmentVariable('ILO_PASSWORD', 'ilo_secret', 'Process')
        try {
            $cred = Get-IloCredentials
            $cred[0] | Should -Be 'ilo_admin'
            $cred[1] | Should -Be 'ilo_secret'
        } finally {
            [System.Environment]::SetEnvironmentVariable('ILO_USER', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('ILO_PASSWORD', $null, 'Process')
        }
    }
}

# =============================================================================
# Get-ScomCredentials — SCOM credential getter
# =============================================================================

Describe 'Get-ScomCredentials' {
    It 'Throws when env absent and CyberArk fails (required path)' {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try {
            { Get-ScomCredentials } | Should -Throw
        } finally {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }

    It 'Returns env values when SCOM_ADMIN_USER / SCOM_ADMIN_PASSWORD are set' {
        [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_USER', 'scom_admin', 'Process')
        [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_PASSWORD', 'scom_pw', 'Process')
        try {
            $cred = Get-ScomCredentials
            $cred[0] | Should -Be 'scom_admin'
            $cred[1] | Should -Be 'scom_pw'
        } finally {
            [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_USER', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_PASSWORD', $null, 'Process')
        }
    }
}

# =============================================================================
# Get-OpenViewCredentials — OpenView credential getter
# =============================================================================

Describe 'Get-OpenViewCredentials' {
    It 'Returns (empty, empty) when env and CyberArk are absent' {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try { 
            $c = Get-OpenViewCredentials
            $c[0] | Should -Be ''
            $c[1] | Should -Be ''
        }
        finally { $env:PATH = "$script:_fakeCliDir;$script:_originalPath" }
    }

    It 'Returns env values when OPENVIEW_USER / OPENVIEW_PASSWORD are set' {
        [System.Environment]::SetEnvironmentVariable('OPENVIEW_USER', 'ov_u', 'Process')
        [System.Environment]::SetEnvironmentVariable('OPENVIEW_PASSWORD', 'ov_p', 'Process')
        try {
            $c = Get-OpenViewCredentials
            $c[0] | Should -Be 'ov_u'
            $c[1] | Should -Be 'ov_p'
        } finally {
            [System.Environment]::SetEnvironmentVariable('OPENVIEW_USER', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('OPENVIEW_PASSWORD', $null, 'Process')
        }
    }
}

# =============================================================================
# Get-SmtpCredentials — SMTP credential getter
# =============================================================================

Describe 'Get-SmtpCredentials' {
    It 'Returns (empty, empty) when env and CyberArk are absent (default is empty string)' {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try {
            $c = Get-SmtpCredentials
            $c[0] | Should -Be ''
            $c[1] | Should -Be ''
        } finally {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }

    It 'Returns env values when SMTP_USER / SMTP_PASSWORD are set' {
        [System.Environment]::SetEnvironmentVariable('SMTP_USER', 'smtp_u', 'Process')
        [System.Environment]::SetEnvironmentVariable('SMTP_PASSWORD', 'smtp_p', 'Process')
        try {
            $c = Get-SmtpCredentials
            $c[0] | Should -Be 'smtp_u'
            $c[1] | Should -Be 'smtp_p'
        } finally {
            [System.Environment]::SetEnvironmentVariable('SMTP_USER', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('SMTP_PASSWORD', $null, 'Process')
        }
    }
}