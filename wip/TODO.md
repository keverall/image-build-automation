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





image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                                  0  16:51:55 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-22 15:52:42 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-22 15:52:42 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 32ms) 
2026-07-22 15:52:43 - Connectivity - INFO - Applied web-proxy bypass for appliance 'va-oneviewt-01' 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE 
  Mode:       oneview 
  Host:       va-oneviewt-01 
  Environment:Prod
  Timestamp:  2026-07-22T15:53:06.2929702Z 

  --- Phase 1: Network Ping --- 
    DNS:       Resolved 
    IP:        10.239.124.79
    TCP:       Open (port 443, 32ms)

  --- Phase 2: Auth Connect --- 
    Module:    Loaded 
    Connected: No 
    Session:   N/A 
    Error:     Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."

==============================================

2026-07-22 15:53:06 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)    
 
Name                           Value
----                           -----
Mode                           oneview
Environment                    Prod
Timestamp                      2026-07-22T15:53:06.2929702Z
Available                      False
AuthConnect                    {[Error, Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code… 
ManagementHost                 va-oneviewt-01
NetworkPing                    {[TcpPortOpen, True], [LatencyMs, 32], [Error, ], [IpAddress, 10.239.124.79]…}

   image-build-automation  ping va-oneviewt-01                                                                        0  1m 3s 965ms  16:53:07 
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
 

Ping statistics for 10.239.124.79:                                                                                                      16:54:08 
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 1ms, Maximum = 1ms, Average = 1ms
   image-build-automation  Connect-OVMgmt                                                                                0  3s 118ms  
16:54:08 
cmdlet Connect-OVMgmt at command pipeline position 1
Supply values for the following parameters:
Hostname: va-oneviewt-01                                                                                                                : "Cannot 
UserName: ADM_98253                                                                                                                     ""  
WARNING: Parameter 'UserName' is obsolete.                                                                                              16:55:26 
Password: ************************
Connect-OVMgmt: Cannot convert argument "uri", with value: "https://va-oneviewt-01 /rest/version", for "RestClient" to type "System.Uri": "Cannot convert value "https://va-oneviewt-01 /rest/version" to type "System.Uri". Error: "Invalid URI: The hostname could not be parsed.""
   image-build-automation                                                                                               1  39s 564ms  
16:55:26                    Connect-OVMgmt

cmdlet Connect-OVMgmt at command pipeline position 1
Supply values for the following parameters:
Hostname: va-oneviewt-01.ad.aib.pri
UserName: test
WARNING: Parameter 'UserName' is obsolete.
Password: *************
Connect-OVMgmt: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '407'."
   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01     










 ping va-oneviewt-01                                                                           0  09:42:13 
Pinging va-oneviewt-01.ad.aib.pri [10.239.124.79] with 32 bytes of data:
Reply from 10.239.124.79: bytes=32 time=2ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61

Ping statistics for 10.239.124.79:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 1ms, Maximum = 2ms, Average = 1ms
   image-build-automation  Get-Command -Module Automation                                                      0  3s 184ms  09:42:45 
CommandType     Name                                               Version    Source     
-----------     ----                                               -------    ------     
Function        Convert-ToUtcIso8601                               1.0.0      Automation 
Function        Disconnect-OneView                                 1.0.0      Automation 
Function        Ensure-DirectoryExists                             1.0.0      Automation 
Function        Get-EnvCredential                                  1.0.0      Automation 
Function        Get-IloCredentials                                 1.0.0      Automation 
Function        Get-LocalTimestamp                                 1.0.0      Automation
Function        Get-Logger                                         1.0.0      Automation 
Function        Get-OneViewConnectionStatus                        1.0.0      Automation
Function        Get-OneViewServerList                              1.0.0      Automation
Function        Get-OneViewServerTarget                            1.0.0      Automation
Function        Get-OpenViewCredentials                            1.0.0      Automation
Function        Get-ProjectRoot                                    1.0.0      Automation
Function        Get-RouteMap                                       1.0.0      Automation
Function        Get-ScomCredentials                                1.0.0      Automation
Function        Get-SmtpCredentials                                1.0.0      Automation
Function        Get-UtcApiTimestamp                                1.0.0      Automation
Function        Get-UtcFileTimestamp                               1.0.0      Automation
Function        Get-UtcTimestamp                                   1.0.0      Automation
Function        Import-JsonConfig                                  1.0.0      Automation
Function        Import-YamlConfig                                  1.0.0      Automation
Function        Initialize-Logging                                 1.0.0      Automation
Function        Invoke-IloRedfish                                  1.0.0      Automation
Function        Invoke-IsoDeploy                                   1.0.0      Automation
Function        Invoke-NativeCommand                               1.0.0      Automation 
Function        Invoke-NativeCommandWithRetry                      1.0.0      Automation
Function        Invoke-OpsRamp                                     1.0.0      Automation
Function        Invoke-OpsRampClient                               1.0.0      Automation
Function        Invoke-PowerShellScript                            1.0.0      Automation
Function        Invoke-PowerShellWinRM                             1.0.0      Automation
Function        Invoke-RoutedRequest                               1.0.0      Automation
Function        Invoke-WindowsSecurityUpdate                       1.0.0      Automation
Function        Load-ClusterCatalogue                              1.0.0      Automation
Function        Load-Json                                          1.0.0      Automation
Function        Load-ServerList                                    1.0.0      Automation
Function        New-AuditLogger                                    1.0.0      Automation
Function        New-AutomationBase                                 1.0.0      Automation 
Function        New-CIPipelineCtrl                                 1.0.0      Automation
Function        New-CommandResult                                  1.0.0      Automation
Function        New-GitLabCtrl                                     1.0.0      Automation
Function        New-IRequestCtrl                                   1.0.0      Automation
Function        New-IsoBuild                                       1.0.0      Automation
Function        New-OneViewMaintenanceScript                       1.0.0      Automation
Function        New-SchedulerCtrl                                  1.0.0      Automation
Function        New-ScomConnection                                 1.0.0      Automation 
Function        New-ScomMaintenanceScript                          1.0.0      Automation
Function        New-ServerInfo                                     1.0.0      Automation
Function        New-Uuid                                           1.0.0      Automation
Function        Publish-BootIso                                    1.0.0      Automation
Function        Resolve-OneViewTarget                              1.0.0      Automation 
Function        Run-CIPipeline                                     1.0.0      Automation
Function        Run-GitLab                                         1.0.0      Automation
Function        Run-IRequest                                       1.0.0      Automation
Function        Run-Scheduler                                      1.0.0      Automation
Function        Save-Json                                          1.0.0      Automation
Function        Save-JsonResult                                    1.0.0      Automation
Function        Set-MaintenanceMode                                1.0.0      Automation
Function        Start-AutomationOrchestrator                       1.0.0      Automation
Function        Start-InstallMonitor                               1.0.0      Automation
Function        Start-PhysicalServerBuild                          1.0.0      Automation
Function        Test-BuildParams                                   1.0.0      Automation
Function        Test-ClusterDefinition                             1.0.0      Automation
Function        Test-ClusterId                                     1.0.0      Automation
Function        Test-PathEx                                        1.0.0      Automation 
Function        Test-PostBuildValidation                           1.0.0      Automation
Function        Test-PreBuildValidation                            1.0.0      Automation
Function        Test-ScomMaintenanceConnectivity                   1.0.0      Automation
Function        Test-ServerConnectivity                            1.0.0      Automation
Function        Test-ServerList                                    1.0.0      Automation
Function        Update-Firmware                                    1.0.0      Automation

   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                        0  09:42:57 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-23 08:43:31 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-23 08:43:31 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 28ms) 
2026-07-23 08:43:31 - Connectivity - INFO - Connecting directly to appliance 'va-oneviewt-01' 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-07-23T08:43:54.0959486Z 

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 28ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded 
    Connected: No
    Session:   N/A
    Error:     Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."
 
==============================================
 
2026-07-23 08:43:54 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)

Name                           Value
----                           -----
Mode                           oneview 
Available                      False
Timestamp                      2026-07-23T08:43:54.0959486Z
Environment                    Prod
NetworkPing                    {[LatencyMs, 28], [TcpPortOpen, True], [Error, ], [Port, 443]…}
AuthConnect                    {[Error, Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with s… 
ManagementHost                 va-oneviewt-01
 
   image-build-automation  Connect-OVMgmt                                                                     0  49s 959ms  09:43:54  
cmdlet Connect-OVMgmt at command pipeline position 1
Supply values for the following parameters:
Hostname: va-oneviewt-01
UserName: adm_98253
WARNING: Parameter 'UserName' is obsolete. 
Password: ************************
Connect-OVMgmt: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."




----------------



Test-ServerConnectivity -ManagementHost va-oneviewt-01                                                                        0  10:23:59 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-23 09:24:27 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-23 09:24:27 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 11ms) 
2026-07-23 09:24:27 - Connectivity - INFO - Connecting directly to appliance 'va-oneviewt-01' 
 
============================================== 
  OneView Connectivity Test
==============================================
 
  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-07-23T09:24:49.5772997Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 11ms)
 
  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: No
    Session:   N/A
    Error:     Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."

==============================================

2026-07-23 09:24:49 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)

Name                           Value
----                           -----
NetworkPing                    {[Port, 443], [TcpPortOpen, True], [IpAddress, 10.239.124.79], [DnsResolved, True]…}
Timestamp                      2026-07-23T09:24:49.5772997Z
Mode                           oneview
ManagementHost                 va-oneviewt-01
Available                      False
AuthConnect                    {[ModuleLoaded, True], [Connected, False], [Error, Auth error: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' fai… 
Environment                    Prod




==================================================================

 Test-ServerConnectivity -ManagementHost va-oneviewt-01                                             0  26s 602ms  14:47:39 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-23 13:48:30 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-23 13:48:30 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 3ms) 

============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-07-23T13:48:32.6701187Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79 
    TCP:       Open (port 443, 3ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: No
    Error:     No credentials supplied and ONEVIEW_USER/ONEVIEW_PASSWORD not configured

==============================================

2026-07-23 13:48:32 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)

Name                           Value
----                           -----
AuthConnect                    {[ModuleLoaded, True], [Disconnected, False], [Connected, False], [Error, No credentials supplied and ONEVIEW_USER/ONEV… 
Environment                    Prod
ManagementHost                 va-oneviewt-01 
Available                      False
NetworkPing                    {[Port, 443], [DnsResolved, True], [TcpPortOpen, True], [LatencyMs, 3]…}
Timestamp                      2026-07-23T13:48:32.6701187Z
Mode                           oneview


Test-ServerConnectivity -ManagementHost va-oneviewt-01                                          0  1m 44s 266ms  09:26:21 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-24 08:31:16 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-24 08:31:16 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 28ms) 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-07-24T08:31:39.0377483Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 28ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    Connected: No
    Error:     Connect-OVMgmt failed: Exception calling "RestClient" with "3" argument(s): "The ServicePointManager does not support proxies with the https scheme."

==============================================

2026-07-24 08:31:39 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)

Name                           Value
----                           -----
Available                      False
Mode                           oneview
NetworkPing                    {[IpAddress, 10.239.124.79], [Error, ], [Port, 443], [DnsResolved, True]…}
Environment                    Prod
Timestamp                      2026-07-24T08:31:39.0377483Z
AuthConnect                    {[Error, Connect-OVMgmt failed: Exception calling "RestClient" with "3" argument(s): "The ServicePointManager does not … 
ManagementHost                 va-oneviewt-01
