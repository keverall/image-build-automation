"""
Request routing for external callers.

Maps incoming requests from Jenkins, scheduler, or iRequest forms
to the appropriate automation module and returns standardized results.

Routing is loaded from configs/request_types.json (single source of truth).
"""

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# Load routing from single source of truth
_CONFIG_PATH = Path(__file__).resolve().parents[3] / "configs" / "request_types.json"
with open(_CONFIG_PATH, encoding="utf-8") as f:
    _CFG = json.load(f)

ROUTE_MAP = {
    req: meta["python_module"]
    for req, meta in _CFG["request_types"].items()
}


def route_request(
    request_type: str,
    params: dict[str, Any],
) -> dict[str, Any]:
    """
    Route a request to the appropriate handler.

    Args:
        request_type: One of the known request types (e.g. 'build_iso')
        params: Parameters from caller (Jenkins params, iRequest form fields, etc.)

    Returns:
        Standardized result dict with 'success', 'output', and 'error' keys
    """
    if request_type not in ROUTE_MAP:
        logger.error("Unknown request type: %s", request_type)
        return {
            "success": False,
            "error": f"Unknown request type: {request_type}",
            "available_types": list(ROUTE_MAP.keys()),
        }

    module_name = ROUTE_MAP[request_type]
    logger.info("Routing %s request to %s", request_type, module_name)

    try:
        import importlib

        module = importlib.import_module(module_name)
    except ImportError as e:
        logger.error("Failed to import %s: %s", module_name, e)
        return {
            "success": False,
            "error": f"Module import failed: {e}",
        }

    # Handle maintenance mode specially (needs action param)
    if request_type.startswith("maintenance_"):
        action = request_type.split("_")[1]
        params["action"] = action
        if hasattr(module, "main"):
            # Convert params to sys.argv-style args for the CLI module
            import sys

            original_argv = sys.argv
            sys.argv = ["maintenance_mode.py", "--cluster-id", params.get("cluster_id", "")]
            if action == "enable" and params.get("start"):
                sys.argv.extend(["--start", params["start"]])
            if params.get("end"):
                sys.argv.extend(["--end", params["end"]])
            if params.get("dry_run"):
                sys.argv.append("--dry-run")
            try:
                exit_code = module.main()
                return {
                    "success": exit_code == 0,
                    "exit_code": exit_code,
                }
            except SystemExit as e:
                return {"success": e.code == 0, "exit_code": e.code}
            finally:
                sys.argv = original_argv
        else:
            return {"success": False, "error": "No main() in maintenance module"}

    # Generic routing: call main() if available
    if hasattr(module, "main"):
        try:
            exit_code = module.main()
            return {"success": exit_code == 0, "exit_code": exit_code}
        except SystemExit as e:
            return {"success": e.code == 0, "exit_code": e.code}
        except Exception as e:
            logger.exception("Module %s raised exception", module_name)
            return {"success": False, "error": str(e)}

    return {"success": False, "error": f"No main() in {module_name}"}
