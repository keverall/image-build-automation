# Authentication & Configuration Index

Configuration and secrets for `Set-MaintenanceMode.ps1`. All secrets stored in CyberArk vault `pas.aib.pri`. See [DevOps Guide to HPE Terms](devops-guide-to-HPe-Terms.md) for the distinction between SCOM, OneView, and iLO.

## Quick Reference

| System | Mode | Secrets Safe | Target Type |
|--------|------|--------------|-------------|
| SCOM | `scom` | `SCOM-2015` | Cluster groups (all nested objects) |
| OneView | `oneview` | `HPE-OneView` | Individual servers (no nesting) |

**Note:** The codebase defines `OpenView` safe (legacy) and `HPE-OneView` safe (current). Use `HPE-OneView` for new implementations.

## Documentation

- [SCOM Configuration](scom-auth.md) - Cluster-level maintenance mode
- [OneView Configuration](oneview-auth.md) - Hardware-level maintenance mode (via iLO)

## Working Config Files

- `configs/scom_config.working.json` - SCOM working configuration template
- `configs/oneview_config.working.json` - OneView working configuration template

## GitLab CI Integration

Set these **Masked** variables in GitLab CI/CD Settings → Variables:

| Variable | Description |
|----------|-------------|
| `CYBERARK_CCP_URL` | `https://cyberark-ccp:443/AIMWebService/API/Accounts` |
| `CYBERARK_APP_ID` | `ci` |

The `cyberark-bootstrap` job fetches secrets and makes them available to downstream jobs.

## Usage

```powershell
# SCOM - cluster maintenance (all servers/resources under group)
Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom

# OneView - individual server maintenance
Set-MaintenanceMode -Action enable -TargetId 'PROD-SERVER-01' -Mode oneview
```