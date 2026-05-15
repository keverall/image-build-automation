$ErrorActionPreference = 'Stop'

# --- Minimal class definition test ---
$code = @'
class MyTestClass {
    [string] $Name
    MyTestClass([string] $n) { $this.Name = $n }
    [string] Greet() { return "Hello $($this.Name)" }
}
'@
$tmp = "$env:TEMP\classtest.psm1"
$code | Set-Content $tmp -Encoding UTF8

try {
    Import-Module $tmp -Force -ErrorAction Stop
    Write-Host "Module imported OK"
    $obj = New-Object MyTestClass("World")
    Write-Host $obj.Greet()
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}

# --- Audit.psm1 direct import test ---
$auditPath = "/home/keverall/repos/image-build-automation/powershell/Automation/Private/Audit.psm1"
try {
    Import-Module $auditPath -Force -DisableNameChecking -ErrorAction Stop
    Write-Host "Audit.psm1 imported OK"
    $a = New-Object AuditLogger("UnitTest")
    Write-Host "AuditLogger Category: $($a.Category)"
}
catch {
    Write-Host "Audit import ERROR: $($_.Exception.Message)"
}
