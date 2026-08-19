---
source:  ./src/powershell/Automation/Public/Get-OneViewServerTarget.ps1
generated: 2026-08-19
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Get-OneViewServerTarget

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

Sends a query against the OneView /rest/server-hardware endpoint and returns a normalized hashtable describing the server.  Validates health (must be OK) and tolerates power state Off or On. STRICT SINGLE-SERVER: this command must resolve to exactly one server. A query that matches more than one server is a hard failure (Success=$false) rather than a warning - it never silently picks the first match, because it underpins destructive operations (ISO attach/deploy, reboot, OS build). Connection to the appliance is handled by the shared Resolve-OneViewSession helper (prompts for the host/credentials when needed) and the session persists; this command never disconnects.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname or IP (e.g. oneview.ad.example.com). |
| `-ServerIdentifier` _(Aliases: -SrvrId)_ | Server name, serial number, OneView resource name, iLO IP, or bay/enclosure positional id (e.g. "Enclosure1, Bay 3"). |
| `-IdentifierType` _(Aliases: -IdTyp)_ | Hint for the search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto. Default Auto attempts each in turn. |
| `-OneViewUser` _(Aliases: -OVUser)_ | OneView username (used with -OneViewPassword). Never read from config or environment. |
| `-OneViewPassword` _(Aliases: -OVPwd)_ | OneView password (used with -OneViewUser). Never read from config or environment. |
| `-Port` | OneView HTTPS port (default 443). |
| `-SkipCertificateCheck` _(Aliases: -SkipCert)_ | Skip SSL cert verification (default true). |
| `-TimeoutSec` _(Aliases: -Timeout)_ | Per-call timeout (default 30 s). |
| `-MockResult` _(Aliases: -Mock)_ | Hashtable to return without making any HTTP calls. Used for tests. |
| `-DryRun` _(Aliases: -Dry)_ | Print query without performing it. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'PROD-SERVER-01'
```

<a id="example-2"></a>

### Example 2

```powershell
Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Query HPE OneView to identify and validate a target server by various identifiers.
        Callable from the module Router.

    .DESCRIPTION
        Sends a query against the OneView /rest/server-hardware endpoint and returns
        a normalized hashtable describing the server.  Validates health (must be OK)
        and tolerates power state Off or On.

        STRICT SINGLE-SERVER: this command must resolve to exactly one server. A
        query that matches more than one server is a hard failure (Success=$false)
        rather than a warning - it never silently picks the first match, because it
        underpins destructive operations (ISO attach/deploy, reboot, OS build).
        Connection to the appliance is handled by the shared Resolve-OneViewSession
        helper (prompts for the host/credentials when needed) and the session
        persists; this command never disconnects.

    .PARAMETER OneViewHost
        OneView appliance hostname or IP (e.g. oneview.ad.example.com).

    .PARAMETER ServerIdentifier
        Server name, serial number, OneView resource name, iLO IP, or bay/enclosure
        positional id (e.g. "Enclosure1, Bay 3").

    .PARAMETER IdentifierType
        Hint for the search filter: Name, Serial, OneViewName, IloIp, EnclosureBay, Auto.
        Default Auto attempts each in turn.

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

    .PARAMETER MockResult
        Hashtable to return without making any HTTP calls. Used for tests.

    .PARAMETER DryRun
        Print query without performing it.

    .RETURNS
        [hashtable] with Success, Server, Details, Error.

    .EXAMPLE
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'PROD-SERVER-01'

    .EXAMPLE
        Get-OneViewServerTarget -OneViewHost 'oneview.ad.example.com' -ServerIdentifier 'MXQ1234567' -IdentifierType Serial
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
