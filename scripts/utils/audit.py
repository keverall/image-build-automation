"""Audit logging utilities for compliance and traceability."""

import json
import logging
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class AuditLogger:
    """
    Centralized audit logger that writes structured JSON logs.

    Maintains an in-memory log list and persists to disk on demand.
    Supports both per-action audit files and a master append-only log.
    """

    def __init__(
        self,
        category: str,
        log_dir: Path = Path("logs"),
        master_log: str = "audit.log"
    ):
        """
        Initialize an audit logger for a specific category/component.

        Args:
            category: Category name (e.g., 'build', 'deploy', 'maintenance')
            log_dir: Base directory for audit logs
            master_log: Filename for the master log (line-delimited JSON)
        """
        self.category = category
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.master_log_path = self.log_dir / master_log
        self.entries: list[dict] = []

    def log(
        self,
        action: str,
        status: str,
        server: str = "",
        details: str = "",
        **extra
    ) -> dict:
        """
        Record an audit event.

        Args:
            action: What was attempted (e.g., 'enter_maintenance', 'deploy_iso')
            status: Result status (e.g., 'SUCCESS', 'FAILED', 'INFO', 'WARNING')
            server: Server hostname or empty for cluster-level events
            details: Optional human-readable details
            **extra: Additional key-value pairs to include

        Returns:
            The audit entry dict that was recorded
        """
        entry = {
            'timestamp': datetime.now().isoformat(),
            'category': self.category,
            'action': action,
            'status': status,
            'server': server,
            'details': details,
            **extra
        }
        self.entries.append(entry)
        logger.info(f"[{status}] {action} | {server} | {details}")
        return entry

    def save(self, filename: Optional[str] = None) -> Path:
        """
        Save accumulated entries to a JSON file.

        Args:
            filename: Optional custom filename; if None, uses category_timestamp.json

        Returns:
            Path to saved file
        """
        if filename is None:
            timestamp = int(time.time())
            filename = f"{self.category}_{timestamp}.json"

        filepath = self.log_dir / filename
        with open(filepath, 'w') as f:
            json.dump({
                'category': self.category,
                'generated_at': datetime.now().isoformat(),
                'entries': self.entries
            }, f, indent=2, default=str)

        logger.debug(f"Audit log saved to {filepath}")
        return filepath

    def append_to_master(self) -> None:
        """Append all entries to the master audit log (line-delimited JSON)."""
        with open(self.master_log_path, 'a') as f:
            for entry in self.entries:
                f.write(json.dumps(entry, default=str) + "\n")
        logger.debug(f"Appended {len(self.entries)} entries to master log")

    def clear(self) -> None:
        """Clear in-memory entries (call after save to rotate logs)."""
        self.entries = []


def save_audit_record(
    audit_data: dict,
    log_dir: Path = Path("logs"),
    subdir: Optional[str] = None,
    prefix: str = ""
) -> Path:
    """
    Standalone function to save an audit record (maintenance style).

    Unlike AuditLogger, this saves a single dict and appends to master log.
    Used by maintenance_mode.py.

    Args:
        audit_data: Complete audit dictionary
        log_dir: Base log directory
        subdir: Optional subdirectory under log_dir
        prefix: Optional filename prefix

    Returns:
        Path to saved audit file
    """
    base_dir = log_dir
    if subdir:
        base_dir = base_dir / subdir
    base_dir.mkdir(parents=True, exist_ok=True)

    timestamp = int(time.time())
    filename = f"{prefix}audit_{timestamp}.json" if prefix else f"audit_{timestamp}.json"
    filepath = base_dir / filename

    with open(filepath, 'w') as f:
        json.dump(audit_data, f, indent=2, default=str)

    # Append to master log
    master_log = log_dir / "audit.log"
    with open(master_log, 'a') as f:
        f.write(json.dumps(audit_data, default=str) + "\n")

    logger.debug(f"Audit record saved: {filepath}")
    return filepath
