# GitLab CI/CD Maintenance Mode Integration

This module enables iRequest to trigger maintenance mode operations on SCOM/HPE OneView/OpenView via GitLab CI/CD pipeline triggers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Option A: Direct GitLab Trigger (via iRequest)                                   │
│                                                                                 │
│  iRequest → Send-GitLabMaintenanceRequest.ps1 → GitLab Trigger API             │
│       → GitLab CI Pipeline → Invoke-GitLabMaintenance.ps1                        │
│       → Set-MaintenanceMode.ps1 → SCOM/OneView/OpenView                           │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│  Option B: Via Control Layer (Run-GitLab)                                         │
│                                                                                 │
│  Run-GitLab → Invoke-GitLabMaintenanceTrigger → Send-GitLabMaintenanceRequest   │
│       → GitLab CI Pipeline → Invoke-GitLabMaintenance.ps1                        │
│       → Set-MaintenanceMode.ps1                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Setup

### 1. Create GitLab Trigger Token

In GitLab project Settings → CI/CD → Pipeline triggers:
- Create a trigger token
- Note the token and project ID

### 2. Configure Environment Variables (iRequest side)

```powershell
$env:GITLAB_URL     = "https://gitlab.example.com"
$env:GITLAB_PROJECT_ID = "12345"
$env:GITLAB_TRIGGER_TOKEN = "glptt-xxxxxxxxxxxx"
```

### 3. GitLab CI Pipeline Setup

The `.gitlab-ci.yml` defines three pipeline jobs:
- `maintenance-enable` - Enable maintenance mode
- `maintenance-disable` - Disable maintenance mode  
- `maintenance-validate` - Validate cluster configuration

## Usage via Control Layer (Recommended)

The `Run-GitLab` cmdlet integrates with the Control module pattern:

```powershell
# Import Control module
Import-Module ./src/powershell/Automation/Control.psm1

# Trigger maintenance via GitLab CI
Run-GitLab -ClusterId 'PROD-CLUSTER-01' -Action 'enable' -Start 'now' -End '2026-05-17 13:00'
```

### Using Factory Pattern

```powershell
# Equivalent using factory pattern
$ctrl = New-GitLabCtrl -Params @{ ClusterId = 'PROD-CLUSTER-01'; Action = 'enable' }
$result = $ctrl | Run-GitLab
```

## Usage from iRequest (Direct)

### Enable Maintenance

```powershell
Import-Module ./src/powershell/Automation/Public/Send-GitLabMaintenanceRequest.ps1

Send-GitLabMaintenanceRequest -Action enable -ClusterId 'PROD-CLUSTER-01' -Start 'now' -End '2026-05-17 13:00'
```

### Disable Maintenance

```powershell
Send-GitLabMaintenanceRequest -Action disable -ClusterId 'PROD-CLUSTER-01'
```

### Validate Cluster

```powershell
Send-GitLabMaintenanceRequest -Action validate -ClusterId 'PROD-CLUSTER-01'
```

### Using Pipeline Variables Directly

You can also trigger via curl:

```bash
curl -X POST \
  -F token=glptt-xxxxxxxxxxxx \
  -F ref=main \
  -F "variables[ACTION]=enable" \
  -F "variables[CLUSTER_ID]=PROD-CLUSTER-01" \
  -F "variables[START]=now" \
  -F "variables[END]=2026-05-17 13:00" \
  https://gitlab.example.com/api/v4/projects/12345/trigger/pipeline
```

### GitLab CI Job (scripts/gitlab/Invoke-GitLabMaintenance.ps1)

The GitLab CI script is located in `scripts/gitlab/Invoke-GitLabMaintenance.ps1` and should be called with `-File`:

```bash
pwsh -File ./scripts/gitlab/Invoke-GitLabMaintenance.ps1 -ACTION "enable" -CLUSTER_ID "PROD-CLUSTER-01"

## Authorization

- GitLab trigger tokens authenticate the pipeline trigger
- GitLab audit logs track all pipeline executions (Admin → Monitoring → Audit Logs)
- The PowerShell `Set-MaintenanceMode` module handles SCOM/iLO/OpenView authentication via configured credential stores

## Artifacts & Results

Each GitLab job produces:
- `logs/maintenance_${CI_JOB_ID}_result.json` - Success result
- `logs/maintenance_${CI_JOB_ID}_error.json` - Error details (if failed)

Check pipeline status via API:
```bash
curl --header "JOB-TOKEN: $CI_JOB_TOKEN" "https://gitlab.example.com/api/v4/projects/$CI_PROJECT_ID/pipelines/$PIPELINE_ID"
```

## Dry Run Mode

Add `-DryRun` to test without making changes:

```powershell
Send-GitLabMaintenanceRequest -Action enable -ClusterId 'PROD-CLUSTER-01' -DryRun
```

## Response/Callback Mechanism

GitLab notifies iRequest via HTTP callback when maintenance completes:

### Callback Setup

1. Set in GitLab project CI/CD variables:
   - `MAINTENANCE_CALLBACK_URL` - Webhook endpoint in iRequest
   - `MAINTENANCE_API_KEY` - Optional authentication key

2. Callback payload (POST JSON):
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

### Poll for Results (Alternative to Callback)

Use `Wait-GitLabMaintenanceResult` to poll pipeline status:

```powershell
Import-Module ./src/powershell/Automation/Public/Send-GitLabMaintenanceRequest.ps1

$result = Send-GitLabMaintenanceRequest -Action enable -ClusterId 'PROD-CLUSTER-01' -CallbackUrl $null
# Or with polling:
$finalResult = Wait-GitLabMaintenanceResult -GitLabUrl $GitLabUrl -ProjectId $projectId -PipelineId $result.pipeline_id -JobToken $jobToken
```

## Configuration

Cluster definitions are stored in `configs/clusters_catalogue.json`:

```json
{
  "clusters": {
    "PROD-CLUSTER-01": {
      "display_name": "Production Cluster 01",
      "scom_group": "Prod-Servers-Group",
      "environment": "production",
      "servers": ["web01", "web02", "db01"],
      "ilo_addresses": {"web01": "10.0.1.10", "web02": "10.0.1.11"},
      "openview_node_ids": {"web01": "ov-001", "web02": "ov-002"}
    }
  }
}
```