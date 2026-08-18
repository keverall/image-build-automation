# Changes

<a id="top"></a>

## Table of Contents

- [Standards](#standards)
  - [DevOps](#devops)
  - [HPE OneView](#hpe-oneview)
  - [PowerShell](#powershell)
- [Changes](#changes)
  - [2026-07-30 - OneView module pinning reworked to "latest installed on this server"](#2026-07-30-oneview-module-pinning-reworked-to-latest-installed-on-this-server)
  - [2026-07-30 - Documentation tooling aligned between make docs and make fix-docs](#2026-07-30-documentation-tooling-aligned-between-make-docs-and-make-fix-docs)
  - [2026-08-13 - OneView list/status commands print formatted tables](#2026-08-13-oneview-liststatus-commands-print-formatted-tables)
  - [2026-08-13 - Standardized OneView host parameter on -OneViewHost](#2026-08-13-standardized-oneview-host-parameter-on-oneviewhost)

Standard, dated changelog for the `image-build-automation` repository. Major,
user-facing changes are recorded here with dates. The **Standards** section
documents the engineering principles that govern these changes; deviations
from them should be flagged for review before they land. The Standards are
aligned with the automation HPE OneView requirements in
`docs/Automation/runbook-requirements.md`.

This changelog starts on **2026-07-30**; earlier changes are available in git
history (`git log`).

> Note: `wip/changes.md` is an unrelated scratch file with stale/incorrect paths
> and is excluded from documentation. This root `changes.md` is the canonical
> changelog.

<a id="standards"></a>

## Standards

These are the agreed engineering standards (DevOps, HPE OneView, PowerShell),
aligned with the automation HPE OneView requirements in
`docs/Automation/runbook-requirements.md` (the authoritative runbook for
physical HPE server build automation). They are the yardstick used to advise
when a request would go against best practice.

<a id="devops"></a>

### DevOps

- **Sensible default + explicit override.** Automation pins the latest
  `HPEOneView.*` module installed on the server running the code. Pipelines pin
  an *exact, reproducible* version via the `ONEVIEW_MODULE_NAME` environment
  variable. Dynamic "latest" is the convenience default; the override is for
  reproducible CI/CD.
- **Read-only checks must not mutate state.** Commands such as
  `Test-ServerConnectivity` and `Get-OneViewConnectionStatus` only read; they
  never change appliance or server state.
- **Idempotent, controlled connections.** A session, once established, is reused;
  we never silently drop a live session (only `Disconnect-OneView` closes it).
- **Auditability & change control.** Record who initiated an action, which
  server was targeted, which module/ISO was used, and the outcome (per the
  runbook's Security & Control Requirements); production builds follow approval /
  CRQ traceability where required.

<a id="hpe-oneview"></a>

### HPE OneView

- **OneView is the authoritative targeting source.** Managed HPE ProLiant/Synergy
  servers are identified and validated through the OneView REST API; query
  `server-hardware` by name, serial number, bay/enclosure, or approved identifier.
- **Target one server, validate before mutating.** Resolve the single target
  explicitly and verify its hardware/power/health state before any mutating
  operation; stop immediately and follow incident/change procedure if the wrong
  server is selected (runbook §10.4 / Validation Checklist).
- **Use the newest installed module.** The latest `HPEOneView` module is
  backward-compatible with older appliances, so pinning to the latest installed
  module is both HPE's recommended practice and the safest choice.
- **Never use a module older than the appliance.** An older PowerShell library
  against a newer appliance is the root cause of 502 / corrupted-state failures.
  `Connect-OneViewSession` now hard-errors on this combination.
- **Make versions visible.** Every OneView call surfaces both the HPEOneView
  PowerShell module version used and the appliance OneView version connected to
  (via `Test-ServerConnectivity -OneViewHost` and `Get-OneViewConnectionStatus`).
- **Credential & transport hygiene.** Never hard-code OneView/iLO credentials;
  source them from a secret store / pipeline secret vault. Prefer trusted TLS
  certificates over certificate-bypass (lab/test only) - runbook Security &
  Control Requirements.

<a id="powershell"></a>

### PowerShell

- **OS-aware module handling.** The `HPEOneView.*` libraries are Windows-only.
  Enumerating or importing them off-Windows (`Get-Module -ListAvailable`) crashes
  the native PowerShell layer on Linux/macOS, so resolution/import is skipped
  off-Windows and falls back to the env override / default name. (The actual
  `Connect-OVMgmt` import remains a Windows-only operation; unit tests mock it.)
- **No dead code.** Remove helpers that are no longer referenced.
- **Centralised session logic.** All OneView calls route through
  `Connect-OneViewSession`; shared session helpers live in `OneViewSession.ps1`.
- **One canonical host parameter.** The OneView appliance host is always
  `-OneViewHost` (alias `-OVHost`). The legacy `-ManagementHost` is retained only
  as a deprecated alias on the OneView commands; the SCOM management-server host
  in `Get-MaintenanceStatusReport`/`Test-ScomMaintenanceConnectivity` is a
  distinct parameter and is unchanged.
- **Human-readable terminal output.** Interactive commands print formatted
  tables/lists, never a raw hashtable/json dump of the returned object. The
  structured object is still available via `-PassThru` for scripts and the Router.
- **Parse-safe module load.** Code must load cleanly under PowerShell 7 (the
  module's required runtime); no PS 5.1-specific workarounds.
- **Redfish/REST consistency.** iLO and OneView operations follow the Redfish /
  REST patterns documented in the runbook (e.g. virtual-media insert, boot-source
  override, reset).

<a id="changes"></a>

## Changes

<a id="2026-07-30-oneview-module-pinning-reworked-to-latest-installed-on-this-server"></a>

### 2026-07-30 - OneView module pinning reworked to "latest installed on this server"

- `Resolve-PinnedOneViewModule` now pins the **latest `HPEOneView.*` module
  installed on the automation server** instead of probing the appliance and
  matching its minor version. Resolution order: `ONEVIEW_MODULE_NAME` override
  → latest installed module → `HPEOneView.1000`. The previous appliance-minor
  matching was brittle and contradicted HPE's backward-compatibility design.
- Added a **hard guard** in `Connect-OneViewSession`: if the selected module's
  major version is **older** than the appliance's major version, the connection
  is refused with a clear error (the only unsupported combination).
- `Test-ServerConnectivity -OneViewHost` and `Get-OneViewConnectionStatus`
  now report **both** the HPEOneView PowerShell module version used and the
  appliance OneView version connected to.
- `Connect-OneViewSession` result gained `ModuleVersion` and `ApplianceVersion`.
- Removed the brittle "module major must equal appliance major" guard; replaced
  with the correct backward-compatible rule (module major >= appliance major is
  fine) in `Get-OneViewConnectionStatus`.
- Removed dead helper `Get-OneViewVersionPair`; re-added `Get-OneViewApplianceMajorVersion`
  to support the older-module guard.
- Fixed a native crash on Linux: removed off-Windows `Get-Module -ListAvailable`
  scans in `Resolve-PinnedOneViewModule`, `Connect-OneViewSession`, and
  `Get-OneViewModuleStatus`. All OneView automation tests now pass (99/99) on
  Linux without segfaulting.

<a id="2026-07-30-documentation-tooling-aligned-between-make-docs-and-make-fix-docs"></a>

### 2026-07-30 - Documentation tooling aligned between make docs and make fix-docs

- `make docs` and `make fix-docs` now share a single canonicalization module
  (`scripts/Docs.Common.ps1`) for logging and the `<a id="top"></a>` anchor, so the
  two targets can no longer drift apart; `make docs` also runs markdown link
  validation/fixing.
- Fixed markdown anchor/TOC spacing for MD022/MD012 compliance: each anchor now has
  a single blank line before its heading, and headings are separated from preceding
  lists by a blank line.
- The `<a id="top"></a>` anchor is now placed immediately below the first H1 and
  above the Table of Contents, where `#top` fragment links expect it.
- Collapsed multiple consecutive blank lines into a single blank line across all
  generated documentation.

<a id="2026-08-13-oneview-liststatus-commands-print-formatted-tables"></a>

### 2026-08-13 - OneView list/status commands print formatted tables

- `Get-OneViewServerList` and `Get-OneViewConnectionStatus` now print a
  **human-readable, formatted table** to the terminal instead of dumping the raw
  returned hashtable/json. Blank fields and duplicate values are suppressed
  (e.g. the redundant `ApplianceVersion`/`Version` pair and empty `Server`/
  `ServerCount`/`VersionWarning`/`Error` rows). When a filtered server list is
  empty, a single "No servers matched the request." line is shown.
- Added a `-PassThru` switch (alias `-PT`) to both commands. By default they emit
  only the formatted table and return nothing to the pipeline; `-PassThru`
  returns the structured `[hashtable]` for scripts and the module Router. Internal
  caller `Get-MaintenanceStatusReport` was updated to pass `-PassThru`.
- `Get-OneViewConnectionStatus` gained a concise `_Format-ConnectionStatusResult`
  summary (Status / Appliance / Reachable / Auth / Version / Module / Mod Compat /
  Session, plus an optional Server block) mirroring the `Test-ServerConnectivity`
  output style.
- Unit tests for both commands were updated to assert against the `-PassThru`
  object; all affected suites pass (`Get-OneViewServerList` 10/10,
  `Get-OneViewConnectionStatus` 17/17).

<a id="2026-08-13-standardized-oneview-host-parameter-on-oneviewhost"></a>

### 2026-08-13 - Standardized OneView host parameter on -OneViewHost

- The OneView appliance host is now the single canonical `-OneViewHost` parameter
  (alias `-OVHost`) across `Test-ServerConnectivity`, `Connect-OneView`, and
  `Set-MaintenanceMode`. The returned result key was also renamed
  `ManagementHost` → `OneViewHost`.
- The legacy `-ManagementHost` is retained **only as a deprecated alias** on those
  three OneView commands, so existing scripts/tests keep working without breakage.
  The SCOM management-server host in `Get-MaintenanceStatusReport` and
  `Test-ScomMaintenanceConnectivity` is a distinct parameter and is unchanged.
- Fixed a correctness bug in `Test-ServerConnectivity`: when a host was supplied
  without an active session or credentials, it **early-returned with a fabricated
  failed network result** ("DNS: FAILED / No credentials available") without ever
  probing the network. The network phase (DNS/TCP) now always runs and reports
  accurately; only the auth phase is skipped gracefully when no session/credential
  is available. Supplying a host that matches the active session still reuses that
  session (no credentials needed).
- In-code help/strings and user-facing messages were updated to reference
  `-OneViewHost` (e.g. `OneViewSession.ps1` no-session message,
  `Get-OneViewConnectionStatus` connect hint, `Logging.ps1` example). Test suites
  for the three commands were updated to `-OneViewHost` and pass
  (`Connect-OneView` 6/6, `Test-ServerConnectivity` 38/38,
  `Set-MaintenanceMode.Environment` 27/27). The whole module parses cleanly with
  no duplicate parameter/alias definitions.
