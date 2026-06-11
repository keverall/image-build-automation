# Set-MaintenanceMode.ps1 Testing Commands

## Parameter Summary

The script supports both `-DryRun` and `-WhatIf` as equivalent parameters for simulation mode.

| Parameter | Type | Required | Description | Examples |
|-----------|------|----------|-------------|----------|
| `-Action` | string | No | 'enable', 'disable', or 'validate' (default: enable) | `-Action enable` |
| `-TargetId` | string | **Yes** | Cluster identifier or server name | `-TargetId PROD-CLUSTER-01` |
| `-Mode` | string | **Yes** | 'scom' or 'oneview' | `-Mode scom` |
| `-Environment` | string | No | 'Test' or 'Prod' (default: Prod from ENVIRONMENT env var) | `-Environment Test` |
| `-ScomHost` | string | No | Override SCOM management server | `-ScomHost scom-backup.local` |
| `-OneViewHost` | string | No | Override OneView appliance | `-OneViewHost ov-test.local` |
| `-Username` | string | No | Direct username (testing only, not recommended for prod) | `-Username admin` |
| `-PostDisableWaitSeconds` | int | No | Seconds to wait after SCOM disable (default: 120) | `-PostDisableWaitSeconds 60` |
| `-ConfigDir` | string | No | Configuration directory (default: configs) | `-ConfigDir ./configs` |
| `-Start` | string | No* | Start datetime (see formats below) | `-Start 'now'`, `-Start '2026-06-11 22:00'` |
| `-End` | string | No* | End datetime (see formats below) | `-End '+2hours'`, `-End '2026-06-12 02:00'` |
| `-DryRun` | switch | No | Simulate without making changes | `-DryRun` |
| `-WhatIf` | switch | No | Alias for -DryRun | `-WhatIf` |
| `-NoSchedule` | switch | No | Skip Windows Scheduled Task creation | `-NoSchedule` |
| `-Json` | switch | No | Output as JSON for API integration | `-Json` |

\* Required for `-Action enable`

### Date/Time Format Support

The `-Start` and `-End` parameters support multiple formats:

| Format Type | Syntax | Example | Notes |
|-------------|--------|---------|-------|
| Current time | `now` | `-Start 'now'` | Uses current UTC time |
| Relative offset | `+<number><unit>` | `-End '+2hours'` | Units: seconds, minutes, hours, days |
| Absolute (UTC) | `YYYY-MM-DD HH:MM` | `-End '2026-06-12 02:00'` | Assumed UTC unless specified |
| Absolute (ISO) | `YYYY-MM-DDTHH:MM:SS` | `-End '2026-06-12T02:00:00'` | ISO 8601 format |
| Culture-specific | `MM/DD/YYYY HH:MM` | `-End '06/12/2026 02:00'` | Depends on system locale |

#### Relative Time Units

- `seconds` or `second`: e.g., `+30seconds`, `+45second`
- `minutes` or `minute`: e.g., `+90minutes`, `+15minute`
- `hours` or `hour`: e.g., `+2hours`, `+1hour`
- `days` or `day`: e.g., `+7days`, `+1day`

## Environment-Based Host Selection

### New Parameters Explained

#### `-Environment` (Test|Prod)
Selects which environment's hosts to use from `connection_hosts.json`:
- **Test**: Uses test SCOM server and OneView appliance
- **Prod**: Uses production SCOM server and OneView appliance
- Falls back to `$env:ENVIRONMENT` if not specified
- Defaults to `Prod` if neither is set

#### `-ScomHost` / `-OneViewHost`
Override the host from environment config:
- Useful for backup servers or emergency scenarios
- Takes precedence over environment config
- Can also be set via env vars: `SCOM_HOST`, `ONEVIEW_HOST`

### Host Resolution Priority

**For SCOM:**
1. `-ScomHost` parameter (highest priority)
2. `$env:SCOM_OVERRIDE_HOST`
3. `$env:SCOM_HOST`
4. `connection_hosts.json` based on `-Environment`
5. Error if not configured

**For OneView:**
1. `-OneViewHost` parameter (highest priority)
2. `$env:ONEVIEW_OVERRIDE_HOST`
3. `$env:ONEVIEW_HOST`
4. `connection_hosts.json` based on `-Environment`
5. Error if not configured

### Credential Resolution Priority

**For Username:**
1. `-Username` parameter
2. `$env:SCOM_ADMIN_USER` (for SCOM mode)
3. `$env:ONEVIEW_USER` (for OneView mode)
4. Interactive prompt (if running interactively)
5. Error (if automated mode)

**For Password:**
1. `$env:SCOM_ADMIN_PASSWORD` (for SCOM mode)
2. `$env:ONEVIEW_PASSWORD` (for OneView mode)
3. Interactive secure prompt (masked input)
4. Error (if automated mode)

## SCOM Group Mode Behavior

When maintenance mode is enabled or disabled for SCOM (via `-Mode scom`), **ALL objects in the SCOM group** are affected — servers, network devices, cluster nodes, and the cluster server itself. This ensures complete alert suppression across the entire cluster.

After disabling SCOM maintenance mode, a configurable wait period (default 120 seconds) allows servers time to reboot, restart services, and stabilize before alerting resumes, preventing false alerts.

## Mode Behavior Summary

| Mode | SCOM | OneView | TargetId Required | Environment Support |
|------|------|---------|-------------------|---------------------|
| `scom` | Yes | No | Must be in `clusters_catalogue.json` | ✅ Yes |
| `oneview` | No | Yes | Resolved via OneView API | ✅ Yes |

## OneView Mode

When `-Mode oneview` is used:
- TargetId is resolved via the OneView API using `ResolveTarget()`
- OneView checks if the identifier matches a `ServerHardware` (single server) or a `Scope` (cluster/collection)
- If ServerHardware: maintenance mode is applied to that single server
- If Scope: maintenance mode is applied to all ServerHardware members within that scope
- Returns per-object status with ACK/NACK details matching SCOM response format

## Connection Validation

Before executing maintenance operations, the script now:
1. Tests connectivity to SCOM management server or OneView appliance
2. Validates credentials before attempting operations
3. Returns clear error messages if connection fails
4. Skips validation in `-DryRun` mode

## Testing Commands

### Environment-Based Testing

**1. Using Environment Parameter (Recommended):**

```powershell
# Test environment with automatic host selection
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+1hour' `
    -DryRun

# Production environment
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -DryRun
```

**2. With Host Override:**

```powershell
# Override SCOM host for specific environment
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ScomHost 'backup-scom.ad.example.com' `
    -Start 'now' `
    -End '+1hour'

# Override OneView host
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'my-server-01' `
    -Mode oneview `
    -Environment Test `
    -OneViewHost 'oneview-backup.test.local' `
    -Start 'now' `
    -End '+1hour'
```

**3. Using Environment Variables:**

```powershell
# Set environment variables
$env:ENVIRONMENT = "Test"
$env:SCOM_ADMIN_USER = "domain\testadmin"
$env:SCOM_ADMIN_PASSWORD = "test_password"

# Script will use Test environment hosts automatically
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Start 'now' `
    -End '+1hour'
```

### Date/Time Format Testing

**4. Relative Time Offsets:**

```powershell
# Various relative time formats
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+30minutes' `
    -DryRun

pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -DryRun

pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1day' `
    -DryRun
```

**5. Absolute Time Formats:**

```powershell
# Standard format (recommended)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00' `
    -DryRun

# ISO 8601 format
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11T22:00:00' `
    -End '2026-06-12T02:00:00' `
    -DryRun

# Mixed: relative start, absolute end
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '2026-06-12 02:00' `
    -DryRun
```

### SCOM Mode Testing

**6. SCOM Group Mode (All Objects):**

```powershell
# Enable maintenance for all objects in SCOM group
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours'

# Disable with default stabilization wait (120 seconds)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod

# Disable with custom wait period
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -PostDisableWaitSeconds 60

# Disable with no wait (immediate alerting)
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -PostDisableWaitSeconds 0
```

**7. SCOM with WhatIf:**

```powershell
# Using WhatIf alias instead of DryRun
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour' `
    -WhatIf
```

### OneView Mode Testing

**8. OneView Single Server:**

```powershell
# Enable maintenance on single server
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'my-server-01' `
    -Mode oneview `
    -Environment Test `
    -Start 'now' `
    -End '+1hour' `
    -DryRun

# Disable maintenance on single server
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action disable `
    -TargetId 'my-server-01' `
    -Mode oneview `
    -Environment Test `
    -DryRun
```

**9. OneView Scope (Cluster):**

```powershell
# Enable maintenance on all servers in scope
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'Production_Cluster_01' `
    -Mode oneview `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -DryRun
```

### Validation Testing

**10. Validate Configuration:**

```powershell
# Validate cluster configuration without making changes
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod

# Validate OneView target resolution
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'my-server-01' `
    -Mode oneview `
    -Environment Test
```

### Module Import Testing

**11. Using Module Import:**

```powershell
# Import module and use function directly
Import-Module ./src/powershell/Automation/Automation.psm1 -Force

# Test environment
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+30min' `
    -DryRun

# Production with host override
Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ScomHost 'backup-scom.local' `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00'

# Disable with stabilization wait
Set-MaintenanceMode `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -PostDisableWaitSeconds 60
```

### JSON Output Testing

**12. JSON Output for iRequest Integration:**

```powershell
# JSON output with environment selection
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -Json | ConvertFrom-Json

# Parse specific fields from JSON output
$result = pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour' `
    -Json | ConvertFrom-Json

Write-Host "Success: $($result.Success)"
Write-Host "SCOM Objects: $($result.ScomObjects.Count)"
Write-Host "Failed Objects: $($result.FailedObjects.Count)"
```

### Interactive Testing

**13. Interactive Credential Prompt:**

```powershell
# Don't set credentials - script will prompt you
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test

# Will prompt:
# Enter SCOM username: domain\admin
# Enter SCOM password: ******** (masked)
```

### Comprehensive Test Scenarios

**14. Full Maintenance Window (Enable → Wait → Disable):**

```powershell
# Step 1: Enable maintenance
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour'

# Step 2: Perform maintenance tasks here...
Write-Host "Performing maintenance..."

# Step 3: Disable with stabilization wait
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action disable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -PostDisableWaitSeconds 120
```

**15. Emergency Maintenance with Overrides:**

```powershell
# Use backup SCOM server for emergency maintenance
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ScomHost 'emergency-scom.ad.example.com' `
    -Start 'now' `
    -End '+4hours' `
    -NoSchedule
```

**16. Cross-Environment Testing:**

```powershell
# Test same operation in both environments
$environments = @('Test', 'Prod')

foreach ($env in $environments) {
    Write-Host "Testing $env environment..." -ForegroundColor Cyan
    
    pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
        -Action validate `
        -TargetId "$env-CLUSTER-01" `
        -Mode scom `
        -Environment $env `
        -DryRun
}
```

## Notes

- For SCOM mode, the script operates on **clusters** defined in `clusters_catalogue.json`. For OneView mode, it can target servers, scopes, or other object types resolved via the OneView API.
- **SCOM group mode**: ALL objects in the SCOM group (servers, network devices, cluster nodes, cluster server) are put into maintenance mode — not just cluster nodes.
- For "now" as the time parameter: `Start 'now'` works for start time; `End` must still be provided for enable action.
- Use `-DryRun` or `-WhatIf` first to validate configuration loading without making changes.
- **Post-disable wait**: After SCOM maintenance is disabled, servers need time to reboot and stabilize. The default 120-second wait prevents false alerts that support staff frequently report. Set `-PostDisableWaitSeconds 0` to skip.
- JSON output mode (`-Json`) is available for iRequest/REST API integration.
- **Environment parameter**: If not specified, reads from `$env:ENVIRONMENT`, defaults to `Prod`.
- **Connection validation**: Script tests connectivity before executing operations (unless `-DryRun`).
- **Credential security**: Never commit `.env` file with real passwords to git.

## Per-Object Status Reporting

When maintenance mode is enabled or disabled, the response includes **detailed per-object status** for every server, network device, cluster node, and cluster server in the SCOM group. This allows the iRequest CMDB to be accurately updated with the maintenance state of each individual object.

### Response Object Structure

Both JSON output (`-Json`) and the return hashtable contain these fields for iRequest integration:

| Field | Type | Description |
|-------|------|-------------|
| `Success` | bool | Overall operation success |
| `Message` | string | Human-readable completion message |
| `StartTimeUtc` | string | Maintenance window start time (ISO 8601) |
| `EndTimeUtc` | string | Maintenance window end time (ISO 8601) |
| `TargetId` | string | Original target identifier |
| `ClusterName` | string | Resolved cluster display name |
| `ServerCount` | int | Number of servers in target |
| `DryRun` | bool | Whether operation was simulated |
| `AuditFile` | string | Path to audit log file |
| `ScomObjects` | array | Array of SCOM objects with their maintenance status |
| `ScomSummary` | object | Aggregated SCOM counts |
| `OneViewObjects` | array | Array of OneView objects with their maintenance status |
| `OneViewSummary` | object | Aggregated OneView counts |
| `FailedObjects` | array | Filtered list of only failed objects with NACK details |

### Per-Object Object Structure

Each entry in `ScomObjects` contains:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Object display name (e.g., `srv01.corp.local`) |
| `Type` | string | SCOM class type (e.g., `WindowsComputer`, `WindowsCluster`) |
| `Action` | string | `enable` or `disable` |
| `Status` | string | `success`, `already_in_maintenance`, `not_in_maintenance`, or `failed` |
| `Message` | string | Human-readable status message |
| `NackReason` | string or null | Failure reason (only present for failed objects) |
| `Resolution` | string or null | Suggested fix for failures (only present for failed objects) |

### Common NACK Reasons

| NackReason | Resolution |
|------------|------------|
| Permission denied | Verify SCOM operator role permissions |
| SCOM agent unreachable | Verify SCOM agent is running and network connectivity |
| Object not found in SCOM | Verify object is monitored by SCOM |
| Agent not found in SCOM | Verify agent is installed and registered with SCOM |
| SCOM operation failed | Check SCOM management server logs |

### CLI Output Example

When running from command line, per-object status is displayed as a table:

```
=== SCOM Per-Object Status ===
Total Objects: 15
Success: 12
Already in Maintenance: 2
Failed: 1

[OK] srv01.corp.local (WindowsComputer) - success
[SKIP] srv02.corp.local (WindowsComputer) - already_in_maintenance
[FAIL] net-switch-01.corp.local (NetworkDevice) - failed
  NACK Reason: SCOM agent unreachable
  Resolution: Verify SCOM agent is running and network connectivity
===============================

=== NACK Summary (Failed Objects) ===
Total Failed: 1
  - net-switch-01.corp.local: SCOM agent unreachable
    Fix: Verify SCOM agent is running and network connectivity
===================================
```

### JSON Output Example (iRequest Integration)

```json
{
  "Success": false,
  "Message": "Maintenance enable finished with errors for cluster 'PROD-CLUSTER-01'",
  "StartTimeUtc": "2026-06-11T13:00:00Z",
  "EndTimeUtc": "2026-06-11T15:00:00Z",
  "TargetId": "PROD-CLUSTER-01",
  "ClusterName": "Production Cluster 01",
  "ServerCount": 3,
  "DryRun": false,
  "ScomObjects": [
    {
      "Name": "srv01.corp.local",
      "Type": "WindowsComputer",
      "Action": "enable",
      "Status": "success",
      "Message": "Maintenance mode enabled"
    },
    {
      "Name": "net-switch-01.corp.local",
      "Type": "NetworkDevice",
      "Action": "enable",
      "Status": "failed",
      "Message": "Access denied",
      "NackReason": "Permission denied",
      "Resolution": "Verify SCOM operator role permissions"
    }
  ],
  "ScomSummary": {
    "Total": 15,
    "Success": 12,
    "AlreadyInMaintenance": 2,
    "Failed": 1
  },
  "FailedObjects": [
    {
      "Name": "net-switch-01.corp.local",
      "Type": "NetworkDevice",
      "Action": "enable",
      "Status": "failed",
      "NackReason": "Permission denied",
      "Resolution": "Verify SCOM operator role permissions"
    }
  ]
}
```

### Testing Per-Object Reporting

```powershell
# Dry-run to see response structure without making changes
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour' `
    -DryRun `
    -Json | ConvertFrom-Json | Select-Object Success, ScomObjects, ScomSummary, FailedObjects

# Live run with JSON output for iRequest CMDB integration
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -Json

# Verify per-object status in module approach
Import-Module ./src/powershell/Automation/Automation.psm1 -Force
$result = Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour' `
    -DryRun

$result.ScomObjects | Format-Table Name, Type, Status, NackReason
$result.FailedObjects | ForEach-Object { Write-Host "$($_.Name): $($_.NackReason) -> $($_.Resolution)" }

# Test with different time formats
$result = Set-MaintenanceMode `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start '2026-06-11 22:00' `
    -End '2026-06-12 02:00'

Write-Host "Window: $($result.StartTimeUtc) to $($result.EndTimeUtc)"
```

## Quick Reference: Common Command Patterns

### Pattern 1: Standard Production Maintenance
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours'
```

### Pattern 2: Test with Validation First
```powershell
# Validate
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action validate `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test

# Execute
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'TEST-CLUSTER-01' `
    -Mode scom `
    -Environment Test `
    -Start 'now' `
    -End '+1hour'
```

### Pattern 3: Emergency with Host Override
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -ScomHost 'emergency-scom.local' `
    -Start 'now' `
    -End '+4hours' `
    -NoSchedule
```

### Pattern 4: OneView Single Server
```powershell
pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'server01.ad.example.com' `
    -Mode oneview `
    -Environment Prod `
    -Start 'now' `
    -End '+1hour'
```

### Pattern 5: Automated with JSON Output
```powershell
$result = pwsh -File ./src/powershell/Automation/Public/Set-MaintenanceMode.ps1 `
    -Action enable `
    -TargetId 'PROD-CLUSTER-01' `
    -Mode scom `
    -Environment Prod `
    -Start 'now' `
    -End '+2hours' `
    -Json | ConvertFrom-Json

if ($result.Success) {
    Write-Host "Maintenance enabled successfully"
} else {
    Write-Error "Failed: $($result.Error)"
}
```
