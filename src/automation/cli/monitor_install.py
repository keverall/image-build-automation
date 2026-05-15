#!/usr/bin/env python3
"""
Installation Monitoring Tool

Monitors Windows Server installations on HPE ProLiant hardware
using multiple methods:
- iLO REST API for power/boot status
- WinRM/PowerShell remoting for OS-level progress
- SNMP for hardware events (placeholder)
- Log file parsing (if accessible)

Provides real-time progress, alerts, and completion confirmation.
"""

import argparse
import logging
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Optional

import requests
from requests.auth import HTTPBasicAuth

from automation.utils.credentials import get_ilo_credentials
from automation.utils.executor import run_command
from automation.utils.file_io import ensure_dir, save_json
from automation.utils.inventory import ServerInfo, load_server_list

# Import utilities
from automation.utils.logging_setup import init_logging

# Import OpsRamp client
try:
    from automation.cli.opsramp_integration import OpsRampClient
except ImportError:
    OpsRampClient = None

# Module logger
logger = logging.getLogger(__name__)


class InstallationMonitor:
    """Monitors Windows Server installation progress on HPE servers."""

    CHECK_INTERVAL = 30  # seconds between checks
    INSTALL_TIMEOUT = 7200  # 2 hours max installation time

    STATUS_PROGRESS_MAP = {
        "Not Started": 0,
        "Initializing": 5,
        "Copying Files": 15,
        "Installing Features": 35,
        "Installing Updates": 60,
        "Configuring": 80,
        "Finalizing": 95,
        "Complete": 100,
        "Failed": -1,
    }

    def __init__(
        self, server_list_file: str = "configs/server_list.txt", opsramp_config: str = "configs/opsramp_config.json"
    ):
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
        self.monitor_log: list[dict] = []
        self.opsramp_client = self._init_opsramp_client()

    def _load_servers(self) -> list[ServerInfo]:
        """Load server list with connection details."""
        if not self.server_list_file.exists():
            logger.error(f"Server list not found: {self.server_list_file}")
            return []
        servers = load_server_list(self.server_list_file, include_details=True)
        return servers  # type: ignore

    def _init_opsramp_client(self) -> Optional[OpsRampClient]:
        """Initialize OpsRamp client if config exists and module available."""
        if not self.opsramp_config_path.exists():
            logger.warning("OpsRamp config not found, integration disabled")
            return None
        if OpsRampClient is None:
            logger.warning("OpsRamp client module not available")
            return None
        try:
            client = OpsRampClient(str(self.opsramp_config_path))
            logger.info("OpsRamp client initialized")
            return client
        except Exception as e:
            logger.warning(f"Failed to initialize OpsRamp client: {e}")
            return None

    def _log(self, action: str, server: str, status: str, details: str = ""):
        """Log monitoring event."""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "server": server,
            "status": status,
            "details": details,
        }
        self.monitor_log.append(entry)
        logger.info(f"[{status}] {action} | {server} | {details}")

    def _send_opsramp_metric(self, server: str, metric_name: str, value: float):
        """Send metric to OpsRamp."""
        if self.opsramp_client:
            try:
                self.opsramp_client.send_metric(
                    resource_id=server,
                    metric_name=metric_name,
                    value=value,
                    tags={"source": "automation.cli.monitor_install"},
                )
            except Exception as e:
                logger.debug(f"OpsRamp metric send failed: {e}")

    def _send_opsramp_alert(self, server: str, alert_type: str, severity: str, message: str):
        """Send alert to OpsRamp."""
        if self.opsramp_client:
            try:
                self.opsramp_client.send_alert(
                    resource_id=server, alert_type=alert_type, severity=severity, message=message
                )
            except Exception as e:
                logger.debug(f"OpsRamp alert send failed: {e}")

    def check_ilo_status(self, server: ServerInfo) -> dict:
        """Check server status via iLO."""
        ilo_ip = server.ilo_ip
        if not ilo_ip:
            return {"status": "unknown", "reason": "No iLO IP configured"}

        username, password = get_ilo_credentials()

        try:
            # Ping iLO
            result = run_command(["ping", "-c", "1", "-W", "2", ilo_ip], timeout=10)
            if not result.success:
                return {"status": "offline", "power_state": "unknown", "boot_source": "unknown"}

            # Query iLO via Redfish (simplified)
            redfish_url = f"https://{ilo_ip}/redfish/v1/Systems/1"
            try:
                resp = requests.get(redfish_url, auth=HTTPBasicAuth(username, password), verify=False, timeout=5)
                if resp.status_code == 200:
                    data = resp.json()
                    power_state = data.get("PowerState", "unknown")
                    boot_source = data.get("Boot", {}).get("BootSourceOverrideTarget", "unknown")
                    return {
                        "status": "online",
                        "power_state": power_state,
                        "boot_source": boot_source,
                        "ilo_reachable": True,
                    }
                else:
                    return {"status": "ilo_error", "http_status": resp.status_code}
            except requests.exceptions.RequestException as e:
                return {"status": "ilo_connect_error", "error": str(e)}

        except Exception as e:
            return {"status": "error", "error": str(e)}

    def check_winrm(self, server: ServerInfo) -> dict:
        """Check Windows Remote Management (WinRM) connectivity."""
        hostname = server.hostname

        try:
            ps_cmd = f"Test-WSMan -ComputerName {hostname} -ErrorAction SilentlyContinue"
            result = run_command(["powershell", "-Command", ps_cmd], timeout=10)

            if result.returncode == 0:
                return {"winrm_accessible": True, "transport": "WinRM"}
            else:
                return {"winrm_accessible": False, "error": result.stderr.strip()}

        except Exception as e:
            return {"winrm_accessible": False, "error": str(e)}

    def query_installation_progress_winrm(self, server: ServerInfo) -> dict:
        """Query Windows installation progress via WinRM."""
        hostname = server.hostname

        try:
            ps_script = """
            $setupPhase = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup' -Name 'Phase' -ErrorAction SilentlyContinue
            $installState = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup' -Name 'InstallState' -ErrorAction SilentlyContinue
            $setupProgress = Get-ItemProperty -Path 'HKLM:\\SYSTEM\\Setup\\State' -Name 'SetupProgress' -ErrorAction SilentlyContinue

            if ($setupPhase) { Write-Output "Phase=$($setupPhase.Phase)" }
            if ($installState) { Write-Output "InstallState=$($installState.InstallState)" }
            if ($setupProgress) { Write-Output "Progress=$($setupProgress.SetupProgress)" }

            $events = Get-WinEvent -LogName 'System' -MaxEvents 10 | Where-Object {$_.ProviderName -eq 'Microsoft-Windows-Setup'}
            if ($events) {
                Write-Output "LastSetupEvent=$($events[0].Id)"
            }
            """
            result = run_command(
                ["powershell", "-Command", f"Invoke-Command -ComputerName {hostname} -ScriptBlock {{{ps_script}}}"],
                timeout=30,
            )

            progress = {
                "winrm_accessible": True,
                "setup_phase": None,
                "install_state": None,
                "progress_percent": None,
                "last_event": None,
            }

            if result.success:
                for line in result.stdout.split("\n"):
                    line = line.strip()
                    if "=" in line:
                        key, _, val = line.partition("=")
                        if key == "Phase":
                            progress["setup_phase"] = int(val)
                        elif key == "InstallState":
                            progress["install_state"] = int(val)
                        elif key == "Progress":
                            progress["progress_percent"] = int(val)
                        elif key == "LastSetupEvent":
                            progress["last_event"] = int(val)

            return progress

        except Exception as e:
            return {"error": str(e)}

    def monitor_server(
        self, server: ServerInfo, timeout: int = INSTALL_TIMEOUT, poll_interval: int = CHECK_INTERVAL
    ) -> dict:
        """
        Monitor a single server's installation progress.

        Args:
            server: Server object
            timeout: Max monitoring time in seconds
            poll_interval: Seconds between checks

        Returns:
            Final monitoring result
        """
        hostname = server.hostname
        logger.info(f"Starting monitoring for {hostname}")

        monitoring_result = {
            "server": hostname,
            "start_time": datetime.now().isoformat(),
            "status": "monitoring",
            "progress_percent": 0,
            "current_phase": "Not Started",
            "duration_seconds": 0,
            "check_count": 0,
            "ilo_events": [],
            "winrm_progress": [],
            "alerts_sent": 0,
        }

        start_time = time.time()

        try:
            while True:
                check_time = datetime.now().isoformat()
                monitoring_result["check_count"] += 1
                elapsed = time.time() - start_time

                if elapsed > timeout:
                    monitoring_result["status"] = "timeout"
                    monitoring_result["error"] = f"Installation exceeded {timeout}s timeout"
                    self._log("monitor", hostname, "TIMEOUT", monitoring_result["error"])
                    self._send_opsramp_alert(hostname, "install_timeout", "WARNING", "Installation timed out")
                    break

                # 1. iLO status
                ilo_status = self.check_ilo_status(server)
                power_state = ilo_status.get("power_state", "unknown")
                boot_source = ilo_status.get("boot_source", "unknown")
                monitoring_result["ilo_events"].append(
                    {"timestamp": check_time, "power_state": power_state, "boot_source": boot_source}
                )

                # 2. WinRM check
                winrm_status = self.check_winrm(server)
                winrm_accessible = winrm_status.get("winrm_accessible", False)

                # 3. Progress if WinRM accessible
                if winrm_accessible:
                    progress = self.query_installation_progress_winrm(server)
                    monitoring_result["winrm_progress"].append({"timestamp": check_time, **progress})

                    phase = progress.get("setup_phase")
                    if phase is not None:
                        phase_names = {
                            0: "Not Started",
                            1: "Generalize",
                            2: "Specialize",
                            3: "Running Windows",
                            4: "RunPhase",
                        }
                        monitoring_result["current_phase"] = phase_names.get(phase, f"Phase {phase}")

                    pct = progress.get("progress_percent")
                    if pct is not None:
                        monitoring_result["progress_percent"] = pct

                # Log current status
                logger.info(
                    f"[{hostname}] Elapsed: {int(elapsed)}s | "
                    f"Power: {power_state} | "
                    f"WinRM: {'accessible' if winrm_accessible else 'not yet'} | "
                    f"Progress: {monitoring_result['progress_percent']}% | "
                    f"Phase: {monitoring_result['current_phase']}"
                )

                # Send OpsRamp metrics
                self._send_opsramp_metric(hostname, "install.progress.percent", monitoring_result["progress_percent"])
                self._send_opsramp_metric(hostname, "install.elapsed_seconds", elapsed)

                # Check for completion
                if monitoring_result["progress_percent"] == 100:
                    monitoring_result["status"] = "completed"
                    self._log("monitor", hostname, "COMPLETE", "Installation finished")
                    self._send_opsramp_alert(
                        hostname, "installation_complete", "INFO", "Windows installation completed successfully"
                    )
                    break

                # Check for failure
                last_winrm = monitoring_result["winrm_progress"][-1] if monitoring_result["winrm_progress"] else {}
                if last_winrm.get("install_state") == 2:  # Failed
                    monitoring_result["status"] = "failed"
                    monitoring_result["error"] = "Installation reported failure"
                    self._log("monitor", hostname, "FAILED", "Installation failed")
                    self._send_opsramp_alert(hostname, "installation_failed", "CRITICAL", "Windows installation failed")
                    break

                time.sleep(poll_interval)

        except KeyboardInterrupt:
            monitoring_result["status"] = "interrupted"
            logger.warning(f"Monitoring interrupted for {hostname}")
        except Exception as e:
            monitoring_result["status"] = "error"
            monitoring_result["error"] = str(e)
            logger.error(f"Monitoring error for {hostname}: {e}")
        finally:
            monitoring_result["end_time"] = datetime.now().isoformat()
            monitoring_result["duration_seconds"] = time.time() - start_time

            # Save session
            sessions_dir = Path("logs") / "monitoring_sessions"
            ensure_dir(sessions_dir)
            session_file = sessions_dir / f"monitor_{hostname}_{int(start_time)}.json"
            save_json(monitoring_result, session_file)
            logger.info(f"Monitoring session saved to {session_file}")

        return monitoring_result

    def monitor_all(self, timeout: int = INSTALL_TIMEOUT) -> dict:
        """Monitor all servers concurrently."""
        logger.info(f"\nStarting monitoring for {len(self.servers)} servers")
        logger.info(f"{'=' * 60}")

        results = []

        with ThreadPoolExecutor(max_workers=5) as executor:
            future_to_server = {
                executor.submit(self.monitor_server, server, timeout): server for server in self.servers
            }
            for future in as_completed(future_to_server):
                server = future_to_server[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Monitoring failed for {server.hostname}: {e}")
                    results.append({"server": server.hostname, "status": "error", "error": str(e)})

        completed = sum(1 for r in results if r.get("status") == "completed")
        failed = sum(1 for r in results if r.get("status") == "failed")
        timed_out = sum(1 for r in results if r.get("status") == "timeout")

        summary = {
            "timestamp": datetime.now().isoformat(),
            "total": len(results),
            "completed": completed,
            "failed": failed,
            "timeout": timed_out,
            "details": results,
        }

        summary_file = Path("logs") / f"monitor_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        save_json(summary, summary_file)

        logger.info("\nMonitoring Summary:")
        logger.info(f"  Completed: {completed}")
        logger.info(f"  Failed: {failed}")
        logger.info(f"  Timeout: {timed_out}")
        logger.info(f"  Total: {len(results)}")
        logger.info(f"  Summary saved to: {summary_file}")

        return summary


def main():
    # Initialize root logging
    init_logging("monitoring.log")

    parser = argparse.ArgumentParser(description="Monitor Windows Server installation progress")
    parser.add_argument("--server", "-s", help="Monitor specific server only")
    parser.add_argument("--server-list", default="configs/server_list.txt", help="Path to server list")
    parser.add_argument("--timeout", "-t", type=int, default=7200, help="Monitoring timeout in seconds")
    parser.add_argument("--poll-interval", type=int, default=30, help="Polling interval in seconds")
    parser.add_argument("--opsramp-config", default="configs/opsramp_config.json", help="OpsRamp configuration path")

    args = parser.parse_args()

    try:
        monitor = InstallationMonitor(args.server_list, args.opsramp_config)

        if args.server:
            server_obj = next((s for s in monitor.servers if s.hostname == args.server), None)
            if not server_obj:
                logger.error(f"Server not found: {args.server}")
                return 1
            result = monitor.monitor_server(server_obj, args.timeout, args.poll_interval)
            success = result["status"] == "completed"
        else:
            summary = monitor.monitor_all(args.timeout)
            success = summary["completed"] > 0

        return 0 if success else 1

    except Exception as e:
        logger.error(f"Monitoring failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
