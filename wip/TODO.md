## Table of Contents

- [Table of Contents](#table-of-contents)
- [Instead, you use the CI pipeline as your API Gateway.](#instead-you-use-the-ci-pipeline-as-your-api-gateway)
- [The Architecture: How They Interact](#the-architecture-how-they-interact)
- [The 3 Ways to Connect iRequest to Your PowerShell Code](#the-3-ways-to-connect-irequest-to-your-powershell-code)
- [Option A: The CI Web API (The Easiest \& Safest Way)](#option-a-the-ci-web-api-the-easiest--safest-way)

NOTE: THIS IS AN ERROR REFERENCE AND LOG FILE AND NOT A REQUIREMENTS REFERENCE, IT IS A LIST OF BUGS TO BE FIXED.

- [Table of Contents](#table-of-contents)
- [Instead, you use the CI pipeline as your API Gateway.](#instead-you-use-the-ci-pipeline-as-your-api-gateway)
- [The Architecture: How They Interact](#the-architecture-how-they-interact)
- [The 3 Ways to Connect iRequest to Your PowerShell Code](#the-3-ways-to-connect-irequest-to-your-powershell-code)
- [Option A: The CI Web API (The Easiest \& Safest Way)](#option-a-the-ci-web-api-the-easiest--safest-way)

If your code isn't a live listening web server, iRequest cannot directly "call" your PowerShell file over the network without a middleman protocol.
Since your target environment is a unified Windows Test Jumpbox containing CI, SCOM, HPE iLO, and iLO modules, you actually have the perfect infrastructure already in place. You do not need the two systems running on the same OS, nor do you need to configure complex low-level Windows Networking (like SMB or WinRM).
Instead, you use the CI pipeline as your API Gateway.
------------------------------
<a name="the-architecture-how-they-interact"></a>
## The Architecture: How They Interact
Instead of iRequest trying to execute code on a filesystem, iRequest makes a standard HTTPS webhook call to the CI pipeline, which executes your local script.

iRequest -   HTTPS POST   → CI Pipeline -   Native Execution   → PowerShell Codebase -  HPE iLO / SCOM

------------------------------
<a name="the-3-ways-to-connect-irequest-to-your-powershell-code"></a>
## The 3 Ways to Connect iRequest to Your PowerShell Code
Depending on how iRequest is configured by your identity/portal team, you will use one of these three standard connection protocols: [1]

<a name="option-a-the-ci-web-api-the-easiest-and-safest-way"></a>
## Option A: The CI Web API (The Easiest & Safest Way)
CI pipelines have a built-in REST API out of the box. You do not write any API listening code in PowerShell.

   1. iRequest fires a standard HTTPS POST request to your CI server jumpbox.
   2. The payload targets a trigger pipeline endpoint with the CI-specific URL format.
   3. CI receives the variables (e.g., $ImageName, $VMSpec), spins up your PowerShell repository, and passes those variables straight into your .ps1 script arguments.


```text
Run these on the Windows OneView server (not the Linux repo). Nothing here touches credentials — this is purely about purging stray PowerShell module copies; the new Get-OneViewVersion shows exactly what's present.

# 1. See every installed HPEOneView.* / HPOneView.* across PSModulePath
Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' | Select-Object Name,Version,Path | Format-Table -AutoSize

# 2. Purge via PowerShellGet (works for Gallery-installed copies)
Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' |
  Where-Object { $_.Name -ne 'HPEOneView.1000' } |
  ForEach-Object { Uninstall-Module -Name $_.Name -AllVersions -Force }

# 3. Manual copies (e.g. copied into Program Files / scripts\modules) are NOT
#    removed by Uninstall-Module — delete them by path:
Get-Module -ListAvailable -Name 'HPEOneView.*','HPOneView.*' |
  Where-Object { $_.Name -ne 'HPEOneView.1000' } |
  ForEach-Object { Remove-Item -LiteralPath $_.Path -Recurse -Force }

# 4. Confirm ONLY HPEOneView.1000 remains
Get-OneViewVersion
Notes:

If Uninstall-Module errors with "not found in installed modules", that copy was installed by folder copy, so step 3 (path deletion) is what actually removes it. Use step 3 regardless to be safe.
Also delete any leftover from your repo's bundled folder on that server: scripts\modules\HPEOneView.860 (and the scripts/modules dir there should contain only HPEOneView.1000).
There is no separate "Windows store" or credential store for the OneView module — PowerShell loads it only from PSModulePath folders, so removing the above leaves OneView.1000 as the sole source. After purging, re-import the Automation module (Import-Module .\src\powershell\Automation\Automation.psd1 -Force) so Connect-OneViewSession accepts the 1000-only session.
```
