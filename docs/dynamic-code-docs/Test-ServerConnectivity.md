---
source:  ./src/powershell/Automation/Public/Test-ServerConnectivity.ps1
generated: 2026-08-20
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Test-ServerConnectivity

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

This command reports the connectivity of an HPE OneView appliance. It is a STATUS CHECK, not a connect command - it NEVER prompts for a host or credentials. * Run with NO parameters: reports the ACTIVE OneView connection (established by Connect-OneView). If nothing is connected it reports "not connected" and returns - no prompt. * Run with -OneViewHost <host>: checks THAT specific appliance only. Phase 1: Network Ping - DNS resolution of the OneView appliance - TCP port probe (HTTPS 443) - Measures latency in milliseconds Phase 2: Authentication Connect - If reusing the active session (no -OneViewHost, or -OneViewHost matches the connected appliance) the existing session is reused - no credentials are needed. - Otherwise credentials come from -Credential, ONEVIEW_USER / ONEVIEW_PASSWORD, or CyberArk. If none are available the auth phase is skipped with a clear message (no prompt). - Loads the HPE OneView PowerShell module and performs Connect-OVMgmt. - Session persists for subsequent OneView commands. - No objects are modified. To actually CONNECT to an appliance, use Connect-OneView -OneViewHost <host> (which prompts for credentials and establishes the session this command then reports on). SAFETY / COMPLIANCE (regulated EMIR environment): - On a live run, config files are NEVER read. The appliance host is taken verbatim from -OneViewHost (when supplied) and only that appliance is contacted. Credentials are never read from config. - Config files (connection_hosts.json, oneview_config.json) are read ONLY with -DryRun, for dry-run validation. Returns a structured hashtable with per-phase results and an overall Available boolean.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance to check (server name or serial). Optional. When OMITTED, the command reports the ACTIVE OneView connection (established by Connect-OneView) and never prompts. When supplied it is used verbatim - no config/env fallback - so only the host you specify is ever contacted. Credentials are not prompted for: the active session is reused when it matches, otherwise supply -Credential or configure ONEVIEW_USER / ONEVIEW_PASSWORD. |
| `-DryRun` _(Aliases: -Dry)_ | Simulate connectivity without actual network calls. Returns mock data to verify configuration resolution. Config files may be read for validation. |
| `-Json` | Emit the result as a JSON string on the success stream (for API integration / redirection) instead of the human-readable report. When omitted, the command writes a human-readable report to the host (terminal / transcript / logs) and does NOT dump a raw hashtable. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = Test-ServerConnectivity -PassThru`, for scripting. |

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        OneView-only network ping + authentication connectivity STATUS CHECK.
        Read-only - safe during a change freeze.

    .DESCRIPTION
        This command reports the connectivity of an HPE OneView appliance. It is
        a STATUS CHECK, not a connect command - it NEVER prompts for a host or
        credentials.

          * Run with NO parameters: reports the ACTIVE OneView connection
            (established by Connect-OneView). If nothing is connected it reports
            "not connected" and returns - no prompt.
          * Run with -OneViewHost <host>: checks THAT specific appliance only.

        Phase 1: Network Ping
          - DNS resolution of the OneView appliance
          - TCP port probe (HTTPS 443)
          - Measures latency in milliseconds

        Phase 2: Authentication Connect
          - If reusing the active session (no -OneViewHost, or -OneViewHost
            matches the connected appliance) the existing session is reused - no
            credentials are needed.
          - Otherwise credentials come from -Credential, ONEVIEW_USER /
            ONEVIEW_PASSWORD, or CyberArk. If none are available the auth phase is
            skipped with a clear message (no prompt).
          - Loads the HPE OneView PowerShell module and performs Connect-OVMgmt.
          - Session persists for subsequent OneView commands.
          - No objects are modified.

        To actually CONNECT to an appliance, use Connect-OneView -OneViewHost
        <host> (which prompts for credentials and establishes the session this
        command then reports on).

        SAFETY / COMPLIANCE (regulated EMIR environment):
          - On a live run, config files are NEVER read. The appliance host is
            taken verbatim from -OneViewHost (when supplied) and only that
            appliance is contacted. Credentials are never read from config.
          - Config files (connection_hosts.json, oneview_config.json) are read
            ONLY with -DryRun, for dry-run validation.

        Returns a structured hashtable with per-phase results and an overall
        Available boolean.

    .PARAMETER OneViewHost
        OneView appliance to check (server name or serial). Optional.

        When OMITTED, the command reports the ACTIVE OneView connection
        (established by Connect-OneView) and never prompts. When supplied it is
        used verbatim - no config/env fallback - so only the host you specify is
        ever contacted. Credentials are not prompted for: the active session is
        reused when it matches, otherwise supply -Credential or configure
        ONEVIEW_USER / ONEVIEW_PASSWORD.

    .PARAMETER DryRun
        Simulate connectivity without actual network calls. Returns mock data to
        verify configuration resolution. Config files may be read for validation.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Test-ServerConnectivity -PassThru`, for scripting.

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys:
          Available        [bool]   - overall pass/fail
          Mode             [string] - always 'oneview'
          OneViewHost   [string]
          Environment      [string]
          NetworkPing      [hashtable] - DnsResolved, IpAddress, TcpPortOpen, Port, LatencyMs, Error
          AuthConnect      [hashtable] - Connected, ModuleLoaded, Error
          Timestamp        [string]   - UTC ISO 8601
        With -Json, a JSON [string] representation of the same data.

    .NOTES
        The OneView session established by this command persists in the current
        session and can be reused by subsequent OneView commands (Get-OneViewServerList,
        Get-OneViewConnectionStatus, etc.). Use Disconnect-OneView to explicitly
        close the session when finished.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
