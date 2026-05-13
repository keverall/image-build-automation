# Audit Process Documentation

## Overview

This document describes the comprehensive audit process for the HPE ProLiant Windows Server ISO Automation pipeline. Every action is logged, timestamped, and stored for compliance, troubleshooting, and reporting.

## Audit Trail Structure

### Log Files

**Master Audit Log**
- Location: `logs/audit_trail.log`
- Format: Human-readable text with timestamps
- Content: All actions across all scripts (build, deploy, monitor, scan)
- Rotation: Daily rollover with compressed archives

**Build Result Files**
- Location: `output/results/build_result_<server>_<timestamp>.json`
- Per-server, per-build JSON records with complete step-by-step log
- Includes: UUID, ISO paths, timestamps, success/failure status, step details

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

## What Gets Audited?

Every script in this repository uses the `_log_step()` or equivalent method to record:

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
   - Target server, deployment method (iLO/PXE/Redfish)
   - iLO connection: IP, credentials check, virtual media mount status
   - PXE configuration: TFTP path, boot files copied
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

## Audit Entry Format

Each audit entry includes:
- `timestamp`: ISO 8601 format (e.g., `2025-11-14T10:30:45.123456`)
- `action`: Action category (e.g., `build_start`, `download_patch`, `deploy_ilo`)
- `status`: One of `START`, `SUCCESS`, `FAILED`, `SKIP`, `ERROR`
- `server`: Server hostname (or `all` for batch operations)
- `details`: Human-readable description (command output, error message, results)

Example:
```json
{
  "timestamp": "2025-11-14T10:30:45.123456",
  "action": "apply_patches",
  "status": "SUCCESS",
  "server": "server1.example.com",
  "details": "Applied 5 patches via DISM (KB5041234, KB5041235, ...)"
}
```

## Log Retention

- **Daily logs**: `logs/` directory (30 days retention)
- **GitHub Actions artifacts**:
  - ISOs: 30 days
  - Build logs: 7 days
  - Scan reports: 30 days
- **Database/External**: OpsRamp retains metrics/alerts per organizational policy
- **Archive**: Monthly ZIP archives moved to `logs/archive/`

## Audit Report Generation

### Daily Summary Report
Generated at midnight (or next build):
- Server: name, UUID, build timestamp
- ISO versions: firmware, Windows patch level
- Installation: duration, success/failure, final status
- Errors: list of any errors encountered with step context
- Performance: build duration, download times

### Weekly Compliance Report
- All servers audited
- Patch levels vs. baseline (November 2025 expected)
- Outstanding vulnerabilities: CVE IDs, severity, age
- Failed builds: servers with repeated failures, root cause analysis
- OpsRamp metrics trend: build success rate, installation success rate
- Scan compliance: % servers with critical vulnerabilities = 0

### Monthly Audit Summary
- Trend analysis: build times, failure rates
- Infrastructure health: iLO connectivity, WinRM accessibility
- License compliance: HPE SUT usage, Windows licensing
- Recommendations: upgrade firmware, patch cycles, server decommission

## Accessing Audit Data

### Local Development
```bash
# Tail live audit log
tail -f logs/audit_trail.log

# Search for server-specific entries
grep "server1.example.com" logs/audit_trail.log

# View structured build result
cat output/results/build_result_server1_20251114_103045.json | jq .

# Review monitoring session
cat logs/monitoring_sessions/monitor_server1_*.json | jq '.ilo_events[]'
```

### OpsRamp Dashboards
- **Build Dashboard**: Build status (success/failure), duration, server count
- **Deployment Dashboard**: Deployment progress, installation status, iLO health
- **Security Dashboard**: Vulnerability counts by severity, patch compliance
- **Audit Dashboard**: Timeline view of all actions, filtered by server/date

### GitHub Actions UI
- Workflow runs: "Actions" tab on repository
- Artifacts: Download logs and ISOs from each run
- Status badges: README can display last build status, build duration

## Audit Integrity

### Tamper Protection
- Git commits for build results (immutable once pushed)
- Serialized JSON logs (parseable, not easily human-altered without detection)
- Checksums for generated ISOs (SHA256 stored in build logs)
- Digital signatures for compliance reports (GPG/PGP optional)

### Data Integrity Verification
```bash
# Verify ISO checksum matches recorded value
sha256sum output/firmware/server1_20251114.iso
# Compare with value in build_result_*.json
```

### Audit Log Rotation
```
audit_trail.log        # Current day's log
audit_trail.log.1     # Previous day
audit_trail.log.2.gz  # 2 days ago (compressed)
...
```

Cron job (or scheduled task) handles rotation:
```bash
# Rotate logs older than 30 days to archive
find logs/ -name "audit_trail.log.*" -mtime +30 -exec mv {} logs/archive/ \;
```

## Compliance and Governance

### Regulatory Alignment
- **SOX**: Full audit trail for change management
- **PCI DSS**: Vulnerability scans and patch tracking
- **HIPAA**: Access logs (who deployed what and when)
- **GDPR**: Server identifiers (UUIDs) pseudonymized; no PII in logs

### Access Controls
- Audit log files: restricted to administrators and auditors
- GitHub repository: read access for all engineers, write limited to automation account
- OpsRamp: RBAC (role-based access control) for dashboards and reports
- Secrets: stored in GitHub Secrets or vault (HashiCorp Vault, Azure Key Vault)

### Anomaly Detection
Monitor for:
- Multiple failed builds for same server in short period
- Deployments outside of approved change windows
- Unauthorized iLO access attempts (via WinRM/iLO logs)
- Unexpected metric spikes (CPU, memory) during installation

## Troubleshooting with Audit Data

### Scenario: Build Failed for Server X
Steps:
1. Find latest `build_result_serverX_*.json` in `output/results/`
2. Check `steps` array for failed step name and error details
3. Correlate with `audit_trail.log` entries for that timestamp
4. Review HPE SUT output (if available in logs)
5. Check network logs for HPE repository access

### Scenario: Installation Stuck at 60%
Steps:
1. Find monitoring session: `logs/monitoring_sessions/monitor_serverX_*.json`
2. Review `winrm_progress` history for last known phase
3. Check `ilo_events` for power state changes or reboots
4. Correlate with OpsRamp alert history (was there an iLO connection loss?)
5. Check server console via iLO remote console for manual inspection

### Scenario: Vulnerability Found Post-Install
Steps:
1. Locate scan report: `logs/scan_reports/<server>_scan_<timestamp>.json`
2. Review `vulnerabilities` array for CVE IDs
3. Cross-reference with `configs/windows_patches.json` to see if patch missing
4. Verify patch actually installed (check `winrm_progress` from build time)
5. Determine if false positive or needs patch update to config

## Best Practices

1. **Never edit JSON logs directly** - use scripts for modifications
2. **Include context**: always log server name and UUID in multi-server operations
3. **Log at appropriate level**: DEBUG for verbose, INFO for normal, WARNING/ERROR for issues
4. **Preserve original logs**: archive, don't delete (for compliance)
5. **Automate report generation**: schedule weekly compliance email from OpsRamp
6. **Secure log transport**: use TLS for remote logging (syslog-ng, fluentd)
7. **Monitor log growth**: implement retention policies; archive old data to S3/Blob

## Appendix: Log File Schemas

### audit_trail.log (line-delimited JSON)
```
{"timestamp":"...", "action":"...", "status":"...", "server":"...", "details":"..."}
{"timestamp":"...", "action":"...", "status":"...", "server":"...", "details":"..."}
```

### build_result_*.json
```json
{
  "server": "...",
  "uuid": "...",
  "firmware_iso": "path/to/iso",
  "patched_iso": "path/to/iso",
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

## Change History

- 2025-11-14: Initial audit process documentation