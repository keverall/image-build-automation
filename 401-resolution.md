# 401-Resolution

<a id="top"></a>

## Table of Contents

- [Overview](#overview)

The code is now substantially more likely to work for the specific failure you described, especially because the revised Configure-PhysicalBuild flow now:

<a id="overview"></a>

## Overview

- Resolves the iLO 5 address from OneView. 
- Prompts for the actual iLO username and password.
- Uses those direct iLO credentials instead of allowing OneView SSO to shadow them.
- Creates the Redfish session using the iLO 5 session endpoint.
- Reads the token from the correct X-Auth-Token response header.
- Uses that token for subsequent Redfish requests.
- Avoids replaying destructive requests after authentication failures.
- If the credentials successfully log in to the iLO web UI at the same resolved iLO address, the direct authentication path - should now match the working UI credentials and avoid the previous 401 causes.

The honest qualification is that no code-only change can prove success against the physical iLO until one live, read-only request succeeds. Before doing any deployment tomorrow, run a direct status test against the same iLO IP:
```pwsh

$credential = Get-Credential -Message 'Enter the iLO 5 account credentials'

Invoke-IloRedfish `
    -Action Status `
    -IloIp '10.0.1.50' `
    -IloCredential $credential

# Do not use MountAndBoot or `Reset for this test.

# The expected result is:

Success : True
```

If that succeeds, the 401/session-token problem is resolved for the direct iLO path and the build command should be ready:

```pwsh
Configure-PhysicalBuild `
    -ServerIdentifier 'srv01' `
    -OneViewHost 'oneview.corp.local' `
    -ExternalIsoPath 'https://artifacts.corp.local/isos/WinSrv2025.iso' `
    -InMaintenanceWindow `
    -GuardRail '^srv01$'
```

The command will resolve the iLO address and prompt for credentials. 
No -IloIp or stored credential variable is needed for the normal Configure workflow.

You have a credible fix now, backed by the bundled HPE session behavior and 693 passing tests. The only remaining uncertainty is the live iLO account/policy response, which cannot be simulated by the test suite. 

Type a message, @ to mention files... (
Ctrl
Shift
A
 to type)
