#!/usr/bin/env python3
"""
Backwards-compatible wrapper for patch_windows_security.

This script calls the main entry point from src/automation/cli/patch_windows_security.py.
It works with `pip install -e .` or when run from the project root with
`PYTHONPATH=src` set.

Usage: python scripts/patch_windows_security.py [args...]
Recommended: python -m automation.cli.patch_windows_security [args...]
"""
import sys
from pathlib import Path

# Allow running without package install (fallback for dev environments)
project_root = Path(__file__).resolve().parent.parent
src_path = project_root / 'src'
if src_path.exists() and str(src_path) not in sys.path:
    sys.path.insert(0, str(src_path))

try:
    from automation.cli.patch_windows_security import main
except ImportError as e:
    print(
        f"Error: Cannot import automation.cli.patch_windows_security.\n"
        f"Install the package: pip install -e .\n"
        f"Or set PYTHONPATH=src\n"
        f"Original error: {e}",
        file=sys.stderr
    )
    sys.exit(1)

sys.exit(main())
