---
source:  ./src/powershell/Automation/Public/Get-OneViewConnectionStatus.ps1
generated: 2026-07-24 09:41 UTC
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


<a name="description"></a>
## Description

Performs two read-only checks against the OneView REST API: 1. Reachability - GET /rest/version (no auth) to confirm the appliance is online and responding. 2. Authentication - GET /rest/server-hardware (authenticated) to confirm the supplied credentials are valid. If -ServerIdentifier is supplied, the target server is also resolved and its power/health reported so you can see at a glance whether it is "connected".

<a name="parameters"></a>
## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` | OneView appliance hostname or IP (e.g. oneview.ad.example.com). If omitted, the command checks for an existing HPEOneView module session (Connect-OVMgmt) and uses that appliance automatically. |
| `-ServerIdentifier` | Optional server name, serial number, iLO IP or bay position to look up. |
| `-IdentifierType` | Hint for the server search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto. Default Auto attempts each in turn. |
| `-OneViewUser` | OneView username. Defaults to $env:ONEVIEW_USER. |
| `-OneViewPassword` | OneView password. Defaults to $env:ONEVIEW_PASSWORD. |
| `-Port` | OneView HTTPS port (default 443). |
| `-SkipCertificateCheck` | Skip SSL cert verification (default true). |
| `-TimeoutSec` | Per-call timeout (default 30 s). |
| `-IncludeServerCount` | Include the total number of servers managed by OneView. |
| `-MockResult` | Hashtable to return without making any HTTP calls. Used for tests. |
| `-DryRun` | Print the checks without performing them. |

<a name="examples"></a>
## Examples

<a name="example-1"></a>
### Example 1
```powershell
Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com'
```

<a name="example-2"></a>
### Example 2
```powershell
Get-OneViewConnectionStatus -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
```

<a name="example-3"></a>
### Example 3
```powershell
Get-OneViewConnectionStatus Uses an existing HPEOneView module session if available. Returns Connected=$false if no session is active.
```

<a name="original-comment-based-help"></a>
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
        OneView username. Defaults to $env:ONEVIEW_USER.

    .PARAMETER OneViewPassword
        OneView password. Defaults to $env:ONEVIEW_PASSWORD.

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

    .RETURNS
        [hashtable] with Success, Connected, Reachable, Authenticated, Appliance,
        Version, ServerCount (optional), Server (optional) and SessionSource
        ('HPEOneViewModule' when reusing an active session, 'Explicit' otherwise).

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
