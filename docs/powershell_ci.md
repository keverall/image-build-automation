# PowerShell Module — CI Run Requirements

What is required to run the `src/powershell/Automation` module standalone or inside a CI pipeline stage. Does **not** duplicate Pester testing guidance (see [`testing.md`](testing.md)).

---

## Table of Contents

1. [CyberArk Credential Bootstrap](#1-cyberark-credential-bootstrap)
2. [CI Pipeline — PowerShell Stage Requirements](#2-ci-pipeline-powershell-stage-requirements)
3. [SCOM 2015 — Will It Work?](#3-scom-2015-will-it-work)
4. [HPE iLO — Will It Work?](#4-hpe-ilo-will-it-work)
5. [Open Items](#5-open-items)

---

## 1. CyberArk Credential Bootstrap

CyberArk is the **single source of truth for all credentials** used by this pipeline. A dedicated **`CyberArk - Bootstrap Secrets`** stage runs as the first step after workspace setup and retrieves every secret, injecting them as environment variables for all subsequent jobs.

### Fetching Strategy

| Method | Tool | Details |
|---|---|---|
| CCP CLI | `ark_ccl` / `ark_cc` on PATH | Preferred — zero REST overhead |
| AIM REST API | `$env:AIM_WEBSERVICE_URL` or `$env:CYBERARK_CCP_URL` | Fallback when CLI is unavailable |

Both sides call the same logic. CLI tried first (13 secrets, one by one); any that CLI misses are retried through the REST API automatically.

### Secrets Fetched (Safe → Object → Env Var)

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
OpenView (Legacy)   OPENVIEW_USER            → OPENVIEW_USER
OpenView          OPENVIEW_PASSWORD        → OPENVIEW_PASSWORD
HPE-Download      hpe-download-user        → HPE_DOWNLOAD_USER
HPE-Download      hpe-download-pass        → HPE_DOWNLOAD_PASS
```

For a Jenkins pipeline excerpt showing the bootstrap implementation, see [Jenkins CI Example](#jenkins-ci-example).

---

## 2. CI Pipeline — PowerShell Stage Requirements

### Minimal Prerequisites

- PowerShell 7.2+ (cross-platform) or Windows PowerShell 5.1
- Pester 5.7.1 (bundled offline under `vendor/modules/Pester/5.7.1/`):
  ```powershell
  # Setup script installs from bundled copy automatically
  pwsh -File scripts/setup-runner.ps1
  
  # Or install manually (offline-capable via vendor copy)
  Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck -Force -AllowClobber
  ```

- `powershell-yaml` module only if YAML configs are used:

  ```powershell
  Install-Module powershell-yaml -Scope CurrentUser -SkipPublisherCheck -Force
  ```

### GitLab CI Example

```yaml
powershell_tests:
  stage: test
  image: mcr.microsoft.com/powershell:7.4
  before_script:
    - pwsh -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted"
    - pwsh -Command "Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force"
  script:
    - pwsh -File ./scripts/run-tests.ps1
    - pwsh -File ./scripts/run-maint-mode-tests.ps1  # High-priority maintenance mode tests
  artifacts:
    paths:
      - generated/logs/
    reports:
      junit: powershell-unit-tests.xml
```

### Jenkins CI Example

```groovy
stage('PowerShell — Pester Unit Tests') {
    agent { label 'windows' }
    steps {
        powershell '''
            if (-not (Get-Module Pester -ListAvailable)) {
                Install-Module Pester -Scope CurrentUser -SkipPublisherCheck -Force
            }
            Import-Module Pester

            $result = Invoke-Pester -Path 'tests/powershell' -Tag 'Unit' `
                -OutputFile 'powershell-test-results.xml' `
                -OutputFormat NUnitXml `
                -PassThru

            Write-Host "Tests Passed : $($result.PassedCount)"
            Write-Host "Tests Failed : $($result.FailedCount)"
            if ($result.FailedCount -gt 0) { exit 1 }
        '''
    }
    post {
        always { junit 'powershell-test-results.xml' }
    }
}
```

See [`testing.md`](testing.md) for the full Pester guide (commands, tags, mocking, CI integration).

---

## 3. SCOM 2015 — Will It Work?

**Yes — this is the strongest part of the module.**

The PS module calls `OperationsManager` cmdlets **natively** from the calling process:

```powershell
Import-Module OperationsManager
$conn  = New-SCOMManagementGroupConnection -ComputerName "<scom-mgmt-server>" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "<group-name>" -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
foreach ($inst in $instances) {
    if (-not $inst.InMaintenanceMode) {
        Start-SCOMMantenanceMode -Instance $inst -Duration $duration -Comment $comment -ErrorAction Stop
    }
}
```

### What Must Be True

| Requirement | Detail |
|---|---|
| CI agent is **domain-joined** | The `windows` agent must be in the same AD forest as the SCOM management group |
| `OperationsManager` module installed | Picked up from the SCOM 2015 console server; copy or use `Import-Module \\scom-server\share\OperationsManager` if remote |
| `scom_config.json` — `management_server` | SCOM management-group server hostname |
| `scom_config.json` — `use_winrm` | Leave `false` (local PowerShell direct); set `true` only if WinRM to a SCOM server is required, then configure WinRM `TrustedHosts` |
| `clusters_catalogue.json` — `scom_group` | Display name **must match exactly** what SCOM `Get-SCOMGroup` returns |

### What Will NOT Work Without More Work

| Gap | Explanation |
|---|---|
| SCOM REST API | SCOM 2015 has no REST API. The `scom_config.use_winrm=true` setting is reserved for future SCOM 2025 support. There is no REST path on 2015. |
| SCOM login token expiry | `-ErrorAction Stop` on `New-SCOMManagementGroupConnection` will surface authentication failures immediately in CI |

---

## 4. HPE iLO — Will It Work?

### `ILOManager` inside `Set-MaintenanceMode` — iLO REST maintenance window ✅

`POST /rest/v1/maintenancewindows` is fully implemented and uses proper iLO auth (ISO session login + `X-Redfish-Session` header). This will create a maintenance window on a real iLO 4/5/6 if IPs and credentials are correct.

### `Invoke-IsoDeploy` — iLO virtual media mount ⚠️ scaffold in place

The PS module has **correct iLO session login** (`POST /rest/v1/sessions`) but the actual virtual media mount step is a **commented scaffold**:

```powershell
# Uncomment when ISO serving URL is available:
$vmActionUrl = "$baseUrl/systems/1/MediaState/0/Actions/Oem/Hpe/HpeiLOVirtualMedia/InsertVirtualMedia"
$vmBody   = @{
    Image                 = "<http://iso-server.iso_url>"
    Inserted              = $true
    BootOnNextServerReset = $true
} | ConvertTo-Json
Invoke-RestMethod -Uri $vmActionUrl -Method Post -Body $vmBody -Headers @{ "X-Redfish-Session" = $sessionKey }
```

Until that `<http_iso_url>` is available the step is intentionally a no-op.

### `Start-InstallMonitor` — iLO Redfish polling ✅

`CheckIloStatus` queries `GET /redfish/v1/Systems/1` and returns `PowerState` / `BootSourceOverrideTarget`. Fully wired into the `MonitorServer` poll loop.

---

## 5. Open Items

| Priority | Item | Status | Detail |
|---|---|---|---|
| ✅ Fixed | `Invoke-IsoDeploy` broken syntax | Fixed | All `;,return,` / `$)($` artefacts removed; pure PS guards |
| ✅ Fixed | `Update-WindowsSecurity` broken syntax | Fixed | All `;,return,` / `$)($` / `Disassemble-Image` artefacts removed |
| ✅ Better | `Update-Firmware` no retry | Improved | Now uses `Invoke-NativeCommandWithRetry` with exponential back-off |
| ✅ Done | `Update-WindowsSecurity` DISM loop | Done | `_ApplyPatchesDism` calls `Invoke-NativeCommand` per KB |
| ⚠️ Partial | iLO virtual media mount in `Invoke-IsoDeploy` | Scaffold in place | Session login implemented; full `InsertVirtualMedia` POST requires an HTTPServing URL to be decided separately |
| ⚠️ Partial | Redfish ISO mount in `Invoke-IsoDeploy` | Scaffold in place | Comment present; needs ISO URL first |

---

## See Also

- [Maintenance Mode Orchestration](maintenance_mode.md)
- [PowerShell Testing Guide](testing.md)
- [Code Quality & Security](code_quality.md)