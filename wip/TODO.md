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

<a id="top"></a>

## Table of Contents

- [The Architecture: How They Interact](#the-architecture-how-they-interact)
- [The 3 Ways to Connect iRequest to Your PowerShell Code](#the-3-ways-to-connect-irequest-to-your-powershell-code)
- [Option A: The CI Web API (The Easiest & Safest Way)](#option-a-the-ci-web-api-the-easiest-and-safest-way)

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

```text
 Get-OneViewServerList                                                                                                                0  16:45:13 
============================================== 
  OneView Server List (16 servers)
============================================== 

Server Name                      Serial Number    Power     Health      iLO IP          
--------------------------------------------------------------------------------------- 
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK                          
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

Name                           Value
----                           -----
Count                          16
Error
Success                        True
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, ALP-STARWAY-01ILO…}

 image-build-automation  Get-OneViewConnectionStatus                                                                                                          0  16:55:39 
Name                           Value
----                           -----
Success                        False
Appliance
Error                          No active OneView session. Use Test-ServerConnectivity -ManagementHost <oneview-appliance-host> to connect, or supply -OneViewHost. 
Authenticated                  False
Reachable                      False
Connected                      False

   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01                                                                               0  16:55:44 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ************************ 
2026-07-27 15:56:09 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-07-27 15:56:09 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 19ms) 
This management appliance is a company owned asset and provided for the exclusive use of authorized personnel. Unauthorized use or abuse of this system may lead to corrective 
action including termination, civil and/or criminal penalties.
 

============================================== 
  OneView Connectivity Test
============================================== 

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-07-27T15:56:33.4130999Z
 
  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79 
    TCP:       Open (port 443, 19ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded 
    Connected: Yes (session active)

==============================================

2026-07-27 15:56:33 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)

Name                           Value
----                           -----
Available                      True
Environment                    Prod
ManagementHost                 va-oneviewt-01
Mode                           oneview
NetworkPing                    {[Error, ], [Port, 443], [LatencyMs, 19], [IpAddress, 10.239.124.79]…}
Timestamp                      2026-07-27T15:56:33.4130999Z
AuthConnect                    {[Error, ], [Connected, True], [Disconnected, False], [ModuleLoaded, True]}

   image-build-automation  Get-OneViewConnectionStatus                                                                                               0  42s 223ms  16:56:33 
Name                           Value 
----                           -----
SessionSource                  HPEOneViewModule
Appliance                      va-oneviewt-01
Reachable                      True
Version                        8200
Connected                      True
Server
Error
Success                        True
Authenticated                  True
ServerCount

   image-build-automation  Get-OneViewConnectionStatus -OneViewHost HPEOpenview.1000                                                                            0  16:56:43 
Name                           Value 
----                           -----
SessionSource                  Explicit
Appliance                      HPEOpenview.1000
Reachable                      False
Version
Connected                      False
Server
Error                          OneView appliance 'HPEOpenview.1000' is not reachable: No such host is known. (hpeopenview.1000:443)
Success                        False 
Authenticated                  False
ServerCount

   image-build-automation  Get-OneViewServerList                                                                                                                0  16:56:56 
============================================== 
  OneView Server List (16 servers)
==============================================

Server Name                      Serial Number    Power     Health      iLO IP          
---------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK                          
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK                          
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

Name                           Value
----                           -----
Success                        True
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, ALP-STARWAY-01ILO…}
Count                          16
Error
```
