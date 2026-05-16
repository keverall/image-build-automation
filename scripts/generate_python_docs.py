#!/usr/bin/env python3
"""
scripts/generate_python_docs.py
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auto-generate Markdown API reference docs for every Python CLI entry-point
defined in pyproject.toml [project.scripts].

Strategy
────────
For each console_scripts entry the script:
  1. Imports the module (no execution — argparse is only invoked on --help).
  2. Locates the `main()` function callable.
  3. Captures both:
       • the module / function docstring (rendered as prose)
       • the `--help` output rendered by argparse (rendered as a fenced code block)
  4. Writes a Markdown file:
       docs/python/generated/<console_script_name>.md
  5. Builds / refreshes docs/python/generated/INDEX.md.

Usage
─────
  uv run python scripts/generate_python_docs.py
  uv run python scripts/generate_python_docs.py --force      # overwrite existing .md files
  uv run python scripts/generate_python_docs.py --output docs/custom

Prerequisites
─────────────
  pip install -e .   (project must be on sys.path with its dependencies)

Jenkins
───────
  sh '''
    python3 scripts/generate_python_docs.py --force
  '''
  archiveArtifacts artifacts: 'docs/python/generated/**'
"""

from __future__ import annotations

import argparse
import importlib
import io
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Config ─────────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SRC_ROOT = PROJECT_ROOT / "src"
DOCS_OUTPUT_DIR = PROJECT_ROOT / "docs" / "python" / "generated"
DOCS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Mirror [project.scripts] from pyproject.toml — single source of truth.
CONSOLE_SCRIPTS: dict[str, str] = {
    "build-iso": "automation.cli.build_iso:main",
    "update-firmware": "automation.cli.update_firmware_drivers:main",
    "patch-windows": "automation.cli.patch_windows_security:main",
    "deploy-server": "automation.cli.deploy_to_server:main",
    "monitor-install": "automation.cli.monitor_install:main",
    "opsramp": "automation.cli.opsramp_integration:main",
    "maintenance-mode": "automation.cli.maintenance_mode:main",
    "generate-uuid": "automation.cli.generate_uuid:main",
}


# ── Data model ────────────────────────────────────────────────────────────────
@dataclass
class CmdDoc:
    """Structured doc for one console-script command."""

    script_name: str
    module_path: str
    function_name: str
    docstring: str | None
    help_text: str
    args: list[dict[str, Any]] = field(default_factory=list)
    raw_help: str = ""


# ── Helpers ───────────────────────────────────────────────────────────────────
def load_callable(dotted: str) -> tuple[Any, str]:
    """Import a module and return (callable, module_path)."""
    module_path, _, func_name = dotted.partition(":")
    mod = importlib.import_module(module_path)
    fn = getattr(mod, func_name)
    return fn, module_path


def capture_help(fn: Any) -> str:
    """Run the argparse-based CLI with --help and capture stdout."""
    # Backup real sys.{stdout,argv,exit}
    _old_stdout = sys.stdout
    _old_argv = sys.argv[:]
    _old_exit = sys.exit

    captured = io.StringIO()
    sys.stdout = captured
    # Put a harmless --help in argv so argparse prints help and then SystemExit
    sys.argv = ["", "--help"]

    try:
        fn()
    except SystemExit:
        pass
    finally:
        sys.stdout = _old_stdout
        sys.argv = _old_argv
        sys.exit = _old_exit  # type: ignore[assignment]

    return captured.getvalue()


def extract_args_from_help(help_text: str) -> list[dict[str, Any]]:
    """Parse argparse --help output and return a list of argument descriptors."""
    args: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line in help_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        # Positional or optional argument line
        if stripped.startswith("-") or stripped[0].isalnum():
            # Reset current on a new arg line
            if stripped.split()[0].startswith("-") or (not stripped.startswith(" ") and not stripped.startswith("{")):
                if current:
                    args.append(current)
                current = {"raw": stripped}
            elif current and stripped.startswith(" "):
                current.setdefault("help_lines", []).append(stripped.strip())
        elif stripped.startswith("{") and current:
            current.setdefault("choices", stripped.strip("{} "))
    if current:
        args.append(current)
    return args


def fmt_arg_block(args: list[dict[str, Any]]) -> str:
    """Format parsed arguments as a Markdown description list."""
    lines = ["", "**Arguments**", ""]
    for a in args:
        name = a.get("raw", "").split()[0] if a.get("raw") else ""
        help_text = " ".join(a.get("help_lines", []))
        if help_text:
            lines.append(f"- `{name}` — {help_text}")
        else:
            lines.append(f"- `{name}`")
    return "\n".join(lines) + "\n" if args else ""


# ── Core: build Markdown for one command ──────────────────────────────────────
def render_markdown(cmd: CmdDoc) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    sections: list[str] = []

    # ── Front-matter snapshot (--- YAML header) ────────────────────────────────
    sections.append("---")
    sections.append(f"source:      {cmd.module_path}::main()")
    sections.append(f"console_script: {cmd.script_name}")
    sections.append(f"generated:   {ts}")
    sections.append("auto_generated_by: scripts/generate_python_docs.py")
    sections.append("---")
    sections.append("")

    # ── Title ─────────────────────────────────────────────────────────────────
    sections.append(f"# `{cmd.script_name}`")
    sections.append("")

    # ── Module docstring (prose) ───────────────────────────────────────────────
    if cmd.docstring:
        sections.append("## Overview")
        for para in cmd.docstring.strip().splitlines():
            sections.append(para)
        sections.append("")

    # ── Help text in a fenced shell block ─────────────────────────────────────
    sections.append("## Help")
    sections.append("```shell")
    sections.append(cmd.help_text.rstrip())
    sections.append("```")
    sections.append("")

    # ── Arguments table ───────────────────────────────────────────────────────
    if cmd.args:
        sections.append("## Parameters")
        sections.append("")
        for a in cmd.args:
            name = a.get("raw", "").split()[0] if a.get("raw") else ""
            help_ = " ".join(a.get("help_lines", []))
            choices = a.get("choices")
            extra = f"  *(choices: {choices})*" if choices else ""
            desc = f"{help_}{extra}" if help_ else ""
            sections.append(f"| `{name}` | {desc} |")
        sections.append("")

    # ── Footer ────────────────────────────────────────────────────────────────
    sections.append("---")
    sections.append(
        "*This file is auto-generated by `scripts/generate_python_docs.py`. "
        "Do not edit directly — update code or docstrings and re-run.*"
    )
    sections.append("")

    return "\n".join(sections)


# ── Master INDEX.md builder ───────────────────────────────────────────────────
def write_index(files: list[str]) -> None:
    index_path = DOCS_OUTPUT_DIR / "INDEX.md"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        "# Python CLI — Generated API Reference",
        "",
        "> Auto-generated by `scripts/generate_python_docs.py` — do not edit manually.",
        "",
        f"Generated: {ts}",
        "",
        "## Commands",
        "",
    ]
    for fn in sorted(files):
        name = Path(fn).stem
        lines.append(f"- [`{name}`]({fn})")
    lines += ["", "---", ""]
    index_path.write_text("\n".join(lines), encoding="utf-8")


# ── Main ───────────────────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Markdown docs for Python CLIs")
    parser.add_argument("--force", action="store_true", help="Overwrite existing .md files")
    parser.add_argument("--output", type=Path, default=DOCS_OUTPUT_DIR, help="Output directory")
    parser.add_argument("--module-root", type=Path, default=SRC_ROOT, help="Project src/ root")
    args = parser.parse_args()

    output_dir: Path = args.output
    output_dir.mkdir(parents=True, exist_ok=True)

    # Ensure src/ is on sys.path so importlib works from any working directory
    if str(SRC_ROOT) not in sys.path:
        sys.path.insert(0, str(SRC_ROOT))

    generated_files: list[str] = []

    for script_name, dotted_path in sorted(CONSOLE_SCRIPTS.items()):
        out_file = output_dir / f"{script_name}.md"

        if out_file.exists() and not args.force:
            print(f"  [SKIP] {script_name}.md (use --force to overwrite)")
            generated_files.append(out_file.name)
            continue

        print(f"  [GENERATE] {script_name}  ({dotted_path})")

        try:
            fn, module_path = load_callable(dotted_path)
        except Exception as exc:
            print(f"    [FAIL] Import error: {exc}", file=sys.stderr)
            continue

        docstring = (fn.__doc__ or "").strip().splitlines()
        docstr = "\n".join(docstring) if docstring else None

        try:
            help_text = capture_help(fn)
        except Exception as exc:
            print(f"    [FAIL] Could not capture --help: {exc}", file=sys.stderr)
            help_text = f"(error capturing help: {exc})"

        args_info = extract_args_from_help(help_text)

        cmd_doc = CmdDoc(
            script_name=script_name,
            module_path=module_path,
            function_name=dotted_path.partition(":")[2],
            docstring=docstr,
            help_text=help_text,
            args=args_info,
            raw_help=help_text,
        )
        md = render_markdown(cmd_doc)
        out_file.write_text(md, encoding="utf-8")
        generated_files.append(out_file.name)
        print(f"    ✓  {out_file.name}")

    write_index(generated_files)
    print(f"\n[generate_python_docs] {len(generated_files)} file(s) written → {output_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
