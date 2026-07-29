# HPE OneView Commands

> Note: "OpenView" is the legacy HP product name; the current product used by this
> automation is **HPE OneView**. This document covers the OneView cmdlets exported
> by the Automation module.

<a id="top"></a>
## Table of Contents

- [Session Management](#session-management)
- [Version and Information](#version-and-information)
- [Server Queries](#server-queries)
- [Maintenance](#maintenance)
- [Quick Health Check](#quick-health-check)
- [Notes](#notes)

<a name="session-management"></a>
## Session Management

The module uses a persistent OneView session stored in `$global:ConnectedSessions`.
Cmdlets reuse the session automatically; disconnect when finished.

```powershell
# Check current connection status
Get-OneViewConnectionStatus

# Close the persistent OneView session
Disconnect-OneView
```

<a name="version-and-information"></a>
## Version and Information

```powershell
# Query the OneView appliance version
Get-OneViewVersion -OneViewHost oneview.ad.example.com
```

<a name="server-queries"></a>
## Server Queries

```powershell
# List server hardware known to the appliance
Get-OneViewServerList -OneViewHost oneview.ad.example.com

# Resolve a target server (name, serial, iLO IP, etc.)
Get-OneViewServerTarget -OneViewHost oneview.ad.example.com -ServerIdentifier MXQ1234567
```

<a name="maintenance"></a>
## Maintenance

```powershell
# Generate a OneView maintenance script
New-OneViewMaintenanceScript -Appliance oneview.ad.example.com -ScopeName MyScope -Operation enable

# Enable maintenance mode via OneView
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
```

<a name="quick-health-check"></a>
## Quick Health Check

```powershell
Get-OneViewConnectionStatus
Get-OneViewVersion -OneViewHost oneview.ad.example.com
```

<a name="notes"></a>
## Notes

- Appliance settings live in `configs/oneview_config.json`; server inventory in
  `configs/servers_catalogue.oneview.json`.
- Legacy "OpenView" naming may still appear in credential/config identifiers
  (e.g. `Get-OpenViewCredentials`); those names are kept for compatibility.
