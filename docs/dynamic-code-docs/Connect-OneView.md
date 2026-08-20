---
source:  ./src/powershell/Automation/Public/Connect-OneView.ps1
generated: 2026-08-19
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Connect-OneView

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

This is a connection-focused alias for Test-ServerConnectivity.  It validates network reachability and performs authentication in a single step, leaving an active OneView session available for subsequent commands (Get-OneViewServerList, Get-OneViewConnectionStatus, etc.). On a live run the appliance host is taken verbatim from -OneViewHost and credentials are entered interactively at the prompt.  Config files are never read during a live run. The OneView session persists for the remainder of the PowerShell session.  Use Disconnect-OneView to explicitly close it.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP address to connect to (server name or serial).  Required for a live (non-DryRun) connection.  Used verbatim - no config/env fallback. |
| `-DryRun` _(Aliases: -Dry)_ | Validate host resolution only - no authentication is attempted and no real connection is made.  Host is resolved from connection_hosts.json (Test environment by default).  Safe for testing code without touching an appliance.  Remove -DryRun when you are ready to connect and make changes. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable report. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Connect-OneView -OneViewHost oneview.example.com Connect to the OneView appliance oneview.example.com.  Credentials are prompted for interactively.
```

<a id="example-2"></a>

### Example 2

```powershell
Connect-OneView -DryRun Validate host resolution from config without connecting or making any changes.  Use this to test code safely.
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Connect to an HPE OneView appliance and establish a persistent session.

    .DESCRIPTION
        This is a connection-focused alias for Test-ServerConnectivity.  It
        validates network reachability and performs authentication in a single
        step, leaving an active OneView session available for subsequent
        commands (Get-OneViewServerList, Get-OneViewConnectionStatus, etc.).

        On a live run the appliance host is taken verbatim from -OneViewHost
        and credentials are entered interactively at the prompt.  Config files
        are never read during a live run.

        The OneView session persists for the remainder of the PowerShell
        session.  Use Disconnect-OneView to explicitly close it.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP address to connect to (server name
        or serial).  Required for a live (non-DryRun) connection.  Used
        verbatim - no config/env fallback.

    .PARAMETER DryRun
        Validate host resolution only - no authentication is attempted and
        no real connection is made.  Host is resolved from
        connection_hosts.json (Test environment by default).  Safe for
        testing code without touching an appliance.  Remove -DryRun when you
        are ready to connect and make changes.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of
        the human-readable report.

    .EXAMPLE
        Connect-OneView -OneViewHost oneview.example.com

        Connect to the OneView appliance oneview.example.com.  Credentials are
        prompted for interactively.

    .EXAMPLE
        Connect-OneView -DryRun

        Validate host resolution from config without connecting or making
        any changes.  Use this to test code safely.

    .OUTPUTS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys:
            Available        [bool]   - connectivity and auth both succeeded
            OneViewHost   [string] - the appliance contacted
            AuthConnect      [hashtable] - authentication details
            NetworkPing      [hashtable] - network probe results
            Message          [string] - human-readable status
            Timestamp        [string] - UTC ISO 8601
        With -Json, a JSON [string] representation of the same data.

    .NOTES
        This command is the counterpart to Disconnect-OneView.  Internally it
        delegates to Test-ServerConnectivity, so all network validation and
        session-establishment logic is shared.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
