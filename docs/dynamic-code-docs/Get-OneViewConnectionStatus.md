---
source:  ./src/powershell/Automation/Public/Get-OneViewConnectionStatus.ps1
generated: 2026-08-20
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Get-OneViewConnectionStatus

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

Performs two read-only checks against the OneView REST API: 1. Reachability - GET /rest/version (no auth) to confirm the appliance is online and responding. 2. Authentication - GET /rest/server-hardware (authenticated) to confirm the supplied credentials are valid. If -ServerIdentifier is supplied, the target server is also resolved and its power/health reported so you can see at a glance whether it is "connected". This command is a STATUS CHECK and NEVER prompts. Run with no parameters to report the ACTIVE OneView connection established by Connect-OneView (Get-OneViewActiveSession). Supply -OneViewHost to check a SPECIFIC appliance instead. To actually connect, use Connect-OneView -OneViewHost <host>.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP (e.g. oneview.ad.example.com). If omitted, the command checks for an existing HPEOneView module session (Connect-OVMgmt) and uses that appliance automatically. |
| `-ServerIdentifier` _(Aliases: -SrvrId)_ | Optional server name, serial number, iLO IP or bay position to look up. |
| `-IdentifierType` _(Aliases: -IdTyp)_ | Hint for the server search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto. Default Auto attempts each in turn. |
| `-OneViewUser` _(Aliases: -OVUser)_ | OneView username (used with -OneViewPassword). Never read from config or environment. |
| `-OneViewPassword` _(Aliases: -OVPwd)_ | OneView password (used with -OneViewUser). Never read from config or environment. |
| `-Port` | OneView HTTPS port (default 443). |
| `-SkipCertificateCheck` _(Aliases: -SkipCert)_ | Skip SSL cert verification (default true). |
| `-TimeoutSec` _(Aliases: -Timeout)_ | Per-call timeout (default 30 s). |
| `-IncludeServerCount` _(Aliases: -SrvrCount)_ | Include the total number of servers managed by OneView. |
| `-MockResult` _(Aliases: -Mock)_ | Hashtable to return without making any HTTP calls. Used for tests. |
| `-DryRun` _(Aliases: -Dry)_ | Print the checks without performing them. |
| `-PassThru` _(Aliases: -PT)_ | By default the command only prints a human-readable status summary to the terminal and emits NO object to the pipeline (so the console is not cluttered with a raw hashtable/json dump). Pass -PassThru to also return the structured [hashtable] for use by scripts or the module Router. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable status summary. |
| `-Quiet` | Suppress the human-readable status summary (use with -PassThru / -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com'
```

<a id="example-2"></a>

### Example 2

```powershell
Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
```

<a id="example-3"></a>

### Example 3

```powershell
Get-OneViewConnectionStatus Uses an existing HPEOneView module session if available. Returns Connected=$false if no session is active.
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Quickly check OneView appliance connectivity and (optionally) a server's
        connection status.  Callable from the module Router.

    .DESCRIPTION
        Performs two read-only checks against the OneView REST API:
           1. Reachability - GET /rest/version (no auth) to confirm the appliance
              is online and responding.
           2. Authentication - GET /rest/server-hardware (authenticated) to confirm
              the supplied credentials are valid.
        If -ServerIdentifier is supplied, the target server is also resolved and
        its power/health reported so you can see at a glance whether it is "connected".

        This command is a STATUS CHECK and NEVER prompts. Run with no parameters to
        report the ACTIVE OneView connection established by Connect-OneView
        (Get-OneViewActiveSession). Supply -OneViewHost to check a SPECIFIC appliance
        instead. To actually connect, use Connect-OneView -OneViewHost <host>.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).
        If omitted, the command checks for an existing HPEOneView module
        session (Connect-OVMgmt) and uses that appliance automatically.

    .PARAMETER ServerIdentifier
        Optional server name, serial number, iLO IP or bay position to look up.

    .PARAMETER IdentifierType
        Hint for the server search filter: Name, Serial, OneViewName, IloIp,
        EnclosureBay, Auto. Default Auto attempts each in turn.

    .PARAMETER OneViewUser
        OneView username (used with -OneViewPassword). Never read from config or environment.

    .PARAMETER OneViewPassword
        OneView password (used with -OneViewUser). Never read from config or environment.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER TimeoutSec
        Per-call timeout (default 30 s).

    .PARAMETER IncludeServerCount
        Include the total number of servers managed by OneView.

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print the checks without performing them.

    .PARAMETER PassThru
        By default the command only prints a human-readable status summary to the
        terminal and emits NO object to the pipeline (so the console is not cluttered
        with a raw hashtable/json dump). Pass -PassThru to also return the structured
        [hashtable] for use by scripts or the module Router.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable status summary.

    .PARAMETER Quiet
        Suppress the human-readable status summary (use with -PassThru / -Json when
        the caller handles display itself).

    .RETURNS
        Nothing by default (summary printed to host). With -PassThru, a [hashtable]
        with Success, Connected, Reachable, Authenticated, Appliance, Version
        (appliance OneView version, e.g. 8200 = 8.20), ServerCount (optional),
        Server (optional), SessionSource ('HPEOneViewModule' when reusing an active
        session, 'Explicit' otherwise), ModuleName (the HPEOneView PowerShell library
        that serves the call), ModuleVersion, ModuleSource, VersionCompliant (bool) and
        VersionWarning (optional, present only on a mismatch). With -Json, a JSON
        [string] representation of the same data.

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com'

    .EXAMPLE
        Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial

    .EXAMPLE
        Get-OneViewConnectionStatus

        Uses an existing HPEOneView module session if available. Returns
        Connected=$false if no session is active.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
