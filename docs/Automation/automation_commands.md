# Automation Command Reference

## Table of Contents

- [Setup (One-Time)](#setup-one-time)
- [Physical Server Build (End-to-End)](#physical-server-build-end-to-end)
  - [Full build (most common)](#full-build-most-common)
  - [Dry run (validate without changing anything)](#dry-run-validate-without-changing-anything)
  - [Re-run after ISO already built (skip build phases)](#re-run-after-iso-already-built-skip-build-phases)
  - [Re-run monitoring after deployment](#re-run-monitoring-after-deployment)
  - [Build with custom domain and post-build checks](#build-with-custom-domain-and-post-build-checks)
  - [Mock build (testing)](#mock-build-testing)
- [ISO Build, Patching, Deployment, and Monitoring](#iso-build-patching-deployment-and-monitoring)
  - [Build a bootable ISO](#build-a-bootable-iso)
  - [Publish a bootable ISO](#publish-a-bootable-iso)
  - [Deploy ISOs to servers](#deploy-isos-to-servers)
  - [Monitor installation progress](#monitor-installation-progress)
  - [Build firmware ISO](#build-firmware-iso)
  - [Patch Windows ISO with security updates](#patch-windows-iso-with-security-updates)
  - [Resolve server target via OneView](#resolve-server-target-via-oneview)
  - [iLO Redfish operations](#ilo-redfish-operations)
  - [Pre-build validation](#pre-build-validation)
  - [Post-build validation](#post-build-validation)
- [Maintenance Mode](#maintenance-mode)
  - [Examples](#examples)
- [Connectivity and Validation](#connectivity-and-validation)
  - [Test OneView connectivity](#test-oneview-connectivity)
  - [Validate server list](#validate-server-list)
  - [Validate build parameters](#validate-build-parameters)
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
- [Troubleshooting](#troubleshooting)
  - [Command not found](#command-not-found)
  - [Run setup again](#run-setup-again)
  - [Check module is loaded](#check-module-is-loaded)
  - [Force reimport](#force-reimport)
  - [Source links](#source-links)


<a id="top"></a>
Runnable examples for every public Automation command. All commands work from any directory once the module is loaded into your PowerShell profile.

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

<a name="physical-server-build-end-to-end"></a>
## Physical Server Build (End-to-End)

The full runbook workflow in one command: pre-build validation, ConfigMgr bootable ISO, publish to HTTPS, OneView target resolution, iLO Redfish mount + boot, installation monitoring, post-build validation, and audit logging. Supports two modes:
- **Build mode** (default): Builds a ConfigMgr bootable ISO, publishes it, deploys it.
- **External ISO mode** (`-ExternalIsoPath`): Deploys a client-supplied ISO directly, skipping build and publish.

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
# Deploy an external ISO from a local path (auto-creates an SMB share when run as Administrator)
Start-PhysicalServerBuild -ServerIdentifier srv01 -IloIp 10.0.1.50 -ExternalIsoPath 'H:\windows.iso' -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

```powershell
# Skip confirmation prompt for automated deployments
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow -SkipConfirmation
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-ServerIdentifier` | Yes | Server name, serial, OneView name, iLO IP, or bay | - |
| `-OneViewHost` | No | OneView appliance hostname or IP | - |
| `-IloIp` | No | Target iLO address or hostname | - |
| `-ExpectedHostname` | No | Post-build hostname | `$ServerIdentifier` |
| `-Domain` | No | AD domain for post-build check | - |
| `-SiteCode` | No | ConfigMgr site code (e.g. `P01`) | - |
| `-ManagementPoint` | No | ConfigMgr Management Point FQDN | - |
| `-DistributionPoint` | No | ConfigMgr Distribution Point FQDN | - |
| `-SiteServer` | No | ConfigMgr site server FQDN (PSRemoting fallback) | - |
| `-BootImageName` | No | Boot image name to embed | - |
| `-TaskSequenceName` | No | Task sequence name (informational) | - |
| `-RepoBaseUrl` | No | HTTPS base URL of the ISO repository | - |
| `-RepoLocalPath` | No | Local path mirrored to `-RepoBaseUrl` | - |
| `-ExternalIsoPath` | No | Client-supplied ISO path (HTTP/HTTPS, UNC/SMB, NFS, or local file). When supplied, `-SkipIsoBuild` and `-SkipPublish` are implied. | - |
| `-MonitorTimeoutSeconds` | No | Max monitoring duration | `7200` |
| `-MonitorPollSeconds` | No | Poll interval | `30` |
| `-SkipPreBuild` | No | Skip pre-build validation | - |
| `-SkipIsoBuild` | No | Skip ISO creation | - |
| `-SkipPublish` | No | Skip ISO publishing | - |
| `-SkipOneView` | No | Skip OneView resolution | - |
| `-SkipMount` | No | Skip iLO mount and boot | - |
| `-SkipMonitor` | No | Skip installation monitoring | - |
| `-SkipPostBuild` | No | Skip post-build validation | - |
| `-SkipConfirmation` | No | Skip the interactive confirmation prompt before deployment. | - |
| `-Mock` | No | Mock all calls (implies `-DryRun`) | - |
| `-DryRun` | No | Validate and print plan only | - |
| `-Force` | No | Allow destructive `ForceRestart` | - |
| `-InMaintenanceWindow` | No | Acknowledge approved maintenance window | - |
| `-AllowUnknownIsoUrl` | No | Skip ISO URL reachability check | - |

**Returns:** `[hashtable]` with `Success`, `Steps`, and `AuditFile`.

---

<a name="iso-build-patching-deployment-and-monitoring"></a>
## ISO Build, Patching, Deployment, and Monitoring

Individual commands for the ISO pipeline - build, publish, deploy, monitor, and patch.

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
| `-RepoBaseUrl` | No | HTTPS base URL of the repository | `$env:ISO_REPO_BASE_URL` |
| `-RepoLocalPath` | No | Local path mirrored to the repository | `$env:ISO_REPO_LOCAL_PATH` |
| `-ForceOverwrite` | No | Overwrite existing ISO | - |
| `-SkipVerify` | No | Skip HTTPS HEAD check | - |
| `-DryRun` | No | Simulate only | - |

**Returns:** `[hashtable]` with `Success`, `PublicUrl`, `RepoPath`, and `Verified`.

---

<a name="deploy-isos-to-servers"></a>
### Deploy ISOs to servers

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Method` | No | Deployment method (`redfish`) | `redfish` |
| `-Server` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | No | Target a server by its HPE serial number; resolved to the hostname (and iLO IP) via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-IsoDir` | No | Directory containing ISO packages | auto-resolved |
| `-IsoUrl` | No | Override the ISO URL | - |
| `-ExternalIsoPath` | No | Client-supplied ISO path (HTTP/HTTPS, UNC/SMB, NFS, or local file). When supplied, `-IsoUrl` is ignored and package resolution is skipped. For local paths, an SMB share is auto-created when run as Administrator. | - |
| `-RepoBaseUrl` | No | HTTPS base URL of the ISO repository. Unused by `-ExternalIsoPath` resolution (local files are shared via an auto-created SMB share instead). | - |
| `-RepoLocalPath` | No | Local filesystem path mirrored to `-RepoBaseUrl`. Unused by `-ExternalIsoPath` resolution. | - |
| `-SkipConfirmation` | No | Skip the interactive confirmation prompt before deployment. (Currently only enforced by `Start-PhysicalServerBuild`; ignored by `Invoke-IsoDeploy`.) | - |
| `-DryRun` | No | Simulate only | - |

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Server` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | No | Target a server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-TimeoutSeconds` | No | Max monitoring duration | `7200` |
| `-PollIntervalSeconds` | No | Seconds between polls | `30` |
| `-OpsRampConfig` | No | Path to OpsRamp config | auto-resolved |

```powershell
# Target by serial number (resolved via OneView)
Start-InstallMonitor -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
```

**Returns:** `[hashtable]` with `Success`, per-server `Status`/`Details`, or bulk `Summary`.

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Config` | No | Firmware manifest path | auto-resolved |
| `-Server` | No | Single server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | No | Target a server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-OutputDir` | No | Output directory | - |
| `-SkipDownload` | No | Skip component download | - |
| `-DryRun` | No | Simulate only | - |

```powershell
# Target by serial number (resolved via OneView)
Update-Firmware -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
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
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -Method powershell
```

#### Dry run

```powershell
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -DryRun
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-BaseIsoPath` | No | Path to the base Windows Server ISO | - |
| `-Server` | No | Server hostname for output naming. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | No | Identify the server by its HPE serial number; resolved to the hostname (for output naming) via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-PatchesConfig` | No | Path to patch manifest | auto-resolved |
| `-OutputDir` | No | Output directory | - |
| `-Method` | No | Patching method: `dism` or `powershell` | `dism` |
| `-DryRun` | No | Simulate only | - |

```powershell
# Target by serial number (resolved via OneView)
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\isos\WinSrv2025.iso' -SerialNumber MXQ1234567 -OneViewHost oneview.ad.example.com
```

**Returns:** `[hashtable]` with `Success`, `PatchedIso`, and details.

---

<a name="resolve-server-target-via-oneview"></a>
### Resolve server target via OneView

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-OneViewHost` | No | OneView appliance hostname or IP | - |
| `-ServerIdentifier` | Yes | Server name, serial, iLO IP, or bay | - |
| `-IdentifierType` | No | `Auto`, `Name`, `Serial`, `OneViewName`, `IloIp`, `EnclosureBay` | `Auto` |
| `-OneViewUser` | No | OneView username | `$env:ONEVIEW_USER` |
| `-OneViewPassword` | No | OneView password | `$env:ONEVIEW_PASSWORD` |
| `-Port` | No | OneView HTTPS port | `443` |
| `-DryRun` | No | Print query without performing it | - |

**Returns:** `[hashtable]` with `Success`, `Server`, `ResolvedBy`, `Details`, and `Error`.

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Action` | Yes | `Mount`, `MountAndBoot`, `Boot`, `Reset`, `Eject`, `Status` | - |
| `-IloIp` | Yes | iLO IPv4 address or hostname | - |
| `-IloUser` | No | iLO username | `$env:ILO_USER` |
| `-IloPassword` | No | iLO password | `$env:ILO_PASSWORD` |
| `-IsoUrl` | No | HTTPS URL of the ISO (for `Mount`/`MountAndBoot`) | - |
| `-CdDeviceId` | No | Virtual media device ID | `1` |
| `-Force` | No | Confirm destructive actions | - |
| `-DryRun` | No | Print actions without performing them | - |

**Returns:** `[hashtable]` with `Success`, `Action`, `IloIp`, `Details`, and `Error`.

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-ServerIdentifier` | Yes | Target server identifier | - |
| `-OneViewHost` | No | OneView appliance hostname or IP | - |
| `-IloIp` | No | Target iLO address | - |
| `-IsoUrl` | No | HTTPS URL of the bootable ISO | - |
| `-ManagementPoint` | No | ConfigMgr Management Point FQDN | - |
| `-DistributionPoint` | No | ConfigMgr Distribution Point FQDN | - |
| `-BootImageName` | No | Boot image name to verify | - |
| `-TaskSequenceName` | No | Task sequence name to verify | - |
| `-SkipOneView` | No | Skip OneView target check | - |
| `-SkipIlo` | No | Skip iLO credential check | - |
| `-SkipDpMp` | No | Skip MP/DP reachability checks | - |
| `-SkipIsoUrl` | No | Skip ISO URL reachability check | - |
| `-DryRun` | No | Validate inputs, skip network probes | - |

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

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Hostname` | Yes* | Target server hostname. Mutually exclusive with `-SerialNumber`. | - |
| `-SerialNumber` | No | Identify the server by its HPE serial number; resolved to the hostname via OneView. Requires `-OneViewHost`. | - |
| `-OneViewHost` | No | OneView appliance used to resolve `-SerialNumber`. | - |
| `-ExpectedHostname` | No | Expected hostname for cross-check | `$Hostname` |
| `-Domain` | No | AD domain expected after build | - |
| `-ExpectedOsVersion` | No | Expected OS version string | - |
| `-SkipCmClient` | No | Skip ConfigMgr client checks | - |
| `-SkipDrivers` | No | Skip HPE driver presence check | - |
| `-SkipRemote` | No | Skip all WinRM-dependent checks | - |
| `-DryRun` | No | Assume checks pass | - |

\* `-Hostname` is required unless `-SerialNumber` is supplied.

**Returns:** `[hashtable]` with `Success`, `Hostname`, `Timestamp`, `Checks`, and `AuditFile`.

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

<a name="connectivity-and-validation"></a>
## Connectivity and Validation

Pre-flight read-only checks. Safe to run during a change freeze.

<a name="test-oneview-connectivity"></a>
### Test OneView connectivity

Combined network ping + authentication test for a OneView appliance. Read-only - safe during a change freeze. On a live run the command never reads config: the appliance host comes from `-ManagementHost` (used verbatim) and credentials come from `-Credential` or an interactive prompt. Config files are read **only** with `-DryRun`.

```powershell
# LIVE: explicit host, credentials prompted interactively
Test-ServerConnectivity -ManagementHost va-oneviewt-01
```

```powershell
# LIVE: explicit host + supplied credential (no prompt)
Test-ServerConnectivity -ManagementHost va-oneviewt-01 -Credential (Get-Credential)
```

```powershell
# DRY-RUN using connection_hosts.json config (no real connection)
Test-ServerConnectivity -Environment Test -JsonConfig -DryRun
```

```powershell
# DRY-RUN with explicit host (validates resolution only)
Test-ServerConnectivity -ManagementHost va-oneviewt-01 -DryRun
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Environment` | No | `Test` or `Prod`. Only used with `-JsonConfig` (DryRun). | - |
| `-ManagementHost` | No* | OneView appliance to connect to (server name or serial). REQUIRED for live runs; used verbatim - no config/env fallback. | - |
| `-Credential` | No | `PSCredential` for the live connection (e.g. `(Get-Credential)`). If omitted, prompted interactively. | - |
| `-ConfigDir` | No | Configuration directory | auto-resolved |
| `-PingTimeoutMs` | No | TCP connect timeout (ms) | `3000` |
| `-Json` | No | Output as JSON | - |
| `-JsonConfig` | No | Resolve host from `connection_hosts.json` (DryRun only) | - |
| `-DryRun` | No | Return mock data; config may be read | - |

\* `-ManagementHost` is required for a live (non-`-DryRun`) connectivity test.

**Returns:** `[hashtable]` with `Available`, `Mode` (`oneview`), `ManagementHost`, `Environment`, `NetworkPing`, `AuthConnect`, and `Timestamp`.

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


