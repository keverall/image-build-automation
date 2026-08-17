# Testing Issues

<a id="top"></a>

## Table of Contents

- [Friday 14 Aug 14:33](#friday-14-aug-1433)
  - [Test-ServerConnectivity](#test-serverconnectivity)
  - [  image-build-automation  Test-ServerConnectivity -ManagementHost oneview.example.com Test-ServerConnectivity: A parameter cannot be found that matches parameter name 'ManagementHost'.](#image-build-automation-test-serverconnectivity-managementhost-oneviewexamplecom-test-serverconnectivity-a-parameter-cannot-be-found-that-matches-parameter-name-managementhost)
  - [  image-build-automation  Test-ServerConnectivity -OneViewHost oneview.example.com    ](#image-build-automation-test-serverconnectivity-oneviewhost-oneviewexamplecom)
  - [###   image-build-automation  Connect-OneView -OneViewHost va-oneviewt-01                        0 ](#image-build-automation-connect-oneview-oneviewhost-va-oneviewt-01-0)
  - [###   image-build-automation  $cred = Get-Credential   ](#image-build-automation-cred-get-credential)
  - [###   image-build-automation  Test-ServerConnectivity  ](#image-build-automation-test-serverconnectivity)
  - [  image-build-automation  Test-ServerConnectivity  -OneViewHost va-oneviewt-01        ](#image-build-automation-test-serverconnectivity-oneviewhost-va-oneviewt-01)
  - [  image-build-automation  Get-OneViewConnectionStatus](#image-build-automation-get-oneviewconnectionstatus)
  - [  image-build-automation  Get-OneViewConnectionStatus -OVHost va-oneviewt-01](#image-build-automation-get-oneviewconnectionstatus-ovhost-va-oneviewt-01)
  - [  image-build-automation  Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 ](#image-build-automation-get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01)
  - [  image-build-automation  Get-OneViewConnectionStatus                             ](#image-build-automation-get-oneviewconnectionstatus-1)
  - [  image-build-automation  Get-OneViewConnectionStatus -IncludeServerCount](#image-build-automation-get-oneviewconnectionstatus-includeservercount)
  - [  image-build-automation  Get-OneViewServerList](#image-build-automation-get-oneviewserverlist)
  - [  image-build-automation  Get-OneViewServerList -OneViewHost va-oneviewt-01](#image-build-automation-get-oneviewserverlist-oneviewhost-va-oneviewt-01)
  - [  image-build-automation  Test-ServerList](#image-build-automation-test-serverlist)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2025.iso'   ](#image-build-automation-test-buildparams-baseisopath-ywin2019autoiso-image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2025iso)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2019.iso' ](#image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2019iso)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' ](#image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso)
  - [  image-build-automation  ls  '//vm-ewismgt-19/Kev/WIN2019Auto.iso'  ](#image-build-automation-ls-vm-ewismgt-19kevwin2019autoiso)
  - [  image-build-automation  ls  '//vm-ewismgt-19/'](#image-build-automation-ls-vm-ewismgt-19)
  - [  image-build-automation  ls  '//vm-ewismgt-19/*'                                                      0  10:34:](#image-build-automation-ls-vm-ewismgt-19-0-1034)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'](#image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kev)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/*'](#image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kev-1)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/W      0  10:35:IN2019Auto.iso'          ](#image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevw-0-1035in2019autoiso)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath 'Y:age-build-autom\Drivers for Windows ISO\FC-14.4.624.0-1'   0  ](#image-build-automation-test-buildparams-baseisopath-yage-build-automdrivers-for-windows-isofc-1446240-1-0)
  - [  image-build-automation  Test-BuildParams -BaseIsoPath 'Y:\Drivers for Windows ISO\FC-14.4.624.0-1\*'   ](#image-build-automation-test-buildparams-baseisopath-ydrivers-for-windows-isofc-1446240-1)
  - [  image-build-automation  Configure-PhysicalBuild -ServerIdentifier alp-qlikview-03ilo -OneViewHo624.0-1', 'Y:\Dst va-oneviewt-01 -ExpectedHostname -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drif type 'System.vers') -GuardRail  'qlikview-03ilo'                                                                 ](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewho6240-1-ydst-va-oneviewt-01-expectedhostname-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drif-type-systemvers-guardrail-qlikview-03ilo)
  - [  image-build-automation  Configure-PhysicalBuild -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)
  - [  image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-1)
  - [  image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'  ](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-2)
  - [  image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-smbvm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)
  - [   image-build-automation Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'Y:\WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-ywin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)

<a name="friday-14-aug-1433"></a>

## Friday 14 Aug 14:33

<a name="test-serverconnectivity"></a>

### Test-ServerConnectivity

```text
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       
  Environment:Prod
  Timestamp:  2026-08-14T09:17:00.0932249Z 

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     No active OneView connection. Connect first with Connect-OneView -OneViewHost <hostial), or supply -OneViewHost to test a specific appliance.
 
  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no active connection  

============================================== 

Name                           Value 
----                           ----- 
OneViewHost
Available                      False 
Mode                           oneview 
Environment                    Prod
Timestamp                      2026-08-14T09:17:00.0932249Z
NetworkPing                    {[Error, No active OneView connection. Connect first with Connect-O
AuthConnect                    {[Error, Skipped - no active connection], [Connected, False]}
```

<a name="image-build-automation-test-serverconnectivity-managementhost-oneviewexamplecom-test-serverconnectivity-a-parameter-cannot-be-found-that-matches-parameter-name-managementhost"></a>

###   image-build-automation  Test-ServerConnectivity -ManagementHost oneview.example.com Test-ServerConnectivity: A parameter cannot be found that matches parameter name 'ManagementHost'.

```text

<a name="image-build-automation-test-serverconnectivity-oneviewhost-oneviewexamplecom"></a>

###   image-build-automation  Test-ServerConnectivity -OneViewHost oneview.example.com    

2026-08-14 09:17:45 - Connectivity - INFO - DNS resolution for 'oneview.example.com': FAILED - DNSr 'oneview.example.com': No such host is known.
2026-08-14 09:17:45 - Connectivity - INFO - TCP probe for 'oneview.example.com': FAILED - DNS resoeview.example.com': No such host is known.

============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE 
  Mode:       oneview
  Host:       oneview.example.com
  Environment:Prod
  Timestamp:  2026-08-14T09:17:45.6003822Z

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     DNS resolution failed for 'oneview.example.com': No such host is known.

  --- Phase 2: Auth Connect ---
    Module:    Not loaded 
    Connected: No
    Error:     Skipped - network ping failed

==============================================

2026-08-14 09:17:45 - Connectivity - INFO - Connectivity test for 'oneview.example.com' completed:=False, TCP=False, Auth=False)

Name                           Value
----                           -----
OneViewHost                    oneview.example.com
Available                      False
Mode                           oneview
Environment                    Prod
Timestamp                      2026-08-14T09:17:45.6003822Z
NetworkPing                    {[Port, ], [Error, DNS resolution failed for 'oneview.example.com':
AuthConnect                    {[Error, Skipped - network ping failed], [Disconnected, False], [Co
```

<a name="image-build-automation-connect-oneview-oneviewhost-va-oneviewt-01-0"></a>

### ###   image-build-automation  Connect-OneView -OneViewHost va-oneviewt-01                        0 

```text
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\commands\Connect-OneView 
2026-08-14 09:19:41 - Connect-OneView - INFO - Connect-OneView invoked: OneViewHost='va-oneviewt-0
Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ****************** 
2026-08-14 09:20:06 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.23
2026-08-14 09:20:06 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 26ms) 
This management appliance is a company owned asset and provided for the exclusive use of authorizeized use or abuse of this system may lead to corrective action including termination, civil and/or

============================================== 
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-14T09:20:56.8382030Z
 
  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79 
    TCP:       Open (port 443, 26ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000  v10.0.4265.2221 (module used for all OneView calls on this
    Appliance OneView version: 8200
    Connected: Yes (session active)
 
==============================================

2026-08-14 09:20:56 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Avai TCP=True, Auth=True)
2026-08-14 09:20:56 - Connect-OneView - INFO - Connect-OneView result: Available=True Message='Conliance 'va-oneviewt-01'.'

Name                           Value
----                           -----
Message                        Connected to OneView appliance 'va-oneviewt-01'. 
Available                      True
OneViewHost                    va-oneviewt-01
Mode                           oneview
Environment                    Prod
NetworkPing                    {[Port, 443], [Error, ], [LatencyMs, 26], [DnsResolved, True]…}
Timestamp                      2026-08-14T09:20:56.8382030Z
AuthConnect                    {[Error, ], [Disconnected, False], [Connected, True], [ModuleVersio
```

<a name="image-build-automation-cred-get-credential"></a>

### ###   image-build-automation  $cred = Get-Credential   

```text                                      0  1m 
PowerShell credential request 
Enter your credentials.       
User: adm_98253 
Password for user adm_98253: ****************** 

<a name="image-build-automation-test-serverconnectivity"></a>

### ###   image-build-automation  Test-ServerConnectivity  

```text                                         0  2026-08-14 09:26:58 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.23
2026-08-14 09:26:58 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 4ms) 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-14T09:27:01.3532173Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 4ms)
 
  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000 (module used for all OneView calls on this server)
    Connected: Yes (session active)

==============================================

2026-08-14 09:27:01 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Avai TCP=True, Auth=True)

Name                           Value
----                           -----
OneViewHost                    va-oneviewt-01 
Available                      True
Mode                           oneview
Environment                    Prod
Timestamp                      2026-08-14T09:27:01.3532173Z
NetworkPing                    {[Port, 443], [Error, ], [LatencyMs, 4], [DnsResolved, True]…}
AuthConnect                    {[Error, ], [Disconnected, False], [Connected, True], [ModuleVersio
```

<a name="image-build-automation-test-serverconnectivity-oneviewhost-va-oneviewt-01"></a>

###   image-build-automation  Test-ServerConnectivity  -OneViewHost va-oneviewt-01        

```text
2026-08-14 09:27:38 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.23
2026-08-14 09:27:38 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 4ms) 

============================================== 
  OneView Connectivity Test
============================================== 

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-14T09:27:39.4032484Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 4ms) 

  --- Phase 2: Auth Connect ---
    Module:    Loaded 
    OneView PS module: HPEOneView.1000 (module used for all OneView calls on this server)
    Connected: Yes (session active)

==============================================

2026-08-14 09:27:39 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Avai TCP=True, Auth=True)

Name                           Value
----                           -----
OneViewHost                    va-oneviewt-01
Available                      True
Mode                           oneview
Environment                    Prod
Timestamp                      2026-08-14T09:27:39.4032484Z
NetworkPing                    {[Port, 443], [Error, ], [LatencyMs, 4], [DnsResolved, True]…}
AuthConnect                    {[Error, ], [Disconnected, False], [Connected, True], [ModuleVersio
```

<a name="image-build-automation-get-oneviewconnectionstatus"></a>

###   image-build-automation  Get-OneViewConnectionStatus

```text
2026-08-14 09:28:15 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=Truhable=True Authenticated=True Error=''

============================================== 
  OneView Connection Status
============================================== 

  Status:    CONNECTED
  Appliance: va-oneviewt-01 
  Reachable: True
  Auth:      True
  Version:   8200
  Module:    HPEOneView.1000  v10.0.4265.2221 
    Source:  LoadedSession
  Mod Compat: Compatible
  Session:   HPEOneViewModule
 
==============================================
```

<a name="image-build-automation-get-oneviewconnectionstatus-ovhost-va-oneviewt-01"></a>

###   image-build-automation  Get-OneViewConnectionStatus -OVHost va-oneviewt-01

```text
2026-08-14 09:28:40 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=Falachable=True Authenticated=False Error='OneView authentication failed for '': Response status codeccess: 401 (Unauthorized).'

============================================== 
  OneView Connection Status
============================================== 

  Status:    NOT CONNECTED
  Appliance: va-oneviewt-01
  Reachable: True
  Auth:      False 
  Version:   8200
  Module:    HPEOneView.1000  v10.0.4265.2221
    Source:  LoadedSession
  Mod Compat: Compatible
  Session:   Explicit

  Error:   OneView authentication failed for '': Response status code does not indicate success: 4

==============================================
```

<a name="image-build-automation-get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01"></a>

###   image-build-automation  Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 

```text
2026-08-14 09:28:55 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=Falachable=True Authenticated=False Error='OneView authentication failed for '': Response status codeccess: 401 (Unauthorized).'

==============================================
  OneView Connection Status
============================================== 

  Status:    NOT CONNECTED
  Appliance: va-oneviewt-01
  Reachable: True
  Auth:      False
  Version:   8200
  Module:    HPEOneView.1000  v10.0.4265.2221 
    Source:  LoadedSession
  Mod Compat: Compatible
  Session:   Explicit

  Error:   OneView authentication failed for '': Response status code does not indicate success: 4

============================================== 
```

<a name="image-build-automation-get-oneviewconnectionstatus-1"></a>

###   image-build-automation  Get-OneViewConnectionStatus                             

```text
2026-08-14 09:29:07 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=Truhable=True Authenticated=True Error=''

==============================================
  OneView Connection Status
==============================================

  Status:    CONNECTED
  Appliance: va-oneviewt-01
  Reachable: True
  Auth:      True 
  Version:   8200
  Module:    HPEOneView.1000  v10.0.4265.2221 
    Source:  LoadedSession
  Mod Compat: Compatible
  Session:   HPEOneViewModule

==============================================
```

<a name="image-build-automation-get-oneviewconnectionstatus-includeservercount"></a>

###   image-build-automation  Get-OneViewConnectionStatus -IncludeServerCount

```text
2026-08-14 09:29:30 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=Truhable=True Authenticated=True Error=''

============================================== 
  OneView Connection Status
============================================== 

  Status:    CONNECTED
  Appliance: va-oneviewt-01
  Reachable: True
  Auth:      True 
  Version:   8200
  Module:    HPEOneView.1000  v10.0.4265.2221
    Source:  LoadedSession
  Mod Compat: Compatible
  Servers:   16
  Session:   HPEOneViewModule

==============================================
```

<a name="image-build-automation-get-oneviewserverlist"></a>

###   image-build-automation  Get-OneViewServerList

```text
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
OMG-CONSTC2-02ilo                CZ2D3701LY       On        Warning
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK                          
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================
 
2026-08-14 09:29:51 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=
```

<a name="image-build-automation-get-oneviewserverlist-oneviewhost-va-oneviewt-01"></a>

###   image-build-automation  Get-OneViewServerList -OneViewHost va-oneviewt-01

```text
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
OMG-CONSTC2-02ilo                CZ2D3701LY       On        Warning
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

2026-08-14 09:30:54 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=
```

<a name="image-build-automation-test-serverlist"></a>

###   image-build-automation  Test-ServerList

```text
Name                           Value
----                           -----
Servers                        {server1.example.com, server2.example.com, server3.example.com, pro
Success                        True
 ```

<a name="image-build-automation-test-buildparams-baseisopath-ywin2019autoiso-image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2025iso"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2025.iso'   

```text
Base ISO not found: //vm-ewismgt-19/Kev/WinSrv2025.iso 
```

<a name="image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2019iso"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2019.iso' 

```text
Base ISO not found: //vm-ewismgt-19/Kev/WinSrv2019.iso 
```

<a name="image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' 

<a name="image-build-automation-ls-vm-ewismgt-19kevwin2019autoiso"></a>

###   image-build-automation  ls  '//vm-ewismgt-19/Kev/WIN2019Auto.iso'  

```text
    Directory: \\vm-ewismgt-19\Kev

Mode                 LastWriteTime         Length Name
 ```

<a name="image-build-automation-ls-vm-ewismgt-19"></a>

###   image-build-automation  ls  '//vm-ewismgt-19/'

```text
      0  10:34:23 Get-ChildItem: Cannot find path '//vm-ewismgt-19/' because it does not exist.    
```

<a name="image-build-automation-ls-vm-ewismgt-19-0-1034"></a>

###   image-build-automation  ls  '//vm-ewismgt-19/*'                                                      0  10:34:

```text
      1  10:34:36 ###   image-build-automation  ls  '//vm-ewismgt-19/Kev/*'
                         0  10:34:50                                                                     1  10:34:
    Directory: \\vm-ewismgt-19\Kev
 
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---          29/06/2022    16:54     5102354432 WIN2019Auto.iso
 ```

<a name="image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kev"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'

 
 ```text
      0  10:35:21 Base ISO not found: //vm-ewismgt-19/Kev/                                               0  10:35:

<a name="image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kev-1"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/*'

<a name="image-build-automation-test-buildparams-baseisopath-vm-ewismgt-19kevw-0-1035in2019autoiso"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/W      0  10:35:IN2019Auto.iso'          

<a name="image-build-automation-test-buildparams-baseisopath-yage-build-automdrivers-for-windows-isofc-1446240-1-0"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath 'Y:age-build-autom\Drivers for Windows ISO\FC-14.4.624.0-1'   0  

Base ISO not found: Y:\Drivers for Windows r Windows ISO\FISO\FC-14.4.624.0-1                                                                                 -1\*' 0  
```

<a name="image-build-automation-test-buildparams-baseisopath-ydrivers-for-windows-isofc-1446240-1"></a>

###   image-build-automation  Test-BuildParams -BaseIsoPath 'Y:\Drivers for Windows ISO\FC-14.4.624.0-1\*'   

```text
10:38:28 Base ISO not found: Y:\Drivers for WindowsISO\FC-14.4.624.0-1\*                 st va-oneviewt-
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewho6240-1-ydst-va-oneviewt-01-expectedhostname-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drif-type-systemvers-guardrail-qlikview-03ilo"></a>

###   image-build-automation  Configure-PhysicalBuild -ServerIdentifier alp-qlikview-03ilo -OneViewHo624.0-1', 'Y:\Dst va-oneviewt-01 -ExpectedHostname -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drif type 'System.vers') -GuardRail  'qlikview-03ilo'                                                                 

```text
Host 'va-onevie
Configure-PhysicalBuild: Missing an argument for parameter 'ExpectedHostname'. Specify a parameter o for Windows ISf type 'System.String' and try again.
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

###   image-build-automation  Configure-PhysicalBuild -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

```text
========================================
  Physical Build Configuration Review
========================================

[1/4] Resolving server identity from OneView...
2026-08-14 09:53:40 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
  [OK] Server resolved

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Appliance     : va-oneviewt-01

[2/4] Resolving ISO...
Exception: C:\Users\adm_98253\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line |
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '/vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL,
     | NFS path, or UNC/SMB path (\\server\share\file.iso).
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-1"></a>

###   image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

```text
========================================
  Physical Build Configuration Review
======================================== 

[1/4] Resolving server identity from OneView...
2026-08-14 12:57:12 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto 
  [OK] Server resolved 

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Appliance     : va-oneviewt-01

[2/4] Resolving ISO...
Exception: C:\Users\adm_98253\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '//vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB     
     | path (\\server\share\file.iso).
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-2"></a>

###   image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'  

```text
========================================
  Physical Build Configuration Review
========================================

[1/4] Resolving server identity from OneView...
2026-08-14 13:24:56 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
  [OK] Server resolved 

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Appliance     : va-oneviewt-01

[2/4] Resolving ISO...
Exception: C:\Users\adm_98253\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '//vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB     
     | path (\\server\share\file.iso).
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-smbvm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

###   image-build-automation  Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

```text
========================================
  Physical Build Configuration Review 
======================================== 

[1/4] Resolving server identity from OneView...
2026-08-14 13:25:45 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto 
  [OK] Server resolved

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Appliance     : va-oneviewt-01 

[2/4] Resolving ISO...
Exception: C:\Users\adm_98253\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT … 
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
     | Unsupported ISO path format: 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB 
     | path (\\server\share\file.iso).
```

<a name="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-ywin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

###    image-build-automation Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'Y:\WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

```text
========================================
  Physical Build Configuration Review
========================================

[1/4] Resolving server identity from OneView...
2026-08-14 13:27:12 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto 
  [OK] Server resolved

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Appliance     : va-oneviewt-01

[2/4] Resolving ISO...
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/WIN2019Auto.iso
  [OK] Resolved to: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/WIN2019Auto.iso

[3/4] Running pre-build validation...
2026-08-14 13:27:33 - Get-OneViewServerTarget - INFO - [DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto
[DRY RUN] Get-OneViewServerTarget Host=va-oneviewt-01 Id=alp-qlikview-03ilo Type=Auto 
  [OK] All pre-build checks passed 

[4/4] Deployment Summary
══════════════════════════════════════════════════════════════

  ─ SERVER IDENTITY ─
  Target:          alp-qlikview-03ilo
  Identifier:      alp-qlikview-03ilo
  Serial:          unknown
  Model:           unknown
  iLO IP:
  OneView URI:     unknown
  Rack/Position:   unknown 
  Server Group:    unknown
  Maintenance Mode:unknown

  ─ ISO DETAILS ─
  Source:          External ISO: Y:\WIN2019Auto.iso
  URL:             cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/WIN2019Auto.iso
  Contents:        Windows Server boot media + ConfigMgr task sequence 

  ─ FIRMWARE UPDATE (post-OS-install) ─
  Component folders:
    - Y:\Drivers for Windows ISO\FC-14.4.624.0-1
    - Y:\Drivers for Windows ISO\MR216i-a Win19Drivers
  Manifest:
 
  ─ DESTRUCTIVE ACTIONS (will be executed by Start-PhysicalBuild) ─
  1. Disk partitioning & formatting (ALL data will be erased)
  2. Windows OS installation from ISO
  3. Server reboot into installed OS
  4. Post-build validation (hostname, domain join, drivers)
  5. Firmware update via HPE SUT (reboots during apply)

  ─ PRE-BUILD VALIDATION RESULTS ─
  [PASS] oneview_target : {"DryRun":true,"Server":"alp-qlikview-03ilo","Details":{"identifier":"alp-qlikview-03ilo","type":"A03ilo","type":"Auto","oneview_host":"va-oneviewt-01"},"Success":true}
  [FAIL] iso_url_format : DryRun - cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
                /WIN2019Auto.iso
  [PASS] ilo_credentials : skipped
  [PASS] audit_recorded : prebuild_alp-qlikview-03ilo logged

  Maintenance window: NOT acknowledged (-InMaintenanceWindow not set)
  This build will reboot a running server if it is On.

══════════════════════════════════════════════════════════════

  ╔════════════════════════════════════════════════════════╗
  ║  ⚠  DESTRUCTIVE ACTION WARNING                       ║
  ║  This will ERASE ALL DATA on the target server and    ║
  ║  install a fresh Windows Server OS + firmware.        ║
  ║                                                      ║
  ║  Type 'DEPLOY' (without quotes) to proceed.           ║
  ║  Anything else cancels this build.                    ║
  ╚════════════════════════════════════════════════════════╝

  Confirm deployment for 'alp-qlikview-03ilo': n
  Build CANCELLED by operator.

Name                           Value
----                           -----
Cancelled                      True
ServerIdentity                 {[identifier, alp-qlikview-03ilo], [type, Auto], [oneview_host, va-oneviewt-…
ValidationChecks               {[oneview_target, System.Collections.Hashtable], [iso_url_format, System.Col…
Reason                         Operator did not confirm with 'DEPLOY'
Server                         alp-qlikview-03ilo
Success                        False
IsoUrl                         cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE                                  …

```
