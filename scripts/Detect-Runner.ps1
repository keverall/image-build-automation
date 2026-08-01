#Requires -Version 7.0
<#
.SYNOPSIS
    Detect the CI runner OS and a target branch, for branching module imports.

.DESCRIPTION
    Production automation must run on the Bank's Windows estate (HPE OneView /
    SCOM are Windows-oriented, and the vendored HPEOneView.1000 module is not
    guaranteed to load on PowerShell 7 for Linux). The CI pipeline, however, may
    execute on Linux or Windows runners depending on what DevOps provisions.

    This helper answers two questions so the rest of the pipeline can branch:

      1. Is this job running on a Windows runner or a Linux/macOS runner?
         Detection prefers PowerShell's built-in $IsWindows / $IsLinux, falls
         back to the `uname` command (the method DevOps asked us to use so the
         behaviour is explicit and visible in job logs), and finally inspects
         $env:OS.

      2. What is the branch/target this job is validating?
         Surfaces the CI branch / merge-request ref so import logic and test
         selection can differ between the default branch and feature branches if
         required.

    It also exposes Import-AutomationModule, which imports the project's
    Automation module and *gracefully* degrades on a non-Windows runner: the
    HPEOneView module targets Windows, so on Linux the import may fail. Rather
    than letting every pipeline job crash, Import-AutomationModule:
      - on Windows: fails the job if the module will not import (FailOnLinux:false
        is the default for Windows).
      - on non-Windows: warns, records the limitation, and returns $false so the
        caller can skip module-dependent steps instead of aborting the whole
        pipeline. Set -FailOnUnsupported to force a hard failure.

    Dot-source this file from a runner script:
      . (Join-Path $PSScriptRoot 'Detect-Runner.ps1')

.OUTPUTS
    Sets the following variables in the caller's scope:
      $IsWindowsRunner   [bool]   true on a Windows runner
      $IsLinuxRunner     [bool]   true on a Linux runner
      $RunnerOS          [string] 'Windows' | 'Linux' | 'macOS' | 'Unknown'
      $RunnerUname       [string] raw `uname -s` output (or '' if unavailable)
      $RunnerBranch      [string] CI branch / MR ref, or 'local'
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Test-Path variable:PROJECT_ROOT)) {
    $PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
}

# -----------------------------------------------------------------------------
# Runner OS detection
# -----------------------------------------------------------------------------
$IsWindowsRunner = $false
$IsLinuxRunner = $false
$macOsRunner = $false
$RunnerOS = 'Unknown'
$RunnerUname = ''

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $IsWindowsRunner = [bool]$IsWindows
    $IsLinuxRunner = [bool]$IsLinux
    $macOsRunner = [bool]$IsMacOS
} else {
    # Windows PowerShell 5.1 has no $Is* automatic variables.
    $IsWindowsRunner = ($env:OS -like 'Windows*')
}

if (-not ($IsWindowsRunner -or $IsLinuxRunner -or $macOsRunner)) {
    # Fall back to `uname`, the method explicitly called out by DevOps. This is
    # the deterministic signal when the automatic variables are absent.
    try {
        $unameRaw = & uname -s 2>$null
        $RunnerUname = ($unameRaw -split "`n" | Select-Object -First 1).Trim()
        if ($RunnerUname -match 'CYGWIN|MINGW|MSYS|Windows') {
            $IsWindowsRunner = $true
        } elseif ($RunnerUname -match 'Linux') {
            $IsLinuxRunner = $true
        } elseif ($RunnerUname -match 'Darwin') {
            $macOsRunner = $true
        }
    } catch {
        # uname unavailable; fall through to $env:OS check below.
    }
}

if (-not ($IsWindowsRunner -or $IsLinuxRunner -or $macOsRunner)) {
    if ($env:OS -like 'Windows*') { $IsWindowsRunner = $true }
}

if ($IsWindowsRunner) { $RunnerOS = 'Windows' }
elseif ($IsLinuxRunner) { $RunnerOS = 'Linux' }
elseif ($macOsRunner) { $RunnerOS = 'macOS' }

# -----------------------------------------------------------------------------
# Branch / target detection
# -----------------------------------------------------------------------------
$RunnerBranch = if ($env:CI_COMMIT_REF_NAME) { $env:CI_COMMIT_REF_NAME }
                elseif ($env:CI_MERGE_REQUEST_SOURCE_BRANCH_NAME) { $env:CI_MERGE_REQUEST_SOURCE_BRANCH_NAME }
                elseif ($env:CI_COMMIT_BRANCH) { $env:CI_COMMIT_BRANCH }
                else { 'local' }

Write-Output "[detect-runner] OS=$RunnerOS (uname='$($RunnerUname -replace "'",'')') Windows=$IsWindowsRunner Linux=$IsLinuxRunner Branch=$RunnerBranch"

# -----------------------------------------------------------------------------
# Branching import
# -----------------------------------------------------------------------------
function Import-AutomationModule {
    [CmdletBinding()]
    param(
        [string] $ModulePath,
        [switch] $FailOnUnsupported
    )

    if ([string]::IsNullOrWhiteSpace($ModulePath)) {
        $ModulePath = Join-Path $PROJECT_ROOT 'src/powershell/Automation/Automation.psd1'
    }

    if (-not (Test-Path -LiteralPath $ModulePath)) {
        throw "Automation module not found at: $ModulePath"
    }

    try {
        $ext = [System.IO.Path]::GetExtension($ModulePath)
        if ($ext -eq '.psd1') {
            Import-Module -Name $ModulePath -Force -ErrorAction Stop
        } else {
            # A bare .psm1 / .ps1 module file cannot be imported with
            # -Name; dot-source it so its definitions land in the session
            # (this is the existing behaviour in run-tests.ps1 et al).
            . $ModulePath
        }
        Write-Output '[detect-runner] Automation module imported.'
        return $true
    } catch {
        $errMsg = $_.Exception.Message
        if (-not $IsWindowsRunner) {
            # The HPEOneView.1000 dependency targets Windows; a failure to import
            # here is expected on a Linux/macOS runner, not a code defect.
            Write-Output '[detect-runner] WARN: Automation module did not import on a non-Windows runner.'
            Write-Output "              Reason: $errMsg"
            Write-Output '              Module-dependent steps (Connect-OVMgmt, OneView cmdlets) are skipped.'
            Write-Output '              Test jobs on Linux will run only the platform-independent unit tests.'
            if ($FailOnUnsupported) {
                throw "Automation module required on this runner but failed to import: $errMsg"
            }
            return $false
        }
        # On Windows the module MUST import. A failure here is a real defect.
        throw "Automation module failed to import on a Windows runner: $errMsg"
    }
}
