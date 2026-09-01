# Automation Command Reference

<a id="top"></a>

## Table of Contents

- [Automation Command Reference](#automation-command-reference)
  - [Table of Contents](#table-of-contents)
  - [How the commands fit together](#how-the-commands-fit-together)
  - [Setup (One-Time)](#setup-one-time)
  - [Connectivity, Connection \& Server Lookup](#connectivity-connection--server-lookup)
    - [Test OneView connectivity](#test-oneview-connectivity)
    - [Connect to OneView](#connect-to-oneview)
    - [Disconnect from OneView](#disconnect-from-oneview)
    - [Get OneView connection status](#get-oneview-connection-status)
    - [Get OneView server list](#get-oneview-server-list)
    - [Validate build parameters](#validate-build-parameters)
  - [ISO Image Naming \& SMB Shares](#iso-image-naming--smb-shares)
    - [Bootable ISO filename convention](#bootable-iso-filename-convention)
    - [ISO path requirements (no local drives)](#iso-path-requirements-no-local-drives)
  - [Physical Server Build (End-to-End)](#physical-server-build-end-to-end)
    - [Configure build (4-eye review)](#configure-build-4-eye-review)
    - [Dry run (validate without changing anything)](#dry-run-validate-without-changing-anything)
    - [Re-run monitoring after deployment](#re-run-monitoring-after-deployment)
    - [Build with custom domain and post-build checks](#build-with-custom-domain-and-post-build-checks)
  - [ISO Deployment \& Monitoring](#iso-deployment--monitoring)
    - [Monitor installation progress](#monitor-installation-progress)
      - [Monitor with custom timeout](#monitor-with-custom-timeout)
      - [Monitor all servers from the server list](#monitor-all-servers-from-the-server-list)
    - [iLO Redfish operations](#ilo-redfish-operations)
      - [Mount ISO only](#mount-iso-only)
      - [Eject virtual media](#eject-virtual-media)
      - [Check current status](#check-current-status)
      - [Force reset](#force-reset)
    - [Resolve server target via OneView](#resolve-server-target-via-oneview)
      - [Look up by serial number](#look-up-by-serial-number)
      - [Dry run](#dry-run)
    - [Pre-build validation](#pre-build-validation)
      - [Skip specific checks](#skip-specific-checks)
      - [Dry run (validate inputs, skip network probes)](#dry-run-validate-inputs-skip-network-probes)
    - [Post-build validation](#post-build-validation)
      - [Skip ConfigMgr client check](#skip-configmgr-client-check)
      - [Skip all remote checks (WinRM not available)](#skip-all-remote-checks-winrm-not-available)
    - [Patch Windows ISO with security updates](#patch-windows-iso-with-security-updates)
      - [Patch with custom method](#patch-with-custom-method)
      - [Dry run](#dry-run-1)
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

<a id="how-the-commands-fit-together"></a>

## How the commands fit together

The module has a lot of commands because each one has a single, well-defined job. Mixing them into one "do everything" command would make it impossible to test individual steps or re-run just the part that failed.

| Layer | Command | What it does |
|-------|---------|--------------|
| **Connect** | `Connect-OneView` | Establishes a persistent OneView session (prompts for credentials). Run this first if you plan to run multiple OneView commands. |
| **Status** | `Test-ServerConnectivity` | Read-only check: is the appliance reachable and authenticated? **Never prompts.** |
| **Status** | `Get-OneViewConnectionStatus` | Quick status check against the active session (or a specific host). **Never prompts.** |
| **Lookup** | `Get-OneViewServerList` | Lists all servers managed by OneView. Reuses the active session. |
| **Lookup** | `Get-OneViewServerTarget` | Resolves a single server by name, serial, iLO IP, or bay. Reuses the active session. |
| **Review** | `Configure-PhysicalBuild` | Read-only 4-eye review. Shows the full deployment plan, including all destructive actions, and waits for you to type `APPROVE`. Automatically places server in OneView maintenance mode before build (use `-NoMaintenanceMode` to skip). |
| **Monitor** | `Start-InstallMonitor` | Watches an in-progress installation and reports progress. |

**Which command should I use?**

- "Is OneView up?" → `Test-ServerConnectivity`
- "I need to run several OneView commands" → `Connect-OneView` once, then use `Get-OneViewServerList` / `Get-OneViewServerTarget` freely
- "Show me what the deploy would do" → `Configure-PhysicalBuild`
- "Actually deploy to the server" → `Configure-PhysicalBuild -Deploy` (or `-Execute`) after review

> **Single public build command:** `Configure-PhysicalBuild` is the only build command you run from the terminal. When you type `APPROVE` (or pass `-Deploy`), it internally executes the build pipeline — OneView resolution, maintenance mode enable, iLO mount, OS install, post-build validation, and maintenance mode disable. 

> ### ⚠ Safe vs destructive commands (read this first)
> On a live, regulated banking appliance you must never lose a client server, its data, or impact a workload. Run the **non-destructive** commands first to identify and validate the exact target and media; the **destructive** ones are gated by a mandatory `-GuardRail` regex (the *resolved* server name must match) and prompt for confirmation.
>
> | Safety | Commands | Effect |
> |--------|----------|--------|
> | ✅ **Non-destructive / safe** | `Test-ServerConnectivity`, `Get-OneViewConnectionStatus`, `Get-OneViewServerList`, `Get-OneViewServerTarget`, `Test-BuildParams`, `Test-PreBuildValidation`, `Start-InstallMonitor`, `Invoke-IloRedfish -Action Status\|Eject`, `Invoke-OpsRampClient`, `Disconnect-OneView` | Read-only lookups, path/validation checks, or status monitoring. No reboot, mount, or change to any server. Safe on the live appliance. |
> | ⚠ **Destructive** | `Configure-PhysicalBuild` (APPROVE confirmation gate) | `Configure-PhysicalBuild` reviews the plan and, on typing `APPROVE` or passing `-Deploy`/`-Execute`, **executes the destructive build** internally — OneView resolution, maintenance mode enable, ISO mount + reboot (wipe/reinstall), post-build validation, and maintenance mode disable. Gated by `-GuardRail`; `-DryRun` prints the plan without acting. **Automatically places the server into OneView maintenance mode before destructive operations** (use `-NoMaintenanceMode` to skip). |
>
> **Recommended pre-flight review (no change is made until you type `APPROVE` on `Configure-PhysicalBuild`, or pass `-Deploy`/`-Execute`):** `Get-OneViewServerTarget` → `Test-BuildParams` (ISO path) → `Test-PreBuildValidation` → `Configure-PhysicalBuild -GuardRail '<server>'` (review, then type `APPROVE` or pass `-Deploy` to authorize the real run).

---

<a id="setup-one-time"></a>

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

<a id="connectivity-connection-server-lookup"></a>

## Connectivity, Connection & Server Lookup

Pre-flight read-only checks. Safe to run during a change freeze. Start here - confirm the appliance is reachable, that you have an active session, and which servers are managed before you build or deploy anything.

<a id="test-oneview-connectivity"></a>

### Test OneView connectivity

Read-only connectivity STATUS CHECK for a OneView appliance. **This command never prompts for a host or credentials.**

- **No parameters** → reports the active `Connect-OneView` session (if any).
- **`-OneViewHost` supplied** → checks that specific appliance only.

Reachability probes DNS/TCP; authentication reuses the active session (when it matches) or uses `-Credential` / `ONEVIEW_USER` + `ONEVIEW_PASSWORD`. It never asks for a username or password.

**To actually connect**, use `Connect-OneView -OneViewHost <host>` (which prompts for credentials and establishes the session this command reports on).

**The OneView session established by `Connect-OneView` persists in the current PowerShell session.** Use `Disconnect-OneView` to explicitly close the session when finished.

```powershell
# STATUS: report the active connection (no params, no prompt)
Test-ServerConnectivity
```

```powershell
# STATUS: check a specific appliance only
Test-ServerConnectivity -OneViewHost oneview.example.com
```

```powershell
# DRY-RUN: validate host resolution only - no real connection or changes
Test-ServerConnectivity -OneViewHost oneview.example.com -DryRun
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-OneViewHost` | No | OneView appliance to check (server name or IP). Omit to report the active `Connect-OneView` session; supply to check a specific appliance verbatim (no config/env fallback). |
| `-Credential` | No | `PSCredential` for authentication. Only used when `-OneViewHost` is supplied and the active session does not match. |
| `-DryRun` | No | Return mock data; config may be read. |

No host is required - without one the command reports the active connection.

**Returns:** `[hashtable]` with `Available`, `Mode` (`oneview`), `OneViewHost`, `NetworkPing`, `AuthConnect`, and `Timestamp`.

**Note:** The OneView session persists after a successful connection. Use `Disconnect-OneView` to close it.

---

<a id="connect-to-oneview"></a>

### Connect to OneView

Establishes a persistent OneView session by validating network reachability and authenticating to the appliance. After connecting, subsequent commands (`Get-OneViewServerList`, `Get-OneViewConnectionStatus`, etc.) reuse this session automatically.

On a live run the appliance host is taken verbatim from `-OneViewHost` and credentials are entered interactively at the prompt. Config files are read **only** with `-DryRun` (no real connection is made).

```powershell
# LIVE: connect to a specific appliance (credentials prompted interactively)
Connect-OneView -OneViewHost oneview.example.com
```

```powershell
# LIVE + NON-INTERACTIVE: supply a PSCredential so nothing is prompted
# (used by runbooks / CI where AUTOMATED_MODE is set)
$cred = Get-Credential
Connect-OneView -OneViewHost oneview.example.com -Credential $cred
```

```powershell
# BARE (no params) on a live run: prompts for the appliance host (interactive)
# or warns "Connect-OneView requires -OneViewHost" in automated mode.
Connect-OneView
```

```powershell
# DRY-RUN (no host): resolve the appliance from connection_hosts.json and
# validate host resolution only - no real connection or changes.
Connect-OneView -DryRun
```

> **Why two commands?** `Test-ServerConnectivity` is a status check that **never prompts**. `Connect-OneView` is the command that **does** prompt for credentials and establishes the session. Use `Test-ServerConnectivity` when you just want to check status; use `Connect-OneView` when you need an active session for subsequent commands.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-OneViewHost` | No* | OneView appliance to connect to (server name or IP). REQUIRED for live runs; used verbatim - no config/env fallback. |
| `-Credential` | No | `PSCredential` for the live connection. If omitted, credentials are prompted interactively (live run, interactive only). |
| `-DryRun` | No | Return mock data; config may be read. Use this to test code without connecting to an appliance or making changes. |
| `-PassThru` | No | Return the structured result hashtable on the success stream (for scripting). |
| `-Json` | No | Emit the result as a JSON string on the success stream. |

\* `-OneViewHost` is required for a live (non-`-DryRun`) connection.

**Returns:** By default, nothing is returned on the success stream (the human-readable report is written to the host). With `-PassThru`, a `[hashtable]` with keys: `Available`, `OneViewHost`, `AuthConnect`, `NetworkPing`, `Message`, and `Timestamp`. With `-Json`, a JSON `[string]` representation of the same data.

---

<a id="disconnect-from-oneview"></a>

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

<a id="get-oneview-connection-status"></a>

### Get OneView connection status

Quick reachability + authentication check against a OneView appliance, with optional per-server status. Read-only - safe during a change freeze. **This command never prompts.** When run without parameters, the command checks for an existing OneView session (established via `Connect-OneView`) and uses that appliance automatically - no connect/disconnect. Reachability probes `GET /rest/version` (no auth); authentication probes `GET /rest/server-hardware` with the session token or supplied credentials. Use `-ServerIdentifier` to also report a single server's power/health. If no session exists, the command returns an error telling you to connect first with `Connect-OneView -OneViewHost <oneview-appliance-host>`.

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
Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier MXQ1234567 -IdentifierType Serial

# SAME RESULT with a single parameter - -IdentifierType defaults to Auto and
# detects the serial automatically, so you never need to specify the type:
Get-OneViewConnectionStatus -OneViewHost oneview.example.com -ServerIdentifier MXQ1234567
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

> **Short aliases:** the long (canonical) parameter names are `-OneViewHost`, `-ServerIdentifier`, `-IdentifierType`, etc.; every one also has a short alias (e.g. `-OVHost`, `-SrvrId`, `-IdTyp`). The long and short forms are interchangeable - the router, `request_types.json`, and existing automation continue to use the long names.

> **One-parameter targeting:** `-IdentifierType` defaults to `Auto`, which tries Name, Serial, OneViewName, iLO IP, then EnclosureBay in turn. So `-ServerIdentifier <value>` (or its alias `-SrvrId <value>`) alone resolves the server - you do **not** need to pass `-IdentifierType`. The explicit type is only required to disambiguate when a value could match more than one form.

> **Note:** the short alias is `-SrvrId` (with the **`r`**). `-SrvId` (without the `r`) is NOT a valid parameter.

If `-OneViewHost` is omitted, the command checks `$global:ConnectedSessions` for an active HPEOneView module session.

**Returns:** `[hashtable]` with `Success`, `Connected`, `Reachable`, `Authenticated`, `Appliance`, `Version`, `ServerCount` (optional), `Server` (optional), and `SessionSource` (`HPEOneViewModule` or `Explicit`).

---

<a id="get-oneview-server-list"></a>

### Get OneView server list

Lists every server managed by the appliance with normalised connection/health fields. Pagination is handled internally so the full fleet is returned in one call. Supports an optional `-Filter` to narrow by health, power state, maintenance mode, or name.

Each row also shows the server's **HPE OneView maintenance mode** and lifecycle **state**, which is what a hardware engineer needs to tell a server that is intentionally in maintenance (e.g. for firmware work) apart from one that is merely monitored or has hit an error:

| Column | Source field | Meaning |
|--------|--------------|---------|
| `MaintMode` | `MaintenanceModeEnabled` | `Yes` when the server is IN HPE OneView maintenance mode, otherwise `No`. This is the definitive "in/out of maintenance?" flag. |
| `State` | `state` | Lifecycle state: `Monitored` (normal), `MaintenanceMode`, `ConfigureHardware`, `NoProfileApplied`, `ProfileApplying`, `ProfileApplied`, `ProfileError`, `Deleting`. |
| `State Reason` | `stateReason` | Optional free-text reason for the current state (often populated for maintenance). |
| `Model` | `modelNumber` | Short, stable HPE model **code** (e.g. `867963-B21`) — placed last because it varies in length and would otherwise break column alignment. The full descriptive model string is still available in the `-PassThru` object as `model`. |

> **Maintenance mode vs other states:** `MaintMode = Yes` **only** when the server is in maintenance mode (and `State` will read `MaintenanceMode`). A server in `ProfileError`, `Monitored`, `NoProfileApplied`, etc. shows in `State` but `MaintMode` stays `No` — so the two columns are independent and an engineer reads `MaintMode = Yes` as the definitive maintenance signal. None of your fleet being in maintenance is expected when every row reads `MaintMode = No`; you would only see `MaintenanceMode` in `State` (and `MaintMode = Yes`) for a server that's actually been placed into maintenance.
>
> **Note on dates:** OneView maintenance mode is a manual toggle on the server-hardware resource — there is **no start/end timestamp** for it. Scheduled maintenance *windows* with start/end dates come from SCOM (see `Get-MaintenanceStatusReport`), not from OneView.

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

```powershell
# Narrow to servers currently IN or OUT of OneView maintenance mode
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'maintenance:Yes'
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'maintenance:No'

# Condensed summary view (Server Name, Serial, MaintMode, Health, iLO IP only)
Get-OneViewServerList -OneViewHost oneview.example.com -Summary

# Explicit full-field view (default when no switch is supplied)
Get-OneViewServerList -OneViewHost oneview.example.com -Detail
```

```powershell
# Narrow by partial / wildcard server name (substring AND * / ? wildcards)
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'name:PROD'
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'name:PROD-*'
Get-OneViewServerList -OneViewHost oneview.example.com -Filter 'name:srv-0?'
```

> **Reference:** the fields above come straight from the HPE OneView REST API `GET /rest/server-hardware` resource. See the official HPE OneView REST API reference for `ServerHardware` (`MaintenanceModeEnabled`, `state`, `stateReason`) and the maintenance-mode operations:
> - HPE OneView REST API (ServerHardware resource): <https://developer.hpe.com/blog/hpe-oneview-rest-api>
> - HPE OneView documentation / API explorer: <https://oneview.ext.hpe.com/>
> - Enable/Disable server maintenance mode (`Enable-OVMaintenanceMode` / `Disable-OVMaintenanceMode` in the HPEOneView PowerShell library): <https://github.com/HewlettPackard/Powershell-HPE-OneView>

**Parameters:**

| Parameter | Aliases | Required | Description | Default |
|-----------|---------|----------|-------------|---------|
| `-OneViewHost` | `-OVHost` | No | OneView appliance hostname or IP. Falls back to active HPEOneView module session if omitted. | - |
| `-Credential` | `-Cred` | No | `PSCredential` for authentication. Preferred, non-interactive entry point (sourced from a secret store). | - |
| `-OneViewUser` | `-OVUser` | No | OneView username (with `-OneViewPassword`) | prompt |
| `-OneViewPassword` | `-OVPwd` | No | OneView password (with `-OneViewUser`) | prompt |
| `-Port` | - | No | OneView HTTPS port | `443` |
| `-SkipCertificateCheck` | `-SkipCert` | No | Skip SSL cert verification. Most appliances use a self-signed/internal-CA cert, so default is `$true`. Only relevant while a NEW connection is established; has no effect when reusing an active session. | `true` |
| `-TimeoutSec` | `-Timeout` | No | Per-call REST timeout. Only relevant while establishing a NEW connection or for very large fleets over a slow link; `30` is fine for normal use. | `30` |
| `-PageSize` | `-Page` | No | Servers fetched per page (max 1000) | `100` |
| `-Filter` | `-` | No | Client-side filter. Case-insensitive **substring** by default, with PowerShell-style `*`/`?` wildcards supported: `health:<value>`, `power:<value>`, `maintenance:<value>` (e.g. `maintenance:Yes`, `maintenance:No`), `name:<value>` (e.g. `name:PROD`, `name:PROD-*`, `name:srv-0?`). | - |
| `-MockResult` | `-Mock` | No | Hashtable to return without making any HTTP calls (tests). | - |
| `-DryRun` | `-Dry` | No | Print the query without performing it | - |
| `-PassThru` | `-PT` | No | Also return the structured `[hashtable]` (by default only a table is printed). | - |
| -Summary | -Sum | No | Print a condensed table with only Server Name, Serial, MaintMode, Health and iLO IP - a quick fleet health/maintenance glance. | - |
| -Detail | -Det | No | Print the full table with every field (the default when neither switch is set). | - |

If `-OneViewHost` is omitted, the command checks `$global:ConnectedSessions` for an active HPEOneView module session.

**Returns:** `[hashtable]` with `Success`, `Count`, and `Servers` (array of name, serial, model, model_number, power_state, health_status, ilo_ip, rom_version, maintenance_mode, state, state_reason). Each `Server` entry maps directly to the HPE OneView `ServerHardware` resource fields documented above.

---

---

<a id="validate-build-parameters"></a>

### Validate build parameters

Reuses the shared `Resolve-ExternalIsoPath` helper (the single resolver used by every deploy/build command) to convert a network-share Windows ISO image path — and optionally firmware component locations — into the network address the iLO BMC mounts as virtual media, then verifies each file is present and usable. On success it returns the resolved iLO URL(s) so you can pass them straight to a deploy command. Local drive paths (`C:\`, `H:\` on a local disk) are rejected because iLO cannot reach local drives.

Accepted formats: `\\server\share\file.iso` (UNC), `//server/share/file.iso` (forward-slash UNC — identical to the above), `cifs://server/share/file.iso`, `smb://server/share/file.iso`, `https://…` / `nfs://…` URLs, or a mapped network drive (`H:\file.iso`).

> **Full format reference:** see [Path Parameter Formats](../PathParameterFormats.md#top) for every accepted `-ExternalIsoPath` / `-IsoPath` / `-FirmwareFolders` format, including the single-slash `/server/share` autocorrection and the list of unsupported local paths.

```powershell
# UNC/SMB share (backslash or forward slash) - resolved to a cifs:// URL iLO can mount
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso'
Test-BuildParams -BaseIsoPath '//fileserver/isos/WinSrv2025.iso'
```

```powershell
# CIFS/SMB URL or HTTPS URL - used directly by iLO
Test-BuildParams -BaseIsoPath 'cifs://fileserver/isos/WinSrv2025.iso'
Test-BuildParams -BaseIsoPath 'https://artifacts/isos/WinSrv2025.iso'
```

```powershell
# Validate ISO + firmware locations together (same shared resolver for both)
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' `
    -FirmwareFolders @('\\fileserver\fw\BIOS', 'H:\fw\iLO5')
```

```powershell
# Validate the path format only (skip checking the files exist)
Test-BuildParams -BaseIsoPath '\\fileserver\isos\WinSrv2025.iso' -DryRun
```

**Returns:** `[hashtable]` with `Success`, `BaseIsoPath`, `IsoUrl` (resolved cifs://, https://, or nfs:// address iLO uses), `ResolvedPath`, `FirmwareResults` (per-location `{Location, ResolvedUrl, Exists, Error}`), and `Errors` (array; empty when valid). On success `IsoUrl` holds the converted share address.

---

<a id="iso-image-naming-smb-shares"></a>

## ISO Image Naming & SMB Shares

How ISO filenames are generated and how local ISO paths are exposed to the iLO BMC over SMB/CIFS. Read this before passing a local path to a deploy command so you know the expected filename and the share name the iLO will mount.

<a id="bootable-iso-filename-convention"></a>

### Bootable ISO filename convention

When building a ConfigMgr bootable ISO, use the standard naming convention:

```
WinSrv2025_HPE_BootableMedia_v<Major.Minor>.iso
```

- `<Major>` / `<Minor>` come from `-VersionMajor` (default `1`) and `-VersionMinor` (default `0`).
- If a file already exists at the resolved path it is reused; pass explicit `-VersionMajor`/`-VersionMinor` or a unique `-OutputPath` to control the name.

Example generated names:

| Scenario | Resulting file |
|----------|----------------|
| Default build | `WinSrv2025_HPE_BootableMedia_v1.0.iso` |
| Custom version | `WinSrv2025_HPE_BootableMedia_v2.1.iso` |

<a id="iso-path-requirements-no-local-drives"></a>

### ISO path requirements (no local drives)

The iLO BMC is a separate physical controller and **cannot** read local drives (`C:\`, `H:\` on a local disk) on your workstation. Always supply a **network-accessible path to the file** — this module **does not** auto-create SMB shares and **never** requires Administrator privileges (regulated banking environment).

All of the following work and resolve to the address iLO mounts as virtual media (SMB/UNC paths are converted to a `cifs://…` URL; HTTPS/NFS URLs are used directly):

| Format | Example | Notes |
|--------|---------|-------|
| HTTPS URL | `https://artifacts.internal.example.com/isos/win2025.iso` | Used directly; iLO downloads — no auth prompt |
| NFS path | `nfs://fileserver/export/win2025.iso` | Used directly; iLO mounts via NFS |
| UNC/SMB path (backslash) | `\\fileserver\isos\win2025.iso` | Converted to `cifs://…`; ensure iLO can reach the share |
| UNC/SMB path (forward slash) | `//fileserver/isos/win2025.iso` | Same as above — Windows treats `//` and `\\` as identical |
| CIFS/SMB URL | `cifs://fileserver/isos/win2025.iso` | Used directly (round-trips the URL this tool emits) |
| SMB URL alias | `smb://fileserver/isos/win2025.iso` | Normalised to `cifs://…` |
| Mapped network drive | `H:\win2025.iso` (H: maps to `\\fileserver\isos`) | Expanded to its UNC share, then `cifs://…` |

> **Point at the file, not the share.** Supply the full path to the `.iso` (or firmware `.zip`/folder), e.g. `\\fileserver\isos\win2025.iso`. A bare `\\fileserver\isos\` with no filename is not a deployable image.

**Not supported:** local drives (`C:\isos\…`, or a letter mapped to a *local* disk). Passing one fails with an error telling you to supply an SMB/UNC or HTTPS path instead.

> **Full format reference:** see [Path Parameter Formats](../PathParameterFormats.md#top) for every accepted `-ExternalIsoPath` / `-IsoPath` / `-FirmwareFolders` format, including the single-slash `/server/share` autocorrection and the list of unsupported local paths.

```powershell
# Any of these work — pick the form that matches how your file is shared:
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath '\\fileserver\isos\win2025.iso' -GuardRail 'srv01'   # UNC (backslash)
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath '//fileserver/isos/win2025.iso' -GuardRail 'srv01'   # UNC (forward slash)
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath 'cifs://fileserver/isos/win2025.iso' -GuardRail 'srv01'   # CIFS URL
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath 'H:\win2025.iso' -GuardRail 'srv01'   # Mapped drive
Configure-PhysicalBuild -ServerIdentifier srv01 -ExternalIsoPath 'https://artifacts.internal.example.com/isos/win2025.iso' -GuardRail 'srv01'
```

---

<a id="physical-server-build-end-to-end"></a>

## Physical Server Build (End-to-End)

The full runbook workflow in one command: pre-build validation, ConfigMgr bootable ISO, OneView target resolution, iLO Redfish mount + boot, installation monitoring, post-build validation, firmware update, and audit logging. Supports two modes:

- **Build mode** (default): Builds a ConfigMgr bootable ISO and deploys it.
- **External ISO mode** (`-ExternalIsoPath`): Deploys a client-supplied ISO directly from a network share (UNC/SMB, `cifs://`, `smb://`, or HTTPS), skipping build and publish entirely.

> **ConfigMgr parameters** (`-SiteCode`, `-ManagementPoint`, `-DistributionPoint`, `-BootImageName`, `-TaskSequenceName`, `-SiteServer`): only needed in **Build mode**. When using `-ExternalIsoPath`, these are not required because the ISO build/publish steps are skipped.

<a id="configure-build-4-eye-review"></a>

### Configure build (4-eye review)

Use `Configure-PhysicalBuild` to review the full deployment plan before anything destructive happens. The review itself makes **no changes** — it resolves server identity from OneView, validates ISO reachability, runs pre-build checks, and prints a comprehensive summary including all destructive actions that the build/deploy will perform. However, it is the **authorization gate**: typing `APPROVE` or passing `-Deploy` (alias `-Execute`) releases the destructive build and deploy of the iso image and firmware files being written to the designated server. 

```powershell
# Full 4-eye review with confirmation prompt
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -SiteCode P01 -ManagementPoint mp01.corp.local -DistributionPoint dp01.corp.local `
    -Domain corp.local -GuardRail 'srv01'
```

```powershell
# Non-interactive deploy — passes -Deploy to skip the prompt and run immediately
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -ExternalIsoPath 'https://artifacts/isos/win2025.iso' -Deploy -GuardRail 'srv01'
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-ServerIdentifier` | Yes | Target server identifier (hostname, serial, OneView name, iLO IP, bay). |
| `-OneViewHost` | No | OneView appliance hostname/IP for server resolution. |
| `-IloIp` | No | iLO IPv4 address / hostname for the target server. |
| `-IloCredential` | No | PSCredential for iLO Redfish check (prompted if omitted). |
| `-ExpectedHostname` | No | Hostname expected after build. Defaults to `-ServerIdentifier`. Only needed if the post-build hostname will differ from the identifier. |
| `-Domain` | No | AD domain to verify in post-build validation. |
| `-SiteCode` | No | ConfigMgr site code (for ISO build / pre-build validation). |
| `-ManagementPoint` | No | ConfigMgr Management Point FQDN (for ISO build / pre-build validation). |
| `-DistributionPoint` | No | ConfigMgr Distribution Point FQDN (for ISO build / pre-build validation). |
| `-SiteServer` | No | ConfigMgr site server FQDN for PSRemoting fallback. |
| `-BootImageName` | No | ConfigMgr boot image name to embed. |
| `-TaskSequenceName` | No | ConfigMgr task sequence name (informational). |
| `-ExternalIsoPath` | No | Client-supplied ISO (UNC/SMB incl. `//server/share`, `cifs://`/`smb://` URLs, HTTPS, NFS, or a mapped network drive; local paths not supported). When supplied, ConfigMgr build/publish is skipped. |
| `-GuardRail` | Yes | **MANDATORY** safety gate for shared/production networks. A CASE-INSENSITIVE **REGEX** the resolved target server name must match before the build plan is even produced. Omitting it aborts early with an expressive, logged error. If it does not match, the review is aborted. Example: `-GuardRail 'quickview\.ilo0'` matches server `quickview.ilo03.alp`. |
| `-InMaintenanceWindow` | No | Acknowledge approved maintenance window. |
| `-OneViewMaintenanceMode` | No | Enable HPE OneView maintenance mode before destructive operations (ISO mount, reboot) and disable it after the build completes. Default is `$true`. Set to `$false` to skip (e.g. when OneView is unavailable). |
| `-NoMaintenanceMode` | No | Convenience switch to disable OneView maintenance mode. Equivalent to `-OneViewMaintenanceMode:$false`. |
| `-SkipPreBuild` | No | Skip pre-build validation. |
| `-SkipOneView` | No | Skip OneView target resolution. |
| `-SkipIlo` | No | Skip iLO credential check. |
| `-SkipDpMp` | No | Skip MP/DP reachability check. |
| `-SkipIsoUrl` | No | Skip ISO URL reachability check. |
| `-Force` | No | Acknowledge server power state is On (informational only — no reboot performed). |
| `-Deploy` | No | Authorize the destructive build immediately (alias `-Execute`). Skips the interactive `APPROVE` prompt. |
| `-PassThru` | No | Return the structured result hashtable on the success stream (for scripting). |
| `-Json` | No | Emit the result as a JSON string on the success stream. |

> **Build mode vs External ISO mode:** When you supply `-ExternalIsoPath`, the ConfigMgr parameters (`-SiteCode`, `-ManagementPoint`, `-DistributionPoint`, `-BootImageName`, `-TaskSequenceName`, `-SiteServer`) are **not required** because the ISO build/publish steps are skipped.

**Automatic OneView maintenance mode:** By default, `Configure-PhysicalBuild` automatically places the target server into HPE OneView maintenance mode **before** any destructive action (ISO mount, reboot) and remove it **after** the build completes. This stops unnecessary alerting and avoids on-call callouts during deployment. A highlighted notice appears in the deployment summary:

```text
> ╔══════════════════════════════════════════════════════════════════════╗
> ║  🔇  ONEVIEW MAINTENANCE MODE (automatic)                            ║
> ╠══════════════════════════════════════════════════════════════════════╣
> ║  This server will be put into HPE OneView maintenance mode           ║
> ║  BEFORE the build starts. This stops unnecessary alerting            ║
> ║  and avoids on-call callouts during the deployment.                  ║
> ║                                                                      ║
> ║  Maintenance mode will be automatically removed when the             ║
> ║  build completes (or if it fails).                                   ║
> ║                                                                      ║
> ║  To skip this, use -NoMaintenanceMode.                               ║
> ╚══════════════════════════════════════════════════════════════════════╝
> ```
> Use `-NoMaintenanceMode` (or `-OneViewMaintenanceMode:$false`) to disable this behavior when OneView is unavailable or the server is not managed by OneView.

---

<a id="full-build-most-common"></a>

### Full build (most common)

`Configure-PhysicalBuild` is the only build command you run from the terminal. It performs the full 4-eye review internally and, on authorization (typing `APPROVE` or passing `-Deploy`/`-Execute`), executes the build pipeline internally. There is no separate command to call directly.

```powershell
# Review + deploy in one command (recommended)
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' -InMaintenanceWindow -Deploy -GuardRail 'srv01'
```

> **Automatic OneView maintenance mode:** `Configure-PhysicalBuild` automatically places the server into HPE OneView maintenance mode before destructive operations and removes it after the build completes. Use `-NoMaintenanceMode` to skip this behavior.

<a id="dry-run-validate-without-changing-anything"></a>

### Dry run (validate without changing anything)

```powershell
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' -DryRun -GuardRail 'srv01'
```

<a id="re-run-monitoring-after-deployment"></a>

### Re-run monitoring after deployment

```powershell
Configure-PhysicalBuild -ServerIdentifier srv01 -SkipPreBuild -SkipOneView -SkipMount -InMaintenanceWindow -GuardRail 'srv01'
```

<a id="build-with-custom-domain-and-post-build-checks"></a>

### Build with custom domain and post-build checks

```powershell
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local -IloIp 10.0.1.50 `
    -ExpectedHostname srv01.corp.local -Domain corp.local -ExternalIsoPath '\\fileserver\isos\WinSrv2025.iso' `
    -InMaintenanceWindow -Deploy -GuardRail 'srv01'
```

---

<a id="iso-deployment-monitoring"></a>

## ISO Deployment & Monitoring

Commands for deploying ISOs to servers and monitoring installation progress.

<a id="monitor-installation-progress"></a>

### Monitor installation progress

**What it does:**
- Watches an **in-progress** OS installation started by `Configure-PhysicalBuild`.
- Polls the server (via OneView/iLO) on an interval and reports progress/status.
- **Read-only / non-destructive** — it only observes; it never reboots, mounts, or changes the server.
- Safe to run on a live appliance at any time (use it to confirm a build is progressing).

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

<a id="ilo-redfish-operations"></a>

### iLO Redfish operations

**What it does:** Talks directly to a server's iLO BMC over Redfish to control virtual media and power.

- `Status` — read the server's current power state and mounted media. **Non-destructive.**
- `Mount` — attach an ISO as virtual media (no reboot yet). Prepares an install but changes nothing on disk.
- `Eject` — detach virtual media. **Non-destructive.**
- `Boot` — set one-time boot to the mounted media (no immediate reboot).
- `MountAndBoot` — mount the ISO **and reboot into it**. **DESTRUCTIVE** — wipes/reinstalls the server.
- `Reset` — force a power reset/reboot. **DESTRUCTIVE.**

Requires `-Force` for `Reset`/`MountAndBoot`; otherwise it prompts. `-DryRun` prints the action without performing it.

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

<a id="resolve-server-target-via-oneview"></a>

### Resolve server target via OneView

**What it does (functionality):**
- Resolves **one** server from OneView by name, serial, iLO IP, or bay.
- **Strict single-server:** if a name/serial matches more than one server it **fails** (never silently picks one) — this protects the destructive steps that follow.
- Validates the resolved server (power state, health, iLO IP, maintenance mode).
- Reuses an active OneView connection if present; otherwise connects with the supplied `-OneViewHost` (prompts for credentials). It never disconnects.
- **Read-only / non-destructive** — it only looks up and validates; it changes nothing.
- This is the single resolver every build/deploy command uses, so targeting stays consistent.

Resolves and validates a target server via OneView. **This is the central single-server module** every OneView automation command that acts on one server uses (via `Resolve-OneViewTarget`), so targeting is consistent and strict across the pipeline. **Strict single-server:** a name or serial that matches more than one server is a hard failure - it never silently picks the first, because it underpins destructive operations (ISO attach/deploy, reboot, OS build). **Connection behaviour (shared helper):** an existing OneView connection always takes priority - a live session is reused and never reconnected (to avoid dropping it); if you supplied a different `-OneViewHost` you are warned which appliance you are on and to `Disconnect-OneView` first to switch. When nothing is connected, supplying `-OneViewHost` establishes a persistent session automatically, prompting for username and password interactively as needed (exactly like `Test-ServerConnectivity` / `Connect-OneView`). With no host and no active session it returns an exception explaining there is none. The session persists - this command never disconnects (only `Disconnect-OneView` does). The build pipeline (`Test-PostBuildValidation`, `Start-InstallMonitor`, etc.) all resolve through this module and inherit both behaviours.

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

> **One-parameter targeting:** `-IdentifierType` defaults to `Auto`, which tries Name, Serial, OneViewName, iLO IP, then EnclosureBay in turn. So `-ServerIdentifier <value>` (or its alias `-SrvrId <value>`) alone resolves the server - you do **not** need to pass `-IdentifierType`. The explicit type is only required to disambiguate when a value could match more than one form.

**Returns:** `[hashtable]` with `Success`, `Server`, `ResolvedBy`, `Details`, and `Error`.

---

<a id="pre-build-validation"></a>

### Pre-build validation

**What it does:** Runs a set of **read-only readiness checks** before any build/deploy, so problems are caught without touching the server:
- **OneView target** — confirms the server resolves via `Get-OneViewServerTarget` (strict single-server).
- **iLO credentials** — verifies iLO login works for the target.
- **ConfigMgr MP/DP** — checks the Management Point / Distribution Point are reachable (skippable).
- **ISO URL** — verifies the boot ISO URL is reachable (skippable).
- **Boot image / task sequence** — validates the named ConfigMgr objects exist (skippable).

**Non-destructive** — checks only; no reboot, mount, or install. Safe on a live appliance. Use `-DryRun` to validate inputs and skip the live network probes entirely.

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

<a id="post-build-validation"></a>

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

---

<a id="patch-windows-iso-with-security-updates"></a>

### Patch Windows ISO with security updates

**What it does:** Injects Windows security updates into a **base Windows Server ISO** (offline DISM servicing) and writes a **patched ISO** file.
- It patches the **ISO image**, **not** a live running server — no server is touched.
- This is an optional **build-time** aid so the boot media ships already-patched; live OS security patching on deployed servers remains BladeLogic's responsibility.
- **Destructive: FALSE for servers** (no server impact). It does write/overwrite an ISO file on disk at `OutputDir`.

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

<a id="maintenance-mode"></a>

## Maintenance Mode

See [`CLIENT-QUICK-START.md`](../CLIENT-QUICK-START.md#top) for the full guide.

<a id="examples"></a>

### Examples

```powershell
Set-MaintenanceMode -Action enable -Mode oneview -SerialNumber ABC123XYZ -Environment Test
```

---

<a id="powershell-execution-and-utility"></a>

## PowerShell Execution and Utility

Low-level helpers used by other commands.

<a id="run-a-local-powershell-script"></a>

### Run a local PowerShell script

**What it does:** Runs a PowerShell **script string** locally in a fresh `pwsh` (PowerShell 7+) process — or remotely via `Invoke-PowerShellWinRM` (below) — with configurable timeout, execution policy, and output capture. It is a generic execution utility, **not** part of the core build/deploy flow.

- **Destructive: DEPENDS ON THE SCRIPT** — the wrapper is neutral; whatever script you pass decides the effect (it can reboot, reconfigure, or change anything the account is allowed to). Run only reviewed scripts from a trusted source.
- The local form runs on the **automation host**; use the WinRM form with `-Server` to run against a target server.

Executes PowerShell scripts locally by spawning a new PowerShell process with configurable timeout, execution policy, and output capture. Prefers `pwsh` (PowerShell 7+) on all platforms and falls back to `powershell.exe` (Windows PowerShell 5.1) only when `pwsh` * is not available.

```powershell
Invoke-PowerShellScript -Script 'Get-Process | Select-Object -First 5' -TimeoutSeconds 30
```

<a id="run-a-remote-powershell-script-via-winrm"></a>

### Run a remote PowerShell script via WinRM

```powershell
Invoke-PowerShellWinRM -Script 'Get-Service wuauserv' -Server srv01
```

<a id="generate-a-deterministic-uuid"></a>

### Generate a deterministic UUID

```powershell
New-Uuid -ServerName srv01
```

<a id="opsramp-api-client"></a>

### OpsRamp API client

**What it does:** Integration helper for the **OpsRamp** monitoring/ITSM platform.
- `Invoke-OpsRampClient -ConfigPath <opsramp_config.json>` is a **factory** that returns an `OpsRamp_Client` object for sending metrics, alerts, and events to OpsRamp from your own scripts.
- Companion `Invoke-OpsRamp` performs a quick **connectivity test** (obtains an API token) to verify credentials/network before a full integration.
- **Destructive: FALSE** — monitoring/ITSM integration only; it makes no change to the target server or the build.

```powershell
Invoke-OpsRampClient
```

---

<a id="routing-and-control-surfaces"></a>

## Routing and Control Surfaces

Dispatch requests to the appropriate handler.

<a id="orchestrator-unified-entry-point"></a>

### Orchestrator (unified entry point)

```powershell
Start-AutomationOrchestrator -RequestType build_iso -Params @{ SiteCode = 'P01'; ManagementPoint = 'mp01.corp.local' }
```

<a id="view-the-route-map"></a>

### View the route map

```powershell
Get-RouteMap
```

<a id="control-surface-factories-and-runners"></a>

### Control surface factories and runners

```powershell
Run-CIPipeline -Params @{ Stage = 'build'; Version = '1.0' }
Run-Scheduler -TaskParams @{ Server = 'srv01'; Timeout = 3600 }
Run-GitLab -Params @{ TargetId = 'CLU-01'; Action = 'enable' }
```

<a id="gitlab-maintenance-trigger"></a>

### GitLab maintenance trigger

```powershell
```

---

<a id="functional-test-harnesses"></a>

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

<a id="testconnectandlist"></a>

### testConnectAndList

Non-destructive connectivity / connection / server-lookup harness. Proves every
read-only command fails **gracefully** without a session and succeeds **with** one,
and runs a parameter-combination matrix.

```powershell
pwsh scripts/testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com
pwsh scripts/testConnectAndList.ps1 -OneViewHost oneview-test.ad.example.com -Live -Credential $cred
```

<a id="testbuilddeploy"></a>

### testBuildDeploy

Build/deploy pipeline harness with the **mandatory `-GuardRail`** safety gate.
Validates ISO path → iLO-accessible URL conversion, guard-rail match / non-match /
omitted behaviour, the confirmation flow, and build/deploy variants — all under
`-DryRun` unless `-Live` is supplied.

```powershell
pwsh scripts/testBuildDeploy.ps1 -OneViewHost oneview-test.ad.example.com -Server srv01 -GuardRail 'srv0'
pwsh scripts/testBuildDeploy.ps1 -Server srv01 -ExternalIsoPath '\\fileserver\isos\win.iso' -GuardRail 'srv0'
```

<a id="troubleshooting"></a>

## Troubleshooting

<a id="command-not-found"></a>

### Command not found

```powershell
. $PROFILE
Get-Command -Module Automation
```

<a id="run-setup-again"></a>

### Run setup again

```powershell
./scripts/Setup-Profile.ps1
```

<a id="check-module-is-loaded"></a>

### Check module is loaded

```powershell
Get-Module Automation
```

<a id="force-reimport"></a>

### Force reimport

```powershell
Import-Module (Get-ChildItem -Recurse -Filter 'Automation.psd1' -Path (Split-Path (Get-Command Setup-Profile).Source | Split-Path) | Select -First 1).FullName -Force
```

<a id="source-links"></a>

### Source links

[Generated API reference](../dynamic-code-docs/INDEX.md#top) with per-command detail pages.
