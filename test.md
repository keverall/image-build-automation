 Type APPROVE to authorize the ISO + firmware deploy to 'alp-qlikview-03ilo', or anything else to cancel: APPROVE 

  ✓ APPROVED — deploying ISO + firmware to 'alp-qlikview-03ilo' (via Invoke-PhysicalServerBuild).

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
2026-10-14 14:27:21 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

==============================================
  OneView Server Target
==============================================

  Details:   name=alp-qlikview-03ilo, serial=CZ22420JCM, model=ProLiant DL360 Gen10 Plus, power=On, health=OK
             maint=Yes, ilo=10.30.14.15, enclosure=/0, rom=U46 v2.42 (06/13/2025)
 
  Resolved By:  Serial

============================================== 

[OK] pre_build_validation 
2026-10-14 14:27:21 - Get-OneViewServerTarget - INFO - Get-OneViewServerTarget resolved Id=CZ22420JCM (ResolvedBy=Serial) 

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
2026-10-14 14:27:21 - GuardRail - INFO - Guard rail matched and -SkipConfirmation supplied; proceeding with physical server build for 'alp-qlikview-03ilo'.
WARNING: Parameter 'SkipCertificateCheck' is obsolete.  
[FAIL] ilo_maintenance_guard 
Server: CZ22420JCM 
Start_Time: 2026-10-14T14:27:20.9063047Z 
Steps:
  Resolve_Iso:
    Success: True 
    Iso URL: cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
  Pre_Build_Validation:
    Timestamp: 2026-10-14T14:27:21.4148366Z
    Checks:
      Oneview_Target: 
        Details: Server: CZ22420JCM, Details: enclosure_name: , ilo_ip: 10.30.14.15, model: ProLiant DL360 Gen10 Plus, health_status: OK, enclosure_bay: 0, serial_number: CZ22420JCM, oneview_uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D, power_state: On, name: alp-qlikview-03ilo, maintenance_mode: Yes, rom_version: U46 v2.42 (06/13/2025), Success: True
        Status: PASS
      Iso_Url_Format:
        Details: CIFS/SMB share URL (verified by Resolve-ExternalIsoPath): cifs://Hnascifsprd6/roi1/BKCWISAPPS/KevinE/WindowsServer2025.iso
        Status: PASS
      Ilo_Credentials:
        Details: skipped (optional — supply -IloIp for a live iLO Redfish GET that verifies reachability and credentials before the destructive mount/reboot)
        Status: SKIP 
      Audit_Recorded:
        Details: logged to C:\Users\adm_98253\products\repos\image-build-automation\generated\logs\audit\2026-10-14T14-27-21Z_prebuild_CZ22420JCM.json
        Status: PASS
    Server: CZ22420JCM
    Success: True
  Oneview_Target:
    Details:
      Enclosure_Name: (none) 
      Ilo_Ip: 10.30.14.15
      Model: ProLiant DL360 Gen10 Plus
      Health_Status: OK
      Enclosure_Bay: 0
      Serial_Number: CZ22420JCM
      Oneview_Uri: /rest/server-hardware/39383250-3834-5A43-3232-3432304A434D 
      Power_State: On
      Name: alp-qlikview-03ilo
      Maintenance_Mode: Yes 
      Rom_Version: U46 v2.42 (06/13/2025)
    Resolved By: Serial
    Server: CZ22420JCM
    Success: True
  Oneview_Maintenance_Enable:
    Skipped: True 
    Reason: Server already in maintenance mode
    Success: True
  Ilo_Maintenance_Guard:
    Auth Diagnostics:
      Attempt_Modes:
        Length   
        -------- 
        32
        28
      Last_Request_Uri: https://10.30.14.15/rest/v1/Systems/1
      Auth_Attempts: 2 
      Raw_Token_Present: True
      Token_Length: 32
      Token_Source: X-Auth-Token
      Raw_Token_Has_Session Key: False
      Raw_Token_Length: 32
      Skip_Certificate_Check: True 
      Token_Present: True 
      Base_Url: https://10.30.14.15/redfish/v1
      Use_Raw_Token: False
      Auth_Mode: oneview_sso
      Last_Error: Response status code does not indicate success: 401 (Unauthorized).
    Error: iLO status check failed: iLO authentication failed (401 Unauthorized) using OneView SSO, and no configured OneView credential was available for the non-interactive direct-iLO fallback. Detail: iLO authentication/request failure at redfish_authenticated_get (https://10.30.14.15/redfish/v1/Systems/1): HTTP 401 Response status code does not indicate success: 401 (Unauthorized).
    Success: False
Success: False
   image-build-automation  main                                                           




                         **Fixed the setup script’s self-deletion bug.**

It previously treated any import failure as corruption, deleted the entire module directory—including the repository bundle—and then attempted PSGallery.

Setup now:
- Imports **explicit local `.psd1` manifests**, preferring the bundled copy.
- **Never deletes module directories or moves away their contents.**
- Makes **no PSGallery or GitHub download attempts**.
- Preserves files and reports the actual import error when loading fails.
- Registers `scripts/modules` in generated profiles so fresh shells discover the offline packages.

### Validation
- **631 tests passed; 0 failed.**
- PowerShell lint and security gate passed.
- Two real offline setup runs completed; **all 265 bundled files retained identical SHA-256 hashes**.

### On `eiswmgt-19`
Once these changes have been committed and transferred through your Git route, restore the previously deleted HPREST package from the server’s checkout, **only if it has no intentional local modifications**:

```powershell
git restore --source=HEAD --worktree -- scripts/modules/HPRESTCmdlets/1.2.0.0
make setup
```

To load the bundled modules directly into your current Windows PowerShell session, run from the repository root:

```powershell
Import-Module .\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1 -ErrorAction Stop
Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1 -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST, Get-HPRESTDataRaw
```

**Windows HPREST import and live iLO authentication remain unverified here.** This fixes setup destroying the dependency; it does not yet establish that the runtime 401 is resolved. Any remaining import error will now be retained and visible rather than followed by deletion.

Four setup/test files are modified. No commit or push was made.                             0  1m 1s 605ms  15:27:24 


**Fixed the setup script’s self-deletion bug.**

It previously treated any import failure as corruption, deleted the entire module directory—including the repository bundle—and then attempted PSGallery.

Setup now:
- Imports **explicit local `.psd1` manifests**, preferring the bundled copy.
- **Never deletes module directories or moves away their contents.**
- Makes **no PSGallery or GitHub download attempts**.
- Preserves files and reports the actual import error when loading fails.
- Registers `scripts/modules` in generated profiles so fresh shells discover the offline packages.

### Validation
- **631 tests passed; 0 failed.**
- PowerShell lint and security gate passed.
- Two real offline setup runs completed; **all 265 bundled files retained identical SHA-256 hashes**.

### On `eiswmgt-19`
Once these changes have been committed and transferred through your Git route, restore the previously deleted HPREST package from the server’s checkout, **only if it has no intentional local modifications**:

```powershell
git restore --source=HEAD --worktree -- scripts/modules/HPRESTCmdlets/1.2.0.0
make setup
```

To load the bundled modules directly into your current Windows PowerShell session, run from the repository root:

```powershell
Import-Module .\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1 -ErrorAction Stop
Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1 -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST, Get-HPRESTDataRaw
```

**Windows HPREST import and live iLO authentication remain unverified here.** This fixes setup destroying the dependency; it does not yet establish that the runtime 401 is resolved. Any remaining import error will now be retained and visible rather than followed by deletion.

Four setup/test files are modified. No commit or push was made.





**Fixed the setup script’s self-deletion bug.**

It previously treated any import failure as corruption, deleted the entire module directory—including the repository bundle—and then attempted PSGallery.

Setup now:
- Imports **explicit local `.psd1` manifests**, preferring the bundled copy.
- **Never deletes module directories or moves away their contents.**
- Makes **no PSGallery or GitHub download attempts**.
- Preserves files and reports the actual import error when loading fails.
- Registers `scripts/modules` in generated profiles so fresh shells discover the offline packages.

### Validation
- **631 tests passed; 0 failed.**
- PowerShell lint and security gate passed.
- Two real offline setup runs completed; **all 265 bundled files retained identical SHA-256 hashes**.

### On `eiswmgt-19`
Once these changes have been committed and transferred through your Git route, restore the previously deleted HPREST package from the server’s checkout, **only if it has no intentional local modifications**:

```powershell
git restore --source=HEAD --worktree -- scripts/modules/HPRESTCmdlets/1.2.0.0
make setup
```

To load the bundled modules directly into your current Windows PowerShell session, run from the repository root:

```powershell
Import-Module .\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1 -ErrorAction Stop
Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1 -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST, Get-HPRESTDataRaw
```

**Windows HPREST import and live iLO authentication remain unverified here.** This fixes setup destroying the dependency; it does not yet establish that the runtime 401 is resolved. Any remaining import error will now be retained and visible rather than followed by deletion.

Four setup/test files are modified. No commit or push was made.

ixed the setup script’s self-deletion bug.

It previously treated any import failure as corruption, deleted the entire module directory—including the repository bundle—and then attempted PSGallery.

Setup now:

Imports explicit local .psd1 manifests, preferring the bundled copy.
Never deletes module directories or moves away their contents.
Makes no PSGallery or GitHub download attempts.
Preserves files and reports the actual import error when loading fails.
Registers scripts/modules in generated profiles so fresh shells discover the offline packages.
Validation
631 tests passed; 0 failed.
PowerShell lint and security gate passed.
Two real offline setup runs completed; all 265 bundled files retained identical SHA-256 hashes.
On eiswmgt-19
Once these changes have been committed and transferred through your Git route, restore the previously deleted HPREST package from the server’s checkout, only if it has no intentional local modifications:

git restore --source=HEAD --worktree -- scripts/modules/HPRESTCmdlets/1.2.0.0
make setup
To load the bundled modules directly into your current Windows PowerShell session, run from the repository root:

Import-Module .\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1 -ErrorAction Stop
Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1 -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST, Get-HPRESTDataRaw
Windows HPREST import and live iLO authentication remain unverified here. This fixes setup destroying the dependency; it does not yet establish that the runtime 401 is resolved. Any remaining import error will now be retained and visible rather than followed by deletion.

Four setup/test files are modified. No commit or push was made.





  Import-Module .\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1 -ErrorAction Stop                                                                                                                                                                             0  17:37:21 CRITICAL:  Another HPE OneView module is already loaded:
  |
  |--> HPEOneView.1000 (10.0.4265.2221)

Import-Module: Another HPE OneView module is already loaded.  The HPE OneView PowerShell library does not support loading multiple versions of libraries within the same console.
   image-build-automation  main  Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1 -ErrorAction Stop                                                                                                                                                                             1  21s 125ms  17:38:22        
Add-Type: Cannot add type. The type name 'AsyncPipeline' already exists.
Add-Type: Cannot add type. Compilation errors occurred.
   image-build-automation  main  make setup                                                                                                                                                                                                                                                                     0  22s 44ms  17:38:50 [setup] Setting up PowerShell environment...

╔══════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation - PowerShell Setup     ║
╚══════════════════════════════════════════════════════╝

[OK] PowerShell 7.6.6
[OK] Added offline module path for this session: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules
[INFO] Verifying local PowerShell modules (offline; files are preserved)…
Exception: C:\Users\adm_98253\products\repos\image-build-automation\scripts\setup-runner.ps1:272:9 
Line |
 272 |          throw "Local import failed for $Name $Version from '$Manifest …
     |          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Local import failed for Pester 6.0.1 from 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\Pester\6.0.1\Pester.psd1'. Files were preserved. Import error: Import-Module: The member 'FormatsToProcess' in the module manifest is not valid: Cannot find path
     | 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\Pester\6.0.1\Pester.Format.ps1xml' because it does not exist.. Verify that a valid value is specified for this field in the 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\Pester\6.0.1\Pester.psd1' file. 
make: *** [Makefile:57: setup] Error 1 
   image-build-automation  main                                                                             
The tracked profile generator is correct and already routes through the guarded importer. Work complete.

## Summary

**Fixed the three blockers behind your `eiswmgt-19` failures.**

**1. `make setup` failed on missing `Pester.Format.ps1xml`** — the tracked `scripts/modules/Pester/6.0.1/` package was incomplete. It's now tracked with both format files (byte-identical to the approved vendor copies) and allowlisted in `.gitignore` alongside HPRESTCmdlets and HPEOneView.1000. Previously committed as `cc471374`.

**2. `Another HPE OneView module is already loaded`** — root-caused to the vendor library itself (`HPEOneView.1000.psm1:58-73` throws when any second library loads). I removed the bypasses:
- **`Connect-OneViewSession`** (`OneViewSession.ps1`) now reuses a loaded module with matching name and version instead of re-importing, and refuses a conflicting library with an actionable message. The decision is extracted into `Resolve-OneViewModuleLoadAction` so all three branches are testable.
- **Five profile templates** (`wip/eis19profile.ps1`, `wip/techvdi-profile.ps1`, `wip/windowspsprofilecurrentvdi.ps1`, `wip/prodtechvdi.ps1`, `prodvdicurrent.ps1`) now call the guarded importer instead of a bare `Import-Module`.

**3. HPREST `AsyncPipeline already exists`** — a vendor dual-`Add-Type` defect (`ShowLicense.ps1` + `HPRESTCmdlets.psm1`). The guard detects the orphaned .NET type and requires a fresh `pwsh -NoProfile` shell rather than retrying or bypassing the license script. No vendor files were modified.

### One delivery caveat you need to know
`.gitignore:138` (`/wip/*`) ignores the `wip/` directory. Of the five templates I fixed, only `wip/prodtechvdi.ps1` and `prodvdicurrent.ps1` are tracked. **`wip/eis19profile.ps1`, `wip/techvdi-profile.ps1`, and `wip/windowspsprofilecurrentvdi.ps1` are untracked, so those fixes will not reach `eiswmgt-19` via `git pull`.**

The tracked path still works: `scripts/Setup-Profile.ps1` regenerates the live profile with the guarded importer, and re-running setup overwrites the stale managed block. So after pulling, run `.\scripts\Setup-Profile.ps1` on the server, or edit the live profile line to match the importer.

### Validation
- **673 tests passed, 0 failed** (100.10s), including new tests for all three module-load decision branches and profile-guard coverage.
- Lint passed on 157 files; security gate passed with 0 active code/config findings.

**Not verified:** Windows HPREST import against real hardware, and the live runtime iLO SSO 401. Your `test.log` failure was an import-blocking prerequisite, not proof the 401 is resolved.
