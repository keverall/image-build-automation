# Offline HPE OneView iLO SSO Deployment Runbook

## Purpose

Use this procedure on the regulated client test server where the host has no Internet access.

The workflow uses the bundled offline HPE OneView module and OneView-issued iLO SSO. It does **not** use the OneView username/password as a local iLO account and does **not** place an iLO password on the command line.

## Important command names

The bundled HPE OneView 10.00 module exports these cmdlets:

```powershell
Get-OVServer
Get-OVIloSso
```

It does **not** export these names:

```text
Get-HPOVServer
Get-HPOVIloSso
```

The repository copy is located at:

```text
scripts/modules/HPEOneView.1000/10.0.4265.2221/
```

## 1. Open PowerShell on the client test server

Use Windows PowerShell 5.1 or PowerShell 7 running on the Windows automation host. Run from the repository root:

```powershell
Set-Location 'C:\path\to\image-build-automation'
```

Replace the path with the actual repository path on the client server.

## 2. Prepare the offline module automatically

Run the repository setup target once on the client server:

```powershell
make setup
```

`make setup` automatically:

- Uses the bundled modules under `scripts/modules/`
- Adds `scripts/modules` to the current `PSModulePath`
- Persists `scripts/modules` to the Windows user `PSModulePath`
- Imports `HPEOneView.1000`
- Verifies `Get-OVServer` and `Get-OVIloSso`
- Configures the PowerShell profile for future sessions

No manual module import is required for later PowerShell sessions. The setup remains offline-first and does not require PowerShell Gallery access when the repository bundle is present.

If `make` is unavailable, the equivalent setup command is:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-runner.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-Profile.ps1
```

## 3. Confirm the bundled HPE OneView module is discoverable

Run:

```powershell
Get-Module -ListAvailable HPEOneView.1000 |
    Select-Object Name, Version, ModuleBase
```

Expected module base path should end with:

```text
scripts\modules\HPEOneView.1000\10.0.4265.2221
```

If no module is returned, stop and correct the repository/module path before attempting a build.

## 4. Import the automation module

```powershell
Import-Module .\src\powershell\Automation\Automation.psd1 -Force -DisableNameChecking
```

Confirm the HPE OneView SSO cmdlets are available:

```powershell
Get-Command Get-OVServer, Get-OVIloSso |
    Select-Object Name, CommandType, Source, Version
```

Expected output:

```text
Get-OVServer
Get-OVIloSso
Source: HPEOneView.1000
```

If either command is missing, do not continue. The iLO SSO step cannot work until the correct HPE module is loaded.

## 5. Connect to HPE OneView

Create the OneView credential in the current PowerShell session:

```powershell
$oneViewCredential = Get-Credential -Message 'HPE OneView credentials'
```

Connect to the appliance:

```powershell
Connect-OneView `
    -ManagementHost 'va-oneviewt-01' `
    -Credential $oneViewCredential
```

Confirm the connection:

```powershell
Get-OneViewConnectionStatus -OneViewHost 'va-oneviewt-01' -PassThru
```

Confirm that OneView can resolve the target server:

```powershell
Get-OVServer -Name 'omg-qlikview-03ilo' |
    Select-Object Name, SerialNumber, State, PowerState, Status
```

If the server is normally targeted by serial number, use the identifier accepted by the environment:

```powershell
Get-OVServer |
    Where-Object { $_.serialNumber -eq 'CZ22420JCN' } |
    Select-Object Name, SerialNumber, State, PowerState, Status
```

## 6. Confirm the OneView iLO SSO command path

Run this read-only verification:

```powershell
$server = Get-OVServer -Name 'omg-qlikview-03ilo' -ErrorAction Stop
$iloSso = $server | Get-OVIloSso -IloRestSession -ErrorAction Stop

$iloSso | Select-Object *
```

The result must contain a OneView-issued iLO SSO connection object, including a root address and token/session value. Do not print or save the token in logs or tickets.

If this command fails, capture only the error message and command/module versions. Do not disclose the token.

## 7. Run Configure-PhysicalBuild

Do **not** pass `-IloUser` or `-IloPassword`. Those parameters are intentionally not part of the safe OneView-managed workflow.

Run:

```powershell
Configure-PhysicalBuild `
    -ServerIdentifier 'CZ22420JCN' `
    -OneViewHost 'va-oneviewt-01' `
    -ExternalIsoPath 'Y:\WIN2019Auto.iso' `
    -GuardRail 'qlikview-03ilo'
```

Expected flow:

1. OneView resolves `CZ22420JCN`.
2. The mapped ISO path is converted to a CIFS/SMB URL.
3. The review validation runs without opening an iLO login.
4. The deployment plan is displayed.
5. The command waits for the destructive approval input.
6. Type exactly:

```text
APPROVE
```

7. After approval, the build obtains the OneView iLO SSO session using `Get-OVServer` and `Get-OVIloSso`.
8. The build performs iLO status, virtual-media, one-time-boot, reset, and eject operations using the SSO token.

## 8. Do not use these unsafe forms

Do not run:

```powershell
-IloUser 'user' -IloPassword 'password'
```

Do not place passwords in:

- PowerShell command history
- Test logs
- Source files
- Environment variables unless approved by the client security process
- Ticket comments
- Screenshots

For a OneView-managed server, the preferred authentication is the OneView SSO flow. A direct iLO `PSCredential` should only be used for an unmanaged server or if the client explicitly approves that fallback.

## 9. Troubleshooting

### `Get-OVServer` or `Get-OVIloSso` is not recognized

Run:

```powershell
Get-Module -ListAvailable HPEOneView.1000
Get-Command Get-OVServer, Get-OVIloSso -ErrorAction SilentlyContinue
```

If missing, verify the repository contains:

```text
scripts/modules/HPEOneView.1000/10.0.4265.2221/HPEOneView.1000.psd1
scripts/modules/HPEOneView.1000/10.0.4265.2221/HPEOneView.1000.psm1
```

Then reload the modules:

```powershell
Remove-Module Automation -Force -ErrorAction SilentlyContinue
Remove-Module HPEOneView.1000 -Force -ErrorAction SilentlyContinue
Import-Module .\src\powershell\Automation\Automation.psd1 -Force -DisableNameChecking
Import-Module HPEOneView.1000 -Force
Get-Command Get-OVServer, Get-OVIloSso
```

### `OneView iLO SSO is unavailable`

Check:

```powershell
Get-Command Get-OVServer, Get-OVIloSso -ErrorAction SilentlyContinue
Get-Module HPEOneView.1000
```

The module must be loaded in the same PowerShell process running `Configure-PhysicalBuild`.

### `401 Unauthorized`

A 401 from direct iLO Redfish login means the supplied username is not a valid local iLO account. Do not retry by passing the OneView username/password as an iLO password.

Instead verify the SSO path:

```powershell
$server = Get-OVServer -Name 'omg-qlikview-03ilo' -ErrorAction Stop
$server | Get-OVIloSso -IloRestSession -ErrorAction Stop
```

If that fails, engage the OneView administrator. The OneView-managed iLO account is appliance-managed and should not be manually replaced.

### No Internet access

No Internet connection is required for the bundled module. Do not run `Install-Module` or `Save-Module` on the regulated client. Confirm that the repository bundle is present and that the local module path points to `scripts/modules`.

## 10. Evidence to capture without exposing secrets

Record:

```powershell
$PSVersionTable.PSVersion
Get-Module HPEOneView.1000 | Select-Object Name, Version, ModuleBase
Get-Command Get-OVServer, Get-OVIloSso | Select-Object Name, Source, Version
```

Do not record:

- OneView passwords
- iLO passwords
- SSO tokens
- Session cookies
- Full request headers
