# Audit Process Documentation

## Table of Contents

- [Overview](#overview)
- [Audit Trail Structure](#audit-trail-structure)
  - [Log Files](#log-files)
- [What Gets Audited?](#what-gets-audited)
- [Audit Entry Format (Structured JSON)](#audit-entry-format-structured-json)
- [Log Retention](#log-retention)
- [Audit Report Generation](#audit-report-generation)
  - [Daily Summary Report](#daily-summary-report)
  - [Weekly Compliance Report](#weekly-compliance-report)
  - [Monthly Audit Summary](#monthly-audit-summary)
- [Accessing Audit Data](#accessing-audit-data)
  - [Local Development](#local-development)
  - [OpsRamp Dashboards](#opsramp-dashboards)
  - [GitHub Actions UI](#github-actions-ui)
- [Audit Integrity](#audit-integrity)
  - [Tamper Protection](#tamper-protection)
  - [Data Integrity Verification](#data-integrity-verification)
  - [Audit Log Rotation](#audit-log-rotation)
- [Compliance and Governance](#compliance-and-governance)
  - [Regulatory Alignment](#regulatory-alignment)
  - [Access Controls](#access-controls)
  - [Anomaly Detection](#anomaly-detection)
- [Troubleshooting with Audit Data](#troubleshooting-with-audit-data)
  - [Scenario: Build Failed for Server X](#scenario-build-failed-for-server-x)
  - [Scenario: Installation Stuck at 60%](#scenario-installation-stuck-at-60)
  - [Scenario: Vulnerability Found Post-Install](#scenario-vulnerability-found-post-install)
  - [Scenario: Maintenance Window Did Not Auto-Disable](#scenario-maintenance-window-did-not-auto-disable)
- [Best Practices](#best-practices)
- [Appendix: Log File Schemas](#appendix-log-file-schemas)
  - [maintenance_audit.log (line-delimited JSON)](#maintenance_auditlog-line-delimited-json)
  - [build_result_*.json](#build_result_json)
  - [monitor_*.json](#monitor_json)
  - [maintenance_<action>_<cluster>_<timestamp>.json](#maintenance_action_cluster_timestampjson)
- [Change History](#change-history)


<a id="top"></a>
<a name="overview"></a>
## Overview

This document describes the comprehensive audit process for the HPE ProLiant Windows Server ISO Automation pipeline. Every action is logged, timestamped, and stored for compliance, troubleshooting, and reporting.

All scripts use the centralized **`AuditLogger`** class for audit logging. Audit logs are written to both per-action files and a master line-delimited JSON log.

<a name="audit-trail-structure"></a>
## Audit Trail Structure

<a name="log-files"></a>
### Log Files

**Master Audit Log**
- Location: `generated/logs/audit/audit_trail.log` (legacy text format, retained for backward compatibility)
- Location: `generated/logs/audit/maintenance_audit.log` (new structured JSON, one object per line)
- Content: All actions across all scripts (build, deploy, monitor, scan, maintenance)
- Rotation: Daily rollover with compressed archives

**Build Result Files**
- Location: `output/results/build_result_<server>_<timestamp>.json`
- Per-server, per-build JSON records with complete step-by-step log
- Includes: UUID, ISO paths, timestamps, success/failure status, step details

**Maintenance-Specific Audit**
- Location: `generated/logs/audit/maintenance_<action>_<cluster>_<timestamp>.json`
- Each maintenance_run creates a detailed JSON record with per-system results
- Aggregated into `generated/logs/audit/maintenance_audit.log` (line-delimited JSON) for centralized querying

**Workflow Logs**
- GitHub Actions: Uploaded as artifacts for each run
- Docker: Stdout captured in container logs
- Local runs: `logs/build_orchestrator.log`, `logs/monitoring.log`

**Deployment & Monitoring Sessions**
- `logs/monitoring_sessions/monitor_<server>_<timestamp>.json`
- Detailed per-check data: iLO status, WinRM progress, alerts sent

**Scan Reports**
- `logs/scan_reports/<target>_scan_<timestamp>.json`
- Vulnerability findings with CVE IDs, severity, remediation

<a name="what-gets-audited"></a>
## What Gets Audited?

Every script in this repository uses the `AuditLogger` class or `_log_step()` method to record:

1. **UUID Generation**
   - Server name, timestamp, generated UUID
   - Deterministic generation logic for reproducibility

2. **Firmware/Driver Builds**
   - Component downloads: HPE SUT commands, component names, versions, checksums
   - ISO creation: Output path, size, label, SPP version
   - Warnings: Missing components, download failures, SUT errors

3. **Windows Patching**
   - Base ISO path, mount/extract method
   - Patches applied: KB numbers, order, success/failure per patch
   - DISM/PowerShell commands executed
   - ISO creation: new ISO path, size, compression ratio

4. **Deployment**
   - Target server, deployment method (iLO/Redfish)
   - iLO connection: IP, credentials check, virtual media mount status
   - Deployment outcome: success, failure, error message

5. **Monitoring**
   - Installation start/end times
   - iLO status checks: power state, boot source (timestamped)
   - WinRM progress checks: phase, percent complete (timestamped)
   - Alerts sent: OpsRamp alert IDs, severity

6. **Vulnerability Scanning**
   - Scan target (ISO or server), scanner tool used
   - Findings: CVE count by severity, specific CVEs, false positives
   - Reports generated: paths to JSON/HTML reports

7. **OpsRamp Integration**
   - Metrics sent: metric name, value, timestamp, resource ID
   - Alerts sent: alert type, severity, message
   - Events: event type, properties
   - API responses: status codes, acknowledgment IDs

8. **Maintenance Mode Operations** (new)
   - Cluster ID, action (enable/disable/validate), dry-run flag
    - Per-system results: SCOM status, iLO window creation, OneView status, email sent, OpsRamp metrics
   - Scheduled task creation/removal
   - Start/end timestamps and computed duration

<a name="audit-entry-format-structured-json"></a>
## Audit Entry Format (Structured JSON)

Each audit entry (from `AuditLogger`) includes:

```json
{
  "timestamp": "2025-11-14T10:30:45.123456",
  "action": "build_firmware_iso",
  "status": "SUCCESS",
  "server": "server1.example.com",
  "details": {
    "iso_path": "output/firmware/server1.iso",
    "size_mb": 1420,
    "spp_version": "November 2025",
    "duration_seconds": 245
  }
}
```

For maintenance operations, the record is more comprehensive:

```json
{
  "timestamp": "2025-11-14T22:00:00",
  "action": "maintenance_enable",
  "cluster_id": "CLU-CLUSTER-01",
  "dry_run": false,
  "start_time": "2025-11-14T22:00:00",
  "end_time": "2025-11-15T08:00:00",
  "systems": {
    "scom": {"success": true, "servers": ["web01", "web02", "db01"]},
    "ilo": {"success": true, "windows_created": 3},
    "oneview": {"success": false, "error": "API endpoint unreachable"},
    "email": {"success": true, "recipients": 5},
    "opsramp": {"success": true, "metrics_sent": 9}
  },
  "scheduled_task": "MaintenanceDisable-CLU-CLUSTER-01",
  "exit_code": 0
}
```

<a name="log-retention"></a>
## Log Retention

- **Daily logs**: `logs/` directory (30 days retention)
- **GitHub Actions artifacts**:
  - ISOs: 30 days
  - Build logs: 7 days
  - Scan reports: 30 days
- **Database/External**: OpsRamp retains metrics/alerts per organizational policy
- **Archive**: Monthly ZIP archives moved to `logs/archive/`

<a name="audit-report-generation"></a>
## Audit Report Generation

<a name="daily-summary-report"></a>
### Daily Summary Report
Generated at midnight (or next build):
- Server: name, UUID, build timestamp
- ISO versions: firmware, Windows patch level
- Installation: duration, success/failure, final status
- Errors: list of any errors encountered with step context
- Performance: build duration, download times

<a name="weekly-compliance-report"></a>
### Weekly Compliance Report
- All servers audited
- Patch levels vs. baseline (November 2025 expected)
- Outstanding vulnerabilities: CVE IDs, severity, age
- Failed builds: servers with repeated failures, root cause analysis
- OpsRamp metrics trend: build success rate, installation success rate
- Scan compliance: % servers with critical vulnerabilities = 0

<a name="monthly-audit-summary"></a>
### Monthly Audit Summary
- Trend analysis: build times, failure rates
- Infrastructure health: iLO connectivity, WinRM accessibility
- License compliance: HPE SUT usage, Windows licensing
- Recommendations: upgrade firmware, patch cycles, server decommission

<a name="accessing-audit-data"></a>
## Accessing Audit Data

<a name="local-development"></a>
### Local Development
```bash
# Tail live structured audit log (new format, JSON per line)
tail -f generated/logs/audit/maintenance_audit.log | jq .

# Search for cluster-specific maintenance entries
grep "CLU-CLUSTER-01" generated/logs/audit/maintenance_audit.log | jq 'select(.cluster_id == "CLU-CLUSTER-01")'

# View latest maintenance action
jq -s 'last' <(cat generated/logs/audit/maintenance_*.json)

# View legacy text audit log
tail -f generated/logs/audit/audit_trail.log

# View structured build result
cat output/results/build_result_server1_20251114_103045.json | jq .

# Review monitoring session
cat logs/monitoring_sessions/monitor_server1_*.json | jq '.ilo_events[]'
```

<a name="opsramp-dashboards"></a>
### OpsRamp Dashboards
- **Build Dashboard**: Build status (success/failure), duration, server count
- **Deployment Dashboard**: Deployment progress, installation status, iLO health
- **Security Dashboard**: Vulnerability counts by severity, patch compliance
- **Audit Dashboard**: Timeline view of all actions, filtered by server/date

<a name="github-actions-ui"></a>
### GitHub Actions UI
- Workflow runs: "Actions" tab on repository
- Artifacts: Download logs and ISOs from each run
- Status badges: README can display last build status, build duration

<a name="audit-integrity"></a>
## Audit Integrity

<a name="tamper-protection"></a>
### Tamper Protection
- Git commits for build results (immutable once pushed)
- Serialized JSON logs (parseable, not easily human-altered without detection)
- Checksums for generated ISOs (SHA256 stored in build logs)
- Digital signatures for compliance reports (GPG/PGP optional)

<a name="data-integrity-verification"></a>
### Data Integrity Verification
```bash
# Verify ISO checksum matches recorded value
sha256sum output/firmware/server1_20251114.iso
# Compare with value in build_result_*.json
```

<a name="audit-log-rotation"></a>
### Audit Log Rotation
```
audit_trail.log        # Current day's log (text)
audit_trail.log.1     # Previous day
audit_trail.log.2.gz  # 2 days ago (compressed)
maintenance_audit.log # Structured JSON (current)
maintenance_audit.log.1 # Rotated
...
```

Cron job (or scheduled task) handles rotation:
```bash
# Rotate logs older than 30 days to archive
find generated/logs/audit/ -name "*.log.*" -mtime +30 -exec mv {} generated/logs/archive/ \;
```

<a name="compliance-and-governance"></a>
## Compliance and Governance

<a name="regulatory-alignment"></a>
### Regulatory Alignment
- **SOX**: Full audit trail for change management (structured JSON, immutable)
- **PCI DSS**: Vulnerability scans and patch tracking with timestamps
- **HIPAA**: Access logs (who deployed what and when) with user context
- **GDPR**: Server identifiers (UUIDs) pseudonymized; no PII in logs

<a name="access-controls"></a>
### Access Controls
- Audit log files: restricted to administrators and auditors
- GitHub repository: read access for all engineers, write limited to automation account
- OpsRamp: RBAC (role-based access control) for dashboards and reports
- Secrets: stored in GitHub Secrets or vault (HashiCorp Vault, Azure Key Vault)

<a name="anomaly-detection"></a>
### Anomaly Detection
Monitor for:
- Multiple failed builds for same server in short period
- Deployments outside of approved change windows
- Unauthorized iLO access attempts (via WinRM/iLO logs)
- Unexpected metric spikes (CPU, memory) during installation

<a name="troubleshooting-with-audit-data"></a>
## Troubleshooting with Audit Data

<a name="scenario-build-failed-for-server-x"></a>
### Scenario: Build Failed for Server X
Steps:
1. Find latest `build_result_serverX_*.json` in `output/results/`
2. Check `steps` array for failed step name and error details
3. Correlate with `generated/logs/audit/maintenance_audit.log` entries for that timestamp
4. Review HPE SUT output (if available in logs)
5. Check network logs for HPE repository access

<a name="scenario-installation-stuck-at-60"></a>
### Scenario: Installation Stuck at 60%
Steps:
1. Find monitoring session: `logs/monitoring_sessions/monitor_serverX_*.json`
2. Review `winrm_progress` history for last known phase
3. Check `ilo_events` for power state changes or reboots
4. Correlate with OpsRamp alert history (was there an iLO connection loss?)
5. Check server console via iLO remote console for manual inspection

<a name="scenario-vulnerability-found-post-install"></a>
### Scenario: Vulnerability Found Post-Install
Steps:
1. Locate scan report: `logs/scan_reports/<server>_scan_<timestamp>.json`
2. Review `vulnerabilities` array for CVE IDs
3. Cross-reference with `configs/windows_patches.json` to see if patch missing
4. Verify patch actually installed (check `winrm_progress` from build time)
5. Determine if false positive or needs patch update to config

<a name="scenario-maintenance-window-did-not-auto-disable"></a>
### Scenario: Maintenance Window Did Not Auto-Disable
Steps:
1. Check `generated/logs/audit/maintenance_audit.log` for the enable action - look for `"scheduled_task"` field
2. Verify Windows Scheduled Task exists: `schtasks /Query /TN "MaintenanceDisable-<cluster>"`
3. Check task history: Event Viewer → Windows Logs → Task Scheduler
4. Review script exit code in task history; any errors logged to `generated/logs/audit/maintenance_audit.log`
5. Manually run disable via PowerShell or scheduled task invocation

<a name="best-practices"></a>
## Best Practices

1. **Never edit JSON logs directly** - use scripts for modifications
2. **Include context**: always log server name and UUID in multi-server operations
3. **Log at appropriate level**: DEBUG for verbose, INFO for normal, WARNING/ERROR for issues
4. **Preserve original logs**: archive, don't delete (for compliance)
5. **Automate report generation**: schedule weekly compliance email from OpsRamp
6. **Secure log transport**: use TLS for remote logging (syslog-ng, fluentd)
7. **Monitor log growth**: implement retention policies; archive old data to S3/Blob
8. **Query structured logs with `jq`**: leverage JSON format for filtering and aggregation

<a name="appendix-log-file-schemas"></a>
## Appendix: Log File Schemas

<a name="maintenance_auditlog-line-delimited-json"></a>
### maintenance_audit.log (line-delimited JSON)
```
{"timestamp":"...", "action":"maintenance_enable", "cluster_id":"...", "dry_run":false, ...}
{"timestamp":"...", "action":"maintenance_disable", "cluster_id":"...", ...}
```

<a name="build_result_json"></a>
### build_result_*.json
```json
{
  "server": "...",
  "uuid": "...",
  "firmware_iso": "path/to/iso",
  "generated/patched_iso": "path/to/iso",
  "combined_iso": "path/to/dir",
  "success": true/false,
  "timestamp": "...",
  "steps": [
    {"step": "generate_uuid", "uuid": "..."},
    {"step": "firmware_iso", "status": "success"},
    ...
  ]
}
```

<a name="monitor_json"></a>
### monitor_*.json
```json
{
  "server": "...",
  "start_time": "...",
  "status": "completed|failed|timeout",
  "progress_percent": 0-100,
  "current_phase": "Copying Files",
  "duration_seconds": 1234,
  "ilo_events": [
    {"timestamp":"...", "power_state":"On", "boot_source":"HDD"}
  ],
  "winrm_progress": [
    {"timestamp":"...", "setup_phase":2, "progress_percent":35}
  ],
  "alerts_sent": 2
}
```

<a name="maintenance_action_cluster_timestampjson"></a>
### maintenance_<action>_<cluster>_<timestamp>.json
```json
{
  "timestamp": "...",
  "action": "maintenance_enable",
  "cluster_id": "...",
  "dry_run": false,
  "start_time": "...",
  "end_time": "...",
  "systems": {
    "scom": {"success": true, "details": "..."},
    "ilo": {"success": true, "details": "..."},
    "oneview": {"success": false, "error": "..."},
    "email": {"success": true},
    "opsramp": {"success": true}
  },
  "scheduled_task": "MaintenanceDisable-CLU-CLUSTER-01",
  "exit_code": 0
}
```

<a name="change-history"></a>
## Change History

- 2026-05-15: Unified AuditLogger class across all scripts; added structured maintenance audit logs
