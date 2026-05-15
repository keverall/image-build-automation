"""Configuration file loading utilities."""

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def load_json_config(
    path: Path,
    required: bool = True,
    auto_env_var_replace: bool = True
) -> dict[str, Any]:
    """
    Load a JSON configuration file with consistent error handling.

    Args:
        path: Path to JSON config file
        required: If True, raise FileNotFoundError when file is missing
        auto_env_var_replace: If True, replace ${VAR} placeholders with environment variables

    Returns:
        Config dictionary (empty if not required and file missing)

    Raises:
        FileNotFoundError: If required=True and file does not exist
        json.JSONDecodeError: If file contains invalid JSON
    """
    try:
        with open(path) as f:
            config = json.load(f)

        if auto_env_var_replace:
            config = _replace_env_vars(config)

        logger.debug(f"Loaded configuration from {path}")
        return config

    except FileNotFoundError:
        if required:
            logger.error(f"Configuration file not found: {path}")
            raise
        else:
            logger.warning(f"Configuration file not found (optional): {path}")
            return {}

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in configuration file {path}: {e}")
        raise


def load_yaml_config(path: Path, required: bool = True) -> dict[str, Any]:
    """
    Load a YAML configuration file (if PyYAML is available).

    Args:
        path: Path to YAML config file
        required: If True, raise FileNotFoundError when file is missing

    Returns:
        Config dictionary

    Raises:
        ImportError: If PyYAML is not installed
        FileNotFoundError: If required=True and file missing
    """
    try:
        import yaml
    except ImportError:
        logger.error("PyYAML is required to load YAML config files")
        raise

    try:
        with open(path) as f:
            config = yaml.safe_load(f)
        logger.debug(f"Loaded YAML configuration from {path}")
        return config or {}
    except FileNotFoundError:
        if required:
            logger.error(f"Configuration file not found: {path}")
            raise
        return {}


def _replace_env_vars(config: dict[str, Any]) -> dict[str, Any]:
    """
    Recursively replace ${VAR} placeholders in config values with environment variables.

    Supports nested dicts and lists.
    """
    import os
    import re

    pattern = re.compile(r'\$\{([^}]+)\}')

    def replace_value(value):
        if isinstance(value, str):
            return pattern.sub(lambda m: os.environ.get(m.group(1), m.group(0)), value)
        elif isinstance(value, dict):
            return {k: replace_value(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [replace_value(item) for item in value]
        else:
            return value

    return replace_value(config)
