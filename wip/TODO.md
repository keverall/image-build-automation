## Table of Contents

- [The Architecture: How They Interact](#the-architecture-how-they-interact)
- [The 3 Ways to Connect iRequest to Your PowerShell Code](#the-3-ways-to-connect-irequest-to-your-powershell-code)
- [Option A: The CI Web API (The Easiest & Safest Way)](#option-a-the-ci-web-api-the-easiest-and-safest-way)

NOTE: THIS IS AN ERROR REFERENCE AND LOG FILE AND NOT A REQUIREMENTS REFERENCE, IT IS A LIST OF BUGS TO BE FIXED.

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





 Test-ServerConnectivity -ManagementHost va-oneviewt-01                                                                               0  15:54:09 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-27 14:54:54 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-27 14:54:54 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 12ms) 
This management appliance is a company owned asset and provided for the exclusive use of authorized personnel. Unauthorized use or abuse of this system may lead to corrective 
action including termination, civil and/or criminal penalties.


============================================== 
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-07-27T14:55:18.6156500Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 12ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: Yes (session active)

==============================================

2026-07-27 14:55:18 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)

Name                           Value
----                           -----
ManagementHost                 va-oneviewt-01
Available                      True
AuthConnect                    {[Disconnected, False], [Error, ], [Connected, True], [ModuleLoaded, True]}
Environment                    Prod
NetworkPing                    {[DnsResolved, True], [IpAddress, 10.239.124.79], [LatencyMs, 12], [Port, 443]…}
Timestamp                      2026-07-27T14:55:18.6156500Z
Mode                           oneview

   image-build-automation  Get-OneViewConnectionStatus                                                                                             0  1m 2s 982ms  15:55:18 
Name                           Value
----                           -----
Reachable                      True
Success                        True
ServerCount
Appliance                      va-oneviewt-01 
Connected                      True
Version                        8200
Error
Server
Authenticated                  True
SessionSource                  HPEOneViewModule