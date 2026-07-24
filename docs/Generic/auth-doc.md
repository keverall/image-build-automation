# Authentication & Configuration Index

<a id="top"></a>
## Table of Contents

- [Quick Reference](#quick-reference)
- [Documentation](#documentation)
- [Working Config Files](#working-config-files)
- [GitLab CI Integration](#gitlab-ci-integration)
- [Usage](#usage)
Configuration and secrets for `Set-MaintenanceMode.ps1`. All secrets stored in CyberArk vault `pas.example.com`. See [DevOps Guide to HPE Terms](../devops-guide-to-HPe-Terms.md#top) for the distinction between SCOM, OneView, and iLO.

<a name="quick-reference"></a>
## Quick Reference

| System | Mode | Secrets Safe | Target Type |
|--------|------|--------------|-------------|
| SCOM | `scom` | `SCOM-2015` | Cluster groups (all nested objects) |
| OneView | `oneview` | `HPE-OneView` | Individual servers (no nesting) |

**Note:** The codebase defines `OpenView` safe (legacy) and `HPE-OneView` safe (current). Use `HPE-OneView` for new implementations.

<a name="documentation"></a>
## Documentation

- [SCOM Configuration](scom-auth.md#top) - Cluster-level maintenance mode
- [OneView Configuration](oneview-auth.md#top) - Hardware-level maintenance mode (via iLO)

<a name="working-config-files"></a>
## Working Config Files

- `configs/scom_config.working.json` - SCOM working configuration template
- `configs/oneview_config.working.json` - OneView working configuration template

<a name="gitlab-ci-integration"></a>
## GitLab CI Integration

Set these **Masked** variables in GitLab CI/CD Settings → Variables:

| Variable | Description |
|----------|-------------|
| `CYBERARK_CCP_URL` | `https://cyberark-ccp:443/AIMWebService/API/Accounts` |
| `CYBERARK_APP_ID` | `ci` |

The `cyberark-bootstrap` job fetches secrets and makes them available to downstream jobs.

<a name="usage"></a>
## Usage

```powershell
# SCOM - cluster maintenance (all servers/resources under group)
Set-MaintenanceMode -Action enable -TargetId 'CLU-CLUSTER-01' -Mode scom

# OneView - individual server maintenance
Set-MaintenanceMode -Action enable -TargetId 'PROD-SERVER-01' -Mode oneview
```


