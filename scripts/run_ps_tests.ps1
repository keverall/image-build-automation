<#
# scripts/run_ps_tests.ps1 — Pester helper called from the Makefile.
# Runs the unit test files listed in tests_ps_paths.txt (sibling file).
# Uses the per-test .Result property for accurate pass/fail counts,
# working around a Pester 5.7.1 bug where PassThru PassedCount/FailedCount
# can be wrong when -Show None is used.
#>
param(
    [string]$PesterVersion = '5.0.0',
    [switch]$ShowOutput,
    [switch]$Integration
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
$repoRoot  = Split-Path $scriptDir -Parent

Import-Module Pester -MinimumVersion $PesterVersion -ErrorAction Stop
Import-Module (Join-Path $repoRoot 'src/powershell/Automation/Automation.psd1') -Force -ErrorAction Stop

$listFile = Join-Path $scriptDir 'tests_ps_paths.txt'
if (-not (Test-Path $listFile)) { Write-Error "Test list not found: $listFile" }

$files = [System.IO.File]::ReadAllLines($listFile) | Where-Object { $_.Trim() }
if ($Integration) {
    $intFile = Join-Path $repoRoot 'tests/powershell/Pester.Integration.ps1'
    if (Test-Path $intFile) { $files += ,$intFile }
}

Write-Host "[pwsh-test] Running $($files.Count) test file(s) ..."

$show = if ($ShowOutput) { 'All' } else { 'None' }

$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $repoRoot "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$pesterLogPath = Join-Path $logDir "testing_coverage_detail_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"

Write-Host "Detailed log: $pesterLogPath"

if ($PSVersionTable.PSVersion.Major -ge 7) { $PSStyle.OutputRendering = 'Ansi' }

Start-Transcript -Path $pesterLogPath -Append:$false | Out-Null
try {
    $result = Invoke-Pester -Path $files -PassThru -Show $show
}
finally {
    Stop-Transcript | Out-Null
}

# Count from per-test .Result to avoid Pester 5.7.1 PassThru count bugs
$testObjs = $result.Tests
$nPased   = ($testObjs | Where-Object Result -EQ 'Passed').Count
$nFailed  = ($testObjs | Where-Object Result -EQ 'Failed').Count
$nSkipped = ($testObjs | Where-Object Result -EQ 'Skipped').Count
$nNotRun  = ($testObjs | Where-Object Result -EQ 'NotRun').Count

Write-Host ""
Write-Host "[pwsh-test] $nPased passed / $nFailed failed / $nSkipped skipped / $nNotRun not-run (Total: $($testObjs.Count))"
if ($nFailed -gt 0) { exit 1 }
exit 0
