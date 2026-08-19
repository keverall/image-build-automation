# Automation Checks

<a id="top"></a>

## Table of Contents

- [1. Is the SMB-path bug universally fixed?](#1-is-the-smb-path-bug-universally-fixed)
- [2. Command clarifications (also added to the docs as scannable bullets)](#2-command-clarifications-also-added-to-the-docs-as-scannable-bullets)
- [3. Safety on a live regulated banking appliance](#3-safety-on-a-live-regulated-banking-appliance)

<a id="1-is-the-smb-path-bug-universally-fixed"></a>

## 1. Is the SMB-path bug universally fixed?

**Yes — confirmed.** There is now exactly **one** `Resolve-ExternalIsoPath` (in `Private/ExternalIso.ps1`), and all four ISO/deploy commands call it:

- `Test-BuildParams` (ISO **and** firmware validation)
- `Configure-PhysicalBuild`
- `Start-PhysicalServerBuild`
- `Invoke-IsoDeploy`

The two duplicate copies (the source of drift) are deleted, and there is no other inline `cifs://` conversion anywhere. So `\\server\share`, `//server/share`, `cifs://…`, `smb://…`, HTTPS, NFS, and mapped drives all resolve identically in every command. `Update-Firmware` was never affected (it doesn't resolve ISO paths — it hands firmware folders straight to the SUT updater on the OS).

<a id="2-command-clarifications-also-added-to-the-docs-as-scannable-bullets"></a>

## 2. Command clarifications (also added to the docs as scannable bullets)

**`Start-InstallMonitor`** — *read-only / safe*

- Watches an **in-progress** install started by `Start-PhysicalServerBuild`/`Invoke-IsoDeploy`.
- Polls the server (OneView/iLO) and reports progress/status.
- Never reboots, mounts, or changes anything. Safe to run anytime on a live appliance.

**`Invoke-IloRedfish`** — *can be destructive*

- `Status` — read power/state + mounted media → **safe**
- `Mount` / `Eject` / `Boot` — attach/detach/set boot → **safe** (no reboot yet)
- `MountAndBoot` and `Reset` — **DESTRUCTIVE** (reboot; MountAndBoot reinstalls/wipes)
- Needs `-Force` for the destructive ones; `-DryRun` prints without doing.

**`Get-OneViewServerTarget`** — *read-only / safe*

- Resolves **one** server by name / serial / iLO IP / bay.
- **Strict single-server:** a name matching >1 server **fails** (never silently picks) — this is what protects downstream destructive steps.
- Validates power/health/iLO/maintenance mode; reuses or opens a OneView session; changes nothing.
- It's the single resolver every build/deploy command uses, so targeting is consistent.

**`Test-PreBuildValidation`** — *read-only / safe*

- Runs readiness checks **before** any build/deploy, touching nothing:
  - OneView target resolves (strict)
  - iLO credentials work
  - ConfigMgr MP/DP reachable (skippable)
  - ISO URL reachable (skippable)
  - Boot image / task sequence exist (skippable)
- `-DryRun` validates inputs and skips live probes.

<a id="3-safety-on-a-live-regulated-banking-appliance"></a>

## 3. Safety on a live regulated banking appliance

You are right to be careful — losing a client server/data is unacceptable. The module is built so you can do **all** identification and validation **non-destructively first**, and destructive actions are gated.

**Non-destructive / safe to run on the live appliance:**
`Test-ServerConnectivity`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`, `Test-BuildParams`, `Test-PreBuildValidation`, `Configure-PhysicalBuild` (it's a **read-only 4-eye review** — prints the full plan, only acts if you type `DEPLOY`), `Start-InstallMonitor`, `Invoke-IloRedfish -Action Status|Eject`, and `-DryRun` on anything.

**Destructive (reboot / reinstall / wipe):**
`Invoke-IsoDeploy`, `Start-PhysicalServerBuild`, `Invoke-IloRedfish -Action MountAndBoot|Reset`, `Update-Firmware`.

**The guardrail is the key control:** `-GuardRail` is **mandatory** on the destructive build/deploy commands. It's a case-insensitive regex the **resolved** server name must match before anything happens — so you can only ever target the exact validated server (e.g. `-GuardRail 'alp-qlikview-03ilo'`).

**Recommended zero-risk pre-flight on the live appliance** (no changes made):

1. `Test-ServerConnectivity` / `Get-OneViewConnectionStatus` — reachability
2. `Get-OneViewServerList` — confirm the managed fleet
3. `Get-OneViewServerTarget -ServerIdentifier <x>` — resolve & validate the **single** target
4. `Test-BuildParams -BaseIsoPath <...> -FirmwareFolders @(...)` — prove the ISO + firmware paths resolve and exist
5. `Test-PreBuildValidation -ServerIdentifier <x>` — all readiness checks
6. `Configure-PhysicalBuild ... -GuardRail '<x>'` — full 4-eye review (prints plan, does not deploy)
7. `Invoke-IsoDeploy ... -DryRun -GuardRail '<x>'` — validates + prints plan, no reboot

Only when all of the above pass and you intend to proceed do you drop `-DryRun` and run the real `Invoke-IsoDeploy`/`Start-PhysicalServerBuild` — and the `-GuardRail` still blocks anything that doesn't match your validated server.
