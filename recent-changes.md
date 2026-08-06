# Change log:

<a id="top"></a>

## Table of Contents

- [Change log:](#change-log)
  - [Table of Contents](#table-of-contents)
    - [Command consolidation — 2-command workflow (runbook-aligned)](#command-consolidation--2-command-workflow-runbook-aligned)
      - [**1. `Configure-PhysicalBuild`** — new read-only 4-eye review command (`src/powershell/Automation/Public/Configure-PhysicalBuild.ps1`):](#1-configure-physicalbuild--new-read-only-4-eye-review-command-srcpowershellautomationpublicconfigure-physicalbuildps1)
      - [**2. `Start-PhysicalServerBuild`** — the actual deploy (already existed, now has firmware support):](#2-start-physicalserverbuild--the-actual-deploy-already-existed-now-has-firmware-support)
    - [Admin code removal](#admin-code-removal)
    - [Tests: 488 passed, 0 failed, 1 pre-existing skip](#tests-488-passed-0-failed-1-pre-existing-skip)
    - [Runbook alignment verification](#runbook-alignment-verification)
    - [2) Maintenance mode progress report for DL](#2-maintenance-mode-progress-report-for-dl)
    - [Key findings:](#key-findings)
    - [Runbook alignment:](#runbook-alignment)

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Command consolidation — 2-command workflow (runbook-aligned) | Kev Everall |

<a name="command-consolidation-2-command-workflow-runbook-aligned"></a>

### Command consolidation — 2-command workflow (runbook-aligned)

#### **1. `Configure-PhysicalBuild`** — new read-only 4-eye review command (`src/powershell/Automation/Public/Configure-PhysicalBuild.ps1`):

- Resolves full server identity from OneView (hostname, serial, iLO IP, model, rack, OneView URI, maintenance mode)
- Resolves ISO URL (from ConfigMgr build or external HTTPS/SMB path)
- Runs `Test-PreBuildValidation` (OneView, iLO Redfish, ConfigMgr, network, ISO reachability)
- Prints comprehensive summary: server identity block, ISO details, firmware folders, all destructive actions listed
- Interactive confirmation prompt (`Type 'DEPLOY' to proceed`) — skipped with `-SkipConfirmation` for automation
- Returns a structured plan hashtable that can be piped to `Start-PhysicalServerBuild`
- **6 new Pester tests**, all pass

#### **2. `Start-PhysicalServerBuild`** — the actual deploy (already existed, now has firmware support):

- Already has the confirmation step (`Confirm-IsoDeployment`)
- Now accepts `-FirmwareFolders` (string array) + `-FirmwareConfig` + `-SkipFirmware`
- Runs `Update-Firmware` post-OS-install when firmware folders are supplied
`-FirmwareFolders` parameter (string array)

Added to both `Update-Firmware` and `Start-PhysicalServerBuild`:

- Accepts multiple firmware component source directories from Marin
- Passed to `hpe_sut` via `--firmware-components` flag
- Usage: `-FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5', 'C:\fw\Storage')`
- Hardware engineer can run standalone: `Update-Firmware -Server srv01 -FirmwareFolders @('C:\fw\BIOS_v2.80')`

<a name="admin-code-removal"></a>

### Admin code removal

- Removed all `New-SmbShare`, `Get-SmbShare`, `WindowsPrincipal`/`IsInRole`, "Run as Administrator" logic from 3 files
- Local drive paths now throw: "Supply -ExternalIsoPath as an SMB/UNC or HTTPS URL instead"
- Updated `automation_commands.md` (SMB share section → ISO path requirements)
- Regenerated all 204 dynamic-code-docs

<a name="tests-488-passed-0-failed-1-pre-existing-skip"></a>

### Tests: 488 passed, 0 failed, 1 pre-existing skip

<a name="runbook-alignment-verification"></a>

### Runbook alignment verification

| Runbook requirement | Covered by 2-command design |
|---|---|
| Target server identified in OneView | ✅ `Configure-PhysicalBuild` step 1 |
| Target approved for imaging | ✅ 4-eye confirmation prompt |
| ISO path validated and reachable | ✅ `Test-PreBuildValidation` |
| iLO credentials verified | ✅ Redfish session check |
| ISO mounted via iLO | ✅ `Invoke-IloRedfish -Action MountAndBoot` |
| One-time boot override | ✅ `SetOneTimeBootCd` |
| Task sequence execution | ✅ ConfigMgr handles post-WinPE |
| Post-build validation | ✅ `Test-PostBuildValidation` (hostname, domain, OU, drivers, CM client) |
| Firmware update post-OS | ✅ New `-FirmwareFolders` param |
| Audit trail | ✅ Audit log in `$finally` block |
| Rollback procedure | ⚠️ iLO eject on failure (partial) |

<a name="2-maintenance-mode-progress-report-for-dl"></a>

### 2) Maintenance mode progress report for DL

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-08-06 | Added docs/maint-mode-status.md to summarise the state and progress on maintenance mode commands and build | Kev Everall |

<a name="key-findings"></a>

### Key findings:  

- **67 maintenance mode tests, all passing** — across 8 test files covering SCOM + OneView enable/disable/validate
- **Full feature coverage verified** — time formats, environment resolution, serial number lookup, scheduled tasks, DryRun, OpsRamp integration
- **4 critical risks identified** for banking deployment:
  1. **SCOM module dependency** — silently degrades with `Write-Warning` instead of failing fast
  2. **Plain-text env var credentials** — needs CyberArk/Azure Key Vault integration
  3. **Windows Task Scheduler** — blocked by AppLocker/CAS in banking (use `-NoSchedule`)
  4. **Local catalogue lookup** for OneView serials — not live API resolution

**3 recommendations:**

1. Pre-flight SCOM module availability check
2. Secret vault integration for credentials
3. `-Confirm` parameter for 4-eye validation on live enable/disable

<a name="runbook-alignment"></a>

### Runbook alignment:  

Per `runbook-requirements.md`, maintenance mode is a **separate operational concern** from the ISO build/deploy pipeline. The 2-command workflow (`Configure-PhysicalBuild` + `Start-PhysicalBuild`) does not include maintenance mode commands — they're standalone SCOM/OneView orchestration tools.
