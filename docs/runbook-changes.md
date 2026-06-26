# Plan: ConfigMgr Bootable Media Automation (per runbook-requirements.md)

## Goal

Replace the current DSC/DISM-based custom ISO build approach with a ConfigMgr bootable media workflow matching `wip/runbook-requirements.md`. The automation will create a ConfigMgr WinPE boot ISO, query HPE OneView for target server identity, mount the ISO via iLO Redfish virtual media, force one-time boot, and monitor the OS deployment.

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ConfigMgr context | Auto-detect: check if CM module is available locally, fall back to PSRemoting | Handles both site-server and remote-admin-host scenarios |
| ISO serving | HTTPS file server (IIS or similar internal web server) | Runbook prefers HTTPS; iLO Redfish requires an HTTP-accessible URL |
| iLO API | Redfish (`/redfish/v1/`) not iLO REST (`/rest/v1/`) | Industry standard, future-proof, client explicitly specified in runbook |
| Firmware/patch code | Relocate from `New-IsoBuild` into standalone `Update-Firmware.ps1` | Preserve for future use; not part of the ConfigMgr workflow |
| Terminology | No "patching", no "firmware in ISO". Use "OSD", "bootable media", "task sequence", "image deployment" | Bladelogic handles patching; this code is for new server builds only |
| SCOM | Not involved | Not mentioned in the runbook; out of scope |

## Scope Boundary

**IN SCOPE:**
- ConfigMgr bootable media ISO creation (dynamic mode, WinPE)
- HPE OneView server identification and validation
- iLO Redfish virtual media mount + one-time boot override
- WinPE boot → task sequence execution monitoring
- Pre-build and post-build validation
- End-to-end orchestrator script
- Audit logging for every action
- HTTPS ISO publishing

**OUT OF SCOPE (handled by other systems/teams):**
- Windows OS patching (Bladelogic)
- Windows Server source image import into ConfigMgr (ConfigMgr Admin)
- Task sequence creation (ConfigMgr Admin)
- Driver package management in ConfigMgr (ConfigMgr Admin)
- HPE hardware assembly/rack-and-stack (Hardware Engineer)
- OneView server inventory maintenance (OneView Admin)
- SCOM monitoring/maintenance mode (separate workflows)

## Implementation Tasks (Ordered)

### Task 1: Add Redfish iLO integration module

**File:** `src/powershell/Automation/Public/Invoke-IloRedfish.ps1` (new)

Replace the current iLO REST scaffold with full Redfish implementation:

1. **Session authentication** via Redfish:
   - `POST /redfish/v1/SessionService/Sessions` with basic auth
   - Store `X-Auth-Token` header for subsequent calls
   - Session logout on completion

2. **Virtual media mount**:
   - `GET /redfish/v1/Managers/1/VirtualMedia/` to enumerate devices
   - Find the CD/DVD virtual media device
   - `POST …/VirtualMedia/<id>/Actions/VirtualMedia.InsertMedia` with ISO URL

3. **One-time boot override**:
   - `PATCH /redfish/v1/Systems/1` with `BootSourceOverrideTarget: "Cd"` and `BootSourceOverrideEnabled: "Once"`

4. **System reset**:
   - `POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset` with `ResetType: "ForceRestart"`

5. **Eject media** (for rollback/recovery):
   - `POST …/VirtualMedia/<id>/Actions/VirtualMedia.EjectMedia`

6. **Skip certificate check** (iLO ships with self-signed certs - same as existing code)

All Redfish calls reuse the existing `Get-IloCredentials` function and the existing `Invoke-RestMethod -SkipCertificateCheck` pattern.

**Dependencies:** None (existing `Credentials.ps1` reused)

---

### Task 2: ISO HTTPS publishing mechanism

**File:** `src/powershell/Automation/Public/Publish-BootIso.ps1` (new)

Publish the ConfigMgr bootable ISO to an HTTPS endpoint that iLO can reach:

1. Accept ISO file path and target URL base from config
2. Validate ISO exists and is readable
3. Copy/serve ISO to the HTTPS repository
4. Return the full public URL for Redfish consumption
5. Support configurable repository via `oneview_config.json` or environment variable (`ISO_REPO_BASE_URL`)
6. Verify the URL is reachable (HTTP HEAD check)

**Config addition to `configs/oneview_config.json`:**
```json
"iso_repository": {
  "base_url": "https://artifacts.internal.example.com/isos/",
  "method": "https_copy"
}
```

---

### Task 3: OneView server targeting

**File:** `src/powershell/Automation/Public/Get-OneViewServerTarget.ps1` (new)

Query HPE OneView REST API to identify and validate the target server:

1. Accept server identifier: name, serial number, or OneView name
2. `GET /rest/server-hardware?filter="name='<identifier>'"` or serial filter
3. Return server object with: name, serial, power state, health state, iLO IP, model, enclosure info
4. Validate health state is "OK" before proceeding
5. Validate power state (off or on - both acceptable if force restart is used)
6. Error if server not found or health is critical

Uses the bundled `HPEOneView.860` module or direct REST API (with the existing `Get-OneViewCredentials`).

**Config reference:** `configs/connection_hosts.json` (OneView appliance URL) and `configs/oneview_config.json` (credentials)

---

### Task 4: Pre-build validation

**File:** `src/powershell/Automation/Public/Test-PreBuildValidation.ps1` (new)

Implementation of the runbook's pre-build validation checklist:

1. OneView target identified and confirmed (calls Task 3)
2. ConfigMgr boot image and task sequence available
3. ISO path/URL reachable
4. iLO credentials verified (Redfish session test)
5. Management Point / Distribution Point network reachability from target VLAN
6. Change record/audit entry logged

Returns a hashtable of checks with pass/fail status.

---

### Task 5: Post-build validation

**File:** `src/powershell/Automation/Public/Test-PostBuildValidation.ps1` (new)

Implementation of the runbook's post-build validation checklist:

1. Expected hostname assigned (query via WinRM or DNS)
2. Domain join successful (check computer object)
3. Operating system version and edition verified
4. HPE device drivers present (check device manager/driver list)
5. ConfigMgr client healthy and assigned to site
6. RDP / PowerShell / management agents operational
7. Build outcome recorded in audit log

---

### Task 6: Rewrite `New-IsoBuild` for ConfigMgr bootable media

**File:** `src/powershell/Automation/Public/New-IsoBuild.ps1` (major rewrite)

Replace the current firmware-DISM logic with ConfigMgr `New-CMBootableMedia`:

1. **Auto-detect ConfigMgr context:**
   - Check if `ConfigurationManager` module is available locally
   - If not, attempt PSRemoting to the ConfigMgr site server (configured in config)
   - Fall back to explicit credentials for remote context

2. **Create bootable media:**
   ```
   New-CMBootableMedia -MediaMode Dynamic -MediaType CdDvd `
       -Path "<output path>" `
       -AllowUnknownMachine -AllowUnattended `
       -BootImage $BootImage `
       -DistributionPoint $DistributionPoint `
       -ManagementPoint $ManagementPoint `
       -MediaPassword $MediaPassword
   ```

3. **Configurable parameters** (from a new or extended config file):
   - Boot image name/ID
   - Management Point FQDN
   - Distribution Point(s)
   - Media password (optional, from secret store)
   - Output path for ISO

4. **ISO versioning** per runbook standard: `WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso`

5. **Return** the ISO path and metadata for the next step (Task 2 publishing)

**Remove:** All `[FirmwareUpdater]`, `[WindowsPatcher]`, DISM logic, `Build-ForServer` function, `$FwConfig`, `$PatchConfig`, `generated_patched_iso`, `firmware_iso` references.

---

### Task 7: Relocate firmware/patch code

**File:** `src/powershell/Automation/Public/Update-Firmware.ps1` (existing, needs refactor)

Move the firmware ISO creation logic (currently embedded in `New-IsoBuild` via `[FirmwareUpdater]` and `[WindowsPatcher]`) into this standalone function. Keep the function registered in `request_types.json` under `update_firmware` and `patch_windows`.

The function should be callable independently but is NOT part of the new end-to-end ConfigMgr build workflow.

Remove `Build-ForServer` private function from `New-IsoBuild` - relocate its firmware portion here.

---

### Task 8: End-to-end orchestrator

**File:** `src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1` (new)

Wrapper function matching the runbook's `Start-PhysicalServerBuild.ps1`:

1. Accept target server identifier (name, serial, or OneView ID)
2. **Pre-build validation** (Task 4)
3. **Create ConfigMgr bootable media ISO** (Task 6 → `New-IsoBuild`)
4. **Publish ISO** to HTTPS repository (Task 2)
5. **OneView server targeting** - resolve iLO address (Task 3)
6. **Mount ISO via iLO Redfish** + force boot (Task 1)
7. **Monitor** installation progress (existing `Start-InstallMonitor`)
8. **Post-build validation** (Task 5)
9. **Audit complete** - log all steps with timestamps

Every step logs to the existing audit infrastructure (`AuditLogger`).

---

### Task 9: Add new request types to routing

**File:** `configs/request_types.json` (update)

Add new request types:
```json
"physical_server_build": {
  "powershell_handler": "Start-PhysicalServerBuild",
  "ci_stage": "all",
  "description": "End-to-end physical server build via ConfigMgr + OneView + iLO"
},
"query_oneview_server": {
  "powershell_handler": "Get-OneViewServerTarget",
  "ci_stage": null,
  "description": "Query HPE OneView for server identity and health"
},
"prebuild_validation": {
  "powershell_handler": "Test-PreBuildValidation",
  "ci_stage": null,
  "description": "Run pre-build validation checks"
},
"postbuild_validation": {
  "powershell_handler": "Test-PostBuildValidation",
  "ci_stage": null,
  "description": "Run post-build validation checks"
},
"publish_iso": {
  "powershell_handler": "Publish-BootIso",
  "ci_stage": "deploy",
  "description": "Publish bootable ISO to HTTPS repository"
},
"ilo_redfish_mount": {
  "powershell_handler": "Invoke-IloRedfish",
  "ci_stage": "deploy",
  "description": "Mount ISO via iLO Redfish and force boot"
}
```

---

### Task 10: Update ConfigMgr configuration

**File:** `configs/configmgr_config.json` (new)

Configuration for ConfigMgr connectivity:

```json
{
  "configmgr": {
    "site_code": "P01",
    "management_point": "mp01.ad.example.com",
    "distribution_points": ["dp01.ad.example.com"],
    "site_server": "cm01.ad.example.com",
    "boot_image_name": "WinPE x64 - HPE",
    "task_sequence_name_prefix": "TS - WinSrv2025 - HPE",
    "media_password_env": "CM_MEDIA_PASSWORD",
    "output_path": "\\\\fileserver\\osdmedia\\"
  }
}
```

---

### Task 11: Update module manifest and exports

**File:** `src/powershell/Automation/Automation.psd1`

Add to `FunctionsToExport`:
- `Start-PhysicalServerBuild`
- `Get-OneViewServerTarget`
- `Invoke-IloRedfish`
- `Publish-BootIso`
- `Test-PreBuildValidation`
- `Test-PostBuildValidation`

---

### Task 12: Unit tests

**File:** `tests/powershell/` (new and updated files)

Create Pester unit tests for all new functions:
- `Invoke-IloRedfish.Unit.Tests.ps1` - mock Redfish responses
- `Get-OneViewServerTarget.Unit.Tests.ps1` - mock OneView API
- `Publish-BootIso.Unit.Tests.ps1` - mock file operations
- `Test-PreBuildValidation.Unit.Tests.ps1`
- `Test-PostBuildValidation.Unit.Tests.ps1`
- `Start-PhysicalServerBuild.Unit.Tests.ps1` - integration mock
- Update `New-IsoBuild.Unit.Tests.ps1` for ConfigMgr rewrite

---

### Task 13: Update existing `Invoke-IsoDeploy` for Redfish

**File:** `src/powershell/Automation/Public/Invoke-IsoDeploy.ps1` (refactor)

- Replace `_DeployViaIlo` with call to new `Invoke-IloRedfish` (Task 1)
- Replace `_DeployViaRedfish` with proper Redfish implementation
- Remove the iLO REST session login code (now handled by Task 1)
- Keep `ISODeployer` class for bulk deployment orchestration
- The `Invoke-IsoDeploy` function becomes a consumer of `Invoke-IloRedfish`, not the primary implementation

---

### Task 14: Rename/remove patching terminology

**Files:** Multiple

- In `request_types.json`: Rename `patch_windows` handler to keep working but remove from the primary flow
- In `New-IsoBuild`: Remove all "patch", "patched_iso", "WindowsPatcher" references
- In `Invoke-IsoDeploy`: Remove `generated_patched_iso` references from metadata lookups - use `bootable_iso` instead
- Update generated metadata keys from `generated_patched_iso` to `bootable_iso`

---

## File Change Summary

| File | Action | Lines ~ |
|------|--------|---------|
| `Public/Invoke-IloRedfish.ps1` | **New** | ~200 |
| `Public/Publish-BootIso.ps1` | **New** | ~80 |
| `Public/Get-OneViewServerTarget.ps1` | **New** | ~130 |
| `Public/Test-PreBuildValidation.ps1` | **New** | ~120 |
| `Public/Test-PostBuildValidation.ps1` | **New** | ~120 |
| `Public/New-IsoBuild.ps1` | **Major rewrite** | ~250 |
| `Public/Start-PhysicalServerBuild.ps1` | **New** | ~150 |
| `Public/Invoke-IsoDeploy.ps1` | **Refactor** | ~80 changed |
| `Public/Update-Firmware.ps1` | **Refactor** (receive relocated code) | ~100 |
| `configs/request_types.json` | **Update** | ~40 |
| `configs/configmgr_config.json` | **New** | ~15 |
| `Automation.psd1` | **Update** | ~6 |
| `tests/powershell/*.Tests.ps1` | **New/updated** | ~400 |
| `configs/oneview_config.json` | **Update** (iso_repository section) | ~5 |

**Total: ~1,700 lines across 14 files**

## Validation

1. Run Pester unit tests: `Invoke-Pester tests/powershell/`
2. Check all new functions export correctly: `Get-Command -Module Automation`
3. Verify route map: `Get-RouteMap` output includes new types
4. Lint: `Invoke-ScriptAnalyzer src/powershell/`
5. Manual integration test (requires ConfigMgr + OneView + iLO lab):
   - `Start-PhysicalServerBuild -ServerIdentifier 'PROD-SERVER-01' -DryRun` → validates full flow without side effects
   - Single real server build with monitoring

## Risks

1. **ConfigMgr PowerShell module availability**: `New-CMBootableMedia` requires the Configuration Manager console or the CM PowerShell module. If neither is available, PSRemoting must be configured and tested.
2. **iLO Redfish version differences**: iLO 4 vs iLO 5 vs iLO 6 have slightly different Redfish endpoints. Need to handle version detection or make endpoints configurable.
3. **HTTPS ISO repository**: Requires an internal web server. If none exists, this is a pre-requisite gap the client must fill.
4. **OneView API permissions**: The service account needs `read` on server-hardware. Must be pre-configured by the OneView admin.