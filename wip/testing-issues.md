# Testing Issues

<a id="top"></a>

## Table of Contents

- [Friday 14 Aug 14:33](#friday-14-aug-1433)
  - [Test-ServerConnectivity](#test-serverconnectivity)
  - [Test-ServerConnectivity -ManagementHost oneview.example.com Test-ServerConnectivity: A parameter cannot be found that matches parameter name 'ManagementHost'.](#test-serverconnectivity-managementhost-oneviewexamplecom-test-serverconnectivity-a-parameter-cannot-be-found-that-matches-parameter-name-managementhost)
  - [Test-ServerConnectivity -OneViewHost oneview.example.com    ](#test-serverconnectivity-oneviewhost-oneviewexamplecom)
  - [Connect-OneView -OneViewHost va-oneviewt-01                        0 ](#connect-oneview-oneviewhost-va-oneviewt-01-0)
  - [$cred = Get-Credential   ](#cred-get-credential)
  - [Test-ServerConnectivity  ](#test-serverconnectivity-1)
  - [Test-ServerConnectivity  -OneViewHost va-oneviewt-01        ](#test-serverconnectivity-oneviewhost-va-oneviewt-01)
  - [Get-OneViewConnectionStatus](#get-oneviewconnectionstatus)
  - [Get-OneViewConnectionStatus -OVHost va-oneviewt-01](#get-oneviewconnectionstatus-ovhost-va-oneviewt-01)
  - [Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 ](#get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01)
  - [Get-OneViewConnectionStatus                             ](#get-oneviewconnectionstatus-1)
  - [Get-OneViewConnectionStatus -IncludeServerCount](#get-oneviewconnectionstatus-includeservercount)
  - [Get-OneViewServerList](#get-oneviewserverlist)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01](#get-oneviewserverlist-oneviewhost-va-oneviewt-01)
  - [Test-ServerList](#test-serverlist)
  - [Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2025.iso'   ](#test-buildparams-baseisopath-ywin2019autoiso-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2025iso)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2019.iso' ](#test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2019iso)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' ](#test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso)
  - [ls  '//vm-ewismgt-19/Kev/WIN2019Auto.iso'  ](#ls-vm-ewismgt-19kevwin2019autoiso)
  - [ls  '//vm-ewismgt-19/'](#ls-vm-ewismgt-19)
  - [ls  '//vm-ewismgt-19/*'                                                      0  10:34:](#ls-vm-ewismgt-19-0-1034)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'](#test-buildparams-baseisopath-vm-ewismgt-19kev)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/*'](#test-buildparams-baseisopath-vm-ewismgt-19kev-1)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/W      0  10:35:IN2019Auto.iso'          ](#test-buildparams-baseisopath-vm-ewismgt-19kevw-0-1035in2019autoiso)
  - [Test-BuildParams -BaseIsoPath 'Y:age-build-autom\Drivers for Windows ISO\FC-14.4.624.0-1'   0  ](#test-buildparams-baseisopath-yage-build-automdrivers-for-windows-isofc-1446240-1-0)
  - [Test-BuildParams -BaseIsoPath 'Y:\Drivers for Windows ISO\FC-14.4.624.0-1\*'   ](#test-buildparams-baseisopath-ydrivers-for-windows-isofc-1446240-1)
  - [Configure-PhysicalBuild -ServerIdentifier alp-qlikview-03ilo -OneViewHo624.0-1', 'Y:\Dst va-oneviewt-01 -ExpectedHostname -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drif type 'System.vers') -GuardRail  'qlikview-03ilo'                                                                 ](#configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewho6240-1-ydst-va-oneviewt-01-expectedhostname-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drif-type-systemvers-guardrail-qlikview-03ilo)
  - [Configure-PhysicalBuild -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)
  - [Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-1)
  - [Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'  ](#configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-2)
  - [Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-smbvm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)
  - [   image-build-automation Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'Y:\WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'](#image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-ywin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo)
- [Tuesday 18th August](#tuesday-18th-august)
  - [Test-ServerConnectivity                   0  15:45:10 ](#test-serverconnectivity-0-154510)
  - [Test-ServerConnectivity  -OneViewHost va-oneviewt-01](#test-serverconnectivity-oneviewhost-va-oneviewt-01-1)
  - [Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'](#test-buildparams-baseisopath-ywin2019autoiso)
  - [Connect-OneView](#connect-oneview)
  - [Get-OneViewConnectionStatus](#get-oneviewconnectionstatus-2)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-1)
  - [Get-OneViewConnectionStatus -IncludeServerCount](#get-oneviewconnectionstatus-includeservercount-1)
  - [Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 ](#get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01-1)
  - [Get-OneViewConnectionStatus](#get-oneviewconnectionstatus-3)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'health:Warning'](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-healthwarning)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:Off' ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweroff)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-2)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -SrvrId CZ22420JCM -IdType Serial ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-srvrid-cz22420jcm-idtype-serial)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerId CZ22420JCM -IdType Serial ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-serverid-cz22420jcm-idtype-serial)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCM -IdType Serial](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcm-idtype-serial)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCM -IdType Serial](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcm-idtype-serial-1)
  - [Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier srv01](#get-oneviewconnectionstatus-oneviewhost-oneviewexamplecom-serveridentifier-srv01)
  - [Get-OneViewConnectionStatus -ServerIdentifier srv01 -ServerIdentifier CZ22420JCM -IdType Serial00 ](#get-oneviewconnectionstatus-serveridentifier-srv01-serveridentifier-cz22420jcm-idtype-serial00)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCM -IdType Serial ](#get-oneviewconnectionstatus-serveridentifier-cz22420jcm-idtype-serial)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCM -IdentifierType Serial ](#get-oneviewconnectionstatus-serveridentifier-cz22420jcm-identifiertype-serial)
  - [Get-OneViewConnectionStatus -ServerIdentifier omg-qlikview-03ilo -IdentifierType OneViewName](#get-oneviewconnectionstatus-serveridentifier-omg-qlikview-03ilo-identifiertype-oneviewname)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial)
  - [Get-OneViewServerList](#get-oneviewserverlist-1)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01  ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-3)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-4)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCN -IdentifierType Serial](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 ServerIdentifier CZ22420JCN -IdentifierType Serial  ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial-1)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial ](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial-1)
  - [Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCN -IdentifierType Serial](#get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial ](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial-2)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Auto](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-auto)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype)
  - [Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN](#get-oneviewconnectionstatus-serveridentifier-cz22420jcn)
  - [Get-OneViewConnectionStatus -ServerIdentifier alp-qlikview-03ilo  ](#get-oneviewconnectionstatus-serveridentifier-alp-qlikview-03ilo)
  - [Get-OneViewServerList -ServerIdentifier alp-qlikview-03ilo](#get-oneviewserverlist-serveridentifier-alp-qlikview-03ilo)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:Off'                 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweroff-1)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:On'                  0  17:45:07 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweron-0-174507)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:*qlikview-03ilo'      0  17:45:20 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03ilo-0-174520)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:qlikview-03ilo'       0  17:50:27 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03ilo-0-175027)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:qlikview-03'          0  17:50:59 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03-0-175059)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:ALP'](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-namealp)
  - [OneViewServerList  ](#oneviewserverlist)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:alp'                  0  17:51:51 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-namealp-0-175151)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:omg'                  0  17:52:04 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameomg-0-175204)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:ilo'                  0  17:52:58 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameilo-0-175258)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:03ilo'                0  17:53:36 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-name03ilo-0-175336)
  - [Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:0*ilo'                0  17:53:53 ](#get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-name0ilo-0-175353)
  - [Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'                                    0  17:54:36   ](#test-buildparams-baseisopath-ywin2019autoiso-0-175436)
  - [Test-BuildParams -BaseIsoPath '//Hnascifsprd6/roi1/BKCWISAPPS/KevinE'                 0  18:06:51  ](#test-buildparams-baseisopath-hnascifsprd6roi1bkcwisappskevine-0-180651)
  - [Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE'            0  18:08:13 ](#test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevine-0-180813)
  - [Test-BuildParams -BaseIsoPath 'Y:\jjWIN2019Auto.iso'                                  0  18:08:36   ](#test-buildparams-baseisopath-yjjwin2019autoiso-0-180836)
  - [Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso'8:09:15 ](#test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevinewin2019autoiso80915)
  - [Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/'                                  8:09:29 ](#test-buildparams-baseisopath-smbvm-ewismgt-19kev-80929)
  - [Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/Win2019Auto.iso'               0  18:10:37 ](#test-buildparams-baseisopath-smbvm-ewismgt-19kevwin2019autoiso-0-181037)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/Win2019Auto.iso'                   0  18:11:10 ](#test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso-0-181110)
  - [Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'                                  0  18:11:56 ](#test-buildparams-baseisopath-vm-ewismgt-19kev-0-181156)
  - [Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso'  ](#test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevinewin2019autoiso)

<a id="friday-14-aug-1433"></a>

## Friday 14 Aug 14:33

<a id="test-serverconnectivity"></a>

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

<a id="test-serverconnectivity-managementhost-oneviewexamplecom-test-serverconnectivity-a-parameter-cannot-be-found-that-matches-parameter-name-managementhost"></a>

### Test-ServerConnectivity -ManagementHost oneview.example.com Test-ServerConnectivity: A parameter cannot be found that matches parameter name 'ManagementHost'.

<a id="test-serverconnectivity-oneviewhost-oneviewexamplecom"></a>

### Test-ServerConnectivity -OneViewHost oneview.example.com    

```text

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

<a id="connect-oneview-oneviewhost-va-oneviewt-01-0"></a>

### Connect-OneView -OneViewHost va-oneviewt-01                        0 

```text
C:\Users\[REDACTED]\products\repos\image-build-automation\generated\logs\commands\Connect-OneView 
2026-08-14 09:19:41 - Connect-OneView - INFO - Connect-OneView invoked: OneViewHost='va-oneviewt-0
Enter OneView username for 'va-oneviewt-01': [REDACTED] 
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

<a id="cred-get-credential"></a>

### $cred = Get-Credential   

```text                                      0  1m 
PowerShell credential request 
Enter your credentials.       
User: [REDACTED] 
Password for user [REDACTED]: ****************** 

```

<a id="test-serverconnectivity-1"></a>

### Test-ServerConnectivity  

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

<a id="test-serverconnectivity-oneviewhost-va-oneviewt-01"></a>

### Test-ServerConnectivity  -OneViewHost va-oneviewt-01        

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

<a id="get-oneviewconnectionstatus"></a>

### Get-OneViewConnectionStatus

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

<a id="get-oneviewconnectionstatus-ovhost-va-oneviewt-01"></a>

### Get-OneViewConnectionStatus -OVHost va-oneviewt-01

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

<a id="get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01"></a>

### Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 

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

<a id="get-oneviewconnectionstatus-1"></a>

### Get-OneViewConnectionStatus                             

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

<a id="get-oneviewconnectionstatus-includeservercount"></a>

### Get-OneViewConnectionStatus -IncludeServerCount

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

<a id="get-oneviewserverlist"></a>

### Get-OneViewServerList

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

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01

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

<a id="test-serverlist"></a>

### Test-ServerList

```text
Name                           Value
----                           -----
Servers                        {server1.example.com, server2.example.com, server3.example.com, pro
Success                        True
 ```

<a id="test-buildparams-baseisopath-ywin2019autoiso-test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2025iso"></a>

### Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2025.iso'   

```text
Base ISO not found: //vm-ewismgt-19/Kev/WinSrv2025.iso 
```

<a id="test-buildparams-baseisopath-vm-ewismgt-19kevwinsrv2019iso"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2019.iso' 

```text
Base ISO not found: //vm-ewismgt-19/Kev/WinSrv2019.iso 
```

<a id="test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' 

<a id="ls-vm-ewismgt-19kevwin2019autoiso"></a>

### ls  '//vm-ewismgt-19/Kev/WIN2019Auto.iso'  

```text
    Directory: \\vm-ewismgt-19\Kev

Mode                 LastWriteTime         Length Name
 ```

<a id="ls-vm-ewismgt-19"></a>

### ls  '//vm-ewismgt-19/'

```text
      0  10:34:23 Get-ChildItem: Cannot find path '//vm-ewismgt-19/' because it does not exist.    
```

<a id="ls-vm-ewismgt-19-0-1034"></a>

### ls  '//vm-ewismgt-19/*'                                                      0  10:34:

```text
      1  10:34:36 ### ls  '//vm-ewismgt-19/Kev/*'
                         0  10:34:50                                                                     1  10:34:
    Directory: \\vm-ewismgt-19\Kev
 
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---          29/06/2022    16:54     5102354432 WIN2019Auto.iso
 ```

<a id="test-buildparams-baseisopath-vm-ewismgt-19kev"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'

 ```text
      0  10:35:21 Base ISO not found: //vm-ewismgt-19/Kev/                                               0  10:35:

```

<a id="test-buildparams-baseisopath-vm-ewismgt-19kev-1"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/*'

<a id="test-buildparams-baseisopath-vm-ewismgt-19kevw-0-1035in2019autoiso"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/W      0  10:35:IN2019Auto.iso'          

<a id="test-buildparams-baseisopath-yage-build-automdrivers-for-windows-isofc-1446240-1-0"></a>

### Test-BuildParams -BaseIsoPath 'Y:age-build-autom\Drivers for Windows ISO\FC-14.4.624.0-1'   0  

Base ISO not found: Y:\Drivers for Windows r Windows ISO\FISO\FC-14.4.624.0-1                                                                                 -1\*' 0  

<a id="test-buildparams-baseisopath-ydrivers-for-windows-isofc-1446240-1"></a>

### Test-BuildParams -BaseIsoPath 'Y:\Drivers for Windows ISO\FC-14.4.624.0-1\*'   

```text
10:38:28 Base ISO not found: Y:\Drivers for WindowsISO\FC-14.4.624.0-1\*                 st va-oneviewt-
```

<a id="configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewho6240-1-ydst-va-oneviewt-01-expectedhostname-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drif-type-systemvers-guardrail-qlikview-03ilo"></a>

### Configure-PhysicalBuild -ServerIdentifier alp-qlikview-03ilo -OneViewHo624.0-1', 'Y:\Dst va-oneviewt-01 -ExpectedHostname -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drif type 'System.vers') -GuardRail  'qlikview-03ilo'                                                                 

```text
Host 'va-onevie
Configure-PhysicalBuild: Missing an argument for parameter 'ExpectedHostname'. Specify a parameter o for Windows ISf type 'System.String' and try again.
```

<a id="configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

### Configure-PhysicalBuild -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

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
Exception: C:\Users\[REDACTED]\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line |
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '/vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL,
     | NFS path, or UNC/SMB path (\\server\share\file.iso).
```

<a id="configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-1"></a>

### Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

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
Exception: C:\Users\[REDACTED]\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '//vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB     
     | path (\\server\share\file.iso).
```

<a id="configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-vm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo-2"></a>

### Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath '//vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'  

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
Exception: C:\Users\[REDACTED]\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Unsupported ISO path format: '//vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB     
     | path (\\server\share\file.iso).
```

<a id="configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-smbvm-ewismgt-19kevwin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

### Configure-PhysicalBuild  -ServerIdentifier 'alp-qlikview-03ilo' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso' -FirmwareFolders @('Y:\Drivers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows ISO\MR216i-a Win19Drivers') -GuardRail  'qlikview-03ilo'

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
Exception: C:\Users\[REDACTED]\products\repos\image-build-automation\src\powershell\Automation\Public\Start-PhysicalServerBuild.ps1:191:5
Line | 
 191 |      throw "Unsupported ISO path format: '$IsoPath'. Expected HTTP/HTT … 
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
     | Unsupported ISO path format: 'smb://vm-ewismgt-19/Kev/WIN2019Auto.iso'. Expected HTTP/HTTPS URL, NFS path, or UNC/SMB 
     | path (\\server\share\file.iso).
```

<a id="image-build-automation-configure-physicalbuild-serveridentifier-alp-qlikview-03ilo-oneviewhost-va-oneviewt-01-expectedhostname-alp-qlikview-03ilo-externalisopath-ywin2019autoiso-firmwarefolders-ydrivers-for-windows-isofc-1446240-1-ydrivers-for-windows-isomr216i-a-win19drivers-guardrail-qlikview-03ilo"></a>

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

<a id="tuesday-18th-august"></a>

## Tuesday 18th August

<a id="test-serverconnectivity-0-154510"></a>

### Test-ServerConnectivity                   0  15:45:10 

```text
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       
  Environment:Prod
  Timestamp:  2026-08-18T14:46:00.9893991Z 

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     No active OneView connection. Connect first with Connect-OneView -OneViewHost <host> (server 
name or serial), or supply -OneViewHost to test a specific appliance.

  --- Phase 2: Auth Connect ---
    Module:    Not loaded 
    Connected: No 
    Error:     Skipped - no active connection  

============================================== 
```

<a id="test-serverconnectivity-oneviewhost-va-oneviewt-01-1"></a>

### Test-ServerConnectivity  -OneViewHost va-oneviewt-01

```text
2026-08-18 14:46:37 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-08-18 14:46:37 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 12ms) 
2026-08-18 14:46:37 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)

============================================== 
  OneView Connectivity Test
============================================== 
 
  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod 
  Timestamp:  2026-08-18T14:46:37.8853192Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 12ms)

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - credentials not supplied 
 
==============================================

```

<a id="test-buildparams-baseisopath-ywin2019autoiso"></a>

### Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'

```text
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/WIN2019Auto.iso

Name                           Value
----                           -----
IsoUrl                         cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE                                 … 
ResolvedPath                   Y:\WIN2019Auto.iso
Success                        True
Errors                         {}
BaseIsoPath                    Y:\WIN2019Auto.iso
```

<a id="connect-oneview"></a>

### Connect-OneView

```text
15:52:44 2026-08-18 14:52:56 - Connect-OneView - INFO - Connect-OneView invoked: OneViewHost='' DryRun=False PassThru=False Json=False
Enter OneView appliance host to connect to (or press Enter to cancel): va-oneviewt-01 
Enter OneView username for 'va-oneviewt-01': [REDACTED] 
Enter OneView password for 'va-oneviewt-01': : ****************** 
2026-08-18 14:53:26 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-08-18 14:53:26 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 7ms) 
This management appliance is a company owned asset and provided for the exclusive use of authorized personnel. Unauthorized use or abuse of this system may lead to corrective action including termination, civil and/o
r criminal penalties.

2026-08-18 14:54:15 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)
2026-08-18 14:54:15 - Connect-OneView - INFO - Connect-OneView result: Available=True Message='Connected to OneView appliance 'va-oneviewt-01'.'

==============================================
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-18T14:54:15.5879859Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 7ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000  v10.0.4265.2221 (module used for all OneView calls on this server)
    Appliance OneView version: 8200
    Connected: Yes (session active)

==============================================

```

<a id="get-oneviewconnectionstatus-2"></a>

### Get-OneViewConnectionStatus

```text

2026-08-18 14:57:37 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-1"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

2026-08-18 14:58:16 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16 

```

<a id="get-oneviewconnectionstatus-includeservercount-1"></a>

### Get-OneViewConnectionStatus -IncludeServerCount

```text
2026-08-18 14:58:31 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

<a id="get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01-1"></a>

### Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 

```text
2026-08-18 14:58:44 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=False Connected=False Reachable=True Authenticated=False Error='OneView authentication failed for '': Response status code does not indicate success: 401 (Unauthorized).'

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

  Error:   OneView authentication failed for '': Response status code does not indicate success: 401 (Unauthorized).

==============================================

```

<a id="get-oneviewconnectionstatus-3"></a>

### Get-OneViewConnectionStatus

```text

026-08-18 14:58:56 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-healthwarning"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'health:Warning'

```text
==============================================
  OneView Server List (3 servers)
==============================================

Server Name        Serial Number    Power     Health      iLO IP          
------------------------------------------------------------------------- 
OMG-CONSTC2-02ilo  CZ2D3701LY       On        Warning                     
ALP-CONSTC1-01ilo  CZ2D3701LT       On        Warning                     
ALP-CONSTC2-01ilo  CZ2D3701LV       On        Warning                     

==============================================

2026-08-18 14:59:48 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=3

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweroff"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:Off' 

```text
No servers matched the request. 
 
2026-08-18 15:00:14 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=0

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-2"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================
 
2026-08-18 15:00:38 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16 

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-srvrid-cz22420jcm-idtype-serial"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -SrvrId CZ22420JCM -IdType Serial 

```text
16:00:38 Get-OneViewServerList: A parameter cannot be found that matches parameter name 'SrvrId'. 

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-serverid-cz22420jcm-idtype-serial"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerId CZ22420JCM -IdType Serial 

```text
16:01:47 Get-OneViewServerList: A parameter cannot be found that matches parameter name 'ServerId'. 

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcm-idtype-serial"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCM -IdType Serial

```text
Get-OneViewServerList: A parameter cannot be found that matches parameter name 'ServerIdentifier'. 

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcm-idtype-serial-1"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCM -IdType Serial

```text
Get-OneViewServerList: A parameter cannot be found that matches parameter name 'ServerIdentifier'. 
```

<a id="get-oneviewconnectionstatus-oneviewhost-oneviewexamplecom-serveridentifier-srv01"></a>

### Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier srv01

```text
16:03:55 2026-08-18 15:04:00 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=False Connected=False Reachable=False Authenticated=False Error='OneView appliance 'oneview.example.com' is not reachable: The requested name is valid, but no data of the requested type was found. (oneview.example.com:443)'

==============================================
  OneView Connection Status
==============================================

  Status:    NOT CONNECTED
  Appliance: oneview.example.com 
  Reachable: False
  Auth:      False
  Session:   Explicit

  Error:   OneView appliance 'oneview.example.com' is not reachable: The requested name is valid, but no data of the requested type was found. (oneview.example.com:443)

==============================================

```

<a id="get-oneviewconnectionstatus-serveridentifier-srv01-serveridentifier-cz22420jcm-idtype-serial00"></a>

### Get-OneViewConnectionStatus -ServerIdentifier srv01 -ServerIdentifier CZ22420JCM -IdType Serial00 

```text
Get-OneViewConnectionStatus: Cannot bind parameter because parameter 'SrvrId' is specified more than once. To provide multiple values to parameters that can accept multiple values, use the array syntax. For example, "-parameter value1,value2,value3".      
```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcm-idtype-serial"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCM -IdType Serial 

```text
Get-OneViewConnectionStatus: A parameter cannot be found that matches parameter name 'IdType'. 
```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcm-identifiertype-serial"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCM -IdentifierType Serial 

```text
16:04:58 2026-08-18 15:05:28 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    alp-qlikview-03ilo
    Serial:  CZ22420JCM 
    Power:   On
    Health:  OK

==============================================
 
```

<a id="get-oneviewconnectionstatus-serveridentifier-omg-qlikview-03ilo-identifiertype-oneviewname"></a>

### Get-OneViewConnectionStatus -ServerIdentifier omg-qlikview-03ilo -IdentifierType OneViewName

```text
2026-08-18 15:06:42 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''
 
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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN 
    Power:   On
    Health:  OK

==============================================

```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial

```text             06:42 2026-08-18 15:07:56 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN
    Power:   On
    Health:  OK

==============================================

```

<a id="get-oneviewserverlist-1"></a>

### Get-OneViewServerList

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================
 
2026-08-18 16:30:22 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-3"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01  

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================
 
2026-08-18 16:31:04 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16 
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-4"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

2026-08-18 16:37:15 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCN -IdentifierType Serial

```text
Get-OneViewServerList: A parameter cannot be found that matches parameter name 'ServerIdentifier'. 
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial-1"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 ServerIdentifier CZ22420JCN -IdentifierType Serial  

```text
 
PowerShell credential request 
Enter your credentials.
Password for user ServerIdentifier:
```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial-1"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial 

```text
2026-08-18 16:40:21 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN
    Power:   On 
    Health:  OK
 
==============================================

```

<a id="get-oneviewconnectionstatus-oneviewhost-va-oneviewt-01-serveridentifier-cz22420jcn-identifiertype-serial"></a>

### Get-OneViewConnectionStatus -OneViewHost va-oneviewt-01 -ServerIdentifier CZ22420JCN -IdentifierType Serial

```text
2026-08-18 16:41:09 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=False Connected=False Reachable=True Authenticated=False Error='OneView authentication failed for '': Response status code does not indicate success: 401 (Unauthorized).'

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

  Error:   OneView authentication failed for '': Response status code does not indicate success: 401 (Unauthorized).

==============================================

```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-serial-2"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Serial 

```text
2026-08-18 16:42:03 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN
    Power:   On
    Health:  OK

==============================================
 
```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype-auto"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType Auto

```text

17:42:04 2026-08-18 16:42:14 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''
 
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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN 
    Power:   On
    Health:  OK

==============================================

```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn-identifiertype"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN -IdentifierType

```text              
17:42:15 Get-OneViewConnectionStatus: Missing an argument for parameter 'IdentifierType'. Specify a parameter of type 'System.String' and try again.
```

<a id="get-oneviewconnectionstatus-serveridentifier-cz22420jcn"></a>

### Get-OneViewConnectionStatus -ServerIdentifier CZ22420JCN

```text                             
17:42:24 2026-08-18 16:42:31 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    omg-qlikview-03ilo
    Serial:  CZ22420JCN
    Power:   On
    Health:  OK

==============================================

```

<a id="get-oneviewconnectionstatus-serveridentifier-alp-qlikview-03ilo"></a>

### Get-OneViewConnectionStatus -ServerIdentifier alp-qlikview-03ilo  

```text
17:42:31 2026-08-18 16:43:03 - OneViewConnectivity - INFO - Get-OneViewConnectionStatus result: Success=True Connected=True Reachable=True Authenticated=True Error=''

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

  --- Server ---
    Name:    alp-qlikview-03ilo
    Serial:  CZ22420JCM
    Power:   On
    Health:  OK 

==============================================

```

<a id="get-oneviewserverlist-serveridentifier-alp-qlikview-03ilo"></a>

### Get-OneViewServerList -ServerIdentifier alp-qlikview-03ilo

```text
erList: A parameter cannot be found that matches parameter name 'ServerIdentifier'. 
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweroff-1"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:Off'                 

No servers matched the request.

2026-08-18 16:45:07 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=0 

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-poweron-0-174507"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'power:On'                  0  17:45:07 

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

2026-08-18 16:45:20 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03ilo-0-174520"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:*qlikview-03ilo'      0  17:45:20 

```text
No servers matched the request. 
 
2026-08-18 16:50:27 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=0
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03ilo-0-175027"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:qlikview-03ilo'       0  17:50:27 

```text
============================================== 
  OneView Server List (2 servers)
==============================================

Server Name         Serial Number    Power     Health      iLO IP
--------------------------------------------------------------------------
alp-qlikview-03ilo  CZ22420JCM       On        OK
omg-qlikview-03ilo  CZ22420JCN       On        OK

==============================================

2026-08-18 16:50:59 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=2

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameqlikview-03-0-175059"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:qlikview-03'          0  17:50:59 

```text
============================================== 
  OneView Server List (2 servers)
==============================================

Server Name         Serial Number    Power     Health      iLO IP
--------------------------------------------------------------------------
alp-qlikview-03ilo  CZ22420JCM       On        OK
omg-qlikview-03ilo  CZ22420JCN       On        OK

==============================================

2026-08-18 16:51:21 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=2 
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-namealp"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:ALP'

```text

0  17:51:21 
============================================== 
  OneView Server List (6 servers)
==============================================

Server Name         Serial Number    Power     Health      iLO IP
--------------------------------------------------------------------------
ALP-WISCLU-01ilo    CZ3508PYS5       On        OK
ALP-STARWAY-01ILO   CZJ831052R       On        OK
ALP-CONSTC1-01ilo   CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo   CZ2D3701LV       On        Warning
alp-qlikview-03ilo  CZ22420JCM       On        OK
alp-qliksen-02ilo   CZ22420JCZ       On        OK

============================================== 

2026-08-18 16:51:51 - 

```

<a id="oneviewserverlist"></a>

### OneViewServerList  

```text

- INFO - Get-OneViewServerList result: Success=True Count=6

```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-namealp-0-175151"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:alp'                  0  17:51:51 

```text
============================================== 
  OneView Server List (6 servers)
==============================================

Server Name         Serial Number    Power     Health      iLO IP
--------------------------------------------------------------------------
ALP-WISCLU-01ilo    CZ3508PYS5       On        OK
ALP-STARWAY-01ILO   CZJ831052R       On        OK
ALP-CONSTC1-01ilo   CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo   CZ2D3701LV       On        Warning
alp-qlikview-03ilo  CZ22420JCM       On        OK                          
alp-qliksen-02ilo   CZ22420JCZ       On        OK

==============================================

2026-08-18 16:52:04 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=6
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameomg-0-175204"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:omg'                  0  17:52:04 

```text
============================================== 
  OneView Server List (6 servers)
==============================================

Server Name                   Serial Number    Power     Health      iLO IP
------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI  CZJ831052N       On        OK
OMG-WISCLU-01ilo              CZJ5500337       On        OK
OMG-CONSTC2-02ilo             CZ2D3701LY       On        Warning
OMG-CONSTC1-02ilo             CZ2D3701LZ       On        OK
omg-qlikview-03ilo            CZ22420JCN       On        OK
omg-qliksen-02ilo             CZ22420JD0       On        OK

==============================================
 
2026-08-18 16:52:58 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=6
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-nameilo-0-175258"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:ilo'                  0  17:52:58 

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
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        OK
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

2026-08-18 16:53:36 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=16
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-name03ilo-0-175336"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:03ilo'                0  17:53:36 

```text
============================================== 
  OneView Server List (6 servers)
==============================================

Server Name                      Serial Number    Power     Health      iLO IP
---------------------------------------------------------------------------------------
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK

==============================================

2026-08-18 16:53:52 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=6
```

<a id="get-oneviewserverlist-oneviewhost-va-oneviewt-01-filter-name0ilo-0-175353"></a>

### Get-OneViewServerList -OneViewHost va-oneviewt-01 -Filter 'name:0*ilo'                0  17:53:53 

```text
No servers matched the request. 

2026-08-18 16:54:36 - OneViewServerList - INFO - Get-OneViewServerList result: Success=True Count=0
```

<a id="test-buildparams-baseisopath-ywin2019autoiso-0-175436"></a>

### Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'                                    0  17:54:36   

```text
[INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/WIN2019Auto.iso

Name                           Value 
----                           ----- 
IsoUrl                         cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE                                                     … 
ResolvedPath                   Y:\WIN2019Auto.iso
Success                        True
Errors                         {}
BaseIsoPath                    Y:\WIN2019Auto.iso

```

<a id="test-buildparams-baseisopath-hnascifsprd6roi1bkcwisappskevine-0-180651"></a>

### Test-BuildParams -BaseIsoPath '//Hnascifsprd6/roi1/BKCWISAPPS/KevinE'                 0  18:06:51  

```text
Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: '//Hnascifsprd6/roi1/BKCWISAPPS/KevinE'. Expected HTTP/HTTPS URL,… 
BaseIsoPath                    //Hnascifsprd6/roi1/BKCWISAPPS/KevinE

```

<a id="test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevine-0-180813"></a>

### Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE'            0  18:08:13 

```text
Name                           Value
----                           ----- 
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE'. Expected HTTP/HTTPS… 
BaseIsoPath                    cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE

```

<a id="test-buildparams-baseisopath-yjjwin2019autoiso-0-180836"></a>

### Test-BuildParams -BaseIsoPath 'Y:\jjWIN2019Auto.iso'                                  0  18:08:36   

```text
[INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
\jjWIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE
/jjWIN2019Auto.iso

Name                           Value
----                           -----
IsoUrl                         cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE                                                     … 
ResolvedPath                   Y:\jjWIN2019Auto.iso
Success                        False
Errors                         {Base ISO not found or not accessible: Y:\jjWIN2019Auto.iso}
BaseIsoPath                    Y:\jjWIN2019Auto.iso 

```

<a id="test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevinewin2019autoiso80915"></a>

### Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso'8:09:15 

```text
Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso'. Exp… 
BaseIsoPath                    cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso 
 
```

<a id="test-buildparams-baseisopath-smbvm-ewismgt-19kev-80929"></a>

### Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/'                                  8:09:29 

```text
Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: 'smb://vm-ewismgt-19/Kev/'. Expected HTTP/HTTPS URL, NFS path, or… 
BaseIsoPath                    smb://vm-ewismgt-19/Kev/

```

<a id="test-buildparams-baseisopath-smbvm-ewismgt-19kevwin2019autoiso-0-181037"></a>

### Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/Win2019Auto.iso'               0  18:10:37 

Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: 'smb://vm-ewismgt-19/Kev/Win2019Auto.iso'. Expected HTTP/HTTPS UR… 
BaseIsoPath                    smb://vm-ewismgt-19/Kev/Win2019Auto.iso

<a id="test-buildparams-baseisopath-vm-ewismgt-19kevwin2019autoiso-0-181110"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/Win2019Auto.iso'                   0  18:11:10 

```text
Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: '//vm-ewismgt-19/Kev/Win2019Auto.iso'. Expected HTTP/HTTPS URL, N… 
BaseIsoPath                    //vm-ewismgt-19/Kev/Win2019Auto.iso

```

<a id="test-buildparams-baseisopath-vm-ewismgt-19kev-0-181156"></a>

### Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'                                  0  18:11:56 

```text
Name                           Value
----                           -----
IsoUrl
ResolvedPath
Success                        False
Errors                         {Unsupported ISO path format: '//vm-ewismgt-19/Kev/'. Expected HTTP/HTTPS URL, NFS path, or UNC… 
BaseIsoPath                    //vm-ewismgt-19/Kev/

```

<a id="test-buildparams-baseisopath-cifshnascifsprd6roi1bkcwisappskevinewin2019autoiso"></a>

### Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.iso'  

```text
10>                                                                                 <History(10)>
> Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/'                                     [History]
> Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/Win2019Auto.iso'                      [History]
> Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/Win2019Auto.iso'                  [History]
> Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/'                                 [History]
> Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WIN2019Auto.i… [History]
> Test-BuildParams -BaseIsoPath 'Y:\jjWIN2019Auto.iso'                                     [History]
> Test-BuildParams -BaseIsoPath 'cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE'               [History]
> Test-BuildParams -BaseIsoPath '//Hnascifsprd6/roi1/BKCWISAPPS/KevinE'                    [History]
> Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'                                       [History]
> Test-BuildParams -BaseIsoPath 'Y:\Drivers for Windows ISO\FC-14.4.624.0-1\*'             [History]
```
