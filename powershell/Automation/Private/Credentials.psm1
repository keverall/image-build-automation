#
# Credentials.psm1 — Env-var backed credential helpers.
# Mirrors Python utils/credentials.py.
#

function Get-EnvCredential {
    <#
    .SYNOPSIS
        Retrieve a credential string from an environment variable.

    .PARAMETER EnvVarName
        Environment variable name to look up.

    .PARAMETER Default
        Default returned when the variable is not set (default: empty string).

    .PARAMETER Required
        Throw when the variable is absent and no Default is provided.

    .EXAMPLE
        $token = Get-EnvCredential 'OPSRAMP_TOKEN' -Required
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $EnvVarName,
        [string] $Default  = '',
        [switch] $Required
    )
    $val = [System.Environment]::GetEnvironmentVariable($EnvVarName)
    if ([string]::IsNullOrEmpty($val)) {
        if ($Required) { throw "Required environment variable '$EnvVarName' is not set." }
        return $Default
    }
    return $val
}

function Get-IloCredentials {
    <#
    .SYNOPSIS
        Return iLO username and password from environment variables.
    #>
    [CmdletBinding()]
    param(
        [string] $UsernameEnv     = 'ILO_USER',
        [string] $PasswordEnv     = 'ILO_PASSWORD',
        [string] $DefaultUsername = 'Administrator',
        [string] $DefaultPassword = ''
    )
    return (Get-EnvCredential $UsernameEnv -Default $DefaultUsername),
           (Get-EnvCredential $PasswordEnv -Default $DefaultPassword)
}

function Get-ScomCredentials {
    <#
    .SYNOPSIS
        Return SCOM admin username and password (from env vars, required).
    #>
    [CmdletBinding()]
    param(
        [string] $UsernameEnv = 'SCOM_ADMIN_USER',
        [string] $PasswordEnv = 'SCOM_ADMIN_PASSWORD'
    )
    return (Get-EnvCredential $UsernameEnv -Required),
           (Get-EnvCredential $PasswordEnv -Required)
}

function Get-OpenViewCredentials {
    [CmdletBinding()]
    param(
        [string] $UserEnv = 'OPENVIEW_USER',
        [string] $PassEnv = 'OPENVIEW_PASSWORD'
    )
    return (Get-EnvCredential $UserEnv), (Get-EnvCredential $PassEnv)
}

function Get-SmtpCredentials {
    [CmdletBinding()]
    param(
        [string] $UserEnv = 'SMTP_USER',
        [string] $PassEnv = 'SMTP_PASSWORD'
    )
    return (Get-EnvCredential $UserEnv), (Get-EnvCredential $PassEnv)
}

# Backwards-compat alias used internally
Set-Alias -Name Get-CredentialSecret -Value Get-EnvCredential -Scope Global -ErrorAction SilentlyContinue

# vim: ts=4 sw=4 et
