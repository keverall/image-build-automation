# GitLab CI/CD Pipeline Trigger API — REST reference and integration guide

> **Scope:** `docs/api/` — external API integration layer.
> For the orchestrator & routing internals that run *inside* the pipeline, see [../api_reference.md](../api_reference.md).

---

## Overview

GitLab CI/CD pipeline triggers bridge web-based ticketing systems (iRequest,
ServiceNow, Jira) with automated backend PowerShell scripts. The GitLab
self-hosted instance is the automation gateway — a REST architecture
that bridges web-based ticketing systems with automated backend PowerShell scripts.

```
iRequest / ServiceNow / Jira
            │
            │  HTTP POST  /api/v4/projects/{id}/trigger/pipeline
            ▼
     GitLab CI/CD Pipeline
            │
            │  pipeline environment variables (ACTION, CLUSTER_ID …)
            ▼
  Invoke-GitLabMaintenance.ps1  (scripts/gitlab/)
            │
            │  calls
            ▼
  Set-MaintenanceMode.ps1  →  SCOM / iLO / OpenView
```

---

## Step 1 — Pipeline configuration (`.gitlab-ci.yml`)

Pipeline jobs are defined as code in `.gitlab-ci.yml` and committed to the
same repository as the automation scripts.

### Required file

**`.gitlab-ci.yml`**

```YAML
stages:
  - maintenance

.maintenance_defaults: &maintenance_defaults
  stage: maintenance
  image: mcr.microsoft.com/powershell:7.4
  only:
    - triggers

maintenance-mode:
  <<: *maintenance_defaults
  variables:
    FF_NETWORK_PER_BUILD: "true"
    ACTION:      "enable"     # or "disable", "validate"
    CLUSTER_ID:  ""
    START:       ""
    END:         ""
    CONFIG_DIR:  "configs"
    DRY_RUN:     "false"
  script:
    - pwsh -File ./scripts/gitlab/Invoke-GitLabMaintenance.ps1
```

### CI/CD Variables (project defaults / override source)

Set in **GitLab > Project Settings > CI/CD > Variables** (`/settings/ci_cd`).

| Variable | Purpose |
|---|---|
| `ACTION` | `enable`, `disable`, or `validate` |
| `CLUSTER_ID` | Target cluster or server group |
| `START` | Maintenance window start (ISO 8601) |
| `END` | Maintenance window end (ISO 8601) |
| `CONFIG_DIR` | Path to cluster config files |
| `DRY_RUN` | `true` to test without making changes |
| `MAINTENANCE_CALLBACK_URL` | Webhook URL for completion callback (optional) |
| `MAINTENANCE_API_KEY` | Password for callback authentication (optional) |

Variables passed directly in the trigger API payload override the values set
in the CI/CD Variables UI for that invocation only.

### GitLab CI entry-point script

**`scripts/gitlab/Invoke-GitLabMaintenance.ps1`**

Executed as `pwsh -File`. Runs inside the CI runner (not dot-sourced). Sources
`Set-MaintenanceMode.ps1`, executes it with the CI environment variables, emits
a JSON result line, and writes an artifact to `logs/`.

Key environment variables exported to the script:

| Variable | Description |
|---|---|
| `ACTION` | enable / disable / validate |
| `CLUSTER_ID` | Target cluster |
| `START` / `END` | ISO 8601 window |
| `CONFIG_DIR` | Config directory path |
| `DRY_RUN` | Boolean string (`true` / `false`) |
| `CI_PIPELINE_ID` | Pipeline ID (for traceability) |
| `CI_JOB_ID` | Job ID (for log/artifact naming) |
| `CI_PROJECT_ID` | Project ID |
| `MAINTENANCE_CALLBACK_URL` | Optional callback webhook |
| `MAINTENANCE_API_KEY` | Optional callback auth header |

**Job artifacts on exit:**

```
logs/maintenance_<CI_JOB_ID>_result.json   # on success or handled failures
logs/maintenance_<CI_JOB_ID>_error.json    # on unhandled exception
```

---

## Step 2 — Generate a Pipeline Trigger Token

The Pipeline Trigger Token authenticates pipeline launches from external systems.

1. In GitLab, navigate to the project → **Settings > CI/CD > Pipeline triggers**
2. Click **Add trigger**
3. Give it a description (e.g., `iRequest-Link`)
4. Click **Save** and **copy the token** — it is displayed **once only**

> A **Project Access Token** (`api` scope) can be used interchangeably. Pipeline
> Trigger Tokens are simpler for bare POST-body webhooks; Project Access Tokens
> can also call non-trigger API endpoints.

Keep in a secure secret store (CyberArk, Vault, etc.). The token value is
required in both `Send-GitLabMaintenanceRequest.ps1` and any manual curl test.

---

## Step 3 — Triggering from iRequest

### REST endpoint

```
POST /api/v4/projects/{project_id}/trigger/pipeline
Content-Type: application/x-www-form-urlencoded

token=<trigger_token>&
ref=<branch>&
variables[ACTION]=enable&
variables[CLUSTER_ID]=Cluster-Prod-02&
variables[START]=2026-05-22T22:00:00Z&
variables[END]=2026-05-22T23:00:00Z&
…
```

The `project_id` is the numeric GitLab project ID, found at **Project Settings >
General > Advanced > Project ID**.

The `ref` parameter specifies the branch or tag the pipeline runs against
(`main` in most cases).

### PowerShell payload (iRequest PowerShell engine)

```powershell
$GitLabUrl    = "https://gitlab.your-company.local"
$ProjectId    = "1234"
$TriggerToken = "glptt-xxxxxxxxxxxxxxxxxxxxxxxxxx"

$Variables = @{
    ACTION     = "enable"
    CLUSTER_ID = "Cluster-Prod-02"
    START      = "2026-05-22T22:00:00Z"
    END        = "2026-05-22T23:00:00Z"
    CONFIG_DIR = "configs"
    DRY_RUN    = "false"
}

$Uri  = "$GitLabUrl/api/v4/projects/$ProjectId/trigger/pipeline"
$Body = @{
    token     = $TriggerToken
    ref       = "main"
    variables = $Variables
}
Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType 'application/x-www-form-urlencoded'
```

### curl payload (Linux-style webhook runner)

```bash
curl -X POST "https://gitlab.example.com/api/v4/projects/1234/trigger/pipeline" \
     --data-urlencode "token=glptt-xxxxxxxxxxxxxxxxxxxxxxxxxx" \
     --data-urlencode "ref=main" \
     --data-urlencode "variables[ACTION]=enable" \
     --data-urlencode "variables[CLUSTER_ID]=Cluster-Prod-02" \
     --data-urlencode "variables[START]=2026-05-22T22:00:00Z" \
     --data-urlencode "variables[END]=2026-05-22T23:00:00Z"
```

---

### PowerShell helper — `Send-GitLabMaintenanceRequest`

Instead of crafting the POST call directly, iRequest can call the pre-built
function in **`scripts/gitlab/Send-GitLabMaintenanceRequest.ps1`**.

```powershell
# Dot-source the module
. ./scripts/gitlab/Send-GitLabMaintenanceRequest.ps1

# Trigger a pipeline and wait for completion
Send-GitLabMaintenanceRequest `
    -Action         "enable" `
    -ClusterId      "PROD-CLUSTER-01" `
    -Start          "now" `
    -End            "2026-05-17 13:00" `
    -GitLabUrl      "https://gitlab.example.com" `
    -ProjectId      "12345" `
    -TriggerToken   "glptt-xxxxxxxxxxxx" `
    -GitRef         "main" `
    -JobToken       $env:GITLAB_JOB_TOKEN `
    -TimeoutSeconds 600
```

The function:

1. POSTs to `/trigger/pipeline` with the parameters encoded.
2. Optionally polls the pipeline status by ID (via the
   `Wait-GitLabMaintenanceResult` helper, using `GITLAB_JOB_TOKEN`).
3. Optionally sends a completion callback to `MAINTENANCE_CALLBACK_URL`.
4. Returns a result hashtable with `success`, `pipeline_id`, `web_url`, and
   `status`.

To run without blocking (fire-and-forget), pass `$null` for `-CallbackUrl`:

```powershell
Send-GitLabMaintenanceRequest -Action enable -ClusterId PROD-CLUSTER-01 -CallbackUrl $null
```

### Control-layer integration (recommended)

The `Run-GitLab` and `New-GitLabCtrl` send-cmdlets in the **Control module**
(`src/powershell/Automation/Control.psm1`) wrap `Send-GitLabMaintenanceRequest`
as another stop in the standard poller loop:

```powershell
Import-Module ./src/powershell/Automation/Control.psm1

# Factory pattern
$ctrl = New-GitLabCtrl -Params @{ ClusterId = 'PROD-CLUSTER-01'; Action = 'enable' }
$result = $ctrl | Run-GitLab
```

### Dry-run mode

Add `-DryRun` to any path (function call or trigger payload) to walk the
enable/disable path with real-time logs and audit records while skipping all
subsystem mutations.

```powershell
Send-GitLabMaintenanceRequest -Action enable -ClusterId 'PROD-CLUSTER-01' -DryRun
```

---

## Completion callbacks

When `MAINTENANCE_CALLBACK_URL` is set in the pipeline CI/CD variables,
`Invoke-GitLabMaintenance.ps1` POSTs JSON back to that URL on success **and**
on handled failure. `Send-GitLabMaintenanceRequest` does the same from the
caller side.

**Callback payload (POST JSON, `Content-Type: application/json`):**

```json
{
  "pipeline_id": 12345,
  "job_id": 5678,
  "cluster_id": "PROD-CLUSTER-01",
  "action": "enable",
  "success": true,
  "message": "Maintenance enable completed.",
  "timestamp": "2026-05-22T12:00:00Z"
}
```

For iRequest callbacks, set the `X-API-Key` header from
`MAINTENANCE_API_KEY`.

---

## Pipeline status polling via the GitLab API

Directly query a pipeline without callbacks using the GitLab Pipelines API
(GitLab ≥ 12.3).

```powershell
# Requires a job token (CI_JOB_TOKEN) scoped to the pipeline/project
$Headers = @{ "JOB-TOKEN" = "$JobToken" }
Invoke-RestMethod `
    -Uri  "https://gitlab.example.com/api/v4/projects/$ProjectId/pipelines/$PipelineId" `
    -Method Get `
    -Headers $Headers
```

Response body:

```json
{
  "id": 5678,
  "status": "success",
  "ref": "main",
  "sha": "a1b2c3d…",
  "web_url": "https://gitlab.example.com/org/repo/-/pipelines/5678",
  "created_at": "2026-05-22T11:55:00Z",
  "updated_at": "2026-05-22T12:05:42Z"
}
```

Status values: `created`, `waiting_for_resource`, `preparing`, `pending`,
`running`, `success`, `failed`, `canceled`, `skipped`, `manual`.

---

## Cluster configuration

Cluster definitions live in `configs/clusters_catalogue.json`:

```json
{
  "clusters": {
    "PROD-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "scom_group": "Prod-Servers-Group",
      "environment": "production",
      "servers": ["web01", "web02", "db01"],
      "ilo_addresses": { "web01": "10.0.1.10", "web02": "10.0.1.11" },
      "openview_node_ids": { "web01": "ov-001", "web02": "ov-002" }
    }
  }
}
```

Maintenance scripts resolve the `CLUSTER_ID` against this catalogue before
making any subsystem calls.

---

## Comparison with legacy CI systems

| Aspect | Legacy CI | GitLab |
|---|---|---|
| Config | Legacy CI file / Web UI | `.gitlab-ci.yml` (code-in-git) |
| Auth | Basic Auth header (username + API token) | Token in POST body (`token=`) |
| Trigger endpoint | `/job/{name}/buildWithParameters` | `/api/v4/projects/{id}/trigger/pipeline` |
| Parameters | `-d key=value` form body | `variables[key]=value` form body |
| Branch selection | Per-job web config | `ref=` in trigger payload |
| Commit tracking | Last-successful hash | Full git SHA in pipeline record |
| Audit trail | build log | GitLab Audit Events + pipeline history |

---

## Network requirements

| Direction | Description |
|---|---|
| **iRequest → GitLab (TCP 443)** | iRequest / webhook runner must reach the GitLab HTTPS API URL |
| **GitLab Runner → GitLab (TCP 443)** | Runners fetch source and submit job results |
| **Runner → targets (WinRM 5985/5986, HTTPS 443)** | Runner must reach servers for SCOM, iLO, OpenView |

If the GitLab instance uses a self-signed internal CA, the runner must trust
that CA or be configured to skip certificate validation (`-SkipCertificateCheck`
in PowerShell, `--insecure` in curl).

---

## Error reference — callers

| Symptom | Cause | Action |
|---|---|---|
| `404 Not Found` on trigger URL | Wrong project ID or API path | Verify dashboard URL and project settings |
| `401 Unauthorized` | Token missing / expired / regenerated | Regenerate trigger token, update iRequest config |
| `403 Forbidden` | Token lacks `pipelines:create` scope | Create new trigger token or PAT with `api` scope |
| `400 Bad Request` / empty pipeline | Missing `ref` parameter | Ensure `ref=main` (or target branch) is in the POST body |
| `Certificate` / `SSL` error (runner) | Self-signed or wrong CA on runner | Add CA to runner trust store or pass `--insecure` |
| Pipeline `failed` without clear cause | Script error in runner | Check pipeline job log in GitLab UI or via API |
| `Maintenance failed: Unauthorized` (SCOM) | Runner service account missing SCOM rights | Verify the runner service account has `OperationsManager` admin in the SCOM management group |
