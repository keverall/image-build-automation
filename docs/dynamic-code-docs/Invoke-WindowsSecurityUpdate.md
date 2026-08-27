---
source:  ./src/powershell/Automation/Public/Update-WindowsSecurity.ps1
generated: 2026-08-27
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# Invoke-WindowsSecurityUpdate

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Examples](#examples)
  - [Example 1](#example-1)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

Applies Windows security patches to a base ISO using DISM or PowerShell DISM equivalent, creating a patched ISO ready for deployment. Reads patch manifest from windows_patches.json and downloads/applies MSU packages to the mounted ISO image.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-BaseIsoPath` _(Aliases: -BaseIso, -b)_ | Path to the base Windows Server ISO file. Accepts the same network-share and URL formats as the other build commands; see |
| `-Server` _(Aliases: -ServerName, -s)_ | Server hostname for output naming. Mutually exclusive with -SerialNumber. |
| `-SerialNumber` _(Aliases: -Srl)_ | Identify the server by its HPE serial number; resolved to the hostname (for output naming) via OneView. Requires -OneViewHost. |
| `-OneViewHost` _(Aliases: -OVHost)_ | OneView appliance hostname/IP used to resolve -SerialNumber. |
| `-PatchesConfig` _(Aliases: -p)_ | Path to windows_patches.json (default: configs\windows_patches.json). |
| `-OutputDir` _(Aliases: -o)_ | Output directory (default: output\patched). |
| `-Method` _(Aliases: -m)_ | Patching method: 'dism' or 'powershell' (default: dism). |
| `-DryRun` _(Aliases: -Dry)_ | Simulate without making changes. |
| `-Json` | Emit the result as a JSON string on the success stream (for API integration / redirection) instead of the human-readable report. When omitted, the command writes a human-readable report to the host (terminal / transcript / logs) and does NOT dump a raw hashtable. |
| `-PassThru` _(Aliases: -PT)_ | Also return the structured [hashtable] result on the success stream. By default the command writes only the human-readable report and returns nothing, so the terminal/log never receives a truncated hashtable dump. Capture the result into a variable, e.g. `$r = Invoke-WindowsSecurityUpdate -PassThru`, for scripting. |
| `-Quiet` | Suppress the human-readable report (use with -PassThru / -Json when the caller handles display itself). |

<a id="examples"></a>

## Examples

<a id="example-1"></a>

### Example 1

```powershell
Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\ISOs\WinServer2022.iso' -Server 'srv01' -DryRun
```

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
        Apply Windows security patches to a base Windows Server ISO and build the patched ISO.
        Callable from the module Router.

    .DESCRIPTION
        Applies Windows security patches to a base ISO using DISM or PowerShell
        DISM equivalent, creating a patched ISO ready for deployment. Reads patch
        manifest from windows_patches.json and downloads/applies MSU packages
        to the mounted ISO image.

    .PARAMETER BaseIsoPath
        Path to the base Windows Server ISO file. Accepts the same network-share
        and URL formats as the other build commands; see
        ../PathParameterFormats.md for the full list of accepted formats.

    .PARAMETER Server
        Server hostname for output naming. Mutually exclusive with -SerialNumber.

    .PARAMETER SerialNumber
        Identify the server by its HPE serial number; resolved to the hostname
        (for output naming) via OneView. Requires -OneViewHost.

    .PARAMETER OneViewHost
        OneView appliance hostname/IP used to resolve -SerialNumber.

    .PARAMETER PatchesConfig
        Path to windows_patches.json (default: configs\windows_patches.json).

    .PARAMETER OutputDir
        Output directory (default: output\patched).

    .PARAMETER Method
        Patching method: 'dism' or 'powershell' (default: dism).

    .PARAMETER DryRun
        Simulate without making changes.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream (for API
        integration / redirection) instead of the human-readable report.
        When omitted, the command writes a human-readable report to the host
        (terminal / transcript / logs) and does NOT dump a raw hashtable.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream.
        By default the command writes only the human-readable report and
        returns nothing, so the terminal/log never receives a truncated
        hashtable dump. Capture the result into a variable, e.g.
        `$r = Invoke-WindowsSecurityUpdate -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .RETURNS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with Success (bool), PatchedIso (string), and Error.
        With -Json, a JSON [string] representation of the same data.

    .EXAMPLE
        Invoke-WindowsSecurityUpdate -BaseIsoPath 'C:\ISOs\WinServer2022.iso' -Server 'srv01' -DryRun
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
