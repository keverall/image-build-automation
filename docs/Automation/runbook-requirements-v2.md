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
  - [Prepare the client-supplied ISO, answer file, and firmware](#prepare-the-client-supplied-iso-answer-file-and-firmware)
  - [Publish the ISO and firmware for iLO consumption](#publish-the-iso-and-firmware-for-ilo-consumption)
  - [Resolve the target server via HPE OneView](#resolve-the-target-server-via-hpe-oneview)
  - [Mount ISO via HPE iLO and force one-time boot](#mount-iso-via-hpe-ilo-and-force-one-time-boot)
  - [OS installation (Windows Setup)](#os-installation-windows-setup)
  - [Post-OS firmware update (HPE SUT)](#post-os-firmware-update-hpe-sut)
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

<a id="purpose"></a>

## Purpose

This runbook defines the standard process for automating the build of physical HPE servers where the operating system image and its unattended configuration are supplied by the client. The build is driven by HPE iLO virtual media: a client-provided Windows Server ISO (containing an `autounattend.xml` answer file for disk format, partitioning, locale, and keyboard layout) is mounted remotely and booted once, after which Windows Setup performs the installation. HPE OneView is used for target identification, inventory, and maintenance-mode orchestration. After the OS is installed, HPE firmware from client-supplied firmware folders is applied using HPE Smart Update Tools (SUT).

> **Correction note (v2):** The earlier draft assumed Configuration Manager (ConfigMgr / MECM) would create and manage bootable media and a task sequence. In this environment there is **no Configuration Manager** and no image repository. The client supplies a complete, pre-built Windows Server ISO plus an answer file and a set of firmware folders. All automation therefore centres on iLO virtual media and OneView, not ConfigMgr.

<a id="scope"></a>

## Scope

- Deploy Windows Server to physical HPE hardware without PXE boot.
- Use the client-supplied Windows Server ISO as the install source; Windows Setup reads the embedded answer file for disk layout, locale, and regional settings.
- Use HPE OneView as the hardware inventory and targeting source for managed HPE ProLiant and Synergy servers, and to place the target into maintenance mode during the build.
- Use HPE iLO Redfish / virtual media operations to mount the client ISO, set one-time boot, and start the build.
- Apply HPE firmware from client-supplied firmware folders **after** the OS install completes, using HPE SUT.
- Support both interactive operations and automation through scripts or pipelines.
- **Out of scope:** Configuration Manager (ConfigMgr / MECM) bootable-media creation, task sequences, and distribution points. These are explicitly **not** used in this environment.

<a id="assumptions-and-design-principles"></a>

## Assumptions and Design Principles

- The client provides a valid, bootable Windows Server ISO.
- The ISO embeds an `autounattend.xml` answer file that performs disk cleaning/formatting, partitioning, locale, keyboard layout, and any required OS-level defaults (e.g. domain join, local/admin configuration) without interactive input.
- The client provides a set of firmware folders (or `.zip` packages) containing the latest HPE firmware for the target platform.
- HPE OneView manages the target servers and can be queried through its REST API.
- HPE iLO network access is available from the automation host or orchestration pipeline.
- No PXE service is available on the deployment network.
- The target server can reach the network share hosting the ISO and firmware folders from iLO virtual media (and, for SUT, from the installed OS).
- The installed OS can reach the firmware repository (e.g. over SMB/HTTPS) so HPE SUT can apply updates post-install.

<a id="references"></a>

## References

- [Microsoft Learn – Windows Setup Automation Overview (unattended answer files).](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-automation-overview)
- [Microsoft Learn – OEM Windows Setup reference (autounattend.xml, disk/partition settings).](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-reference)
- [HPE OneView REST API Reference](https://support.hpe.com/docs/display/public/dp00006616en_us/index.html)
- [HPE Redfish examples – mount virtual media ISO, change boot order, and reboot server.](https://servermanagementportal.ext.hpe.com/docs/redfishclients/python-redfish-library/examples)
- [HPE Smart Update Tools (SUT) and SUM documentation.](https://support.hpe.com/)

<a id="roles-and-responsibilities"></a>

## Roles and Responsibilities

| Role | Responsibility | Notes |
| --- | --- | --- |
| ISO / Answer-file Owner (client) | Provide a bootable Windows Server ISO with a correct `autounattend.xml` (disk format, partition, locale, keyboard) and version it. | Owns the OS image and unattended configuration. |
| Firmware Owner (client) | Provide the latest HPE firmware folders/packages for the target platform and version them. | Owns the firmware repository content. |
| OneView Administrator | Maintain accurate server inventory and API access for managed HPE hardware. | Ensures correct server identification and management state. |
| Server Engineering / Build Operator | Initiate and monitor the build workflow; validate pre-checks and post-build health. | Can be a human operator or a pipeline account. |
| Security / IAM | Provide and govern service account permissions and secret storage | Prefer secret vault / pipeline secrets; avoid hard-coded credentials. |
| Change Manager | Approve production builds and maintain CRQ traceability where required. | Recommended for controlled environments. |

<a id="high-level-architecture"></a>

## High-Level Architecture

The automation pattern uses HPE OneView to identify the target physical host, HPE iLO to mount the client-supplied Windows Server ISO as virtual media and force a one-time boot from it, and HPE SUT to apply firmware after the OS is installed. Windows Setup reads the answer file embedded in the ISO to perform disk formatting, partitioning, locale, and keyboard configuration with no interactive input.

1. Operator or pipeline identifies the target server by name, serial number, or OneView identifier.
2. Automation queries HPE OneView and validates the target server state.
3. The client ISO and firmware folders must be held on a network share  
    1. which by definition is a Windows shared file (SMB),  
    2. and has an SMB address provided or a network-share name and path/filename,  
    3. and that network share exists on the Windows server  
    4. which image-build-automation (this repo is being run from)  
    5. that network path / SMB address is reachable by iLO virtual media (and by the installed OS for SUT).  
4. Automation mounts the ISO through iLO virtual media.
5. Automation sets one-time boot override to virtual CD/DVD and restarts the host.
6. Windows Setup starts from the mounted ISO and applies the embedded `autounattend.xml` (disk clean/format, partition, locale, keyboard), then installs Windows Server.
7. After the OS is installed and reachable, HPE SUT applies firmware from the client-supplied firmware folders.
8. Post-build validation is completed and the build record is updated.

<a id="prerequisites"></a>

## Prerequisites

<a id="technical-prerequisites"></a>

### Technical prerequisites

- The client-supplied Windows Server ISO is bootable and embeds a valid `autounattend.xml` answer file (disk clean/format, partition layout, locale, keyboard, and any required OS defaults).
- The client-supplied firmware folders/packages (latest HPE firmware for the target platform) are available on a network share reachable from the installed OS.
- HPE OneView API credentials with rights to query server-hardware objects and toggle maintenance mode.
- HPE iLO credentials with rights to perform virtual media and power operations.
- Secure network location to host the ISO and firmware (SMB preferred; HTTPS/NFS also supported by iLO virtual media).
- The target network permits iLO virtual media access to the ISO share, and (post-install) OS access to the firmware repository.

<a id="access-prerequisites"></a>

### Access prerequisites

- Change approval for production builds (if required by local process).
- Approved service accounts for OneView API and iLO access.
- Administrative access on the system used to run the automation (no ConfigMgr site access required).

<a id="media-strategy"></a>

## Media Strategy

Preferred approach: mount the **client-supplied Windows Server ISO** over HPE iLO virtual media. This is the most flexible option for environments without PXE, because the server boots to Windows Setup directly from the ISO and applies its embedded answer file. No Configuration Manager bootable media or task sequence is used.

- Preferred: Client-supplied ISO mounted via iLO virtual media – smallest operational footprint; the answer file travels with the ISO.
- Post-OS firmware: client-supplied firmware folders applied via HPE SUT after the OS install.
- Not used here: Configuration Manager stand-alone / prestaged media (no ConfigMgr in this environment).

<a id="standard-operating-procedure"></a>

## Standard Operating Procedure

<a id="prepare-the-client-supplied-iso-answer-file-and-firmware"></a>

### Prepare the client-supplied ISO, answer file, and firmware

1. Obtain the client-supplied Windows Server ISO and confirm it embeds an `autounattend.xml` answer file.
    1. The answer file must perform disk cleaning/formatting and partitioning.
    2. The answer file must set locale and keyboard layout (and any other regional/OS defaults).
    3. The answer file should be authored so the install completes without interactive input.
2. Obtain the client-supplied firmware folders/packages (latest HPE firmware for the target platform).
3. Store the ISO and the firmware folders on a network share,  
    1. which by definition is Windows shared (SMB),  
    2. and has an SMB address provided or a network-share name and path/filename,  
    3. and that network share exists on the Windows server  
    4. which image-build-automation (this repo is being run from)  
    5. that network path / SMB address is reachable by iLO virtual media and by the installed OS (for SUT).
4. Version the ISO according to the client release standard (for example: `WinSrv2025_HPE_ClientISO_v1.7.iso`).

<a id="publish-the-iso-and-firmware-for-ilo-consumption"></a>

### Publish the ISO and firmware for iLO consumption

1. Place the ISO and firmware folders in locations accessible to iLO virtual media (ISO) and the installed OS (firmware repository).
2. Prefer HTTPS/SMB with controlled access and auditable hosting.
3. Validate the full ISO path / URL and the firmware folder paths before initiating the build.

1. Query HPE OneView for the target physical server by name, serial number, Bay/Enclosure position, or other approved identifier.
2. Verify the hardware state, power state, and health state before proceeding.
3. Confirm the correct server has been selected and is approved for build / rebuild.
4. Resolve or derive the corresponding iLO management address or endpoint for the server.

```PWSH
# Example OneView REST query pattern:

GET https://<oneview-appliance>/rest/server-hardware?filter="name='<ServerName>'"
```

<a id="resolve-the-target-server-via-hpe-oneview"></a>

### Resolve the target server via HPE OneView

1. Authenticate to OneView (service account) and resolve the single target server.
2. Verify the hardware state, power state, and health state.
3. Confirm the correct server has been selected and is approved for build / rebuild.
4. The build pipeline **automatically** places the server into **HPE OneView maintenance mode** before any destructive action (ISO mount + one-time boot, and post-OS firmware) and removes it again after the build completes (or if the build fails). This suppresses hardware/firmware alerting and avoids on-call callouts during the rebuild. It is controlled by `-OneViewMaintenanceMode` (default on; use `-NoMaintenanceMode` to skip).
5. **SCOM maintenance mode is separate** and is **not** toggled by the build pipeline. SCOM watches the OS/cluster layer; if the rebuilt host is also monitored by SCOM and OS-level alerts must be suppressed, enable SCOM maintenance mode independently (e.g. `Set-MaintenanceMode -Mode scom`). See the Maintenance-Mode documentation for the SCOM/OneView distinction.

<a id="mount-iso-via-hpe-ilo-and-force-one-time-boot"></a>

### Mount ISO via HPE iLO and force one-time boot

1. Authenticate to the target iLO using a service account with virtual media and power control rights.
2. Insert the client Windows Server ISO as virtual media.
3. Set a one-time boot override to the virtual CD/DVD device.
4. Restart or power on the physical server.
5. Observe console output or iLO event logs to verify the host boots to Windows Setup.

```PWSH
# Example Redfish operations (conceptual):

POST /redfish/v1/Managers/1/VirtualMedia/<DeviceId>/Actions/VirtualMedia.InsertMedia
PATCH /redfish/v1/Systems/1   { BootSourceOverrideEnabled: "Once", BootSourceOverrideTarget: "Cd" }
POST /redfish/v1/Systems/1/Actions/ComputerSystem.Reset
```

<a id="os-installation-windows-setup"></a>

### OS installation (Windows Setup)

1. Windows Setup starts from the mounted ISO.
2. The embedded `autounattend.xml` cleans/forms the disk, creates the partition layout, and applies locale and keyboard settings.
3. The operating system image is applied.
4. Post-install steps from the answer file execute, such as domain join, security baseline, local/admin configuration, and standard software configuration.
5. The system reboots into the installed operating system.
6. Post-build validation is completed and the build record is updated.

<a id="post-os-firmware-update-hpe-sut"></a>

### Post-OS firmware update (HPE SUT)

1. After the OS is installed and reachable (WinRM/PowerShell), apply HPE firmware from the client-supplied firmware folders.
2. Use HPE Smart Update Tools (SUT) / SUM against the firmware repository so the latest BIOS/iLO/device firmware is installed.
3. Reboot the server if the firmware update requires it.
4. Confirm firmware versions post-update as part of post-build validation.

> Firmware is applied **after** the OS image install (post-OS), not before. This keeps the install deterministic and lets SUT run against a live, managed OS.

<a id="validation-checklist"></a>

## Validation Checklist

<a id="pre-build-validation"></a>

### Pre-build validation

- Correct target server identified in OneView.
- Target approved for imaging / rebuild.
- Client ISO present on a network share reachable by iLO virtual media.
- `autounattend.xml` present/embedded in the ISO (answer file performs format/partition/locale/keyboard).
- Firmware folders present on a repository reachable from the installed OS.
- iLO credentials verified.
- Configuration / change record created where required.

<a id="in-build-validation"></a>

### In-build validation

- ISO mounted successfully in iLO virtual media.
- One-time boot override applied.
- System boots to Windows Setup.
- Disk operations (clean/format/partition) complete successfully.
- OS image apply completes successfully.
- System reaches the installed OS and is reachable.
- Firmware update (SUT) completes and any required reboot succeeds.

<a id="post-build-validation"></a>

### Post-build validation

- Expected hostname assigned.
- Domain join successful (if required).
- Correct OU placement or directory registration.
- Operating system version, edition, and patch baseline verified.
- Expected HPE device drivers present.
- HPE firmware versions match the supplied firmware set.
- RDP / PowerShell / management agents operational.
- Build outcome captured in operational records.

<a id="rollback-recovery-procedure"></a>

## Rollback / Recovery Procedure

1. If the install fails before OS application, eject virtual media, reset boot order to normal, and investigate Windows Setup / network / driver issues.
2. If the install fails after partial deployment, either rerun the build after remediation or wipe/reinitialize the local storage before retry.
3. If the wrong server was selected, stop the workflow immediately, eject media, cancel the change, and follow incident / change procedures.
4. If iLO virtual media operations fail, validate device index, iLO generation, ISO accessibility, and Redfish permission scope.
5. If firmware (SUT) fails, review the SUT/SUM logs, confirm repository reachability, and re-run the firmware step; do not proceed to production use until firmware is at the required level.

<a id="troubleshooting-guide"></a>

## Troubleshooting Guide

| Issue | Likely Cause | Recommended Action |
| --- | --- | --- |
| Server does not boot from ISO | One-time boot override not applied; wrong virtual media device; ISO not mounted | Check iLO virtual media state, boot order override, and device ID; retry restart. |
| Windows Setup starts but fails | Answer file error; disk/partition mismatch; missing driver in image | Review `autounattend.xml`; validate disk/partition settings and embedded drivers. |
| WinPE/Setup has no network | Missing NIC driver in the image | Ensure the client ISO includes the required HPE NIC driver. |
| Disk preparation fails | Storage controller driver missing or RAID not initialized | Validate Smart Array / RAID state and storage driver support in the image. |
| OS installs but post-build steps fail | Answer-file package/app issue; domain join issue; variable problem | Review Setup logs and validate packages, credentials, and answer-file settings. |
| Firmware (SUT) fails | Repository unreachable from OS; wrong firmware set | Confirm firmware folder path/reachability and that the set matches the platform. |
| Wrong target server built | Target validation failure | Stop process immediately and invoke incident/change process; improve pre-check controls. |

<a id="security-and-control-requirements"></a>

## Security and Control Requirements

- Do not hard-code production credentials in scripts.
- Store OneView and iLO credentials in a secure secret store or pipeline secret vault.
- Use a mandatory approval/guard-rail gate (e.g. regex match on the resolved server name) before any destructive mount/reboot.
- Maintain audit logs showing who initiated the build, which server was targeted, which ISO and firmware set were used, and the final outcome.

<a id="appendix-a-sample-automation-components"></a>

## Appendix A: Sample Automation Components

<a id="sample-workflow-components"></a>

### Sample workflow components

- `Get-OneViewServerTarget.ps1` – retrieves and validates the server object from OneView.
- `Invoke-IloRedfish.ps1` – mounts the ISO through Redfish, sets one-time boot override, and restarts the server.
- `Configure-PhysicalBuild.ps1` – 4-eye review / approval gate (resolves target, validates ISO + firmware reachability, prints the plan, requires `APPROVE`/`Deploy` and a guard-rail match).
- `Start-PhysicalServerBuild.ps1` – wrapper/orchestrator (OneView resolution, iLO mount + boot, install monitoring, post-OS firmware via SUT, post-build validation, maintenance-mode cleanup, audit).
- `Test-PreBuildValidation.ps1` / `Test-PostBuildValidation.ps1` – read-only readiness and post-build checks.

<a id="example-file-naming-and-versioning-standard"></a>

### Example file naming and versioning standard

- Client ISO: `WinSrv2025_HPE_ClientISO_v<Major.Minor>.iso`
- Firmware set: `HPE_Firmware_<Platform>_v<Major.Minor>` (folder or `.zip`)
- Build record ID: `OSD-<YYYYMMDD>-<Sequence>`

<a id="source-note"></a>

## Source Note

This runbook was prepared using documented platform capabilities for HPE OneView REST API automation, HPE iLO Redfish virtual media / reboot workflows, Windows Setup unattended (`autounattend.xml`) installation, and HPE Smart Update Tools (SUT) firmware management. It deliberately excludes Configuration Manager (ConfigMgr / MECM) bootable-media and task-sequence steps, which are not used in this environment.

(End of file)
