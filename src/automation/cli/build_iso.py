#!/usr/bin/env python3
"""
Main ISO Build Orchestrator

Coordinates firmware/driver builds and Windows patching to create
complete customized ISOs for HPE ProLiant servers.
"""

import argparse
import json
import logging
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

# Import our custom modules and utils
from automation.cli.generate_uuid import generate_unique_uuid
from automation.cli.patch_windows_security import WindowsPatcher
from automation.cli.update_firmware_drivers import FirmwareUpdater
from automation.utils import AutomationBase, ensure_dir, load_server_list
from automation.utils.logging_setup import init_logging

# Module-level logger (uses root configured in main())
logger = logging.getLogger(__name__)

class ISOOrchestrator(AutomationBase):
    """Orchestrates the complete ISO build pipeline."""

    def __init__(
        self,
        config_dir: str = "configs",
        output_dir: str = "output",
        dry_run: bool = False,
    ):
        """
        Initialize orchestrator.

        Args:
            config_dir: Directory containing configuration files
            output_dir: Root output directory
            dry_run: Simulate mode
        """
        super().__init__(
            config_dir=Path(config_dir), output_dir=Path(output_dir), dry_run=dry_run
        )

        # Resolve config file paths
        self.fw_config = self.config_dir / "hpe_firmware_drivers_nov2025.json"
        self.patch_config = self.config_dir / "windows_patches.json"
        self.server_list_file = self.config_dir / "server_list.txt"

        self._validate_configs()

    def _validate_configs(self) -> None:
        """Validate all required configuration files exist."""
        required = {
            "Firmware config": self.fw_config,
            "Patch config": self.patch_config,
            "Server list": self.server_list_file,
        }

        for name, path in required.items():
            if not path.exists():
                raise FileNotFoundError(f"{name} not found: {path}")

        self.logger.info("All configuration files validated")

    def _load_servers(self) -> list[str]:
        """Load server list from file."""
        servers_objs = load_server_list(self.server_list_file, include_details=False)
        # type: ignore - we get List[str] when include_details=False
        return servers_objs  # type: ignore

    def build_for_server(
        self, server_name: str, base_iso_path: Optional[str] = None
    ) -> dict:
        """
        Complete ISO build for a single server.

        Args:
            server_name: Server hostname/identifier
            base_iso_path: Path to base Windows Server ISO (optional)

        Returns:
            Build result dictionary
        """
        self.log_and_audit(
            "build_start", "START", f"Building ISOs for {server_name}", server_name
        )

        result = {
            "server": server_name,
            "uuid": None,
            "firmware_iso": None,
            "patched_iso": None,
            "combined_iso": None,
            "success": False,
            "timestamp": datetime.now().isoformat(),
            "steps": [],
        }

        try:
            # Step 1: Generate deterministic UUID
            if self.dry_run:
                generated_uuid = "00000000-0000-0000-0000-000000000000"
            else:
                generated_uuid = generate_unique_uuid(server_name)
            result["uuid"] = generated_uuid
            result["steps"].append({"step": "automation.cli.generate_uuid", "uuid": generated_uuid})
            self.log_and_audit(
                "automation.cli.generate_uuid", "SUCCESS", f"UUID: {generated_uuid}", server_name
            )

            # Step 2: Build firmware/driver ISO
            fw_output = self.output_dir / "firmware" / server_name
            fw_updater = FirmwareUpdater(str(self.fw_config), str(fw_output))
            fw_result = fw_updater.build(server_name, dry_run=self.dry_run)

            if fw_result.get("success") and fw_result.get("firmware_iso"):
                result["firmware_iso"] = fw_result["firmware_iso"]
                self.log_and_audit(
                    "firmware_iso",
                    "SUCCESS",
                    f"ISO: {Path(fw_result['firmware_iso']).name}",
                    server_name,
                )
            else:
                self.log_and_audit(
                    "firmware_iso", "FAILED", "Firmware ISO build failed", server_name
                )
            result["steps"].append({"step": "firmware_iso", "status": "done"})

            # Step 3: Build patched Windows ISO
            if not base_iso_path:
                self.logger.warning(
                    "No base Windows ISO provided, skipping Windows patching"
                )
            else:
                patch_output = self.output_dir / "patched" / server_name
                patcher = WindowsPatcher(
                    str(self.patch_config), output_dir=str(patch_output)
                )
                patch_result = patcher.build(
                    base_iso_path, server_name, dry_run=self.dry_run
                )

                if patch_result.get("success") and patch_result.get("patched_iso"):
                    result["patched_iso"] = patch_result["patched_iso"]
                    self.log_and_audit(
                        "patched_iso",
                        "SUCCESS",
                        f"ISO: {Path(patch_result['patched_iso']).name}",
                        server_name,
                    )
                else:
                    self.log_and_audit(
                        "patched_iso", "FAILED", "Windows patching failed", server_name
                    )

            result["steps"].append({"step": "patched_iso", "status": "done"})

            # Step 4: Generate combined deployment package
            combined_dir = self.output_dir / "combined" / server_name
            ensure_dir(combined_dir)

            # Copy firmware ISO
            if result["firmware_iso"] and Path(result["firmware_iso"]).exists():
                fw_dest = combined_dir / Path(result["firmware_iso"]).name
                shutil.copy2(result["firmware_iso"], fw_dest)
                self.logger.info("Copied firmware ISO to deployment package")

            # Copy patched ISO
            if result["patched_iso"] and Path(result["patched_iso"]).exists():
                pw_dest = combined_dir / Path(result["patched_iso"]).name
                shutil.copy2(result["patched_iso"], pw_dest)
                self.logger.info("Copied patched ISO to deployment package")

            # Create metadata file
            metadata = {
                "server_name": server_name,
                "uuid": result["uuid"],
                "build_timestamp": result["timestamp"],
                "firmware_iso": (
                    Path(result["firmware_iso"]).name
                    if result["firmware_iso"]
                    else None
                ),
                "patched_iso": (
                    Path(result["patched_iso"]).name if result["patched_iso"] else None
                ),
                "config_version": "nov2025",
            }
            with open(combined_dir / "deployment_metadata.json", "w") as f:
                json.dump(metadata, f, indent=2)

            result["combined_iso"] = str(combined_dir)
            self.log_and_audit(
                "deployment_package",
                "SUCCESS",
                f"Combined package at {combined_dir}",
                server_name,
            )

            result["steps"].append({"step": "deployment_package", "status": "done"})
            result["success"] = True

        except Exception as e:
            error_msg = str(e)
            self.log_and_audit("build", "FAILED", error_msg, server_name)
            self.logger.error(
                f"Build failed for {server_name}: {error_msg}", exc_info=True
            )
            result["error"] = error_msg

        # Save per-server result
        self.save_result(result, "build_result", category="results")

        return result

    def build_all(self, base_iso_path: Optional[str] = None) -> dict:
        """
        Build ISOs for all servers from server list.

        Args:
            base_iso_path: Path to base Windows Server ISO

        Returns:
            Summary dictionary
        """
        self.log_and_audit("build_all", "START", "Building for all servers")

        servers = self._load_servers()
        results = []

        for server in servers:
            self.logger.info(f"\n{'='*70}")
            self.logger.info(f"Processing: {server}")
            self.logger.info(f"{'='*70}")

            result = self.build_for_server(server, base_iso_path)
            results.append(result)

        # Summary
        success_count = sum(1 for r in results if r["success"])
        summary = {
            "timestamp": datetime.now().isoformat(),
            "total_servers": len(servers),
            "successful": success_count,
            "failed": len(servers) - success_count,
            "results": results,
        }

        self.save_result(summary, "build_summary")
        self.logger.info(f"\nBuild Summary: {success_count}/{len(servers)} successful")

        self.log_and_audit(
            "build_all",
            "COMPLETE",
            f"Success: {success_count}/{len(servers)}",
            "all_servers",
        )

        return summary

def main():
    # Initialize root logging to console + file
    init_logging("build_orchestrator.log")

    parser = argparse.ArgumentParser(
        description="Orchestrate ISO builds for HPE ProLiant servers"
    )
    parser.add_argument(
        "--base-iso",
        "-b",
        help="Path to base Windows Server ISO (required for Windows patching)",
    )
    parser.add_argument(
        "--config-dir", "-c", default="configs", help="Configuration directory"
    )
    parser.add_argument("--output-dir", "-o", default="output", help="Output directory")
    parser.add_argument(
        "--server", "-s", help="Build for specific server (default: all servers)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Simulate without executing commands"
    )
    parser.add_argument(
        "--skip-audit", action="store_true", help="Skip audit logging (for testing)"
    )

    args = parser.parse_args()

    try:
        orchestrator = ISOOrchestrator(
            config_dir=args.config_dir, output_dir=args.output_dir, dry_run=args.dry_run
        )

        if args.server:
            result = orchestrator.build_for_server(args.server, args.base_iso)
            success = result["success"]
        else:
            summary = orchestrator.build_all(args.base_iso)
            success = summary["successful"] == summary["total_servers"]

        # Save master audit unless skipped
        if not args.skip_audit:
            orchestrator.save_audit()

        return 0 if success else 1

    except Exception as e:
        logger.error(f"Orchestrator failed: {e}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())
