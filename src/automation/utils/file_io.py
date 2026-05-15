"""File I/O utilities for JSON persistence and directory management."""

import json
import logging
import time
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)


def ensure_dir(path: Path) -> Path:
    """
    Ensure a directory exists, creating it if necessary.

    Args:
        path: Directory path

    Returns:
        The same path (for chaining)
    """
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_json(data: dict[str, Any], path: Path, indent: int = 2) -> Path:
    """
    Save dictionary to JSON file atomically.

    Args:
        data: Data to save
        path: Target file path
        indent: JSON indentation level

    Returns:
        Path to saved file
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=indent, default=str)
    logger.debug(f"Saved JSON to {path}")
    return path


def load_json(path: Path, required: bool = True) -> dict[str, Any]:
    """
    Load JSON from file.

    Args:
        path: Path to JSON file
        required: If True, raise error when missing

    Returns:
        Parsed dictionary

    Raises:
        FileNotFoundError: If required=True and file missing
    """
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        if required:
            logger.error(f"Required JSON file not found: {path}")
            raise
        return {}


def save_result_json(
    data: dict[str, Any], base_name: str, output_dir: Path = Path("logs"), category: Optional[str] = None
) -> Path:
    """
    Save result JSON with standardized naming.

    Creates filename: <category>/<base_name>_<timestamp>.json or <base_name>_<timestamp>.json

    Args:
        data: Result data
        base_name: Base filename (e.g., 'build_result', 'deploy_log')
        output_dir: Root output directory
        category: Optional subdirectory category

    Returns:
        Path to saved file
    """
    timestamp = int(time.time())
    if category:
        output_dir = output_dir / category
    ensure_dir(output_dir)

    filename = f"{base_name}_{timestamp}.json"
    filepath = output_dir / filename
    return save_json(data, filepath)
