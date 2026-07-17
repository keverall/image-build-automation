---
source:  ./src/powershell/Automation/Public/Test-ScomMaintenanceConnectivity.ps1
generated: 2026-07-17 09:57 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Test-ScomMaintenanceConnectivity

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Original Comment-Based Help](#original-comment-based-help)


<a name="description"></a>
## Description

Phase 1: Network Ping - DNS resolution of the SCOM management server - TCP port probe (WinRM 5985/5986, or 5985/135 when not using WinRM) - Measures latency in milliseconds Phase 2: Authentication Connect - Prompts for username/password (or uses -Credential) - Loads the OperationsManager PowerShell module - Performs a full authentication (New-SCOMManagementGroupConnection) - Immediately disconnects (Remove-SCOMManagementGroupConnection) - No objects are modified SAFETY / COMPLIANCE (regulated EMIR environment): - On a live run, config files are NEVER read. The management server host is taken verbatim from -ManagementHost and only that server is contacted. Credentials are never taken from config - they are supplied via -Credential or entered interactively. - Config files (connection_hosts.json, scom_config.json) are read ONLY with -DryRun, for dry-run validation. Returns a structured hashtable with per-phase results and an overall Available boolean.

<a name="parameters"></a>
## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Environment` | 'Test' or 'Prod'. Informational for live runs. Host resolution from connection_hosts.json only happens with -JsonConfig AND -DryRun. |
| `-ManagementHost` | SCOM management server to connect to (server name or serial). REQUIRED for a live run. Used verbatim - no config/env fallback - so only the host you specify is ever contacted. |
| `-Credential` | PSCredential for the live connection (e.g. -Credential (Get-Credential)). If omitted on a live run, the command prompts interactively for username and password. Never read from config. |
| `-ConfigDir` | Directory containing configuration files (default: 'configs'). Only used with -DryRun. |
| `-PingTimeoutMs` | TCP connect timeout in milliseconds (default: 3000). |
| `-Json` | If set, outputs the result as a JSON string instead of formatted text. |
| `-JsonConfig` | Reads the SCOM management server from configs/connection_hosts.json. ONLY honoured together with -DryRun (config is for dry-run testing, never live runs). |
| `-DryRun` | Simulate connectivity without actual network calls. Returns mock data to verify configuration resolution. Config files may be read for validation. |

<a name="original-comment-based-help"></a>
## Original Comment-Based Help
```powershell
.SYNOPSIS
        SCOM-only network ping + authentication connectivity test.
        Read-only - safe during a change freeze.

    .DESCRIPTION
        Phase 1: Network Ping
          - DNS resolution of the SCOM management server
          - TCP port probe (WinRM 5985/5986, or 5985/135 when not using WinRM)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - Prompts for username/password (or uses -Credential)
          - Loads the OperationsManager PowerShell module
          - Performs a full authentication (New-SCOMManagementGroupConnection)
          - Immediately disconnects (Remove-SCOMManagementGroupConnection)
          - No objects are modified

        SAFETY / COMPLIANCE (regulated EMIR environment):
          - On a live run, config files are NEVER read. The management server host
            is taken verbatim from -ManagementHost and only that server is
            contacted. Credentials are never taken from config - they are supplied
            via -Credential or entered interactively.
          - Config files (connection_hosts.json, scom_config.json) are read
            ONLY with -DryRun, for dry-run validation.

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER Environment
        'Test' or 'Prod'. Informational for live runs. Host resolution from
        connection_hosts.json only happens with -JsonConfig AND -DryRun.

    .PARAMETER ManagementHost
        SCOM management server to connect to (server name or serial).
        REQUIRED for a live run. Used verbatim - no config/env fallback - so only
        the host you specify is ever contacted.

    .PARAMETER Credential
        PSCredential for the live connection (e.g. -Credential (Get-Credential)).
        If omitted on a live run, the command prompts interactively for username
        and password. Never read from config.

    .PARAMETER ConfigDir
        Directory containing configuration files (default: 'configs'). Only used
        with -DryRun.

    .PARAMETER PingTimeoutMs
        TCP connect timeout in milliseconds (default: 3000).

    .PARAMETER Json
        If set, outputs the result as a JSON string instead of formatted text.

    .PARAMETER JsonConfig
        Reads the SCOM management server from configs/connection_hosts.json. ONLY
        honoured together with -DryRun (config is for dry-run testing, never
        live runs).

    .PARAMETER DryRun
        Simulate connectivity without actual network calls. Returns mock data to
        verify configuration resolution. Config files may be read for validation.

    .RETURNS
        [hashtable] with keys:
          Available        [bool]   - overall pass/fail
          Mode             [string] - always 'scom'
          ManagementHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] - DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] - Connected, Disconnected, ModuleLoaded, Error
          Timestamp        [string]   - UTC ISO 8601
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
