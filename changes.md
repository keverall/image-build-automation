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

test results -

 image-build-automation  Test-ServerConnectivity                                     0  09:41:54 
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       
  Environment:Prod
  Timestamp:  2026-08-11T08:42:18.6050975Z 

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     No active OneView connection. Connect first with Connect-OneView -ManagementHost <host> (server name or serial), or supply -ManagementHost to test a specific appliance.
 
  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no active connection  

============================================== 

Name                           Value   
----                           -----   
Mode                           oneview 
Available                      False
NetworkPing                    {[Error, No active OneView connection. Connect first with Connect-One… 
Timestamp                      2026-08-11T08:42:18.6050975Z
AuthConnect                    {[Connected, False], [Error, Skipped - no active connection]}
ManagementHost
Environment                    Prod

   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01      0  09:42:18 
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-11T08:42:34.4115625Z     

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     No credentials available to authenticate against 'va-oneviewt-01'. 

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no credentials. Connect with Connect-OneView -ManagementHost <host> or supply -Credential / set ONEVIEW_USER + ONEVIEW_PASSWORD.

==============================================

Name                           Value
----                           ----- 
Mode                           oneview
Available                      False
NetworkPing                    {[Error, No credentials available to authenticate against 'va-oneview… 
Timestamp                      2026-08-11T08:42:34.4115625Z
AuthConnect                    {[Connected, False], [Error, Skipped - no credentials. Connect with C… 
ManagementHost                 va-oneviewt-01
Environment                    Prod

   image-build-automation                                                    0  1s 865ms  09:42:34    image-build-automation  Disconnect-OneView                                          0  09:42:34 WARNING: No active OneView session. Use Test-ServerConnectivity -ManagementHost <oneview-appliance-host> to connect, or supply -OneViewHost. Nothing to disconnect.

Name                           Value
----                           -----
Success                        False
Timestamp                      2026-08-11T08:43:07.1799497Z
Message                        No active OneView session. Use Test-ServerConnectivity -ManagementHos… 

   image-build-automation  Get-OneViewConnectionStatus                                 0  09:43:07  
Name                           Value
----                           -----
Success                        False
Authenticated                  False
Connected                      False
Error                          No active OneView session. Use Test-ServerConnectivity -ManagementHos… 
Appliance
Reachable                      False

   image-build-automation  Get-OneViewServerList                                       0  09:43:43 
Name                           Value
----                           -----
Success                        False
Count                          0
Servers                        {}
Error                          No active OneView session. Use Test-ServerConnectivity -ManagementHos… 

   image-build-automation  Get-OneViewServerList -OneViewHost va-oneviewt-01           0  09:43:51 Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : ****************** 
This management appliance is a company owned asset and provided for the exclusive use of authorized personnel. Unauthorized use or abuse of this system may lead to corrective action including termination, civil and/or criminal penalties.

============================================== 
  OneView Server List (16 servers)
============================================== 
 
Server Name                      Serial Number    Power     Health      iLO IP          
---------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK                          
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning                     
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

Name                           Value
----                           -----
Success                        True
Count                          16
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, AL… 
Error

   image-build-automation  Get-OneViewServerList                             1m 6s 986ms  09:45:20 
============================================== 
  OneView Server List (16 servers)
==============================================
 
Server Name                      Serial Number    Power     Health      iLO IP
---------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK                          
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================

Name                           Value 
----                           ----- 
Success                        True 
Count                          16 
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, AL… 
Error

   image-build-automation  Get-OneViewServerList -OneViewHost va-oneviewt-01           0  10:26:12 
============================================== 
  OneView Server List (16 servers)
==============================================
 
Server Name                      Serial Number    Power     Health      iLO IP
---------------------------------------------------------------------------------------
OMG-STARWAY-01ILO.AD.AIB.PRI     CZJ831052N       On        OK
ALP-WISCLU-01ilo                 CZ3508PYS5       On        OK
OMG-WISCLU-01ilo                 CZJ5500337       On        OK
ALP-STARWAY-01ILO                CZJ831052R       On        OK
gam-isechost-02-03ilo.ad.ad.pri  CZ29350B60       On        OK
gamdmzhost-01-03ilo.AD.AIB.PRI   CZ29350B5Y       On        OK
gamdmzhost-02-03ilo              CZ29350B5Z       On        OK
gamisechost-01-03ilo.AD.AIB.PRI  CZ29350B61       On        Critical
OMG-CONSTC2-02ilo                CZ2D3701LY       On        OK
ALP-CONSTC1-01ilo                CZ2D3701LT       On        Warning
ALP-CONSTC2-01ilo                CZ2D3701LV       On        Warning
OMG-CONSTC1-02ilo                CZ2D3701LZ       On        Critical
alp-qlikview-03ilo               CZ22420JCM       On        OK
alp-qliksen-02ilo                CZ22420JCZ       On        OK
omg-qlikview-03ilo               CZ22420JCN       On        OK
omg-qliksen-02ilo                CZ22420JD0       On        OK

==============================================
 

Name                           Value
----                           -----
Success                        True
Count                          16
Servers                        {OMG-STARWAY-01ILO.AD.AIB.PRI, ALP-WISCLU-01ilo, OMG-WISCLU-01ilo, AL… 
Error

   image-build-automation  Get-OneViewConnectionStatus                                 0  10:26:17 
Name                           Value 
----                           -----
ModuleSource                   LoadedSession
Server
VersionWarning
Authenticated                  True
ApplianceVersion               8200
ModuleVersion                  10.0.4265.2221
Version                        8200
ServerCount
Error
Success                        True
SessionSource                  HPEOneViewModule
Reachable                      True
Appliance                      va-oneviewt-01
Connected                      True
ModuleName                     HPEOneView.1000
VersionCompliant               True

   image-build-automation  Test-ServerConnectivity                                     0  10:26:23 2026-08-11 09:26:29 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79
2026-08-11 09:26:29 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 14ms) 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-11T09:26:33.1044581Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 14ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000 (module used for all OneView calls on this server)
    Connected: Yes (session active)

==============================================
 
2026-08-11 09:26:33 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)

Name                           Value 
----                           -----
Mode                           oneview
Available                      True
NetworkPing                    {[TcpPortOpen, True], [IpAddress, 10.239.124.79], [Error, ], [Latency… 
Timestamp                      2026-08-11T09:26:33.1044581Z
AuthConnect                    {[Connected, True], [ModuleVersion, ], [ModuleLoaded, True], [Error, … 
ManagementHost                 va-oneviewt-01
Environment                    Prod

   image-build-automation  Test-ServerConnectivity -ManagementHost va-oneviewt-01s 954ms  10:26:33 
============================================== 
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-11T09:26:40.9548530Z

  --- Phase 1: Network Ping ---
    DNS:       FAILED
    TCP:       FAILED
    Error:     No credentials available to authenticate against 'va-oneviewt-01'.

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no credentials. Connect with Connect-OneView -ManagementHost <host> or supply -Credential / set ONEVIEW_USER + ONEVIEW_PASSWORD.

==============================================

Name                           Value
----                           -----
Mode                           oneview 
Available                      False
NetworkPing                    {[Error, No credentials available to authenticate against 'va-oneview… 
Timestamp                      2026-08-11T09:26:40.9548530Z
AuthConnect                    {[Connected, False], [Error, Skipped - no credentials. Connect with C… 
ManagementHost                 va-oneviewt-01
Environment                    Prod

   image-build-automation  Test-ServerConnectivity                               s 612ms  10:26:41 2026-08-11 09:49:17 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79
2026-08-11 09:49:17 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 7ms) 

============================================== 
  OneView Connectivity Test
==============================================

  Status:     AVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-08-11T09:49:18.0922940Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved 
    IP:        10.239.124.79
    TCP:       Open (port 443, 7ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000 (module used for all OneView calls on this server)
    Connected: Yes (session active) 

==============================================

2026-08-11 09:49:18 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=True (DNS=True, TCP=True, Auth=True)

Name                           Value
----                           -----
Mode                           oneview
Available                      True
NetworkPing                    {[TcpPortOpen, True], [IpAddress, 10.239.124.79], [Error, ], [Latency… 
Timestamp                      2026-08-11T09:49:18.0922940Z
AuthConnect                    {[Connected, True], [ModuleVersion, ], [ModuleLoaded, True], [Error, … 
ManagementHost                 va-oneviewt-01
Environment                    Prod

   image-build-automation  Test-ServerList                                      0  850ms  10:49:18 
Name                           Value
----                           -----
Servers                        {server1.example.com, server2.example.com, server3.example.com, proli… 
Success                        True

   image-build-automation  Test-BuildParams -BaseIsoPath 'C:\isos\WinSrv2025.iso'      0  10:49:33 Base ISO not found: C:\isos\WinSrv2025.iso 
   image-build-automation  Test-BuildParams -BaseIsoPath 'Y:\WIN2019Auto.iso'          0  10:49:46    image-build-automation  Test-BuildParams -BaseIsoPath smb://vm-ewismgt-19/Kev/      0  10:50:07 Base ISO not found: smb://vm-ewismgt-19/Kev/ 
   image-build-automation  Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/'    0  10:58:05 
Base ISO not found: smb://vm-ewismgt-19/Kev/ 
   image-build-automation  Test-BuildParams -BaseIsoPath 'smb://vm-ewismgt-19/Kev/WinSrv2025.iso'8 
Base ISO not found: smb://vm-ewismgt-19/Kev/WinSrv2025.iso 
   image-build-automation  Test-BuildParams -BaseIsoPath '//vm-ewismgt-19/Kev/WinSrv2025.iso'    1 
Base ISO not found: //vm-ewismgt-19/Kev/WinSrv2025.iso 
   image-build-automation                                                              
