## Table of Contents

- [The Architecture: How They Interact](#the-architecture-how-they-interact)
- [The 3 Ways to Connect iRequest to Your PowerShell Code](#the-3-ways-to-connect-irequest-to-your-powershell-code)
- [Option A: The CI Web API (The Easiest & Safest Way)](#option-a-the-ci-web-api-the-easiest-and-safest-way)

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

 Test-ServerConnectivity -ManagementHost va-oneviewt-01                                       0  47s 819ms  14:28:36 Enter OneView username for 'va-oneviewt-01': test 
Enter OneView password for 'va-oneviewt-01': : ************* 
Invoke-PowerShellScript: C:\Products\repos\image-build-automation\src\powershell\Automation\Public\Test-ServerConnectivity.ps1:577:33 
Line |
 577 |  …        $scriptResult = Invoke-PowerShellScript -Script $scriptContent 
     |                           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
     | PowerShell error (exit code 1): Import-Module : The version of Windows PowerShell on this computer is '5.1.17763.8880'. The module         
     | 'C:\Users\adm_98253\Documents\PowerShell\Modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1' requires a  minimum Windows
     | PowerShell version of '7.0' to run. Verify that you have the minimum required version of Windows  PowerShell installed, and then try       
     | again. At line:1 char:1 + Import-Module HPEOneView.1000 -ErrorAction Stop + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     +
     | CategoryInfo          : ResourceUnavailable: (C:\Users\adm_98...eView.1000.psd1:String) [Import-Module], Invalid     OperationException    
     | + FullyQualifiedErrorId : Modules_InsufficientPowerShellVersion,Microsoft.PowerShell.Commands.ImportModuleCommand

==============================================
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-07-20T13:29:04.2127979Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 3ms) 

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Clean up:  N/A
    Error:     Connection script failed: 
Import-Module : The version of Windows PowerShell on this computer is '5.1.17763.8880'. The module
'C:\Users\adm_98253\Documents\PowerShell\Modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1' requires a
minimum Windows PowerShell version of '7.0' to run. Verify that you have the minimum required version of Windows
PowerShell installed, and then try again.
At line:1 char:1
+ Import-Module HPEOneView.1000 -ErrorAction Stop
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ResourceUnavailable: (C:\Users\adm_98...eView.1000.psd1:String) [Import-Module], Invalid
   OperationException
    + FullyQualifiedErrorId : Modules_InsufficientPowerShellVersion,Microsoft.PowerShell.Commands.ImportModuleCommand

   OperationException
    + FullyQualifiedErrorId : Modules_InsufficientPowerShellVersion,Microsoft.PowerShell.Commands.ImportModuleCommand
   OperationException
    + FullyQualifiedErrorId : Modules_InsufficientPowerShellVersion,Microsoft.PowerShell.Commands.ImportModuleCommand

==============================================


Name                           Value
----                           -----
Mode                           oneview
NetworkPing                    {[IpAddress, 10.239.124.79], [Port, 443], [DnsResolved, True], [Error, ]…}
Available                      False
Timestamp                      2026-07-20T13:29:04.2127979Z
ManagementHost                 va-oneviewt-01
AuthConnect                    {[Error, Connection script failed: …
Environment                    Prod
