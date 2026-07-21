# HPE OpenView 1000 Useful Commands

## Table of Contents

- [Version and Information](#version-and-information)
- [Service and Process Management](#service-and-process-management)
- [Node and Network Management](#node-and-network-management)
- [Event and Message Management](#event-and-message-management)
- [Troubleshooting](#troubleshooting)
- [Configuration](#configuration)
- [Windows-Specific Commands](#windows-specific-commands)
- [Common File Paths (Windows)](#common-file-paths-windows)
- [Quick Health Check Script](#quick-health-check-script)
- [Notes](#notes)
- [Discover Available Commands](#discover-available-commands)


<a name="version-and-information"></a>
## Version and Information

```powershell
# Check OpenView version (CONFIRMED WORKING)
ovversion
```

<a name="service-and-process-management"></a>
## Service and Process Management

```powershell
# Note: Commands vary by HPE OpenView version
# Check what commands are available in your installation:
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name

# Check OpenView Windows services
Get-Service | Where-Object { $_.DisplayName -like "*OpenView*" -or $_.Name -like "*HP*" }
```

<a name="node-and-network-management"></a>
## Node and Network Management

```powershell
# Note: These commands may not be available in all versions
# Check your installation's bin directory for available executables
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name
```

<a name="event-and-message-management"></a>
## Event and Message Management

```powershell
# Note: Commands vary by HPE OpenView version
# Check available executables in your installation
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name
```

<a name="troubleshooting"></a>
## Troubleshooting

```powershell
# Find all available OpenView commands
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name

# Check OpenView logs
Get-Content "C:\Program Files\HP\HP OpenView\log\*.log" -Tail 50

# Test network connectivity to managed nodes
Test-NetConnection <node_name> -Port 161
```

<a name="configuration"></a>
## Configuration

```powershell
# Note: Commands vary by HPE OpenView version
# Check available executables in your installation
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name
```

<a name="windows-specific-commands"></a>
## Windows-Specific Commands

```powershell
# Check OpenView Windows services
Get-Service | Where-Object { $_.DisplayName -like "*OpenView*" }

# Check OpenView processes
Get-Process | Where-Object { $_.ProcessName -like "*ov*" -or $_.ProcessName -like "*openview*" }

# Find OpenView installation path
Get-ChildItem -Path "C:\Program Files" -Directory -Filter "*OpenView*" -ErrorAction SilentlyContinue

# Check OpenView registry entries
Get-ItemProperty "HKLM:\SOFTWARE\HP\HP OpenView\*" -ErrorAction SilentlyContinue
```

<a name="common-file-paths-windows"></a>
## Common File Paths (Windows)

```
Installation: C:\Program Files\HP\HP OpenView\
Binaries:     C:\Program Files\HP\HP OpenView\bin\
Logs:         C:\Program Files\HP\HP OpenView\log\
Config:       C:\Program Files\HP\HP OpenView\conf\
Data:         C:\Program Files\HP\HP OpenView\data\
```

<a name="quick-health-check-script"></a>
## Quick Health Check Script

```powershell
# Quick OpenView health check
Write-Host "=== HPE OpenView Health Check ===" -ForegroundColor Cyan
Write-Host "`nVersion:" -ForegroundColor Yellow
ovversion
Write-Host "`nWindows Services:" -ForegroundColor Yellow
Get-Service | Where-Object { $_.DisplayName -like "*OpenView*" } | Format-Table Name, Status, DisplayName
Write-Host "`nAvailable OpenView Commands:" -ForegroundColor Yellow
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object Name
```

<a name="notes"></a>
## Notes

- This document is for **HPE OpenView 1000**
- Run PowerShell as Administrator for full access
- Commands vary by version — use the discovery commands below to find what's available
- Check `%PATH%` environment variable if commands are not recognized

<a name="discover-available-commands"></a>
## Discover Available Commands

```powershell
# List all executables in the OpenView bin directory
Get-ChildItem "C:\Program Files\HP\HP OpenView\bin" -Filter "*.exe" | Select-Object Name

# Search for any OpenView-related commands on the system
Get-Command *openview* -ErrorAction SilentlyContinue
Get-Command *ov* -ErrorAction SilentlyContinue

# Check PATH for OpenView directories
$env:PATH -split ";" | Where-Object { $_ -like "*OpenView*" -or $_ -like "*HP*" }
```
