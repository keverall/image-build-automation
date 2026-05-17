"""PowerShell execution helpers for Windows automation."""

import logging
import subprocess

logger = logging.getLogger(__name__)


def run_powershell(
    script: str, capture_output: bool = True, timeout: int = 300, execution_policy: str = "Bypass"
) -> tuple[bool, str]:
    """Execute a PowerShell script locally."""
    cmd = ["powershell", "-ExecutionPolicy", execution_policy, "-NoProfile", "-NonInteractive", "-Command", script]

    try:
        result = subprocess.run(cmd, capture_output=capture_output, text=True, timeout=timeout)
        output = result.stdout + result.stderr
        if result.returncode != 0:
            logger.error(f"PowerShell error: {output}")
            return False, output
        return True, output
    except subprocess.TimeoutExpired:
        return False, f"PowerShell script timed out after {timeout}s"
    except Exception as e:
        return False, str(e)


def run_powershell_winrm(
    script: str, server: str, username: str, password: str, transport: str = "ntlm", timeout: int = 300
) -> tuple[bool, str]:
    """Execute PowerShell script on remote server via WinRM."""
    try:
        import winrm
    except ImportError:
        return False, "pywinrm module not installed"

    try:
        session = winrm.Session(server, auth=(username, password), transport=transport)
        result = session.run_ps(script)
        output = (result.std_out.decode() + result.std_err.decode()).strip()
        if result.status_code == 0:
            return True, output
        else:
            logger.error(f"WinRM command failed with status {result.status_code}: {output}")
            return False, output
    except Exception as e:
        logger.error(f"WinRM connection/execution failed: {e}")
        return False, str(e)


def build_scom_connection(management_server: str) -> str:
    """Build PowerShell script to create SCOM management group connection."""
    return f"""
Import-Module OperationsManager -ErrorAction Stop
$conn = New-SCOMManagementGroupConnection -ComputerName "{management_server}" -ErrorAction Stop
"""


def build_scom_maintenance_script(
    group_display_name: str,
    duration_seconds: int,
    comment: str,
    operation: str = "start",  # "start" or "stop"
) -> str | None:
    """Build PowerShell script for SCOM maintenance mode operations."""
    safe_comment = comment.replace("'", "''")

    if operation.lower() == "start":
        return f"""
Import-Module OperationsManager -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "{group_display_name}" -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
$duration = New-TimeSpan -Seconds {duration_seconds}
$comment = '{safe_comment}'
$failed = @()
foreach ($inst in $instances) {{
    if ($inst.InMaintenanceMode) {{
        Write-Host "$($inst.Name) already in maintenance - skipping"
    }} else {{
        try {{
            Start-SCOMMaintenanceMode -Instance $inst -Duration $duration -Comment $comment -ErrorAction Stop
            Write-Host "Maintenance started: $($inst.Name)"
        }} catch {{
            Write-Error "Failed for $($inst.Name): $_"
            $failed += $inst.Name
        }}
    }}
}}
if ($failed.Count -gt 0) {{
    Write-Error "Failed for: $($failed -join ', ')"
    exit 1
}} else {{
    Write-Host "All instances entered maintenance successfully"
}}
"""
    elif operation.lower() == "stop":
        return f"""
Import-Module OperationsManager -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "{group_display_name}" -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
$stopped = @()
foreach ($inst in $instances) {{
    if ($inst.InMaintenanceMode) {{
        try {{
            Stop-SCOMMaintenanceMode -Instance $inst -ErrorAction Stop
            Write-Host "Maintenance stopped: $($inst.Name)"
            $stopped += $inst.Name
        }} catch {{
            Write-Error "Failed to stop for $($inst.Name): $_"
        }}
    }} else {{
        Write-Host "$($inst.Name) not in maintenance - skipping"
    }}
}}
if ($stopped.Count -gt 0) {{
    Write-Host "Stopped maintenance for $($stopped.Count) instances"
}} else {{
    Write-Host "No instances were in maintenance"
}}
"""

    return None
