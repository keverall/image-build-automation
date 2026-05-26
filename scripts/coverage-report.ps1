# =============================================================================
# HPE ProLiant Windows Server ISO Automation — PowerShell Coverage Report
# =============================================================================
# Generates Cobertura XML code coverage reports using Pester.
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
$config.Output.Verbosity = 'None'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @($sourcePath)
$config.CodeCoverage.OutputPath = $outputPath
$config.CodeCoverage.OutputFormat = 'Cobertura'

$envName = if ([string]::IsNullOrWhiteSpace($env:ENVIRONMENT)) { 'testing' } else { $env:ENVIRONMENT }
$logDir = Join-Path $PROJECT_ROOT "generated/logs/$envName"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

$pesterLogPath = Join-Path $logDir "pester_test_results_$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ').log"
Write-Host "[coverage-report] Running Pester tests... (Detailed log: $pesterLogPath)" -ForegroundColor Cyan
Invoke-Pester -Configuration $config *> $pesterLogPath

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
$totalLines = ($files | Measure-Object -Property Total -Sum).Sum
$overallRate = if ($totalLines -gt 0) { [math]::Round(($totalCovered / $totalLines) * 100, 1) } else { 0 }

Write-Host ''
Write-Host '========================================'
Write-Host '[coverage-report] Code Coverage Summary'
Write-Host "  Files: $($files.Count)"
Write-Host "  Lines: $totalCovered / $totalLines ($overallRate%)"
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
            ($totalLines - $totalCovered).ToString().PadLeft(8) + " | " +
            $totalLines.ToString().PadLeft(6))
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
$mdOutput += "- **Lines:** $totalCovered / $totalLines ($overallRate%)"
$mdOutput += ""
$mdOutput += "## Coverage by File"
$mdOutput += ""
$mdOutput += "| Name | Rate | Covered | Missed | Total |"
$mdOutput += "|------|------|---------|--------|-------|"

foreach ($f in $files) {
    $mdLine = "| $($f.Filename.PadRight(50)) | {0:N1}% | {1} | {2} | {3} |" -f $f.Rate, $f.Covered, $f.Missed, $f.Total
    $mdOutput += $mdLine
}

$mdOutput += "| $($("TOTAL".PadRight(50))) | {0:N1}% | {1} | {2} | {3} |" -f $overallRate, $totalCovered, ($totalLines - $totalCovered), $totalLines

$txtOutputPath = Join-Path $outputDir 'coverage-report.txt'
$txtOutput = @()
$txtOutput += "# Code Coverage Report"
$txtOutput += ""
$txtOutput += "## Summary"
$txtOutput += ""
$txtOutput += "- **Files:** $($files.Count)"
$txtOutput += "- **Lines:** $totalCovered / $totalLines ($overallRate%)"
$txtOutput += ""
$txtOutput += "## Coverage by File"
$txtOutput += ""
$txtOutput += "| Name | Rate | Covered | Missed | Total |"
$txtOutput += "|------|------|---------|--------|-------|"

foreach ($f in $files) {
    $txtLine = "| $($f.Filename.PadRight(50)) | {0:N1}% | {1} | {2} | {3} |" -f $f.Rate, $f.Covered, $f.Missed, $f.Total
    $txtOutput += $txtLine
}

$txtOutput += "| $($("TOTAL".PadRight(50))) | {0:N1}% | {1} | {2} | {3} |" -f $overallRate, $totalCovered, ($totalLines - $totalCovered), $totalLines

$txtOutput | Out-File -FilePath $txtOutputPath -Encoding UTF8

Write-Host '[coverage-report] Reports written to: ' -ForegroundColor Green -NoNewline
Write-Host "$outputDir"