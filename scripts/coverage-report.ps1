# =============================================================================
# HPE ProLiant Windows Server ISO Automation - PowerShell Coverage Report
# =============================================================================
# Generates Cobertura XML code coverage reports using Pester.

<#
.SYNOPSIS
    Generate code coverage report from Pester tests.

.DESCRIPTION
    Runs Pester tests with code coverage enabled and generates:
    - Cobertura XML coverage file (coverage-results.xml)
    - Markdown coverage report (coverage-report.md)
    - Text coverage report (coverage-report.txt)
    
    Reports are written to generated/output/coverage directory.
    Displays formatted coverage summary in console output.

.PARAMETER InputFile
    Path to Cobertura XML file (default: coverage-results.xml)

.PARAMETER OutputFile
    Path for text report output (default: coverage-report.txt)

.EXAMPLE
    pwsh -File scripts/coverage-report.ps1
    
.EXAMPLE
    ./scripts/coverage-report.ps1 -InputFile 'custom-coverage.xml' -OutputFile 'my-report.txt'
#>

# Usage: pwsh -File scripts/coverage-report.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$PROJECT_ROOT = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

if (-not (Get-Module Pester -ListAvailable)) {
    Write-Error "Pester not installed. Install with: Install-Module Pester -Scope CurrentUser"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$testPath = Join-Path $PROJECT_ROOT 'tests/powershell'
$sourcePath = Join-Path $PROJECT_ROOT 'src/powershell'
$outputDir = Join-Path $PROJECT_ROOT 'generated/output/coverage'
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
$outputPath = Join-Path $outputDir 'coverage-results.xml'

Write-Host '[coverage-report] Running tests with code coverage...' -ForegroundColor Cyan

$config = New-PesterConfiguration
$config.Run.Path = @($testPath)
$config.Output.Verbosity = 'Minimal'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @($sourcePath)
$config.CodeCoverage.OutputPath = $outputPath
$config.CodeCoverage.OutputFormat = 'Cobertura'

$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

$pesterLogPath = Join-Path $logDir "testing_coverage_detail_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"
Write-Host "[coverage-report] Running Pester tests... (Detailed log: $pesterLogPath)" -ForegroundColor Cyan

if ($PSVersionTable.PSVersion.Major -ge 7) { $PSStyle.OutputRendering = 'Ansi' }
Start-Transcript -Path $pesterLogPath -Append:$false | Out-Null
try {
    # In Pester 5.7, Invoke-Pester -Configuration returns $null and -PassThru
    # is incompatible with -Configuration. We run the tests, then parse the
    # transcript (which already contains Pester's summary output) for counts.
    $pesterResult = Invoke-Pester -Configuration $config

    # Parse the transcript for Pester's summary lines
    $logContent = Get-Content $pesterLogPath -Raw

    $passed = 0; $failed = 0; $skipped = 0; $inconclusive = 0; $notRun = 0; $durationSec = 0

    # "Tests completed in 25.78s"
    $durationMatch = [regex]::Match($logContent, 'Tests completed in ([\d.]+)s')
    if ($durationMatch.Success) {
        $durationSec = [math]::Round([double]$durationMatch.Groups[1].Value, 2)
    }

    # "Tests Passed: 171, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0"
    $summaryMatch = [regex]::Match($logContent, 'Tests Passed:\s*(\d+),\s*Failed:\s*(\d+),\s*Skipped:\s*(\d+),\s*Inconclusive:\s*(\d+),\s*NotRun:\s*(\d+)')
    if ($summaryMatch.Success) {
        $passed        = [int]$summaryMatch.Groups[1].Value
        $failed        = [int]$summaryMatch.Groups[2].Value
        $skipped       = [int]$summaryMatch.Groups[3].Value
        $inconclusive  = [int]$summaryMatch.Groups[4].Value
        $notRun        = [int]$summaryMatch.Groups[5].Value
    }

    $durStr = "{0:N2}" -f $durationSec
    Write-Host ''
    Write-Host '**********************************************************************'
    Write-Host '*                    COVERAGE TEST SUMMARY                           *'
    Write-Host '**********************************************************************'
    Write-Host '*'
    Write-Host ('*  Duration : {0}s' -f $durStr)
    Write-Host '*'
    Write-Host '*  +--------------+-------+'
    Write-Host ('*  | Passed       | {0,5} |' -f $passed)
    Write-Host ('*  | Failed       | {0,5} |' -f $failed)
    Write-Host ('*  | Skipped      | {0,5} |' -f $skipped)
    Write-Host ('*  | Inconclusive | {0,5} |' -f $inconclusive)
    Write-Host ('*  | NotRun       | {0,5} |' -f $notRun)
    Write-Host '*  +--------------+-------+'
    Write-Host '*'

    if (-not (Test-Path $outputPath)) {
        Write-Host '*  WARNING: Coverage data not available'
    } else {
        [xml]$xml = Get-Content $outputPath

        $files = @()
        foreach ($cls in $xml.coverage.packages.package.classes.class) {
            $filename = $cls.filename
            $lineRate = [double]$cls.'line-rate'
            $lines = @()

            $methodLines = $cls.SelectNodes('.//method')
            foreach ($method in $methodLines) {
                $lineNodes = $method.SelectNodes('./lines/line')
                foreach ($lineNode in $lineNodes) {
                    $lines += $lineNode
                }
            }

            $directLines = $cls.SelectNodes('./lines/line')
            foreach ($lineNode in $directLines) {
                $lines += $lineNode
            }

            $totalLines = $lines.Count
            $coveredLines = ($lines | Where-Object { [int]$_.hits -gt 0 }).Count

            $files += [PSCustomObject]@{
                Filename = $filename
                Rate = $lineRate * 100
                Covered = $coveredLines
                Missed = $totalLines - $coveredLines
                Total = $totalLines
            }
        }

        $files = $files | Sort-Object Filename

        $totalCovered = ($files | Measure-Object -Property Covered -Sum).Sum
        $totalLinesCount = ($files | Measure-Object -Property Total -Sum).Sum
        $overallRate = if ($totalLinesCount -gt 0) { [math]::Round(($totalCovered / $totalLinesCount) * 100, 1) } else { 0 }
        $pctStr = "{0:N1}%" -f $overallRate

        $barWidth = 40
        $filledWidth = if ($overallRate -gt 0) { [math]::Floor(($overallRate / 100) * $barWidth) } else { 0 }
        $emptyWidth = $barWidth - $filledWidth
        $filledBar = '#' * $filledWidth
        $emptyBar = '.' * $emptyWidth

        $fileCount = $files.Count

        Write-Host '*  COVERAGE SUMMARY'
        Write-Host ('*  {0} {1}{2}' -f $pctStr, $filledBar, $emptyBar)
        Write-Host '*'
        Write-Host '*  +-----------+----------+----------+--------+'
        Write-Host ('*  | Files     | {0,-8} |          |        |' -f $fileCount)
        Write-Host ('*  | Lines     | {0,-8} | covered  | of {1} |' -f $totalCovered, $totalLinesCount)
        Write-Host ('*  | Rate      | {0,-8} |          |        |' -f $pctStr)
        Write-Host '*  +-----------+----------+----------+--------+'
    }

    Write-Host '*'
    Write-Host '**********************************************************************'
} finally {
    Stop-Transcript | Out-Null
}

if (-not (Test-Path $outputPath)) {
    Write-Host '[coverage-report] WARNING: Coverage file not generated' -ForegroundColor Yellow
    exit 0
}

[xml]$xml = Get-Content $outputPath

$files = @()
foreach ($cls in $xml.coverage.packages.package.classes.class) {
    $filename = $cls.filename
    $lineRate = [double]$cls.'line-rate'
    $lines = @()

    $methodLines = $cls.SelectNodes('.//method')
    foreach ($method in $methodLines) {
        $lineNodes = $method.SelectNodes('./lines/line')
        foreach ($lineNode in $lineNodes) {
            $lines += $lineNode
        }
    }

    $directLines = $cls.SelectNodes('./lines/line')
    foreach ($lineNode in $directLines) {
        $lines += $lineNode
    }

    $totalLines = $lines.Count
    $coveredLines = ($lines | Where-Object { [int]$_.hits -gt 0 }).Count

    $files += [PSCustomObject]@{
        Filename = $filename
        Rate = $lineRate * 100
        Covered = $coveredLines
        Missed = $totalLines - $coveredLines
        Total = $totalLines
    }
}

$files = $files | Sort-Object Filename

$totalCovered = ($files | Measure-Object -Property Covered -Sum).Sum
$totalLinesCount = ($files | Measure-Object -Property Total -Sum).Sum
$overallRate = if ($totalLinesCount -gt 0) { [math]::Round(($totalCovered / $totalLinesCount) * 100, 1) } else { 0 }

Write-Host ''
Write-Host '========================================'
Write-Host '[coverage-report] Code Coverage Summary'
Write-Host "  Files: $($files.Count)"
Write-Host "  Lines: $totalCovered / $totalLinesCount ($overallRate%)"
Write-Host '========================================'
Write-Host ''

$header = "Name".PadRight(56) + " | Rate | Covered | Missed | Total"
$separator = "-" * 72

$output = @()
$output += ""
$output += $header
$output += $separator

foreach ($f in $files) {
    $line = $f.Filename.PadRight(56) + " | " +
            ("{0:N1}%" -f $f.Rate).PadLeft(6) + " | " +
            $f.Covered.ToString().PadLeft(8) + " | " +
            $f.Missed.ToString().PadLeft(8) + " | " +
            $f.Total.ToString().PadLeft(6)
    $output += $line
}

$output += $separator
$output += ("TOTAL".PadRight(56) + " | " +
            ("{0:N1}%" -f $overallRate).PadLeft(6) + " | " +
            $totalCovered.ToString().PadLeft(8) + " | " +
            ($totalLinesCount - $totalCovered).ToString().PadLeft(8) + " | " +
            $totalLinesCount.ToString().PadLeft(6))
$output += ""

# Don't print the huge table to the console, it floods the terminal.
# $output | Write-Output

$mdOutputPath = Join-Path $outputDir 'coverage-report.md'
$mdHeader = "# Code Coverage Report"
$mdOutput = @()
$mdOutput += $mdHeader
$mdOutput += ""
$mdOutput += "## Summary"
$mdOutput += ""
$mdOutput += "- **Files:** $($files.Count)"
$mdOutput += "- **Lines:** $totalCovered / $totalLinesCount ($overallRate%)"
$mdOutput += ""
$mdOutput += "## Coverage by File"
$mdOutput += ""
$mdOutput += "| Name | Rate | Covered | Missed | Total |"
$mdOutput += "|------|------|---------|--------|-------|"

foreach ($f in $files) {
    $mdLine = "| $($f.Filename.PadRight(50)) | {0:N1}% | {1} | {2} | {3} |" -f $f.Rate, $f.Covered, $f.Missed, $f.Total
    $mdOutput += $mdLine
}

$mdOutput += "| $($("TOTAL".PadRight(50))) | {0:N1}% | {1} | {2} | {3} |" -f $overallRate, $totalCovered, ($totalLinesCount - $totalCovered), $totalLinesCount

$mdOutput | Out-File -FilePath $mdOutputPath -Encoding UTF8

$txtOutputPath = Join-Path $outputDir 'coverage-report.txt'
$txtOutput = @()
$txtOutput += "# Code Coverage Report"
$txtOutput += ""
$txtOutput += "## Summary"
$txtOutput += ""
$txtOutput += "- **Files:** $($files.Count)"
$txtOutput += "- **Lines:** $totalCovered / $totalLinesCount ($overallRate%)"
$txtOutput += ""
$txtOutput += "## Coverage by File"
$txtOutput += ""
$txtOutput += "| Name | Rate | Covered | Missed | Total |"
$txtOutput += "|------|------|---------|--------|-------|"

foreach ($f in $files) {
    $txtLine = "| $($f.Filename.PadRight(50)) | {0:N1}% | {1} | {2} | {3} |" -f $f.Rate, $f.Covered, $f.Missed, $f.Total
    $txtOutput += $txtLine
}

$txtOutput += "| $($("TOTAL".PadRight(50))) | {0:N1}% | {1} | {2} | {3} |" -f $overallRate, $totalCovered, ($totalLinesCount - $totalCovered), $totalLinesCount

$txtOutput | Out-File -FilePath $txtOutputPath -Encoding UTF8

Write-Host '[coverage-report] Reports written to: ' -ForegroundColor Green -NoNewline
Write-Host "$outputDir"