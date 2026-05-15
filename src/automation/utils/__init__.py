"""
Shared utilities package for HPE Windows ISO Automation.

Eliminates code duplication across all automation scripts through
centralized logging, configuration loading, audit trails, credential
management, and PowerShell execution helpers.
"""

from .audit import AuditLogger
from .base import AutomationBase
from .config import load_json_config
from .credentials import get_credential, get_ilo_credentials, get_scom_credentials
from .executor import run_command, run_with_retry
from .file_io import ensure_dir, save_json
from .inventory import ServerInfo, load_cluster_catalogue, load_server_list, validate_cluster_definition
from .logging_setup import init_logging
from .powershell import (
    build_scom_connection,
    build_scom_maintenance_script,
    run_powershell,
    run_powershell_winrm,
)

__all__ = [
    "init_logging",
    "load_json_config",
    "load_server_list",
    "load_cluster_catalogue",
    "ServerInfo",
    "validate_cluster_definition",
    "AuditLogger",
    "ensure_dir",
    "save_json",
    "run_command",
    "run_with_retry",
    "get_credential",
    "get_ilo_credentials",
    "get_scom_credentials",
    "run_powershell",
    "run_powershell_winrm",
    "build_scom_connection",
    "build_scom_maintenance_script",
    "AutomationBase",
]
