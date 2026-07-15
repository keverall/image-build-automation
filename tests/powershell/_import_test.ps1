$ErrorActionPreference = 'Stop'
$AbsPath = (Resolve-Path (Join-Path $PSScriptRoot '../../src/powershell/Automation/Automation.psd1')).Path
Write-Output "Module path: $AbsPath"

try {
    Import-Module $AbsPath -Force -ErrorAction Stop -DisableNameChecking
    Write-Output 'Module imported OK'
} catch {
    Write-Output "FAILED to import: $($_.Exception.Message)"
    exit 1
}

# Test each key exported function (CLI scripts are entry points, not module functions)
$tests = @(
    'Initialize-Logging',
    'Get-Logger',
    'Import-JsonConfig',
    'Get-IloCredentials',
    'Get-ScomCredentials',
    'Load-ServerList',
    'Load-ClusterCatalogue',
    'New-AuditLogger',
    'New-ServerInfo',
    'Ensure-DirectoryExists',
    'Save-Json',
    'Load-Json',
    'New-CommandResult',
    'Invoke-NativeCommand',
    'Invoke-NativeCommandWithRetry',
    'Test-ClusterId',
    'Test-ServerList',
    'Test-BuildParams',
    'Invoke-RoutedRequest',
    'New-ScomConnection',
    'New-ScomMaintenanceScript',
    'Invoke-PowerShellScript',
    'Invoke-PowerShellWinRM',
    'New-AutomationBase',
    'New-Uuid'
)
$ok = 0; $fail = 0
foreach ($fn in $tests) {
    $found = Get-Command $fn -ErrorAction SilentlyContinue
    if ($found) { Write-Output "  OK: $fn"; $ok++ }
    else         { Write-Output "  MISSING: $fn"; $fail++ }
}
Write-Output "`nSummary: $ok OK, $fail MISSING"
if ($fail -gt 0) { exit 1 } else { exit 0 }
