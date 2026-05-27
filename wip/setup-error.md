#errors 

pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/setup-runner.ps1

╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup       ║
╚══════════════════════════════════════════════════════════╝

[INFO] PowerShell version: 7.6.2
[OK] PowerShell version check passed
[INFO] Configuring PowerShell Gallery...
[INFO] Pester 5.0.0 already installed
[INFO] PSScriptAnalyzer 1.24.0 already installed
[INFO] PlatyPS 0.14.0 already installed
[INFO] Updating PowerShell help...
[OK] Help updated                                                                                       
WriteError: C:\Users\98253\repos\image-build-automation\scripts\setup-runner.ps1:100:5
Line |
 100 |      $isWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersio …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Cannot overwrite variable IsWindows because it is read-only or constant.