#!/usr/bin/env python3
"""
Installation Monitoring Tool

Monitors Windows Server installations on HPE ProLiant hardware
using multiple methods:
- iLO REST API for power/boot status
- WinRM/PowerShell remoting for OS-level progress
- SNMP for hardware events
- Log file parsing (if accessible)

Provides real-time progress, alerts, and completion confirmation.
"""

import subprocess
import json
import logging
import argparse
import sys
import time
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from requests.auth import HTTPBasicAuth
import socket
import snmp  # pysnmp would be used in production


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('logs/monitoring.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)


class InstallationMonitor:
    """Monitors Windows Server installation progress on HPE servers."""

    CHECK_INTERVAL = 30  # seconds between checks
    INSTALL_TIMEOUT = 7200  # 2 hours max installation time
    STATUS_PROGRESS_MAP = {
        'Not Started': 0,
        'Initializing': 5,
        'Copying Files': 15,
        'Installing Features': 35,
        'Installing Updates': 60,
        'Configuring': 80,
        'Finalizing': 95,
        'Complete': 100,
        'Failed': -1
    }

    def __init__(self, server_list_file: str = "configs/server_list.txt",
                 opsramp_config: str = "configs/opsramp_config.json"):
        """
        Initialize monitor.

        Args:
            server_list_file: Path to server list
            opsramp_config: Path to OpsRamp configuration
        """
        self.server_list_file = Path(server_list_file)
        self.opsramp_config_path = Path(opsramp_config)
        self.servers = self._load_servers()
        self.monitoring_sessions = {}
        self.monitor_log = []
        self.opsramp_config = self._load_opsramp_config()

    def _load_servers(self) -> List[Dict]:
        """Load server list with connection details."""
        servers = []
        if not self.server_list_file.exists():
            logger.error(f"Server list not found: {self.server_list_file}")
            return servers

        with open(self.server_list_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                parts = [p.strip() for p in line.split(',')]
                server = {
                    'hostname': parts[0],
                    'ipmi_ip': parts[1] if len(parts) > 1 else None,
                    'ilo_ip': parts[2] if len(parts) > 2 else None
                }
                servers.append(server)

        logger.info(f"Loaded {len(servers)} servers for monitoring")
        return servers

    def _load_opsramp_config(self) -> Dict:
        """Load OpsRamp configuration."""
        if not self.opsramp_config_path.exists():
            logger.warning("OpsRamp config not found, integration disabled")
            return {}

        with open(self.opsramp_config_path, 'r') as f:
            return json.load(f)

    def _log(self, action: str, server: str, status: str, details: str = ""):
        """Log monitoring event."""
        entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action,
            'server': server,
            'status': status,
            'details': details
        }
        self.monitor_log.append(entry)
        logger.info(f"[{status}] {action} | {server} | {details}")

    def _send_opsramp_metric(self, server: str, metric_name: str,
                            value: float, timestamp: datetime = None):
        """Send metric to OpsRamp."""
        if not self.opsramp_config or not self.opsramp_config.get('integration', {}).get('send_metrics'):
            return

        # Placeholder - actual implementation would use OpsRamp API
        # Would construct metric payload and POST to OpsRamp
        logger.debug(f"[OpsRamp] Metric: {metric_name}={value} for {server}")

    def _send_opsramp_alert(self, server: str, alert_type: str,
                           severity: str, message: str):
        """Send alert to OpsRamp."""
        if not self.opsramp_config:
            return

        logger.info(f"[OpsRamp Alert] {severity} - {server}: {message}")

    def check_ilo_status(self, server: Dict) -> Dict:
        """
        Check server status via iLO.

        Args:
            server: Server dictionary with iLO IP

        Returns:
            Status dictionary
        """
        ilo_ip = server.get('ilo_ip')
        if not ilo_ip:
            return {'status': 'unknown', 'reason': 'No iLO IP configured'}

        ilo_user = os.environ.get('ILO_USER', 'Administrator')
        ilo_pass = os.environ.get('ILO_PASSWORD', 'password')

        try:
            # Use ilorest or python-hpilo for production
            # Here we simulate basic check

            # Ping iLO
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "2", ilo_ip],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                return {
                    'status': 'offline',
                    'power_state': 'unknown',
                    'boot_source': 'unknown'
                }

            # Query iLO via Redfish (simplified)
            redfish_url = f"https://{ilo_ip}/redfish/v1/Systems/1"
            try:
                resp = requests.get(
                    redfish_url,
                    auth=HTTPBasicAuth(ilo_user, ilo_pass),
                    verify=False,
                    timeout=5
                )
                if resp.status_code == 200:
                    data = resp.json()
                    power_state = data.get('PowerState', 'unknown')
                    boot_source = data.get('Boot', {}).get('BootSourceOverrideTarget', 'unknown')

                    return {
                        'status': 'online',
                        'power_state': power_state,
                        'boot_source': boot_source,
                        'ilo_reachable': True
                    }
                else:
                    return {
                        'status': 'ilo_error',
                        'http_status': resp.status_code
                    }
            except requests.exceptions.RequestException as e:
                return {'status': 'ilo_connect_error', 'error': str(e)}

        except Exception as e:
            return {'status': 'error', 'error': str(e)}

    def check_winrm(self, server: Dict) -> Dict:
        """
        Check Windows Remote Management (WinRM) connectivity.

        Args:
            server: Server dictionary

        Returns:
            Connectivity status
        """
        hostname = server['hostname']

        try:
            # Test WinRM connection using PowerShell
            ps_cmd = (
                f"Test-WSMan -ComputerName {hostname} -ErrorAction SilentlyContinue"
            )
            result = subprocess.run(
                ["powershell", "-Command", ps_cmd],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                return {
                    'winrm_accessible': True,
                    'transport': 'WinRM'
                }
            else:
                return {
                    'winrm_accessible': False,
                    'error': result.stderr.strip()
                }

        except subprocess.TimeoutExpired:
            return {'winrm_accessible': False, 'error': 'Timeout'}
        except Exception as e:
            return {'winrm_accessible': False, 'error': str(e)}

    def query_installation_progress_winrm(self, server: Dict) -> Dict:
        """
        Query Windows installation progress via WinRM.

        Args:
            server: Server dictionary

        Returns:
            Progress status
        """
        hostname = server['hostname']

        try:
            # PowerShell script to check installation status
            ps_script = """
            $setupPhase = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup' -Name 'Phase' -ErrorAction SilentlyContinue
            $installState = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup' -Name 'InstallState' -ErrorAction SilentlyContinue
            $setupProgress = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup\\State' -Name 'SetupProgress' -ErrorAction SilentlyContinue

            if ($setupPhase) { Write-Output "Phase=$($setupPhase.Phase)" }
            if ($installState) { Write-Output "InstallState=$($installState.InstallState)" }
            if ($setupProgress) { Write-Output "Progress=$($setupProgress.SetupProgress)" }

            # Also check Windows image setup status via event log
            $events = Get-WinEvent -LogName 'System' -MaxEvents 10 | Where-Object {$_.ProviderName -eq 'Microsoft-Windows-Setup'}
            if ($events) {
                Write-Output "LastSetupEvent=$($events[0].Id)"
            }
            """

            result = subprocess.run(
                [
                    "powershell",
                    "-Command",
                    f"Invoke-Command -ComputerName {hostname} -ScriptBlock {{{ps_script}}}"
                ],
                capture_output=True, text=True, timeout=30
            )

            progress = {
                'winrm_accessible': True,
                'setup_phase': None,
                'install_state': None,
                'progress_percent': None,
                'last_event': None
            }

            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    line = line.strip()
                    if '=' in line:
                        key, _, val = line.partition('=')
                        if key == 'Phase':
                            progress['setup_phase'] = int(val)
                        elif key == 'InstallState':
                            progress['install_state'] = int(val)
                        elif key == 'Progress':
                            progress['progress_percent'] = int(val)
                        elif key == 'LastSetupEvent':
                            progress['last_event'] = int(val)

            return progress

        except subprocess.TimeoutExpired:
            return {'winrm_accessible': False, 'error': 'WinRM timeout'}
        except Exception as e:
            return {'error': str(e)}

    def query_installation_progress_snmp(self, server: Dict) -> Dict:
        """
        Query installation progress via SNMP (if agent runs on target).

        Args:
            server: Server dictionary

        Returns:
            SNMP-derived status
        """
        # SNMP monitoring would be done via pysnmp
        # Placeholder for implementation
        return {'snmp_accessible': False, 'note': 'SNMP monitoring not implemented'}

    def check_installation_logs(self, server: Dict, log_path: str = None) -> Dict:
        """
        Check installation logs if accessible via network share.

        Args:
            server: Server dictionary
            log_path: UNC path to log files

        Returns:
            Log analysis results
        """
        if not log_path:
            return {'logs_accessible': False, 'note': 'No log path configured'}

        try:
            # Try to access logs via SMB
            result = subprocess.run(
                ["ls", log_path],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                return {'logs_accessible': True, 'log_path': log_path}
            else:
                return {'logs_accessible': False, 'error': result.stderr}
        except Exception as e:
            return {'logs_accessible': False, 'error': str(e)}

    def monitor_server(self, server: Dict, timeout: int = INSTALL_TIMEOUT,
                      poll_interval: int = CHECK_INTERVAL) -> Dict:
        """
        Monitor a single server's installation progress.

        Args:
            server: Server dictionary
            timeout: Maximum monitoring time in seconds
            poll_interval: Seconds between status checks

        Returns:
            Final monitoring result
        """
        hostname = server['hostname']
        logger.info(f"Starting monitoring for {hostname}")

        monitoring_result = {
            'server': hostname,
            'start_time': datetime.now().isoformat(),
            'status': 'monitoring',
            'progress_percent': 0,
            'current_phase': 'Not Started',
            'duration_seconds': 0,
            'check_count': 0,
            'ilo_events': [],
            'winrm_progress': [],
            'alerts_sent': 0
        }

        start_time = time.time()

        try:
            while True:
                check_time = datetime.now().isoformat()
                monitoring_result['check_count'] += 1
                elapsed = time.time() - start_time

                # Check timeout
                if elapsed > timeout:
                    monitoring_result['status'] = 'timeout'
                    monitoring_result['error'] = f'Installation exceeded {timeout}s timeout'
                    self._log('monitor', hostname, 'TIMEOUT', monitoring_result['error'])
                    self._send_opsramp_alert(hostname, 'install_timeout', 'WARNING',
                                            'Installation timed out')
                    break

                # 1. Check iLO status
                ilo_status = self.check_ilo_status(server)
                power_state = ilo_status.get('power_state', 'unknown')
                boot_source = ilo_status.get('boot_source', 'unknown')

                monitoring_result['ilo_events'].append({
                    'timestamp': check_time,
                    'power_state': power_state,
                    'boot_source': boot_source
                })

                # 2. Check if WinRM becomes accessible (OS booted)
                winrm_status = self.check_winrm(server)
                winrm_accessible = winrm_status.get('winrm_accessible', False)

                # 3. Query installation progress via WinRM if accessible
                if winrm_accessible:
                    progress = self.query_installation_progress_winrm(server)
                    monitoring_result['winrm_progress'].append({
                        'timestamp': check_time,
                        **progress
                    })

                    phase = progress.get('setup_phase')
                    if phase is not None:
                        phase_names = {0: 'Not Started', 1: 'Generalize', 2: ' specialize',
                                      3: 'Running Windows', 4: 'RunPhase'}
                        monitoring_result['current_phase'] = phase_names.get(phase, f'Phase {phase}')

                    pct = progress.get('progress_percent')
                    if pct is not None:
                        monitoring_result['progress_percent'] = pct

                # Log current status
                logger.info(
                    f"[{hostname}] Elapsed: {int(elapsed)}s | "
                    f"Power: {power_state} | "
                    f"WinRM: {'accessible' if winrm_accessible else 'not yet'} | "
                    f"Progress: {monitoring_result['progress_percent']}% | "
                    f"Phase: {monitoring_result['current_phase']}"
                )

                # Send OpsRamp metrics
                self._send_opsramp_metric(
                    hostname, 'install.progress.percent',
                    monitoring_result['progress_percent'], datetime.now()
                )
                self._send_opsramp_metric(
                    hostname, 'install.elapsed_seconds', elapsed, datetime.now()
                )

                # Check for completion
                if monitoring_result['progress_percent'] == 100:
                    monitoring_result['status'] = 'completed'
                    self._log('monitor', hostname, 'COMPLETE', 'Installation finished')
                    self._send_opsramp_alert(hostname, 'installation_complete', 'INFO',
                                            'Windows installation completed successfully')
                    break

                # Check for failure
                last_winrm = monitoring_result['winrm_progress'][-1] if monitoring_result['winrm_progress'] else {}
                if last_winrm.get('install_state') == 2:  # Failed
                    monitoring_result['status'] = 'failed'
                    monitoring_result['error'] = 'Installation reported failure'
                    self._log('monitor', hostname, 'FAILED', 'Installation failed')
                    self._send_opsramp_alert(hostname, 'installation_failed', 'CRITICAL',
                                            'Windows installation failed')
                    break

                # Sleep before next check
                time.sleep(poll_interval)

        except KeyboardInterrupt:
            monitoring_result['status'] = 'interrupted'
            logger.warning(f"Monitoring interrupted for {hostname}")
        except Exception as e:
            monitoring_result['status'] = 'error'
            monitoring_result['error'] = str(e)
            logger.error(f"Monitoring error for {hostname}: {e}")

        finally:
            monitoring_result['end_time'] = datetime.now().isoformat()
            monitoring_result['duration_seconds'] = time.time() - start_time

            # Save monitoring session
            sessions_dir = Path("logs") / "monitoring_sessions"
            sessions_dir.mkdir(parents=True, exist_ok=True)
            session_file = sessions_dir / f"monitor_{hostname}_{int(start_time)}.json"
            with open(session_file, 'w') as f:
                json.dump(monitoring_result, f, indent=2)

            logger.info(f"Monitoring session saved to {session_file}")

        return monitoring_result

    def monitor_all(self, timeout: int = INSTALL_TIMEOUT) -> Dict:
        """
        Monitor all servers concurrently.

        Args:
            timeout: Maximum monitoring duration per server

        Returns:
            Summary of monitoring results
        """
        logger.info(f"\n{'='*60}")
        logger.info(f"Starting monitoring for {len(self.servers)} servers")
        logger.info(f"{'='*60}")

        results = []

        with ThreadPoolExecutor(max_workers=5) as executor:
            future_to_server = {
                executor.submit(self.monitor_server, server, timeout): server
                for server in self.servers
            }

            for future in as_completed(future_to_server):
                server = future_to_server[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Monitoring failed for {server['hostname']}: {e}")
                    results.append({
                        'server': server['hostname'],
                        'status': 'error',
                        'error': str(e)
                    })

        # Summary
        completed = sum(1 for r in results if r.get('status') == 'completed')
        failed = sum(1 for r in results if r.get('status') == 'failed')
        timeout = sum(1 for r in results if r.get('status') == 'timeout')

        summary = {
            'timestamp': datetime.now().isoformat(),
            'total': len(results),
            'completed': completed,
            'failed': failed,
            'timeout': timeout,
            'details': results
        }

        summary_file = Path("logs") / f"monitor_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)

        logger.info(f"\nMonitoring Summary:")
        logger.info(f"  Completed: {completed}")
        logger.info(f"  Failed: {failed}")
        logger.info(f"  Timeout: {timeout}")
        logger.info(f"  Total: {len(results)}")
        logger.info(f"  Summary saved to: {summary_file}")

        return summary


def main():
    parser = argparse.ArgumentParser(
        description="Monitor Windows Server installation progress"
    )
    parser.add_argument(
        "--server", "-s",
        help="Monitor specific server only"
    )
    parser.add_argument(
        "--server-list",
        default="configs/server_list.txt",
        help="Path to server list"
    )
    parser.add_argument(
        "--timeout", "-t",
        type=int,
        default=7200,
        help="Monitoring timeout in seconds (default: 7200)"
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=30,
        help="Polling interval in seconds (default: 30)"
    )
    parser.add_argument(
        "--opsramp-config",
        default="configs/opsramp_config.json",
        help="OpsRamp configuration path"
    )

    args = parser.parse_args()

    monitor = InstallationMonitor(args.server_list, args.opsramp_config)

    if args.server:
        server = next((s for s in monitor.servers if s['hostname'] == args.server), None)
        if not server:
            logger.error(f"Server not found: {args.server}")
            return 1
        result = monitor.monitor_server(server, args.timeout, args.poll_interval)
        success = result['status'] == 'completed'
    else:
        summary = monitor.monitor_all(args.timeout)
        success = summary['completed'] > 0

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
