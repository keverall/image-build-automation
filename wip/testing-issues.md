# Testing Issues

<a id="top"></a>

## Table of Contents

- [Tuesday 24th August](#tuesday-24th-august)
- [Wednesday 26th August](#wednesday-26th-august)

<a id="tuesday-24th-august"></a>

## Tuesday 24th August

```text
 image-build-automation  Test-PreBuildValidation -SC:\Users\adm_98253\products\repos\image-build-automatio
C:\Users\adm_98253\products\repos\image-build-automatio5T08-43-45Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System
Timestamp                      2026-08-25T08:43:45.6511
Server                         omg-qlikview-03ilo

   image-build-automation  Get-OneViewServerList

==============================================
  OneView Server List (16 servers)
==============================================

Server Name                      Serial Number    Power
-------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On   
8 C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026-08-25T08-44-36Z.json2026-08-25T08-44-36Z.json

Name                           Value
----                           -----
Success                        True                                                                            Co…
Checks                         {[oneview_target, System.Collections.Hashtable], [iso_url_check_skipped, System.pped, System.Co…
Timestamp                      2026-08-25T08:44:36.2860633Z
Server                         CZ22420JCM                                                                      36 

   image-build-automation                                                                           0  09:44:
    0  09:44:36 

 image-build-automation  Test-PreBuildValidation -SWARNING: Already connected to OneView appliance 'va-oneting session (reconnecting would drop the live session)ryRun'.
C:\Users\adm_98253\products\repos\image-build-automatio
C:\Users\adm_98253\products\repos\image-build-automatio5T08-42-54Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System
Timestamp                      2026-08-25T08:42:54.7043
Server                         omg-qlikview-03ilo
{
  "success": true,
  "checks": {
    "oneview_target": {
      "details": "{\"DryRun\":true,\"Server\":\"alp-qlikview-03ilo\",\"Details\":{\"identifier\":\"alp-qlikview-03ilo\",\"type\":\"Auto\",\"oneview_host\":\"va-oneviewt-01\"},\"Success\":true}",
      "status": "PASS"
    },
    "iso_url_format": {
      "details": "DryRun - cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000/WIN2019Auto.iso",
      "status": "FAIL"
    },
    "ilo_credentials": {
      "details": "skipped",
      "status": "PASS"
    }
  },
  "event": "prebuild_validation",
  "server": "alp-qlikview-03ilo",
  "timestamp": "2026-08-14T13:27:33.2726898Z"
}

   image-build-automation  Test-PreBuildValidation -SC:\Users\adm_98253\products\repos\image-build-automatio
C:\Users\adm_98253\products\repos\image-build-automatio5T08-43-45Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System
Timestamp                      2026-08-25T08:43:45.6511
Server                         omg-qlikview-03ilo

   image-build-automation  Get-OneViewServerList

==============================================
  OneView Server List (16 servers)
==============================================

Server Name                      Serial Number    Power
-------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On   
8 C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026

Timestamp                      2026-08-25T08:44:36.2860633Z
Server                         CZ22420JCM

   image-build-automation                                                                           
0  09:44:36             Test-PreBuildValidation -ServerIdentifier CZ22420JCM
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026-08-25T08-51-14Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System.Collections.Hashtable], [iso_url_check_s…     
Timestamp                      2026-08-25T08:51:14.8911559Z
Server                         CZ22420JCM
 
   image-build-automation  Test-PreBuildValidation -ServerIdentifier CZ22420JCM    0  09:51:15     
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026-08-25T08-51-27Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System.Collections.Hashtable], [iso_url_check_skipped, System.Collections.Hashtable], [ilo_credenti…
Timestamp                      2026-08-25T08:51:27.6427619Z
Server                         CZ22420JCM

   image-build-automation 
                             Test-PreBuildValidation -ServerIdentifier CZ22420JCM  image-build-automation  Test-PreBuildValidation -SWARNING: Already connected to OneView appliance 'va-oneting session (reconnecting would drop the live session)ryRun'.
> C:\Users\adm_98253\products\repos\image-build-automatio
> C:\Users\adm_98253\products\repos\image-build-automatio5T08-42-54Z.json
> 
> Name                           Value
> ----                           -----
> Success                        True
> Checks                         {[oneview_target, System
> Timestamp                      2026-08-25T08:42:54.7043
> Server                         omg-qlikview-03ilo
> ^C 
   image-build-automation  Test-PreBuildValidation -ServerIdentifier CZ22420JCM -SkipDpMp -SkipIsoUrl
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit 
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026-08-25T08-53-00Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System.Collections.Hashtable], [iso_url_check_skipp… 
Timestamp                      2026-08-25T08:53:00.1587655Z
Server                         CZ22420JCM

   image-build-automation  Test-PostBuildValidation                                    0  09:53:00 
cmdlet Test-PostBuildValidation at command pipeline position 1 
Supply values for the following parameters:
Hostname: va-oneviewt-01 
PS> 
   image-build-automation  Get-OneViewServerTarget -ServerIdentifier alp-qlikview-03ilo -IdentifierType Auto

Name                           Value
----                           -----
Success                        False
Error                          OneView query failed: Response status code does not indicate success:… 
Server                         alp-qlikview-03ilo
 
   image-build-automation  Get-OneViewServerTarget -ServerIdentifier alp-qlikview-03ilo -IdentifierType OneViewName

============================================== 
  OneView Server Target
==============================================

  Server:       alp-qlikview-03ilo
  Serial:       CZ22420JCM 
  Model:        ProLiant DL360 Gen10 Plus
  Power:        On
  Health:       OK
  iLO IP:       
  Enclosure:     / 0
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  OneViewName

==============================================

2026-08-25 08:57:08 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=alp-qlikview-03ilo (ResolvedBy=OneViewName)

Name                           Value
----                           -----
Success                        True
ResolvedBy                     OneViewName 
Details                        {[oneview_uri, /rest/server-hardware/39383250-3834-5A43-3232-3432304A… 
Server                         alp-qlikview-03ilo

   image-build-automation  Get-OneViewServerTarget -ServerIdentifier CZ22420JCN -OneViewHost va-oneview-01 -IdentifierType Serial                                                                         
WARNING: Already connected to OneView appliance 'va-oneviewt-01'. Cannot reconnect to 'va-oneview-01' 
- reusing the existing session (reconnecting would drop the live session). Run Disconnect-OneView first if you need to switch to 'va-oneview-01'.

============================================== 
  OneView Server Target
============================================== 

  Server:       omg-qlikview-03ilo
  Serial:       CZ22420JCN
  Model:        ProLiant DL360 Gen10 Plus
  Power:        On
  Health:       OK
  iLO IP:       
  Enclosure:     / 0 
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  Serial

==============================================

2026-08-25 08:57:34 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCN 
(ResolvedBy=Serial)

Name                           Value
----                           -----
Success                        True 
ResolvedBy                     Serial
Details                        {[oneview_uri, /rest/server-hardware/39383250-3834-5A43-3232-3432304A… 
Server                         CZ22420JCN

   image-build-automation  Test-PreBuildValidation -ServerIdentifier CZ22420JCM
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit 
C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\prebuild_CZ22420JCM_2026-08-25T09-54-03Z.json

Name                           Value
----                           -----
Success                        True
Checks                         {[oneview_target, System.Collections.Hashtable], [iso_url_check_skipp… 
Timestamp                      2026-08-25T09:54:03.1053868Z
Server                         CZ22420JCM

 Test-BuildParams -BaseIsoPvers for 
Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows I
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/WIN2019Auto.iso
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\FC-14.4.624.0-1
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/FC-14.4.624.0-1
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\MR216i-a Win19Drivrs
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/MR216i-a Win19Drivrs

Name                           Value
----                           -----
Success                        False
BaseIsoPath                    Y:\WIN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1       … 
ResolvedPath                   Y:\WIN2019Auto.iso
FirmwareResults                {System.Collections.Specalized.… 
Errors                         {Firmware location not fMR216i-… 

   image-build-automation  Test-BuildParams -BaseIsoPers for W
indows ISO\FC-14.4.624.0-1', 'Y:\Drivers for Windows IS
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\IN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/IN2019Auto.iso
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\FC-14.4.624.0-1
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/FC-14.4.624.0-1
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\MR216i-a Win19Drivrs
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/MR216i-a Win19Drivrs

Name                           Value
----                           -----
Success                        False
BaseIsoPath                    Y:\IN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1       … 
ResolvedPath                   Y:\IN2019Auto.iso
FirmwareResults                {System.Collections.Specalized.… 
Errors                         {Base ISO not found or n not fo… 

   image-build-automation 1:57:31 
 *  History restored 
Identity added: C:\Users\adm_98253\.ssh\id_ed25519 (Kev
   image-build-automation  Test-ServerConnectivity  -2026-08-24 10:22:23 - Connectivity - INFO - DNS resolut2026-08-24 10:22:23 - Connectivity - INFO - TCP probe f
2026-08-24 10:22:23 - Connectivity - INFO - Connectivitlse (DNS=True, TCP=True, Auth=False)

============================================== 
  OneView Connectivity Test
============================================== 
 
  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-24T10:22:23.3275626Z 

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 15ms) 

  --- Phase 2: Auth Connect ---      
    Module:    Not loaded
    Connected: No
    Error:     Skipped - credentials not supplied 

==============================================    

   image-build-automation  Test-ServerConnectivity
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       
  Environment:Prod
  Timestamp:  2026-08-24T10:22:33.3367835Z     

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED 
    Error:     No active OneView connection. Connect fir name or serial), or supply -OneViewHost to test a spe

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no active connection

==============================================

   image-build-automation  Test-ServerList 
============================================== 
  Server List Validation
============================================== 
 
  Status:   VALID
  File:     configs\server_list.txt
  Servers:  5

  --- Servers ---
    - server1.example.com
    - server2.example.com
    - server3.example.com
    - proliant-server-01
    - proliant-server-02

==============================================

   image-build-automation  Test-BuildParams -BaseIsoP
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/WIN2019Auto.iso
 
Name                           Value
----                           -----
Success                        True
BaseIsoPath                    Y:\WIN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1
ResolvedPath                   Y:\WIN2019Auto.iso
FirmwareResults                {}
Errors                         {}

   image-build-automation    image-build-automation  Connect-OneView -OneViewHo2026-08-24 10:23:36 - Connect-OneView - INFO - Connect-n=False PassThru=False Json=False
Enter OneView username for 'va-oneviewt-01':  
   image-build-automation  Connect-OneView -OneViewHo2026-08-24 10:54:03 - Connect-OneView - INFO - Connect-n=False PassThru=False Json=False
Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ********
2026-08-24 10:54:21 - Connectivity - INFO - DNS resolut2026-08-24 10:54:21 - Connectivity - INFO - TCP probe f
This management appliance is a company owned asset and nel. Unauthorized use or abuse of this system may lead nd/or criminal penalties.

2026-08-24 10:55:29 - Connectivity - INFO - Connectivitue (DNS=True, TCP=True, Auth=True)
2026-08-24 10:55:29 - Connect-OneView - INFO - Connect-o OneView appliance 'va-oneviewt-01'.'

==============================================
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-24T10:55:29.4975157Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved 
    IP:        10.239.124.79
    TCP:       Open (port 443, 10ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000  v10.0.4265.2221    Appliance OneView version: 8200
    Connected: Yes (session active)

==============================================

   image-build-automation  Connect-OneView -OneViewHo2026-08-24 11:05:44 - Connect-OneView - INFO - Connect-n=False PassThru=False Json=False
2026-08-24 11:05:44 - Connectivity - INFO - DNS resolut2026-08-24 11:05:44 - Connectivity - INFO - TCP probe f
2026-08-24 11:05:49 - Connectivity - INFO - Connectivitue (DNS=True, TCP=True, Auth=True)
2026-08-24 11:05:49 - Connect-OneView - INFO - Connect-nected to OneView appliance 'va-oneviewt-01'.'
2026-08-24 11:05:49 - Connect-OneView - INFO - Connect-nected to OneView appliance 'va-oneviewt-01'.'

============================================== 
  OneView Connectivity Test
==============================================
 
  Status:     AVAILABLE 
  Mode:       oneview
  Host:       va-oneviewt-01 
  Environment:Prod 
  Timestamp:  2026-08-24T11:05:49.4119021Z

  --- Phase 1: Network Ping --- 
    DNS:       Resolved 
    IP:        10.239.124.79
    TCP:       Open (port 443, 7ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000 (module used for
    Connected: Yes (session active)

==============================================
 
   image-build-automation  Get-OneViewConnectionStatu

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
 
   image-build-automation  Get-OneViewConnectionStatu

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

   image-build-automation  Get-OneViewServerList
============================================== 
  OneView Server List (16 servers)
============================================== 

Server Name                      Serial Number    Power
-------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On   
ALP-WISCLU-01ilo                 CZ3508PYS5       On   
OMG-WISCLU-01ilo                 CZJ5500337       On   
ALP-STARWAY-01ILO                CZJ831052R       On   
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On   
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On   
gamdmzhost-02-03ilo              CZ29350B5Z       On   
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On   
OMG-CONSTC2-02ilo                CZ2D3701LY       On   
ALP-CONSTC1-01ilo                CZ2D3701LT       On   
ALP-CONSTC2-01ilo                CZ2D3701LV       On   
OMG-CONSTC1-02ilo                CZ2D3701LZ       On   
alp-qlikview-03ilo               CZ22420JCM       On   
alp-qliksen-02ilo                CZ22420JCZ       On   
omg-qlikview-03ilo               CZ22420JCN       On   
omg-qliksen-02ilo                CZ22420JD0       On   
 
==============================================

   image-build-automation  Get-OneViewServerList -One
 
==============================================
  OneView Server List (16 servers)
==============================================

Server Name                      Serial Number    Power
-------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On   
ALP-WISCLU-01ilo                 CZ3508PYS5       On   
OMG-WISCLU-01ilo                 CZJ5500337       On   
ALP-STARWAY-01ILO                CZJ831052R       On   
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On   
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On   
gamdmzhost-02-03ilo              CZ29350B5Z       On   
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On   
OMG-CONSTC2-02ilo                CZ2D3701LY       On   
ALP-CONSTC1-01ilo                CZ2D3701LT       On   
ALP-CONSTC2-01ilo                CZ2D3701LV       On   
OMG-CONSTC1-02ilo                CZ2D3701LZ       On   
alp-qlikview-03ilo               CZ22420JCM       On   
alp-qliksen-02ilo                CZ22420JCZ       On   
omg-qlikview-03ilo               CZ22420JCN       On   
omg-qliksen-02ilo                CZ22420JD0       On   

==============================================

   image-build-automation  Get-OneViewServerList -One 
No servers matched the request. 

   image-build-automation  Get-OneViewServerList -Oneal'
WARNING: Already connected to OneView appliance 'va-one' - reusing the existing session (reconnecting would dr
if you need to switch to 'oneview.example.com'.

============================================== 
  OneView Server List (1 servers)
============================================== 

Server Name                      Serial Number    Power
-------------------------------------------------------
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On   
 
============================================== 
 
   image-build-automation  Get-OneViewServerList -OneWARNING: Already connected to OneView appliance 'va-one' - reusing the existing session (reconnecting would dr
if you need to switch to 'oneview.example.com'.

No servers matched the request. 
 
   image-build-automation  Get-OneViewServerList  -Fi 
No servers matched the request. 

   image-build-automation  Get-OneViewServerList  -Fi
============================================== 
  OneView Server List (6 servers)
==============================================

Server Name                      Serial Number    Power
-------------------------------------------------------
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On   
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On   
gamdmzhost-02-03ilo              CZ29350B5Z       On   
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On   
alp-qlikview-03ilo               CZ22420JCM       On   
omg-qlikview-03ilo               CZ22420JCN       On   

============================================== 

   image-build-automation  Get-OneViewServerList  -Fi
No servers matched the request. 

   image-build-automation  Get-OneViewServerList  -Fi
No servers matched the request. 

   image-build-automation  Get-OneViewServerList  -Fi
============================================== 
  OneView Server List (2 servers) 
============================================== 

Server Name         Serial Number    Power     Health  
-------------------------------------------------------
alp-qlikview-03ilo  CZ22420JCM       On        OK
omg-qlikview-03ilo  CZ22420JCN       On        OK

==============================================

   image-build-automation  Test-ServerList
============================================== 
  Server List Validation
============================================== 
 
  Status:   VALID
  File:     configs\server_list.txt 
  Servers:  5 

  --- Servers ---
    - server1.example.com 
    - server2.example.com
    - server3.example.com
    - proliant-server-01 
    - proliant-server-02

==============================================

   image-build-automation  Test-BuildParams -BaseIsoP  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\WIN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/WIN2019Auto.iso

Name                           Value
----                           -----
Success                        True
BaseIsoPath                    Y:\WIN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1
ResolvedPath                   Y:\WIN2019Auto.iso
FirmwareResults                {}
Errors                         {}

   image-build-automation  Test-BuildParams -BaseIsoP  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\WIrN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/WIrN2019Auto.iso

Name                           Value 
----                           -----
Success                        False
BaseIsoPath                    Y:\WIrN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1
ResolvedPath                   Y:\WIrN2019Auto.iso
FirmwareResults                {}
Errors                         {Base ISO not found or n

   image-build-automation  Test-BuildParams -BaseIsoPers for Windows ISO\FC-14.4.624.0-1', 'Y:\Drivers for W
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\IN2019Auto.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/IN2019Auto.iso
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\FC-14.4.624.0-1
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/FC-14.4.624.0-1
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\ro
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISA
\Drivers for Windows ISO\MR216i-a Win19Drivrs
  [OK] Mapped drive converted to CIFS URL: cifs://Hnasc
/Drivers for Windows ISO/MR216i-a Win19Drivrs

Name                           Value 
----                           -----
Success                        False
BaseIsoPath                    Y:\IN2019Auto.iso
IsoUrl                         cifs://Hnascifsprd6/roi1
ResolvedPath                   Y:\IN2019Auto.iso 
FirmwareResults                {System.Collections.Spec
Errors                         {Base ISO not found or n

   image-build-automation  Get-OneViewServerTarget -S01 -IdentifierType Serial
WARNING: Already connected to OneView appliance 'va-oneusing the existing session (reconnecting would drop the need to switch to 'va-oneview-01'.

============================================== 
  OneView Server Target
============================================== 

  Server:       omg-qlikview-03ilo
  Serial:       CZ22420JCN
  Model:        ProLiant DL360 Gen10 Plus
  Power:        On
  Health:       OK
  iLO IP:       
  Enclosure:     / 0 
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  Serial 
 
==============================================

2026-08-24 11:36:31 - Get-OneViewServerTarget - INFO - olvedBy=Serial)

Name                           Value
----                           -----
Success                        True
ResolvedBy                     Serial
Details                        {[oneview_uri, /rest/ser
Server                         CZ22420JCN

   image-build-automation  Get-OneViewServerTarget -S-oneview-01
WARNING: Already connected to OneView appliance 'va-oneusing the existing session (reconnecting would drop the need to switch to 'va-oneview-01'.

Name                           Value 
----                           -----
Success                        False
Error                          OneView query failed: Re
Server                         omg-qlikview-03ilo

   image-build-automation  Get-OneViewServerTarget -S01 -IdentifierType Serial
WARNING: Already connected to OneView appliance 'va-oneusing the existing session (reconnecting would drop the need to switch to 'va-oneview-01'.
 
============================================== 
  OneView Server Target
==============================================

  Server:       omg-qlikview-03ilo
  Serial:       CZ22420JCN
  Model:        ProLiant DL360 Gen10 Plus 
  Power:        On
  Health:       OK
  iLO IP:       
  Enclosure:     / 0
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  Serial

==============================================

2026-08-24 14:10:29 - Get-OneViewServerTarget - INFO - olvedBy=Serial)

Name                           Value
----                           -----
Success                        True 
ResolvedBy                     Serial
Details                        {[oneview_uri, /rest/ser
Server                         CZ22420JCN

   image-build-automation  Get-OneViewServerTarget -S01
WARNING: Already connected to OneView appliance 'va-one existing session (reconnecting would drop the live ses 'va-oneview-01'.

==============================================
  OneView Server Target
==============================================

  Server:       omg-qlikview-03ilo
  Serial:       CZ22420JCN
  Model:        ProLiant DL360 Gen10 Plus
  Power:        On
  Health:       OK
  iLO IP:
  Enclosure:     / 0
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  Serial

==============================================

2026-08-24 14:10:42 - Get-OneViewServerTarget - INFO - erial)

Name                           Value
----                           -----
Success                        True
ResolvedBy                     Serial
Details                        {[oneview_uri, /rest/ser
Server                         CZ22420JCN

   image-build-automation  Get-OneViewServerTarget -S01
WARNING: Already connected to OneView appliance 'va-one existing session (reconnecting would drop the live ses 'va-oneview-01'.
 
Name                           Value
----                           -----
Success                        False
Error                          OneView query failed: Re
Server                         omg-qlikview-03ilo 

   image-build-automation  Get-OneViewServerTarget -S

Name                           Value
----                           -----
Success                        False
Error                          OneView query failed: Re
Server                         omg-qlikview-03ilo

   image-build-automation  Get-OneViewServerList  -Fi
 
No servers matched the request. 

   image-build-automation  Get-OneViewServerList
==============================================
  OneView Server List (16 servers)
==============================================
 
Server Name                      Serial Number    Power
-------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On   
ALP-WISCLU-01ilo                 CZ3508PYS5       On   
OMG-WISCLU-01ilo                 CZJ5500337       On   
ALP-STARWAY-01ILO                CZJ831052R       On   
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On   
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On   
gamdmzhost-02-03ilo              CZ29350B5Z       On   
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On   
OMG-CONSTC2-02ilo                CZ2D3701LY       On   
ALP-CONSTC1-01ilo                CZ2D3701LT       On   
ALP-CONSTC2-01ilo                CZ2D3701LV       On   
OMG-CONSTC1-02ilo                CZ2D3701LZ       On   
alp-qlikview-03ilo               CZ22420JCM       On   
alp-qliksen-02ilo                CZ22420JCZ       On   
omg-qlikview-03ilo               CZ22420JCN       On   
omg-qliksen-02ilo                CZ22420JD0       On   

==============================================

   image-build-automation  Get-OneViewServerTarget -S
Name                           Value
----                           -----
Success                        False
Error                          OneView query failed: Re
Server                         alp-qlikview-03il
 
   image-build-automation  Get-OneViewServerTarget -S
============================================== 
  OneView Server Target
============================================== 

  Server:       alp-qlikview-03ilo
  Serial:       CZ22420JCM
  Model:        ProLiant DL360 Gen10 Plus
  Power:        On
  Health:       OK
  iLO IP:       
  Enclosure:     / 0
  ROM Version:  U46 v2.42 (06/13/2025)
  Resolved By:  Serial 

==============================================

2026-08-24 14:13:09 - Get-OneViewServerTarget - INFO - erial)

Name                           Value
----                           ----- 
Success                        True
ResolvedBy                     Serial
Details                        {[oneview_uri, /rest/ser
Server                         CZ22420JCM

   image-build-automation  Get-OneViewServerTarget -S
Name                           Value
----                           -----
Success                        False
Error                          OneView query failed: Re
Server                         alp-qlikview-03ilo
 
   image-build-automation  Get-OneViewServerTarget -Sme 
```

<a id=wednesday-26th-august"></a>

<a id="wednesday-26th-august"></a>

## Wednesday 26th August

```text
  OneView Server List (16 servers)
  Appliance: va-oneviewt-01
==============================================

| Server Name                     | Serial          | MaintMode | Health     | iLO IP          | 
|---------------------------------|-----------------|-----------|------------|-----------------| 
| OMG-STARWAY-01ILO.AD.AIB.PRI    | CZJ831052N      | No        | OK         | 10.239.230.72   | 
| ALP-WISCLU-01ilo                | CZ3508PYS5      | No        | OK         | 10.30.13.115    |
| OMG-WISCLU-01ilo                | CZJ5500337      | No        | OK         | 10.30.52.142    |
| ALP-STARWAY-01ILO               | CZJ831052R      | No        | OK         | 10.239.228.76   |
| gam-isechost-02-03ilo.ad.ad.pri | CZ29350B60      | No        | OK         | 10.30.14.83     |
| gamdmzhost-01-03ilo.AD.AIB.PRI  | CZ29350B5Y      | No        | OK         | 10.30.14.80     | 
| gamdmzhost-02-03ilo             | CZ29350B5Z      | No        | OK         | 10.30.14.81     |
| gamisechost-01-03ilo.AD.AIB.PRI | CZ29350B61      | No        | Critical   | 10.30.14.82     |
| OMG-CONSTC2-02ilo               | CZ2D3701LY      | No        | Warning    | 10.239.231.29   |
| ALP-CONSTC1-01ilo               | CZ2D3701LT      | No        | Warning    | 10.239.229.64   |
| ALP-CONSTC2-01ilo               | CZ2D3701LV      | No        | Warning    | 10.239.229.65   |
| OMG-CONSTC1-02ilo               | CZ2D3701LZ      | No        | OK         | 10.239.231.28   |
| alp-qlikview-03ilo              | CZ22420JCM      | No        | OK         | 10.30.14.15     |
| alp-qliksen-02ilo               | CZ22420JCZ      | No        | OK         | 10.30.14.17     |
| omg-qlikview-03ilo              | CZ22420JCN      | No        | OK         | 10.30.54.22     |
| omg-qliksen-02ilo               | CZ22420JD0      | No        | OK         | 10.30.54.21     |

KEY
  MaintMode : HPE OneView maintenance mode.  Yes = server is IN maintenance mode;  No = NOT in maintenance mode.

============================================== 

   image-build-automation  Get-OneViewServerList -Detail                                                                                                                                                                                 0  18:03:36 
==============================================
  OneView Server List (16 servers)
  Appliance: va-oneviewt-01
==============================================

| Server Name                     | Serial          | MaintMode | State            | Health     | Power    | iLO IP          | ROM          | State Reason  | Model      |
|---------------------------------|-----------------|-----------|------------------|------------|----------|-----------------|--------------|---------------|------------|
| OMG-STARWAY-01ILO.AD.AIB.PRI    | CZJ831052N      | No        | Monitored        | OK         | On       | 10.239.230.72   | U32 v3.50 (04/17/2025) | NotApplicable |            | 
| ALP-WISCLU-01ilo                | CZ3508PYS5      | No        | Monitored        | OK         | On       | 10.30.13.115    | P89 v2.92 (11/23/2021) | NotApplicable |            | 
| OMG-WISCLU-01ilo                | CZJ5500337      | No        | Monitored        | OK         | On       | 10.30.52.142    | P89 v2.92 (11/23/2021) | NotApplicable |            | 
| ALP-STARWAY-01ILO               | CZJ831052R      | No        | Monitored        | OK         | On       | 10.239.228.76   | U32 v3.50 (04/17/2025) | NotApplicable |            |
| gam-isechost-02-03ilo.ad.ad.pri | CZ29350B60      | No        | NoProfileApplied | OK         | On       | 10.30.14.83     | U30 v3.42 (02/21/2025) | NotApplicable |            |
| gamdmzhost-01-03ilo.AD.AIB.PRI  | CZ29350B5Y      | No        | NoProfileApplied | OK         | On       | 10.30.14.80     | U30 v3.42 (02/21/2025) | NotApplicable |            |
| gamdmzhost-02-03ilo             | CZ29350B5Z      | No        | NoProfileApplied | OK         | On       | 10.30.14.81     | U30 v3.42 (02/21/2025) | NotApplicable |            |
| gamisechost-01-03ilo.AD.AIB.PRI | CZ29350B61      | No        | NoProfileApplied | Critical   | On       | 10.30.14.82     | U30 v3.42 (02/21/2025) | NotApplicable |            | 
| OMG-CONSTC2-02ilo               | CZ2D3701LY      | No        | ProfileApplied   | Warning    | On       | 10.239.231.29   | U68 v1.52 (10/03/2025) | NotApplicable |            |
| ALP-CONSTC1-01ilo               | CZ2D3701LT      | No        | ProfileApplied   | Warning    | On       | 10.239.229.64   | U68 v1.52 (10/03/2025) | NotApplicable |            |
| ALP-CONSTC2-01ilo               | CZ2D3701LV      | No        | ProfileApplied   | Warning    | On       | 10.239.229.65   | U68 v1.52 (10/03/2025) | NotApplicable |            |
| OMG-CONSTC1-02ilo               | CZ2D3701LZ      | No        | ProfileApplied   | OK         | On       | 10.239.231.28   | U68 v1.52 (10/03/2025) | NotApplicable |            |
| alp-qlikview-03ilo              | CZ22420JCM      | No        | NoProfileApplied | OK         | On       | 10.30.14.15     | U46 v2.42 (06/13/2025) | NotApplicable |            |
| alp-qliksen-02ilo               | CZ22420JCZ      | No        | NoProfileApplied | OK         | On       | 10.30.14.17     | U46 v2.24 (10/04/2024) | NotApplicable |            |
| omg-qlikview-03ilo              | CZ22420JCN      | No        | NoProfileApplied | OK         | On       | 10.30.54.22     | U46 v2.42 (06/13/2025) | NotApplicable |            |
| omg-qliksen-02ilo               | CZ22420JD0      | No        | NoProfileApplied | OK         | On       | 10.30.54.21     | U46 v2.24 (10/04/2024) | NotApplicable |            | 

KEY
  MaintMode : HPE OneView maintenance mode.  Yes = server is IN maintenance mode;  No = NOT in maintenance mode.
  State     : server lifecycle state from OneView:
               Monitored        = normal / being monitored (not in maintenance)
               MaintenanceMode  = same as MaintMode=Yes (server placed in maintenance)
               NoProfileApplied = no server profile assigned
               ProfileApplying  = a server profile is being applied
               ProfileApplied   = a server profile has been applied
               ConfigureHardware = hardware configuration in progress
               ProfileError     = profile apply failed (NOT maintenance)
               Deleting         = server being removed

==============================================
```
