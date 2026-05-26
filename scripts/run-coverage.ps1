# =============================================================================
# Run-Coverage.ps1 - Run Pester tests with code coverage
# =============================================================================
param(
    [string]$TestPath = "tests/powershell",
    [string]$SourcePath = "src/powershell",
    [string]$OutputFile = "generated/output/coverage/coverage-results.xml",
    [double]$Threshold = 70
)

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$config = New-PesterConfiguration
$config.Run.Path = @($TestPath)
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = 'Auto'

$outputDir = Split-Path -Parent $OutputFile
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @($SourcePath)
$config.CodeCoverage.OutputPath = $OutputFile
$config.CodeCoverage.OutputFormat = 'Cobertura'

Invoke-Pester -Configuration $config

if (Test-Path $OutputFile) {
    [xml]$xml = Get-Content $OutputFile
    $totalLines = [int]$xml.coverage.'lines-valid'
    $coveredLines = [int]$xml.coverage.'lines-covered'
    $percent = if ($totalLines -gt 0) { [math]::Round(($coveredLines / $totalLines) * 100, 2) } else { 0 }
} else {
    $coveredLines = 0
    $totalLines = 0
    $percent = 0
}

Write-Host ''
Write-Host '========================================'
Write-Host '[coverage] Results:'
Write-Host "  Covered commands: $coveredLines / $totalLines"
Write-Host "  Coverage: $percent%"
Write-Host '========================================'

if ($percent -lt $Threshold) {
    Write-Host "[coverage] ERROR: Coverage $percent% is below threshold $Threshold%"
    exit 1
} else {
    Write-Host "[coverage] SUCCESS: Coverage meets threshold"
}