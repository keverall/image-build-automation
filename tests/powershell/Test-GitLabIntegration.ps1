#
# Test-GitLabIntegration.ps1 - Unit tests for GitLab maintenance callback mechanism
#
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot    = (Resolve-Path (Join-Path $scriptRoot '..' '..' 'src' 'powershell' 'Automation')).ProviderPath

# Import the Automation module which now includes Control.ps1

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../src/powershell/Automation')
Import-Module (Join-Path $repoRoot 'Automation.psd1') -Force

$testResults = @{
    passed = 0
    failed = 0
    tests = @()
}

function Test-Assert {
    param(
        [scriptblock] $Condition,
        [string] $Message,
        [string] $TestName
    )

    $testResults.tests += $TestName

    try {
        $result = & $Condition
        if ($result) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $testResults.passed++
        } else {
            Write-Host "✗ FAIL: $TestName - $Message" -ForegroundColor Red
            $testResults.failed++
        }
    } catch {
        Write-Host "✗ ERROR: $TestName - $($_.Exception.Message)" -ForegroundColor Red
        $testResults.failed++
    }
}

# Test 1: RouteMap contains gitlab_maintenance
Test-Assert -TestName "RouteMap - gitlab_maintenance" -Message "Should have gitlab_maintenance route" {
    (Get-RouteMap).ContainsKey('gitlab_maintenance')
}

# Test 2: RouteMap maps to correct handler
Test-Assert -TestName "RouteMap - Handler Mapping" -Message "Should map to Invoke-GitLabMaintenanceTrigger" {
    (Get-RouteMap)['gitlab_maintenance'] -eq 'Invoke-GitLabMaintenanceTrigger'
}

# Test 3: Control module has Run-GitLab function
Test-Assert -TestName "Control - Run-GitLab Exists" -Message "Should have Run-GitLab function" {
    $func = Get-Command Run-GitLab -ErrorAction SilentlyContinue
    $null -ne $func
}

# Test 4: Control module has New-GitLabCtrl function
Test-Assert -TestName "Control - New-GitLabCtrl Exists" -Message "Should have New-GitLabCtrl function" {
    $func = Get-Command New-GitLabCtrl -ErrorAction SilentlyContinue
    $null -ne $func
}

# Test 5: New-GitLabCtrl returns correct structure
Test-Assert -TestName "New-GitLabCtrl - Structure" -Message "Should return correct property types" {
    $ctrl = New-GitLabCtrl -Params @{ ClusterId = 'test-cluster'; Action = 'enable' }
    $ctrl.RequestType -eq 'gitlab_maintenance' -and $ctrl.Source -eq 'gitlab'
}

# Test 6: Invoke-GitLabMaintenanceTrigger script exists
Test-Assert -TestName "Invoke-GitLabMaintenanceTrigger - Exists" -Message "Handler script should exist" {
    Test-Path (Join-Path $repoRoot 'Public/Invoke-GitLabMaintenanceTrigger.ps1')
}

# Test 7: Invoke-GitLabMaintenance script exists (GitLab CI entry point)
Test-Assert -TestName "Invoke-GitLabMaintenance - Exists" -Message "GitLab CI entry point should exist" {
    Test-Path '/home/keverall/repos/image-build-automation/scripts/gitlab/Invoke-GitLabMaintenance.ps1'
}

# Test 8: Send-GitLabMaintenanceRequest script exists (iRequest caller)
Test-Assert -TestName "Send-GitLabMaintenanceRequest - Exists" -Message "iRequest caller should exist" {
    Test-Path '/home/keverall/repos/image-build-automation/scripts/gitlab/Send-GitLabMaintenanceRequest.ps1'
}

# Test 9: .gitlab-ci.yml exists
Test-Assert -TestName "GitLab CI Config - Exists" -Message ".gitlab-ci.yml should exist" {
    Test-Path (Resolve-Path (Join-Path $scriptRoot '..' '..' '.gitlab-ci.yml')).ProviderPath
}

# Test 10: request_types.json contains gitlab_maintenance
Test-Assert -TestName "request_types.json - gitlab_maintenance" -Message "Should have gitlab_maintenance entry" {
    $configPath = '/home/keverall/repos/image-build-automation/configs/request_types.json'
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $config.request_types.gitlab_maintenance -ne $null
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.failed)" -ForegroundColor ($testResults.failed -gt 0 ? 'Red' : 'Green')
Write-Host "Total:  $($testResults.tests.Count)"

exit $(if ($testResults.failed -gt 0) { 1 } else { 0 })

# vim: ts=4 sw=4 et