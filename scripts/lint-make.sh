#!/usr/bin/env bash
set -e

if command -v checkmake >/dev/null 2>&1; then
    checkmake Makefile
else
    echo -e "\033[1;33m[lint-make]\033[0m 'checkmake' missing. Running basic syntax check..."
    make --dry-run --quiet help > /dev/null
    echo -e "\033[0;32m[lint-make]\033[0m Makefile syntax OK"
fi
