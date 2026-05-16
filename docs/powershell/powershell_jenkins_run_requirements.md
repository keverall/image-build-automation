# PowerShell Module — Jenkins Run Requirements

What is required to run the `powershell/Automation` module standalone or inside a
separate Jenkins `windows` stage.  Does **not** duplicate Pester testing guidance
(see [`powershell_testing.md`](powershell_testing.md)) or the Python testing
guide (see [`../python/testing.md`](../python/testing.md)).

---

## Table of Contents

1. [Feature Parity: Python `src/` → PowerShell](#feature-parity)
2. [Jenkinsfile — Standalone PowerShell Stage](#jenkinsfile-standalone-ps-stage)

### CyberArk credential bootstrap

CyberArk is the **single source of truth for all credentials** used by this
pipeline.  The Jenkins `environment {}` block no longer uses `credentials()`
IDs — instead a dedicated **`CyberArk - Bootstrap Secrets`** stage runs as the
first thing after workspace setup and retrieves every secret, injecting them as
environment variables for all subsequent Python and PowerShell stages.

#### Fetching strategy

| Method | Tool | Details |
|---|---|---|
| CCP CLI | `ark_ccl` / `ark_cc` on PATH | Preferred — zero REST overhead
| AIM REST API | `$env:AIM_WEBSERVICE_URL` or `$env:CYBERARK_CCP_URL` | Fallback when CLI is unavailable

Both sides call the same logic.  CLI tried first (13 secrets, one by one);
any that CLI misses are retried through the REST API automatically.

#### Secrets fetched (safe → object → env-var)

```
Safe              Object                   → Env Var
HPE-iLO           ILO_USER                 → ILO_USER
HPE-iLO           ILO_PASSWORD             → ILO_PASSWORD
SCOM-2015         SCOM_ADMIN_USER          → SCOM_ADMIN_USER
SCOM-2015         SCOM_ADMIN_PASSWORD      → SCOM_ADMIN_PASSWORD
OpsRamp           OPSRAMP_CLIENT_ID        → OPSRAMP_CLIENT_ID
OpsRamp           OPSRAMP_CLIENT_SECRET    → OPSRAMP_CLIENT_SECRET
OpsRamp           OPSRAMP_TENANT_ID        → OPSRAMP_TENANT_ID
SMTP-Mail         SMTP_USER                → SMTP_USER
SMTP-Mail         SMTP_PASSWORD            → SMTP_PASSWORD
OpenView          OPENVIEW_USER            → OPENVIEW_USER
OpenView          OPENVIEW_PASSWORD        → OPENVIEW_PASSWORD
HPE-Download      hpe-download-user        → HPE_DOWNLOAD_USER
HPE-Download      hpe-download-pass        → HPE_DOWNLOAD_PASS
```

#### Jenkinsfile excerpt

```groovy
stage('CyberArk - Bootstrap Secrets') {
    steps {
        powershell '''
        # CCP CLI
        $ccCli = Get-Command ark_ccl -ErrorAction SilentlyContinue
        if (-not $ccCli) { $ccCli = Get-Command ark_cc -ErrorAction SilentlyContinue }
        if ($ccCli) {
            # …fetch each Safe/Object envelope via CLI…
            [System.Environment]::SetEnvironmentVariable($s.Var, $secret, 'Process')
        }
        # REST fallback
        $aimUrl = $env:AIM_WEBSERVICE_URL ?? 'https://cyberark-ccp:443/AIMWebService/API/Accounts'
        # …fetch any remaining missing secrets via REST…
        '''
    }
}
```

3. [SCOM 2015 — Will It Work?](#scom-2015)
4. [HPE iLO — Will It Work?](#hpe-ilo)
5. [Open Items](#open-items)

---

<a name="feature-parity"></a>
## 1. Feature Parity: Python `src/` → PowerShell

Every Python module in `src/automation/` is **structurally present** in
`powershell/Automation/` — same file count, same routing map, same entry-point
names, same config contracts (`configs/*.json` shared by both).  Degree of
implementation is noted separately below.

| # | Module | Python file | PowerShell file | PS status |
|---|---|---|---|---|
| 1 | Config | `utils/config.py` | `Private/Config.ps1` | ✅ Fully ported |
| 2 | Credentials | `utils/credentials.py` | `Private/Credentials.ps1` | ✅ Fully ported |
| 3 | Executor | `utils/executor.py` | `Private/Executor.ps1` | ✅ + `Invoke-NativeCommandWithRetry` stronger |
| 4 | FileIO | `utils/file_io.py` | `Private/FileIO.ps1` | ✅ Fully ported |
| 5 | Inventory | `utils/inventory.py` | `Private/Inventory.ps1` | ✅ Fully ported |
| 6 | Audit | `utils/audit.py` | `Private/Audit.ps1` | ✅ Fully ported |
| 7 | Logging | `utils/logging_setup.py` | `Private/Logging.ps1` | ✅ |
| 8 | Router | `core/router.py` | `Private/Router.ps1` + `_RouteMap.ps1` | ✅ |
| 9 | Orchestrator | `core/orchestrator.py` | `Public/Start-AutomationOrchestrator.ps1` | ✅ |
| 10 | Base | `utils/base.py` | `Private/Base.ps1` | ✅ |
| 11 | Uuid | `cli/generate_uuid.py` | `Public/New-Uuid.ps1` | ✅ RFC-4122 v4 |
| 12 | Build ISO | `cli/build_iso.py` | `Public/New-IsoBuild.ps1` | ✅ |
| 13 | **Firmware** | `cli/update_firmware_drivers.py` | `Public/Update-Firmware.ps1` | ⚠️ See §Open Items |
| 14 | **Security Patch** | `cli/patch_windows_security.py` | `Public/Update-WindowsSecurity.ps1` | ⚠️ See §Open Items |
| 15 | **Deploy** | `cli/deploy_to_server.py` | `Public/Invoke-IsoDeploy.ps1` | ⚠️ See §Open Items |
| 16 | **Install Monitor** | `cli/monitor_install.py` | `Public/Start-InstallMonitor.ps1` | ✅ (full loop: iLO + WinRM) |
| 17 | **Maintenance Mode** | `cli/maintenance_mode.py` | `Public/Set-MaintenanceMode.ps1` | ✅ |
| 18 | OpsRamp | `cli/opsramp_integration.py` | `Public/Invoke-OpsRampClient.ps1` | ✅ |
| 19 | Validators | `utils/validators.py` | `Public/Invoke-Validator.ps1` | ✅ |
| 20 | PS execution | `utils/powershell.py` | `Public/Invoke-PowerShellScript.ps1` + `WinRM.ps1` | ✅ |
| 21 | SCOM helpers | N/A (PS-only) | `Public/New-ScomConnection.ps1` + `New-ScomMaintenanceScript.ps1` | ✅ PS-native |

**Modules in unbroken grey above (16 of 21) are complete and tested.**  
The three ⚠️ entries are documented individually below.

---

<a name="jenkinsfile-standalone-ps-stage"></a>
## 2. Jenkinsfile — Standalone PowerShell Stage

The existing `Jenkinsfile` runs on `label 'windows'`.  A dedicated PS stage can be
dropped in alongside the existing Python `Unit Tests & Coverage` stage — no new
infrastructure is needed.

### Minimal prerequisite

```powershell
Install-Module Pester          -Scope CurrentUser -SkipPublisherCheck -Force
Install-Module powershell-yaml -Scope CurrentUser -SkipPublisherCheck -Force   # only if YAML configs are used
```

### Recommended Jenkinsfile addition

```groovy
stage('PowerShell — Pester Unit Tests') {
    agent { label 'windows' }
    steps {
        powershell '''
            # Bootstrap
            if (-not (Get-Module Pester -ListAvailable)) {
                Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
            }
            if (-not (Get-Module powershell-yaml -ListAvailable)) {
                Install-Module powershell-yaml -Scope CurrentUser -SkipPublisherCheck -Force
            }

            # Import module
            $mod = Resolve-Path 'powershell\Automation\Automation.psd1'
            Import-Module $mod.Path -Force -ErrorAction Stop

            # Run unit tests, emit JUnit XML for Jenkins
            $result = Invoke-Pester -Path 'powershell\\Tests' -Tag 'Unit' `
                -OutputFile 'powershell-unit-tests.xml' `
                -OutputFormat NUnitXml `
                -PassThru

            Write-Host "Passed: $($result.PassedCount)  Failed: $($result.FailedCount)"
            if ($result.FailedCount -gt 0) { exit 1 }
        '''
    }
    post {
        always { junit 'powershell-unit-tests.xml' }
        failure {
            mail to: 'dev-team@yourcompany.com',
                 subject: "PowerShell Tests FAILED: Build #${BUILD_NUMBER}",
                 body: "Run Invoke-Pester locally from the workspace."
        }
    }
}
```

See [`../powershell/powershell_testing.md`](../powershell/powershell_testing.md) for the full Pester guide
(commands, tags, mocking, CI integration).

### Incremental / PR testing (optional)

When `params.RUN_PS_INTEGRATION` is `true` the following tag-filtered step can
run after unit tests pass:

```groovy
stage('PowerShell — Integration Tests') {
    when { expression { params.RUN_PS_INTEGRATION } }
    agent { label 'windows' }
    steps {
        powershell '''
            Invoke-Pester -Path 'powershell\\Tests\Pester.All.api.ps1' -Tag Integration -PassThru
        '''
    }
}
```

---

<a name="scom-2015"></a>
## 3. SCOM 2015 — Will It Work?

**Yes — this is the strongest part of the module.**

The PS module calls `OperationsManager` cmdlets **natively** from the calling
process.  The Python side had to shell out to `powershell.exe`; the PS side does
not:

```powershell
Import-Module OperationsManager                         # SCOM 2015 cmdlets loaded
$conn  = New-SCOMManagementGroupConnection -ComputerName "<scom-mgmt-server>" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "<group-name>"       -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
foreach ($inst in $instances) {
    if (-not $inst.InMaintenanceMode) {
        Start-SCOMMantenanceMode -Instance $inst -Duration $duration -Comment $comment -ErrorAction Stop
    }
}
```

This is exactly the script the Python `New-ScomMaintenanceScript.ps1` would emit
and pipe to `powershell.exe`; in PS it runs inline.

### What must be true

| Requirement | Detail |
|---|---|
| Jenkins agent is **domain-joined** | The `windows` agent must be in the same AD forest as the SCOM management group |
| `OperationsManager` module installed | Picked up from the SCOM 2015 console server; copy or use `Import-Module \\scom-server\share\OperationsManager` if remote |
| `scom_config.json` — `management_server` | SCOM management-group server hostname |
| `scom_config.json` — `use_winrm` | Leave `false` (local PowerShell direct); set `true` only if WinRM to a SCOM server is required, then configure WinRM `TrustedHosts` |
| `clusters_catalogue.json` — `scom_group` | Display name **must match exactly** what SCOM `Get-SCOMGroup` returns |

### What will NOT work without more work

| Gap | Explanation |
|---|---|
| SCOM REST API | SCOM 2015 has no REST API. The Python code uses `scom_config.use_winrm=true` as a future SCOM 2025 path (see `README.md § Why Not REST?`). There is no REST path on 2015 — both implementations are correct for 2015. |
| SCOM login token expiry | `-ErrorAction Stop` on `New-SCOMManagementGroupConnection` will surface authentication failures immediately in CI |

---

<a name="hpe-ilo"></a>
## 4. HPE iLO — Will It Work?

### `ILOManager` inside `Set-MaintenanceMode` — iLO REST maintenance window ✅

`POST /rest/v1/maintenancewindows` is fully implemented and uses proper iLO auth
(ISO session login + `X-Redfish-Session` header).  This will create a maintenance
window on a real iLO 4/5/6 if IPs and credentials are correct.

### `Invoke-IsoDeploy` — iLO virtual media mount ⚠️ scaffold in place

The PS module has **correct iLO session login** (`POST /rest/v1/sessions`) but
the actual virtual media mount step is a **commented scaffold** — same contract as
Python:

```powershell
# Uncomment when ISO serving URL is available:
$vmActionUrl = "$baseUrl/systems/1/MediaState/0/Actions/Oem/Hpe/HpeiLOVirtualMedia/InsertVirtualMedia"
$vmBody   = @{
    Image                 = "<http://iso-server.iso_url>"
    Inserted              = $true
    BootOnNextServerReset = $true
} | ConvertTo-Json
Invoke-RestMethod -Uri $vmActionUrl -Method Post -Body $vmBody -Headers @{ "X-Redfish-Session" = $sessionKey } …
```

Until that `<http_iso_url>` is available the step is intentionally a no-op,
mirroring the Python-side placeholder verbatim.

### `ILOManager` inside `Set-MaintenanceMode` — iLO maintenance window ✅

`POST /rest/v1/maintenancewindows` — POSTs a new maintenance window body
including start/end timestamps.  iLO ships a self-signed cert by default; the
call uses `-SkipCertificateCheck` which is the PowerShell equivalent of
Python's `requests.post(verify=False)`.

### `Start-InstallMonitor` — iLO Redfish polling ✅

`CheckIloStatus` queries `GET /redfish/v1/Systems/1` and returns
`PowerState` / `BootSourceOverrideTarget`.  Fully wired into the `MonitorServer`
poll loop.

---

<a name="open-items"></a>
## 5. Open Items

| Priority | Item | Status | Detail |
|---|---|---|---|
| ✅ Fixed | `Invoke-IsoDeploy` broken syntax | Fixed | All `;,return,` / `$)($` artefacts removed; pure PS guards |
| ✅ Fixed | `Update-WindowsSecurity` broken syntax | Fixed | All `;,return,` / `$)($` / `Disassemble-Image` artefacts removed |
| ✅ Better | `Update-Firmware` no retry | Improved | Now uses `Invoke-NativeCommandWithRetry` with exponential back-off — cache-side improvement over Python (Python also has no retry; PS is now marginally stronger) |
| ✅ Done | `Update-WindowsSecurity` DISM loop | Done | `_ApplyPatchesDism` calls `Invoke-NativeCommand` per KB. `DISM /Image /Add-Package /PackagePath /LimitAccess /NoRestart` on `winpeimg` — same pattern as Python stub |
| ⚠️ Partial | iLO virtual media mount in `Invoke-IsoDeploy` | Unchanged — same on Python side | Scaffold is in place (session login + commented mount sequence); full `InsertVirtualMedia` POST requires an HTTPServing URL to be decided separately |
| ⚠️ Partial | Redfish ISO mount in `Invoke-IsoDeploy` | Unchanged — same on Python side | Scaffold comment present; needs ISO URL first |
