---
source:  ./src/powershell/Automation/Public/Test-ServerConnectivity.ps1
generated: 2026-07-22 12:04 UTC
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Test-ServerConnectivity

<a id="top"></a>
## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Original Comment-Based Help](#original-comment-based-help)


<a name="description"></a>
## Description

Phase 1: Network Ping - DNS resolution of the OneView appliance - TCP port probe (HTTPS 443) - Measures latency in milliseconds Phase 2: Authentication Connect - Prompts for username/password (or uses -Credential) - Loads the HPE OneView PowerShell module - Performs a full authentication (Connect-OVMgmt) - Session persists for subsequent OneView commands - No objects are modified SAFETY / COMPLIANCE (regulated EMIR environment): - On a live run, config files are NEVER read. The appliance host is taken verbatim from -ManagementHost and only that appliance is contacted. Credentials are never taken from config - they are supplied via -Credential or entered interactively. - Config files (connection_hosts.json, oneview_config.json) are read ONLY with -DryRun, for dry-run validation. Returns a structured hashtable with per-phase results and an overall Available boolean.

<a name="parameters"></a>
## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Environment` | 'Test' or 'Prod'. Informational for live runs. Host resolution from connection_hosts.json only happens with -JsonConfig AND -DryRun. |
| `-ManagementHost` | OneView appliance to connect to (server name or serial). REQUIRED for a live run. Used verbatim - no config/env fallback - so only the host you specify is ever contacted. |
| `-Credential` | PSCredential for the live connection (e.g. -Credential (Get-Credential)). If omitted on a live run, the command prompts interactively for username and password. Never read from config. |
| `-ConfigDir` | Directory containing configuration files (default: 'configs'). Only used with -DryRun. |
| `-PingTimeoutMs` | TCP connect timeout in milliseconds (default: 3000). |
| `-Json` | If set, outputs the result as a JSON string instead of formatted text. |
| `-JsonConfig` | Reads the OneView appliance from configs/connection_hosts.json. ONLY honoured together with -DryRun (config is for dry-run testing, never live runs). |
| `-DryRun` | Simulate connectivity without actual network calls. Returns mock data to verify configuration resolution. Config files may be read for validation. |

<a name="original-comment-based-help"></a>
## Original Comment-Based Help
```powershell
.SYNOPSIS
        OneView-only network ping + authentication connectivity test.
        Read-only - safe during a change freeze.

    .DESCRIPTION
        Phase 1: Network Ping
          - DNS resolution of the OneView appliance
          - TCP port probe (HTTPS 443)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - Prompts for username/password (or uses -Credential)
          - Loads the HPE OneView PowerShell module
          - Performs a full authentication (Connect-OVMgmt)
          - Session persists for subsequent OneView commands
          - No objects are modified

        SAFETY / COMPLIANCE (regulated EMIR environment):
          - On a live run, config files are NEVER read. The appliance host is
            taken verbatim from -ManagementHost and only that appliance is
            contacted. Credentials are never taken from config - they are supplied
            via -Credential or entered interactively.
          - Config files (connection_hosts.json, oneview_config.json) are read
            ONLY with -DryRun, for dry-run validation.

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER Environment
        'Test' or 'Prod'. Informational for live runs. Host resolution from
        connection_hosts.json only happens with -JsonConfig AND -DryRun.

    .PARAMETER ManagementHost
        OneView appliance to connect to (server name or serial).
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
        Reads the OneView appliance from configs/connection_hosts.json. ONLY
        honoured together with -DryRun (config is for dry-run testing, never
        live runs).

    .PARAMETER DryRun
        Simulate connectivity without actual network calls. Returns mock data to
        verify configuration resolution. Config files may be read for validation.

    .RETURNS
        [hashtable] with keys:
          Available        [bool]   - overall pass/fail
          Mode             [string] - always 'oneview'
          ManagementHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] - DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] - Connected, ModuleLoaded, Error
          Timestamp        [string]   - UTC ISO 8601

    .NOTES
        The OneView session established by this command persists in the current
        PowerShell session. Use Disconnect-OneView to explicitly close the session
        when finished.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
