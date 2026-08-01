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

<a name="standards"></a>

## Standards

These are the agreed engineering standards (DevOps, HPE OneView, PowerShell),
aligned with the automation HPE OneView requirements in
`docs/Automation/runbook-requirements.md` (the authoritative runbook for
physical HPE server build automation). They are the yardstick used to advise
when a request would go against best practice.

<a name="devops"></a>

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

<a name="hpe-oneview"></a>

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
  (via `Test-ServerConnectivity -ManagementHost` and `Get-OneViewConnectionStatus`).
- **Credential & transport hygiene.** Never hard-code OneView/iLO credentials;
  source them from a secret store / pipeline secret vault. Prefer trusted TLS
  certificates over certificate-bypass (lab/test only) - runbook Security &
  Control Requirements.

<a name="powershell"></a>

### PowerShell

- **OS-aware module handling.** The `HPEOneView.*` libraries are Windows-only.
  Enumerating or importing them off-Windows (`Get-Module -ListAvailable`) crashes
  the native PowerShell layer on Linux/macOS, so resolution/import is skipped
  off-Windows and falls back to the env override / default name. (The actual
  `Connect-OVMgmt` import remains a Windows-only operation; unit tests mock it.)
- **No dead code.** Remove helpers that are no longer referenced.
- **Centralised session logic.** All OneView calls route through
  `Connect-OneViewSession`; shared session helpers live in `OneViewSession.ps1`.
- **Parse-safe module load.** Code must load cleanly under PowerShell 7 (the
  module's required runtime); no PS 5.1-specific workarounds.
- **Redfish/REST consistency.** iLO and OneView operations follow the Redfish /
  REST patterns documented in the runbook (e.g. virtual-media insert, boot-source
  override, reset).

<a name="changes"></a>

## Changes

<a name="2026-07-30-oneview-module-pinning-reworked-to-latest-installed-on-this-server"></a>

### 2026-07-30 - OneView module pinning reworked to "latest installed on this server"

- `Resolve-PinnedOneViewModule` now pins the **latest `HPEOneView.*` module
  installed on the automation server** instead of probing the appliance and
  matching its minor version. Resolution order: `ONEVIEW_MODULE_NAME` override
  → latest installed module → `HPEOneView.1000`. The previous appliance-minor
  matching was brittle and contradicted HPE's backward-compatibility design.
- Added a **hard guard** in `Connect-OneViewSession`: if the selected module's
  major version is **older** than the appliance's major version, the connection
  is refused with a clear error (the only unsupported combination).
- `Test-ServerConnectivity -ManagementHost` and `Get-OneViewConnectionStatus`
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

<a name="2026-07-30-documentation-tooling-aligned-between-make-docs-and-make-fix-docs"></a>

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
