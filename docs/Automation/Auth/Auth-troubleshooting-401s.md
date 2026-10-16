# Troubleshooting HPE iLO 5 HTTP 401 Authentication Failures

<a id="top"></a>

## Table of Contents

- [Quick decision guide](#quick-decision-guide)
- [Direct iLO REST authentication](#direct-ilo-rest-authentication)
  - [Safe direct-authentication test](#safe-direct-authentication-test)
- [OneView-managed iLO SSO](#oneview-managed-ilo-sso)
  - [Important HPE module behavior](#important-hpe-module-behavior)
  - [Safe SSO object inspection](#safe-sso-object-inspection)
- [Configure-PhysicalBuild authentication](#configure-physicalbuild-authentication)
- [401 troubleshooting matrix](#401-troubleshooting-matrix)
  - [Direct iLO login returns 401](#direct-ilo-login-returns-401)
  - [OneView SSO object exists but the first iLO request returns 401](#oneview-sso-object-exists-but-the-first-ilo-request-returns-401)
- [Module and version checks](#module-and-version-checks)
- [Evidence to capture without exposing secrets](#evidence-to-capture-without-exposing-secrets)
- [Authoritative bundled references](#authoritative-bundled-references)

This guide separates the two supported authentication paths used by the automation:

1. **Direct iLO REST authentication** with an iLO username and password.
2. **OneView-issued iLO SSO** for a server managed by HPE OneView.

These are different authentication domains. A credential that logs in to the
OneView appliance is not automatically an iLO local account.

<a id="quick-decision-guide"></a>

## Quick decision guide

| Situation | Use | Primary reference |
|---|---|---|
| Engineer has an iLO account and password | Direct iLO REST session | `Connect-HPREST` / `HPRESTExamples.ps1` |
| Server is managed by OneView and SSO is enabled | OneView iLO SSO session | `Get-OVIloSso -IloRestSession` |
| OneView appliance uses CAC/PIV or client certificates | OneView appliance certificate authentication | `about_Two_Factor_Authentication.help.txt` |

`about_Two_Factor_Authentication.help.txt` is **not** an iLO 5 Redfish
authentication guide. It documents authentication to the OneView appliance.

<a id="direct-ilo-rest-authentication"></a>

## Direct iLO REST authentication

The canonical implementation is:

```text
scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTCmdlets.psm1
```

The bundled examples are:

```text
scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTExamples.ps1
```

`Connect-HPREST` performs this sequence:

```text
POST https://<ilo-address>/rest/v1/sessions
        |
        +-- JSON UserName and Password
        |
        +-- X-Auth-Token response header
        +-- Location response header
```

Subsequent requests send:

```text
X-Auth-Token: <token>
```

The token is intentionally managed inside the HPREST session object; the
examples therefore use `-Session` rather than manually constructing headers.

<a id="safe-direct-authentication-test"></a>

### Safe direct-authentication test

This checks login and a read-only iLO request. It does not mount media or reboot
the server:

```powershell
Import-Module .\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1

$iloCredential = Get-Credential -Message 'Enter the iLO 5 account credentials'
$session = $null
try {
    $session = Connect-HPREST `
        -Address '10.0.1.50' `
        -Credential $iloCredential

    $system = Get-HPRESTDataRaw `
        -Href 'rest/v1/Systems' `
        -Session $session

    $system
}
finally {
    if ($session) {
        Disconnect-HPREST -Session $session
    }
}
```

If this returns 401, investigate the iLO account, password, account state,
permissions, iLO network path, and certificate/TLS handling before investigating
OneView SSO.

The examples most relevant to this project are:

- Example 2: server reset
- Example 6: one-time boot
- Example 15: virtual media mount/unmount
- Example 17: iLO reset

Do not run the destructive examples as an authentication test.

<a id="oneview-managed-ilo-sso"></a>

## OneView-managed iLO SSO

The canonical OneView command is:

```powershell
$server = Get-OVServer -Name 'srv01' -ErrorAction Stop
$iloSso = $server | Get-OVIloSso -IloRestSession -ErrorAction Stop
```

The generated HPREST-compatible object contains:

```text
RootUri
X-Auth-Token
Location (normally null in the HPE-generated SSO object)
```

The HPE OneView module implementation derives the iLO address and token from
the OneView-generated SSO URL. It does not use the iLO username/password in this
path.

<a id="important-hpe-module-behavior"></a>

### Important HPE module behavior

The bundled HPE OneView release notes state that `Get-OVIloSso` no longer
connects to iLO to generate or validate the SSO token. Therefore, this command
can succeed while the first actual iLO request returns 401.

A valid object is not proof that the token is accepted by iLO.

<a id="safe-sso-object-inspection"></a>

### Safe SSO object inspection

Never print the token itself:

```powershell
$server = Get-OVServer -Name 'srv01' -ErrorAction Stop
$iloSso = $server | Get-OVIloSso -IloRestSession -ErrorAction Stop

$iloSso | Select-Object RootUri, @{
    Name = 'HasAuthToken'
    Expression = {
        -not [string]::IsNullOrWhiteSpace([string]$_.'X-Auth-Token')
    }
}
```

The result should show a valid `RootUri` and `HasAuthToken: True`. This only
confirms object construction; it does not validate the token.

<a id="configure-physicalbuild-authentication"></a>

## Configure-PhysicalBuild authentication

For the normal managed-server workflow, provide the server name or serial and
OneView host. Do not provide `-IloIp` or store an iLO credential in a variable:

```powershell
Configure-PhysicalBuild `
    -ServerIdentifier 'srv01' `
    -OneViewHost 'oneview.corp.local' `
    -ExternalIsoPath 'https://artifacts.corp.local/isos/WinSrv2025.iso' `
    -GuardRail '^srv01$'
```

The command resolves the iLO address through OneView, then prompts for the iLO
username and secure password. The prompted direct credential is reused for the
approved iLO operations and takes precedence over OneView SSO.

`-Deploy` skips only the `APPROVE` authorization prompt. It does not suppress
the iLO credential prompt when `-IloCredential` is omitted.

Use `-SkipIlo` only when intentionally skipping the review-time iLO check and
prompt. It does not disable the approved deployment's iLO mount, boot, reset, or
eject operations.

<a id="401-troubleshooting-matrix"></a>

## 401 troubleshooting matrix

<a id="direct-ilo-login-returns-401"></a>

### Direct iLO login returns 401

Check:

1. The username is an iLO local/directory account, not merely a OneView account.
2. The password works in the iLO web UI at the same iLO address.
3. The account is enabled and has the required iLO privileges.
4. The request reaches the intended iLO address and not a proxy or load balancer.
5. The HPREST/Redfish session is created before sending `X-Auth-Token`.
6. The response token is read from the `X-Auth-Token` header, not a JSON `token` property.

<a id="oneview-sso-object-exists-but-the-first-ilo-request-returns-401"></a>

### OneView SSO object exists but the first iLO request returns 401

Check:

1. The correct `HPEOneView.1000` module is loaded.
2. `Get-OVIloSso -IloRestSession` is used, not an invalid switch such as `-IloSsoSession`.
3. The SSO object `RootUri` points to the target iLO.
4. The request sends the exact `X-Auth-Token` value from the object.
5. The OneView server hardware resource maps to the expected iLO address.
6. The OneView appliance and iLO firmware support the SSO relationship.
7. A fresh SSO object is generated immediately before the iLO operation.

Because HPE no longer validates the token inside `Get-OVIloSso`, the actual
status request is the first meaningful SSO test.

<a id="module-and-version-checks"></a>

## Module and version checks

Run these checks before changing authentication code:

```powershell
Get-Module -ListAvailable HPEOneView.1000, HPRESTCmdlets |
    Select-Object Name, Version, ModuleBase

Get-Command Connect-OVMgmt, Get-OVServer, Get-OVIloSso, Connect-HPREST |
    Select-Object Name, Source, Version
```

Expected bundled versions are:

- `HPEOneView.1000` 10.0.4265.2221 or compatible 10.00 release
- `HPRESTCmdlets` 1.2.0.0

The HPEOneView DLL is required by the OneView module and is declared by its
manifest. HPREST is a script module and does not require a separate DLL.

<a id="evidence-to-capture-without-exposing-secrets"></a>

## Evidence to capture without exposing secrets

Capture:

- PowerShell version
- module names, versions, and paths
- target server identifier
- resolved iLO address, if permitted
- `RootUri` only
- whether `X-Auth-Token` exists, as a Boolean
- HTTP status and sanitized error stage

Do not capture:

- iLO passwords
- OneView passwords
- `X-Auth-Token` values
- complete SSO URLs containing token query parameters
- full request or response bodies containing credentials

<a id="authoritative-bundled-references"></a>

## Authoritative bundled references

- `scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTCmdlets.psm1` — direct iLO session implementation and help
- `scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTExamples.ps1` — direct iLO operation examples
- `scripts/modules/HPEOneView.1000/10.0.4265.2221/HPEOneView.1000.psm1` — `Get-OVIloSso` implementation
- `scripts/modules/HPEOneView.1000/10.0.4265.2221/en-US/HPEOneView.1000.psm1-help.xml` — `Get-OVIloSso` help and examples
- `scripts/modules/HPEOneView.1000/10.0.4265.2221/en-US/about_Two_Factor_Authentication.help.txt` — OneView appliance certificate authentication only
- `docs/Automation/offline-oneview-ilo-sso-runbook.md` — project SSO verification runbook
- `docs/fixes-2026-10-03.md` — prior SSO object and token handling corrections
