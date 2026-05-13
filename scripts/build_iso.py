#!/usr/bin/env python3
"""
Main ISO Build Orchestrator

Coordinates firmware/driver builds and Windows patching to create
complete customized ISOs for HPE ProLiant servers.
"""

import argparse
import json
import logging
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import uuid as uuid_lib

# Import our custom modules
sys.path.insert(0, str(Path(__file__).parent))
from generate_uuid import generate_unique_uuid
from update_firmware_drivers import FirmwareUpdater
from patch_windows_security import WindowsPatcher


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('logs/build_orchestrator.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)


class ISOOrchestrator:
    """Orchestrates the complete ISO build pipeline."""

    def __init__(self, config_dir: str = "configs", output_dir: str = "output"):
        """
        Initialize orchestrator.

        Args:
            config_dir: Directory containing configuration files
            output_dir: Root output directory
        """
        self.config_dir = Path(config_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.audit_log = []

        # Load configurations
        self.fw_config = self.config_dir / "hpe_firmware_drivers_nov2025.json"
        self.patch_config = self.config_dir / "windows_patches.json"
        self.server_list_file = self.config_dir / "server_list.txt"

        self._validate_configs()

    def _validate_configs(self):
        """Validate all required configuration files exist."""
        required = {
            'Firmware config': self.fw_config,
            'Patch config': self.patch_config,
            'Server list': self.server_list_file
        }

        for name, path in required.items():
            if not path.exists():
                raise FileNotFoundError(f"{name} not found: {path}")

        logger.info("All configuration files validated")

    def _load_servers(self) -> List[str]:
        """Load server list from file."""
        servers = []
        with open(self.server_list_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    servers.append(line)
        logger.info(f"Loaded {len(servers)} servers from {self.server_list_file}")
        return servers

    def _audit(self, action: str, status: str, details: str = "", server: str = ""):
        """Record audit entry."""
        entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action,
            'status': status,
            'server': server,
            'details': details
        }
        self.audit_log.append(entry)
        logger.info(f"[{status}] {action} | {server} | {details}")

    def build_for_server(self, server_name: str, base_iso_path: Optional[str] = None,
                        dry_run: bool = False) -> Dict:
        """
        Complete ISO build for a single server.

        Args:
            server_name: Server hostname/identifier
            base_iso_path: Path to base Windows Server ISO (optional)
            dry_run: If True, don't execute commands

        Returns:
            Build result dictionary
        """
        self._audit("build_start", "START", f"Building ISOs for {server_name}", server_name)

        result = {
            'server': server_name,
            'uuid': None,
            'firmware_iso': None,
            'patched_iso': None,
            'combined_iso': None,
            'success': False,
            'timestamp': datetime.now().isoformat(),
            'steps': []
        }

        try:
            # Step 1: Generate deterministic UUID
            if dry_run:
                generated_uuid = "00000000-0000-0000-0000-000000000000"
            else:
                generated_uuid = generate_unique_uuid(server_name)
            result['uuid'] = generated_uuid
            result['steps'].append({'step': 'generate_uuid', 'uuid': generated_uuid})
            self._audit("generate_uuid", "SUCCESS", f"UUID: {generated_uuid}", server_name)

            # Step 2: Build firmware/driver ISO
            fw_output = self.output_dir / "firmware" / server_name
            fw_updater = FirmwareUpdater(str(self.fw_config), str(fw_output))
            fw_result = fw_updater.build(server_name, dry_run=dry_run)

            if fw_result.get('success') and fw_result.get('firmware_iso'):
                result['firmware_iso'] = fw_result['firmware_iso']
                self._audit("firmware_iso", "SUCCESS",
                           f"ISO: {Path(fw_result['firmware_iso']).name}", server_name)
            else:
                self._audit("firmware_iso", "FAILED", "Firmware ISO build failed", server_name)
                result['steps'].append({'step': 'firmware_iso', 'status': 'failed'})
                # Continue - firmware ISO might not be strictly required

            result['steps'].append({'step': 'firmware_iso', 'status': 'done'})

            # Step 3: Build patched Windows ISO
            if not base_iso_path:
                logger.warning("No base Windows ISO provided, skipping Windows patching")
            else:
                patch_output = self.output_dir / "patched" / server_name
                patcher = WindowsPatcher(str(self.patch_config),
                                        output_dir=str(patch_output))
                patch_result = patcher.build(base_iso_path, server_name, dry_run=dry_run)

                if patch_result.get('success') and patch_result.get('patched_iso'):
                    result['patched_iso'] = patch_result['patched_iso']
                    self._audit("patched_iso", "SUCCESS",
                               f"ISO: {Path(patch_result['patched_iso']).name}", server_name)
                else:
                    self._audit("patched_iso", "FAILED", "Windows patching failed", server_name)

            result['steps'].append({'step': 'patched_iso', 'status': 'done'})

            # Step 4: Generate combined deployment package
            combined_dir = self.output_dir / "combined" / server_name
            combined_dir.mkdir(parents=True, exist_ok=True)

            # Copy firmware ISO
            if result['firmware_iso'] and Path(result['firmware_iso']).exists():
                fw_dest = combined_dir / Path(result['firmware_iso']).name
                shutil.copy2(result['firmware_iso'], fw_dest)
                logger.info(f"Copied firmware ISO to deployment package")

            # Copy patched ISO
            if result['patched_iso'] and Path(result['patched_iso']).exists():
                pw_dest = combined_dir / Path(result['patched_iso']).name
                shutil.copy2(result['patched_iso'], pw_dest)
                logger.info(f"Copied patched ISO to deployment package")

            # Create metadata file
            metadata = {
                'server_name': server_name,
                'uuid': result['uuid'],
                'build_timestamp': result['timestamp'],
                'firmware_iso': Path(result['firmware_iso']).name if result['firmware_iso'] else None,
                'patched_iso': Path(result['patched_iso']).name if result['patched_iso'] else None,
                'config_version': 'nov2025'
            }
            with open(combined_dir / "deployment_metadata.json", 'w') as f:
                json.dump(metadata, f, indent=2)

            result['combined_iso'] = str(combined_dir)
            self._audit("deployment_package", "SUCCESS",
                       f"Combined package at {combined_dir}", server_name)

            result['steps'].append({'step': 'deployment_package', 'status': 'done'})
            result['success'] = True

        except Exception as e:
            error_msg = str(e)
            self._audit("build", "FAILED", error_msg, server_name)
            logger.error(f"Build failed for {server_name}: {error_msg}", exc_info=True)
            result['error'] = error_msg

        # Save per-server result
        results_dir = self.output_dir / "results"
        results_dir.mkdir(parents=True, exist_ok=True)
        result_file = results_dir / f"build_result_{server_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(result_file, 'w') as f:
            json.dump(result, f, indent=2)

        return result

    def build_all(self, base_iso_path: Optional[str] = None, dry_run: bool = False) -> Dict:
        """
        Build ISOs for all servers from server list.

        Args:
            base_iso_path: Path to base Windows Server ISO
            dry_run: If True, simulate

        Returns:
            Summary dictionary
        """
        self._audit("build_all", "START", f"Building for all servers")

        servers = self._load_servers()
        results = []

        for server in servers:
            logger.info(f"\n{'='*70}")
            logger.info(f"Processing: {server}")
            logger.info(f"{'='*70}")

            result = self.build_for_server(server, base_iso_path, dry_run)
            results.append(result)

        # Summary
        success_count = sum(1 for r in results if r['success'])
        summary = {
            'timestamp': datetime.now().isoformat(),
            'total_servers': len(servers),
            'successful': success_count,
            'failed': len(servers) - success_count,
            'results': results
        }

        summary_file = self.output_dir / f"build_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)

        logger.info(f"\n{'='*70}")
        logger.info(f"Build Summary: {success_count}/{len(servers)} successful")
        logger.info(f"Details saved to: {summary_file}")
        logger.info(f"{'='*70}")

        self._audit("build_all", "COMPLETE",
                   f"Success: {success_count}/{len(servers)}",
                   "all_servers")

        return summary


def main():
    parser = argparse.ArgumentParser(
        description="Orchestrate ISO builds for HPE ProLiant servers"
    )
    parser.add_argument(
        "--base-iso", "-b",
        help="Path to base Windows Server ISO (required for Windows patching)"
    )
    parser.add_argument(
        "--config-dir", "-c",
        default="configs",
        help="Configuration directory"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default="output",
        help="Output directory"
    )
    parser.add_argument(
        "--server", "-s",
        help="Build for specific server (default: all servers)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate without executing commands"
    )
    parser.add_argument(
        "--skip-audit",
        action="store_true",
        help="Skip audit logging (for testing)"
    )

    args = parser.parse_args()

    # Ensure output and logs directories exist
    Path("logs").mkdir(exist_ok=True)

    try:
        orchestrator = ISOOrchestrator(args.config_dir, args.output_dir)

        if args.server:
            result = orchestrator.build_for_server(args.server, args.base_iso, args.dry_run)
            success = result['success']
        else:
            summary = orchestrator.build_all(args.base_iso, args.dry_run)
            success = summary['successful'] == summary['total_servers']

        return 0 if success else 1

    except Exception as e:
        logger.error(f"Orchestrator failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
