"""
__main__.py — CLI entry-point for 'python -m automation'.

Dispatches to:
    Source                 Env variable                      Python call path
    ─────────────────────  ───────────────────────────────  ──────────────────────────────────────
    Jenkins / cron         HPE_AUTO_SOURCE=jenkins            run_jenkins(params)
    iRequest / ISAPI form  HPE_AUTO_SOURCE=irequest           run_irequest(form_data)
    Windows Task Scheduler HPE_AUTO_SOURCE=scheduler          run_scheduler(task_params)
"""

# ── stdlib imports first (no dependency on sys.path) ─────────────────────────
import json
import os
import sys

# ── sys.path fix: must run BEFORE any relative / package imports so that this
#    file works when invoked directly (e.g. cron, where PYTHONPATH is absent).
#    Placed after the stdlib imports above because those are always on sys.path.
_src = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _src not in sys.path:
    sys.path.insert(0, _src)
del _src

from automation.control import run_irequest, run_jenkins, run_scheduler  # noqa: E402


def main() -> None:
    source = os.environ.get("HPE_AUTO_SOURCE", "jenkins")

    if source == "jenkins":
        params = {
            "BUILD_STAGE": os.environ.get("HPE_AUTO_BUILD_STAGE", os.environ.get("BUILD_STAGE", "all")),
            "BASE_ISO_PATH": os.environ.get("BASE_ISO_PATH", ""),
            "SERVER_FILTER": os.environ.get("SERVER_FILTER", ""),
            "DEPLOY_METHOD": os.environ.get("DEPLOY_METHOD", "ilo"),
            "SKIP_DOWNLOAD": os.environ.get("SKIP_DOWNLOAD", "false").lower() == "true",
            "DRY_RUN": os.environ.get("DRY_RUN", "false").lower() == "true",
        }
        result = run_jenkins(params)

    elif source == "scheduler":
        task_params = {
            "task": os.environ.get("HPE_AUTO_TASK", "maintenance_disable"),
            "cluster_id": os.environ.get("HPE_AUTO_MAINT_DISABLE_CLUSTER_ID", ""),
            "dry_run": os.environ.get("DRY_RUN", "false").lower() == "true",
        }
        result = run_scheduler(task_params)

    elif source == "irequest":
        form_data = {
            "cluster_id": os.environ.get("HPE_AUTO_IRREQUEST_CLUSTER_ID", ""),
            "action": os.environ.get("HPE_AUTO_IRREQUEST_ACTION", "enable"),
            "start": os.environ.get("HPE_AUTO_IRREQUEST_START", "now"),
            "end": os.environ.get("HPE_AUTO_IRREQUEST_END", None),
            "dry_run": os.environ.get("DRY_RUN", "false").lower() == "true",
        }
        result = run_irequest(form_data)

    else:
        print(f"Unknown HPE_AUTO_SOURCE: {source}", file=sys.stderr)
        print("Valid sources: jenkins, scheduler, irequest", file=sys.stderr)
        sys.exit(1)

    json.dump(result, sys.stdout, indent=2, default=str)
    print()
    sys.exit(0 if result.get("success") else 1)


if __name__ == "__main__":
    main()
