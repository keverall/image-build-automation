# Logs Directory Structure

This directory contains all logs for the image-build-automation project, organized by purpose and retention requirements per DevOps best practices.

## Directory Structure

```
generated/logs/
├── audit/           # Regulatory/compliance logs (EMIR, GDPR, SOX)
│   ├── audit.log               # Main audit trail
│   ├── audit_trail.log         # Detailed audit events
│   └── maintenance_audit.log   # Maintenance operation audit
│
├── testing/         # Test/QA logs (generated during testing)
│   └── *_make-test-files.json  # Test output files (marked with suffix)
│
├── production/      # Operational logs (daily operations)
│   ├── maintenance.log
│   ├── monitoring.log
│   ├── windows_patcher.log
│   ├── firmware_updater.log
│   └── isoorchestrator_*.json
│
└── build_reports/   # Build artifact reports (optional)
```

## Naming Conventions

| Log Type | Directory | Pattern | Example |
|----------|-----------|---------|---------|
| Audit | `audit/` | `{action}_{cluster}_{timestamp}.json` | `enable_PROD-CLUSTER-01_1779785105.json` |
| Production | `production/` | `{logname}.log`, `{name}_{timestamp}.json` | `maintenance.log`, `isoorchestrator_1778803507.json` |
| Testing | `testing/` | `*_make-test-files.json` | `enable_UNIT-TEST-CLUSTER_1779787997_make-test-files.json` |

## Git Ignore Rules

All log files are ignored by git except `.gitkeep` files that preserve directory structure:
- `generated/logs/*` - ignored
- `generated/logs/*.gitkeep` - tracked

## Log Categories

### Audit Logs (`audit/`)
- **Retention**: Long-term (7+ years recommended)
- **Purpose**: Compliance with EMIR, GDPR, and other regulatory requirements
- **Content**: All maintenance mode operations, cluster changes, and system modifications
- **Note**: These logs must be preserved for audit trails and are often immutable

### Production Logs (`production/`)
- **Retention**: 90-365 days
- **Purpose**: Daily operational visibility and troubleshooting
- **Content**: Maintenance operations, monitoring data, patch operations, ISO builds

### Test Logs (`testing/`)
- **Retention**: Short-term (cleanup after test completion)
- **Purpose**: Development and QA testing
- **Naming**: Files are suffixed with `_make-test-files` for clarity
- **Note**: These are generated during automated testing and can be safely deleted

## DevOps Best Practices Applied

1. **Separation of Concerns**: Logs are separated by purpose (audit, production, testing)
2. **Clear Naming**: Test files are clearly marked with `_make-test-files` suffix
3. **Regulatory Compliance**: Audit logs are isolated in their own directory
4. **Retention Policy**: Directory structure supports different retention periods
5. **Git Ignore**: See "Git Ignore Rules" section above for exclusion patterns