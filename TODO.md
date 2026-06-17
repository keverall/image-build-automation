If your code isn't a live listening web server, iRequest cannot directly "call" your PowerShell file over the network without a middleman protocol.
Since your target environment is a unified Windows Test Jumpbox containing CI, SCOM, HPE iLO, and iLO modules, you actually have the perfect infrastructure already in place. You do not need the two systems running on the same OS, nor do you need to configure complex low-level Windows Networking (like SMB or WinRM).
Instead, you use the CI pipeline as your API Gateway.
------------------------------
## The Architecture: How They Interact
Instead of iRequest trying to execute code on a filesystem, iRequest makes a standard HTTPS webhook call to the CI pipeline, which executes your local script.

iRequest —   HTTPS POST   → CI Pipeline —   Native Execution   → PowerShell Codebase —  HPE iLO / SCOM

------------------------------
## The 3 Ways to Connect iRequest to Your PowerShell Code
Depending on how iRequest is configured by your identity/portal team, you will use one of these three standard connection protocols: [1]

## Option A: The CI Web API (The Easiest & Safest Way)
CI pipelines have a built-in REST API out of the box. You do not write any API listening code in PowerShell.

   1. iRequest fires a standard HTTPS POST request to your CI server jumpbox.
   2. The payload targets a trigger pipeline endpoint with the CI-specific URL format.
   3. CI receives the variables (e.g., $ImageName, $VMSpec), spins up your PowerShell repository, and passes those variables straight into your .ps1 script arguments.

## Option B: Windows Remote Management (WinRM)
If iRequest is a classic enterprise platform (like ServiceNow, Micro Focus, or an older internal portal) and must trigger a script directly on a target server:

   1. Both servers must talk over your internal Windows Domain Network.
   2. iRequest uses the WinRM protocol (Ports 5985/5986).
   3. It uses a service account to execute a remote command:
    Invoke-Command -ComputerName "Your-Jumpbox" -ScriptBlock { C:\repos\automation\scripts\build.ps1 -Param1 "Value" }
    
## Option C: SCOM Alert/Event Database Drop (Decoupled Integration)
If iRequest doesn't support active, outbound network connections:

   1. iRequest can drops a specific log event or registry key changes to a server monitored by SCOM.
   2. SCOM detects this flag state change and triggers a "Management Pack Recovery Action".
   3. This native SCOM engine hook launches your local execution script on the jumpbox runner.

------------------------------
## What This Means for Your API Documentation
Since the CI pipeline acts as your actual HTTP entry gateway, the documentation format we discussed earlier fits perfectly.
When you write your single-page OpenAPI/Swagger document, you aren't documenting raw PowerShell paths—you are documenting the CI API Endpoints that wrap them.
Your Swagger JSON file parameters map directly to your CI pipeline trigger variables:

{
  "openapi": "3.0.3",
  "paths": {
    "/api/v4/projects/{id}/trigger/pipeline": {
      "post": {
        "summary": "Invokes the HPE iLO configuration loop via iRequest",
        "parameters": [
          { "name": "TargetServerIP", "in": "formData", "required": true },
          { "name": "FirmwareVersion", "in": "formData", "required": false }
        ]
      }
    }
  }
}

## Recommendation for Your Test Jumpbox
Since you have everything co-located on that test jumpbox right now, start with Option A (CI Web API). It keeps your PowerShell code entirely pure, lets the CI pipeline handle the security tokens, and creates a clear, web-addressable API target that iRequest can hit easily.
Do you know if your iRequest platform prefers calling REST Webhooks (HTTP POST), or does it typically use Mid-Server orchestrators to run native Windows commands?

[1] https://www.reddit.com/r/PowerShell/comments/gdf401/run_scripts_simultaneously_on_different_servers/
[2] https://www.youtube.com/watch?v=roqtA8JRKzU&t=283




 2       10.986 uninstall-module HPEOneView.1000 -force
   3        0.137 remove-module HPEOneView.1000
   4       13.049 Install-Module HPEOneView.900
   5       11.103 Install-Module HPEOneView.900 -AllowClobber
   6        2.310 import-module HPEOneView.900
   7        0.333 remove-module HPEOneView.1000
   8       45.914 Connect-OVMgmt
   9       37.533 Connect-OVMgmt
  10        0.376 Get-HPEOVVersion
  11        0.252 Get-HPEOVersion
  12        0.030 get-command -module HPOneView.900
  13        0.014 Get-Command -module HPOneView.900
  14        2.327 Get-Command -module HPEOneView.900
  15        0.443 Get-OVUser  
  16        0.112 Get-OVVersion 
  17        0.235 Disconnect-OVMgmt
  18        0.387 Get-OVVersion 

  install-module HPOneView.860  -scope currentuser

   
   make setup
[prune-logs] Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
[setup] Setting up PowerShell environment...

╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup       ║
╚══════════════════════════════════════════════════════════╝

[INFO] PowerShell version: 7.6.3
[OK] PowerShell version check passed
[INFO] Installing PowerShell modules from bundled copies...
[INFO] Pester 5.7.1 already installed and verified
[INFO] PSScriptAnalyzer 1.21.0 already installed and verified
[INFO] PlatyPS 0.14.0 already installed and verified
[WARN] Exact version 8.60 of HPEOneView.860 not found. Using available version 8.60.3997.3057.
[INFO] Installing HPEOneView.860 8.60 from bundled copy...
[OK] HPEOneView.860 installed from bundled copy
[WARN] OperationsManager 1.0 found but failed to import (possibly corrupted), reinstalling...
[INFO] Removed corrupted OperationsManager installation
[WARN] Bundled copy of OperationsManager 1.0 not found. Attempting PSGallery...
[ERROR] Failed to install OperationsManager. Bundled copy not found and PSGallery unavailable (air-gapped).
[ERROR] To fix: Download or copy 'OperationsManager' from a connected machine/SCOM server and place the version folder in:
[ERROR]   scripts/modules/OperationsManager/<version-folder>/
[ERROR]   (Example: scripts/modules/OperationsManager/10.22.1234.0/)
[INFO] Skipping Update-Help (offline mode)
[WARN] Oh My Posh binary not found in bin/. Skipping.
[WARN] NOTE: If .exe execution is blocked by admin policy (e.g., AppLocker), using 'git clone' will NOT bypass this,
[WARN]       because compiling from source still produces an .exe file. To use Oh My Posh, you must either:
[WARN]       1. Download oh-my-posh.exe and place it in the project's 'bin/' folder (if your IT policy allows it).
[WARN]       2. Request an IT exception for the oh-my-posh executable.
[WARN]       3. Use a pure PowerShell custom prompt (no .exe required) by adding a prompt function to your $PROFILE.
[INFO] Detecting make for Windows...
[INFO] make already available: GNU Make 3.81
[OK] make version check passed
[INFO] Checking for checkmake (Makefile linting)...
[INFO] Downloading checkmake v0.2.2 for windows/amd64...
[WARN] Failed to download checkmake: Response status code does not indicate success: 404 (Not Found).                   
[WARN] To install offline: Download checkmake-0.2.2.windows.amd64 from https://github.com/mrtazz/checkmake/releases
[WARN] and place it in 'C:\Users\98253\repos\image-build-automation\bin\checkmake.exe'
[INFO] Verifying PowerShell tools...
[OK] Pester 5.7.1
[OK] PSScriptAnalyzer 1.21.0
[OK] PlatyPS 0.14.0
[ERROR] HPEOneView.860 NOT FOUND
[ERROR] OperationsManager NOT FOUND
[INFO] Verifying Pester test discovery...
[OK] Found 35 PowerShell test files

╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup Complete   ║
╚══════════════════════════════════════════════════════════╝

  Project root: C:\Users\98253\repos\image-build-automation
  Log file:     C:\Users\98253\AppData\Local\Temp\hpe-automation-pwsh-setup-20260617-112116.log

To run PowerShell tests:
    cd C:\Users\98253\repos\image-build-automation
    pwsh -File scripts/run-tests.ps1

To lint PowerShell files:
    pwsh -NoProfile -Command 'Invoke-ScriptAnalyzer -Path src/powershell -Recurse'

Makefile targets:
    make setup      # Run this setup script
    make test       # Run all Pester tests
    make lint       # Lint PowerShell with PSScriptAnalyzer
    make coverage   # Run tests with code coverage
    make clean      # Remove build artifacts

[OK] Setup complete!
[setup] Configuring PowerShell profiles with Automation module...
[setup] Found 4 profile(s) to update
[setup] Updating Automation module path in Microsoft.PowerShell_profile.ps1...
[setup] ✓ Updated in Microsoft.PowerShell_profile.ps1
[setup] Updating Automation module path in Microsoft.PowerShell_profile.ps1...
[setup] ✓ Updated in Microsoft.PowerShell_profile.ps1
[setup] Updating Automation module path in psprofile.ps1...
[setup] ✓ Updated in psprofile.ps1
[setup] Updating Automation module path in vscodeprofile.ps1...
[setup] ✓ Updated in vscodeprofile.ps1

[setup] ✓ Profile configuration complete
[setup] Restart your PowerShell session or run '. $PROFILE' to load