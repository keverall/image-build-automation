# Docker EntryPoint Script for HPE Windows ISO Automation
# Configures environment for PowerShell automation

param(
    [Parameter(Mandatory=$false)]
    [string]$Command = "help"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Log function for audit trail
function Write-AuditLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-LogTimestamp
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Output $logEntry
    if (Test-Path "C:\app\logs") {
        $ts = Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ'
        Add-Content -Path "C:\app\logs\audit_trail_${ts}_INFO.log" -Value $logEntry
    }
}

Write-AuditLog "Container startup initiated"

# Validate environment
if (-not (Test-Path "C:\app\src\powershell\Automation")) {
    Write-AuditLog "ERROR: PowerShell module not found - container may not be properly built" "ERROR"
    exit 1
}

# Import the automation module
try {
    Import-Module "C:\app\src\powershell\Automation\Automation.psd1" -Force
    Write-AuditLog "PowerShell module imported successfully"
} catch {
    Write-AuditLog "WARNING: Failed to import module - $($_.Exception.Message)" "WARNING"
}

# Main execution
if ($args) {
    Write-AuditLog "Executing command: $args"
    & $args
    $exitCode = $LASTEXITCODE
    Write-AuditLog "Command completed with exit code: $exitCode"
    exit $exitCode
} else {
    Write-AuditLog "No command provided - starting interactive PowerShell session"
    pwsh -NoExit -NoLogo
}

Write-AuditLog "Container entrypoint script completed"