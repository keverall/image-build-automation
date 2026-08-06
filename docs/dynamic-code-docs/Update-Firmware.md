---
source:  ./src/powershell/Automation/Public/Update-Firmware.ps1
generated: 2026-08-06
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Update-Firmware

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
- [Original Comment-Based Help](#original-comment-based-help)

<a name="description"></a>

## Description

Reads the firmware/driver manifest (hpe_firmware_drivers_nov2025.json) and invokes hpe_sut.exe to create per-server firmware ISOs.  Equivalent to the reference implementation automation.cli.update_firmware_drivers module.

<a name="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Config` _(Aliases: -Cfg)_ | Path to firmware drivers JSON config (default: configs\hpe_firmware_drivers_nov2025.json). |
| `-Server` _(Aliases: -Srvr)_ | Build for a specific server only. Mutually exclusive with -SerialNumber. |
| `-SerialNumber` _(Aliases: -Srl)_ | Build for a server identified by its HPE serial number. Resolved to the server hostname via OneView; requires -OneViewHost. |
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname/IP used to resolve -SerialNumber. |
| `-ServerList` _(Aliases: -SrvrList)_ | Path to server_list.txt. Only used for -DryRun mock targeting. |
| `-OutputDir` _(Aliases: -OutDir)_ | Output directory. |
| `-FirmwareFolders` _(Aliases: -FwDirs)_ | Additional firmware component source directories (string array). These are local folder paths containing pre-downloaded HPE SUT component packages (e.g. '.spp' component folders or extracted firmware update packs). Each folder is passed to hpe_sut via the --firmware-components flag so SUT includes them alongside the manifest-specified components. Use this when Marin provides firmware component folders outside the standard manifest repository. Example: Update-Firmware -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5') |
| `-SkipDownload` _(Aliases: -SkipDl)_ | Skip component download step. |
| `-DryRun` _(Aliases: -Dry)_ | Simulate without executing. |

<a name="examples"></a>

## Examples

<a name="example-1"></a>

### Example 1

```powershell
Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -Server 'srv01.corp.local'
```

<a name="example-2"></a>

### Example 2

```powershell
Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.ad.example.com'
```

<a name="example-3"></a>

### Example 3

```powershell
Update-Firmware -Server 'srv01.corp.local' -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')
```

<a name="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Build HPE firmware/driver ISOs using the Smart Update Tool (SUT).
        Callable from the module Router.

    .DESCRIPTION
        Reads the firmware/driver manifest (hpe_firmware_drivers_nov2025.json) and
        invokes hpe_sut.exe to create per-server firmware ISOs.  Equivalent to the
        reference implementation automation.cli.update_firmware_drivers module.

    .PARAMETER Config
        Path to firmware drivers JSON config (default: configs\hpe_firmware_drivers_nov2025.json).

    .PARAMETER Server
        Build for a specific server only. Mutually exclusive with -SerialNumber.

    .PARAMETER SerialNumber
        Build for a server identified by its HPE serial number. Resolved to the
        server hostname via OneView; requires -OneViewHost.

    .PARAMETER OneViewHost
        OneView appliance hostname/IP used to resolve -SerialNumber.

    .PARAMETER ServerList
        Path to server_list.txt. Only used for -DryRun mock targeting.

    .PARAMETER OutputDir
        Output directory.

    .PARAMETER FirmwareFolders
        Additional firmware component source directories (string array). These are
        local folder paths containing pre-downloaded HPE SUT component packages
        (e.g. '.spp' component folders or extracted firmware update packs).
        Each folder is passed to hpe_sut via the --firmware-components flag so
        SUT includes them alongside the manifest-specified components. Use this
        when Marin provides firmware component folders outside the standard
        manifest repository.

        Example:
          Update-Firmware -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')

    .PARAMETER SkipDownload
        Skip component download step.

    .PARAMETER DryRun
        Simulate without executing.

    .RETURNS
        [hashtable] with Success (bool) and details.

    .EXAMPLE
        Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -Server 'srv01.corp.local'
    .EXAMPLE
        Update-Firmware -Config 'configs\hpe_firmware_drivers_nov2025.json' -SerialNumber 'MXQ1234567' -OneViewHost 'oneview.ad.example.com'
    .EXAMPLE
        Update-Firmware -Server 'srv01.corp.local' -FirmwareFolders @('C:\fw\BIOS', 'C:\fw\iLO5')
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
