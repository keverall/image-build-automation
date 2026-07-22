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



image-build-automation  ping va-oneviewt-01                                                                       0  1m 27s 899ms  12:03:20 
Pinging va-oneviewt-01.ad.aib.pri [10.239.124.79] with 32 bytes of data:
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61

Ping statistics for 10.239.124.79:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 1ms, Maximum = 1ms, Average = 1ms
   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                        0  3s 172ms  12:03:39 Enter OneView username for 'va-oneviewt-01':  
   image-build-automation  Get-OneViewConnectionStatus                                                                  0  28s 556ms  12:04:45 
Name                           Value
----                           -----
Connected                      False
Reachable                      False
Success                        False 
Authenticated                  False
Appliance
Error                          No active OneView session. Use Connect-OVMgmt to connect, or supply -OneViewHost.

   image-build-automation  Get-OneViewConnectionStatus -IncludeServerCount                                                         0  12:04:49  
Name                           Value 
----                           ----- 
Connected                      False 
Reachable                      False 
Success                        False 
Authenticated                  False
Appliance
Error                          No active OneView session. Use Connect-OVMgmt to connect, or supply -OneViewHost.

   image-build-automation  Connect-OVMgmt                                                                                          0  12:05:30 
cmdlet Connect-OVMgmt at command pipeline position 1 
Supply values for the following parameters:
Hostname: va-oneviewt-01 
UserName: adm_98253 
WARNING: Parameter 'UserName' is obsolete.  
Password: ************************ 
Connect-OVMgmt: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'." 
   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                       1  43s 393ms  12:06:27 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-07-22T11:07:11.2475726Z 

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 4ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: No
    Session:   N/A 
    Error:     Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."

==============================================


Name                           Value
----                           -----
ManagementHost                 va-oneviewt-01
Timestamp                      2026-07-22T11:07:11.2475726Z 
Mode                           oneview
Available                      False
AuthConnect                    {[Error, Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code… 
Environment                    Prod
NetworkPing                    {[Port, 443], [TcpPortOpen, True], [IpAddress, 10.239.124.79], [Error, ]…}