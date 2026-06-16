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


 make  maint-mode-tests
process_begin: CreateProcess(NULL, pwd, ...) failed.
process_begin: CreateProcess(NULL, printf \033, ...) failed.
"[0;36m[prune-logs][0m Pruning old log files..." 
[prune-logs] Pruning logs to keep maximum 10 per type... 
[prune-logs] Pruned 0 excess log files. 
Add-Type: Cannot bind parameter 'Path' to the target. Exception setting "Path": "Cannot find path 
'C:\Users\adm_98253\Documents\PowerShell\Modules\Pester\5.7.1\bin\netstandard2.0\Pester.dll' because it does not exist." 
make: *** [maint-mode-tests] Error 1 






alponeview01                        LibraryVersion Path
------------                        -------------- ----
ApplianceVersion: 9.40.00.505610.00 9.0.4020.1622  C:\Users\98253\Documents\PowerShell\Modules\HPEOneView.900\9.0…

     image-build-automation  main  Get-HPEOVersion^C                                              0  12:36:34 
     image-build-automation  main  Disconnect-OVMgmt                                              0  12:44:40 
     image-build-automation  main  Get-OVVersion                                                  0  12:44:45 

alponeview01                        LibraryVersion Path
------------                        -------------- ----
ApplianceVersion: 9.40.00.505610.00 9.0.4020.1622  C:\Users\98253\Documents\PowerShell\Modules\HPEOneView.900\9.0…

     image-build-automation  main                                                                 


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
Save-Module -Name HPEOneView -Path .\temp-modules -Force
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