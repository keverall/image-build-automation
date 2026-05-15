$ErrorActionPreference = 'Stop'

$code = @"
class MyTestClass {
    [string] `$Name
    MyTestClass() { }
    [string] Greet() { return 'Hi' }
}
"@
$tmp = '/tmp/classtest_final.psm1'
Set-Content -Path $tmp -Value $code -Encoding UTF8 -Force

try {
    Import-Module $tmp -Force
    Write-Host "IMPORT OK"
    $obj = New-Object MyTestClass
    Write-Host "GREET: $($obj.Greet())"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.PSObject.Properties) { $_.Exception | Format-List * }
}

# Also check the test I expect to see
Write-Host "Script end"
