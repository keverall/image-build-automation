# Authentication & Configuration Index

Configuration and secrets for `Set-MaintenanceMode.ps1`. All secrets stored in CyberArk vault `pas.example.com`.

## Quick Reference

| System | Mode | Secrets Safe | Target Type |
|--------|------|--------------|-------------|
| SCOM | `scom` | `SCOM-2015` | Cluster groups (all nested objects) |
| OneView | `oneview` | `HPE-OneView` | Individual servers (no nesting) |

## Documentation

- [SCOM Configuration](scom-auth.md) - Cluster-level maintenance mode
- [OneView Configuration](oneview-auth.md) - Hardware-level maintenance mode

## Working Config Files

- `configs/scom_config.working.json` - SCOM working configuration template
- `configs/oneview_config.working.json` - OneView working configuration template

## Usage

```powershell
# SCOM - cluster maintenance (all servers/resources under group)
Set-MaintenanceMode -Action enable -TargetId 'PROD-CLUSTER-01' -Mode scom

# OneView - individual server maintenance
Set-MaintenanceMode -Action enable -TargetId 'PROD-SERVER-01' -Mode oneview
```