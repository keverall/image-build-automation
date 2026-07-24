# Checkmake Integration

<a id="top"></a>
## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
  - [Run checkmake only:](#run-checkmake-only)
  - [Run as part of full linting:](#run-as-part-of-full-linting)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
  - [Checkmake hangs](#checkmake-hangs)
  - [Checkmake not found](#checkmake-not-found)
  - [Checkmake finds violations](#checkmake-finds-violations)
- [Configuration](#configuration)
<a name="overview"></a>
## Overview
Checkmake has been integrated into the build system to validate Makefile syntax and best practices.

<a name="installation"></a>
## Installation
Checkmake is automatically installed during `make setup`:
```bash
make setup
```

Or manually via the setup script:
```powershell
pwsh -File scripts/setup-runner.ps1
```

<a name="usage"></a>
## Usage

<a name="run-checkmake-only"></a>
### Run checkmake only:
```bash
make lint-checkmake
```

<a name="run-as-part-of-full-linting"></a>
### Run as part of full linting:
```bash
make lint
```

This runs:
- `lint-make` - Makefile syntax checking
- `lint-checkmake` - Makefile best practices validation
- `pwsh-lint` - PowerShell PSScriptAnalyzer

<a name="how-it-works"></a>
## How It Works

1. **Setup**: `scripts/setup-runner.ps1` downloads checkmake from GitHub releases based on OS/architecture
2. **Fallback**: If GitHub download fails, tries package managers (brew, apt-get with Go)
3. **Installation**: Places binary in `bin/checkmake` for offline use
4. **Validation**: `make lint-checkmake` runs checkmake with a 5-second timeout

<a name="troubleshooting"></a>
## Troubleshooting

<a name="checkmake-hangs"></a>
### Checkmake hangs
The lint-checkmake target has a built-in 5-second timeout. If it times out, it silently continues.

<a name="checkmake-not-found"></a>
### Checkmake not found
Install manually:
```bash
# Via Homebrew (macOS)
brew install checkmake

# Via Go
go install github.com/mrtazz/checkmake@latest

# Via the setup script
pwsh -File scripts/setup-runner.ps1
```

<a name="checkmake-finds-violations"></a>
### Checkmake finds violations
Run with verbose output to see details:
```bash
checkmake Makefile
```

Common violations:
- `maxbodylength`: Target body exceeds 5 lines
- `phony`: Missing .PHONY declaration
- `double-colon`: Using double colon rules

<a name="configuration"></a>
## Configuration
Checkmake uses default rules. To customize, create a `.checkmake` file in the project root.
