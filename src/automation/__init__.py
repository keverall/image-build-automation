"""
HPE ProLiant Windows Server ISO Automation.

A comprehensive automation suite for building customized Windows Server
installation ISOs tailored for HPE ProLiant hardware. Integrates firmware/
driver updates, security patching, vulnerability scanning, complete audit
trails, OpsRamp monitoring, and SCOM/iLO/OpenView maintenance orchestration.

Subpackages:
    - cli: Command-line entry points (build_iso, deploy, monitor, etc.)
    - utils: Shared utilities (logging, config, audit, credentials, etc.)
"""

from . import cli, core, utils

__version__ = "1.0.0"
__author__ = "Kev Everall"

__all__ = [
    "cli",
    "control",
    "core",
    "core",
    "utils",
]
