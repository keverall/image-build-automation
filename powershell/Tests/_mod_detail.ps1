$ErrorActionPreference = 'Stop'

$p = '/home/keverall/repos/image-build-automation/powershell/Automation/Automation.psd1'
Import-Module $p -Force -DisableNameChecking

# Check module
$m = Get-Module 'Automation'
"Module loaded: $($null -ne $m)"
"Module base: $($m.ModuleBase)"
"Exported Fns count: $($m.ExportedFunctions.Count)"

# List the first 10 exported functions if any
$m.ExportedFunctions.Keys | Sort-Object | Select-Object -First 10 | ForEach-Object { "  Exported: $_" }

# Check if dot-sourcing runs at all — write a sentinel file
$sentinel = '/tmp/ps_sentinel.txt'
Remove-Item $sentinel -ErrorAction SilentlyContinue
$psm1Content = Get-Content $m.ModuleBase + '\Automation.psm1'
"PSM1 line count: $($psm1Content.Count)"

# Try to call a function that should exist
try {
    $result = Import-JsonConfig -Path '/tmp/nonexistent.json' -Required $false
    "Import-JsonConfig returned: $(if($result){'non-null'}else{'empty'})"
} catch {
    "Import-JsonConfig threw: $($_.Exception.Message)"
}
