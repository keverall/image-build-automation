---
source:  ./scripts/testBuildDeploy.ps1
generated: 2026-09-02
auto_generated_by: scripts/Generate-PSDocs.ps1
---

# testBuildDeploy

<a id="top"></a>

## Table of Contents

- [Description](#description)
- [Parameters](#parameters)
- [Original Comment-Based Help](#original-comment-based-help)

<a id="description"></a>

## Description

Exercises the build/deploy commands plus the ISO validation they rely on: Configure-PhysicalBuild, Start-PhysicalServerBuild What it exercises ----------------- 1. Connection check / connect-when-none (mirrors testConnectAndList). 2. Running build/deploy WITHOUT the mandatory -GuardRail -> early, graceful, logged BLOCK (never an unguarded action). 3. HPE OneView ISO file variants: * filename/UNC/HTTPS/NFS path -> resolved to an iLO-accessible URL (SMB conversion, shareability checks) * a supplied local ISO path is validated (exists, is an .iso) 4. Firmware archive validation (exists, valid zip/cab/tar) — path validation only; the standalone Update-Firmware command has been removed. 5. The -GuardRail SAFETY GATE across both commands: * omitted      -> blocked (GUARD RAIL REQUIRED) * non-matching -> blocked (mismatch) * matching     -> proceeds (DryRun) 6. Confirmation flow: a matched guard in an automated run with no -Deploy / -Execute auto-cancels (no unconfirmed destructive action). 7. Build/deploy VARIANTS (external ISO) under -DryRun. -OneViewHost is the OneView appliance and -Server is the target server identifier (name / serial / iLO IP). Nothing is hard-coded; both are prompted when omitted. By default the script runs SAFE (connections validated with -DryRun, builds with -DryRun) and only performs live calls when -Live is passed with credentials. Full logging is written via the module's common logging commands (Initialize-Logging / Get-Logger) under generated/logs/commands/testBuildDeploy/.

<a id="parameters"></a>

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-OneViewHost` | OneView appliance hostname or IP (alias -OVHost). Prompted if omitted. |
| `-Server` | Target server identifier (name / serial / iLO IP) to build or deploy. Prompted if omitted. |
| `-SerialNumber` | Resolve -Server from an HPE serial number via OneView. |
| `-IloIp` | Target iLO address or hostname. |
| `-Credential` | PSCredential for a live (-Live) connection. Prompted when -Live is set and this is omitted. |
| `-IsoPath` | Local or network ISO path to validate (existence + .iso + iLO shareability). |
| `-FirmwarePath` | Local firmware archive (.zip/.cab/.tar/...) to validate. |
| `-GuardRail` | CASE-INSENSITIVE REGEX the target server name must match. Supplied to every build/deploy command so the safety gate is exercised (matches '.*' by default when omitted here, which still satisfies the commands' mandatory requirement). |
| `-Live` | Perform REAL connections / builds using -Credential instead of -DryRun validation. Use only against an approved test appliance. |
| `-DryRun` | Validate with -DryRun (default-safe behaviour even without -Live). |
| `-PingTimeoutMs` | TCP connect timeout in milliseconds for reachability probes (default 3000). |

<a id="original-comment-based-help"></a>

## Original Comment-Based Help

```powershell
.SYNOPSIS
    Functional / re-runnable test harness for the BUILD & DEPLOY pipeline and its
    mandatory -GuardRail safety gate.

.DESCRIPTION
    Exercises the build/deploy commands plus the ISO validation they rely on:

      Configure-PhysicalBuild, Start-PhysicalServerBuild

    What it exercises
    -----------------
      1. Connection check / connect-when-none (mirrors testConnectAndList).
      2. Running build/deploy WITHOUT the mandatory -GuardRail -> early, graceful,
         logged BLOCK (never an unguarded action).
      3. HPE OneView ISO file variants:
            * filename/UNC/HTTPS/NFS path -> resolved to an iLO-accessible URL
              (SMB conversion, shareability checks)
            * a supplied local ISO path is validated (exists, is an .iso)
      4. Firmware archive validation (exists, valid zip/cab/tar) — path validation
         only; the standalone Update-Firmware command has been removed.
      5. The -GuardRail SAFETY GATE across both commands:
            * omitted      -> blocked (GUARD RAIL REQUIRED)
            * non-matching -> blocked (mismatch)
            * matching     -> proceeds (DryRun)
      6. Confirmation flow: a matched guard in an automated run with no
         -Deploy / -Execute auto-cancels (no unconfirmed destructive action).
      7. Build/deploy VARIANTS (external ISO) under -DryRun.

    -OneViewHost is the OneView appliance and -Server is the target
    server identifier (name / serial / iLO IP). Nothing is hard-coded; both are
    prompted when omitted. By default the script runs SAFE (connections validated
    with -DryRun, builds with -DryRun) and only performs live calls when -Live is
    passed with credentials. Full logging is written via the module's common logging
    commands (Initialize-Logging / Get-Logger) under
    generated/logs/commands/testBuildDeploy/.

.PARAMETER OneViewHost
    OneView appliance hostname or IP (alias -OVHost). Prompted if omitted.

.PARAMETER Server
    Target server identifier (name / serial / iLO IP) to build or deploy. Prompted
    if omitted.

.PARAMETER SerialNumber
    Resolve -Server from an HPE serial number via OneView.

.PARAMETER IloIp
    Target iLO address or hostname.

.PARAMETER Credential
    PSCredential for a live (-Live) connection. Prompted when -Live is set and
    this is omitted.

.PARAMETER IsoPath
    Local or network ISO path to validate (existence + .iso + iLO shareability).

.PARAMETER FirmwarePath
    Local firmware archive (.zip/.cab/.tar/...) to validate.

.PARAMETER GuardRail
    CASE-INSENSITIVE REGEX the target server name must match. Supplied to every
    build/deploy command so the safety gate is exercised (matches '.*' by default
    when omitted here, which still satisfies the commands' mandatory requirement).

.PARAMETER Live
    Perform REAL connections / builds using -Credential instead of -DryRun
    validation. Use only against an approved test appliance.

.PARAMETER DryRun
    Validate with -DryRun (default-safe behaviour even without -Live).

.PARAMETER PingTimeoutMs
    TCP connect timeout in milliseconds for reachability probes (default 3000).

.EXAMPLE
    .\testBuildDeploy.ps1 -OneViewHost oneview-test.ad.example.com -Server srv01

.EXAMPLE
    .\testBuildDeploy.ps1 -Server srv01 -IsoPath '\\fileserver\isos\win.iso' -GuardRail 'srv0'

.EXAMPLE
    .\testBuildDeploy.ps1 -Live -OneViewHost ov.corp.local -Server srv01 -Credential $cred -IsoPath 'https://artifacts/isos/win.iso' -GuardRail 'srv0'
```

---
*Auto-generated by `scripts/Generate-PSDocs.ps1` - do not edit manually.*
