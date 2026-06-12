#!/usr/bin/env bash
# =============================================================================
# Run checkmake to validate Makefile
# =============================================================================

set -euo pipefail

if ! command -v checkmake >/dev/null 2>&1; then
    echo "[checkmake] Not installed (install with: make setup)"
    exit 0
fi

echo "[checkmake] Validating Makefile..."
if timeout 5 checkmake Makefile </dev/null 2>&1; then
    echo "[checkmake] ✓ No issues found"
else
    echo "[checkmake] ⚠ Issues detected (see above)"
fi
