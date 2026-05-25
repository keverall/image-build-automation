# PowerShell Module — GitLab CI Run Requirements

What is required to run the `src/powershell/Automation` module standalone or inside GitLab CI stages. Does **not** duplicate Pester testing guidance (see [`powershell_testing.md`](powershell_testing.md)).

---

## Table of Contents

1. [GitLab CI — PowerShell Stage Requirements](#gitlab-ci-powershell-stage)

### CyberArk credential bootstrap

CyberArk is the **single source of truth for all credentials** used by this pipeline. GitLab CI variables (not `credentials()` IDs) store the initial authentication, then a dedicated **`CyberArk - Bootstrap Secrets`** job runs as the first step after workspace setup and retrieves every secret, injecting them as environment variables for all subsequent PowerShell jobs.

#### Fetching strategy

| Method | Tool | Details |
|---|---|---|
| CCP CLI | `ark_ccl` / `ark_cc` on PATH | Preferred — zero REST overhead |
| AIM REST API | `$env:AIM_WEBSERVICE_URL` or `$env:CYBERARK_CCP_URL` | Fallback when CLI is unavailable |

Both sides call the same logic. CLI tried first (13 secrets, one by one); any that CLI misses are retried through the REST API automatically.

#### Secrets fetched (safe → object → env-var)

\`\`\`
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
\`\`\`

3. [SCOM 2015 — Will It Work?](#scom-2015)
4. [HPE iLO — Will It Work?](#hpe-ilo)
5. [Open Items](#open-items)


---

<a name="gitlab-ci-powershell-stage"></a>
## 2. GitLab CI — PowerShell Stage Requirements

The GitLab CI pipeline in `.gitlab-ci.yml` runs PowerShell jobs using `mcr.microsoft.com/powershell` container images. 
### Minimal prerequisites

- PowerShell 7.4+ (container image in `.gitlab-ci.yml`)
- Pester module for testing:
  \`\`\`powershell
  Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
  \`\`\`
- `powershell-yaml` module only if YAML configs are used:
  \`\`\`powershell
  Install-Module powershell-yaml -Scope CurrentUser -SkipPublisherCheck -Force
  \`\`\`

### Required GitLab CI variables

Set these in your GitLab project's CI/CD variables:

| Variable | Description |
|---|---|
| `MAINTENANCE_CALLBACK_URL` | Webhook URL for completion callback |
| `MAINTENANCE_API_KEY` | Optional API key for callback authentication |
| `CLUSTER_ID` | Target cluster identifier |
| `CONFIG_DIR` | Path to configuration directory |
| `DRY_RUN` | Set to `true` for validation-only runs |

### GitLab CI job example

\`\`\`yaml
powershell_tests:
  stage: test
  image: mcr.microsoft.com/powershell:7.4
  before_script:
    - pwsh -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted"
    - pwsh -Command "Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force"
  script:
    - pwsh -File ./scripts/run-powershell-tests.ps1
  artifacts:
    paths:
      - logs/
    reports:
      junit: powershell-unit-tests.xml
\`\`\`

See [`../../src/powershell/powershell_testing.md`](../../src/powershell/powershell_testing.md) for the full Pester guide (commands, tags, mocking, CI integration).

---

<a name="scom-2015"></a>
## 3. SCOM 2015 — Will It Work?

**Yes — this is the strongest part of the module.**

The PS module calls `OperationsManager` cmdlets **natively** from the calling process. 
\`\`\`powershell
Import-Module OperationsManager                         # SCOM 2015 cmdlets loaded
$conn  = New-SCOMManagementGroupConnection -ComputerName "<scom-mgmt-server>" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "<group-name>"       -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
foreach ($inst in $instances) {
    if (-not $inst.InMaintenanceMode) {
        Start-SCOMMantenanceMode -Instance $inst -Duration $duration -Comment $comment -ErrorAction Stop
    }
}
\`\`\`


### What must be true

| Requirement | Detail |
|---|---|
| GitLab runner is **domain-joined** | The runner must be in the same AD forest as the SCOM management group |
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

`POST /rest/v1/maintenancewindows` is fully implemented and uses proper iLO auth (ISO session login + `X-Redfish-Session` header). This will create a maintenance window on a real iLO 4/5/6 if IPs and credentials are correct.

### `Invoke-IsoDeploy` — iLO virtual media mount ⚠️ scaffold in place

The PS module has **correct iLO session login** (`POST /rest/v1/sessions`) but the actual virtual media mount step is a **commented scaffold** — same contract as Python:

\`\`\`powershell
# Uncomment when ISO serving URL is available:
$vmActionUrl = "$baseUrl/systems/1/MediaState/0/Actions/Oem/Hpe/HpeiLOVirtualMedia/InsertVirtualMedia"
$vmBody   = @{
    Image                 = "<http://iso-server.iso_url>"
    Inserted              = $true
    BootOnNextServerReset = $true
} | ConvertTo-Json
Invoke-RestMethod -Uri $vmActionUrl -Method Post -Body $vmBody -Headers @{ "X-Redfish-Session" = $sessionKey } …
\`\`\`

Until that `<http_iso_url>` is available the step is intentionally a no-op, mirroring the Python-side placeholder verbatim.

### `ILOManager` inside `Set-MaintenanceMode` — iLO maintenance window ✅

`POST /rest/v1/maintenancewindows` — POSTs a new maintenance window body including start/end timestamps. iLO ships a self-signed cert by default; the call uses `-SkipCertificateCheck` which is the PowerShell equivalent of Python's `requests.post(verify=False)`.

### `Start-InstallMonitor` — iLO Redfish polling ✅

`CheckIloStatus` queries `GET /redfish/v1/Systems/1` and returns `PowerState` / `BootSourceOverrideTarget`. Fully wired into the `MonitorServer` poll loop.

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
