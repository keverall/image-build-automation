# Credentials.Unit.Tests.ps1 — Full credential resolver test suite
#
# Enhanced test output features:
# - Test descriptions include command args and parameters
# - Colored output: Purple for successful responses, Red for failures
# - Detailed response information showing what was returned
#
# Covers _Resolve-Credential (env → CLI → REST → default) and every public
# credential getter for all four CyberArk fallback dimensions.

$Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
if (-not $env:TEMP)  { $env:TEMP  = '/tmp' }
if (-not $env:TMP)   { $env:TMP   = '/tmp' }

# Import test output helper for colored/detailed output
Import-Module (Join-Path $PSScriptRoot 'TestOutputHelper.psm1') -Force -ErrorAction SilentlyContinue

Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

BeforeAll {
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
        It 'Returns value from env var when set [EnvVarName=_RES_ENV_FAST_, Value=fast_value]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_ENV_FAST_' }
            
            [System.Environment]::SetEnvironmentVariable('_RES_ENV_FAST_', 'fast_value', 'Process')
            try {
                $result = _Resolve-Credential -EnvVarName '_RES_ENV_FAST_'
                
                Write-TestResponse -Success ($result -eq 'fast_value') -ExpectedSuccess $true `
                    -Message "Returned: '$result'" -Details @{ ExpectedValue = 'fast_value'; ActualValue = $result }
                $result | Should -Be 'fast_value'
            } finally {
                [System.Environment]::SetEnvironmentVariable('_RES_ENV_FAST_', $null, 'Process')
            }
        }

        It 'Returns default when env var absent and not required [EnvVarName=_RES_ABSENT_DFL_, Default=dflt]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_ABSENT_DFL_'; Default = 'dflt'; Required = $false }
            
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_DFL_' -Default 'dflt' -Required:$false
            
            Write-TestResponse -Success ($result -eq 'dflt') -ExpectedSuccess $true `
                -Message "Returned default: '$result'" -Details @{ DefaultValue = 'dflt'; ActualValue = $result }
            $result | Should -Be 'dflt'
        }

        It 'Returns empty string when no env var, no default, not required [EnvVarName=_RES_ABSENT_NODFLT_]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_ABSENT_NODFLT_'; Required = $false }
            
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_NODFLT_' -Required:$false
            
            Write-TestResponse -Success ($result -eq '') -ExpectedSuccess $true `
                -Message "Returned empty string as expected" -Details @{ ActualValue = "'$result'" }
            $result | Should -Be ''
        }

        It 'Returns empty string when no env var, default is null, not required [Default=""]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_ABSENT_NULL_'; Default = ''; Required = $false }
            
            $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_NULL_' -Default '' -Required:$false
            
            Write-TestResponse -Success ($result -eq '') -ExpectedSuccess $true `
                -Message "Returned empty string for null default" -Details @{ ActualValue = "'$result'" }
            $result | Should -Be ''
        }

        It 'Throws when env var missing and -Required is set [EnvVarName=_RES_MISSING_REQ_, Required=$true]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_MISSING_REQ_$$$'; Required = $true }
            
            { _Resolve-Credential -EnvVarName '_RES_MISSING_REQ_$$$' -Required } | Should -Throw
            
            Write-TestResponse -Success $true -ExpectedSuccess $true `
                -Message "Correctly threw exception for missing required env var"
        }

        It 'Returns value when -Required and env var exists [EnvVarName=_RES_REQ_BNR_, Value=here]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_RES_REQ_BNR_'; Required = $true }
            
            [System.Environment]::SetEnvironmentVariable('_RES_REQ_BNR_', 'here', 'Process')
            try {
                $result = _Resolve-Credential -EnvVarName '_RES_REQ_BNR_' -Required -Default $null
                
                Write-TestResponse -Success ($result -eq 'here') -ExpectedSuccess $true `
                    -Message "Returned: '$result'" -Details @{ ExpectedValue = 'here'; ActualValue = $result }
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

        It 'Returns Default value when all methods fail [EnvVarName=_ST4_DEF_, Default=step4_def]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_ST4_DEF_'; Default = 'step4_def'; Required = $false }
            
            $result = _Resolve-Credential -EnvVarName '_ST4_DEF_' -Default 'step4_def' -Required:$false
            
            Write-TestResponse -Success ($result -eq 'step4_def') -ExpectedSuccess $true `
                -Message "Returned default after all methods failed: '$result'" -Details @{ DefaultValue = 'step4_def'; ActualValue = $result }
            $result | Should -Be 'step4_def'
        }

        It 'Returns empty string default when no Default specified [EnvVarName=_ST4_ED_]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_ST4_ED_'; Required = $false }
            
            $result = _Resolve-Credential -EnvVarName '_ST4_ED_' -Required:$false
            
            Write-TestResponse -Success ($result -eq '') -ExpectedSuccess $true `
                -Message "Returned empty string when no default specified" -Details @{ ActualValue = "'$result'" }
            $result | Should -Be ''
        }

        It 'Throws when -Required and every method has failed [EnvVarName=_ST4_REQ_, Required=$true]' {
            Write-TestCommand -Command "_Resolve-Credential" -Params @{ EnvVarName = '_ST4_REQ_$$$'; Required = $true }
            
            { _Resolve-Credential -EnvVarName '_ST4_REQ_$$$' -Required } | Should -Throw
            
            Write-TestResponse -Success $true -ExpectedSuccess $true `
                -Message "Correctly threw exception when required and all methods failed"
        }
    }
}

# =============================================================================
# Get-EnvCredential — generic getter
# =============================================================================

Describe 'Get-EnvCredential' {
    It 'Returns env var value when set [EnvVarName=_GEN_UTILS_CRED_, Value=genval]' {
        Write-TestCommand -Command "Get-EnvCredential" -Params @{ EnvVarName = '_GEN_UTILS_CRED_' }
        
        [System.Environment]::SetEnvironmentVariable('_GEN_UTILS_CRED_', 'genval', 'Process')
        try { 
            $result = Get-EnvCredential -EnvVarName '_GEN_UTILS_CRED_'
            
            Write-TestResponse -Success ($result -eq 'genval') -ExpectedSuccess $true `
                -Message "Returned: '$result'" -Details @{ ExpectedValue = 'genval'; ActualValue = $result }
            $result | Should -Be 'genval' 
        }
        finally { [System.Environment]::SetEnvironmentVariable('_GEN_UTILS_CRED_', $null, 'Process') }
    }

    It 'Returns default when env absent and not required [EnvVarName=_GEN_ABSENT_, Default=gen_dflt]' {
        Write-TestCommand -Command "Get-EnvCredential" -Params @{ EnvVarName = '_GEN_ABSENT_'; Default = 'gen_dflt'; Required = $false }
        
        $result = Get-EnvCredential -EnvVarName '_GEN_ABSENT_' -Default 'gen_dflt' -Required:$false
        
        Write-TestResponse -Success ($result -eq 'gen_dflt') -ExpectedSuccess $true `
            -Message "Returned default: '$result'" -Details @{ DefaultValue = 'gen_dflt'; ActualValue = $result }
        $result | Should -Be 'gen_dflt'
    }

    It 'Throws when required and env absent [EnvVarName=_GEN_ABSENT_REQ_, Required=$true]' {
        Write-TestCommand -Command "Get-EnvCredential" -Params @{ EnvVarName = '_GEN_ABSENT_REQ_$$$'; Required = $true }
        
        { Get-EnvCredential -EnvVarName '_GEN_ABSENT_REQ_$$$' -Required } | Should -Throw
        
        Write-TestResponse -Success $true -ExpectedSuccess $true `
            -Message "Correctly threw exception for missing required credential"
    }
}

# =============================================================================
# Get-IloCredentials — iLO credential getter
# =============================================================================

Describe 'Get-IloCredentials' {
    It 'Returns (Administrator, empty) when no env set and CLIs/REST fail [No env vars]' {
        Write-TestCommand -Command "Get-IloCredentials" -Params @{}
        
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        
        $cred = Get-IloCredentials
        
        $success = ($cred[0] -eq 'Administrator') -and ($cred[1] -eq '')
        Write-TestResponse -Success $success -ExpectedSuccess $true `
            -Message "Returned default credentials" -Details @{ Username = $cred[0]; Password = "'$($cred[1])'" }
        $cred[0] | Should -Be 'Administrator'
        $cred[1] | Should -Be ''
    }

    It 'Returns env values when ILO_USER/ILO_PASSWORD present [ILO_USER=ilo_admin]' {
        Write-TestCommand -Command "Get-IloCredentials" -Params @{ ILO_USER = 'ilo_admin'; ILO_PASSWORD = '***' }
        
        [System.Environment]::SetEnvironmentVariable('ILO_USER', 'ilo_admin', 'Process')
        [System.Environment]::SetEnvironmentVariable('ILO_PASSWORD', 'ilo_secret', 'Process')
        try {
            $cred = Get-IloCredentials
            
            $success = ($cred[0] -eq 'ilo_admin') -and ($cred[1] -eq 'ilo_secret')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned env credentials" -Details @{ Username = $cred[0]; Password = '***' }
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
    It 'Throws when env absent and CyberArk fails (required path) [No env vars, Required]' {
        Write-TestCommand -Command "Get-ScomCredentials" -Params @{ Mode = 'required' }
        
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try {
            { Get-ScomCredentials } | Should -Throw
            
            Write-TestResponse -Success $true -ExpectedSuccess $true `
                -Message "Correctly threw exception when SCOM credentials unavailable"
        } finally {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }

    It 'Returns env values when SCOM_ADMIN_USER/PASSWORD set [SCOM_ADMIN_USER=scom_admin]' {
        Write-TestCommand -Command "Get-ScomCredentials" -Params @{ SCOM_ADMIN_USER = 'scom_admin' }
        
        [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_USER', 'scom_admin', 'Process')
        [System.Environment]::SetEnvironmentVariable('SCOM_ADMIN_PASSWORD', 'scom_pw', 'Process')
        try {
            $cred = Get-ScomCredentials
            
            $success = ($cred[0] -eq 'scom_admin') -and ($cred[1] -eq 'scom_pw')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned env credentials" -Details @{ Username = $cred[0]; Password = '***' }
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
    It 'Returns (empty, empty) when env and CyberArk absent [No env vars]' {
        Write-TestCommand -Command "Get-OpenViewCredentials" -Params @{}
        
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try { 
            $c = Get-OpenViewCredentials
            
            $success = ($c[0] -eq '') -and ($c[1] -eq '')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned empty credentials as expected" -Details @{ Username = "'$($c[0])'"; Password = "'$($c[1])'" }
            $c[0] | Should -Be ''
            $c[1] | Should -Be ''
        }
        finally { $env:PATH = "$script:_fakeCliDir;$script:_originalPath" }
    }

    It 'Returns env values when OPENVIEW_USER/PASSWORD set [OPENVIEW_USER=ov_u]' {
        Write-TestCommand -Command "Get-OpenViewCredentials" -Params @{ OPENVIEW_USER = 'ov_u' }
        
        [System.Environment]::SetEnvironmentVariable('OPENVIEW_USER', 'ov_u', 'Process')
        [System.Environment]::SetEnvironmentVariable('OPENVIEW_PASSWORD', 'ov_p', 'Process')
        try {
            $c = Get-OpenViewCredentials
            
            $success = ($c[0] -eq 'ov_u') -and ($c[1] -eq 'ov_p')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned env credentials" -Details @{ Username = $c[0]; Password = '***' }
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
    It 'Returns (empty, empty) when env and CyberArk absent [No env vars, Default=empty]' {
        Write-TestCommand -Command "Get-SmtpCredentials" -Params @{}
        
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try {
            $c = Get-SmtpCredentials
            
            $success = ($c[0] -eq '') -and ($c[1] -eq '')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned empty credentials (default)" -Details @{ Username = "'$($c[0])'"; Password = "'$($c[1])'" }
            $c[0] | Should -Be ''
            $c[1] | Should -Be ''
        } finally {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }

    It 'Returns env values when SMTP_USER/PASSWORD set [SMTP_USER=smtp_u]' {
        Write-TestCommand -Command "Get-SmtpCredentials" -Params @{ SMTP_USER = 'smtp_u' }
        
        [System.Environment]::SetEnvironmentVariable('SMTP_USER', 'smtp_u', 'Process')
        [System.Environment]::SetEnvironmentVariable('SMTP_PASSWORD', 'smtp_p', 'Process')
        try {
            $c = Get-SmtpCredentials
            
            $success = ($c[0] -eq 'smtp_u') -and ($c[1] -eq 'smtp_p')
            Write-TestResponse -Success $success -ExpectedSuccess $true `
                -Message "Returned env credentials" -Details @{ Username = $c[0]; Password = '***' }
            $c[0] | Should -Be 'smtp_u'
            $c[1] | Should -Be 'smtp_p'
        } finally {
            [System.Environment]::SetEnvironmentVariable('SMTP_USER', $null, 'Process')
            [System.Environment]::SetEnvironmentVariable('SMTP_PASSWORD', $null, 'Process')
        }
    }
}
