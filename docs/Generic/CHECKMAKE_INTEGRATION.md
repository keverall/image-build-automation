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

<a id="overview"></a>

## Overview

Checkmake validates Makefile syntax and best practices as part of the build system.

<a id="installation"></a>

## Installation

Automatically installed during `make setup`:

```bash
make setup
```

Or via the setup script:

```powershell
pwsh -File scripts/setup-runner.ps1
```

<a id="usage"></a>

## Usage

<a id="run-checkmake-only"></a>

### Run checkmake only:

```bash
make lint-checkmake
```

<a id="run-as-part-of-full-linting"></a>

### Run as part of full linting:

```bash
make lint
```

Runs `lint-make` (Makefile syntax), `lint-checkmake` (best practices), and `pwsh-lint` (PSScriptAnalyzer).

<a id="how-it-works"></a>

## How It Works

1. `scripts/setup-runner.ps1` downloads checkmake from GitHub releases by OS/architecture
2. Falls back to package managers (brew, apt-get with Go) if the download fails
3. Places the binary in `bin/checkmake` for offline use
4. `make lint-checkmake` runs it with a 5-second timeout

<a id="troubleshooting"></a>

## Troubleshooting

<a id="checkmake-hangs"></a>

### Checkmake hangs

The `lint-checkmake` target has a built-in 5-second timeout and silently continues if it times out.

<a id="checkmake-not-found"></a>

### Checkmake not found

```bash
brew install checkmake                              # macOS
go install github.com/mrtazz/checkmake@latest      # Go
pwsh -File scripts/setup-runner.ps1                # setup script
```

<a id="checkmake-finds-violations"></a>

### Checkmake finds violations

```bash
checkmake Makefile
```

Common violations: `maxbodylength` (target body > 5 lines), `phony` (missing `.PHONY`), `double-colon` (double-colon rules).

<a id="configuration"></a>

## Configuration

Checkmake uses default rules. To customize, create a `.checkmake` file in the project root.
