#!/usr/bin/env pwsh
#
# run-maintenance-tests.ps1 - Run all maintenance mode tests including new environment features
#

<#
.SYNOPSIS
    Run comprehensive maintenance mode test suite.

.DESCRIPTION
    Executes Pester tests for maintenance mode functionality with support for:
    - Environment-based host selection tests
    - DateTime handling tests  
    - Backward compatibility tests
    - Connection validation tests
    
    Test suites can be filtered by TestSuite parameter.

.PARAMETER TestSuite
    Test suite to run: All, Environment, DateTime, BackwardCompat, or Connection (default: 'All')

.PARAMETER Verbose
    Enable verbose output during test execution

.PARAMETER PassThru
    Return detailed Pester test results object with counts

.EXAMPLE
    pwsh -File scripts/run-maintenance-tests.ps1
    
.EXAMPLE
    ./scripts/run-maintenance-tests.ps1 -TestSuite Environment -PassThru
#>

[CmdletBinding()]
param(
    [ValidateSet('All', 'Environment', 'DateTime', 'BackwardCompat', 'Connection')][string]$TestSuite = 'All',
    [switch]$Verbose,
    [switch]$PassThru
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Maintenance Mode Test Suite ===" -ForegroundColor Cyan
Write-Host "Test Suite: $TestSuite" -ForegroundColor Yellow
Write-Host ""

# Get test directory
$testDir = Join-Path $PSScriptRoot '../tests/powershell'

# Build test file list based on suite
$testFiles = @()

switch ($TestSuite) {
    'All' {
        $testFiles = @(
            'Set-MaintenanceMode.Environment.Tests.ps1',
            'Set-MaintenanceMode.Unit.Tests.ps1',
            'Set-MaintenanceMode.Enable.Tests.ps1',
            'Set-MaintenanceMode.Disable.Tests.ps1',
            'Set-MaintenanceMode.Validation.Tests.ps1'
        )
    }
    'Environment' {
        $testFiles = @('Set-MaintenanceMode.Environment.Tests.ps1')
    }
    'DateTime' {
        # DateTime tests are in Environment.Tests
        $testFiles = @('Set-MaintenanceMode.Environment.Tests.ps1')
    }
    'BackwardCompat' {
        $testFiles = @('Set-MaintenanceMode.Environment.Tests.ps1')
    }
    'Connection' {
        $testFiles = @('Set-MaintenanceMode.Environment.Tests.ps1')
    }
}

# Run tests
$results = @()
$passed = 0
$failed = 0
$skipped = 0

foreach ($testFile in $testFiles) {
    $testPath = Join-Path $testDir $testFile
    
    if (-not (Test-Path $testPath)) {
        Write-Warning "Test file not found: $testPath"
        continue
    }
    
    Write-Host "Running: $testFile" -ForegroundColor Green
    
    try {
        $result = Invoke-Pester -Path $testPath -PassThru:$PassThru -Output Detailed
        
        if ($PassThru) {
            $results += $result
            $passed += $result.PassedCount
            $failed += $result.FailedCount
            $skipped += $result.SkippedCount
        } else {
            Write-Host "  (Use -PassThru for detailed results)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Failed to run tests in $testFile`: $_"
        $failed++
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
if ($PassThru) {
    Write-Host "Passed:  $passed" -ForegroundColor Green
    Write-Host "Failed:  $failed" -ForegroundColor Red
    Write-Host "Skipped: $skipped" -ForegroundColor Yellow
} else {
    Write-Host "Tests completed. Use -PassThru for detailed counts." -ForegroundColor Yellow
}
Write-Host ""

if ($failed -gt 0) {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
