Already up to date.
   image-build-automation  main  git log -1 --oneline                                                                                                                                             0  971ms  11:20:54 38045b3e (HEAD -> main, origin/main, origin/HEAD) Remove unnecessary text from test.md and ensure linting passes
   image-build-automation  main  make setup                                                                                                                                                              0  11:21:03 [setup] Setting up PowerShell environment...

╔══════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation - PowerShell Setup     ║
╚══════════════════════════════════════════════════════╝

[OK] PowerShell 7.6.6
[OK] Added offline module path for this session: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules
[INFO] Verifying local PowerShell modules (offline; files are preserved)…
[OK] Pester 6.0.1 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\Pester\6.0.1\Pester.psd1
[OK] PSScriptAnalyzer 1.21.0 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\PSScriptAnalyzer\1.21.0\PSScriptAnalyzer.psd1
[OK] PlatyPS 0.14.0 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\platyPS\0.14.0\platyPS.psd1
[OK] HPEOneView.1000 10.0.4265.2221 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1
Exception: C:\Users\adm_98253\products\repos\image-build-automation\scripts\setup-runner.ps1:277:9 
Line | 
 277 |          throw "Local import failed for $Name $Version from '$Manifest …
     |          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Local import failed for HPRESTCmdlets 1.2.0.0 from 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1'. Files were preserved. Import error:       
     | Exception: C:\Users\adm_98253\products\repos\image-build-automation\scripts\Import-OfflineHpeModules.ps1:56:13 Line |   56 | 
     | throw "Unable to import local $ModuleName from '$Manifest …      | 
     | ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~      | Unable to import local HPRESTCmdlets from
     | 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1'. Files were preserved. After a previous failed HPE
     |      | import, start a fresh 'pwsh -NoProfile' shell rather than forcing a reload. Original error: Cannot add type. The
     | type name 'AsyncPipeline' already exists.
make: *** [Makefile:57: setup] Error 1 
   image-build-automation  main                                                                                  

No — and it should **not** be imported. Here's the definitive breakdown from the manifest itself.

<a id="what-hprestcmdletspsd1-actually-loads"></a>

## What `HPRESTCmdlets.psd1` actually loads

The manifest declares only three relevant keys (no `NestedModules`, no `RequiredAssemblies`, no `FormatsToProcess`, no `TypesToProcess`):

| Manifest key | File | Role |
|---|---|---|
| `RootModule = 'HPRESTCmdlets.psm1'` | HPRESTCmdlets.psm1 | The cmdlets |
| `ScriptsToProcess = @('ShowLicense.ps1')` | ShowLicense.ps1 | Runs **before** RootModule — HPE license acceptance + the `AsyncPipeline` type |
| `FileList = @(...,'HPRESTExamples.ps1',...)` | — | **Packaging metadata only** |

**PowerShell never executes `FileList` entries.** `HPRESTExamples.ps1` is only listed there (and mentioned in the `Description`) as shipped documentation. Its own content confirms it: 2,510 lines of comment blocks listing cmdlets, plus sample scripts that call `Connect-HPREST` against live devices. It is never loaded, and dot-sourcing it would execute example code that tries to connect to hardware.

<a id="import-the-psd1-never-the-psm1"></a>

## Import the `.psd1`, never the `.psm1`

```powershell
Import-Module '.\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1' -ErrorAction Stop
```

Importing the `.psm1` directly would:
- **Bypass HPE's license acceptance** (`ShowLicense.ps1`) — the license file states the module must not be used until accepted;
- Export *every* function in the file, including internal helpers like `Get-Message` and `Create-ThreadPool`, risking name collisions;
- Lose version/GUID identity that `make setup` and `Get-CommandHelp` rely on.

`Import-Module HPRESTCmdlets` by name works too once `scripts/modules` is on `$env:PSModulePath` (which `make setup` now does).

<a id="verify-all-four-layers-are-resident-and-usable"></a>

## Verify all four layers are resident and usable

```powershell
Get-Module HPRESTCmdlets, HPEOneView.1000 | Format-Table Name,Version,Path

Get-Command Get-OVServer, Get-OVIloSso `            # auth source (from HPEOneView.1000)
  | Format-Table Name,Module,Version
Get-Command Connect-HPREST, Get-HPRESTDataRaw `      # confirms the psd1 loaded fully
  | Format-Table Name,Module,Version

$null -ne ('AsyncPipeline' -as [type])               # True = ShowLicense.ps1 actually ran
```

If `AsyncPipeline` is `False` while `HPRESTCmdlets` is loaded, the module was imported by `.psm1` rather than `.psd1` — that's the failure mode to avoid.

One accurate detail for your auth work: `Configure-PhysicalServer`'s SSO path needs **`Get-OVServer` + `Get-OVIloSso`** (`HPEOneView.1000`) and passes the token to `[IloRedfishSession]` which sends `X-Auth-Token`. `HPRESTCmdlets` is the vendor-declared iLO REST dependency that `make setup` requires. Run `Invoke-IloRedfish -Action Status -IloIp <ip> -OneViewHost <host> -OneViewServerName <name>` and read its `Auth_Diagnostics` to see `Token_Source`, `Token_Length`, and `Last_Error`.

I confirmed the guard is in HEAD and your working tree is clean — so your server just needs git pull to get it. The run you pasted was against 38045b3e, which predates that fix.

What to do on eiswmgt-19
git pull
make setup

# make setup verifies in a child process; do this in YOUR shell:

<a id="top"></a>

## Table of Contents

- [What `HPRESTCmdlets.psd1` actually loads](#what-hprestcmdletspsd1-actually-loads)
- [Import the `.psd1`, never the `.psm1`](#import-the-psd1-never-the-psm1)
- [Verify all four layers are resident and usable](#verify-all-four-layers-are-resident-and-usable)

Import-Module '.\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1' -ErrorAction Stop
Import-Module '.\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1' -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST | Format-Table Name,Module,Version
$null -ne ('AsyncPipeline' -as [type])    # must be True
If it breaks again, capture the exact error line — the three above are distinguishable by their first line alone, and that determines which fix applies.

127.2 t/s



 Configure-PhysicalBuild -ServerIdentifier 'CZ22420JCM' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'Y:\WindowsServer2025.iso' -GuardRail  'qlikview-03ilo'

======================================== 
  Physical Build Configuration Review
========================================        

[1/4] Resolving server identity from OneView... 
2026-10-16 08:40:17 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

============================================== 
  OneView Server Target
==============================================

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025)
 
  Resolved By:  Serial

==============================================

  [OK] Server resolved
iLO username for '10.30.14.15': cswinilo
iLO password for 'cswinilo': ***************************

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Serial number : CZ22420JCM
  Appliance     : va-oneviewt-01
2026-10-16 08:40:51 - GuardRail - INFO - Guard rail matched and -SkipConfirmation supplied; proceeding with build plan review for 'alp-qlikview-03ilo'.

[2/4] Resolving ISO...
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE 
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE\WindowsServer2025.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso 
  [OK] Resolved to: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso

[3/4] Running pre-build validation...
2026-10-16 08:41:12 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

============================================== 
  OneView Server Target
============================================== 

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025) 

  Resolved By:  Serial

==============================================

  [OK] All pre-build checks passed 

[4/4] Deployment Summary
══════════════════════════════════════════════════════════════

  ─ SERVER IDENTITY ─
  Target:          alp-qlikview-03ilo
  Identifier:      CZ22420JCM
  Serial:          CZ22420JCM
  Model:           ProLiant DL360 Gen10 Plus
  iLO IP:          10.30.14.15
  OneView URI:     /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D
  Rack/Position:   unknown
  Server Group:    unknown
  Maintenance Mode:Yes
  Power State:     On
  Health:          OK 

  ─ ISO DETAILS ─
  Source:          External ISO: Y:\WindowsServer2025.iso
  URL:             cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  Contents:        Windows Server boot media + ConfigMgr task sequence

  ─ DESTRUCTIVE ACTIONS (will be executed by Start-PhysicalBuild) ─
  1. Disk partitioning & formatting (ALL data will be erased)
  2. Windows OS installation from ISO
  3. Server reboot into installed OS
  4. Post-build validation (hostname, domain join, drivers)

  ╔══════════════════════════════════════════════════════════════════════╗
  ║  �🔇  ONEVIEW MAINTENANCE MODE (automatic)                            ║
  ╠══════════════════════════════════════════════════════════════════════╣
  ║  This server will be put into HPE OneView maintenance mode           ║
  ║  BEFORE the build starts. This stops unnecessary alerting            ║
  ║  and avoids on-call callouts during the deployment.                  ║ 
  ║                                                                      ║
  ║  Maintenance mode will be automatically removed when the             ║
  ║  build completes (or if it fails).                                   ║
  ║                                                                      ║
  ║  To skip this, use -NoMaintenanceMode.                               ║
  ╚══════════════════════════════════════════════════════════════════════╝

  ─ PRE-BUILD VALIDATION RESULTS ─
  [PASS] oneview_target : Server: CZ22420JCM, Details: enclosure_bay: 0, model: ProLiant DL360 Gen10 Plus, ilo_ip: 10.30.14.15, health_status: OK, maintenance_mode: Yes, serial_number: CZ22420JCM, rom_version: U46 v2.42 (06/13/2025), enclosure_name: , oneview_uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D, name: alp-qlikview-03ilo, power_state: On, Success: True
  [PASS] iso_url_format : CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  [SKIP] ilo_credentials : skipped (optional — supply -IloIp for a live iLO Redfish GET that verifies reachability and credentials before the destructive mount/reboot)
  [PASS] audit_recorded : logged to C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\2026-10-16T08-41-12Z_prebuild_CZ22420JCM.json

  Maintenance window: NOT acknowledged (-InMaintenanceWindow not set)
  This build will reboot a running server if it is On.

══════════════════════════════════════════════════════════════
 
  ╔════════════════════════════════════════════════════════╗
  ║  ⚠  DESTRUCTIVE ACTION WARNING                       ║ 
  ║  You are authorizing a destructive deploy to this     ║
  ║  server. It will be REFORMATTED / REPARTITIONED per    ║
  ║  the ISO, firmware REINSTALLED, and hostname/serial    ║
  ║  allocated as confirmed above. Re-check, then type     ║
  ║  APPROVE to proceed. Anything else cancels.            ║
  ╚════════════════════════════════════════════════════════╝

  Type APPROVE to authorize the ISO + firmware deploy to 'alp-qlikview-03ilo', or anything else to cancel: APPROVE 

  ✓ APPROVED — deploying ISO + firmware to 'alp-qlikview-03ilo' (via Start-PhysicalServerBuild).
 
========================================
  External ISO Deployment Mode 
========================================
ISO Source: Y:\WindowsServer2025.iso
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE\WindowsServer2025.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso 
ISO URL for iLO: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
========================================

  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE 
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE\WindowsServer2025.iso
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
[OK] resolve_iso
2026-10-16 08:41:19 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

============================================== 
  OneView Server Target
==============================================

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025)

  Resolved By:  Serial

==============================================

[OK] pre_build_validation 
2026-10-16 08:41:20 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 
 
==============================================
  OneView Server Target
==============================================

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025)

  Resolved By:  Serial

==============================================

[OK] oneview_target

  [OneView] Server 'alp-qlikview-03ilo' is already in maintenance mode — skipping enable.
[OK] oneview_maintenance_enable

========================================
  GUARD RAIL MATCH - DESTRUCTIVE ACTION
========================================
  Guard pattern : qlikview-03ilo
  Target server : alp-qlikview-03ilo
  Serial number : CZ22420JCM
  Appliance     : va-oneviewt-01 

  WARNING: this will OVERWRITE 'alp-qlikview-03ilo' with a Windows ISO image,
  partition layout, Windows setup, and firmware from the supplied
  archive. This is DESTRUCTIVE.
2026-10-16 08:41:20 - GuardRail - INFO - Guard rail matched and -SkipConfirmation supplied; proceeding with physical server build for 'alp-qlikview-03ilo'.
[FAIL] ilo_maintenance_guard 
Server: CZ22420JCM 
Start_Time: 2026-10-16T08:41:19.3020526Z 
Steps:
  Resolve_Iso:
    Success: True 
    Iso URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  Pre_Build_Validation:
    Server: CZ22420JCM
    Success: True
    Timestamp: 2026-10-16T08:41:19.9779425Z
    Checks: 
      Oneview_Target:
        Status: PASS
        Details: Server: CZ22420JCM, Details: enclosure_bay: 0, model: ProLiant DL360 Gen10 Plus, ilo_ip: 10.30.14.15, health_status: OK, maintenance_mode: Yes, serial_number: CZ22420JCM, rom_version: U46 v2.42 (06/13/2025), enclosure_name: , oneview_uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D, name: alp-qlikview-03ilo, power_state: On, Success: True
      Iso_Url_Format:
        Status: PASS
        Details: CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
      Ilo_Credentials: 
        Status: SKIP
        Details: skipped (optional — supply -IloIp for a live iLO Redfish GET that verifies reachability and credentials before the destructive mount/reboot)
      Audit_Recorded:
        Status: PASS
        Details: logged to C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\2026-10-16T08-41-19Z_prebuild_CZ22420JCM.json
  Oneview_Target:
    Server: CZ22420JCM
    Success: True 
    Resolved By: Serial
    Details:
      Enclosure_Bay: 0
      Model: ProLiant DL360 Gen10 Plus
      Ilo_Ip: 10.30.14.15
      Health_Status: OK
      Maintenance_Mode: Yes 
      Serial_Number: CZ22420JCM
      Rom_Version: U46 v2.42 (06/13/2025)
      Enclosure_Name: (none)
      Oneview_Uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D
      Name: alp-qlikview-03ilo 
      Power_State: On 
  Oneview_Maintenance_Enable:
    Reason: Server already in maintenance mode
    Success: True
    Skipped: True
  Ilo_Maintenance_Guard:
    Success: False
    Auth Diagnostics:
      Token_Source: redfish_session_login
      Last_Request_Uri: /redfish/v1/Managers/1/VirtualMedia/2 
      Use_Raw_Token: False
      Attempt_Modes:
        Length   
        -------- 
        32
        32
        32
        32
      Token_Length: 0
      Base_Url: https://10.30.14.15/redfish/v1
      Token_Present: False 
      Raw_Token_Present: False
      Skip_Certificate_Check: True
      Auth_Attempts: 4
      Last_Error: Invalid URI: The hostname could not be parsed.
      Raw_Token_Has_Session Key: False
      Raw_Token_Length: 0
      Auth_Mode: direct_ilo
    Error: iLO status check failed: Cannot convert the "System.Object[]" value of type "System.Object[]" to type "System.Collections.Hashtable".
Success: False
   image-build-automation  main                                                                                                                                                                                                  0  1m 5s 367ms  09:41:22 