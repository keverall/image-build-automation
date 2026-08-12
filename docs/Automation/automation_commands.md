# Automation Command Reference

<a id="top"></a>

## Table of Contents

- [Setup (One-Time)](#setup-one-time)
- [Connectivity, Connection & Server Lookup](#connectivity-connection-server-lookup)
  - [Test OneView connectivity](#test-oneview-connectivity)
  - [Connect to OneView](#connect-to-oneview)
  - [Disconnect from OneView](#disconnect-from-oneview)
  - [Get OneView connection status](#get-oneview-connection-status)
  - [Get OneView server list](#get-oneview-server-list)
  - [Validate server list](#validate-server-list)
  - [Validate build parameters](#validate-build-parameters)
- [ISO Image Naming & SMB Shares](#iso-image-naming-smb-shares)
  - [Bootable ISO filename convention](#bootable-iso-filename-convention)
  - [ISO path requirements (no local drives)](#iso-path-requirements-no-local-drives)
- [Physical Server Build (End-to-End)](#physical-server-build-end-to-end)
  - [Configure build (4-eye review)](#configure-build-4-eye-review)
  - [Full build (most common)](#full-build-most-common)
  - [Dry run (validate without changing anything)](#dry-run-validate-without-changing-anything)
  - [Build with firmware folders (post-OS-install)](#build-with-firmware-folders-post-os-install)
  - [Re-run after ISO already built (skip build phases)](#re-run-after-iso-already-built-skip-build-phases)
  - [Re-run monitoring after deployment](#re-run-monitoring-after-deployment)
  - [Build with custom domain and post-build checks](#build-with-custom-domain-and-post-build-checks)
  - [Mock build (testing)](#mock-build-testing)
- [ISO Build, Deployment & Monitoring](#iso-build-deployment-monitoring)
  - [Build a bootable ISO](#build-a-bootable-iso)
  - [Publish a bootable ISO](#publish-a-bootable-iso)
  - [Deploy ISOs to servers](#deploy-isos-to-servers)
  - [Monitor installation progress](#monitor-installation-progress)
  - [iLO Redfish operations](#ilo-redfish-operations)
  - [Resolve server target via OneView](#resolve-server-target-via-oneview)
  - [Pre-build validation](#pre-build-validation)
  - [Post-build validation](#post-build-validation)
  - [Build firmware ISO](#build-firmware-iso)
  - [Patch Windows ISO with security updates](#patch-windows-iso-with-security-updates)
- [Maintenance Mode](#maintenance-mode)
  - [Examples](#examples)
- [PowerShell Execution and Utility](#powershell-execution-and-utility)
  - [Run a local PowerShell script](#run-a-local-powershell-script)
  - [Run a remote PowerShell script via WinRM](#run-a-remote-powershell-script-via-winrm)
  - [Generate a deterministic UUID](#generate-a-deterministic-uuid)
  - [OpsRamp API client](#opsramp-api-client)
- [Routing and Control Surfaces](#routing-and-control-surfaces)
  - [Orchestrator (unified entry point)](#orchestrator-unified-entry-point)
  - [View the route map](#view-the-route-map)
  - [Control surface factories and runners](#control-surface-factories-and-runners)
  - [GitLab maintenance trigger](#gitlab-maintenance-trigger)
- [Functional Test Harnesses](#functional-test-harnesses)
  - [testConnectAndList](#testconnectandlist)
  - [testBuildDeploy](#testbuilddeploy)
- [Troubleshooting](#troubleshooting)
  - [Command not found](#command-not-found)
  - [Run setup again](#run-setup-again)
  - [Check module is loaded](#check-module-is-loaded)
  - [Force reimport](#force-reimport)
  - [Source links](#source-links)

Runnable examples for every public Automation command. All commands work from any directory once the module is loaded into your PowerShell profile.

> **Terminal command rules:** live (non-`-DryRun`) runs are driven **only** by parameters passed on the command line or values entered at an interactive prompt. Config files, server lists, and environment-variable defaults are **`-DryRun`-only helpers** (except a file path you explicitly pass as a parameter). Credentials are never read from config, environment, or CyberArk - enter them interactively when prompted.

---

<a name="setup-one-time"></a>

## Setup (One-Time)

Run make setup from the project root to register the Automation module in your PowerShell profile:

```powershell
make setup
```

Then restart PowerShell or reload your profile:

```make
. $PROFILE
```

After this, every command below is available from any directory - no paths required.

Verify all commands are loaded:

```powershell
Get-Command -Module Automation
```

---

<a name="connectivity-connection-server-lookup"></a>

## Connectivity, Connection & Server Lookup

Pre-flight read-only checks. Safe to run during a change freeze. Start here - confirm the appliance is reachable, that you have an active session, and which servers are managed before you build or deploy anything.

<a name="test-oneview-connectivity"></a>

### Test OneView connectivity

Read-only connectivity STATUS CHECK for a OneView appliance - safe during a change freeze. **This command never prompts for a host or credentials.** Run with no parameters to report the ACTIVE OneView connection (established by `Connect-OneView`); supply `-ManagementHost` to check a SPECIFIC appliance only. Reachability probes DNS/TCP; authentication reuses the active session (when it matches) or uses `-Credential` / `ONEVIEW_USER` + `ONEVIEW_PASSWORD` - it never asks for a username or password.

**To actually connect**, use `Connect-OneView -ManagementHost <host>` (which prompts for credentials and establishes the session this command reports on).

**The OneView session established by `Connect-OneView` persists in the current PowerShell session.** Use `Disconnect-OneView` to explicitly close the session when finished.

```powershell
# STATUS: report the active connection (no params, no prompt)
Test-ServerConnectivity
```

```powershell
# STATUS: check a specific appliance only
Test-ServerConnectivity -ManagementHost oneview.example.com
```

```powershell
# DRY-RUN: validate host resolution only - no real connection or changes
Test-ServerConnectivity -ManagementHost oneview.example.com -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-ManagementHost` | `-MgmtHost` | No | OneView appliance to check (server name or serial). Omit to report the active `Connect-OneView` session; supply to check a specific appliance verbatim (no config/env fallback). | - |
| `-DryRun` | `-Dry` | No | Return mock data; config may be read. | - |

No host is required - without one the command reports the active connection.

**Returns:** `[hashtable]` with `Available`, `Mode` (`oneview`), `ManagementHost`, `NetworkPing`, `AuthConnect`, and `Timestamp`.

**Note:** The OneView session persists after a successful connection. Use `Disconnect-OneView` to close it.

---

<a name="connect-to-oneview"></a>

### Connect to OneView

A user-friendly alias for `Test-ServerConnectivity`.  Validates network reachability and authenticates to the OneView appliance in a single step, leaving an active session for subsequent commands (`Get-OneViewServerList`, `Get-OneViewConnectionStatus`, etc.).

On a live run the appliance host is taken verbatim from `-ManagementHost` and credentials are entered interactively at the prompt.  Config files are read **only** with `-DryRun` (no real connection is made).

```powershell
# LIVE: connect to a specific appliance (credentials prompted interactively)
Connect-OneView -ManagementHost oneview.example.com
```

```powershell
# LIVE + NON-INTERACTIVE: supply a PSCredential so nothing is prompted
# (used by runbooks / CI where AUTOMATED_MODE is set)
$cred = Get-Credential
Connect-OneView -ManagementHost oneview.example.com -Credential $cred
```

```powershell
# BARE (no params) on a live run: Connect-OneView needs a target, so it
# prompts for the appliance host (interactive) - or, in automated mode /
# non-TTY, warns "Connect-OneView requires -ManagementHost" and makes no
# connection. Prefer the explicit form above.
Connect-OneView
```

```powershell
# DRY-RUN (no host): resolve the appliance from connection_hosts.json and
# validate host resolution only - no real connection or changes. This is the
# bare, safe-to-run-anywhere form.
Connect-OneView -DryRun
```

> **Supplying `-ManagementHost` vs not:** a live connection *requires* a target
> appliance. With `-ManagementHost` the command connects to exactly that host
> (prompting for credentials, or taking `-Credential` in automation). Without it,
> `Connect-OneView` cannot connect on a live run - it either prompts for the host
> (interactive) or warns and exits (automated). `-DryRun` is the exception: with
> no host it validates the configured appliance instead.

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-ManagementHost` | `-MgmtHost` | No* | OneView appliance to connect to (server name or serial). REQUIRED for live runs; used verbatim - no config/env fallback. | - |
| `-Credential` | `-Cred` | No | `PSCredential` for the live connection. If omitted, credentials are prompted interactively (live run, interactive only). Supply this for non-interactive / automation runs. | prompt (interactive) |
| `-DryRun` | `-Dry` | No | Return mock data; config may be read. Use this to test code without connecting to an appliance or making changes. | - |

\* `-ManagementHost` is required for a live (non-`-DryRun`) connection.

**Returns:** `[hashtable]` with `Available`, `ManagementHost`, `AuthConnect`, `NetworkPing`, `Message`, and `Timestamp`.

**Note:** `Connect-OneView` delegates to `Test-ServerConnectivity`, so the full network-ping + auth validation happens under the hood.  The OneView session persists after a successful connection.  Use `Disconnect-OneView` to close it.

---

<a name="disconnect-from-oneview"></a>

### Disconnect from OneView

Closes the active HPE OneView session established by `Connect-OneView` / `Test-ServerConnectivity` or `Connect-OVMgmt`. Use this command when you are finished running OneView commands and want to explicitly close the connection.

```powershell
# Disconnect from the current OneView session
Disconnect-OneView
```

```powershell
# Force disconnection, suppressing any cleanup errors
Disconnect-OneView -Force
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Force` | No | Force disconnection even if errors occur during cleanup | - |

**Returns:** `[hashtable]` with `Success`, `Message`, and `Timestamp`.

---

<a name="get-oneview-connection-status"></a>

### Get OneView connection status

Quick reachability + authentication check against a OneView appliance, with optional per-server status. Read-only - safe during a change freeze. **This command never prompts.** When run without parameters, the command checks for an existing OneView session (established via `Connect-OneView`) and uses that appliance automatically - no connect/disconnect. Reachability probes `GET /rest/version` (no auth); authentication probes `GET /rest/server-hardware` with the session token or supplied credentials. Use `-ServerIdentifier` to also report a single server's power/health. If no session exists, the command returns an error telling you to connect first with `Connect-OneView -ManagementHost <oneview-appliance-host>`.

```powershell
# BARE: no params - reports the ACTIVE OneView session (from Connect-OneView).
# Never prompts. If nothing is connected it reports not connected.
Get-OneViewConnectionStatus
```

```powershell
# WITH -OneViewHost: check a SPECIFIC appliance instead of the active session.
# Connectivity + appliance version + managed server count
Get-OneViewConnectionStatus -OneViewHost oneview.example.com -IncludeServerCount
```

```powershell
# Specific server status by name (still targets the named appliance)
Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier srv01
```

```powershell
# Specific server status by serial number (resolved via OneView)
Get-OneViewConnectionStatus -OVHost oneview.example.com -SrvrId MXQ1234567 -IdTyp Serial
```

> **Supplying `-OneViewHost` vs not:** with no parameters the command reports the
> active `Connect-OneView` session - the appliance it connects to is whatever you
> already connected to, and it never asks for a host or credentials. Supply
> `-OneViewHost` to check a *different* appliance (it will use `-Credential` /
> `ONEVIEW_USER`+`ONEVIEW_PASSWORD` for that host; it still never prompts). Omitting
> the host is the normal "is my connection still up?" check.

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP. Falls back to active HPEOneView module session if omitted. | - |
| `-ServerIdentifier` | `-SrvrId` | No | Optional server name, serial, iLO IP or bay to look up | - |
| `-IdentifierType` | `-IdTyp` | No | `Auto`, `Name`, `Serial`, `OneViewName`, `IloIp`, `EnclosureBay` | `Auto` |
| `-OneViewUser` | `-OVUser` | No | OneView username (with `-OneViewPassword`) | prompt |
| `-OneViewPassword` | `-OVPwd` | No | OneView password (with `-OneViewUser`) | prompt |
| `-SkipCertificateCheck` | `-SkipCert` | No | Skip SSL cert verification | `true` |
| `-TimeoutSec` | `-Timeout` | No | Per-call timeout | `30` |
| `-IncludeServerCount` | `-SrvrCount` | No | Include the total number of servers managed by OneView | - |
| `-MockResult` | `-Mock` | No | Hashtable to return without making any HTTP calls (tests). | - |
| `-DryRun` | `-Dry` | No | Print the checks without performing them | - |

> **Short aliases:** every parameter above also has a short alias (e.g. `-SrvrId`, `-IdTyp`, `-OVHost`). The long and short forms are interchangeable - the router, `request_types.json`, and existing automation continue to use the long names.

If `-OneViewHost` is omitted, the command checks `$global:ConnectedSessions` for an active HPEOneView module session.

**Returns:** `[hashtable]` with `Success`, `Connected`, `Reachable`, `Authenticated`, `Appliance`, `Version`, `ServerCount` (optional), `Server` (optional), and `SessionSource` (`HPEOneViewModule` or `Explicit`).

---

<a name="get-oneview-server-list"></a>

### Get OneView server list

Lists every server managed by the appliance with normalised connection/health fields. Pagination is handled internally so the full fleet is returned in one call. Supports an optional `-Filter` to narrow by health, power state, or name.

**Connection behaviour (shared helper):** An existing OneView connection always takes priority - if a session is already active, the command reuses it and never reconnects (reconnecting could drop the live session and cause incidents); if you supplied a different `-OneViewHost`, it warns you which appliance you are connected to and to run `Disconnect-OneView` first to switch. When nothing is connected, supplying `-OneViewHost` establishes a persistent session automatically, prompting for username and password interactively as needed (exactly like `Test-ServerConnectivity`). If there is no host and no active session, it returns an exception explaining there is none and how to connect. The session persists - this command never disconnects (only `Disconnect-OneView` does).

```powershell
# Full list of servers from current HPEOneView session (no params needed if connected)
Get-OneViewServerList
```

```powershell
# Full list of servers connected to the appliance
Get-OneViewServerList -OneViewHost oneview.example.com
```

```powershell
# Narrow to critical-health or powered-on servers
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'health:Critical'
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'power:On'
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP. Falls back to active HPEOneView module session if omitted. | - |
| `-OneViewUser` | `-OVUser` | No | OneView username (with `-OneViewPassword`) | prompt |
| `-OneViewPassword` | `-OVPwd` | No | OneView password (with `-OneViewUser`) | prompt |
| `-SkipCertificateCheck` | `-SkipCert` | No | Skip SSL cert verification | `true` |
| `-TimeoutSec` | `-Timeout` | No | Per-call timeout | `30` |
| `-PageSize` | `-Page` | No | Servers fetched per page (max 1000) | `100` |
| `-Filter` | `-` | No | `health:<status>` / `power:<state>` / `name:<substring>` | - |
| `-DryRun` | `-Dry` | No | Print the query without performing it | - |

If `-OneViewHost` is omitted, the command checks `$global:ConnectedSessions` for an active HPEOneView module session.

**Returns:** `[hashtable]` with `Success`, `Count`, and `Servers` (array of name, serial, model, power_state, health_status, ilo_ip, enclosure, rom_version).

---

<a name="validate-server-list"></a>

### Validate server list

```powershell
Test-ServerList
```

**Returns:** `[hashtable]` with `Success` and `Servers`.

---

<a name="validate-build-parameters"></a>

### Validate build parameters

```powershell
Test-BuildParams -BaseIsoPath 'C:\isos\WinSrv2025.iso'
```

**Returns:** `[string[]]` - empty if valid, error messages otherwise.

---

<a name="iso-image-naming-smb-shares"></a>

## ISO Image Naming & SMB Shares

How ISO filenames are generated and how local ISO paths are exposed to the iLO BMC over SMB/CIFS. Read this before passing a local path to a deploy command so you know the expected filename and the share name the iLO will mount.

<a name="bootable-iso-filename-convention"></a>

### Bootable ISO filename convention

`New-IsoBuild` emits a ConfigMgr bootable media ISO using the runbook naming standard:

```
WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso
```

- `<Major>` / `<Minor>` come from `-VersionMajor` (default `1`) and `-VersionMinor` (default `0`).
- `New-IsoBuild` does **not** auto-bump the version. If a file already exists at the resolved path it is reused; pass explicit `-VersionMajor`/`-VersionMinor` or a unique `-OutputPath` to control the name.

Example generated names:

| Command | Resulting file |
|---------|----------------|
| `New-IsoBuild -SiteCode P01 -ManagementPoint mp01 -DistributionPoint dp01` | `WinSrv2025_HPE_BootableMedia_v1.0.iso` |
| `New-IsoBuild ... -VersionMajor 2 -VersionMinor 1` | `WinSrv2025_HPE_BootableMedia_v2.1.iso` |

The same `WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso` name is what `Publish-BootIso` and `Invoke-IsoDeploy -IsoUrl` expect to reference in the repository.

<a name="iso-path-requirements-no-local-drives"></a>

### ISO path requirements (no local drives)

The iLO BMC is a separate physical controller and **cannot** read local drives (`C:\`, `H:\`, ...) on your workstation. This module **does not** auto-create SMB shares and **never** requires Administrator privileges (regulated banking environment).

To deploy an ISO, always supply a network-accessible path:

| Format | Example | Notes |
|--------|---------|-------|
| HTTPS URL | `https://artifacts.internal.example.com/isos/win2025.iso` | iLO downloads directly — no auth prompt |
| UNC/SMB path | `\\fileserver\isos\win2025.iso` | Converted to `cifs://` URL for iLO; ensure iLO can reach the share |
| NFS path | `nfs://fileserver/export/win2025.iso` | iLO mounts via NFS; ensure iLO can reach the export |
| Mapped drive | `H:\win2025.iso` (if H: maps to `\\fileserver\isos`) | Auto-resolved to UNC; only works if the drive is a mapped network drive, **not** a local drive |

**Local paths (e.g. `H:\` on a local disk, `C:\isos\`) are not supported.** If you pass one, the command fails with an error directing you to supply an SMB/UNC or HTTPS path instead.

```powershell
# Correct — supply an already-shared path
Invoke-IsoDeploy -Server srv01 -ExternalIsoPath '\\fileserver\isos\win2025.iso'
Invoke-IsoDeploy -Server srv01 -ExternalIsoPath 'https://artifacts.internal.example.com/isos/win2025.iso'
```

> **Note:** `ReadAccess 'Everyone'` is applied by the auto-creation helper. In a regulated environment, replace it with a scoped account or IP restrictions as required by your security team.

---

<a name="physical-server-build-end-to-end"></a>

## Physical Server Build (End-to-End)

The full runbook workflow in one command: pre-build validation, ConfigMgr bootable ISO, publish to HTTPS, OneView target resolution, iLO Redfish mount + boot, installation monitoring, post-build validation, firmware update, and audit logging. Supports two modes:
- **Build mode** (default): Builds a ConfigMgr bootable ISO, publishes it, deploys it.
- **External ISO mode** (`-ExternalIsoPath`): Deploys a client-supplied ISO directly, skipping build and publish.

<a name="configure-build-4-eye-review"></a>

### Configure build (4-eye review)

Use `Configure-PhysicalBuild` to review the full deployment plan before anything destructive happens. This command is **read-only** — it resolves server identity from OneView, validates ISO reachability, runs pre-build checks, and prints a comprehensive summary including all destructive actions that `Start-PhysicalServerBuild` would perform. Requires interactive confirmation (type `DEPLOY`) unless `-SkipConfirmation` is used.

```powershell
# Full 4-eye review with confirmation prompt
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local `
    -RepoBaseUrl 'https://artifacts/isos/' -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5') -Domain corp.local
```

```powershell
# Non-interactive (skip confirmation) — returns a plan hashtable that can be piped to Start-PhysicalBuild
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -ExternalIsoPath 'https://artifacts/isos/win2025.iso' -SkipConfirmation
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-ServerIdentifier` | `-SrvrId` | Yes | Target server identifier (hostname, serial, OneView name, iLO IP, bay) | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname/IP for server resolution | - |
| `-IloIp` | `-Ilo` | No | iLO IPv4 address / hostname | - |
| `-IloCredential` | — | No | PSCredential for iLO Redfish check (prompted if omitted) | Interactive prompt |
| `-ExpectedHostname` | — | No | Hostname expected after build | Defaults to `-ServerIdentifier` |
| `-Domain` | — | No | AD domain to verify | - |
| `-SiteCode` | — | No | ConfigMgr site code | - |
| `-ManagementPoint` | — | No | ConfigMgr MP FQDN | - |
| `-DistributionPoint` | — | No | ConfigMgr DP FQDN | - |
| `-SiteServer` | — | No | ConfigMgr site server FQDN | - |
| `-BootImageName` | — | No | ConfigMgr boot image name | - |
| `-TaskSequenceName` | — | No | ConfigMgr task sequence name | - |
| `-RepoBaseUrl` | — | No | HTTPS base URL of ISO repository | - |
| `-RepoLocalPath` | — | No | Local filesystem path mirrored to RepoBaseUrl | - |
| `-ExternalIsoPath` | `-ExtIso` | No | Client-supplied ISO (SMB/UNC or HTTPS; local paths not supported) | - |
| `-FirmwareFolders` | `-FwDirs` | No | Firmware component source directories (string array) | @() |
| `-FirmwareConfig` | — | No | Firmware manifest JSON path | - |
| `-GuardRail` | — | Yes | **MANDATORY** safety gate for shared/production networks. A CASE-INSENSITIVE **REGEX** the resolved target server name must match before the build plan is even produced. Omitting it aborts early with an expressive, logged error. If it does not match, the review is aborted. Example: `-GuardRail 'quickview\.ilo0'` matches server `quickview.ilo03.alp`. | - |
| `-InMaintenanceWindow` | — | No | Acknowledge approved maintenance window | - |
| `-SkipPreBuild` | — | No | Skip pre-build validation | - |
| `-SkipOneView` | — | No | Skip OneView target resolution | - |
| `-SkipIlo` | — | No | Skip iLO credential check | - |
| `-SkipDpMp` | — | No | Skip MP/DP reachability check | - |
| `-SkipIsoUrl` | — | No | Skip ISO URL reachability check | - |
| `-Force` | — | No | Acknowledge server power state is On (informational only — no reboot performed) | - |
| `-SkipConfirmation` | `-SkipConf` | No | Skip interactive confirmation prompt | - |

<a name="full-build-most-common"></a>

### Full build (most common)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

<a name="dry-run-validate-without-changing-anything"></a>

### Dry run (validate without changing anything)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -DryRun
```

<a name="build-with-firmware-folders-post-os-install"></a>

### Build with firmware folders (post-OS-install)

Specify firmware component source directories (e.g. from Marin) to be applied via HPE SUT after the OS build completes. The firmware ISO is built, mounted via iLO, and applied after post-build validation.

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local `
    -InMaintenanceWindow -FirmwareFolders @('C:\fw\BIOS_v2.80', 'C:\fw\iLO5_v2.70', 'C:\fw\SmartArray')
```

```powershell
# Using an external ISO with firmware folders
Start-PhysicalServerBuild -ServerIdentifier srv01 -IloIp 10.0.1.50 `
    -ExternalIsoPath 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso' `
    -InMaintenanceWindow -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')
```

```powershell
# Apply firmware later if hardware engineer forgot to add it during the build
Update-Firmware -Server srv01 -FirmwareFolders @('C:\fw\BIOS_v2.80')
```

<a name="re-run-after-iso-already-built-skip-build-phases"></a>

### Re-run after ISO already built (skip build phases)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -IloIp 10.0.1.50 -SkipPreBuild -SkipIsoBuild -SkipPublish -InMaintenanceWindow
```

<a name="re-run-monitoring-after-deployment"></a>

### Re-run monitoring after deployment

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -InMaintenanceWindow
```

<a name="build-with-custom-domain-and-post-build-checks"></a>

### Build with custom domain and post-build checks

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -ExpectedHostname srv01.corp.local -Domain corp.local -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

<a name="mock-build-testing"></a>

### Mock build (testing)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -Mock
```

```powershell
# Deploy an external ISO directly (skip build/publish phases)
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -ExternalIsoPath '\\fileserver\isos\custom.iso' -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

```powershell
# Deploy an external ISO from an HTTPS URL (local drive paths not supported)
Start-PhysicalServerBuild -ServerIdentifier srv01 -IloIp 10.0.1.50 -ExternalIsoPath 'https://fileserver/isos/windows.iso' -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

```powershell
# Skip confirmation prompt for automated deployments
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow -SkipConfirmation
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-ServerIdentifier` | `-SrvrId` | Yes | Server name, serial, OneView name, iLO IP, or bay | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP | - |
| `-IloIp` | `-Ilo` | No | Target iLO address or hostname | - |
| `-ExpectedHostname` | `-` | No | Post-build hostname | `$ServerIdentifier` |
| `-Domain` | `-` | No | AD domain for post-build check | - |
| `-SiteCode` | `-` | No | ConfigMgr site code (e.g. `P01`) | - |
| `-ManagementPoint` | `-` | No | ConfigMgr Management Point FQDN | - |
| `-DistributionPoint` | `-` | No | ConfigMgr Distribution Point FQDN | - |
| `-SiteServer` | `-` | No | ConfigMgr site server FQDN (PSRemoting fallback) | - |
| `-BootImageName` | `-` | No | Boot image name to embed | - |
| `-TaskSequenceName` | `-` | No | Task sequence name (informational) | - |
| `-RepoBaseUrl` | `-` | No | HTTPS base URL of the ISO repository | - |
| `-RepoLocalPath` | `-` | No | Local path mirrored to `-RepoBaseUrl` | - |
| `-ExternalIsoPath` | `-ExtIso` | No | Client-supplied ISO path (HTTP/HTTPS, UNC/SMB, NFS, or local file). When supplied, `-SkipIsoBuild` and `-SkipPublish` are implied. | - |
| `-GuardRail` | — | Yes | **MANDATORY** safety gate for shared/production networks. A CASE-INSENSITIVE **REGEX** the resolved target server name must match before any destructive action. Omitting it aborts early with an expressive, logged error and performs no action. If it does not match, the build is aborted. When it matches, a destructive confirmation (typing YES) is still required unless `-SkipConfirmation`/`-DryRun` are supplied. Example: `-GuardRail 'quickview\.ilo0'` matches server `quickview.ilo03.alp`. | - |
| `-MonitorTimeoutSeconds` | `-` | No | Max monitoring duration | `7200` |
| `-MonitorPollSeconds` | `-` | No | Poll interval | `30` |
| `-SkipPreBuild` | `-` | No | Skip pre-build validation | - |
| `-SkipIsoBuild` | `-` | No | Skip ISO creation | - |
| `-SkipPublish` | `-` | No | Skip ISO publishing | - |
| `-SkipOneView` | `-` | No | Skip OneView resolution | - |
| `-SkipMount` | `-` | No | Skip iLO mount and boot | - |
| `-SkipMonitor` | `-` | No | Skip installation monitoring | - |
| `-SkipPostBuild` | `-` | No | Skip post-build validation | - |
| `-SkipConfirmation` | `-SkipConf` | No | Skip the interactive confirmation prompt before deployment. | - |
| `-Mock` | `-Mock` | No | Mock all calls (implies `-DryRun`) | - |
| `-DryRun` | `-Dry` | No | Validate and print plan only | - |
| `-Force` | `-` | No | Allow destructive `ForceRestart` | - |
| `-InMaintenanceWindow` | `-` | No | Acknowledge approved maintenance window | - |
| `-AllowUnknownIsoUrl` | `-` | No | Skip ISO URL reachability check | - |

**Returns:** `[hashtable]` with `Success`, `Steps`, and `AuditFile`.

---

<a name="iso-build-deployment-monitoring"></a>

## ISO Build, Deployment & Monitoring

Individual commands for the ISO pipeline - build, publish, deploy (reboot + install), and monitor. These are the building blocks the full build above orchestrates.

<a name="build-a-bootable-iso"></a>

### Build a bootable ISO

```powershell
New-IsoBuild -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local
```

#### Build with explicit version and output path

```powershell
New-IsoBuild -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -VersionMajor 2 -VersionMinor 1 -OutputPath 'C:\isos\winpe_v2.1.iso'
```

#### Build dry run

```powershell
New-IsoBuild -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -DryRun
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-SiteCode` | Yes | ConfigMgr site code | - |
| `-ManagementPoint` | Yes | ConfigMgr Management Point FQDN | - |
| `-DistributionPoint` | Yes | ConfigMgr Distribution Point FQDN | - |
| `-OutputPath` | No | Full output path for the ISO | Auto-generated |
| `-VersionMajor` | No | Major version in filename | `1` |
| `-VersionMinor` | No | Minor version in filename | `0` |
| `-BootImageName` | No | Boot image name to embed | - |
| `-TaskSequenceName` | No | Task sequence name | - |
| `-SiteServer` | No | Site server FQDN (PSRemoting fallback) | - |
| `-DryRun` | No | Validate inputs only | - |

**Returns:** `[hashtable]` with `Success`, `IsoPath`, and `Metadata`.

---

<a name="publish-a-bootable-iso"></a>

### Publish a bootable ISO

```powershell
Publish-BootIso -IsoPath 'C:\isos\winpe_v1.0.iso'
```

#### Publish with force overwrite

```powershell
Publish-BootIso -IsoPath 'C:\isos\winpe_v1.0.iso' -ForceOverwrite
```

#### Publish without HTTPS verification

```powershell
Publish-BootIso -IsoPath 'C:\isos\winpe_v1.0.iso' -SkipVerify
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-IsoPath` | Yes | Local path to the ISO file | - |
| `-RepoBaseUrl` | Yes (live) | HTTPS base URL of the repository. Env default only with `-DryRun`. | - |
| `-RepoLocalPath` | No | Local path mirrored to the repository. Env default only with `-DryRun`. | - |
| `-ForceOverwrite` | No | Overwrite existing ISO | - |
| `-SkipVerify` | No | Skip HTTPS HEAD check | - |
| `-DryRun` | No | Simulate only | - |

**Returns:** `[hashtable]` with `Success`, `PublicUrl`, `RepoPath`, and `Verified`.

---

<a name="deploy-isos-to-servers"></a>

### Deploy ISOs to servers

Mounts the ISO on the server's iLO via Redfish, sets the one-time boot override, and reboots the server to begin installation. This is the command that actually reboots the server and kicks off the OS install.

```powershell
# Deploy by server hostname
Invoke-IsoDeploy -Server srv01 -IsoUrl 'https://artifacts/isos/WinSrv2025_v1.0.iso'
```

#### Deploy an external ISO (HTTP/HTTPS, UNC/SMB, NFS, or local path)

```powershell
# Deploy from a network share (auto-converted to CIFS URL for iLO)
Invoke-IsoDeploy -Server srv01 -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso'
```

```powershell
# Deploy from an HTTP URL (used directly)
Invoke-IsoDeploy -Server srv01 -ExternalIsoPath 'https://artifacts/isos/WinSrv2025.iso'
```

```powershell
# Deploy from a local path - auto-creates an SMB share if running as Administrator
Invoke-IsoDeploy -Server srv01 -ExternalIsoPath 'H:\windows.iso'
```

#### Deploy by serial number (resolved via OneView)

```powershell
Invoke-IsoDeploy -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'
```

#### Deploy by serial number with external ISO

```powershell
Invoke-IsoDeploy -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com -ExternalIsoPath 'H:\custom.iso'
```

#### Bulk deploy to all servers

```powershell
Invoke-IsoDeploy
```

#### Dry run - see what would deploy

```powershell
Invoke-IsoDeploy -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-Method` | `-` | No | Deployment method (`redfish`) | `redfish` |
| `-Server` | `-Srvr` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | `-Srl` | No | Target a server by its HPE serial number; resolved to the hostname (and iLO IP) via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | `-SrvrList` | No | Path to server list | auto-resolved |
| `-IsoDir` | `-` | No | Directory containing ISO packages | auto-resolved |
| `-IsoUrl` | `-Iso` | No | Override the ISO URL | - |
| `-ExternalIsoPath` | `-ExtIso` | No | Client-supplied ISO path (HTTP/HTTPS, UNC/SMB, NFS, or local file). When supplied, `-IsoUrl` is ignored and package resolution is skipped. For local paths, an SMB share is auto-created when run as Administrator. | - |
| `-GuardRail` | — | Yes | **MANDATORY** safety gate for shared/production networks. A CASE-INSENSITIVE **REGEX** the resolved target server name must match before any deployment. Omitting it aborts early with an expressive, logged error and performs no deployment. If it does not match, the deployment is aborted. When it matches, a destructive confirmation (typing YES) is still required unless `-SkipConfirmation`/`-DryRun` are supplied. Example: `-GuardRail 'quickview\.ilo0'` matches server `quickview.ilo03.alp`. | - |
| `-RepoBaseUrl` | `-RepoUrl` | No | HTTPS base URL of the ISO repository. Unused by `-ExternalIsoPath` resolution (local files are shared via an auto-created SMB share instead). | - |
| `-RepoLocalPath` | `-RepoPath` | No | Local filesystem path mirrored to `-RepoBaseUrl`. Unused by `-ExternalIsoPath` resolution. | - |
| `-SkipConfirmation` | `-SkipConf` | No | Skip the interactive confirmation prompt before deployment. (Currently only enforced by `Start-PhysicalServerBuild`; ignored by `Invoke-IsoDeploy`.) | - |
| `-DryRun` | `-Dry` | No | Simulate only | - |

```powershell
# Target by serial number (resolved via OneView)
Invoke-IsoDeploy -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com -IsoUrl 'https://artifacts/isos/WinSrv2025_BootableMedia_v1.0.iso'
```

**Returns:** `[hashtable]` with `Success`, `Server`, and `Summary`.

---

<a name="monitor-installation-progress"></a>

### Monitor installation progress

```powershell
Start-InstallMonitor -Server srv01
```

#### Monitor with custom timeout

```powershell
Start-InstallMonitor -Server srv01 -TimeoutSeconds 3600 -PollIntervalSeconds 15
```

#### Monitor all servers from the server list

```powershell
Start-InstallMonitor
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-Server` | `-Srvr` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | `-Srl` | No | Target a server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | `-SrvrList` | No | Path to server list | auto-resolved |
| `-TimeoutSeconds` | `-Timeout` | No | Max monitoring duration | `7200` |
| `-PollIntervalSeconds` | `-PollSec` | No | Seconds between polls | `30` |
| `-OpsRampConfig` | `-OpsCfg` | No | Path to OpsRamp config - only read when explicitly passed | - |

```powershell
# Target by serial number (resolved via OneView)
Start-InstallMonitor -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
```

**Returns:** `[hashtable]` with `Success`, per-server `Status`/`Details`, or bulk `Summary`.

---

<a name="ilo-redfish-operations"></a>

### iLO Redfish operations

```powershell
Invoke-IloRedfish -Action MountAndBoot -IloIp 10.0.1.50 -IsoUrl 'https://artifacts/isos/WinSrv2025_v1.0.iso' -Force
```

#### Mount ISO only

```powershell
Invoke-IloRedfish -Action Mount -IloIp 10.0.1.50 -IsoUrl 'https://artifacts/isos/WinSrv2025_v1.0.iso'
```

#### Eject virtual media

```powershell
Invoke-IloRedfish -Action Eject -IloIp 10.0.1.50
```

#### Check current status

```powershell
Invoke-IloRedfish -Action Status -IloIp 10.0.1.50
```

#### Force reset

```powershell
Invoke-IloRedfish -Action Reset -IloIp 10.0.1.50 -Force
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-Action` | `-` | Yes | `Mount`, `MountAndBoot`, `Boot`, `Reset`, `Eject`, `Status` | - |
| `-IloIp` | `-Ilo` | Yes | iLO IPv4 address or hostname | - |
| `-IloUser` | `-IloU` | No | iLO username. Never read from config/env. | prompt |
| `-IloPassword` | `-IloP` | No | iLO password. Never read from config/env. | prompt |
| `-IsoUrl` | `-Iso` | No | HTTPS URL of the ISO (for `Mount`/`MountAndBoot`) | - |
| `-CdDeviceId` | `-` | No | Virtual media device ID | `1` |
| `-Force` | `-` | No | Confirm destructive actions | - |
| `-DryRun` | `-Dry` | No | Print actions without performing them | - |

**Returns:** `[hashtable]` with `Success`, `Action`, `IloIp`, `Details`, and `Error`.

---

<a name="resolve-server-target-via-oneview"></a>

### Resolve server target via OneView

Resolves and validates a target server via OneView. **This is the central single-server module** every OneView automation command that acts on one server uses (via `Resolve-OneViewTarget`), so targeting is consistent and strict across the pipeline. **Strict single-server:** a name or serial that matches more than one server is a hard failure - it never silently picks the first, because it underpins destructive operations (ISO attach/deploy, reboot, OS build). **Connection behaviour (shared helper):** an existing OneView connection always takes priority - a live session is reused and never reconnected (to avoid dropping it); if you supplied a different `-OneViewHost` you are warned which appliance you are on and to `Disconnect-OneView` first to switch. When nothing is connected, supplying `-OneViewHost` establishes a persistent session automatically, prompting for username and password interactively as needed (exactly like `Test-ServerConnectivity` / `Connect-OneView`). With no host and no active session it returns an exception explaining there is none. The session persists - this command never disconnects (only `Disconnect-OneView` does). The build pipeline (`Invoke-IsoDeploy`, `Update-Firmware`, `Test-PostBuildValidation`, `Start-InstallMonitor`, `Start-PhysicalServerBuild`, etc.) all resolve through this module and inherit both behaviours.

```powershell
Get-OneViewServerTarget -ServerIdentifier srv01 -OneViewHost oneview.corp.local
```

#### Look up by serial number

```powershell
Get-OneViewServerTarget -ServerIdentifier ABC123XYZ -OneViewHost oneview.corp.local -IdentifierType Serial
```

#### Dry run

```powershell
Get-OneViewServerTarget -ServerIdentifier srv01 -OneViewHost oneview.corp.local -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP | - |
| `-ServerIdentifier` | `-SrvrId` | Yes | Server name, serial, iLO IP, or bay | - |
| `-IdentifierType` | `-IdTyp` | No | `Auto`, `Name`, `Serial`, `OneViewName`, `IloIp`, `EnclosureBay` | `Auto` |
| `-OneViewUser` | `-OVUser` | No | OneView username (with `-OneViewPassword`) | prompt |
| `-OneViewPassword` | `-OVPwd` | No | OneView password (with `-OneViewUser`) | prompt |
| `-DryRun` | `-Dry` | No | Print query without performing it | - |

**Returns:** `[hashtable]` with `Success`, `Server`, `ResolvedBy`, `Details`, and `Error`.

---

<a name="pre-build-validation"></a>

### Pre-build validation

```powershell
Test-PreBuildValidation -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50
```

#### Skip specific checks

```powershell
Test-PreBuildValidation -ServerIdentifier srv01 -SkipDpMp -SkipIsoUrl
```

#### Dry run (validate inputs, skip network probes)

```powershell
Test-PreBuildValidation -ServerIdentifier srv01 -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-ServerIdentifier` | `-SrvrId` | Yes | Target server identifier | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP | - |
| `-IloIp` | `-Ilo` | No | Target iLO address | - |
| `-IsoUrl` | `-` | No | HTTPS URL of the bootable ISO | - |
| `-ManagementPoint` | `-` | No | ConfigMgr Management Point FQDN | - |
| `-DistributionPoint` | `-` | No | ConfigMgr Distribution Point FQDN | - |
| `-BootImageName` | `-` | No | Boot image name to verify | - |
| `-TaskSequenceName` | `-` | No | Task sequence name to verify | - |
| `-SkipOneView` | `-` | No | Skip OneView target check | - |
| `-SkipIlo` | `-` | No | Skip iLO credential check | - |
| `-SkipDpMp` | `-` | No | Skip MP/DP reachability checks | - |
| `-SkipIsoUrl` | `-` | No | Skip ISO URL reachability check | - |
| `-DryRun` | `-Dry` | No | Validate inputs, skip network probes | - |

**Returns:** `[hashtable]` with `Success`, `Server`, `Timestamp`, and `Checks`.

---

<a name="post-build-validation"></a>

### Post-build validation

```powershell
Test-PostBuildValidation -Hostname srv01 -Domain corp.local
```

#### Skip ConfigMgr client check

```powershell
Test-PostBuildValidation -Hostname srv01 -SkipCmClient
```

#### Skip all remote checks (WinRM not available)

```powershell
# Target by serial number (resolved to hostname via OneView)
Test-PostBuildValidation -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com -Domain corp.local
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-Hostname` | `-` | Yes* | Target server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | `-Srl` | No | Identify the server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ExpectedHostname` | `-` | No | Expected hostname for cross-check | `$Hostname` |
| `-Domain` | `-` | No | AD domain expected after build | - |
| `-ExpectedOsVersion` | `-` | No | Expected OS version string | - |
| `-SkipCmClient` | `-` | No | Skip ConfigMgr client checks | - |
| `-SkipDrivers` | `-` | No | Skip HPE driver presence check | - |
| `-SkipRemote` | `-` | No | Skip all WinRM-dependent checks | - |
| `-DryRun` | `-Dry` | No | Assume checks pass | - |

\* `-Hostname` is required unless `-SerialNumber` is supplied.

**Returns:** `[hashtable]` with `Success`, `Hostname`, `Timestamp`, `Checks`, and `AuditFile`.

---

<a name="build-firmware-iso"></a>

### Build firmware ISO

```powershell
Update-Firmware -Server srv01
```

#### Build firmware for all servers

```powershell
Update-Firmware
```

#### Dry run

```powershell
Update-Firmware -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-Config` | `-Cfg` | Yes (live) | Firmware manifest path - must be passed explicitly on live runs; default path only with `-DryRun` | DryRun only |
| `-Server` | `-Srvr` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | `-Srl` | No | Target a server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | `-SrvrList` | No | Path to server list | auto-resolved |
| `-OutputDir` | `-OutDir` | No | Output directory | - |
| `-SkipDownload` | `-SkipDl` | No | Skip component download | - |
| `-DryRun` | `-Dry` | No | Simulate only | - |
| `-FirmwareFolders` | `-FwDirs` | No | Additional firmware component source directories (array). Passed to `hpe_sut` via `--firmware-components`. Use when Marin provides firmware folders outside the standard manifest. | `-` |
| `-GuardRail` | — | Yes | **MANDATORY** safety gate for shared/production networks. A CASE-INSENSITIVE **REGEX** the resolved target server name must match before any firmware update. Omitting it aborts early with an expressive, logged error and performs no update. If it does not match, the update is aborted. Example: `-GuardRail 'quickview\.ilo0'` matches server `quickview.ilo03.alp`. | - |
| `-SkipFirmware` | — | No | Skip the post-OS firmware update step (only on `Start-PhysicalServerBuild`). | - |

```powershell
# Target by serial number (resolved via OneView)
Update-Firmware -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com

# Include Marin-provided firmware component folders
Update-Firmware -Server srv01 -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5', 'C:\fw\Storage')
```

**Returns:** `[hashtable]` with `Success` and details.

---

<a name="patch-windows-iso-with-security-updates"></a>

### Patch Windows ISO with security updates

```powershell
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -Server srv01
```

#### Patch with custom method

```powershell
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -Server srv01 -Method powershell
```

#### Dry run

```powershell
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -Server srv01 -DryRun
```

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-BaseIsoPath` | `-BaseIso` | Yes | Path to the base Windows Server ISO | - |
| `-Server` | `-` | Yes | Server hostname for output naming. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | `-Srl` | No | Identify the server by its HPE serial number; resolved to the hostname (for output naming) via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | `-OVHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-PatchesConfig` | `-` | Yes (live) | Patch manifest path - must be passed explicitly on live runs; default path only with `-DryRun` | DryRun only |
| `-OutputDir` | `-` | No | Output directory | - |
| `-Method` | `-` | No | Patching method: `dism` or `powershell` | `dism` |
| `-DryRun` | `-Dry` | No | Simulate only | - |

```powershell
# Target by serial number (resolved via OneView)
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
```

**Returns:** `[hashtable]` with `Success`, `PatchedIso`, and details.

---

<a name="maintenance-mode"></a>

## Maintenance Mode

See [`CLIENT-QUICK-START.md`](../CLIENT-QUICK-START.md#top) for the full guide.

<a name="examples"></a>

### Examples

```powershell
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
```

---

<a name="powershell-execution-and-utility"></a>

## PowerShell Execution and Utility

Low-level helpers used by other commands.

<a name="run-a-local-powershell-script"></a>

### Run a local PowerShell script

Executes PowerShell scripts locally by spawning a new PowerShell process with configurable timeout, execution policy, and output capture. Prefers `pwsh` (PowerShell 7+) on all platforms and falls back to `powershell.exe` (Windows PowerShell 5.1) only when `pwsh` is not available.

```powershell
Invoke-PowerShellScript -Script 'Get-Process | Select-Object -First 5' -TimeoutSeconds 30
```

<a name="run-a-remote-powershell-script-via-winrm"></a>

### Run a remote PowerShell script via WinRM

```powershell
Invoke-PowerShellWinRM -Script 'Get-Service wuauserv' -Server srv01
```

<a name="generate-a-deterministic-uuid"></a>

### Generate a deterministic UUID

```powershell
New-Uuid -ServerName srv01
```

<a name="opsramp-api-client"></a>

### OpsRamp API client

```powershell
Invoke-OpsRampClient
```

---

<a name="routing-and-control-surfaces"></a>

## Routing and Control Surfaces

Dispatch requests to the appropriate handler.

<a name="orchestrator-unified-entry-point"></a>

### Orchestrator (unified entry point)

```powershell
Start-AutomationOrchestrator -RequestType build_iso -Params @{ SiteCode = 'P01'; ManagementPoint = 'mp01.corp.local' }
```

<a name="view-the-route-map"></a>

### View the route map

```powershell
Get-RouteMap
```

<a name="control-surface-factories-and-runners"></a>

### Control surface factories and runners

```powershell
Run-CIPipeline -Params @{ Stage = 'build'; Version = '1.0' }
Run-Scheduler -TaskParams @{ Server = 'srv01'; Timeout = 3600 }
Run-GitLab -Params @{ TargetId = 'CLU-01'; Action = 'enable' }
```

<a name="gitlab-maintenance-trigger"></a>

### GitLab maintenance trigger

```powershell
```

---

<a name="functional-test-harnesses"></a>

## Functional Test Harnesses

Two re-runnable, parameter-driven PowerShell scripts exercise the live commands
end-to-end (safe by default — they validate with `-DryRun` and only perform live
calls when you pass `-Live` with credentials). They take the host/server as
parameters (or prompt when omitted) and write a full audit log via the module's
common logging commands. Every command that emits log output initializes its own
isolated log under `generated/logs/commands/<CommandName>/` via
`Initialize-Logging` / `Get-Logger`, so a nested command's logging can never
hijack (or truncate) its caller's log file — the log path is captured per
logger at creation time. Read-only / connection commands are covered by this
convention too (not just the documented write commands), so operator-facing
notices such as the `-DryRun` "mock test only" banner are persisted alongside
the step records. Both are documented in full under
[`docs/dynamic-code-docs/testConnectAndList.md`](../dynamic-code-docs/testConnectAndList.md#top)
and
[`docs/dynamic-code-docs/testBuildDeploy.md`](../dynamic-code-docs/testBuildDeploy.md#top).

<a name="testconnectandlist"></a>

### testConnectAndList

Non-destructive connectivity / connection / server-lookup harness. Proves every
read-only command fails **gracefully** without a session and succeeds **with** one,
and runs a parameter-combination matrix.

```powershell
pwsh scripts/testConnectAndList.ps1 -ManagementHost oneview-test.ad.example.com
pwsh scripts/testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com -Live -Credential $cred
```

<a name="testbuilddeploy"></a>

### testBuildDeploy

Build/deploy pipeline harness with the **mandatory `-GuardRail`** safety gate.
Validates ISO path → iLO-accessible URL conversion, firmware archive integrity,
guard-rail match / non-match / omitted behaviour, the confirmation flow, and
build/deploy variants — all under `-DryRun` unless `-Live` is supplied.

```powershell
pwsh scripts/testBuildDeploy.ps1 -ManagementHost oneview-test.ad.example.com -Server srv01 -GuardRail 'srv0'
pwsh scripts/testBuildDeploy.ps1 -Server srv01 -IsoPath '\\fileserver\isos\win.iso' -FirmwarePath 'C:\fw\firmware.zip' -GuardRail 'srv0'
```

<a name="troubleshooting"></a>

## Troubleshooting

<a name="command-not-found"></a>

### Command not found

```powershell
. $PROFILE
Get-Command -Module Automation
```

<a name="run-setup-again"></a>

### Run setup again

```powershell
./scripts/Setup-Profile.ps1
```

<a name="check-module-is-loaded"></a>

### Check module is loaded

```powershell
Get-Module Automation
```

<a name="force-reimport"></a>

### Force reimport

```powershell
Import-Module (Get-ChildItem -Recurse -Filter 'Automation.psd1' -Path (Split-Path (Get-Command Setup-Profile).Source | Split-Path) | Select -First 1).FullName -Force
```

<a name="source-links"></a>

### Source links

[Generated API reference](../dynamic-code-docs/INDEX.md#top) with per-command detail pages.
