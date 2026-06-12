#!/usr/bin/env bash
# =============================================================================
# Install checkmake for Makefile linting
# =============================================================================
# Downloads and installs checkmake from GitHub releases for offline use.
# Falls back to system package manager if download fails.
# =============================================================================

set -euo pipefail

CHECKMAKE_VERSION="0.2.2"
CHECKMAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$CHECKMAKE_DIR/bin"
CHECKMAKE_BIN="$BIN_DIR/checkmake"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}[checkmake]${NC} Installing checkmake v$CHECKMAKE_VERSION..."

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Check if already installed
if [ -f "$CHECKMAKE_BIN" ]; then
    CURRENT_VERSION=$("$CHECKMAKE_BIN" --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}[checkmake]${NC} Already installed: $CURRENT_VERSION"
    exit 0
fi

# Determine platform
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    i386|i686) ARCH="386" ;;
esac

# Download URL
URL="https://github.com/mrtazz/checkmake/releases/download/$CHECKMAKE_VERSION/checkmake-$CHECKMAKE_VERSION.$PLATFORM.$ARCH"

# Try to download from GitHub
echo -e "${CYAN}[checkmake]${NC} Downloading from GitHub..."
if curl -fsSL -o "$CHECKMAKE_BIN" "$URL" 2>/dev/null; then
    chmod +x "$CHECKMAKE_BIN"
    echo -e "${GREEN}[checkmake]${NC} Installed successfully to $CHECKMAKE_BIN"
    exit 0
fi

# Fallback: try system package manager
echo -e "${YELLOW}[checkmake]${NC} GitHub download failed, trying package manager..."

if command -v brew &>/dev/null; then
    echo -e "${CYAN}[checkmake]${NC} Installing via Homebrew..."
    brew install checkmake 2>/dev/null && {
        echo -e "${GREEN}[checkmake]${NC} Installed via Homebrew"
        exit 0
    }
elif command -v apt-get &>/dev/null; then
    echo -e "${CYAN}[checkmake]${NC} Installing via apt-get..."
    # checkmake not in default repos, need to build from source or use Go
    if command -v go &>/dev/null; then
        echo -e "${CYAN}[checkmake]${NC} Building from source with Go..."
        go install "github.com/mrtazz/checkmake@v$CHECKMAKE_VERSION" 2>/dev/null && {
            # Go installs to GOPATH/bin or ~/go/bin
            GO_BIN="${GOPATH:-$HOME/go}/bin/checkmake"
            if [ -f "$GO_BIN" ]; then
                cp "$GO_BIN" "$CHECKMAKE_BIN"
                echo -e "${GREEN}[checkmake]${NC} Built and installed from source"
                exit 0
            fi
        }
    fi
elif command -v yum &>/dev/null; then
    echo -e "${YELLOW}[checkmake]${NC} yum detected, trying to build from source..."
    if command -v go &>/dev/null; then
        go install "github.com/mrtazz/checkmake@v$CHECKMAKE_VERSION" 2>/dev/null && {
            GO_BIN="${GOPATH:-$HOME/go}/bin/checkmake"
            if [ -f "$GO_BIN" ]; then
                cp "$GO_BIN" "$CHECKMAKE_BIN"
                echo -e "${GREEN}[checkmake]${NC} Built and installed from source"
                exit 0
            fi
        }
    fi
fi

# Last resort: inform user
echo -e "${RED}[checkmake]${NC} Failed to install checkmake automatically."
echo -e "${YELLOW}[checkmake]${NC} You can:"
echo -e "  1. Manually download from: https://github.com/mrtazz/checkmake/releases"
echo -e "  2. Place it in: $CHECKMAKE_BIN"
echo -e "  3. Or install via: brew install checkmake"
echo -e "  4. Or build from source: go install github.com/mrtazz/checkmake@v$CHECKMAKE_VERSION"
exit 1
