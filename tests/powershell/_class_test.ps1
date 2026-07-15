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
    Write-Output "Module imported OK"
    $obj = New-Object MyTestClass("World")
    Write-Output $obj.Greet()
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
}

# --- Audit.psm1 direct import test ---
$auditPath = "/home/keverall/repos/image-build-automation/powershell/Automation/Private/Audit.psm1"
try {
    Import-Module $auditPath -Force -DisableNameChecking -ErrorAction Stop
    Write-Output "Audit.psm1 imported OK"
    $a = New-Object AuditLogger("UnitTest")
    Write-Output "AuditLogger Category: $($a.Category)"
}
catch {
    Write-Output "Audit import ERROR: $($_.Exception.Message)"
}
