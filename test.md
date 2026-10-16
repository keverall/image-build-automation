 Configure-PhysicalBuild -ServerIdentifier 'CZ22420JCM' -OneViewHost 'va-oneviewt-01' -ExpectedHostname 'alp-qlikview-03ilo' -ExternalIsoPath 'Y:\WindowsServer2025.iso' -GuardRail  'qlikview-03ilo'  -InMaintenanceWindow
 
========================================        
  Physical Build Configuration Review
========================================        

[1/4] Resolving server identity from OneView... 
2026-10-16 10:24:23 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

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
2026-10-16 10:24:49 - GuardRail - INFO - Guard rail matched and -SkipConfirmation supplied; proceeding with build plan review for 'alp-qlikview-03ilo'.
 
[2/4] Resolving ISO...
  [INFO] Detected mapped drive: Y: -> \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE 
  [INFO] Resolved UNC path: \\Hnascifsprd6\roi1\BKCWISAPPS\KevinE\WindowsServer2025.iso 
  [OK] Mapped drive converted to CIFS URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  [OK] Resolved to: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso

[3/4] Running pre-build validation...
2026-10-16 10:24:50 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

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
  [PASS] oneview_target : Server: CZ22420JCM, Details: enclosure_name: , health_status: OK, enclosure_bay: 0, serial_number: CZ22420JCM, ilo_ip: 10.30.14.15, rom_version: U46 v2.42 (06/13/2025), 
name: alp-qlikview-03ilo, model: ProLiant DL360 Gen10 Plus, maintenance_mode: Yes, power_state: On, oneview_uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D, Success: True
  [PASS] iso_url_format : CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  [SKIP] ilo_credentials : deferred to Start-PhysicalServerBuild; direct iLO credentials are validated immediately before mount/reboot
  [PASS] audit_recorded : logged to C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\2026-10-16T10-24-50Z_prebuild_CZ22420JCM.json

  Maintenance window: ACKNOWLEDGED

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
2026-10-16 10:24:56 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

==============================================
  OneView Server Target
==============================================

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025)

  Resolved By:  Serial

============================================== 

[OK] pre_build_validation 
2026-10-16 10:24:56 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

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
2026-10-16 10:24:56 - GuardRail - INFO - Guard rail matched and -SkipConfirmation supplied; proceeding with physical server build for 'alp-qlikview-03ilo'.

============================================== 
  iLO Redfish - Status
==============================================

  iLO IP:    10.30.14.15
  Success:   True

  --- System ---
    Manufacturer:  HPE
    Model:         ProLiant DL360 Gen10 Plus 

  --- Virtual Media ---
    Device 1:  Inserted=No
    Device 2:  Inserted=No

==============================================

[OK] ilo_maintenance_guard 
[FAIL] ilo_mount_and_boot 
Server: CZ22420JCM
Start_Time: 2026-10-16T10:24:55.7060215Z
Steps:
  Resolve_Iso:
    Iso URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
    Success: True
  Pre_Build_Validation:
    Server: CZ22420JCM
    Checks: 
      Oneview_Target:
        Status: PASS
        Details: Server: CZ22420JCM, Details: enclosure_name: , health_status: OK, enclosure_bay: 0, serial_number: CZ22420JCM, ilo_ip: 10.30.14.15, rom_version: U46 v2.42 (06/13/2025), name: alp-qlikview-03ilo, model: ProLiant DL360 Gen10 Plus, maintenance_mode: Yes, power_state: On, oneview_uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D, Success: True
      Iso_Url_Format: 
        Status: PASS 
        Details: CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
      Ilo_Credentials:
        Status: SKIP
        Details: deferred to Start-PhysicalServerBuild; direct iLO credentials are validated immediately before mount/reboot
      Audit_Recorded:
        Status: PASS 
        Details: logged to C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\2026-10-16T10-24-56Z_prebuild_CZ22420JCM.json
    Timestamp: 2026-10-16T10:24:56.2466903Z
    Success: True
  Oneview_Target:
    Server: CZ22420JCM
    Success: True
    Resolved By: Serial
    Details:
      Enclosure_Name: (none)
      Health_Status: OK 
      Enclosure_Bay: 0
      Serial_Number: CZ22420JCM
      Ilo_Ip: 10.30.14.15
      Rom_Version: U46 v2.42 (06/13/2025)
      Name: alp-qlikview-03ilo
      Model: ProLiant DL360 Gen10 Plus
      Maintenance_Mode: Yes
      Power_State: On
      Oneview_Uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D
  Oneview_Maintenance_Enable:
    Success: True
    Skipped: True 
    Reason: Server already in maintenance mode
  Ilo_Maintenance_Guard:
    Acknowledged: True
    Success: True
    Power State: (none)
  Ilo_Mount_And_Boot:
    Ilo IP: 10.30.14.15
    Action: MountAndBoot
    Success: False
    Error: Action 'MountAndBoot' is destructive and requires -Force (or -DryRun). Use -Force to confirm intent.
Success: False 