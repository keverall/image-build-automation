If your code isn’t a live listening web server, iRequest cannot directly "call" your PowerShell file over the network without a middleman protocol.
Since your target environment is a unified Windows Test Jumpbox containing Jenkins, SCOM, HPE iLO, and iLO modules, you actually have the perfect infrastructure already in place. You do not need the two systems running on the same OS, nor do you need to configure complex low-level Windows Networking (like SMB or WinRM).
Instead, you use Jenkins as your API Gateway.
------------------------------
## 🔀 The Architecture: How They Interact
Instead of iRequest trying to execute code on a filesystem, iRequest makes a standard HTTPS webhook call to Jenkins, and Jenkins executes your local script.

┌────────────┐               🟢 HTTPS POST             ┌─────────────┐
│  iRequest  │ ──────────────────────────────────────► │   Jenkins   │
└────────────┘   (Sends JSON parameters over Web)      └──────┬──────┘
                                                              │
                                                              │ 🔵 Native Execution 
                                                              ▼ (Local Context)
                                                      ┌─────────────┐
                                                      │ PowerShell  │ ──► HPE iLO / SCOM
                                                      │ Codebase    │
                                                      └─────────────┘

------------------------------
## 🌐 The 3 Ways to Connect iRequest to Your PowerShell Code
Depending on how iRequest is configured by your identity/portal team, you will use one of these three standard connection protocols: [1] 
## Option A: The Jenkins Web API (The Easiest & Safest Way)
Jenkins has a built-in REST API out of the box. You do not write any API listening code in PowerShell.

   1. iRequest fires a standard HTTPS POST request to your Jenkins server jumpbox.
   2. The payload targets a parameterized job URL: https://your-jumpbox:8080/job/Trigger-ImageBuild/buildWithParameters?TOKEN=SecretToken
   3. Jenkins receives the variables (e.g., $ImageName, $VMSpec), spins up your PowerShell repository, and passes those variables straight into your .ps1 script arguments.

## Option B: Windows Remote Management (WinRM)
If iRequest is a classic enterprise platform (like ServiceNow, Micro Focus, or an older internal portal) and must trigger a script directly on a target server:

   1. Both servers must talk over your internal Windows Domain Network.
   2. iRequest uses the WinRM protocol (Ports 5985/5986).
   3. It uses a service account to execute a remote command:
   
   Invoke-Command -ComputerName "Your-Jumpbox" -ScriptBlock { C:\repos\automation\scripts\build.ps1 -Param1 "Value" }
   
   [2] 

## Option C: SCOM Alert/Event Database Drop (Decoupled Integration)
If iRequest doesn't support active, outbound network connections:

   1. iRequest can drops a specific log event or registry key changes to a server monitored by SCOM.
   2. SCOM detects this flag state change and triggers a "Management Pack Recovery Action".
   3. This native SCOM engine hook launches your local execution script on the jumpbox runner.

------------------------------
## 🎯 What This Means for Your API Documentation
Because Jenkins acts as your actual HTTP entry gateway, the documentation format we discussed earlier fits perfectly.
When you write your single-page OpenAPI/Swagger document, you aren't documenting raw PowerShell paths—you are documenting the Jenkins API Endpoints that wrap them.
Your Swagger JSON file parameters map directly to your Jenkins build parameters:

{
  "openapi": "3.0.3",
  "paths": {
    "/job/Trigger-ImageBuild/buildWithParameters": {
      "post": {
        "summary": "Invokes the HPE iLO configuration loop via iRequest",
        "parameters": [
          { "name": "TargetServerIP", "in": "query", "required": true },
          { "name": "FirmwareVersion", "in": "query", "required": false }
        ]
      }
    }
  }
}

## 💡 Recommendation for Your Test Jumpbox
Since you have everything co-located on that test jumpbox right now, start with Option A (Jenkins Web API). It keeps your PowerShell code entirely pure, lets Jenkins handle the security tokens, and creates a clear, web-addressable API target that iRequest can hit easily.
Do you know if your iRequest platform prefers calling REST Webhooks (HTTP POST), or does it typically use Mid-Server orchestrators to run native Windows commands?

[1] [https://www.reddit.com](https://www.reddit.com/r/PowerShell/comments/gdf401/run_scripts_simultaneously_on_different_servers/)
[2] [https://www.youtube.com](https://www.youtube.com/watch?v=roqtA8JRKzU&t=283)
