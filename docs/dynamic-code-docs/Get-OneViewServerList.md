---
source:  ./src/powershell/Automation/Public/Get-OneViewServerList.ps1
generated: 2026-08-20
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Get-OneViewServerList

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

Queries GET /rest/server-hardware across all pages and returns a normalised list of servers (name, serial, model, power state, health, iLO IP, enclosure). Supports an optional -Filter to narrow the result by health, power state, or name (substring/wildcard match).

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP (e.g. oneview.ad.example.com). If omitted, the command checks for an existing HPEOneView module session (Connect-OVMgmt); when one is active it is reused, otherwise a clean "not connected" status is returned instead of prompting for a host. |
| `-Credential` _(Aliases: -Cred)_ | PSCredential for authentication. Preferred, non-interactive entry point (sourced from a secret store). Falls back to -OneViewUser/-OneViewPassword or an interactive prompt when omitted. Never read from config or environment. |
| `-OneViewUser` _(Aliases: -OVUser)_ | OneView username (used with -OneViewPassword). Never read from config or environment. |
| `-OneViewPassword` _(Aliases: -OVPwd)_ | OneView password (used with -OneViewUser). Never read from config or environment. |
| `-Port` | OneView HTTPS port (default 443). |
| `-SkipCertificateCheck` _(Aliases: -SkipCert)_ | Skip SSL certificate verification for the REST calls that fetch the list. Most OneView appliances in lab/test use a self-signed or internal-CA certificate, so the default is $true. Only relevant while a NEW connection is being established - when an active session is reused it has no effect. Set to $false only against an appliance presenting a fully trusted cert. |
| `-TimeoutSec` _(Aliases: -Timeout)_ | Per-call timeout (default 30 s) for each paginated REST request. Only relevant while a NEW connection is established or when fetching very large fleets over a slow link; the default is fine for normal use. |
| `-PageSize` _(Aliases: -Page)_ | Servers fetched per page (default 100, max 1000). |
| `-Filter` | Optional client-side filter. Matching is case-insensitive and, by default, a SUBSTRING match, so partial values still match (health:Critical matches "Critical", name:PROD matches "PROD-SRV-01"). The name/power/health values also accept PowerShell-style wildcards: health:<value>   e.g. health:Critical, health:*Warning* power:<value>     e.g. power:On, power:Off name:<value>     e.g. name:PROD (substring), name:PROD-* (wildcard), name:srv-0? (single-char wildcard) |
| `-MockResult` _(Aliases: -Mock)_ | Hashtable to return without making any HTTP calls. Used for tests. |
| `-DryRun` _(Aliases: -Dry)_ | Print the query without performing it. |
| `-PassThru` _(Aliases: -PT)_ | By default the command only prints a human-readable table to the terminal and emits NO object to the pipeline (so the console is not cluttered with a raw hashtable/json dump). Pass -PassThru to also return the structured [hashtable] (Success, Count, Servers, Error) for use by scripts or the module Router. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Get-OneViewServerList -OneViewHost 'oneview.ad.example.com'
```

<a id="example-2"></a>

### Example 2

```powershell
Get-OneViewServerList -OneViewHost 'oneview.ad.example.com' -Filter 'health:Critical'
```

<a id="example-3"></a>

### Example 3

```powershell
Get-OneViewServerList Runs without parameters: reuses an active OneView session if one exists (Connect-OneView), otherwise returns Success=$false with a "not connected" message instead of prompting for a host.
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        List all servers connected to HPE OneView.  Callable from the module Router.

    .DESCRIPTION
        Queries GET /rest/server-hardware across all pages and returns a normalised
        list of servers (name, serial, model, power state, health, iLO IP, enclosure).
        Supports an optional -Filter to narrow the result by health, power state, or
        name (substring/wildcard match).

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).
        If omitted, the command checks for an existing HPEOneView module
        session (Connect-OVMgmt); when one is active it is reused, otherwise a
        clean "not connected" status is returned instead of prompting for a host.

    .PARAMETER Credential
        PSCredential for authentication. Preferred, non-interactive entry point
        (sourced from a secret store). Falls back to -OneViewUser/-OneViewPassword
        or an interactive prompt when omitted. Never read from config or environment.

    .PARAMETER OneViewUser
        OneView username (used with -OneViewPassword). Never read from config or environment.

    .PARAMETER OneViewPassword
        OneView password (used with -OneViewUser). Never read from config or environment.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate verification for the REST calls that fetch the list.
        Most OneView appliances in lab/test use a self-signed or internal-CA
        certificate, so the default is $true. Only relevant while a NEW connection
        is being established - when an active session is reused it has no effect.
        Set to $false only against an appliance presenting a fully trusted cert.

    .PARAMETER TimeoutSec
        Per-call timeout (default 30 s) for each paginated REST request. Only
        relevant while a NEW connection is established or when fetching very
        large fleets over a slow link; the default is fine for normal use.

    .PARAMETER PageSize
        Servers fetched per page (default 100, max 1000).

    .PARAMETER Filter
        Optional client-side filter. Matching is case-insensitive and, by default,
        a SUBSTRING match, so partial values still match (health:Critical matches
        "Critical", name:PROD matches "PROD-SRV-01"). The name/power/health values
        also accept PowerShell-style wildcards:
          health:<value>   e.g. health:Critical, health:*Warning*
          power:<value>     e.g. power:On, power:Off
          name:<value>     e.g. name:PROD (substring), name:PROD-* (wildcard),
                            name:srv-0? (single-char wildcard)

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print the query without performing it.

    .PARAMETER PassThru
        By default the command only prints a human-readable table to the terminal
        and emits NO object to the pipeline (so the console is not cluttered with a
        raw hashtable/json dump). Pass -PassThru to also return the structured
        [hashtable] (Success, Count, Servers, Error) for use by scripts or the
        module Router.

    .RETURNS
        Nothing by default (table printed to host). With -PassThru, a [hashtable]
        with Success, Count, Servers (array of hashtables), Error.

    .EXAMPLE
        Get-OneViewServerList -OneViewHost 'oneview.ad.example.com'

    .EXAMPLE
        Get-OneViewServerList -OneViewHost 'oneview.ad.example.com' -Filter 'health:Critical'

    .EXAMPLE
        Get-OneViewServerList

        Runs without parameters: reuses an active OneView session if one exists
        (Connect-OneView), otherwise returns Success=$false with a "not connected"
        message instead of prompting for a host.
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
