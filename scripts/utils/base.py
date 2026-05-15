"""Base class for automation scripts providing common functionality."""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .logging_setup import get_logger
from .config import load_json_config
from .inventory import load_server_list, ServerInfo
from .audit import AuditLogger
from .file_io import ensure_dir, save_json
from .executor import run_command, CommandResult

logger = logging.getLogger(__name__)


class AutomationBase:
    """
    Base class for automation scripts.

    Provides common initialization through explicit init_logging() call.
    Subclasses should call init_logging() at the start of their main().
    """

    CONFIG_DIR = Path("configs")
    OUTPUT_DIR = Path("output")
    LOG_DIR = Path("logs")

    def __init__(
        self,
        config_dir: Optional[Path] = None,
        output_dir: Optional[Path] = None,
        dry_run: bool = False
    ):
        """
        Initialize base automation class.

        Note: Root logger should be configured by calling init_logging() before
        instantiating this class (typically in main()).

        Args:
            config_dir: Configuration directory path
            output_dir: Output directory path
            dry_run: Simulate mode flag
        """
        self.config_dir = Path(config_dir) if config_dir else self.CONFIG_DIR
        self.output_dir = Path(output_dir) if output_dir else self.OUTPUT_DIR
        self.dry_run = dry_run

        # Ensure directories exist
        ensure_dir(self.output_dir)
        ensure_dir(self.LOG_DIR)

        # Class-specific logger (propagates to root)
        self.logger = get_logger(self.__class__.__name__)
        self.logger.info(f"{self.__class__.__name__} initialized")

        # Audit logger
        self.audit = AuditLogger(
            category=self.__class__.__name__.lower(),
            log_dir=self.LOG_DIR
        )
        self.audit.log(
            action="initialization",
            status="INFO",
            details=f"Config dir: {self.config_dir}, Output dir: {self.output_dir}, Dry run: {dry_run}"
        )

    def load_config(self, filename: str, required: bool = True) -> Dict[str, Any]:
        """Load a JSON config file from config_dir."""
        path = self.config_dir / filename
        return load_json_config(path, required=required)

    def load_servers(self, filename: str = "server_list.txt") -> List[ServerInfo]:
        """Load server list from config_dir."""
        path = self.config_dir / filename
        return load_server_list(path, include_details=True)  # type: ignore

    def save_result(self, data: Dict[str, Any], base_name: str, category: Optional[str] = None) -> Path:
        """Save result JSON to output directory."""
        if category:
            out_dir = self.output_dir / category
        else:
            out_dir = self.output_dir
        ensure_dir(out_dir)

        timestamp = int(datetime.now().timestamp())
        filename = f"{base_name}_{timestamp}.json"
        filepath = out_dir / filename
        return save_json(data, filepath)

    def log_and_audit(
        self,
        action: str,
        status: str,
        server: str = "",
        details: str = "",
        **extra
    ) -> None:
        """Combined logging and audit entry."""
        self.logger.info(f"[{status}] {action} | {server} | {details}")
        self.audit.log(action=action, status=status, server=server,
                       details=details, **extra)

    def save_audit(self, filename: Optional[str] = None) -> Path:
        """Save accumulated audit entries to file and append to master log."""
        filepath = self.audit.save(filename)
        self.audit.append_to_master()
        return filepath

    def run_command(self, *args, **kwargs) -> CommandResult:
        """Wrapper around run_command."""
        return run_command(*args, **kwargs)

    # Subclasses should implement
    def validate(self) -> bool:
        raise NotImplementedError

    def execute(self) -> int:
        raise NotImplementedError
