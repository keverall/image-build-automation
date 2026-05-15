#!/usr/bin/env python3
"""
HPE Firmware and Driver Update Tool

Integrates with HPE Smart Update Tool (SUT) to create firmware/driver ISOs
for HPE ProLiant servers. Supports Gen10 and Gen10 Plus servers.
"""

import argparse
import json
import logging
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# Import utilities
sys.path.insert(0, str(Path(__file__).parent))
from utils.logging_setup import init_logging
from utils.config import load_json_config
from utils.file_io import ensure_dir
from utils.executor import run_command

# Module-level logger (root configured in main)
logger = logging.getLogger(__name__)


class FirmwareUpdater:
    """Manages HPE firmware and driver updates via SUT."""

    def __init__(
        self,
        config_path: str,
        output_dir: str = "output"
    ):
        """
        Initialize FirmwareUpdater.

        Args:
            config_path: Path to JSON configuration file
            output_dir: Directory for output ISOs and logs
        """
        self.config_path = Path(config_path)
        self.output_dir = Path(output_dir)
        ensure_dir(self.output_dir)
        self.config = self._load_config()
        self.sut_path = self._find_sut()
        self.build_log: List[Dict] = []

    def _load_config(self) -> Dict:
        """Load configuration from JSON file using utils."""
        return load_json_config(self.config_path, required=True)

    def _find_sut(self) -> Path:
        """Locate HPE Smart Update Tool executable."""
        search_paths = [
            Path("tools/hpe_sut.exe"),
            Path("/opt/hpe/sut/hpe_sut.exe"),
            Path("/usr/local/bin/hpe_sut"),
            Path("C:\\Program Files\\HPE\\Smart Update Tool\\hpe_sut.exe"),
        ]

        path_dirs = os.environ.get('PATH', '').split(os.pathsep)
        for dir_name in path_dirs:
            search_paths.append(Path(dir_name) / "hpe_sut")

        for path in search_paths:
            if path.exists():
                logger.info(f"Found HPE SUT at {path}")
                return path

        raise FileNotFoundError(
            "HPE Smart Update Tool (hpe_sut) not found. "
            "Ensure it's installed and in PATH or placed in tools/ directory."
        )

    def _determine_server_gen(self, server_name: str) -> str:
        """Determine server generation from name or inventory."""
        server_lower = server_name.lower()
        if 'gen10+' in server_lower or 'gen10plus' in server_lower or 'plus' in server_lower:
            return 'gen10_plus'
        return 'gen10'

    def _get_component_list(self, server_gen: str) -> List[Dict]:
        """Get list of firmware/driver components for server generation."""
        components = []
        gen_config = self.config.get('components', {}).get(server_gen, {})

        for fw in gen_config.get('firmware', []):
            components.append({
                'type': 'firmware',
                'component': fw['component'],
                'version': fw['version']
            })

        for drv in gen_config.get('drivers', []):
            components.append({
                'type': 'driver',
                'component': drv['component'],
                'version': drv['version']
            })

        return components

    def _log_step(self, step: str, status: str, details: str = ""):
        """Log a build step for audit trail."""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'step': step,
            'status': status,
            'details': details
        }
        self.build_log.append(log_entry)
        logger.info(f"[{status}] {step}: {details}" if details else f"[{status}] {step}")

    def build(self, server_name: str, dry_run: bool = False) -> Dict:
        """
        Build firmware/driver ISO for a server.

        Args:
            server_name: Server hostname
            dry_run: If True, simulate without executing commands

        Returns:
            Result dictionary with keys: success, firmware_iso, build_log, error
        """
        self._log_step("build_start", "START", f"Building for {server_name}")

        result = {
            'server': server_name,
            'firmware_iso': None,
            'success': False,
            'build_log': self.build_log,
            'timestamp': datetime.now().isoformat()
        }

        try:
            # Determine server generation
            server_gen = self._determine_server_gen(server_name)
            self._log_step("detect_generation", "INFO", f"Detected: {server_gen}")

            components = self._get_component_list(server_gen)
            self._log_step("component_resolution", "INFO", f"Components: {len(components)}")

            # Prepare output directory per server
            server_dir = self.output_dir / server_name
            ensure_dir(server_dir)

            # If dry-run, just simulate
            if dry_run:
                iso_name = f"{server_name}_firmware_dryrun.iso"
                fake_iso = server_dir / iso_name
                self._log_step("dry_run", "INFO", "Skipped SUT execution")
                result['firmware_iso'] = str(fake_iso)
                result['success'] = True
                return result

            # Construct SUT command
            repo_url = self.config.get('hpe_repository_url', '')
            sut_cmd = [
                str(self.sut_path),
                "create",
                "--server-generation", server_gen,
                "--repository", repo_url,
                "--output", str(server_dir / f"{server_name}_firmware.iso"),
                "--components", ",".join([c['component'] for c in components]),
                "--include-drivers"
            ]

            self._log_step("sut_invoke", "START", "Starting SUT")
            sut_result = run_command(sut_cmd, timeout=3600, check=False)

            if sut_result.success:
                self._log_step("sut_invoke", "SUCCESS", "SUT completed")
                iso_path = sut_result.stdout.strip().split('\n')[-1]  # approximate
                # Actually SUT prints output; better to capture known output file.
                # Let's assume we know the exact output path:
                iso_path = server_dir / f"{server_name}_firmware.iso"
                if iso_path.exists():
                    result['firmware_iso'] = str(iso_path)
                    result['success'] = True
                    self._log_step("iso_create", "SUCCESS", f"Created: {iso_path}")
                else:
                    self._log_step("iso_create", "FAILED", "ISO not found after SUT run")
            else:
                self._log_step("sut_invoke", "FAILED", sut_result.stderr[:200])
                result['error'] = sut_result.stderr

        except Exception as e:
            self._log_step("build", "FAILED", str(e))
            result['error'] = str(e)

        return result


def main():
    # Initialize root logging
    init_logging("firmware_updater.log")

    parser = argparse.ArgumentParser(
        description="Build HPE firmware/driver ISOs for servers"
    )
    parser.add_argument(
        "--config", "-c",
        default="configs/hpe_firmware_drivers_nov2025.json",
        help="Path to firmware/drivers configuration JSON"
    )
    parser.add_argument(
        "--server", "-s",
        help="Server hostname (default: from server list)"
    )
    parser.add_argument(
        "--server-list",
        default="configs/server_list.txt",
        help="Path to server list file"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default="output/firmware",
        help="Output directory for ISOs"
    )
    parser.add_argument(
        "--skip-download",
        action="store_true",
        help="Skip downloading components (use cached)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate without executing SUT"
    )

    args = parser.parse_args()

    try:
        # Load server list if needed
        if args.server:
            servers = [args.server]
        else:
            from utils.inventory import load_server_list
            servers = load_server_list(Path(args.server_list), include_details=False)  # type: ignore

        # Process each server
        updater = FirmwareUpdater(config_path=args.config, output_dir=args.output_dir)
        results = []
        for srv in servers:
            res = updater.build(srv, dry_run=args.dry_run)
            results.append(res)

        # Summary
        success_count = sum(1 for r in results if r['success'])
        logger.info(f"\nFirmware build: {success_count}/{len(servers)} succeeded")

        # Save per-server results
        from utils.file_io import save_json
        out_dir = Path(args.output_dir)
        ensure_dir(out_dir / "results")
        for r in results:
            save_json(r, out_dir / "results" / f"firmware_result_{r['server']}.json")

        return 0 if success_count == len(servers) else 1

    except Exception as e:
        logger.error(f"Firmware build failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
