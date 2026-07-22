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
