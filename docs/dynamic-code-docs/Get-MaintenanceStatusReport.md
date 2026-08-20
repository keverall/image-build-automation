---
source:  ./src/powershell/Automation/Public/Get-MaintenanceStatusReport.ps1
generated: 2026-08-20
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Get-MaintenanceStatusReport

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

Discovers clusters/groups and their member servers from the connected SCOM management group (live), then for each server collects: - SCOM maintenance mode state + active maintenance window (start/end) - HPE OneView maintenance mode state (linked per server by name/serial) - The cluster power schedule (from catalogue enrichment; SCOM has none) Live SCOM/OneView queries degrade gracefully to 'Unknown' when unreachable. In -DryRun / -IncludeLive:$false the catalogue is used as mock data only.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-ConfigDir` _(Aliases: -Cfg)_ | Configuration directory (default: <project-root>/configs). |
| `-Environment` _(Aliases: -Env)_ | Environment used to resolve management hosts (Test | Prod). Default: Prod, or $env:ENVIRONMENT when set. |
| `-ManagementHost` _(Aliases: -Host, -MgmtHost)_ | Override the SCOM management server. Otherwise resolved from connection_hosts.json or $env:MAINTENANCE_HOST. |
| `-OneViewHost` _(Aliases: -OVHost)_ | Override the HPE OneView appliance (may differ from the SCOM host). When omitted, resolved from connection_hosts.json, then falls back to -ManagementHost if that was supplied. |
| `-IncludeLive` _(Aliases: -Live)_ | Query live SCOM + OneView (default). Use -IncludeLive:$false for a catalogue-only mock report (no network calls) - used by tests. |
| `-Format` | Output format: Csv (default, written to -Path), Json, or Table (console). |
| `-Path` _(Aliases: -Out)_ | CSV output path. Defaults to generated/reports/MaintenanceStatusReport_<ts>.csv. |
| `-DryRun` _(Aliases: -Dry)_ | Alias for -IncludeLive:$false - catalogue-only mock report, no connections. |
| `-Json` | Emit the result rows as a JSON string on the success stream (for API integration / redirection) instead of the human-readable report. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [PSObject[]] result rows on the success stream. By default the command writes only the human-readable report (per -Format) and returns nothing, so the terminal/log never receives a truncated object dump. Capture the result into a variable, e.g. `$rows = Get-MaintenanceStatusReport -PassThru`, for scripting. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). When combined with -PassThru the report is suppressed but the objects are still returned. |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Get-MaintenanceStatusReport -Environment Prod
```

<a id="example-2"></a>

### Example 2

```powershell
Get-MaintenanceStatusReport -ManagementHost scom01.corp.local -OneViewHost oneview.corp.local
```

<a id="example-3"></a>

### Example 3

```powershell
Invoke-RoutedRequest -RequestType 'maintmode_status_report' -Params @{ Environment = 'Prod' }
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Generate a read-only status report linking SCOM and HPE OneView for clusters.

    .DESCRIPTION
        Discovers clusters/groups and their member servers from the connected SCOM
        management group (live), then for each server collects:
          - SCOM maintenance mode state + active maintenance window (start/end)
          - HPE OneView maintenance mode state (linked per server by name/serial)
          - The cluster power schedule (from catalogue enrichment; SCOM has none)
        Live SCOM/OneView queries degrade gracefully to 'Unknown' when unreachable.
        In -DryRun / -IncludeLive:$false the catalogue is used as mock data only.

    .PARAMETER ConfigDir
        Configuration directory (default: <project-root>/configs).

    .PARAMETER Environment
        Environment used to resolve management hosts (Test | Prod). Default: Prod,
        or $env:ENVIRONMENT when set.

    .PARAMETER ManagementHost
        Override the SCOM management server. Otherwise resolved from
        connection_hosts.json or $env:MAINTENANCE_HOST.

    .PARAMETER OneViewHost
        Override the HPE OneView appliance (may differ from the SCOM host). When
        omitted, resolved from connection_hosts.json, then falls back to
        -ManagementHost if that was supplied.

    .PARAMETER IncludeLive
        Query live SCOM + OneView (default). Use -IncludeLive:$false for a
        catalogue-only mock report (no network calls) - used by tests.

    .PARAMETER Format
        Output format: Csv (default, written to -Path), Json, or Table (console).

    .PARAMETER Path
        CSV output path. Defaults to generated/reports/MaintenanceStatusReport_<ts>.csv.

    .PARAMETER DryRun
        Alias for -IncludeLive:$false - catalogue-only mock report, no connections.

    .PARAMETER Json
        Emit the result rows as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.

    .PARAMETER PassThru
        Also return the structured [PSObject[]] result rows on the success stream.
        By default the command writes only the human-readable report (per -Format)
        and returns nothing, so the terminal/log never receives a truncated
        object dump. Capture the result into a variable, e.g.
        `$rows = Get-MaintenanceStatusReport -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself). When combined with -PassThru the report
        is suppressed but the objects are still returned.

    .OUTPUTS
        By default, nothing is returned on the success stream (the report is
        written to the host per -Format, or to a CSV file). With -PassThru, the
        [PSObject[]] result rows. With -Json, a JSON [string] of the same rows.

    .EXAMPLE
        Get-MaintenanceStatusReport -Environment Prod

    .EXAMPLE
        Get-MaintenanceStatusReport -ManagementHost scom01.corp.local -OneViewHost oneview.corp.local

    .EXAMPLE
        Invoke-RoutedRequest -RequestType 'maintmode_status_report' -Params @{ Environment = 'Prod' }
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
