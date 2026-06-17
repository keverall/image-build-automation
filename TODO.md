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

   
   

I have updated the setup script to include `HPEOneView` (version 8.60) in the offline preinstallation list. The script will now look for it in the bundled modules directory and install it locally without needing PSGallery or internet access.

### How to Preinstall `HPEOneView` for the Offline Server

Since the test server is air-gapped, you will need to download the module on a machine with internet access and copy it into the repository. Here is the exact process:

#### Step 1: Download the Module (On a Connected Machine)
Open PowerShell on a machine with internet access and run:
```powershell
# Create a temporary directory
New-Item -ItemType Directory -Force -Path .\temp-modules

# Download HPEOneView and all its dependencies
Save-Module -Name HPEOneView.860 -Path .\temp-modules -Force
```
*Note: This will create a folder like `.\temp-modules\HPEOneView\8.60.xxxx\` (the exact version number will depend on the latest 8.60.x release).*

#### Step 2: Bundle It Into the Repository
1. Navigate to the downloaded folder: `.\temp-modules\HPEOneView\`
2. You will see a folder named with the version number (e.g., `8.60.3915.0`).
3. Copy that **version folder** into your repository at this exact path:
   ```
   image-build-automation/scripts/modules/HPEOneView/<version-folder>/
   ```
   *(Create the `HPEOneView` folder inside `scripts/modules/` if it doesn't exist yet).*

#### Step 3: Transfer to the Offline Server
Commit this change to your repository, or simply copy the entire `scripts/modules/` directory to the offline Windows Server via USB, secure network share, or your preferred air-gap transfer method.

#### Step 4: Run Setup
On the offline Windows Server, run:
```powershell
make setup
```
The script will now detect the bundled `HPEOneView` folder, copy it to the server's PowerShell user module path (`~\Documents\PowerShell\Modules`), and report `[OK] HPEOneView installed from bundled copy`.

### What Changed in the Code
1. Added `@{ Name = 'HPEOneView'; Version = '8.60' }` to the `$REQUIRED_MODULES` array in `scripts/setup-runner.ps1`.
2. Updated the script's header documentation to reflect the new module and the Powerline prompt.
3. Improved the fallback error message to give explicit, copy-pasteable instructions on where to place the module folder if the bundle is ever missing.

This ensures your automation suite is 100% self-contained and ready for strict air-gapped environments.

The setup script has been fully updated to support offline preinstallation of the `OperationsManager` (SCOM) module alongside `HPEOneView`. 

I also enhanced the module detection logic to automatically find and use the highest available version of the module if the exact version string doesn't match. This is crucial for SCOM, as the module version changes depending on whether you are using SCOM 2019 (`10.19.x`), SCOM 2022 (`10.22.x`), etc.

### How to Bundle `OperationsManager` for the Offline Server

Because the `OperationsManager` module is tied to the SCOM console installation and isn't reliably hosted on PSGallery, the best approach is to copy it directly from your SCOM management server or a machine with the SCOM console installed.

#### Step 1: Locate or Copy the Module
On a machine that has the SCOM console installed (or via a network share to the SCOM server), locate the module. It is typically found at:
```powershell
# Common SCOM Console installation path
C:\Program Files\WindowsPowerShell\Modules\OperationsManager
# OR
C:\Program Files\Microsoft System Center\Operations Manager\Powershell\OperationsManager
```
Alternatively, as noted in your `setup-scom.ps1` script, you can copy it from a SCOM server share:
```powershell
# Example from your docs
Copy-Item -Path "\\VR-OPM19P1-7382.ad.example.com\share\OperationsManager" -Destination .\temp-scom -Recurse -Force
```

#### Step 2: Bundle It Into the Repository
1. Inside the copied `OperationsManager` folder, you will see a folder named with the version number (e.g., `10.19.10050.0` or `10.22.x.x`).
2. Copy that **version folder** into your repository at this exact path:
   ```text
   image-build-automation/scripts/modules/OperationsManager/<version-folder>/
   ```
   *(Create the `OperationsManager` folder inside `scripts/modules/` if it doesn't exist yet).*

#### Step 3: Transfer to the Offline Server
Commit this change to your repository, or transfer the updated `scripts/modules/` directory to the offline Windows Server via your approved air-gap transfer method (USB, secure network share, etc.).

#### Step 4: Run Setup
On the offline Windows Server, run:
```powershell
make setup
```

### What the Script Will Do Now
1. It will scan `scripts/modules/OperationsManager/`.
2. Even if you specified `10.19.10050.0` in the config but copied `10.22.1234.0`, the script's new fallback logic will detect the available folder and say:  
   `[WARN] Exact version 10.19.10050.0 of OperationsManager not found. Using available version 10.22.1234.0.`
3. It will copy it to the local PowerShell user module path and report:  
   `[OK] OperationsManager installed from bundled copy`.
4. The setup will complete successfully with zero internet access and zero `.exe` execution blocks.



[WARN] Bundled copy of HPEOneView 8.60 not found. Attempting PSGallery...
[ERROR] Failed to install HPEOneView. Bundled copy not found and PSGallery unavailable (air-gapped).
[ERROR] To fix: Download or copy 'HPEOneView' from a connected machine/SCOM server and place the version folder in:
[ERROR]   scripts/modules/HPEOneView/<version-folder>/
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/)
[WARN] Bundled copy of OperationsManager 10.19.10050.0 not found. Attempting PSGallery...
[ERROR] Failed to install OperationsManager. Bundled copy not found and PSGallery unavailable (air-gapped).
[ERROR] To fix: Download or copy 'OperationsManager' from a connected machine/SCOM server and place the version folder in:
[ERROR]   scripts/modules/OperationsManager/<version-folder>/
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/)



from tech vdi today - 

 make setup                                                                                  0  678ms  09:16:05 
[prune-logs] Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
[setup] Setting up PowerShell environment...

╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup       ║
╚══════════════════════════════════════════════════════════╝

[INFO] PowerShell version: 7.6.2
[OK] PowerShell version check passed
[INFO] Installing PowerShell modules from bundled copies...
[INFO] Pester 5.7.1 already installed and verified
[INFO] PSScriptAnalyzer 1.21.0 already installed and verified
[INFO] PlatyPS 0.14.0 already installed and verified
[WARN] Bundled copy of HPEOneView 8.60 not found. Attempting PSGallery...
[ERROR] Failed to install HPEOneView. Bundled copy not found and PSGallery unavailable (air-gapped).
[ERROR] To fix: Download or copy 'HPEOneView' from a connected machine/SCOM server and place the version folder in:
[ERROR]   scripts/modules/HPEOneView/<version-folder>/
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/)
[WARN] Bundled copy of OperationsManager 10.19.10050.0 not found. Attempting PSGallery...
[ERROR] Failed to install OperationsManager. Bundled copy not found and PSGallery unavailable (air-gapped).
[ERROR] To fix: Download or copy 'OperationsManager' from a connected machine/SCOM server and place the version folder in:
[ERROR]   scripts/modules/OperationsManager/<version-folder>/
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/)
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
[ERROR] HPEOneView NOT FOUND
[ERROR] OperationsManager NOT FOUND
[INFO] Verifying Pester test discovery...
[OK] Found 35 PowerShell test files

╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup Complete   ║
╚══════════════════════════════════════════════════════════╝

  Project root: C:\Users\98253\repos\image-build-automation
  Log file:     C:\Users\98253\AppData\Local\Temp\hpe-automation-pwsh-setup-20260617-092005.log

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
[setup] Microsoft.PowerShell_profile.ps1 already contains Automation module
[setup] Microsoft.PowerShell_profile.ps1 already contains Automation module
[setup] psprofile.ps1 already contains Automation module
[setup] vscodeprofile.ps1 already contains Automation module

[setup] ✓ Profile configuration complete
[setup] Restart your PowerShell session or run '. $PROFILE' to load

# Note: checkmake installation is now handled gracefully by setup-runner.ps1


on test server -


make setup
"[prune-logs] Pruning old log files..."
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
"[setup] Setting up PowerShell environment..."
 
╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup       ║
╚══════════════════════════════════════════════════════════╝

[INFO] PowerShell version: 7.4.6
[OK] PowerShell version check passed
[INFO] Installing PowerShell modules from bundled copies...
[INFO] Pester 5.7.1 already installed and verified 
[INFO] PSScriptAnalyzer 1.21.0 already installed and verified 
[INFO] PlatyPS 0.14.0 already installed and verified 
[WARN] Bundled copy of HPEOneView 8.60 not found. Attempting PSGallery... 
[ERROR] Failed to install HPEOneView. Bundled copy not found and PSGallery unavailable (air-gapped). 
[ERROR] To fix: Download or copy 'HPEOneView' from a connected machine/SCOM server and place the version folder in: 
[ERROR]   scripts/modules/HPEOneView/<version-folder>/ 
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/) 
[WARN] Bundled copy of OperationsManager 10.19.10050.0 not found. Attempting PSGallery... 
[ERROR] Failed to install OperationsManager. Bundled copy not found and PSGallery unavailable (air-gapped). 
[ERROR] To fix: Download or copy 'OperationsManager' from a connected machine/SCOM server and place the version folder in: 
[ERROR]   scripts/modules/OperationsManager/<version-folder>/ 
[ERROR]   (Example: scripts/modules/OperationsManager/10.19.10050.0/) 
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
[WARN] Failed to download checkmake: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond. (github.com:443)
[WARN] To install offline: Download checkmake-0.2.2.windows.amd64 from https://github.com/mrtazz/checkmake/releases 
[WARN] and place it in 'C:\Products\repos\image-build-automation\bin\checkmake.exe' 
[INFO] Verifying PowerShell tools... 
[OK] Pester 5.7.1 
[OK] PSScriptAnalyzer 1.21.0 
[OK] PlatyPS 0.14.0 
[ERROR] HPEOneView NOT FOUND 
[OK] OperationsManager 1.0 
[INFO] Verifying Pester test discovery... 
[OK] Found 35 PowerShell test files 
 
╔══════════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation — PowerShell Setup Complete   ║ 
╚══════════════════════════════════════════════════════════╝

  Project root: C:\Products\repos\image-build-automation
  Log file:     C:\Users\ADM_98~2\AppData\Local\Temp\15\hpe-automation-pwsh-setup-20260617-100804.log

To run PowerShell tests:
    cd C:\Products\repos\image-build-automation 
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
[setup] Microsoft.PowerShell_profile.ps1 already contains Automation module 
[setup] Microsoft.PowerShell_profile.ps1 already contains Automation module 
[setup] psprofile.ps1 already contains Automation module
[setup] vscodeprofile.ps1 already contains Automation module 

[setup] ✓ Profile configuration complete
[setup] Restart your PowerShell session or run '. $PROFILE' to load

# Note: checkmake installation is now handled gracefully by setup-runner.ps1 
process_begin: CreateProcess(NULL, # Note: checkmake installation is now handled gracefully by setup-runner.ps1, ...) failed. 
make (e=2): The system cannot find the file specified. 
make: *** [setup] Error 2


(If make is still acting up, run the scripts directly: pwsh -File scripts/setup-runner.ps1 followed by pwsh -File scripts/Setup-Profile.ps1)
Restart your PowerShell session or run . $PROFILE to load the updated profile with the corrected path.
Step 4: Verify Powerline Prompt The fallback prompt uses Nerd Font Unicode characters (, ). If these render as empty boxes, squares, or question marks on the test server, configure your terminal emulator (Windows Terminal, VS Code, etc.) to use a Nerd Font (e.g., "Cascadia Code NF" or "MesloLGS NF") in its font settings. The prompt logic itself is now correctly injected and functional.