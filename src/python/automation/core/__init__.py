"""
Core control layer for HPE ProLiant Windows Server ISO Automation.

Handles input routing from external callers:
- Jenkins pipeline (parameter-driven builds)
- Windows Task Scheduler (maintenance windows)
- BMC iRequest forms (cluster maintenance requests)

Provides a unified entry point that validates input, routes to the correct
CLI module, and returns standardized results.
"""

from .orchestrator import AutomationOrchestrator
from .router import route_request
from .validators import validate_build_params, validate_cluster_id, validate_server_list

__all__ = [
    "AutomationOrchestrator",
    "route_request",
    "validate_cluster_id",
    "validate_server_list",
    "validate_build_params",
]
