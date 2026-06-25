# Automation Command Reference

Runnable examples for every public Automation command. All commands work from any directory once the module is loaded into your PowerShell profile.

---

## Table of Contents

- [Setup (One-Time)](#setup-one-time)
- [Physical Server Build (End-to-End)](#physical-server-build-end-to-end)
- [ISO Build, Patching, Deployment, and Monitoring](#iso-build-patching-deployment-and-monitoring)
- [Maintenance Mode](#maintenance-mode)
- [Connectivity and Validation](#connectivity-and-validation)
- [PowerShell Execution and Utility](#powershell-execution-and-utility)
- [Routing and Control Surfaces](#routing-and-control-surfaces)
- [Troubleshooting](#troubleshooting)

---

## Setup (One-Time)

Run make setup from the project root to register the Automation module in your PowerShell profile:

```powershell
make setup
```

Then restart PowerShell or reload your profile:

```make
. $PROFILE
```

After this, every command below is available from any directory — no paths required.

Verify all commands are loaded:

```powershell
Get-Command -Module Automation
```

---

## Physical Server Build (End-to-End)

The full runbook workflow in one command: pre-build validation, ConfigMgr bootable ISO, publish to HTTPS, OneView target resolution, iLO Redfish mount + boot, installation monitoring, post-build validation, and audit logging.

### Full build (most common)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

### Dry run (validate without changing anything)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -DryRun
```

### Re-run after ISO already built (skip build phases)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -IloIp 10.0.1.50 -SkipPreBuild -SkipIsoBuild -SkipPublish -InMaintenanceWindow
```

### Re-run monitoring after deployment

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -SkipPreBuild -SkipIsoBuild -SkipPublish -SkipOneView -SkipMount -InMaintenanceWindow
```

### Build with custom domain and post-build checks

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 -ExpectedHostname srv01.corp.local -Domain corp.local -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local -InMaintenanceWindow
```

### Mock build (testing)

```powershell
Start-PhysicalServerBuild -ServerIdentifier srv01 -Mock
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-ServerIdentifier` | Yes | Server name, serial, OneView name, iLO IP, or bay | — |
| `-OneViewHost` | No | OneView appliance hostname or IP | — |
| `-IloIp` | No | Target iLO address or hostname | — |
| `-ExpectedHostname` | No | Post-build hostname | `$ServerIdentifier` |
| `-Domain` | No | AD domain for post-build check | — |
| `-SiteCode` | No | ConfigMgr site code (e.g. `P01`) | — |
| `-ManagementPoint` | No | ConfigMgr Management Point FQDN | — |
| `-DistributionPoint` | No | ConfigMgr Distribution Point FQDN | — |
| `-SiteServer` | No | ConfigMgr site server FQDN (PSRemoting fallback) | — |
| `-BootImageName` | No | Boot image name to embed | — |
| `-TaskSequenceName` | No | Task sequence name (informational) | — |
| `-RepoBaseUrl` | No | HTTPS base URL of the ISO repository | — |
| `-RepoLocalPath` | No | Local path mirrored to `-RepoBaseUrl` | — |
| `-MonitorTimeoutSeconds` | No | Max monitoring duration | `7200` |
| `-MonitorPollSeconds` | No | Poll interval | `30` |
| `-SkipPreBuild` | No | Skip pre-build validation | — |
| `-SkipIsoBuild` | No | Skip ISO creation | — |
| `-SkipPublish` | No | Skip ISO publishing | — |
| `-SkipOneView` | No | Skip OneView resolution | — |
| `-SkipMount` | No | Skip iLO mount and boot | — |
| `-SkipMonitor` | No | Skip installation monitoring | — |
| `-SkipPostBuild` | No | Skip post-build validation | — |
| `-Mock` | No | Mock all calls (implies `-DryRun`) | — |
| `-DryRun` | No | Validate and print plan only | — |
| `-Force` | No | Allow destructive `ForceRestart` | — |
| `-InMaintenanceWindow` | No | Acknowledge approved maintenance window | — |
| `-AllowUnknownIsoUrl` | No | Skip ISO URL reachability check | — |

**Returns:** `[hashtable]` with `Success`, `Steps`, and `AuditFile`.

---

## ISO Build, Patching, Deployment, and Monitoring

Individual commands for the ISO pipeline — build, publish, deploy, monitor, and patch.

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
| `-SiteCode` | Yes | ConfigMgr site code | — |
| `-ManagementPoint` | Yes | ConfigMgr Management Point FQDN | — |
| `-DistributionPoint` | Yes | ConfigMgr Distribution Point FQDN | — |
| `-OutputPath` | No | Full output path for the ISO | Auto-generated |
| `-VersionMajor` | No | Major version in filename | `1` |
| `-VersionMinor` | No | Minor version in filename | `0` |
| `-BootImageName` | No | Boot image name to embed | — |
| `-TaskSequenceName` | No | Task sequence name | — |
| `-SiteServer` | No | Site server FQDN (PSRemoting fallback) | — |
| `-DryRun` | No | Validate inputs only | — |

**Returns:** `[hashtable]` with `Success`, `IsoPath`, and `Metadata`.

---

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
| `-IsoPath` | Yes | Local path to the ISO file | — |
| `-RepoBaseUrl` | No | HTTPS base URL of the repository | `$env:ISO_REPO_BASE_URL` |
| `-RepoLocalPath` | No | Local path mirrored to the repository | `$env:ISO_REPO_LOCAL_PATH` |
| `-ForceOverwrite` | No | Overwrite existing ISO | — |
| `-SkipVerify` | No | Skip HTTPS HEAD check | — |
| `-DryRun` | No | Simulate only | — |

**Returns:** `[hashtable]` with `Success`, `PublicUrl`, `RepoPath`, and `Verified`.

---

### Deploy ISOs to servers

```powershell
Invoke-IsoDeploy -Server srv01 -IsoUrl 'https://artifacts/isos/WinSrv2025_v1.0.iso'
```

#### Bulk deploy to all servers

```powershell
Invoke-IsoDeploy
```

#### Dry run — see what would deploy

```powershell
Invoke-IsoDeploy -DryRun
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Method` | No | Deployment method (`redfish`) | `redfish` |
| `-Server` | No | Single server hostname | — |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-IsoDir` | No | Directory containing ISO packages | auto-resolved |
| `-IsoUrl` | No | Override the ISO URL | — |
| `-RepoBaseUrl` | No | HTTPS base URL of the ISO repository | — |
| `-DryRun` | No | Simulate only | — |

**Returns:** `[hashtable]` with `Success`, `Server`, and `Summary`.

---

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
| `-Server` | No | Single server hostname | — |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-TimeoutSeconds` | No | Max monitoring duration | `7200` |
| `-PollIntervalSeconds` | No | Seconds between polls | `30` |
| `-OpsRampConfig` | No | Path to OpsRamp config | auto-resolved |

**Returns:** `[hashtable]` with `Success`, per-server `Status`/`Details`, or bulk `Summary`.

---

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
| `-Server` | No | Single server hostname | — |
| `-ServerList` | No | Path to server list | auto-resolved |
| `-OutputDir` | No | Output directory | — |
| `-SkipDownload` | No | Skip component download | — |
| `-DryRun` | No | Simulate only | — |

**Returns:** `[hashtable]` with `Success` and details.

---

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
| `-BaseIsoPath` | No | Path to the base Windows Server ISO | — |
| `-Server` | No | Server hostname for output naming | — |
| `-PatchesConfig` | No | Path to patch manifest | auto-resolved |
| `-OutputDir` | No | Output directory | auto-resolved |
| `-Method` | No | Patching method: `dism` or `powershell` | `dism` |
| `-DryRun` | No | Simulate only | — |

**Returns:** `[hashtable]` with `Success`, `PatchedIso`, and details.

---

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
| `-OneViewHost` | No | OneView appliance hostname or IP | — |
| `-ServerIdentifier` | Yes | Server name, serial, iLO IP, or bay | — |
| `-IdentifierType` | No | `Auto`, `Name`, `Serial`, `OneViewName`, `IloIp`, `EnclosureBay` | `Auto` |
| `-OneViewUser` | No | OneView username | `$env:ONEVIEW_USER` |
| `-OneViewPassword` | No | OneView password | `$env:ONEVIEW_PASSWORD` |
| `-Port` | No | OneView HTTPS port | `443` |
| `-DryRun` | No | Print query without performing it | — |

**Returns:** `[hashtable]` with `Success`, `Server`, `ResolvedBy`, `Details`, and `Error`.

---

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
| `-Action` | Yes | `Mount`, `MountAndBoot`, `Boot`, `Reset`, `Eject`, `Status` | — |
| `-IloIp` | Yes | iLO IPv4 address or hostname | — |
| `-IloUser` | No | iLO username | `$env:ILO_USER` |
| `-IloPassword` | No | iLO password | `$env:ILO_PASSWORD` |
| `-IsoUrl` | No | HTTPS URL of the ISO (for `Mount`/`MountAndBoot`) | — |
| `-CdDeviceId` | No | Virtual media device ID | `1` |
| `-Force` | No | Confirm destructive actions | — |
| `-DryRun` | No | Print actions without performing them | — |

**Returns:** `[hashtable]` with `Success`, `Action`, `IloIp`, `Details`, and `Error`.

---

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
| `-ServerIdentifier` | Yes | Target server identifier | — |
| `-OneViewHost` | No | OneView appliance hostname or IP | — |
| `-IloIp` | No | Target iLO address | — |
| `-IsoUrl` | No | HTTPS URL of the bootable ISO | — |
| `-ManagementPoint` | No | ConfigMgr Management Point FQDN | — |
| `-DistributionPoint` | No | ConfigMgr Distribution Point FQDN | — |
| `-BootImageName` | No | Boot image name to verify | — |
| `-TaskSequenceName` | No | Task sequence name to verify | — |
| `-SkipOneView` | No | Skip OneView target check | — |
| `-SkipIlo` | No | Skip iLO credential check | — |
| `-SkipDpMp` | No | Skip MP/DP reachability checks | — |
| `-SkipIsoUrl` | No | Skip ISO URL reachability check | — |
| `-DryRun` | No | Validate inputs, skip network probes | — |

**Returns:** `[hashtable]` with `Success`, `Server`, `Timestamp`, and `Checks`.

---

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
Test-PostBuildValidation -Hostname srv01 -SkipRemote
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Hostname` | Yes | Target server hostname | — |
| `-ExpectedHostname` | No | Expected hostname for cross-check | `$Hostname` |
| `-Domain` | No | AD domain expected after build | — |
| `-ExpectedOsVersion` | No | Expected OS version string | — |
| `-SkipCmClient` | No | Skip ConfigMgr client checks | — |
| `-SkipDrivers` | No | Skip HPE driver presence check | — |
| `-SkipRemote` | No | Skip all WinRM-dependent checks | — |
| `-DryRun` | No | Assume checks pass | — |

**Returns:** `[hashtable]` with `Success`, `Hostname`, `Timestamp`, `Checks`, and `AuditFile`.

---

## Maintenance Mode

See [`CLIENT-QUICK-START.md`](CLIENT-QUICK-START.md) for the full guide.

### Examples

```powershell
Set-MaintenanceMode -Action enable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod -DryRun
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
Set-MaintenanceMode -Action disable -TargetId CLU-CLUSTER-01 -Mode scom -Environment Prod
```

---

## Connectivity and Validation

Pre-flight read-only checks. Safe to run during a change freeze.

### Test server connectivity

```powershell
Test-ServerConnectivity -Mode scom -Environment Prod
```

```powershell
Test-ServerConnectivity -Mode oneview -Environment Test
```

```powershell
Test-ServerConnectivity -ManagementHost myhost.corp.local
```

**Parameters:**

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `-Mode` | No | `scom` or `oneview` | — |
| `-Environment` | No | `Test` or `Prod` | — |
| `-ManagementHost` | No | Direct host override | — |
| `-ConfigDir` | No | Configuration directory | auto-resolved |
| `-PingTimeoutMs` | No | TCP connect timeout | `3000` |
| `-Json` | No | Output as JSON | — |
| `-JsonConfig` | No | Resolve host from `connection_hosts.json` | — |
| `-DryRun` | No | Return mock data | — |

**Returns:** `[hashtable]` with `Available`, `NetworkPing`, `AuthConnect`, and `Timestamp`.

---

### Validate server list

```powershell
Test-ServerList
```

**Returns:** `[hashtable]` with `Success` and `Servers`.

---

### Validate cluster ID

```powershell
Test-ClusterId -TargetId CLU-CLUSTER-01
```

**Returns:** `[hashtable]` with `Success`, `Cluster`, and `Error`.

---

### Validate build parameters

```powershell
Test-BuildParams -BaseIsoPath 'C:\isos\WinSrv2025.iso'
```

**Returns:** `[string[]]` — empty if valid, error messages otherwise.

---

## PowerShell Execution and Utility

Low-level helpers used by other commands.

### Run a local PowerShell script

```powershell
Invoke-PowerShellScript -Script 'Get-Process | Select-Object -First 5' -TimeoutSeconds 30
```

### Run a remote PowerShell script via WinRM

```powershell
Invoke-PowerShellWinRM -Script 'Get-Service wuauserv' -Server srv01
```

### Generate a deterministic UUID

```powershell
New-Uuid -ServerName srv01
```

### OpsRamp API client

```powershell
Invoke-OpsRampClient
```

### SCOM connection string

```powershell
New-ScomConnection -ManagementServer scom01.corp.local
```

---

## Routing and Control Surfaces

Dispatch requests to the appropriate handler.

### Orchestrator (unified entry point)

```powershell
Start-AutomationOrchestrator -RequestType build_iso -Params @{ SiteCode = 'P01'; ManagementPoint = 'mp01.corp.local' }
```

### View the route map

```powershell
Get-RouteMap
```

### Control surface factories and runners

```powershell
Run-CIPipeline -Params @{ Stage = 'build'; Version = '1.0' }
Run-IRequest -FormData @{ Action = 'enable'; TargetId = 'CLU-01' }
Run-Scheduler -TaskParams @{ Server = 'srv01'; Timeout = 3600 }
Run-GitLab -Params @{ TargetId = 'CLU-01'; Action = 'enable' }
```

### GitLab maintenance trigger

```powershell
Invoke-GitLabMaintenanceTrigger -TargetId CLU-CLUSTER-01 -Action enable -Start now -End +4hours
```

---

## Troubleshooting

### Command not found

```powershell
. $PROFILE
Get-Command -Module Automation
```

### Run setup again

```powershell
./scripts/Setup-Profile.ps1
```

### Check module is loaded

```powershell
Get-Module Automation
```

### Force reimport

```powershell
Import-Module (Get-ChildItem -Recurse -Filter 'Automation.psd1' -Path (Split-Path (Get-Command Setup-Profile).Source | Split-Path) | Select -First 1).FullName -Force
```

### Source links

[Generated API reference](dynamic-code-docs/INDEX.md) with per-command detail pages.
