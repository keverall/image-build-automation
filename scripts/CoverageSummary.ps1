# =============================================================================
# CoverageSummary.ps1 - Convert Cobertura XML coverage to human-readable table
# =============================================================================

<#
.SYNOPSIS
    Generate human-readable coverage summary from Cobertura XML.

.DESCRIPTION
    Parses Cobertura XML coverage file and generates formatted table showing:
    - Per-file coverage statistics (rate, covered lines, missed lines)
    - Overall coverage summary
    - Output to both console and text file
    
    Default input: coverage-results.xml
    Default output: coverage-report.txt

.PARAMETER InputFile
    Path to Cobertura XML coverage file (default: coverage-results.xml)

.PARAMETER OutputFile
    Path for text report output (default: coverage-report.txt)

.EXAMPLE
    pwsh -File scripts/CoverageSummary.ps1
    
.EXAMPLE
    ./scripts/CoverageSummary.ps1 -InputFile 'custom.xml' -OutputFile 'summary.txt'
#>

param(
    [string]$InputFile = "coverage-results.xml",
    [string]$OutputFile = "coverage-report.txt"
)

if (-not (Test-Path $InputFile)) {
    Write-Error "Coverage file not found: $InputFile"
    exit 1
}

[xml]$xml = Get-Content $InputFile
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

$output | Write-Output

$output | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "[coverage] Report written to: $OutputFile" 2>&1

return @{
    Rate = $overallRate
    Covered = $totalCovered
    Total = $totalLines
    Output = $OutputFile
}