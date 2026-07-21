# Runbook for automating the build of physical HPE servers

<a id="top"></a>
## Table of Contents

- [Purpose](#purpose)
- [Scope](#scope)
- [Assumptions and Design Principles](#assumptions-and-design-principles)
- [References](#references)
- [Roles and Responsibilities](#roles-and-responsibilities)
- [High-Level Architecture](#high-level-architecture)
- [Prerequisites](#prerequisites)
  - [Technical prerequisites](#technical-prerequisites)
  - [Access prerequisites](#access-prerequisites)
- [Media Strategy](#media-strategy)
- [Standard Operating Procedure](#standard-operating-procedure)
  - [Prepare or update the Windows Server build in Configuration Manager](#prepare-or-update-the-windows-server-build-in-configuration-manager)
  - [Create bootable media ISO](#create-bootable-media-iso)
  - [Publish the ISO for iLO consumption](#publish-the-iso-for-ilo-consumption)
  - [Mount ISO via HPE iLO and force one-time boot](#mount-iso-via-hpe-ilo-and-force-one-time-boot)
  - [Task sequence execution](#task-sequence-execution)
- [Validation Checklist](#validation-checklist)
  - [Pre-build validation](#pre-build-validation)
  - [In-build validation](#in-build-validation)
  - [Post-build validation](#post-build-validation)
- [Rollback / Recovery Procedure](#rollback-recovery-procedure)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Security and Control Requirements](#security-and-control-requirements)
- [Appendix A: Sample Automation Components](#appendix-a-sample-automation-components)
  - [Sample workflow components](#sample-workflow-components)
  - [Example file naming and versioning standard](#example-file-naming-and-versioning-standard)
- [Source Note](#source-note)
<a name="purpose"></a>
## Purpose

This runbook defines the standard process for automating the build of physical HPE servers using Microsoft Configuration Manager (ConfigMgr / MECM) and HPE OneView, with HPE iLO virtual media used as the remote boot mechanism where PXE boot is not available. The design supports HPE ProLiant rack servers and HPE Synergy compute modules.

<a name="scope"></a>
## Scope

- Deploy Windows Server to physical HPE hardware without PXE boot.
- Use Configuration Manager to create and maintain the boot image, OS image, drivers, task sequence, and deployment content.
- Use HPE OneView as the hardware inventory and targeting source for managed HPE ProLiant and Synergy servers.
- Use HPE iLO Redfish / virtual media operations to mount bootable media, set one-time boot, and start the build.
- Support both interactive operations and automation through scripts or pipelines.

<a name="assumptions-and-design-principles"></a>
## Assumptions and Design Principles

- Microsoft Configuration Manager current branch is available and operational.
- A valid Windows Server image and task sequence are maintained within Configuration Manager.
- The WinPE boot image includes all required network and storage drivers for the target HPE platforms.
- HPE OneView manages the target servers and can be queried through its REST API.
- HPE iLO network access is available from the automation host or orchestration pipeline.
- No PXE service is available on the deployment network.
- The target server can reach the required Configuration Manager infrastructure during build when using dynamic boot media.

<a name="references"></a>
## References

- [Microsoft Learn – Create bootable media Configuration Manager.](https://learn.microsoft.com/en-us/intune/configmgr/osd/deploy-use/create-bootable-media)
- [Microsoft Learn – Create task sequence media Configuration Manager.](https://learn.microsoft.com/en-us/intune/configmgr/osd/deploy-use/create-task-sequence-media)
- [Microsoft Learn – Introduction to operating system deployment in Configuration Manager.](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/introduction-to-operating-system-deployment)
- [Microsoft Learn – Prestart commands for task sequence media in Configuration Manager](https://learn.microsoft.com/en-us/intune/configmgr/osd/understand/prestart-commands-for-task-sequence-media)
- [Microsoft Learn – New-CMBootableMedia and New-CMPrestageMedia PowerShell cmdlets.](https://learn.microsoft.com/en-us/powershell/module/configurationmanager/new-cmbootablemedia?view=sccm-ps)
- [HPE OneView REST API Reference](https://support.hpe.com/docs/display/public/dp00006616en_us/index.html)
- [HPE Redfish examples – mount virtual media ISO, change boot order, and reboot server.](https://servermanagementportal.ext.hpe.com/docs/redfishclients/python-redfish-library/examples)

<a name="roles-and-responsibilities"></a>
## Roles and Responsibilities

| Role | Responsibility | Notes |
| --- | --- | --- |
| ConfigMgr Administrator | Maintain boot images, OS images, task sequences, drivers, distribution points, and deployment collections. | Owns OSD content and imaging standards. |
| OneView Administrator | Maintain accurate server inventory and API access for managed HPE hardware. | Ensures correct server identification and management state. |
| Server Engineering / Build Operator | Initiate and monitor the build workflow; validate pre-checks and post-build health. | Can be a human operator or a pipeline account. |
| Security / IAM | Provide and govern service account permissions and secret storage | Prefer secret vault / pipeline secrets; avoid hard-coded credentials. |
| Change Manager | Approve production builds and maintain CRQ traceability where required. | Recommended for controlled environments. |

<a name="high-level-architecture"></a>
## High-Level Architecture

The automation pattern uses Configuration Manager to generate bootable OSD media and task sequence content, HPE OneView to identify the target physical host, and HPE iLO to mount the boot ISO and force a one-time boot from virtual media. Once WinPE starts, the server retrieves task sequence policy and content from Configuration Manager and completes the operating system deployment.

1. Operator or pipeline identifies the target server by name, serial number, or OneView identifier.
2. Automation queries HPE OneView and validates the target server state.
3. Configuration Manager bootable media ISO is published to a secured repository reachable by iLO virtual media.
4. Automation mounts the ISO through iLO virtual media.
5. Automation sets one-time boot override to virtual CD/DVD and restarts the host.
6. WinPE starts and contacts Configuration Manager management/distribution infrastructure.
7. Task sequence partitions disk, applies operating system, installs drivers and ConfigMgr client, and performs post-install actions.
8. Server reboots to the newly deployed operating system and final validation is completed.

<a name="prerequisites"></a>
## Prerequisites

<a name="technical-prerequisites"></a>
### Technical prerequisites

- Configuration Manager console and PowerShell module installed on the administration host.
- Appropriate deployment task sequence created for the target Windows Server version.
- Boot image contains HPE-compatible NIC and storage drivers required in WinPE.
- All required task sequence content distributed to one or more distribution points.
- Target network permits access from WinPE / server to Management Point and Distribution Point as applicable.
- HPE OneView API credentials with rights to query server-hardware objects.
- HPE iLO credentials with rights to perform virtual media and power operations.
- Secure location to host bootable ISO (preferably HTTPS).

<a name="access-prerequisites"></a>
### Access prerequisites

- Change approval for production builds (if required by local process).
- Approved service accounts for OneView API and iLO access.
- Access to Configuration Manager site drive / PowerShell context sufficient to create task sequence media.
- Administrative access on the system used to create ConfigMgr media.

<a name="media-strategy"></a>
## Media Strategy

Preferred approach: use Configuration Manager bootable media (ISO) mounted over iLO virtual media. This is the most flexible option for environments without PXE because the server boots to WinPE from ISO and then retrieves the task sequence and required content from Configuration Manager. Alternative options include stand-alone media for restricted-network scenarios or prestaged media for depot/factory workflows.

- Preferred: Bootable media ISO – smallest and easiest to maintain; task sequence remains centrally managed.
- Alternative: Stand-alone media – suitable where network access to MP/DP is restricted during build; includes task sequence and content locally.
- Less preferred: Prestaged media – more appropriate for factory / preloaded disk scenarios than for remote iLO-led imaging.

<a name="standard-operating-procedure"></a>
## Standard Operating Procedure

<a name="prepare-or-update-the-windows-server-build-in-configuration-manager"></a>
### Prepare or update the Windows Server build in Configuration Manager

9.Import or update the Windows Server source image within Configuration Manager.  
1. Create or update the OSD task sequence for the target operating system build.  
2. Add or update HPE driver packages and ensure the required WinPE boot image contains the correct NIC and storage drivers.  
3. Distribute all associated content to at least one distribution point.  
4. Validate task sequence deployment scope (known / unknown computer support as required).  

```PWSH
# Example ConfigMgr media creation command:
New-CMBootableMedia -MediaMode Dynamic -MediaType CdDvd -Path "\\fileserver\osdmedia\WinSrv2025_BootMedia.iso" -AllowUnknownMachine -AllowUnattended -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaPassword $MediaPassword -Force
```

<a name="create-bootable-media-iso"></a>
### Create bootable media ISO

1. From the Configuration Manager console PowerShell context, create dynamic bootable media as an ISO.
2. Apply a media password where required by policy.
3. Store the ISO in a secured central repository.
4. Version the ISO according to the OSD release standard (for example: WinSrv2025_HPE_BootableMedia_v1.7.iso).

<a name="publish-the-iso-for-ilo-consumption"></a>
### Publish the ISO for iLO consumption

1. Place the ISO in a location accessible to iLO virtual media.
2. Prefer HTTPS with controlled access and auditable hosting.
3. Validate the full ISO path / URL before initiating the build.

10.4 Identify and validate the target server in HPE OneView

1. Query HPE OneView for the target physical server by name, serial number, Bay/Enclosure position, or other approved identifier.
2. Verify the hardware state, power state, and health state before proceeding.
3. Confirm the correct server has been selected and is approved for build / rebuild.
4. Resolve or derive the corresponding iLO management address or endpoint for the server.

```PWSH
# Example OneView REST query pattern:

GET https://<oneview-appliance>/rest/server-hardware?filter="name='<ServerName>'"
```

<a name="mount-iso-via-hpe-ilo-and-force-one-time-boot"></a>
### Mount ISO via HPE iLO and force one-time boot

1. Authenticate to the target iLO using a service account with virtual media and power control rights.
2. Insert the ConfigMgr bootable ISO as virtual media.
3. Set a one-time boot override to the virtual CD/DVD device.
4. Restart or power on the physical server.
5. Observe console output or iLO event logs to verify the host boots to WinPE.

```PWSH
# Example Redfish operations (conceptual):

POST /redfish/v1/Managers/1/VirtualMedia/<DeviceId>/Actions/VirtualMedia.InsertMedia
PATCH /redfish/v1/Systems/1   { BootSourceOverrideEnabled: "Once", BootSourceOverrideTarget: "Cd" }
POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset
```

<a name="task-sequence-execution"></a>
### Task sequence execution

1. WinPE starts from the bootable ISO.
2. he server connects to the Configuration Manager Management Point and downloads task sequence policy.
3. Disk partitioning and formatting are performed according to task sequence standards.
4. The operating system image is applied.
5. Drivers and the Configuration Manager client are installed.
6. Post-install steps execute, such as domain join, security baseline, management agent installation, and standard software configuration.
7. The system reboots into the installed operating system.
8. Post-build validation is completed and the build record is updated.

<a name="validation-checklist"></a>
## Validation Checklist

<a name="pre-build-validation"></a>
### Pre-build validation

- Correct target server identified in OneView.
- Target approved for imaging / rebuild.
- Task sequence and required content available in Configuration Manager.
- Boot image includes required HPE WinPE drivers.
- ISO path validated and reachable.
- Network path to MP/DP validated for the target VLAN or build network.
- iLO credentials verified.
- Configuration / change record created where required.

<a name="in-build-validation"></a>
### In-build validation

- ISO mounted successfully in iLO virtual media.
- One-time boot override applied.
- System boots to WinPE.
- Task sequence is visible / starts correctly.
- Disk operations complete successfully.
- OS image apply completes successfully.
- Task sequence reaches final restart with no blocking errors.

<a name="post-build-validation"></a>
### Post-build validation

- Expected hostname assigned.
- Domain join successful (if required).
- Correct OU placement or directory registration.
- Operating system version, edition, and patch baseline verified.
- Expected HPE device drivers present.
- Configuration Manager client healthy and assigned to site.
- RDP / PowerShell / management agents operational.
- Build outcome captured in operational records.

<a name="rollback-recovery-procedure"></a>
## Rollback / Recovery Procedure

1. If the task sequence fails before OS application, eject virtual media, reset boot order to normal, and investigate WinPE / network / driver issues.
2. If the task sequence fails after partial deployment, either rerun the build after remediation or wipe/reinitialize the local storage before retry.
3. If the wrong server was selected, stop the workflow immediately, eject media, cancel the change, and follow incident / change procedures.
4. If iLO virtual media operations fail, validate device index, iLO generation, ISO accessibility, and Redfish permission scope.

<a name="troubleshooting-guide"></a>
## Troubleshooting Guide

| Issue | Likely Cause | Recommended Action |
| --- | --- | --- |
| Server does not boot from ISO	One-time boot override not applied; | wrong virtual media device; ISO not mounted | Check iLO virtual media state, boot order override, and device ID; retry restart. |
| WinPE starts but no task sequence	Cannot reach MP/DP; task sequence not deployed; missing boundary/network path | Validate network path, task sequence deployment scope, boundary groups, and MP/DP availability. |
| WinPE has no network | Missing NIC driver in boot image | Inject correct HPE NIC driver into WinPE boot image and redistribute boot image. |
| Disk preparation fails | Storage controller driver missing or RAID not initialized | Validate Smart Array / RAID state and WinPE storage driver support. |
| OS installs but post-build steps fail	Package/app content issue; | domain join issue; variable problem | Review task sequence logs and validate packages, credentials, and variables. |
| Wrong target server built | Target validation failure | Stop process immediately and invoke incident/change process; improve pre-check controls. |

<a name="security-and-control-requirements"></a>
## Security and Control Requirements

- Do not hard-code production credentials in scripts.
- Store OneView and iLO credentials in a secure secret store or pipeline secret vault.
- Use Configuration Manager media passwords where appropriate.
- Restrict ISO repository access to approved systems and service accounts.
- Prefer trusted TLS certificates over certificate bypass methods used only in lab/testing.
- Maintain audit logs showing who initiated the build, which server was targeted, which ISO was used, and the final outcome.

<a name="appendix-a-sample-automation-components"></a>
## Appendix A: Sample Automation Components

<a name="sample-workflow-components"></a>
### Sample workflow components

- New-CM-BootMedia.ps1 – creates bootable media ISO in Configuration Manager.
- Get-OneView-ServerTarget.ps1 – retrieves and validates server object from OneView.
- Invoke-iLO-BootFromIso.ps1 – mounts ISO through Redfish, sets boot override, and restarts server.
- Start-PhysicalServerBuild.ps1 – wrapper/orchestrator script used manually or from a pipeline.

<a name="example-file-naming-and-versioning-standard"></a>
### Example file naming and versioning standard

- ISO: WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso
- Task Sequence: TS - WinSrv2025 - HPE - <Role>
- Build record ID: OSD-<YYYYMMDD>-<Sequence>

<a name="source-note"></a>
## Source Note

This runbook was prepared using documented platform capabilities for Configuration Manager task sequence media, bootable media / prestaged media, prestart commands, PowerShell media creation cmdlets, HPE OneView REST API automation, and HPE iLO Redfish virtual media / reboot workflows.
Citable source identifiers used in preparation: turn1search19, turn1search8, turn1search22, turn1search11, turn1search23, turn1search21, turn1search1, turn1search14, turn1search15.
