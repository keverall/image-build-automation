#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Updates the GitLab CI/CD hardening & compliance test plan with a pipeline run.

.DESCRIPTION
    Records an execution-evidence row in docs/Automation/GITLAB_HARDENING_TEST_PLAN.md
    for a pipeline run that exercised the EMIR/DORA hardening controls (GitLab
    native Secret Detection, SAST, the PSScriptAnalyzer security gate, code
    coverage, dependency/container scanning, runner-OS detection). It also records
    the test-unit coverage figure, then regenerates the timestamped HTML snapshot
    in docs/Automation/Testing_Reports/ (same convention as the Automation and
    OneView plans, so the GitLab plan appears alongside them as evidence).

    The script mirrors Update-TestProgress.ps1 and shares its pure helpers
    (scripts/TestProgress.Common.ps1). It can be driven interactively via
    `make gitlab-hardening-update` or non-interactively from the GitLab
    compliance-evidence job via environment variables.

    Env vars (non-interactive):
      GH_REASON       - reason/ref for the run (ticket, MR)
      GH_PIPELINEJOB  - pipeline or job identifier
      GH_ENV          - environment (e.g. "GitLab CI", "Bank GitLab - UAT")
      GH_RESULT       - Pass / Fail / Partial
      GH_NOTES        - free-text reference notes
      GH_COVERAGE     - coverage percentage measured this run
      GH_THRESHOLD    - coverage threshold (e.g. "70")
      GH_ENFORCED     - "report" | "enforce"
      GH_ADD_ROW      - "1" to append an evidence row (default: refresh date only)
      GH_ADD_COV_ROW  - "1" to append a coverage row

.PARAMETER PlanPath
    Path to GITLAB_HARDENING_TEST_PLAN.md.

.PARAMETER SkipHtml
    Skip HTML regeneration (used by tests to stay hermetic).
#>
[CmdletBinding()]
param(
    [string]$PlanPath = "docs/Automation/GITLAB_HARDENING_TEST_PLAN.md",
    [string]$ReportsDir = "docs/Automation/Testing_Reports",
    [switch]$NonInteractive,
    [string]$Reason,
    [string]$PipelineJob,
    [string]$Environment,
    [string]$Result,
    [string]$RefNotes,
    [string]$CoveragePercent,
    [string]$Threshold,
    [string]$Enforcement,
    [switch]$AddRow,
    [switch]$AddCovRow,
    [switch]$SkipHtml
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'TestProgress.Common.ps1')
. (Join-Path $PSScriptRoot 'Detect-Runner.ps1')

function _Resolve {
    param([AllowNull()][AllowEmptyString()][string]$Current, [string]$Prompt, [string]$Default)
    if (-not [string]::IsNullOrWhiteSpace($Current)) { return $Current }
    if ($NonInteractive) { return $Default }
    Write-Host "$Prompt (default: '$Default'): " -ForegroundColor Yellow -NoNewline
    $v = [System.Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}

# Pull from env when invoked from the pipeline.
if ($env:GH_REASON)        { $Reason = $env:GH_REASON }
if ($env:GH_PIPELINEJOB)   { $PipelineJob = $env:GH_PIPELINEJOB }
if ($env:GH_ENV)           { $Environment = $env:GH_ENV }
if ($env:GH_RESULT)        { $Result = $env:GH_RESULT }
if ($env:GH_NOTES)         { $RefNotes = $env:GH_NOTES }
if ($env:GH_COVERAGE)      { $CoveragePercent = $env:GH_COVERAGE }
if ($env:GH_THRESHOLD)     { $Threshold = $env:GH_THRESHOLD }
if ($env:GH_ENFORCED)      { $Enforcement = $env:GH_ENFORCED }
if ($env:GH_ADD_ROW -eq '1')    { $AddRow = $true }
if ($env:GH_ADD_COV_ROW -eq '1') { $AddCovRow = $true }

if (-not (Test-Path $PlanPath)) {
    Write-Error "GitLab hardening test plan not found: $PlanPath"
    exit 1
}

$runDate = [DateTime]::UtcNow.ToString('dd/MM/yyyy HH:mm') + ' UTC'
$dateTime = [DateTime]::UtcNow.ToString('dd/MM/yyyy HH:mm:ss') + ' UTC'

$Reason = _Resolve -Current $Reason -Prompt 'Reason / reference (ticket, MR)' -Default 'GitLab hardening pipeline run'
$PipelineJob = _Resolve -Current $PipelineJob -Prompt 'Pipeline / job' -Default 'gitlab-ci (security + compliance)'
$Environment = _Resolve -Current $Environment -Prompt 'Environment' -Default 'GitLab CI'
$Result = _Resolve -Current $Result -Prompt 'Result' -Default 'Partial (report-only gate)'

# Working flags. Boolean switches are positional in `pwsh -File` (the next
# token is consumed as the value), so the pipeline drives these via the
# GH_ADD_ROW / GH_ADD_COV_ROW environment variables, which are unambiguous.
$gitlabAddEvidence = $false
if ($AddRow) { $gitlabAddEvidence = $true }
elseif (-not $NonInteractive) {
    Write-Host 'Add an evidence row? (y/N): ' -ForegroundColor Yellow -NoNewline
    $gitlabAddEvidence = ([System.Console]::ReadLine() -match '^[Yy]')
}

$gitlabAddCoverage = $false
if ($AddCovRow) { $gitlabAddCoverage = $true }
elseif (-not $NonInteractive) {
    Write-Host 'Add a coverage row? (y/N): ' -ForegroundColor Yellow -NoNewline
    $gitlabAddCoverage = ([System.Console]::ReadLine() -match '^[Yy]')
}

$content = Get-Content $PlanPath -Raw
$content = Repair-DuplicateBlockMarker -Content $content
$content = Update-RunDateBlock -Content $content -RunDate $runDate

if ($null -ne (Get-Block -Content $content -Key 'gitlab-hardening-evidence-rows')) {
    $ev = Update-GitLabHardeningBlock -Content $content -DateTime $dateTime `
        -AddRow:$gitlabAddEvidence -PipelineJob $PipelineJob -Environment $Environment `
        -Result $Result -RefNotes $RefNotes
    $content = $ev.Content
    Set-Content -Path $PlanPath -Value $content -NoNewline
    if ($ev.Added) {
        Write-Host "[gitlab-hardening] Added evidence row #$($ev.RunNumber)" -ForegroundColor Green
    } else {
        Write-Host "[gitlab-hardening] Refreshed evidence last-row date" -ForegroundColor Green
    }
} else {
    Write-Warning "Could not find gitlab-hardening-evidence-rows block in $PlanPath"
}

if ($null -ne (Get-Block -Content $content -Key 'gitlab-coverage-rows')) {
    $cov = Update-GitLabCoverageBlock -Content $content -DateTime $dateTime `
        -AddRow:$gitlabAddCoverage -CoveragePercent $CoveragePercent -Threshold $Threshold `
        -Enforcement $Enforcement -Notes $RefNotes
    $content = $cov.Content
    Set-Content -Path $PlanPath -Value $content -NoNewline
    if ($cov.Added) {
        Write-Host "[gitlab-hardening] Added coverage row #$($cov.RunNumber)" -ForegroundColor Green
    } else {
        Write-Host "[gitlab-hardening] Refreshed coverage last-row date" -ForegroundColor Green
    }
} else {
    Write-Warning "Could not find gitlab-coverage-rows block in $PlanPath"
}

if ($SkipHtml) {
    Write-Host "`n[gitlab-hardening] -SkipHtml supplied; skipping HTML regeneration." -ForegroundColor Yellow
    return
}

$converterScript = "scripts/MD_to_HTML_Converter.py"
$timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ssZ')
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null
}
$htmlPath = "$ReportsDir/GITLAB_HARDENING_TEST_PLAN_$timestamp.html"

if (-not (Test-Path $converterScript)) {
    Write-Warning "HTML converter not found: $converterScript; skipping HTML."
    return
}
try {
    python3 $converterScript $PlanPath $htmlPath
    Write-Host "[gitlab-hardening] HTML generated: $htmlPath" -ForegroundColor Green
} catch {
    Write-Warning "Failed to regenerate HTML: $_"
}
