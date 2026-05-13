#!/usr/bin/env python3
"""
HPE Firmware and Driver Update Tool

Integrates with HPE Smart Update Tool (SUT) to create firmware/driver ISOs
for HPE ProLiant servers. Supports Gen10 and Gen10 Plus servers.
"""

import subprocess
import json
import logging
import argparse
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class FirmwareUpdater:
    """Manages HPE firmware and driver updates via SUT."""

    def __init__(self, config_path: str, output_dir: str = "output"):
        """
        Initialize FirmwareUpdater.

        Args:
            config_path: Path to JSON configuration file
            output_dir: Directory for output ISOs and logs
        """
        self.config_path = Path(config_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.config = self._load_config()
        self.sut_path = self._find_sut()
        self.build_log = []

    def _load_config(self) -> Dict:
        """Load configuration from JSON file."""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            logger.info(f"Loaded configuration from {self.config_path}")
            return config
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {self.config_path}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in config file: {e}")
            raise

    def _find_sut(self) -> Path:
        """
        Locate HPE Smart Update Tool executable.

        Returns:
            Path to hpe_sut.exe

        Raises:
            FileNotFoundError: If SUT cannot be found
        """
        # Check common locations
        search_paths = [
            Path("tools/hpe_sut.exe"),
            Path("/opt/hpe/sut/hpe_sut.exe"),
            Path("/usr/local/bin/hpe_sut"),
            Path("C:\\Program Files\\HPE\\Smart Update Tool\\hpe_sut.exe"),
        ]

        # Also check PATH
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
        """
        Determine server generation from name or inventory.

        Args:
            server_name: Server hostname

        Returns:
            Either 'gen10' or 'gen10_plus'
        """
        # Simple heuristic: check for 'gen10+' or 'gen10 plus' in name
        # In production, this would query inventory system
        server_lower = server_name.lower()
        if 'gen10+' in server_lower or 'gen10plus' in server_lower or 'plus' in server_lower:
            return 'gen10_plus'
        return 'gen10'

    def _get_component_list(self, server_gen: str) -> List[Dict]:
        """
        Get list of firmware/driver components for server generation.

        Args:
            server_gen: Server generation ('gen10' or 'gen10_plus')

        Returns:
            List of component dictionaries
        """
        components = []
        gen_config = self.config.get('components', {}).get(server_gen, {})

        # Add firmware components
        for fw in gen_config.get('firmware', []):
            components.append({
                'type': 'firmware',
                'component': fw['component'],
                'version': fw['version']
            })

        # Add driver components
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

    def download_components(self, server_name: str, dry_run: bool = False) -> Tuple[List[str], List[str]]:
        """
        Download firmware and driver components for a specific server.

        Args:
            server_name: Server identifier
            dry_run: If True, simulate actions without making changes

        Returns:
            Tuple of (firmware_files, driver_files)
        """
        self._log_step("download_components", "START", f"Server: {server_name}")

        server_gen = self._determine_server_gen(server_name)
        components = self._get_component_list(server_gen)
        firmware_files = []
        driver_files = []

        download_dir = self.output_dir / "downloads" / server_name
        download_dir.mkdir(parents=True, exist_ok=True)

        for comp in components:
            comp_name = comp['component']
            version = comp['version']
            comp_type = comp['type']

            self._log_step(
                "download",
                "INFO",
                f"Downloading {comp_type} {comp_name} v{version}"
            )

            if dry_run:
                logger.info(f"[DRY RUN] Would download {comp_name} v{version}")
                continue

            # Use HPE SUT to download components
            download_cmd = [
                str(self.sut_path),
                "--download",
                "--component", comp_name,
                "--version", version,
                "--output", str(download_dir),
                "--repo-url", self.config.get('hpe_repository_url', '')
            ]

            # Add credentials if provided
            creds = self.config.get('download_credentials', {})
            if creds.get('username'):
                download_cmd.extend(["--user", creds['username']])
            if creds.get('password'):
                download_cmd.extend(["--password", creds['password']])

            result = subprocess.run(download_cmd, capture_output=True, text=True)

            if result.returncode != 0:
                error_msg = f"Failed to download {comp_name}: {result.stderr}"
                self._log_step("download", "FAILED", error_msg)
                logger.error(error_msg)
                # Continue with other components
                continue

            self._log_step("download", "SUCCESS", f"{comp_name} v{version}")
            if comp_type == 'firmware':
                firmware_files.append(str(download_dir / comp_name))
            else:
                driver_files.append(str(download_dir / comp_name))

        self._log_step("download_components", "COMPLETE",
                       f"Firmware: {len(firmware_files)}, Drivers: {len(driver_files)}")

        return firmware_files, driver_files

    def create_firmware_iso(self, server_name: str, firmware_files: List[str],
                           dry_run: bool = False) -> Optional[str]:
        """
        Create bootable firmware/driver ISO using HPE SUT.

        Args:
            server_name: Server identifier
            firmware_files: List of firmware/driver file paths
            dry_run: If True, simulate actions

        Returns:
            Path to created ISO file, or None if failed
        """
        self._log_step("create_iso", "START", f"Creating firmware ISO for {server_name}")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        iso_name = f"hpe_fw_drivers_{server_name}_{timestamp}.iso"
        output_path = self.output_dir / iso_name

        if dry_run:
            logger.info(f"[DRY RUN] Would create ISO: {output_path}")
            return str(output_path)

        # Build SUT command to create ISO
        sut_cmd = [
            str(self.sut_path),
            "--create-iso",
            "--output", str(output_path),
            "--label", f"HPE_FW_DRIVERS_{server_name.upper()}"
        ]

        # Add all downloaded components
        for file_path in firmware_files:
            sut_cmd.extend(["--input", file_path])

        # Add SPP if specified in config
        spp_iso = self.config.get('spp_iso')
        if spp_iso and Path(spp_iso).exists():
            sut_cmd.extend(["--spp", spp_iso])

        result = subprocess.run(sut_cmd, capture_output=True, text=True)

        if result.returncode != 0:
            error_msg = f"Failed to create ISO: {result.stderr}"
            self._log_step("create_iso", "FAILED", error_msg)
            logger.error(error_msg)
            return None

        self._log_step("create_iso", "SUCCESS", str(output_path))
        logger.info(f"Created firmware ISO: {output_path}")
        return str(output_path)

    def build(self, server_name: str, skip_download: bool = False,
              dry_run: bool = False) -> Dict:
        """
        Complete firmware/driver ISO build process for one server.

        Args:
            server_name: Server identifier
            skip_download: Skip download step, use existing files
            dry_run: Simulate actions without making changes

        Returns:
            Dictionary with build results
        """
        self._log_step("build", "START", f"Server: {server_name}")

        result = {
            'server': server_name,
            'success': False,
            'firmware_iso': None,
            'firmware_count': 0,
            'driver_count': 0,
            'timestamp': datetime.now().isoformat()
        }

        try:
            # Step 1: Download components
            if not skip_download:
                firmware_files, driver_files = self.download_components(
                    server_name, dry_run
                )
                result['firmware_count'] = len(firmware_files)
                result['driver_count'] = len(driver_files)
            else:
                logger.info("Skipping download, using existing files")
                result['firmware_count'] = 0
                result['driver_count'] = 0

            # Step 2: Create ISO
            iso_path = self.create_firmware_iso(server_name, firmware_files, dry_run)
            if iso_path:
                result['firmware_iso'] = iso_path
                result['success'] = True

            status = "SUCCESS" if result['success'] else "FAILED"
            self._log_step("build", status, f"ISO: {result.get('firmware_iso', 'N/A')}")

        except Exception as e:
            error_msg = f"Build failed: {str(e)}"
            self._log_step("build", "FAILED", error_msg)
            logger.error(error_msg, exc_info=True)
            result['error'] = str(e)

        # Save build log
        log_path = self.output_dir / f"build_log_{server_name}_{datetime.now().strftime('%Y%m%d')}.json"
        with open(log_path, 'w') as f:
            json.dump({
                'server': server_name,
                'timestamp': datetime.now().isoformat(),
                'success': result['success'],
                'log': self.build_log
            }, f, indent=2)

        return result


def main():
    parser = argparse.ArgumentParser(
        description="Build HPE firmware/driver ISOs for ProLiant servers"
    )
    parser.add_argument(
        "--config", "-c",
        default="configs/hpe_firmware_drivers_nov2025.json",
        help="Path to configuration JSON file"
    )
    parser.add_argument(
        "--server", "-s",
        help="Server name to build for (default: read from server_list.txt)"
    )
    parser.add_argument(
        "--server-list",
        default="configs/server_list.txt",
        help="Path to server list file"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default="output",
        help="Output directory for ISOs and logs"
    )
    parser.add_argument(
        "--skip-download",
        action="store_true",
        help="Skip download step, use existing files"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate actions without making changes"
    )

    args = parser.parse_args()

    # Determine servers to process
    servers = []
    if args.server:
        servers = [args.server]
    else:
        try:
            with open(args.server_list, 'r') as f:
                servers = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        except FileNotFoundError:
            logger.error(f"Server list file not found: {args.server_list}")
            return 1

    if not servers:
        logger.error("No servers specified")
        return 1

    # Process each server
    all_results = []
    updater = FirmwareUpdater(args.config, args.output_dir)

    for server in servers:
        logger.info(f"\n{'='*60}")
        logger.info(f"Processing server: {server}")
        logger.info(f"{'='*60}")

        result = updater.build(server, args.skip_download, args.dry_run)
        all_results.append(result)

        if result['success']:
            logger.info(f"✓ Successfully built ISO for {server}")
        else:
            logger.error(f"✗ Failed to build ISO for {server}")

    # Summary
    success_count = sum(1 for r in all_results if r['success'])
    logger.info(f"\n{'='*60}")
    logger.info(f"Build Summary: {success_count}/{len(all_results)} servers successful")
    logger.info(f"{'='*60}")

    return 0 if all(r['success'] for r in all_results) else 1


if __name__ == "__main__":
    sys.exit(main())
