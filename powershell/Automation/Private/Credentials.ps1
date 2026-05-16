#
# Private/Credentials.ps1 — Env-var credential helpers with CyberArk CCP fallback.
# Mirrors Python utils/credentials.py.
#
# Resolution order (every credential function follows this):
#   1. Environment variable               (Jenkins pre-fetches from CyberArk and sets these)
#   2. CyberArk Central Credential Provider CLI  (ark_ccl / ark_cc on PATH)
#   3. CyberArk AIM Web Service REST API  ($env:AIM_WEBSERVICE_URL or $env:CYBERARK_CCP_URL)
#   4. Safe default                       (empty string or low-privilege default so secrets don't leak)
#
# CyberArk safe / object naming convention:
#   Safe    — logical grouping, e.g. "HPE-iLO", "SCOM-2015", "OpenView", "SMTP-Mail"
#   Object  — same as the env-var name, e.g. "ILO_USER", "SCOM_ADMIN_PASSWORD"
#   AppID   — "jenkins"  (or set via $env:CYBERARK_APP_ID)
#

function _Resolve-Credential {
    <#
    .SYNOPSIS
        Core credential resolver: env var → CyberArk CLI → REST → default.
        PowerShell equivalent of Python utils/credentials._resolve().

    .PARAMETER EnvVarName
        Environment variable to check first.
    .PARAMETER SafeName
        CyberArk safe name for CCP look-up.
    .PARAMETER ObjectName
        CyberArk object name (normally = EnvVarName).
    .PARAMETER Default
        Fallback value when env var and CyberArk are both absent.
    .PARAMETER Required
        Throw when resolution fails entirely.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $EnvVarName,
        [Parameter(Mandatory)][string] $SafeName,
        [Parameter(Mandatory)][string] $ObjectName,
        [string] $Default  = '',
        [switch] $Required
    )

    # ── Step 1: Environment variable (Jenkins / shell) ─────────────────────
    $val = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not [string]::IsNullOrEmpty($val)) {
        return $val
    }

    # ── Step 2: CyberArk CLI on PATH ─────────────────────────────────────────
    foreach ($cliName in @('ark_ccl','ark_cc','CyberArk.CLI')) {
        try {
            $cliPath = Get-Command $cliName -ErrorAction SilentlyContinue
            if (-not $cliPath) { continue }
            # Standard CCP getpassword argument syntax
            $args = @('getpassword',
                      "-pAppID=jenkins",
                      "-pSafe=$SafeName",
                      "-pObject=$ObjectName")
            $psi             = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName     = $cliPath.Source
            $psi.Arguments    = ($args -join ' ')
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            $done = $proc.WaitForExit(15000)
            if (-not $done) { try { $proc.Kill() } catch {} }
            $out  = $proc.StandardOutput.ReadToEnd().Trim()
            if ($proc.ExitCode -eq 0 -and $out) {
                $lines = $out -split "`n" | ForEach-Object { $_.Trim() }
                $user  = if ($lines.Count -ge 1) { $lines[0] } else { '' }
                $pwd   = if ($lines.Count -ge 2) { $lines[1] } else { '' }
                if ($user) {
                    # Cache into env var so subsequent look-ups in the same process are instant
                    if ($EnvVarName -match '_USER$|_ID$') {
                        [System.Environment]::SetEnvironmentVariable($EnvVarName, $user)
                        return $user
                    } else {
                        [System.Environment]::SetEnvironmentVariable($EnvVarName, $pwd)
                        return $pwd
                    }
                }
            }
        } catch { continue }
    }

    # ── Step 3: CyberArk AIM Web Service REST API ────────────────────────────
    # Env vars:  AIM_WEBSERVICE_URL  |  CYBERARK_CCP_URL
    # Default:   https://cyberark-ccp:443/AIMWebService/API/Accounts
    $aimUrl = [System.Environment]::GetEnvironmentVariable('AIM_WEBSERVICE_URL')
    if (-not $aimUrl) {
        $aimUrl = [System.Environment]::GetEnvironmentVariable('CYBERARK_CCP_URL')
    }
    if (-not $aimUrl) {
        $aimUrl = 'https://cyberark-ccp:443/AIMWebService/API/Accounts'
    }
    try {
        $queryEnc = [System.Uri]::EscapeDataString("Safe=$SafeName;Object=$ObjectName")
        $fullUrl  = "$aimUrl`?AppID=jenkins&Query=$queryEnc"
        $items    = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        $first    = if ($items -is [System.Array]) { $items[0] } else { $items }
        $cUser    = $first.UserName
        $cPwd     = $first.Content
        if ($cUser) {
            $cacheVal = if ($EnvVarName -match '_USER$|_ID$') { $cUser } else { $cPwd }
            [System.Environment]::SetEnvironmentVariable($EnvVarName, $cacheVal)
            return $cacheVal
        }
    } catch {
        logger.debug("CyberArk REST fetch failed: safe=$SafeName object=$ObjectName: %s",
                     $_.Exception.Message)
    }

    # ── Step 4: Safe default ─────────────────────────────────────────────────
    if ($Required) {
        throw "Required credential '$EnvVarName' not found in environment "
            + "or CyberArk (safe=$SafeName, object=$ObjectName)."
    }
    return $Default
}

function Get-EnvCredential {
    <#
    .SYNOPSIS
        Retrieve a credential string.  Env var → CyberArk → default.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $EnvVarName,
        [string] $Default  = '',
        [switch] $Required
    )
    return _Resolve-Credential -EnvVarName $EnvVarName `
                               -SafeName    'Jenkins' `
                               -ObjectName  $EnvVarName `
                               -Default     $Default `
                               -Required:$Required
}

function Get-IloCredentials {
    <#
    .SYNOPSIS
        Return iLO username and password.
        Env var: ILO_USER / ILO_PASSWORD → CyberArk safe HPE-iLO → default.
    #>
    [CmdletBinding()]
    param(
        [string] $UsernameEnv     = 'ILO_USER',
        [string] $PasswordEnv     = 'ILO_PASSWORD',
        [string] $DefaultUsername = 'Administrator',
        [string] $DefaultPassword = ''
    )
    return (_Resolve-Credential -EnvVarName $UsernameEnv -SafeName 'HPE-iLO'   -ObjectName $UsernameEnv -Default $DefaultUsername),
           (_Resolve-Credential -EnvVarName $PasswordEnv -SafeName 'HPE-iLO'   -ObjectName $PasswordEnv -Default $DefaultPassword)
}

function Get-ScomCredentials {
    <#
    .SYNOPSIS
        Return SCOM admin username + password.
        Env var: SCOM_ADMIN_USER / SCOM_ADMIN_PASSWORD → CyberArk safe SCOM-2015 → required-error.
    #>
    [CmdletBinding()]
    param(
        [string] $UsernameEnv = 'SCOM_ADMIN_USER',
        [string] $PasswordEnv = 'SCOM_ADMIN_PASSWORD'
    )
    return (_Resolve-Credential -EnvVarName $UsernameEnv -SafeName 'SCOM-2015' -ObjectName $UsernameEnv -Required),
           (_Resolve-Credential -EnvVarName $PasswordEnv -SafeName 'SCOM-2015' -ObjectName $PasswordEnv -Required)
}

function Get-OpenViewCredentials {
    [CmdletBinding()]
    param(
        [string] $UserEnv = 'OPENVIEW_USER',
        [string] $PassEnv = 'OPENVIEW_PASSWORD'
    )
    return (_Resolve-Credential -EnvVarName $UserEnv  -SafeName 'OpenView'  -ObjectName $UserEnv),
           (_Resolve-Credential -EnvVarName $PassEnv  -SafeName 'OpenView'  -ObjectName $PassEnv)
}

function Get-SmtpCredentials {
    [CmdletBinding()]
    param(
        [string] $UserEnv = 'SMTP_USER',
        [string] $PassEnv = 'SMTP_PASSWORD'
    )
    return (_Resolve-Credential -EnvVarName $UserEnv -SafeName 'SMTP-Mail' -ObjectName $UserEnv -Default ''),
           (_Resolve-Credential -EnvVarName $PassEnv -SafeName 'SMTP-Mail'  -ObjectName $PassEnv -Default '')
}
