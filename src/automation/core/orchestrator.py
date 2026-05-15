"""
AutomationOrchestrator — unified entry point for all external callers.

Handles requests from:
- Jenkins pipeline (via CLI args or API)
- Windows Task Scheduler (maintenance windows)
- BMC iRequest forms (cluster maintenance)
- Direct Python API calls

Usage:
    # API usage
    from automation.core import AutomationOrchestrator
    orch = AutomationOrchestrator()
    result = orch.execute("build_iso", {"base_iso": "/path/to/iso.iso"})

    # CLI usage
    python -m automation.core.orchestrator build_iso --base-iso /path/to/iso.iso
"""

import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from .router import route_request
from .validators import validate_build_params, validate_cluster_id

logger = logging.getLogger(__name__)


class AutomationOrchestrator:
    """Unified orchestrator for all automation requests."""

    def __init__(
        self,
        config_dir: Path = Path("configs"),
        logs_dir: Path = Path("logs"),
        dry_run: bool = False,
    ):
        """
        Initialize orchestrator.

        Args:
            config_dir: Configuration directory
            logs_dir: Logs directory
            dry_run: Enable dry-run mode for all operations
        """
        self.config_dir = config_dir
        self.logs_dir = logs_dir
        self.dry_run = dry_run

        logs_dir.mkdir(parents=True, exist_ok=True)
        logger.info("AutomationOrchestrator initialized (dry_run=%s)", dry_run)

    def execute(
        self,
        request_type: str,
        params: dict[str, Any],
    ) -> dict[str, Any]:
        """
        Execute a request with validation and routing.

        Args:
            request_type: Request type (build_iso, maintenance_enable, etc.)
            params: Request parameters

        Returns:
            Result dict with success status and output
        """
        logger.info("Executing %s request", request_type)

        # Validate based on request type
        errors = self._validate(request_type, params)
        if errors:
            return {
                "success": False,
                "errors": errors,
                "timestamp": datetime.now().isoformat(),
            }

        # Add common params
        if self.dry_run:
            params["dry_run"] = True

        # Route to handler
        result = route_request(request_type, params)
        result["timestamp"] = datetime.now().isoformat()
        result["request_type"] = request_type

        return result

    def _validate(
        self,
        request_type: str,
        params: dict[str, Any],
    ) -> list:
        """Validate parameters for a given request type."""
        errors = []

        # Build-related validation
        if request_type in ("build_iso", "patch_windows"):
            base_iso = params.get("base_iso")
            if base_iso:
                errors.extend(validate_build_params(base_iso_path=base_iso))

        # Maintenance-related validation
        if request_type.startswith("maintenance_"):
            cluster_id = params.get("cluster_id")
            if cluster_id:
                catalogue_path = self.config_dir / "clusters_catalogue.json"
                if not validate_cluster_id(cluster_id, catalogue_path):
                    errors.append(f"Invalid cluster ID: {cluster_id}")

        return errors


def main() -> int:
    """CLI entry point for the orchestrator."""
    parser = argparse.ArgumentParser(description="Automation Orchestrator")
    parser.add_argument(
        "request_type",
        help="Request type (build_iso, maintenance_enable, etc.)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Dry run mode")
    parser.add_argument("--base-iso", help="Base Windows ISO path")
    parser.add_argument("--cluster-id", help="Cluster ID for maintenance")
    parser.add_argument("--start", help="Maintenance start time")
    parser.add_argument("--end", help="Maintenance end time")

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    orch = AutomationOrchestrator(dry_run=args.dry_run)

    params = {}
    if args.base_iso:
        params["base_iso"] = args.base_iso
    if args.cluster_id:
        params["cluster_id"] = args.cluster_id
    if args.start:
        params["start"] = args.start
    if args.end:
        params["end"] = args.end

    result = orch.execute(args.request_type, params)

    if result.get("success"):
        print(f"SUCCESS: {args.request_type} completed")
        return 0
    else:
        print(f"FAILED: {args.request_type} — {result.get('errors', result.get('error'))}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
