#Requires -Version 7.0
<#
.SYNOPSIS
    Run the Pester suite with code coverage and enforce a coverage threshold.

.DESCRIPTION
    Creates scripts/run-coverage.ps1, which .gitlab-ci.yml referenced but which
    did not exist. The reference was masked because every job that used the
    test template overrode the 'script' block, so the missing file was never
    invoked - the declared COVERAGE_THRESHOLD of 70 was therefore never applied
    to anything.

    This script produces:
      - Cobertura XML  : consumed by GitLab for MR coverage annotation
      - JUnit XML      : consumed by GitLab for the MR test report widget
      - A stdout line matching the pipeline's coverage regex

    Exits non-zero if any test fails, or if line coverage is below -Threshold
    while -EnforceThreshold is set.

.PARAMETER Threshold
    Minimum line coverage percentage.

.PARAMETER EnforceThreshold
    Fail the run when coverage is below -Threshold. Omitted during the
    remediation window so that coverage is measured and reported before it is
    gated. See docs/compliance/SECURITY_PIPELINE.md.

.EXAMPLE
    pwsh -File scripts/run-coverage.ps1 -Threshold 70

.EXAMPLE
    pwsh -File scripts/run-coverage.ps1 -Threshold 70 -EnforceThreshold
#>
[CmdletBinding()]
param(
    [string] $TestPath = 'tests/powershell',
    [string] $SourcePath = 'src/powershell',
    [string] $OutputDirectory = 'generated/output/coverage',
    [ValidateRange(0, 100)]
    [double] $Threshold = 70,
    [switch] $EnforceThreshold
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

function Resolve-ProjectPath {
    param([string] $Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $projectRoot $Path
}

$TestPath = Resolve-ProjectPath $TestPath
$SourcePath = Resolve-ProjectPath $SourcePath
$OutputDirectory = Resolve-ProjectPath $OutputDirectory
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory

$coverageXml = Join-Path $OutputDirectory 'coverage-results.xml'
$testResultsXml = Join-Path $OutputDirectory 'test-results.xml'

. (Join-Path $PSScriptRoot 'Ensure-Pester.ps1')
. (Join-Path $PSScriptRoot 'Detect-Runner.ps1')
$null = Import-AutomationModule -ErrorAction SilentlyContinue
# On a Linux runner the Automation module (which depends on HPEOneView.1000,
# a Windows-oriented module) may not import. Import-AutomationModule degrades
# gracefully; coverage of module-dependent code still runs where the module
# loaded, and platform-independent tests run regardless.

# Discover tests dynamically, excluding the scratch/manual harness files that
# live alongside the real suite (_class_test.ps1, Pester.Integration.ps1 etc.).
$testFiles = @(
    Get-ChildItem -Path $TestPath -Filter '*.Tests.ps1' -File -Recurse |
        Where-Object { $_.Name -notlike '_*' } |
        Sort-Object FullName
)

if ($testFiles.Count -eq 0) {
    throw "No test files discovered under $TestPath"
}

# Cover the module source only. Test files and the scripts/ helpers are not
# the subject of the coverage measurement.
$coverageTargets = @(
    Get-ChildItem -Path $SourcePath -Recurse -Include '*.ps1', '*.psm1' -File |
        Where-Object { $_.FullName -notmatch '[\\/](modules|vendor)[\\/]' } |
        Select-Object -ExpandProperty FullName
)

Write-Output "Test files      : $($testFiles.Count)"
Write-Output "Coverage files  : $($coverageTargets.Count)"
Write-Output "Threshold       : $Threshold% (enforced: $([bool]$EnforceThreshold))"
Write-Output ''

$config = New-PesterConfiguration
$config.Run.Path = $testFiles.FullName
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Normal'

$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'JUnitXml'
$config.TestResult.OutputPath = $testResultsXml

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $coverageTargets
$config.CodeCoverage.OutputFormat = 'Cobertura'
$config.CodeCoverage.OutputPath = $coverageXml
# Threshold is evaluated below rather than by Pester, so that coverage is always
# reported even when it is not being enforced.
$config.CodeCoverage.CoveragePercentTarget = $Threshold

$results = Invoke-Pester -Configuration $config

# -----------------------------------------------------------------------------
# Results
# -----------------------------------------------------------------------------
$coveragePercent = 0.0
if ($results.PSObject.Properties.Name -contains 'CodeCoverage' -and $results.CodeCoverage) {
    $analysed = $results.CodeCoverage.CommandsAnalyzedCount
    $executed = $results.CodeCoverage.CommandsExecutedCount
    if ($analysed -gt 0) {
        $coveragePercent = [math]::Round(($executed / $analysed) * 100, 2)
    }
}

Write-Output ''
Write-Output '=============================================================================='
Write-Output ' TEST AND COVERAGE SUMMARY'
Write-Output '=============================================================================='
Write-Output " Total tests     : $($results.TotalCount)"
Write-Output " Passed          : $($results.PassedCount)"
Write-Output " Failed          : $($results.FailedCount)"
Write-Output " Skipped         : $($results.SkippedCount)"
Write-Output " Duration        : $($results.Duration.TotalSeconds.ToString('0.00'))s"
# This exact wording is what the GitLab job's coverage regex matches on.
Write-Output " Coverage        : $coveragePercent%"
Write-Output " Threshold       : $Threshold%"
Write-Output '=============================================================================='

$failed = $false

if ($results.FailedCount -gt 0) {
    Write-Output "FAIL: $($results.FailedCount) test(s) failed."
    $failed = $true
}

if ($coveragePercent -lt $Threshold) {
    if ($EnforceThreshold) {
        Write-Output "FAIL: coverage $coveragePercent% is below the $Threshold% threshold."
        $failed = $true
    } else {
        Write-Output "WARN: coverage $coveragePercent% is below the $Threshold% threshold (not enforced)."
    }
}

if ($failed) { exit 1 }

Write-Output 'RESULT: PASS'
exit 0
