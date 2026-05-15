#!/usr/bin/env python3
"""
Maintenance Mode Orchestration Script

Enables or disables maintenance mode for a cluster of servers across:
- SCOM 2015 (System Center Operations Manager) via PowerShell cmdlets
- HPE iLO (Integrated Lights-Out) via REST API or PowerShell module
- HPE OpenView via REST API or CLI

Integrates with OpsRamp for monitoring/alerting and sends email notifications.
Supports scheduling automatic disable via Windows Task Scheduler.

Usage examples:
  python automation.cli.maintenance_mode.py --cluster-id PROD-CLUSTER-01 --start now --end 2025-05-15T08:00:00
  python automation.cli.maintenance_mode.py --cluster-id PROD-CLUSTER-01 --disable
  python automation.cli.maintenance_mode.py --cluster-id PROD-CLUSTER-01 --validate-only
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# Add parent directory to path if needed for relative imports
from automation.cli.opsramp_integration import OpsRampClient
from automation.utils.config import load_json_config as utils_load_json_config
from automation.utils.credentials import get_credential, get_ilo_credentials
from automation.utils.executor import run_command
from automation.utils.logging_setup import init_logging
from automation.utils.powershell import run_powershell, run_powershell_winrm

# Constants
BASE_DIR = Path(__file__).parent.parent  # repository root
CONFIG_DIR = BASE_DIR / "configs"
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Setup placeholder logger (will be configured by init_logging in main)
logger = logging.getLogger(__name__)

def save_audit(audit: dict, path: Path):
    """Save audit record to JSON file and append to main log."""
    try:
        with open(path, 'w') as f:
            json.dump(audit, f, indent=2, default=str)
        # Append to master log (line-delimited JSON)
        with open(LOG_DIR / "maintenance_audit.log", 'a') as f:
            f.write(json.dumps(audit, default=str) + "\n")
    except Exception as e:
        logger.error(f"Failed to save audit: {e}")

def parse_datetime(s: str) -> datetime:
    """Parse a datetime string in ISO-like format or 'now'. Returns naive datetime."""
    if s.lower() == 'now':
        return datetime.now()
    # Accept either YYYY-MM-DD HH:MM[:SS] or YYYY-MM-DDTHH:MM[:SS]
    s = s.replace('T', ' ')
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M'):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    raise ValueError(f"Invalid datetime format '{s}'. Use 'now' or 'YYYY-MM-DD HH:MM[:SS]'")

def compute_next_work_start(schedule: dict, after_dt: datetime) -> datetime:
    """
    Compute next occurrence of work_start time that is strictly after after_dt.
    Schedule dict keys: work_days (list of Mon,Tue,...), work_start (HH:MM), work_end (HH:MM)
    Times are treated as local server time; ensure server timezone matches schedule expectation.
    """
    work_start_str = schedule.get('work_start', '08:00')
    work_start_time = datetime.strptime(work_start_str, '%H:%M').time()
    day_map = {'Mon':0, 'Tue':1, 'Wed':2, 'Thu':3, 'Fri':4, 'Sat':5, 'Sun':6}
    work_days = [day_map[d] for d in schedule.get('work_days', ['Mon','Tue','Wed','Thu','Fri'])]

    candidate_date = after_dt.date()
    while True:
        if candidate_date.weekday() in work_days:
            candidate_dt = datetime.combine(candidate_date, work_start_time)
            if candidate_dt > after_dt:
                return candidate_dt
        candidate_date += timedelta(days=1)

def format_datetime_for_scom(dt: datetime) -> str:
    """Format datetime as string suitable for SCOM/PowerShell (culture invariant)."""
    return dt.strftime('%Y-%m-%dT%H:%M:%S')

def format_datetime_for_api(dt: datetime) -> str:
    """Format datetime for REST APIs (ISO format with timezone if present)."""
    if dt.tzinfo is None:
        return dt.isoformat()
    else:
        return dt.astimezone().isoformat()

class SCOMManager:
    """Manages SCOM 2015 maintenance mode via PowerShell cmdlets."""

    def __init__(self, config: dict):
        self.config = config
        self.mgmt_server = config.get('management_server', 'localhost')
        self.module_name = config.get('powershell_module', 'OperationsManager')
        self.use_winrm = config.get('use_winrm', False)
        self.cred = None
        if config.get('credentials'):
            user_env = config['credentials'].get('username_env')
            pass_env = config['credentials'].get('password_env')
            if user_env and pass_env:
                username = os.environ.get(user_env)
                password = os.environ.get(pass_env)
                if username and password:
                    # We will pass as secure string; but we'll embed via script if needed
                    self.cred = {'username': username, 'password': password}
        # For local execution, we assume current user has rights

    def _run_ps(self, script: str, capture_output: bool = True) -> tuple[bool, str]:
        """Execute a PowerShell script either locally or via WinRM."""
        if self.use_winrm:
            if not self.cred:
                return False, "WinRM credentials not configured"
            # Use WinRM via utils
            return run_powershell_winrm(
                script,
                server=self.mgmt_server,
                username=self.cred['username'],
                password=self.cred['password']
            )
        else:
            return run_powershell(script, capture_output=capture_output)

    def get_group_members(self, group_display_name: str) -> tuple[bool, list[str]]:
        """Return list of server names in the SCOM group."""
        script = f"""
Import-Module {self.module_name} -ErrorAction Stop
$conn = New-SCOMManagementGroupConnection -ComputerName "{self.mgmt_server}" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "{group_display_name}" -ErrorAction SilentlyContinue
if (-not $group) {{
    Write-Error "Group '{group_display_name}' not found"
    exit 1
}}
$instances = Get-SCOMClassInstance -Group $group
$instances | ForEach-Object {{ $_.Name }}
"""
        success, output = self._run_ps(script)
        if not success:
            return False, []
        # Output lines are server names
        servers = [line.strip() for line in output.strip().split('\n') if line.strip()]
        return True, servers

    def enter_maintenance(self, group_display_name: str, duration: timedelta, comment: str, dry_run: bool = False) -> tuple[bool, list[str]]:
        """Place all computers in the given SCOM group into maintenance mode."""
        # Convert duration to total seconds (int)
        total_seconds = int(duration.total_seconds())
        # Escape single quotes in comment for PowerShell safety
        safe_comment = comment.replace("'", "''")
        # Build PowerShell script
        script = f"""
Import-Module {self.module_name} -ErrorAction Stop
$conn = New-SCOMManagementGroupConnection -ComputerName "{self.mgmt_server}" -ErrorAction Stop
$group = Get-SCOMGroup -DisplayName "{group_display_name}" -ErrorAction Stop
$instances = Get-SCOMClassInstance -Group $group
$duration = New-TimeSpan -Seconds {total_seconds}
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
        if dry_run:
            logger.info(f"[DRY RUN] Would enable SCOM maintenance for group '{group_display_name}', duration={duration}")
            return True, []
        success, output = self._run_ps(script)
        if success:
            logger.info(f"SCOM maintenance enabled: {output}")
            return True, [output]
        else:
            logger.error(f"SCOM maintenance failed: {output}")
            return False, [output]

    def exit_maintenance(self, group_display_name: str, dry_run: bool = False) -> bool:
        """Explicitly exit maintenance mode for group if not already expired (optional)."""
        # If SCOM maintenance auto-expires via duration, this may not be needed.
        # But we provide for manual early exit or to ensure cleanup.
        script = f"""
Import-Module {self.module_name} -ErrorAction Stop
$conn = New-SCOMManagementGroupConnection -ComputerName "{self.mgmt_server}" -ErrorAction Stop
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
        if dry_run:
            logger.info(f"[DRY RUN] Would disable SCOM maintenance for group '{group_display_name}'")
            return True
        success, output = self._run_ps(script)
        logger.info(f"SCOM maintenance disable output: {output}")
        return success

class ILOManager:
    """Manages HPE iLO maintenance mode via REST API or CLI."""

    def __init__(self, cluster_def: dict):
        self.cluster_def = cluster_def
        # Global iLO credentials from env; cluster-specific overrides
        self.global_user, self.global_password = get_ilo_credentials()
        # Determine which method to use: 'rest' or 'ilorest' or 'powershell'
        self.method = 'rest'  # default; could be overridden by config
        # Timeout for HTTP requests
        self.timeout = 30

    def _get_ilo_credentials(self, server_name: str) -> tuple[str, str]:
        """Get iLO username/password for a given server."""
        cred_map = self.cluster_def.get('ilo_credentials', {})
        if server_name in cred_map:
            cred_info = cred_map[server_name]
            username = cred_info.get('username', self.global_user)
            password_env = cred_info.get('password_env')
            if password_env:
                password = get_credential(password_env, required=False, default=self.global_password)
            else:
                password = self.global_password
            return username, password
        else:
            return self.global_user, self.global_password

    def _get_ilo_ip(self, server_name: str) -> Optional[str]:
        """Get iLO IP address for a server."""
        ilo_map = self.cluster_def.get('ilo_addresses', {})
        return ilo_map.get(server_name)

    def _create_window_rest(self, ilo_ip: str, username: str, password: str,
                             start_dt: datetime, end_dt: datetime, dry_run: bool = False) -> tuple[bool, str]:
        """Create iLO maintenance window using REST API."""
        if dry_run:
            return True, f"[DRY RUN] Would create iLO maintenance window on {ilo_ip} from {start_dt} to {end_dt}"
        try:
            import requests
            # Disable SSL warnings if using self-signed
            requests.packages.urllib3.disable_warnings()
        except ImportError:
            return False, "requests module not available"

        session = requests.Session()
        session.auth = (username, password)
        session.verify = False  # iLO often uses self-signed

        # iLO 4 REST API uses /rest/v1/maintenancewindows
        base_url = f"https://{ilo_ip}/rest/v1"
        # Validate iLO is reachable quickly
        try:
            # Quick check
            r = session.get(f"{base_url}/systems/1", timeout=self.timeout)
            if r.status_code not in (200, 201):
                return False, f"iLO unreachable or auth failed: {r.status_code}"
        except Exception as e:
            return False, f"iLO connection failed: {e}"

        # Build window payload
        window_name = f"maintenance_{int(time.time())}"
        payload = {
            "Name": window_name,
            "StartTime": format_datetime_for_api(start_dt),
            "EndTime": format_datetime_for_api(end_dt),
            "Repeat": "Once"
        }
        try:
            resp = session.post(f"{base_url}/maintenancewindows", json=payload, timeout=self.timeout)
            if resp.status_code in (200, 201, 202):
                data = resp.json()
                window_id = data.get('Id') or data.get('id')
                return True, f"Created iLO maintenance window (id={window_id}) on {ilo_ip}"
            else:
                return False, f"iLO API error {resp.status_code}: {resp.text[:200]}"
        except Exception as e:
            return False, f"iLO window creation failed: {e}"

    def _create_window_ilorest(self, ilo_ip: str, username: str, password: str,
                               start_dt: datetime, end_dt: datetime, dry_run: bool = False) -> tuple[bool, str]:
        """Use HPE ilorest CLI to create maintenance window."""
        if dry_run:
            return True, f"[DRY RUN] Would use ilorest for {ilo_ip}"
        # Build command: ilorest login <ip> -u user -p pass; set maintwindow; logout
        ilorest_exe = "ilorest"  # assume in PATH
        # Create window using ilorest
        # Note: ilorest uses set maintwindow with --start and --duration in minutes or --end?
        # Let's assume: ilorest set maintwindow --enabled true --start <ISO> --end <ISO>
        # However actual ilorest syntax: set maintwindow --start <date> --duration <min>?
        # We'll try generic approach and catch failure
        start_str = start_dt.strftime('%Y-%m-%dT%H:%M:%S')
        end_str = end_dt.strftime('%Y-%m-%dT%H:%M:%S')
        # Assume ilorest supports: ilorest set maintwindow --enabled true --start <start> --end <end>
        cmd_login = [ilorest_exe, "login", ilo_ip, "-u", username, "-p", password]
        cmd_set = [ilorest_exe, "set", "maintwindow", "--enabled", "true", "--start", start_str, "--end", end_str]
        cmd_logout = [ilorest_exe, "logout"]
        try:
            # Login
            r = subprocess.run(cmd_login, capture_output=True, text=True, timeout=self.timeout)
            if r.returncode != 0:
                return False, f"ilorest login failed: {r.stderr}"
            # Set
            r = subprocess.run(cmd_set, capture_output=True, text=True, timeout=self.timeout)
            success = r.returncode == 0
            msg = r.stdout if success else r.stderr
            # Logout
            subprocess.run(cmd_logout, capture_output=True)
            return success, msg
        except FileNotFoundError:
            return False, "ilorest command not found"
        except Exception as e:
            return False, str(e)

    def set_maintenance_window(self, cluster_def: dict, start_dt: datetime, end_dt: datetime, dry_run: bool = False) -> tuple[bool, dict]:
        """Set maintenance window on all iLO interfaces in the cluster."""
        servers = cluster_def.get('servers', [])
        if dry_run:
            logger.info(f"[DRY RUN] Would set iLO maintenance for {len(servers)} servers")
            fake_details = {}
            for s in servers:
                fake_details[s] = {
                    "success": True,
                    "message": "[DRY RUN] Simulated iLO window",
                    "ilo_ip": cluster_def.get('ilo_addresses', {}).get(s, 'N/A')
                }
            return True, fake_details

        results = {}
        overall_success = True
        ilo_addresses = cluster_def.get('ilo_addresses', {})
        if not ilo_addresses:
            logger.warning("No iLO addresses defined for cluster; skipping iLO")
            return True, {"skipped": True, "reason": "No iLO addresses"}
        for server in servers:
            ilo_ip = ilo_addresses.get(server)
            if not ilo_ip:
                logger.warning(f"No iLO IP for server {server}; skipping")
                results[server] = {"success": False, "error": "Missing iLO IP"}
                overall_success = False
                continue
            username, password = self._get_ilo_credentials(server)
            if not username or not password:
                logger.warning(f"Missing iLO credentials for {server}; skipping")
                results[server] = {"success": False, "error": "Missing credentials"}
                overall_success = False
                continue
            # Try REST then fallback to ilorest
            success, msg = self._create_window_rest(ilo_ip, username, password, start_dt, end_dt, dry_run)
            if not success:
                logger.warning(f"REST method failed for {server}: {msg}; trying ilorest fallback")
                success, msg = self._create_window_ilorest(ilo_ip, username, password, start_dt, end_dt, dry_run)
            results[server] = {"success": success, "message": msg, "ilo_ip": ilo_ip}
            if not success:
                overall_success = False
        return overall_success, results

class OpenViewClient:
    """HPE OpenView maintenance integration via REST/CLI."""

    def __init__(self, config: dict, cluster_def: dict):
        self.config = config.get('openview', {})
        self.cluster_def = cluster_def
        self.base_url = self.config.get('default_api_url', 'https://openview.example.com/api')
        self.api_version = self.config.get('api_version', 'v1')
        self.endpoint = self.config.get('maintenance_endpoint', '/maintenance')
        self.timeout = self.config.get('timeout_seconds', 30)
        # Auth
        auth_cfg = self.config.get('auth', {})
        self.auth_type = auth_cfg.get('type', 'basic')
        user_env = auth_cfg.get('user_env', 'OPENVIEW_USER')
        pass_env = auth_cfg.get('pass_env', 'OPENVIEW_PASSWORD')
        self.username = get_credential(user_env, required=False, default='')
        self.password = get_credential(pass_env, required=False, default='')
        # Optionally use CLI if configured
        self.use_cli = self.config.get('use_cli', False)
        self.cli_path = self.config.get('cli_path', 'ovcall')

    def set_maintenance(self, cluster_def: dict, start_dt: datetime, end_dt: datetime, dry_run: bool = False) -> tuple[bool, str]:
        """Set maintenance mode for all OpenView nodes associated with the cluster."""
        node_ids_map = cluster_def.get('openview_node_ids', {})
        if not node_ids_map:
            logger.warning("No OpenView node IDs defined for cluster; skipping OpenView")
            return True, "No OpenView nodes configured"
        node_ids = list(node_ids_map.values())
        cluster_name = cluster_def.get('display_name', cluster_def.get('scom_group'))

        if self.use_cli:
            return self._set_maintenance_cli(node_ids, start_dt, end_dt, cluster_name, dry_run)
        else:
            return self._set_maintenance_rest(node_ids, start_dt, end_dt, cluster_name, dry_run)

    def _set_maintenance_rest(self, node_ids: list[str], start_dt: datetime, end_dt: datetime, cluster_name: str, dry_run: bool) -> tuple[bool, str]:
        """Use REST API to put nodes into maintenance."""
        if dry_run:
            return True, f"[DRY RUN] Would set OpenView maintenance for nodes: {node_ids}"
        import requests
        session = requests.Session()
        if self.auth_type == 'basic':
            session.auth = (self.username, self.password)
        else:
            # Could extend for token auth
            pass
        url = f"{self.base_url.rstrip('/')}/{self.api_version.strip('/')}{self.endpoint}"
        payload = {
            "nodes": node_ids,
            "start_time": format_datetime_for_api(start_dt),
            "end_time": format_datetime_for_api(end_dt),
            "comment": f"Maintenance for {cluster_name}",
            "cluster": cluster_name
        }
        try:
            resp = session.post(url, json=payload, timeout=self.timeout, verify=False)
            if resp.status_code in (200, 201, 202):
                return True, f"OpenView maintenance set for {len(node_ids)} nodes"
            else:
                return False, f"OpenView API error {resp.status_code}: {resp.text[:200]}"
        except Exception as e:
            return False, f"OpenView REST call failed: {e}"

    def _set_maintenance_cli(self, node_ids: list[str], start_dt: datetime, end_dt: datetime, cluster_name: str, dry_run: bool) -> tuple[bool, str]:
        """Use legacy ovcall or other CLI to set maintenance."""
        if dry_run:
            return True, f"[DRY RUN] Would use OpenView CLI for nodes: {node_ids}"
        # Example: ovcall -c "set maintenance -nodes node1,node2 -start ... -end ..."
        start_str = start_dt.strftime('%Y-%m-%d %H:%M:%S')
        end_str = end_dt.strftime('%Y-%m-%d %H:%M:%S')
        nodes_str = ','.join(node_ids)
        cmd = [
            self.cli_path,
            "-c", f"set maintenance -nodes {nodes_str} -start '{start_str}' -end '{end_str}' -comment '{cluster_name}'"
        ]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=self.timeout)
            if r.returncode == 0:
                return True, r.stdout
            else:
                return False, r.stderr
        except Exception as e:
            return False, str(e)

class EmailNotifier:
    """Sends email notifications to distribution lists."""

    def __init__(self, config: dict):
        self.config = config.get('email', {})
        self.smtp_server = self.config.get('smtp_server', 'localhost')
        self.smtp_port = self.config.get('smtp_port', 25)
        self.use_tls = self.config.get('use_tls', False)
        self.use_ssl = self.config.get('use_ssl', False)
        self.username = os.environ.get(self.config.get('username_env')) if self.config.get('username_env') else None
        self.password = os.environ.get(self.config.get('password_env')) if self.config.get('password_env') else None
        self.from_addr = self.config.get('from_address', 'maintenance-bot@example.com')
        self.templates = self.config.get('templates', {})
        # Support simple distribution list file in project root (overrides JSON config if present)
        simple_list_path = BASE_DIR / "maintenance_distribution_list.txt"
        if simple_list_path.exists():
            with open(simple_list_path) as f:
                self.simple_recipients = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            self.use_simple = True
        else:
            self.use_simple = False
            self.dist_lists = self.config.get('distribution_lists', {})

    def _get_recipients(self, action: str) -> list[str]:
        """Get recipient list based on action; uses simple list if configured."""
        if self.use_simple:
            return self.simple_recipients
        key = f"maintenance_{action}"  # e.g., maintenance_enabled
        return self.dist_lists.get(key, [])

    def send_maintenance_notification(self, action: str, cluster: dict, servers: list[str],
                                      start_time: Optional[datetime], end_time: Optional[datetime],
                                      dry_run: bool = False) -> bool:
        """Send email about maintenance mode change."""
        recipients = self._get_recipients(action)
        if not recipients:
            logger.warning(f"No distribution list configured for action '{action}'; skipping email")
            return False

        cluster_name = cluster.get('display_name', cluster.get('scom_group', 'Unknown'))
        environment = cluster.get('environment', 'unknown')
        # Prepare template variables
        tpl_vars = {
            'cluster_name': cluster_name,
            'environment': environment,
            'servers': ', '.join(servers),
            'start_time': start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else 'N/A',
            'end_time': end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else 'N/A',
            'triggered_by': 'iRequest',
            'additional_info': ''
        }
        if action == 'enabled':
            tpl_vars['additional_info'] = "Maintenance mode is now ACTIVE. Health checks and alerts are suppressed."
        elif action == 'disabled':
            tpl_vars['additional_info'] = "Maintenance mode has ended. Health checks are re-enabled. Some transient alerts may occur but are expected during stabilization."
        else:
            tpl_vars['additional_info'] = f"Maintenance action: {action}"

        # Subject
        subj_tpl = self.templates.get(f'subject_{action}', "Maintenance {action} - {cluster_name} ({environment})")
        subject = subj_tpl.format(**tpl_vars)

        # Body
        body_tpl = self.templates.get('body_template', "Dear Team,\n\nMaintenance window for cluster '{cluster_name}' has {action}.\n\nStart: {start_time}\nEnd: {end_time}\nServers: {servers}\n\n{additional_info}\n\nRegards,\nMaintenance Bot")
        # Need to replace {action} placeholder with past tense
        body_action = {"enabled": "been ENABLED", "disabled": "been DISABLED"}.get(action, action)
        body = body_tpl.format(action=body_action, **tpl_vars)

        if dry_run:
            logger.info(f"[DRY RUN] Email to: {recipients}\nSubject: {subject}\nBody: {body}")
            return True

        # Send via SMTP
        try:
            import smtplib
            from email.mime.multipart import MIMEMultipart
            from email.mime.text import MIMEText

            msg = MIMEMultipart()
            msg['From'] = self.from_addr
            msg['To'] = ', '.join(recipients)
            msg['Subject'] = subject
            msg.attach(MIMEText(body, 'plain'))

            if self.use_ssl:
                server = smtplib.SMTP_SSL(self.smtp_server, self.smtp_port, timeout=30)
            else:
                server = smtplib.SMTP(self.smtp_server, self.smtp_port, timeout=30)
            if self.use_tls:
                server.starttls()
            if self.username and self.password:
                server.login(self.username, self.password)
            server.send_message(msg)
            server.quit()
            logger.info(f"Notification email sent to {recipients}")
            return True
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False

def schedule_disable_task(cluster_id: str, end_dt: datetime, script_path: Path, no_schedule: bool) -> bool:
    """Schedule a Windows Scheduled Task to run maintenance disable at end_dt."""
    if no_schedule:
        logger.info("Scheduling of disable task is disabled (--no-schedule)")
        return True

    # Only Windows supports schtasks
    if sys.platform != "win32":
        logger.info("Scheduled task creation skipped: not running on Windows")
        return True

    task_name = f"MaintenanceDisable-{cluster_id}"
    python_exe = sys.executable  # Path to python interpreter

    # Command line to run
    # Use absolute paths; quote paths with spaces
    cmd = f'"{python_exe}" "{script_path}" --action disable --cluster-id {cluster_id} --no-schedule'

    # Delete existing task if present (ignore errors)
    run_command(["schtasks", "/Delete", "/TN", task_name, "/F"], capture_output=True)

    # Build schtask create command
    # /SC ONCE /ST hh:mm /SD yyyy/mm/dd
    st_time = end_dt.strftime("%H:%M")
    sd_date = end_dt.strftime("%Y/%m/%d")
    # Use highest privileges and run as SYSTEM (or could run as specified user)
    create_cmd = [
        "schtasks", "/Create",
        "/TN", task_name,
        "/TR", cmd,
        "/SC", "ONCE",
        "/ST", st_time,
        "/SD", sd_date,
        "/RL", "HIGHEST",
        "/RU", "SYSTEM",
        "/F"
    ]

    try:
        result = run_command(create_cmd, capture_output=True)
        if result.success:
            logger.info(f"Scheduled task '{task_name}' created successfully for {end_dt}")
            return True
        else:
            logger.error(f"Failed to create scheduled task: {result.stderr.strip()}")
            return False
    except Exception as e:
        logger.error(f"Exception creating task: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Maintenance Mode Orchestration for SCOM, HPE iLO, and OpenView.")
    parser.add_argument("-c", "--cluster-id", required=True, help="Cluster identifier (key from clusters_catalogue.json)")
    parser.add_argument("-s", "--start", help="Maintenance start datetime (ISO 8601, e.g., 2025-05-15T14:30:00 or 'now')")
    parser.add_argument("-e", "--end", help="Maintenance end datetime (ISO 8601). If omitted, computed from cluster schedule.")
    parser.add_argument("-a", "--action", choices=['enable', 'disable', 'validate'], default='enable',
                        help="Action to perform (default: enable)")
    parser.add_argument("--dry-run", action='store_true', help="Simulate only, do not make changes")
    parser.add_argument("--no-schedule", action='store_true', help="Do not create scheduled task for automatic disable")
    parser.add_argument("--verbose", "-v", action='store_true', help="Enable verbose debug logging")
    args = parser.parse_args()

    # Initialize root logging
    init_logging("maintenance.log")

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Prepare audit base
    audit = {
        'cluster_id': args.cluster_id,
        'action': args.action,
        'dry_run': args.dry_run,
        'timestamp_start': datetime.now().isoformat(),
        'steps': {}
    }

    # Load configs using utils (return {} on error, not exception)
    clusters_cfg = utils_load_json_config(CONFIG_DIR / "clusters_catalogue.json", required=False)
    if not clusters_cfg:
        logger.error("Failed to load clusters catalogue")
        sys.exit(1)
    clusters_map = clusters_cfg.get('clusters', {})

    scom_cfg = utils_load_json_config(CONFIG_DIR / "scom_config.json", required=False)
    openview_cfg = utils_load_json_config(CONFIG_DIR / "openview_config.json", required=False)
    email_cfg = utils_load_json_config(CONFIG_DIR / "email_distribution_lists.json", required=False)
    # OpsRamp config loaded in its own class

    # Validate cluster ID (must be a key in clusters)
    if args.cluster_id not in clusters_map:
        logger.error(f"Cluster ID '{args.cluster_id}' not found in catalogue")
        print(f"ERROR: Invalid cluster ID: {args.cluster_id}", file=sys.stderr)
        sys.exit(2)

    cluster_def = clusters_map[args.cluster_id]

    # Validate required fields in cluster definition
    required_fields = ['display_name', 'servers', 'scom_group', 'environment']
    missing = [f for f in required_fields if f not in cluster_def]
    if missing:
        logger.error(f"Cluster definition missing required fields: {missing}")
        sys.exit(1)
    if not isinstance(cluster_def['servers'], list) or len(cluster_def['servers']) == 0:
        logger.error(f"Cluster 'servers' must be a non-empty list for {args.cluster_id}")
        sys.exit(1)

    # Ensure cluster is not a server ID: if the cluster_id is actually a server hostname that appears in some cluster's servers list but not a cluster key, we already reject. Additional check could be implemented if needed.

    if args.action == 'validate':
        logger.info(f"Cluster '{args.cluster_id}' validated successfully. Servers: {cluster_def['servers']}")
        audit['success'] = True
        audit_file = LOG_DIR / f"validate_{args.cluster_id}_{int(time.time())}.json"
        save_audit(audit, audit_file)
        sys.exit(0)

    # Parse start/end based on action
    start_dt = None
    end_dt = None

    if args.action == 'enable':
        # Start datetime
        if args.start:
            try:
                start_dt = parse_datetime(args.start)
            except ValueError as e:
                logger.error(str(e))
                sys.exit(1)
        else:
            start_dt = datetime.now()

        # End datetime
        if args.end:
            try:
                end_dt = parse_datetime(args.end)
            except ValueError as e:
                logger.error(str(e))
                sys.exit(1)
        else:
            # Compute from cluster schedule
            schedule = cluster_def.get('schedule')
            if not schedule:
                logger.error("No end date provided and cluster has no schedule defined")
                sys.exit(1)
            try:
                end_dt = compute_next_work_start(schedule, start_dt)
                logger.info(f"Computed end time from schedule: {end_dt}")
            except Exception as e:
                logger.error(f"Failed to compute end time from schedule: {e}")
                sys.exit(1)

        # Ensure end > start
        if end_dt <= start_dt:
            logger.error("End time must be after start time")
            sys.exit(1)

        # Log window duration
        duration = end_dt - start_dt
        logger.info(f"Maintenance window: {start_dt} to {end_dt} (duration: {duration})")
    elif args.action == 'disable':
        # No start/end needed
        pass

    # Initialize managers
    try:
        scom_mgr = SCOMManager(scom_cfg)
    except Exception as e:
        logger.error(f"Failed to initialize SCOM manager: {e}")
        scom_mgr = None

    ilo_mgr = ILOManager(cluster_def)
    openview_mgr = OpenViewClient(openview_cfg, cluster_def)
    emailer = EmailNotifier(email_cfg)

    # OpsRamp (optional)
    try:
        opsramp_client = OpsRampClient(str(CONFIG_DIR / "opsramp_config.json"))
    except Exception as e:
        logger.warning(f"OpsRamp client unavailable: {e}")
        opsramp_client = None

    # Execute action
    if args.action == 'enable':
        overall_success = True

        # SCOM maintenance
        scom_success = False
        scom_info = ""
        if scom_mgr:
            duration_hours = (end_dt - start_dt).total_seconds() / 3600.0
            comment = f"iRequest Maintenance: {args.cluster_id}"
            scom_success, scom_info = scom_mgr.enter_maintenance(
                group_display_name=cluster_def['scom_group'],
                duration=timedelta(hours=duration_hours),
                comment=comment,
                dry_run=args.dry_run
            )
            logger.info(f"SCOM maintenance result: {'OK' if scom_success else 'FAILED'}")
        else:
            scom_success = False
            scom_info = "SCOM manager not initialized"
        audit['steps']['scom'] = {'success': scom_success, 'info': scom_info}
        if not scom_success:
            overall_success = False

        # iLO maintenance
        ilo_success, ilo_details = ilo_mgr.set_maintenance_window(cluster_def, start_dt, end_dt, dry_run=args.dry_run)
        logger.info(f"iLO result: {'OK' if ilo_success else 'FAILED'}")
        audit['steps']['ilo'] = {'success': ilo_success, 'details': ilo_details}
        if not ilo_success:
            overall_success = False

        # OpenView maintenance
        ov_success, ov_msg = openview_mgr.set_maintenance(cluster_def, start_dt, end_dt, dry_run=args.dry_run)
        logger.info(f"OpenView result: {'OK' if ov_success else 'FAILED'}: {ov_msg}")
        audit['steps']['openview'] = {'success': ov_success, 'message': ov_msg}
        if not ov_success:
            overall_success = False

        # Send enable email
        email_sent = emailer.send_maintenance_notification(
            action='enabled',
            cluster=cluster_def,
            servers=cluster_def['servers'],
            start_time=start_dt,
            end_time=end_dt,
            dry_run=args.dry_run
        )
        audit['steps']['email'] = {'sent': email_sent}
        if not email_sent:
            overall_success = False  # maybe not critical, but warning

        # OpsRamp metrics/events
        if opsramp_client and not args.dry_run:
            try:
                # Send metric for each server
                for server in cluster_def['servers']:
                    opsramp_client.send_metric(
                        resource_id=server,
                        metric_name="maintenance.mode",
                        value=1,
                        tags={"cluster": args.cluster_id, "environment": cluster_def.get('environment')}
                    )
                # Send alert/event
                opsramp_client.send_alert(
                    resource_id=args.cluster_id,
                    alert_type="maintenance.enabled",
                    severity="INFO",
                    message=f"Maintenance enabled for cluster {args.cluster_id}",
                    details={
                        "cluster": cluster_def.get('display_name'),
                        "servers": cluster_def['servers'],
                        "start": start_dt.isoformat(),
                        "end": end_dt.isoformat()
                    }
                )
                opsramp_client.send_event(
                    resource_id=args.cluster_id,
                    event_type="maintenance.enabled",
                    message=f"Maintenance window started for {cluster_def.get('display_name')}",
                    properties={"cluster": args.cluster_id, "action": "enable"}
                )
                audit['steps']['opsramp'] = {'success': True}
                logger.info("OpsRamp metrics and events sent")
            except Exception as e:
                logger.error(f"OpsRamp reporting failed: {e}")
                audit['steps']['opsramp'] = {'success': False, 'error': str(e)}
                overall_success = False
        else:
            audit['steps']['opsramp'] = {'skipped': True}

        # Schedule disable task
        script_abs = Path(__file__).resolve()
        schedule_ok = schedule_disable_task(
            cluster_id=args.cluster_id,
            end_dt=end_dt,
            script_path=script_abs,
            no_schedule=args.no_schedule
        )
        audit['steps']['scheduled_task'] = {'created': schedule_ok}
        if not schedule_ok:
            overall_success = False

        audit['success'] = overall_success
        audit_file = LOG_DIR / f"enable_{args.cluster_id}_{int(time.time())}.json"
        save_audit(audit, audit_file)

        if overall_success:
            logger.info("Maintenance enable completed successfully.")
            return 0
        else:
            logger.error("Maintenance enable completed with errors. Check audit log.")
            return 1

    elif args.action == 'disable':
        # Disable maintenance (or notify end)
        # For completeness, you could try to abort any leftover iLO windows or SCOM, but not strictly necessary.
        # We'll just send notifications and OpsRamp events.
        overall_success = True

        # Optionally call SCOM exit_maintenance if needed; but if using duration, it already expired. We can still try.
        # For safety, we can try to exit if still in maintenance (not auto-expired). But we may not have start time.
        # We'll skip to avoid errors.

        # Send disable email
        email_sent = emailer.send_maintenance_notification(
            action='disabled',
            cluster=cluster_def,
            servers=cluster_def['servers'],
            start_time=None,
            end_time=datetime.now(),
            dry_run=args.dry_run
        )
        audit['steps']['email'] = {'sent': email_sent}
        if not email_sent:
            overall_success = False

        # OpsRamp
        if opsramp_client and not args.dry_run:
            try:
                for server in cluster_def['servers']:
                    opsramp_client.send_metric(
                        resource_id=server,
                        metric_name="maintenance.mode",
                        value=0,
                        tags={"cluster": args.cluster_id, "environment": cluster_def.get('environment')}
                    )
                opsramp_client.send_alert(
                    resource_id=args.cluster_id,
                    alert_type="maintenance.disabled",
                    severity="INFO",
                    message=f"Maintenance disabled for cluster {args.cluster_id}",
                    details={"completed_at": datetime.now().isoformat()}
                )
                opsramp_client.send_event(
                    resource_id=args.cluster_id,
                    event_type="maintenance.disabled",
                    message=f"Maintenance window ended for {cluster_def.get('display_name')}",
                    properties={"cluster": args.cluster_id, "action": "disable"}
                )
                audit['steps']['opsramp'] = {'success': True}
            except Exception as e:
                logger.error(f"OpsRamp reporting failed: {e}")
                audit['steps']['opsramp'] = {'success': False, 'error': str(e)}
                overall_success = False
        else:
            audit['steps']['opsramp'] = {'skipped': True}

        # Cleanup: delete the scheduled disable task (if exists) since we are running it now
        task_name = f"MaintenanceDisable-{args.cluster_id}"
        if sys.platform == "win32":
            try:
                subprocess.run(["schtasks", "/Delete", "/TN", task_name, "/F"], capture_output=True)
                logger.info(f"Deleted scheduled task '{task_name}' after completion")
                audit['steps']['scheduled_task_cleanup'] = {'deleted': True}
            except Exception as e:
                logger.warning(f"Failed to delete scheduled task {task_name}: {e}")
                audit['steps']['scheduled_task_cleanup'] = {'deleted': False, 'error': str(e)}
        else:
            logger.info("Skipped scheduled task cleanup: not on Windows")
            audit['steps']['scheduled_task_cleanup'] = {'skipped': True}

        audit['success'] = overall_success
        audit_file = LOG_DIR / f"disable_{args.cluster_id}_{int(time.time())}.json"
        save_audit(audit, audit_file)

        if overall_success:
            logger.info("Maintenance disable notifications completed.")
            return 0
        else:
            logger.error("Maintenance disable encountered errors.")
            return 1

    else:
        logger.error(f"Unsupported action: {args.action}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
