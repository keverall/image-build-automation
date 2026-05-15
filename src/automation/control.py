"""
Central Control Module — single entry point for all external callers.

Homogenizes input from:
- Jenkins pipeline (parameter-driven builds)
- Windows Task Scheduler (cron/scheduled tasks)
- BMC iRequest forms (cluster maintenance requests)
- Direct Python API calls

Usage:
    from automation.control import Control

    # Jenkins pipeline
    ctrl = Control.from_jenkins(params)
    result = ctrl.run()

    # iRequest form
    ctrl = Control.from_irequest(form_data)
    result = ctrl.run()

    # Scheduler
    ctrl = Control.from_scheduler(task_params)
    result = ctrl.run()
"""

import logging
from datetime import datetime
from pathlib import Path
from typing import Any

from .core.orchestrator import AutomationOrchestrator
from .core.validators import validate_build_params, validate_cluster_id

logger = logging.getLogger(__name__)


class Control:
    """
    Central control interface for all automation requests.

    Normalizes input from different sources and delegates to the
    AutomationOrchestrator for execution.
    """

    def __init__(
        self,
        request_type: str,
        params: dict[str, Any],
        source: str = "unknown",
        dry_run: bool = False,
    ):
        """
        Initialize control instance.

        Args:
            request_type: Operation to perform (build_iso, maintenance_enable, etc.)
            params: Operation parameters
            source: Caller identifier ("jenkins", "scheduler", "irequest", "api")
            dry_run: Enable dry-run mode
        """
        self.request_type = request_type
        self.params = params
        self.source = source
        self.dry_run = dry_run

        self._orchestrator = AutomationOrchestrator(dry_run=dry_run)

    @classmethod
    def from_jenkins(cls, params: dict[str, Any]) -> "Control":
        """
        Create control from Jenkins pipeline parameters.

        Expected params:
            BUILD_STAGE: firmware | windows | deploy | scan | all
            SERVER_FILTER: comma-separated server list
            BASE_ISO_PATH: path to base Windows ISO
            DRY_RUN: "true" or "false"
            DEPLOY_METHOD: ilo | redfish
            SKIP_DOWNLOAD: "true" or "false"

        Args:
            params: Jenkins parameter dictionary

        Returns:
            Control instance configured for Jenkins build
        """
        stage = params.get("BUILD_STAGE", "all")
        dry_run = str(params.get("DRY_RUN", "false")).lower() == "true"

        # Map Jenkins stage to request type
        stage_map = {
            "firmware": "update_firmware",
            "windows": "patch_windows",
            "deploy": "deploy",
            "scan": "opsramp_report",
            "all": "build_iso",
        }
        request_type = stage_map.get(stage, "build_iso")

        control_params = {
            "base_iso": params.get("BASE_ISO_PATH"),
            "server_filter": params.get("SERVER_FILTER"),
            "deploy_method": params.get("DEPLOY_METHOD", "ilo"),
            "skip_download": str(params.get("SKIP_DOWNLOAD", "false")).lower() == "true",
        }

        return cls(request_type, control_params, source="jenkins", dry_run=dry_run)

    @classmethod
    def from_irequest(cls, form_data: dict[str, Any]) -> "Control":
        """
        Create control from BMC iRequest form submission.

        Expected fields:
            cluster_id: Cluster identifier (required)
            action: enable | disable | validate
            start: maintenance start time (ISO format or "now")
            end: maintenance end time (ISO format)
            dry_run: "true" or "false"

        Args:
            form_data: iRequest form field dictionary

        Returns:
            Control instance configured for maintenance operation
        """
        cluster_id = form_data.get("cluster_id", "")
        action = form_data.get("action", "enable")
        dry_run = str(form_data.get("dry_run", "false")).lower() == "true"

        request_type = f"maintenance_{action}"

        control_params = {
            "cluster_id": cluster_id,
            "start": form_data.get("start", "now"),
            "end": form_data.get("end"),
        }

        return cls(request_type, control_params, source="irequest", dry_run=dry_run)

    @classmethod
    def from_scheduler(cls, task_params: dict[str, Any]) -> "Control":
        """
        Create control from Windows Task Scheduler parameters.

        Expected params:
            task: maintenance_disable | build_firmware | build_windows
            cluster_id: cluster ID (for maintenance tasks)
            dry_run: "true" or "false"

        Args:
            task_params: Scheduler task parameter dictionary

        Returns:
            Control instance configured for scheduled operation
        """
        task = task_params.get("task", "")
        dry_run = str(task_params.get("dry_run", "false")).lower() == "true"

        # Map scheduler task to request type
        task_map = {
            "maintenance_disable": "maintenance_disable",
            "build_firmware": "update_firmware",
            "build_windows": "patch_windows",
        }
        request_type = task_map.get(task, task)

        control_params = {
            "cluster_id": task_params.get("cluster_id"),
        }

        return cls(request_type, control_params, source="scheduler", dry_run=dry_run)

    def run(self) -> dict[str, Any]:
        """
        Execute the request through the orchestrator.

        Returns:
            Result dictionary with success status, output, and metadata
        """
        logger.info(
            "Control.run() — type=%s source=%s dry_run=%s",
            self.request_type,
            self.source,
            self.dry_run,
        )

        # Pre-execution validation
        validation = self._validate()
        if validation:
            return {
                "success": False,
                "errors": validation,
                "source": self.source,
                "request_type": self.request_type,
                "timestamp": datetime.now().isoformat(),
            }

        # Execute through orchestrator
        result = self._orchestrator.execute(self.request_type, self.params)
        result["source"] = self.source

        logger.info("Control.run() completed — success=%s", result.get("success"))
        return result

    def _validate(self) -> list[str]:
        """Validate parameters before execution."""
        errors = []

        # Maintenance operations require valid cluster ID
        if self.request_type.startswith("maintenance_"):
            cluster_id = self.params.get("cluster_id")
            if not cluster_id:
                errors.append("cluster_id is required for maintenance operations")
            else:
                catalogue = Path("configs/clusters_catalogue.json")
                if catalogue.exists() and not validate_cluster_id(cluster_id, catalogue):
                    errors.append(f"Invalid cluster_id: {cluster_id}")

        # Build operations require valid base ISO
        if self.request_type in ("build_iso", "patch_windows"):
            base_iso = self.params.get("base_iso")
            if base_iso:
                iso_errors = validate_build_params(base_iso_path=base_iso)
                errors.extend(iso_errors)

        return errors


def run_jenkins(params: dict[str, Any]) -> dict[str, Any]:
    """Convenience: run a Jenkins pipeline request."""
    return Control.from_jenkins(params).run()


def run_irequest(form_data: dict[str, Any]) -> dict[str, Any]:
    """Convenience: run a BMC iRequest form request."""
    return Control.from_irequest(form_data).run()


def run_scheduler(task_params: dict[str, Any]) -> dict[str, Any]:
    """Convenience: run a scheduled task request."""
    return Control.from_scheduler(task_params).run()
