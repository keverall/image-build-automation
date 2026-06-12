# Checkmake Integration

## Overview
Checkmake has been integrated into the build system to validate Makefile syntax and best practices.

## Installation
Checkmake is automatically installed during `make setup`:
```bash
make setup
```

Or manually:
```bash
bash scripts/install-checkmake.sh
```

## Usage

### Run checkmake only:
```bash
make lint-checkmake
```

### Run as part of full linting:
```bash
make lint
```

This runs:
- `lint-make` - Makefile syntax checking
- `lint-checkmake` - Makefile best practices validation
- `pwsh-lint` - PowerShell PSScriptAnalyzer

## How It Works

1. **Setup**: `scripts/install-checkmake.sh` downloads checkmake from GitHub releases
2. **Fallback**: If GitHub download fails, tries package managers (brew, apt-get with Go)
3. **Installation**: Places binary in `bin/checkmake` for offline use
4. **Validation**: `make lint-checkmake` runs checkmake with a 5-second timeout

## Troubleshooting

### Checkmake hangs
The lint-checkmake target has a built-in 5-second timeout. If it times out, it silently continues.

### Checkmake not found
Install manually:
```bash
# Via Homebrew (macOS)
brew install checkmake

# Via Go
go install github.com/mrtazz/checkmake@latest

# Via the installer script
bash scripts/install-checkmake.sh
```

### Checkmake finds violations
Run with verbose output to see details:
```bash
checkmake Makefile
```

Common violations:
- `maxbodylength`: Target body exceeds 5 lines
- `phony`: Missing .PHONY declaration
- `double-colon`: Using double colon rules

## Configuration
Checkmake uses default rules. To customize, create a `.checkmake` file in the project root.
