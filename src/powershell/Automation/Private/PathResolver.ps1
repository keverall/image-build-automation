#
# Private/PathResolver.ps1 - Shared path resolution utilities.
#

function Get-ProjectRoot {
    <#
    .SYNOPSIS
        Walk up directories from the current location to find the project root
        (identified by the presence of kilo.json or Makefile).

    .PARAMETER StartPath
        Directory to start searching from. Defaults to $PSScriptRoot.

    .RETURNS
        The resolved project root path, or $null if not found.
    #>
    param([string]$StartPath = $PSScriptRoot)

    if (-not $StartPath) { $StartPath = Get-Location }
    $current = $StartPath
    while ($current -and -not (Test-Path (Join-Path $current 'kilo.json')) -and -not (Test-Path (Join-Path $current 'Makefile'))) {
        $parent = Split-Path $current
        if ($parent -eq $current -or -not $parent) { break }
        $current = $parent
    }
    if ($current -and (Test-Path $current)) {
        return (Resolve-Path $current).Path
    }
    return $null
}

function Resolve-EffectiveConfigDir {
    <#
    .SYNOPSIS
        Resolve the effective configuration directory for a command.

    .DESCRIPTION
        Shared resolution logic used by all Public commands that accept a
        -ConfigDir parameter. Resolution order:
          1. When -ConfigDir was explicitly bound: absolute paths are used
             verbatim; relative paths are resolved against the current location.
          2. Otherwise: <project-root>\configs.
          3. Fallback: when the marker file is not found in the resolved
             directory and -ConfigDir is relative, retry against the project
             root (handles commands invoked from outside the repo root).

    .PARAMETER ConfigDir
        The -ConfigDir parameter value as supplied to the caller (default
        'configs' when the caller did not bind it).

    .PARAMETER MarkerFile
        A file whose presence confirms the directory (e.g.
        'connection_hosts.json', 'clusters_catalogue.json').

    .PARAMETER ExplicitlyBound
        Pass $PSBoundParameters.ContainsKey('ConfigDir') from the caller.

    .RETURNS
        [string] The resolved config directory path (not guaranteed to exist).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $ConfigDir,
        [Parameter(Mandatory)][string] $MarkerFile,
        [switch] $ExplicitlyBound
    )

    $projRoot = Get-ProjectRoot
    if (-not $projRoot) { $projRoot = (Get-Location).Path }

    $effective = if ($ExplicitlyBound) {
        if (Split-Path $ConfigDir -IsAbsolute) { $ConfigDir }
        else { Join-Path (Get-Location) $ConfigDir }
    } else {
        Join-Path $projRoot 'configs'
    }

    if (-not (Test-Path (Join-Path $effective $MarkerFile))) {
        if (-not (Split-Path $ConfigDir -IsAbsolute)) {
            $fallback = Join-Path $projRoot $ConfigDir
            if (Test-Path (Join-Path $fallback $MarkerFile)) {
                $effective = $fallback
            }
        }
    }
    return $effective
}

function Get-LogDirectory {
    <#
    .SYNOPSIS
        Get the appropriate log directory based on context (testing vs production).

    .PARAMETER Category
        Log category: 'test', 'audit', 'regulatory', 'build_reports', or 'production' (default).
    #>
    param([string]$Category = 'production')

    $projectRoot = Get-ProjectRoot
    if (-not $projectRoot) { return $null }

    $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
    if ($Category -eq 'test' -or ($isTesting -and $Category -eq 'production')) {
        $subDir = 'testing'
    } elseif ($Category -in 'audit', 'regulatory') {
        $subDir = 'audit'
    } elseif ($Category -eq 'build_reports') {
        $subDir = 'build_reports'
    } else {
        $subDir = 'production'
    }
    return Join-Path $projectRoot "generated/logs/$subDir"
}
