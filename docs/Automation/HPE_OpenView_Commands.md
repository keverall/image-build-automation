# HPE OneView Commands

<a id="top"></a>

## Table of Contents

- [1. Connection Lifecycle (run first)](#1-connection-lifecycle-run-first)
- [2. Server Queries (read-only)](#2-server-queries-read-only)
- [3. Build Parameter & Validation Checks (read-only)](#3-build-parameter--validation-checks-read-only)
- [4. ⚠ Destructive — ISO Installation & Maintenance](#4--destructive--iso-installation--maintenance)
- [5. Quick Health Check](#5-quick-health-check)
- [Notes](#notes)

> Note: "OpenView" is the legacy HP product name; the current product used by this
> automation is **HPE OneView**. This document covers the OneView cmdlets exported
> by the Automation module. Documented command surface matches
> [`automation_commands.md`](./automation_commands.md#top) and the test plan
> ([`AUTOMATION_TEST_PLAN.md`](./AUTOMATION_TEST_PLAN.md#top)).

<a id="1-connection-lifecycle-run-first"></a>

## 1. Connection Lifecycle (run first)

The module uses a persistent OneView session. Run the connection checks **first** —
every downstream command reuses the active session. A live connection cannot be
"re-connected" while already active: supplying a *different* `-OneViewHost` only
**warns** you to `Disconnect-OneView` first (it never drops the live session).

```powershell
# STATUS (never prompts): report the active connection, or check a specific host
Test-ServerConnectivity
Test-ServerConnectivity -OneViewHost oneview.ad.example.com

# CONNECT (prompts for credentials): establish the persistent session
Connect-OneView -OneViewHost oneview.ad.example.com
Connect-OneView -OneViewHost oneview.ad.example.com -Credential $cred   # non-interactive

# STATUS of the active session (reachability + auth + optional server count)
Get-OneViewConnectionStatus
Get-OneViewConnectionStatus -OneViewHost oneview.ad.example.com -IncludeServerCount
Get-OneViewConnectionStatus -OneViewHost oneview.ad.example.com -ServerIdentifier MXQ1234567

# DISCONNECT when finished (reconnect = Disconnect then Connect again)
Disconnect-OneView
Disconnect-OneView -Force        # suppress cleanup errors
```

> **Version / appliance info** is now read from `Get-OneViewConnectionStatus`
> (`Version`, and `ServerCount` with `-IncludeServerCount`). The standalone
> `Get-OneViewVersion` cmdlet is no longer part of the public surface.

<a id="2-server-queries-read-only"></a>

## 2. Server Queries (read-only)

```powershell
# List server hardware known to the appliance (reuses active session if connected)
Get-OneViewServerList -OneViewHost oneview.ad.example.com

# Narrow by health / power / maintenance mode / name (wildcards supported)
Get-OneViewServerList -OneViewHost oneview.ad.example.com -Filter 'health:Critical'
Get-OneViewServerList -OneViewHost oneview.ad.example.com -Filter 'maintenance:Yes'
Get-OneViewServerList -OneViewHost oneview.ad.example.com -Filter 'name:PROD-*'
Get-OneViewServerList -OneViewHost oneview.ad.example.com -Summary   # condensed view

# Resolve a single target server (name, serial, iLO IP, or bay)
Get-OneViewServerTarget -OneViewHost oneview.ad.example.com -ServerIdentifier MXQ1234567
Get-OneViewServerTarget -OneViewHost oneview.ad.example.com -ServerIdentifier MXQ1234567 -IdentifierType Serial
```

<a id="3-build-parameter--validation-checks-read-only"></a>

## 3. Build Parameter & Validation Checks (read-only)

These validate the target and media **without changing anything** — safe on a live
appliance. Run them before any build.

```powershell
# Validate an ISO / firmware path resolves to an iLO-mountable URL
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'
Test-BuildParams -BaseIsoPath 'cifs://fileserver/isos/WinSrv2025.iso' -DryRun

# Pre-build readiness checks (OneView / iLO / MP-DP / ISO URL)
Test-PreBuildValidation -ServerIdentifier srv01 -OneViewHost oneview.ad.example.com -IloIp 10.0.1.50

# Post-build validation (hostname / domain / OS / drivers / CM client)
Test-PostBuildValidation -Hostname srv01 -Domain corp.local

# Monitor an in-progress install (read-only observation)
Start-InstallMonitor -Server srv01
Start-InstallMonitor -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
```

<a id="4--destructive--iso-installation--maintenance"></a>

## 4. ⚠ Destructive — ISO Installation & Maintenance

> 🔴 These commands can **wipe, reinstall, reboot, or change maintenance state** of a
> production server. They are gated by `-GuardRail` (regex the resolved server name
> must match) and/or confirmation (`APPROVE` / `-Force` / `-Deploy`). Always `-DryRun`
> first, always inside an approved maintenance window, and evidence the run.

```powershell
# 4-eye review, then authorize the build (the ONLY build command)
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.ad.example.com `
    -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' -GuardRail 'srv01'      # review only
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' `
    -GuardRail 'srv01' -Deploy                                                    # authorize (alias -Execute)
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' `
    -GuardRail 'srv01' -DryRun                                                    # plan only, no action

# iLO Redfish — destructive actions require -Force; -DryRun prints only
Invoke-IloRedfish -Action MountAndBoot -IloIp 10.0.1.50 -IsoUrl 'https://artifacts/isos/WinSrv2025_v1.0.iso' -Force
Invoke-IloRedfish -Action Reset -IloIp 10.0.1.50 -Force

# Semi-destructive: change alerting/maintenance state of a live server (needs window)
Set-MaintenanceMode -Action enable  -Mode oneview -SerialNumber ABC123XYZ -Environment Test
Set-MaintenanceMode -Action disable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
```

> Non-destructive iLO actions `Status` and `Eject` are safe to run any time:
> `Invoke-IloRedfish -Action Status -IloIp 10.0.1.50`.

<a id="5-quick-health-check"></a>

## 5. Quick Health Check

```powershell
# 1) Is the session up? (never prompts)
Test-ServerConnectivity

# 2) Reachability + auth + appliance version + server count
Get-OneViewConnectionStatus -OneViewHost oneview.ad.example.com -IncludeServerCount

# 3) Fleet health / maintenance glance
Get-OneViewServerList -OneViewHost oneview.ad.example.com -Summary
```

<a id="notes"></a>

## Notes

- The OneView session persists in `$global:ConnectedSessions` after `Connect-OneView`
  and is reused by all OneView commands; only `Disconnect-OneView` closes it.
- Live (non-`-DryRun`) runs are driven **only** by parameters / interactive prompts.
  Config files, server lists, and environment-variable defaults are `-DryRun`-only
  helpers. **Credentials are never read from config, environment, or CyberArk** —
  enter them interactively when prompted.
- `Get-OneViewVersion` and `New-OneViewMaintenanceScript` are **no longer part of the
  public surface** (version is read from `Get-OneViewConnectionStatus`; maintenance
  scripting is handled by `Set-MaintenanceMode`). The SCOM maintenance scripts
  (`New-ScomConnection` / `New-ScomMaintenanceScript`) are also retired from the
  public surface.
- Legacy "OpenView" naming may still appear in some credential/config identifiers;
  those names are kept for compatibility only.
