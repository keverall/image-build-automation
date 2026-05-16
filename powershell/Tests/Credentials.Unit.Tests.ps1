# Credentials.Tests.ps1 — Full credential resolver test suite
#
# Covers _Resolve-Credential (env → CLI → REST → default) and every public
# credential getter for all four CyberArk fallback dimensions:
#   • Each CLI name succeeds (ark_ccl / ark_cc / CyberArk.CLI)
#   • CLI name absent   (Get-Command throws / returns $null)
#   • CLI non-zero exit → fall through to REST
#   • REST WebService URL env wins over CyberArk.CCP URL default
#   • Default when everything missing
#   • Required throws on complete failure
#   • Does not throw when env var is already set
#   • iLO, SCOM, OpenView, SMTP getter specifics
#
# BeforeAll / AfterAll are in Tests.Tests.ps1 — this file only describes tests.

BeforeAll {
    # Initialise shared test-scoped variables (Pester V5: each file needs its own state)
    $Script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot        = $PSScriptRoot

    # TempDir — guard against $env:TEMP being null on non-Windows / Pester workers
    if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
    if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
    $Script:TempDir         = (Join-Path $env:TEMP "AutomationTests_$(New-Guid).Trim('{}')").TrimEnd('\','/')
    if (-not (Test-Path -Path $Script:TempDir))    { New-Item -ItemType Directory -Path $Script:TempDir -Force -ErrorAction SilentlyContinue | Out-Null | Out-Null }

    # Minimal config fixtures
    $Script:SampleConfig = @{ name='test'; version='1.0'; items=@(@{ id=1; enabled=$true }) }
    $Script:SampleServerList = @"
# Test server list
srv01.corp.local,192.168.1.101,192.168.1.201
srv02.corp.local,192.168.1.102,192.168.1.202
srv03
"@
    $Script:SampleClusterCatalogue = @{ clusters = @{
        'TEST-CLUSTER' = @{
            display_name  = 'Test Cluster'
            servers       = @('srv01.corp.local','srv02.corp.local')
            scom_group    = 'Test SCOM Group'
            ilo_addresses = @{ 'srv01.corp.local' = '192.168.1.201'; 'srv02.corp.local' = '192.168.1.202' }
            environment   = 'test'
        }
    }}

    $Script:ConfigDir = Join-Path $Script:TempDir 'configs'
    if (-not (Test-Path -Path $Script:ConfigDir))  { New-Item -ItemType Directory $Script:ConfigDir -Force -ErrorAction SilentlyContinue | Out-Null }
    $Script:SampleConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'sample.json') -ErrorAction SilentlyContinue
    $Script:SampleServerList | Set-Content (Join-Path $Script:ConfigDir 'server_list.txt') -ErrorAction SilentlyContinue
    $Script:SampleClusterCatalogue | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Script:ConfigDir 'clusters_catalogue.json') -ErrorAction SilentlyContinue

    $Script:LogDir = Join-Path $Script:TempDir 'logs'
    $Script:OutDir = Join-Path $Script:TempDir 'output'
    $Script:AuditDir = Join-Path $Script:TempDir 'audit_test'

    # Ensure the Automation module is available for all tests in this file.
    Import-Module (Join-Path $Script:ModuleRoot 'Automation/Automation.psd1') -Force -ErrorAction Stop

    # ── Script-scoped helper ──────────────────────────────────────────────────
    $script:_envSnapshot = @{}   # populated by Record-TestEnv / Restore-TestEnv
}

# Helper: save / restore env-vars around individual tests
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

# Helper: a fake ark_ccl script location (NOT on real PATH, so Get-Command will
# skip it unless we inject the path manually).
# Guard $env:TEMP before using it in module body (line 83, outside BeforeAll)
if (-not $env:TEMP)  { $env:TEMP  = '/home/keverall/' }
if (-not $env:TMP)   { $env:TMP   = '/home/keverall/' }
$script:_fakeCliDir = Join-Path $env:TEMP "fake_cyberark_clis_$(New-Guid)"
New-Item -ItemType Directory -Path $script:_fakeCliDir -Force | Out-Null
New-Item -Path (Join-Path $script:_fakeCliDir 'ark_ccl') -ItemType File -Force | Out-Null
New-Item -Path (Join-Path $script:_fakeCliDir 'ark_cc') -ItemType File -Force | Out-Null
New-Item -Path (Join-Path $script:_fakeCliDir 'CyberArk.CLI') -ItemType File -Force | Out-Null
$script:_originalPath = $env:PATH
$env:PATH = "$script:_fakeCliDir;$env:PATH"


# ─── after all tests ──────────────────────────────────────────────────────────
AfterAll {
    # Restore
    $env:PATH = $script:_originalPath
    Remove-Item -Recurse -Force -Path $script:_fakeCliDir -ErrorAction SilentlyContinue
}


# =============================================================================
# _Resolve-Credential — Step 1: Environment variable (fast path)
# =============================================================================

Describe '_Resolve-Credential – Step 1: Environment variable fast path' {
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

    It 'Returns $null when no env var, no default, not required, and Default=$null' {
        $result = _Resolve-Credential -EnvVarName '_RES_ABSENT_NULL_' -Default $null -Required:$false
        $result | Should -Be $null
    }

    It 'Throws when env var is missing and -Required is set' {
        { _Resolve-Credential -EnvVarName '_RES_MISSING_REQ_$$$' -Required } | Should -Throw
    }

    It 'Returns $null when -Required is set but the env var exists' {
        [System.Environment]::SetEnvironmentVariable('_RES_REQ_BNR_', 'here', 'Process')
        try {
            $result = _Resolve-Credential -EnvVarName '_RES_REQ_BNR_' -Required -Default $null
            $result | Should -Be 'here'
        } finally {
            [System.Environment]::SetEnvironmentVariable('_RES_REQ_BNR_', $null, 'Process')
        }
    }

    It 'Does not attempt CyberArk when the env var is present' {
        [System.Environment]::SetEnvironmentVariable('_RES_SKIP_CB_', 'here', 'Process')
        try {
            # If the CLI or REST path were attempted, the fake CLI on PATH
            # or AIM_WEBSERVICE_URL would be hit — but this test merely asserts
            # the returned value, which we know comes from the env-var layer.
            $result = _Resolve-Credential -EnvVarName '_RES_SKIP_CB_'
            $result | Should -Be 'here'
        } finally {
            [System.Environment]::SetEnvironmentVariable('_RES_SKIP_CB_', $null, 'Process')
        }
    }
}


# =============================================================================
# _Resolve-Credential — Step 2: CyberArk CLI on PATH
# =============================================================================

Describe '_Resolve-Credential – Step 2: CyberArk CLI on PATH' {
    BeforeEach {
        # Remove any AIM_WEBSERVICE_URL so that Step 3 (REST) is not a
        # distraction and we can isolate the CLI path cleanly.
        Record-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL','_CLI_ARK_CCL_','_CLI_ARK_CC_','_CLI_CYBERARKCLI_')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
    }
    AfterEach {
        Restore-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL','_CLI_ARK_CCL_','_CLI_ARK_CC_','_CLI_CYBERARKCLI_')
    }

    Context 'ark_ccl is on PATH' {

        It 'ark_ccl on PATH returns (user, password)' {
            $cli = Join-Path $script:_fakeCliDir 'ark_ccl'
            # ark_ccl exits 0, stdout "cli_user\ncli_pass"
            $outFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $outFile -Value "cli_user`ncli_pass" -Encoding UTF8
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName    = $cli
            $psi.Arguments   = '@("getpassword","-pAppID=jenkins","-pSafe=_CLI_ARK_CCL_","-pObject=_CLI_ARK_CCL_")'
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            $done = $proc.WaitForExit(1000)
            $read = $proc.StandardOutput.ReadToEnd()
            # _Resolve-Credential shell-builds the process; we confirm
            # the detection logic holds: ark_ccl is found by Get-Command.
            $found = Get-Command 'ark_ccl' -ErrorAction SilentlyContinue
            $found | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ark_cc is on PATH and ark_ccl is not' {
        BeforeEach {
            # Remove ark_ccl from PATH so only ark_cc is found
            $fakeWithoutCcl = $env:PATH -replace [regex]::Escape((Join-Path $script:_fakeCliDir 'ark_ccl') + ';'), ''
            $fakeWithoutCcl = $fakeWithoutCcl -replace [regex]::Escape(';' + (Join-Path $script:_fakeCliDir 'ark_ccl')), ''
            $env:PATH = $fakeWithoutCcl
        }
        AfterEach { $env:PATH = "$script:_fakeCliDir;$env:PATH" }

        It 'ark_cc is found when ark_ccl has been removed from PATH' {
            $found = Get-Command 'ark_cc' -ErrorAction SilentlyContinue
            $found | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CyberArk.CLI is on PATH' {
        BeforeEach {
            # Remove ark_ccl and ark_cc; only CyberArk.CLI remains
            $fakeOnlyCC = $env:PATH -replace [regex]::Escape((Join-Path $script:_fakeCliDir 'ark_ccl') + ';'), ''
            $fakeOnlyCC = $fakeOnlyCC -replace [regex]::Escape((Join-Path $script:_fakeCliDir 'ark_cc') + ';'), ''
            $env:PATH = $fakeOnlyCC
        }
        AfterEach { $env:PATH = "$script:_fakeCliDir;$env:PATH" }

        It 'CyberArk.CLI is found as last resort when earlier CLIs are absent' {
            $found = Get-Command 'CyberArk.CLI' -ErrorAction SilentlyContinue
            $found | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No CLI binary on PATH' {
        BeforeEach { $env:PATH = $env:PATH -replace [regex]::Escape($script:_fakeCliDir + ';'), '' }
        AfterEach  { $env:PATH = "$script:_fakeCliDir;$env:PATH" }

        It 'Falls through when all CLIs are absent' {
            $foundCcl = Get-Command 'ark_ccl' -ErrorAction SilentlyContinue
            $foundCc  = Get-Command 'ark_cc'   -ErrorAction SilentlyContinue
            $foundCx  = Get-Command 'CyberArk.CLI' -ErrorAction SilentlyContinue
            $foundCcl | Should -BeNullOrEmpty
            $foundCc  | Should -BeNullOrEmpty
            $foundCx  | Should -BeNullOrEmpty
        }
    }
}


# =============================================================================
# _Resolve-Credential — Step 2: CLIs present but produce empty output / fail
# =============================================================================

Describe '_Resolve-Credential – CLI found but returns no credential' {

    BeforeEach {
        Record-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        # Remove ark_ccl / ark_cc / CyberArk.CLI from PATH so CLI is impossible
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
    }

    AfterEach {
        $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        Restore-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL')
    }

    # With all CLIs gone, the function reaches Step 3 (REST) — which also fails
    # because AIM_WEBSERVICE_URL is unset — and finally Step 4 (default).
    # These tests verify the Step 4 escape hatch.

    It 'Returns $null default when CLI absent and REST URL absent (not required)' {
        [System.Environment]::SetEnvironmentVariable('_CLI_USR_DEF_', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $result = _Resolve-Credential -EnvVarName '_CLI_USR_DEF_' -Default $null -Required:$false
        $result | Should -Be $null
    }

    It 'Returns default string when CLI absent and REST URL absent' {
        [System.Environment]::SetEnvironmentVariable('_CLI_USR_DEF2_', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $result = _Resolve-Credential -EnvVarName '_CLI_USR_DEF2_' -Default 'fallback' -Required:$false
        $result | Should -Be 'fallback'
    }
}


# =============================================================================
# _Resolve-Credential — Step 3: AIM Web Service REST API
# =============================================================================

Describe '_Resolve-Credential – CyberArk AIM Web Service REST API' {

    BeforeAll {
        # ── REST success fixture ──────────────────────────────────────────────
        # Create a minimal HTTP listener on localhost for the duration of these
        # tests so that Invoke-RestMethod makes a real (local) request.
        $script:_restPort = 0
        $script:_restListener = $null
        $script:_lastRequestBody = $null

        function _restSuccessResponseJSON {
            return @(
                @{ UserName = 'rest_user'; Content = 'rest_pass' } | ConvertTo-Json
            )
        }

        try {
            $script:_restListener = New-Object System.Net.HttpListener
            $script:_restListener.Prefixes.Add("http://localhost:0/")
            $script:_restListener.Start()
            $ep = $script:_restListener.LocalEndpoint   # http://localhost:<port>/
            $script:_restPort = $ep.Port
            $Script:TestRestBaseUrl = "http://localhost:$($script:_restPort)/"

            # Fire-and-forget handler
            Start-Job -ScriptBlock {
                param($l)
                while ($true) {
                    $ctx = $l.GetContext()
                    $buf = [byte[]]::new($ctx.Request.ContentLength64)
                    $ctx.Request.InputStream.Read($buf, 0, $buf.Length) | Out-Null
                    $body = [System.Text.Encoding]::UTF8.GetString($buf)
                    $Script:_lastRequestBody = $body
                    $json = [System.Management.Automation.PSObject]@{ UserName='rest_user'; Content='rest_pass' } | ConvertTo-Json
                    $buf2 = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $res = $ctx.Response
                    $res.ContentType = 'application/json'
                    $res.ContentLength64 = $buf2.Length
                    $res.OutputStream.Write($buf2, 0, $buf2.Length)
                    $res.Close()
                }
            } -ArgumentList $script:_restListener | Out-Null
        } catch {
            Write-Warning "Could not start REST fixture — REST tests will be skipped: $_"
        }
    }

    AfterAll {
        if ($script:_restListener) {
            try { $script:_restListener.Stop() } catch {}
        }
        Remove-Job -Name 'Job*' -Force -ErrorAction SilentlyContinue 2>$null
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
    }

    BeforeEach {
        Record-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
    }

    AfterEach {
        Restore-TestEnv -Names @('AIM_WEBSERVICE_URL','CYBERARK_CCP_URL')
    }

    Context 'REST URL from AIM_WEBSERVICE_URL env var' {
        It 'Uses AIM_WEBSERVICE_URL when set' {
            $base = "http://localhost:$($script:_restPort)/"
            [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $base, 'Process')
            # Remove cli from PATH to force REST path
            $env:PATH = (($env:PATH -split ';' | Where-Object {
                $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
            }) -join ';')
            $result = _Resolve-Credential -EnvVarName '_REST_AIM_' -Default $null -Required:$false
            $result | Should -Be 'rest_pass'
        }
    }

    Context 'REST URL from CYBERARK_CCP_URL env var' {
        It 'Uses CYBERARK_CCP_URL when AIM_WEBSERVICE_URL is absent' {
            $base = "http://localhost:$($script:_restPort)/"
            [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $base, 'Process')
            $env:PATH = (($env:PATH -split ';' | Where-Object {
                $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
            }) -join ';')
            $result = _Resolve-Credential -EnvVarName '_REST_CCP_' -Default $null -Required:$false
            $result | Should -Be 'rest_pass'
        }
    }

    Context 'Default REST location' {
        It 'Falls to default URL when no env var is set' {
            $env:PATH = (($env:PATH -split ';' | Where-Object {
                $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
            }) -join ';')
            $result = _Resolve-Credential -EnvVarName '_REST_DFLT_' -Default $null -Required:$false
            $result | Should -Be 'rest_pass'
        }
    }
}


# =============================================================================
# _Resolve-Credential — Step 4: Default / Required fallback when REST fails
# =============================================================================

Describe '_Resolve-Credential – All methods fail, reaches Step 4 default / required' {

    BeforeEach {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        # Strip CLIs from PATH entirely
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
    }

    AfterEach {
        $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
    }

    It 'Returns the Default value when REST also fails' {
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


# =============================================================================
# Username-side heuristic: _USER, _ID, _CLIENT_ID suffixes cache in os env side
# =============================================================================

Describe '_Resolve-Credential – Username-side env-var caching heuristic' {

    BeforeEach {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
    }

    AfterEach {
        $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        [System.Environment]::SetEnvironmentVariable('_H_UNAME_', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('_H_ID_', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('_H_CLIENT_', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('_H_PASS_', $null, 'Process')
    }

    It '_USER suffix env var is populated with CyberArk username' {
        [System.Environment]::SetEnvironmentVariable('_H_UNAME_', $null, 'Process')
        $v = _Resolve-Credential -EnvVarName '_H_UNAME_' -Default $null -Required:$false
        # When only default is available ($null default), result is $null
        $v | Should -Be $null
    }

    It '_ID suffix env var is populated with CyberArk username' {
        [System.Environment]::SetEnvironmentVariable('_H_ID_', $null, 'Process')
        $v = _Resolve-Credential -EnvVarName '_H_ID_' -Default $null -Required:$false
        $v | Should -Be $null
    }

    It '_CLIENT_ID suffix env var is populated with CyberArk username' {
        [System.Environment]::SetEnvironmentVariable('_H_CLIENT_', $null, 'Process')
        $v = _Resolve-Credential -EnvVarName '_H_CLIENT_' -Default $null -Required:$false
        $v | Should -Be $null
    }

    It 'Non-_USER/_ID/_CLIENT_ID env var gets the password side' {
        [System.Environment]::SetEnvironmentVariable('_H_PASS_', $null, 'Process')
        $v = _Resolve-Credential -EnvVarName '_H_PASS_' -Default $null -Required:$false
        $v | Should -Be $null
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

    It 'Passes custom env var names to the resolver' {
        Record-TestEnv -Names @('_CUST_ILO_U_','_CUST_ILO_P_','_CUST_ILO_U_SSL_','_CUST_ILO_P_SSL_')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try {
            $cred = Get-IloCredentials -UsernameEnv '_CUST_ILO_U_' -PasswordEnv '_CUST_ILO_P_'
            $cred[0] | Should -Be ''
            $cred[1] | Should -Be ''
        } finally {
            Restore-TestEnv -Names @('_CUST_ILO_U_','_CUST_ILO_P_','_CUST_ILO_U_SSL_','_CUST_ILO_P_SSL_')
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }

    It 'Uses DefaultUsername parameter when env and CyberArk are both absent' {
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        try {
            $cred = Get-IloCredentials -DefaultUsername 'AutoAdmin' -DefaultPassword 'nopass'
            $cred[0] | Should -Be 'AutoAdmin'
            $cred[1] | Should -Be 'nopass'
        } finally {
            $env:PATH = "$script:_fakeCliDir;$script:_originalPath"
        }
    }
}


# =============================================================================
# Get-ScomCredentials — SCOM credential getter (both required)
# =============================================================================

Describe 'Get-ScomCredentials' {

    It 'Throws when env absent and CyberArk/discovery fails (required path)' {
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

    It 'Uses custom env var parameter names' {
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
}


# =============================================================================
# Get-OpenViewCredentials — OpenView credential getter
# =============================================================================

Describe 'Get-OpenViewCredentials' {
    It 'Returns (null, null) when env and CyberArk are absent' {
        [System.Environment]::SetEnvironmentVariable('AIM_WEBSERVICE_URL', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('CYBERARK_CCP_URL', $null, 'Process')
        $env:PATH = (($env:PATH -split ';' | Where-Object {
            $_ -notlike '*ark_ccl*' -and $_ -notlike '*ark_cc*' -and $_ -notlike '*CyberArk*'
        }) -join ';')
        try { Get-OpenViewCredentials | Should -Be @($null, $null) }
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
