---
source:  ./src/powershell/Automation/Public/Get-OneViewVersion.ps1
generated: 2026-09-01
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Get-OneViewVersion

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

Local checks (always performed): * Loaded HPEOneView.*/HPOneView.* modules in this session (name, version, path). * Installed HPEOneView.*/HPOneView.* modules on PSModulePath. * Compliance with the HPEOneView.1000-only policy, including the exact remediation command when a stray version (e.g. HPEOneView.860) is found. Appliance check (best effort): * If -OneViewHost is supplied, or an active session exists, queries GET /rest/version (unauthenticated) and reports currentVersion. This value comes from the appliance and is unrelated to the local module version.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` _(Aliases: -OVHost)_ | Optional appliance hostname/IP. Defaults to the active session's appliance when one exists. Skips the appliance probe when unresolved. |
| `-Port` | OneView HTTPS port (default 443). |
| `-SkipCertificateCheck` _(Aliases: -SkipCert)_ | Skip SSL cert verification (default true). |
| `-TimeoutSec` _(Aliases: -Timeout)_ | Appliance probe timeout (default 15 s). |
| `-Quiet` _(Aliases: -Q)_ | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). By default the command writes the report to the host and returns nothing on the success stream. |
| `-Json` | Emit the result as a JSON string on the success stream instead of the human-readable report. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = Get-OneViewVersion -PassThru`, for scripting. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Get-OneViewVersion Reports local module state and, if a session is active, the appliance version.
```

<a id="example-2"></a>

### Example 2

```powershell
Get-OneViewVersion -OneViewHost oneview.example.com
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Show the HPEOneView PowerShell module version(s) on this machine and,
        when reachable, the version reported by the OneView appliance.

    .DESCRIPTION
        Local checks (always performed):
          * Loaded HPEOneView.*/HPOneView.* modules in this session (name,
            version, path).
          * Installed HPEOneView.*/HPOneView.* modules on PSModulePath.
          * Compliance with the HPEOneView.1000-only policy, including the
            exact remediation command when a stray version (e.g. HPEOneView.860)
            is found.

        Appliance check (best effort):
          * If -OneViewHost is supplied, or an active session exists, queries
            GET /rest/version (unauthenticated) and reports currentVersion.
            This value comes from the appliance and is unrelated to the local
            module version.

    .PARAMETER OneViewHost
        Optional appliance hostname/IP. Defaults to the active session's
        appliance when one exists. Skips the appliance probe when unresolved.

    .PARAMETER Port
        OneView HTTPS port (default 443).

    .PARAMETER SkipCertificateCheck
        Skip SSL cert verification (default true).

    .PARAMETER TimeoutSec
        Appliance probe timeout (default 15 s).

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself). By default the command writes the report
        to the host and returns nothing on the success stream.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream. By
        default the command writes only the report and returns nothing, so the
        terminal/log never receives a truncated hashtable dump. Capture the
        result into a variable, e.g. `$r = Get-OneViewVersion -PassThru`, for
        scripting.

    .OUTPUTS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys Success, RequiredModule, Compliant, LoadedModules,
        InstalledModules, NonCompliantLoaded, NonCompliantInstalled, Appliance,
        ApplianceVersion, ApplianceReachable, Error. With -Json, a JSON [string]
        representation of the same data.

    .EXAMPLE
        Get-OneViewVersion

        Reports local module state and, if a session is active, the appliance version.

    .EXAMPLE
        Get-OneViewVersion -OneViewHost oneview.example.com
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
