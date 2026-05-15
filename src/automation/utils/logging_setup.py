"""Centralized logging configuration for automation scripts.

Provides init_logging() to configure root logger with console and optional file handler.
"""

import logging
import sys
from pathlib import Path
from typing import Optional


def init_logging(log_file: Optional[str] = None, level: int = logging.INFO) -> None:
    """Configure root logger with console and optional file output.

    Args:
        log_file: Optional log filename (stored under logs/ directory).
        level: Logging level (default: logging.INFO).

    Raises:
        OSError: If log directory cannot be created.
    """
    root = logging.getLogger()
    root.setLevel(level)

    if root.hasHandlers():
        root.handlers.clear()

    formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    root.addHandler(console_handler)

    if log_file:
        log_path = Path("logs") / log_file
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_path, mode="a")
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)


def get_logger(name: str) -> logging.Logger:
    """Get a named logger that propagates to the configured root.

    Args:
        name: Logger name (usually __name__ or class name).

    Returns:
        Logger instance.
    """
    return logging.getLogger(name)
