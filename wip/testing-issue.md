The latest run finally isolates this outside the automation code.

### What the log proves

The client is running the fallback commit:

```text
7962371a
```

Both authentication paths fail against the same iLO:

```text
SSO:
GET https://10.30.14.15/redfish/v1/Systems/1
401 Unauthorized

Direct OneView credential:
POST https://10.30.14.15/redfish/v1/SessionService/Sessions
401 Unauthorized
```

The OneView side is healthy:

```text
Connected: Yes
Server resolution: successful
Maintenance mode: detected
OneView maintenance step: successful/skipped
```

The code now mirrors HPE’s documented SSO flow:

```powershell
Get-OVIloSso -IloRestSession -SkipCertificateCheck
X-Auth-Token: <token>
GET /redfish/v1/Systems/1
```

The direct login also fails, so changing the token header again will not resolve this.

## Actual fault

The iLO is rejecting both:

1. The OneView-issued SSO token.
2. The OneView account as a direct iLO Redfish login.

This indicates an iLO/OneView SSO configuration or authorization problem, such as:

- HPE SSO disabled or misconfigured in iLO.
- OneView appliance certificate/trust relationship rejected by iLO.
- The `adm_98253` OneView role has no mapped iLO privilege.
- iLO SSO role mapping is missing or invalid.
- iLO firmware/OneView SSO compatibility issue.
- Existing iLO authentication/session policy rejecting both token and account.

The HPE UI can still work because it uses the browser SSO URL flow; that does not prove the Redfish SSO token endpoint is authorized.

## Direct proof command

Run this on the Windows client using the same connected session:

```powershell
$server = Get-OVServer -Name 'alp-qlikview-03ilo'
$sso = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck

$headers = @{
    'X-Auth-Token' = $sso.'X-Auth-Token'
}

Invoke-RestMethod `
    -Uri "$($sso.RootUri)/redfish/v1/Systems/1" `
    -Headers $headers `
    -SkipCertificateCheck `
    -ErrorAction Stop
```

If this returns 401, it independently proves the failure is between OneView SSO and iLO, outside `Configure-PhysicalBuild`.

The iLO administrator needs to check the iLO HPE SSO configuration and role mapping for the `adm_98253` OneView role. The automation now records both SSO and direct-auth failures and is correctly failing closed instead of bypassing iLO authentication.