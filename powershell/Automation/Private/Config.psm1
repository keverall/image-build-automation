#
# Config.psm1 — JSON/YAML configuration loading with ${VAR} env substitution.
#

function Import-JsonConfig {
    <#
    .SYNOPSIS
        Load a JSON file into a hashtable, optionally resolving ${VAR} env placeholders.

    .PARAMETER Path
        Path to the JSON config file.

    .PARAMETER Required
        Throw when file is missing if $true (default).

    .PARAMETER AutoEnvVarReplace
        Replace ${VAR} placeholder strings with environment variable values.

    .EXAMPLE
        $cfg = Import-JsonConfig 'configs\clusters_catalogue.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Path,
        [bool] $Required           = $true,
        [bool] $AutoEnvVarReplace  = $true
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        if ($Required) { throw "Configuration file not found: $Path" }
        return @{}
    }

    try {
        $raw    = Get-Content -Path $Path -Raw -Encoding UTF8
        $parsed = $raw | ConvertFrom-Json -Depth 64
        $config = _PS_ConvertTo-Hashtable $parsed
        if ($AutoEnvVarReplace) { $config = _PS_ReplaceEnvVars $config }
        return $config
    }
    catch {
        throw "Invalid JSON in '$Path': $($_.Exception.Message)"
    }
}

function Import-YamlConfig {
    <#
    .SYNOPSIS
        Load a YAML config file. Requires the 'powershell-yaml' module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Path,
        [bool] $Required = $true
    )
    if (-not (Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue)) {
        throw "Install powershell-yaml first: Install-Module powershell-yaml"
    }
    if (-not (Test-Path $Path -PathType Leaf)) {
        if ($Required) { throw "Config file not found: $Path" }
        return @{}
    }
    return (Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Yaml -Depth 64) ?? @{}
}

# ─── private helpers ──────────────────────────────────────────────────────────

function _PS_ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)] $InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IDictionary]) {
            $ht = @{}
            foreach ($k in $InputObject.Keys) { $ht[$k] = _PS_ConvertTo-Hashtable $InputObject[$k] }
            return $ht
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            return ,@($InputObject | ForEach-Object { _PS_ConvertTo-Hashtable $_ })
        }
        return $InputObject
    }
}

function _PS_ReplaceEnvVars {
    param([hashtable] $Config)
    $out = @{}
    foreach ($key in $Config.Keys) {
        $val = $Config[$key]
        $out[$key] = if ($val -is [hashtable]) {
            _PS_ReplaceEnvVars $val
        } elseif ($val -is [System.Collections.IEnumerable] -and $val -isnot [string]) {
            ,@($val | ForEach-Object {
                if ($_ -is [hashtable]) { _PS_ReplaceEnvVars $_ }
                elseif ($_ -is [string]) { _PS_SubstituteEnvVars $_ }
                else { $_ }
            })
        } elseif ($val -is [string]) {
            _PS_SubstituteEnvVars $val
        } else { $val }
    }
    return $out
}

function _PS_SubstituteEnvVars {
    # Replace ${VARNAME} with the corresponding environment variable value.
    # Uses a simple while-loop to avoid regex callback syntax issues across PS versions.
    param([string] $Str)
    $result = $Str
    $start  = $result.IndexOf('${')
    while ($start -ge 0) {
        $end = $result.IndexOf('}', $start + 2)
        if ($end -lt 0) { break }
        $varName = $result.Substring($start + 2, $end - $start - 2)
        $envVal  = [System.Environment]::GetEnvironmentVariable($varName)
        $token   = $result.Substring($start, $end - $start + 1)   # e.g. "${FOO}"
        if ($null -ne $envVal) {
            $result = $result.Remove($start, $token.Length).Insert($start, $envVal)
            $start  = $result.IndexOf('${', $start + $envVal.Length)
        } else {
            $start  = $result.IndexOf('${', $start + $token.Length)
        }
    }
    return $result
}

# vim: ts=4 sw=4 et
