$ErrorActionPreference = 'Stop'
$AbsPath = (Resolve-Path 'powershell/Automation/Automation.psd1').Path
Write-Host "Module path: $AbsPath"

try {
    Import-Module $AbsPath -Force -ErrorAction Stop -DisableNameChecking
    Write-Host 'Module imported OK'
} catch {
    Write-Host "FAILED to import: $($_.Exception.Message)"
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
    'Test-Uuid'
)
$ok = 0; $fail = 0
foreach ($fn in $tests) {
    $found = Get-Command $fn -ErrorAction SilentlyContinue
    if ($found) { Write-Host "  OK: $fn"; $ok++ }
    else         { Write-Host "  MISSING: $fn"; $fail++ }
}
Write-Host "`nSummary: $ok OK, $fail MISSING"
if ($fail -gt 0) { exit 1 } else { exit 0 }
