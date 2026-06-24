# Automation Command Reference

Complete reference for the public PowerShell automation commands in [`src/powershell/Automation/Public/`](../src/powershell/Automation/Public/). Each command is described at a functional level with its full parameter set. Source links point to the implementation files. For generated, example-rich help see [`dynamic-code-docs/INDEX.md`](dynamic-code-docs/INDEX.md).

---

## Table of Contents

- [Physical server build (ConfigMgr + OneView + iLO Redfish)](#physical-server-build-configmgr--oneview--ilo-redfish)
- [ISO build, patching, deployment, and monitoring](#iso-build-patching-deployment-and-monitoring)
- [Maintenance mode](#maintenance-mode)
- [Connectivity and validation](#connectivity-and-validation)
- [PowerShell execution and utility](#powershell-execution-and-utility)
- [Routing and control surfaces](#routing-and-control-surfaces)

---

## Physical server build (ConfigMgr + OneView + iLO Redfish)

These commands implement the runbook workflow defined in [`runbook-requirements.md`](runbook-requirements.md) and [`runbook-changes.md`](runbook-changes.md): build a ConfigMgr WinPE bootable ISO, publish it to an HTTPS repository, identify the target server through HPE OneView, mount the ISO via iLO Redfish, and validate the result.

### Start-PhysicalServerBuild

**Source:** [`src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1`](../src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1)

End-to-end orchestrator. Runs pre-build validation, ISO creation, ISO publishing, OneView resolution, iLO mount/boot, installation monitoring, post-build validation, and audit logging. Skip switches allow individual phases to be re-run.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ServerIdentifier` | **Required** `[string]` | — | Target server name, serial, OneView name, iLO IP, or bay position. |
| `-OneViewHost` | Optional `[string]` | — | HPE OneView appliance hostname or IP. |
| `-IloIp` | Optional `[string]` | — | Target iLO IPv4 address or hostname. |
| `-ExpectedHostname` | Optional `[string]` | `$ServerIdentifier` | Hostname expected after the build. |
| `-Domain` | Optional `[string]` | — | Active Directory domain to verify during post-build validation. |
| `-SiteCode` | Optional `[string]` | — | Configuration Manager site code (e.g. `P01`). |
| `-ManagementPoint` | Optional `[string]` | — | ConfigMgr Management Point FQDN. |
| `-DistributionPoint` | Optional `[string]` | — | ConfigMgr Distribution Point FQDN. |
| `-SiteServer` | Optional `[string]` | — | ConfigMgr site server FQDN for PSRemoting fallback. |
| `-BootImageName` | Optional `[string]` | — | ConfigMgr boot image name to embed. |
| `-TaskSequenceName` | Optional `[string]` | — | Optional task sequence name (informational). |
| `-RepoBaseUrl` | Optional `[string]` | — | HTTPS base URL of the ISO repository. |
| `-RepoLocalPath` | Optional `[string]` | — | Local filesystem path mirrored to `-RepoBaseUrl`. |
| `-MonitorTimeoutSeconds` | Optional `[int]` | `7200` | Maximum monitoring duration in seconds. |
| `-MonitorPollSeconds` | Optional `[int]` | `30` | Monitoring poll interval in seconds. |
| `-SkipPreBuild` | `[switch]` | — | Skip pre-build validation. |
| `-SkipIsoBuild` | `[switch]` | — | Skip ISO creation. |
| `-SkipPublish` | `[switch]` | — | Skip ISO publishing. |
| `-SkipOneView` | `[switch]` | — | Skip OneView target resolution. |
| `-SkipMount` | `[switch]` | — | Skip iLO mount and boot. |
| `-SkipMonitor` | `[switch]` | — | Skip installation monitoring. |
| `-SkipPostBuild` | `[switch]` | — | Skip post-build validation. |
| `-Mock` | `[switch]` | — | Run with mocked calls; implies `-DryRun`. |
| `-DryRun` | `[switch]` | — | Validate and print plan without side effects. |
| `-Force` | `[switch]` | — | Confirm the destructive `ForceRestart` action. |
| `-InMaintenanceWindow` | `[switch]` | — | Acknowledge an approved maintenance window. |
| `-AllowUnknownIsoUrl` | `[switch]` | — | Skip ISO URL reachability verification. |

**Returns:** `[hashtable]` with `Success`, `Steps`, and `AuditFile`.

---

### New-IsoBuild

**Source:** [`src/powershell/Automation/Public/New-IsoBuild.ps1`](../src/powershell/Automation/Public/New-IsoBuild.ps1)

Builds a Configuration Manager bootable media ISO (WinPE) for physical server deployment. Auto-detects a local `ConfigurationManager` module or falls back to PSRemoting against the ConfigMgr site server.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-OutputPath` | Optional `[string]` | Auto-generated | Full output path for the ISO file. |
| `-VersionMajor` | Optional `[int]` | `1` | Major version embedded in the filename. |
| `-VersionMinor` | Optional `[int]` | `0` | Minor version embedded in the filename. |
| `-SiteCode` | **Required** `[string]` | — | ConfigMgr site code. |
| `-ManagementPoint` | **Required** `[string]` | — | ConfigMgr Management Point FQDN. |
| `-DistributionPoint` | **Required** `[string]` | — | ConfigMgr Distribution Point FQDN. |
| `-BootImageName` | Optional `[string]` | — | Name of the boot image to embed. |
| `-TaskSequenceName` | Optional `[string]` | — | Optional task sequence name. |
| `-SiteServer` | Optional `[string]` | — | Site server FQDN for PSRemoting fallback. |
| `-SiteServerUser` | Optional `[string]` | `$env:CM_SITE_USER` | Username for PSRemoting. |
| `-SiteServerPassword` | Optional `[string]` | `$env:CM_SITE_PASSWORD` | Password for PSRemoting. |
| `-MediaPassword` | Optional `[string]` | `$env:CM_MEDIA_PASSWORD` | Optional boot media password. |
| `-AllowUnknownMachine` | Optional `[bool]` | `$true` | Pass `-AllowUnknownMachine` to `New-CMBootableMedia`. |
| `-AllowUnattended` | Optional `[bool]` | `$true` | Pass `-AllowUnattended` to `New-CMBootableMedia`. |
| `-SkipCertificateCheck` | Optional `[bool]` | `$true` | Skip SSL certificate verification for PSRemoting. |
| `-MockIsoPath` | Optional `[string]` | — | Path to a placeholder ISO file for testing. |
| `-DryRun` | `[switch]` | — | Validate inputs and print plan without creating the ISO. |

**Returns:** `[hashtable]` with `Success`, `IsoPath`, and `Metadata`.

---

### Publish-BootIso

**Source:** [`src/powershell/Automation/Public/Publish-BootIso.ps1`](../src/powershell/Automation/Public/Publish-BootIso.ps1)

Publishes a ConfigMgr bootable ISO to an HTTPS repository so that iLO Redfish can mount it. Performs an HTTP HEAD check by default.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-IsoPath` | **Required** `[string]` | — | Local path to the ISO file. |
| `-RepoBaseUrl` | Optional `[string]` | `$env:ISO_REPO_BASE_URL` | HTTPS base URL of the repository. |
| `-RepoLocalPath` | Optional `[string]` | `$env:ISO_REPO_LOCAL_PATH` | Local filesystem path mirrored to the repository. |
| `-ForceOverwrite` | `[switch]` | — | Overwrite an existing ISO with the same filename. |
| `-SkipVerify` | `[switch]` | — | Skip the HTTPS HEAD reachability check. |
| `-DryRun` | `[switch]` | — | Simulate without copying or verifying. |

**Returns:** `[hashtable]` with `Success`, `PublicUrl`, `RepoPath`, and `Verified`.

---

### Get-OneViewServerTarget

**Source:** [`src/powershell/Automation/Public/Get-OneViewServerTarget.ps1`](../src/powershell/Automation/Public/Get-OneViewServerTarget.ps1)

Queries HPE OneView to identify and validate a target physical server. Accepts several identifier types and validates that server health is acceptable.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-OneViewHost` | Optional `[string]` | — | OneView appliance hostname or IP. |
| `-ServerIdentifier` | **Required** `[string]` | — | Server name, serial, OneView name, iLO IP, or bay/enclosure position. |
| `-IdentifierType` | Optional `[string]` | `Auto` | Search hint: `Auto`, `Name`, `Serial`, `OneViewName`, `IloIp`, or `EnclosureBay`. |
| `-OneViewUser` | Optional `[string]` | `$env:ONEVIEW_USER` | OneView username. |
| `-OneViewPassword` | Optional `[string]` | `$env:ONEVIEW_PASSWORD` | OneView password. |
| `-Port` | Optional `[int]` | `443` | OneView HTTPS port. |
| `-SkipCertificateCheck` | Optional `[bool]` | `$true` | Skip SSL certificate verification. |
| `-TimeoutSec` | Optional `[int]` | `30` | Per-call timeout in seconds. |
| `-MockResult` | Optional `[hashtable]` | — | Return value used in place of a live API call. |
| `-DryRun` | `[switch]` | — | Print the query without performing it. |

**Returns:** `[hashtable]` with `Success`, `Server`, `ResolvedBy`, `Details`, and `Error`.

---

### Invoke-IloRedfish

**Source:** [`src/powershell/Automation/Public/Invoke-IloRedfish.ps1`](../src/powershell/Automation/Public/Invoke-IloRedfish.ps1)

Performs iLO 5/6 Redfish operations: session authentication, virtual media insert/eject, one-time boot override to CD, and system reset.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Action` | **Required** `[string]` | — | Operation: `Mount`, `MountAndBoot`, `Boot`, `Reset`, `Eject`, or `Status`. |
| `-IloIp` | **Required** `[string]` | — | iLO IPv4 address or hostname. |
| `-IloUser` | Optional `[string]` | `$env:ILO_USER` | iLO username. |
| `-IloPassword` | Optional `[string]` | `$env:ILO_PASSWORD` | iLO password. |
| `-IsoUrl` | Optional `[string]` | — | HTTPS URL of the ISO file (required for `Mount`/`MountAndBoot`). |
| `-CdDeviceId` | Optional `[int]` | `1` | Virtual media device ID. |
| `-SkipCertificateCheck` | Optional `[bool]` | `$true` | Skip SSL certificate verification. |
| `-TimeoutSec` | Optional `[int]` | `30` | Per-call timeout in seconds. |
| `-Force` | `[switch]` | — | Confirm destructive actions (`MountAndBoot`, `Boot`, `Reset`). |
| `-DryRun` | `[switch]` | — | Print actions without performing them. |

**Returns:** `[hashtable]` with `Success`, `Action`, `IloIp`, `Details`, and `Error`.

---

### Test-PreBuildValidation

**Source:** [`src/powershell/Automation/Public/Test-PreBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PreBuildValidation.ps1)

Runs the runbook pre-build validation checklist: OneView target, ISO URL reachability, iLO credentials, MP/DP reachability, and audit recording.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ServerIdentifier` | **Required** `[string]` | — | Target server identifier. |
| `-OneViewHost` | Optional `[string]` | — | OneView appliance hostname or IP. |
| `-IloIp` | Optional `[string]` | — | Target iLO address or hostname. |
| `-IsoUrl` | Optional `[string]` | — | HTTPS URL of the bootable ISO. |
| `-ManagementPoint` | Optional `[string]` | — | ConfigMgr Management Point FQDN. |
| `-DistributionPoint` | Optional `[string]` | — | ConfigMgr Distribution Point FQDN. |
| `-BootImageName` | Optional `[string]` | — | Boot image name to verify. |
| `-TaskSequenceName` | Optional `[string]` | — | Task sequence name to verify. |
| `-SkipOneView` | `[switch]` | — | Skip the OneView target check. |
| `-SkipIlo` | `[switch]` | — | Skip the iLO credential check. |
| `-SkipDpMp` | `[switch]` | — | Skip MP/DP reachability checks. |
| `-SkipIsoUrl` | `[switch]` | — | Skip ISO URL reachability check. |
| `-DryRun` | `[switch]` | — | Validate inputs but skip network probes. |

**Returns:** `[hashtable]` with `Success`, `Server`, `Timestamp`, and `Checks`.

---

### Test-PostBuildValidation

**Source:** [`src/powershell/Automation/Public/Test-PostBuildValidation.ps1`](../src/powershell/Automation/Public/Test-PostBuildValidation.ps1)

Connects to the freshly-built server over WinRM and verifies hostname, domain join, OS version, HPE drivers, ConfigMgr client health, and management services.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Hostname` | **Required** `[string]` | — | Target server hostname. |
| `-ExpectedHostname` | Optional `[string]` | `$Hostname` | Expected hostname for cross-check. |
| `-Domain` | Optional `[string]` | — | AD domain expected after build. |
| `-ExpectedOsVersion` | Optional `[string]` | — | Expected OS version string. |
| `-SkipCmClient` | `[switch]` | — | Skip ConfigMgr client checks. |
| `-SkipDrivers` | `[switch]` | — | Skip HPE driver presence check. |
| `-SkipRemote` | `[switch]` | — | Skip all WinRM-dependent checks. |
| `-DryRun` | `[switch]` | — | Assume checks pass without WinRM probes. |

**Returns:** `[hashtable]` with `Success`, `Hostname`, `Timestamp`, `Checks`, and `AuditFile`.

---

### Start-InstallMonitor

**Source:** [`src/powershell/Automation/Public/Start-InstallMonitor.ps1`](../src/powershell/Automation/Public/Start-InstallMonitor.ps1)

Polls iLO Redfish and WinRM to track Windows installation progress. Emits progress metrics and alerts to OpsRamp.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Server` | Optional `[string]` | — | Monitor a single server only. |
| `-ServerList` | Optional `[string]` | `configs\server_list.txt` | Path to the server list file. |
| `-TimeoutSeconds` | Optional `[int]` | `7200` | Maximum monitoring duration in seconds. |
| `-PollIntervalSeconds` | Optional `[int]` | `30` | Seconds between polls. |
| `-OpsRampConfig` | Optional `[string]` | `configs\opsramp_config.json` | Path to the OpsRamp configuration file. |

**Returns:** `[hashtable]` with `Success` and either per-server `Status`/`Details` or a bulk `Summary`.

---

## ISO build, patching, deployment, and monitoring

Commands for the older/custom ISO pipeline (firmware ISOs, Windows patching, bulk ISO deployment) and installation monitoring.

### Update-Firmware

**Source:** [`src/powershell/Automation/Public/Update-Firmware.ps1`](../src/powershell/Automation/Public/Update-Firmware.ps1)

Builds HPE firmware/driver ISOs using the Smart Update Tool (SUT) and the firmware manifest.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Config` | Optional `[string]` | `configs\hpe_firmware_drivers_nov2025.json` | Path to the firmware manifest. |
| `-Server` | Optional `[string]` | — | Build for a specific server only. |
| `-ServerList` | Optional `[string]` | — | Path to `server_list.txt`. |
| `-OutputDir` | Optional `[string]` | — | Output directory. |
| `-SkipDownload` | `[switch]` | — | Skip component download. |
| `-DryRun` | `[switch]` | — | Simulate without executing. |

**Returns:** `[hashtable]` with `Success` and details.

---

### Invoke-WindowsSecurityUpdate

**Source:** [`src/powershell/Automation/Public/Update-WindowsSecurity.ps1`](../src/powershell/Automation/Public/Update-WindowsSecurity.ps1)

Applies Windows security patches to a base Windows Server ISO using DISM or PowerShell DISM, producing a patched ISO.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-BaseIsoPath` | Optional `[string]` | — | Path to the base Windows Server ISO. |
| `-Server` | Optional `[string]` | — | Server hostname for output naming. |
| `-PatchesConfig` | Optional `[string]` | `configs\windows_patches.json` | Path to the patch manifest. |
| `-OutputDir` | Optional `[string]` | `output\patched` | Output directory. |
| `-Method` | Optional `[string]` | `dism` | Patching method: `dism` or `powershell`. |
| `-DryRun` | `[switch]` | — | Simulate without making changes. |

**Returns:** `[hashtable]` with `Success`, `PatchedIso`, and details.

---

### Invoke-IsoDeploy

**Source:** [`src/powershell/Automation/Public/Invoke-IsoDeploy.ps1`](../src/powershell/Automation/Public/Invoke-IsoDeploy.ps1)

Bulk deployment orchestrator. Resolves each server's iLO IP from `server_list.txt`, locates the bootable ISO package, and delegates the mount/boot to `Invoke-IloRedfish`.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Method` | Optional `[string]` | `redfish` | Deployment method (only `redfish` supported). |
| `-Server` | Optional `[string]` | — | Deploy to a single named server only. |
| `-ServerList` | Optional `[string]` | `configs\server_list.txt` | Path to the server list file. |
| `-IsoDir` | Optional `[string]` | `output\bootable_media` | Directory containing ISO packages. |
| `-IsoUrl` | Optional `[string]` | — | Override the ISO URL. |
| `-RepoBaseUrl` | Optional `[string]` | — | HTTPS base URL used with the ISO filename from metadata. |
| `-DryRun` | `[switch]` | — | Simulate without deploying. |

**Returns:** `[hashtable]` with `Success`, `Server`, and `Summary`.

---

## Maintenance mode

Commands for SCOM and HPE OneView maintenance-mode orchestration and GitLab-triggered maintenance.

### Set-MaintenanceMode

**Source:** [`src/powershell/Automation/Public/Set-MaintenanceMode.ps1`](../src/powershell/Automation/Public/Set-MaintenanceMode.ps1)

Enables, disables, or validates maintenance mode for clusters or individual servers in SCOM 2015 or HPE OneView.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Action` | Optional `[string]` | `enable` | Operation: `enable`, `disable`, or `validate`. |
| `-TargetId` | Optional `[string]` | — | Cluster ID or server name. |
| `-Mode` | Optional `[string]` | — | `scom` or `oneview`. |
| `-Environment` | Optional `[string]` | — | `Test` or `Prod`. |
| `-ManagementHost` | Optional `[string]` | — | Override management server/appliance. |
| `-SerialNumber` | Optional `[string]` | — | OneView only: look up server by serial number. |
| `-Username` | Optional `[string]` | — | Direct username (testing only). |
| `-PostDisableWaitSeconds` | Optional `[int]` | `120` | Stabilization wait after SCOM disable. |
| `-ConfigDir` | Optional `[string]` | `configs` | Configuration directory. |
| `-Start` | Optional `[string]` | — | Maintenance window start (UTC). |
| `-End` | Optional `[string]` | — | Maintenance window end (UTC). |
| `-DryRun` | `[switch]` | — | Simulate without making changes. |
| `-MockMaintenanceState` | Optional `[string]` | `disable` | Dry-run validate status: `enable`, `disable`, or `partial`. |
| `-NoSchedule` | `[switch]` | — | Skip scheduled task creation. |
| `-Json` | `[switch]` | — | Output as JSON. |
| `-ShowHelp` | `[switch]` | — | Display built-in help. |

**Returns:** `[hashtable]` with `Success`, `Message`, `AuditFile`, mode-specific fields, and other details.

---

### New-ScomMaintenanceScript

**Source:** [`src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-ScomMaintenanceScript.ps1)

Generates a PowerShell script string for SCOM maintenance mode start/stop.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-GroupDisplayName` | Optional `[string]` | — | SCOM group display name (group mode). |
| `-ServerHostnames` | Optional `[array]` | — | Server hostnames (cluster mode). |
| `-EndTimeStr` | Optional `[string]` | — | Maintenance end time (ISO-8601). |
| `-Reason` | Optional `[string]` | `PlannedOther` | Maintenance reason. |
| `-Comment` | Optional `[string]` | — | Maintenance comment. |
| `-Operation` | Optional `[string]` | `start` | `start` or `stop`. |
| `-UseClusterMode` | `[switch]` | — | Operate at the cluster class level. |

**Returns:** `[string]` PowerShell script.

---

### New-OneViewMaintenanceScript

**Source:** [`src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1`](../src/powershell/Automation/Public/New-OneViewMaintenanceScript.ps1)

Generates a PowerShell script string for HPE OneView maintenance mode operations.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Appliance` | Optional `[string]` | — | OneView appliance hostname or IP. |
| `-ScopeName` | Optional `[string]` | — | OneView scope containing server hardware. |
| `-Operation` | Optional `[string]` | — | `enable` or `disable`. |
| `-Async` | Optional `[bool]` | `$true` | Use `-Async` for bulk operations. |
| `-ModuleName` | Optional `[string]` | — | HPE OneView module name (e.g. `HPEOneView.860`). |

**Returns:** `[string]` PowerShell script.

---

### Invoke-GitLabMaintenanceTrigger

**Source:** [`src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1`](../src/powershell/Automation/Public/Invoke-GitLabMaintenanceTrigger.ps1)

Initiates a GitLab CI/CD pipeline for maintenance operations instead of executing directly.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-TargetId` | Optional `[string]` | — | Cluster or server identifier. |
| `-Action` | Optional `[string]` | — | `enable`, `disable`, or `validate`. |
| `-Start` | Optional `[string]` | — | Maintenance window start (ISO-8601). |
| `-End` | Optional `[string]` | — | Maintenance window end (ISO-8601). |
| `-ConfigDir` | Optional `[string]` | `configs` | Configuration directory. |
| `-DryRun` | `[switch]` | — | Validate without executing. |
| `-GitLabUrl` | Optional `[string]` | `$env:GITLAB_URL` | GitLab instance URL. |
| `-ProjectId` | Optional `[string]` | `$env:GITLAB_PROJECT_ID` | GitLab project ID. |
| `-TriggerToken` | Optional `[string]` | `$env:GITLAB_TRIGGER_TOKEN` | CI trigger token. |
| `-GitRef` | Optional `[string]` | `main` | Git branch/ref to trigger. |
| `-CallbackUrl` | Optional `[string]` | `$env:MAINTENANCE_CALLBACK_URL` | Completion callback URL. |
| `-CallbackApiKey` | Optional `[string]` | `$env:MAINTENANCE_API_KEY` | Callback API key. |
| `-TimeoutSeconds` | Optional `[int]` | `600` | Pipeline wait timeout. |
| `-JobToken` | Optional `[string]` | `$env:GITLAB_JOB_TOKEN` | GitLab job token. |

**Returns:** `[hashtable]` with pipeline details or validation result.

---

## Connectivity and validation

Read-only and pre-flight commands used before executing changes.

### Test-ServerConnectivity

**Source:** [`src/powershell/Automation/Public/Test-ServerConnectivity.ps1`](../src/powershell/Automation/Public/Test-ServerConnectivity.ps1)

Performs a DNS/TCP probe and an authentication connect against SCOM or OneView. Safe to run during a change freeze.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Mode` | Optional `[string]` | — | `scom` or `oneview`. |
| `-Environment` | Optional `[string]` | — | `Test` or `Prod` (used with `-JsonConfig`). |
| `-ManagementHost` | Optional `[string]` | — | Direct host override. |
| `-ConfigDir` | Optional `[string]` | `configs` | Configuration directory. |
| `-PingTimeoutMs` | Optional `[int]` | `3000` | TCP connect timeout. |
| `-Json` | `[switch]` | — | Output as JSON. |
| `-JsonConfig` | `[switch]` | — | Resolve host from `connection_hosts.json`. |
| `-DryRun` | `[switch]` | — | Return mock data without network calls. |

**Returns:** `[hashtable]` with `Available`, `NetworkPing`, `AuthConnect`, and `Timestamp`.

---

### Test-ServerList

**Source:** [`src/powershell/Automation/Public/Test-ServerList.ps1`](../src/powershell/Automation/Public/Test-ServerList.ps1)

Reads and validates the server list text file.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ServerListPath` | Optional `[string]` | `configs\server_list.txt` | Path to the server list file. |

**Returns:** `[hashtable]` with `Success` and `Servers`.

---

### Test-ClusterId

**Source:** [`src/powershell/Automation/Public/Test-ClusterId.ps1`](../src/powershell/Automation/Public/Test-ClusterId.ps1)

Validates that a cluster ID exists in `clusters_catalogue.json` and has required fields.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-TargetId` | Optional `[string]` | — | Cluster identifier. |
| `-CataloguePath` | Optional `[string]` | `configs\clusters_catalogue.json` | Path to the catalogue. |

**Returns:** `[hashtable]` with `Success`, `Cluster`, and `Error`.

---

### Test-BuildParams

**Source:** [`src/powershell/Automation/Public/Test-BuildParams.ps1`](../src/powershell/Automation/Public/Test-BuildParams.ps1)

Validates build prerequisites, such as the existence of a base ISO path.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-BaseIsoPath` | Optional `[string]` | — | Path to the base Windows ISO. |
| `-DryRun` | `[switch]` | — | Skip additional validation. |

**Returns:** `[string[]]` — empty if valid, otherwise error messages.

---

## PowerShell execution and utility

Low-level execution helpers and utilities used by other commands.

### Invoke-PowerShellScript

**Source:** [`src/powershell/Automation/Public/Invoke-PowerShellScript.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellScript.ps1)

Runs a PowerShell script in a new local process with timeout and output capture.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Script` | Optional `[string]` | — | PowerShell script to execute. |
| `-CaptureOutput` | Optional `[bool]` | `$true` | Capture stdout/stderr. |
| `-TimeoutSeconds` | Optional `[int]` | `300` | Per-script timeout. |
| `-ExecutionPolicy` | Optional `[string]` | `Bypass` | Execution policy override. |

**Returns:** `[hashtable]` with `Success` and `Output`.

---

### Invoke-PowerShellWinRM

**Source:** [`src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1`](../src/powershell/Automation/Public/Invoke-PowerShellWinRM.ps1)

Executes a PowerShell script on a remote server via WinRM.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-Script` | Optional `[string]` | — | PowerShell script to execute remotely. |
| `-Server` | Optional `[string]` | — | Remote hostname or IP. |
| `-Username` | Optional `[string]` | — | WinRM username. |
| `-Password` | Optional `[string]` | — | WinRM password. |
| `-Transport` | Optional `[string]` | `NTLM` | WinRM transport. |
| `-TimeoutSeconds` | Optional `[int]` | `300` | Timeout per command. |

**Returns:** `[hashtable]` with `Success` and `Output`.

---

### New-Uuid

**Source:** [`src/powershell/Automation/Public/New-Uuid.ps1`](../src/powershell/Automation/Public/New-Uuid.ps1)

Generates a deterministic UUID from a server name and timestamp using SHA-256.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ServerName` | Optional `[string]` | — | Server hostname or identifier. |
| `-Timestamp` | Optional `[string]` | Current UTC | ISO-8601 timestamp. |
| `-OutputPath` | Optional `[string]` | — | Optional file path to write the UUID. |

**Returns:** `[guid]` (or written to file).

---

### Invoke-OpsRampClient

**Source:** [`src/powershell/Automation/Public/Invoke-OpsRampClient.ps1`](../src/powershell/Automation/Public/Invoke-OpsRampClient.ps1)

Factory/connection test for the OpsRamp API client.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ConfigPath` | Optional `[string]` | — | Path to `opsramp_config.json`. |

**Returns:** `[OpsRamp_Client]` instance or connectivity boolean via `Invoke-OpsRamp`.

---

### New-ScomConnection

**Source:** [`src/powershell/Automation/Public/New-ScomConnection.ps1`](../src/powershell/Automation/Public/New-ScomConnection.ps1)

Returns a PowerShell command string that creates an SCOM management-group connection.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-ManagementServer` | Optional `[string]` | — | SCOM management server hostname or IP. |

**Returns:** `[string]` PowerShell command.

---

## Routing and control surfaces

Commands that dispatch, introspect, or adapt external surfaces to the orchestrator.

### Start-AutomationOrchestrator

**Source:** [`src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1`](../src/powershell/Automation/Public/Start-AutomationOrchestrator.ps1)

Unified entry point. Validates a request and routes it to the appropriate handler.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-RequestType` | **Required** `[string]` | — | Request type (see `request_types.json`). |
| `-Params` | Optional `[hashtable]` | `@{}` | Parameters forwarded to the handler. |

**Returns:** `[hashtable]` with `Success`, `Output`/`Error`, `RequestType`, and `Timestamp`.

---

### Invoke-RoutedRequest

**Source:** [`src/powershell/Automation/Private/Router.ps1`](../src/powershell/Automation/Private/Router.ps1)

Dispatches a request to its handler based on the routing table loaded from `request_types.json`.

| Parameter | Required / Type | Default | Description |
| --- | --- | --- | --- |
| `-RequestType` | **Required** `[string]` | — | Request type to dispatch. |
| `-Params` | Optional `[hashtable]` | `@{}` | Parameters passed to the handler. |

**Returns:** `[hashtable]` with at least `Success` and `Output`/`Error`.

---

### Get-RouteMap

**Source:** [`src/powershell/Automation/Public/Get-RouteMap.ps1`](../src/powershell/Automation/Public/Get-RouteMap.ps1)

Returns the current request-type to handler-function routing table.

**Parameters:** none.

**Returns:** `[hashtable]` mapping request type strings to handler function names.

---

### Control surface factories and runners

**Source:** [`src/powershell/Automation/Public/Control.ps1`](../src/powershell/Automation/Public/Control.ps1)

Adapter functions for CI pipelines, iRequest/ISAPI, scheduled tasks, and GitLab CI/CD. Each runner accepts a hashtable, maps it to an orchestrator request type, and executes it.

| Command | Parameters | Purpose |
| --- | --- | --- |
| `New-CIPipelineCtrl` | `-Params` `[hashtable]` (required) | Factory for CI pipeline request object. |
| `Run-CIPipeline` | `-Params` `[hashtable]` (pipeline) | Run CI pipeline stage request. |
| `New-IRequestCtrl` | `-FormData` `[hashtable]` (required) | Factory for iRequest maintenance object. |
| `Run-IRequest` | `-FormData` `[hashtable]` (pipeline) | Execute iRequest maintenance action. |
| `New-SchedulerCtrl` | `-TaskParams` `[hashtable]` (required) | Factory for scheduled-task object. |
| `Run-Scheduler` | `-TaskParams` `[hashtable]` (pipeline) | Execute scheduled task request. |
| `New-GitLabCtrl` | `-Params` `[hashtable]` (required) | Factory for GitLab maintenance trigger object. |
| `Run-GitLab` | `-Params` `[hashtable]` (pipeline) | Trigger GitLab CI/CD pipeline for maintenance. |

All runners return a `[hashtable]` result envelope from the orchestrator.
