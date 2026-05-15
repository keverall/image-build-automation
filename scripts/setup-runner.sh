#!/usr/bin/env bash
# =============================================================================
# HPE ProLiant Windows Server ISO Automation — Jenkins Runner Setup Script
# =============================================================================
# Installs Python 3.14 (via uv), all dependencies, and CI/CD tooling.
# Designed for: Azure/AWS Linux runners, VDI build jumpboxes, POC environments.
# Eventually compatible with BMS GitStash/GitLab container runners.
#
# Usage:
#   curl -sSL https://.../scripts/setup-runner.sh | bash
#   # or locally:
#   chmod +x scripts/setup-runner.sh && ./scripts/setup-runner.sh
#
# After setup, activate the environment:
#   source .venv/bin/activate
# =============================================================================

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
PYTHON_VERSION="3.14"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/.venv"
LOG_FILE="/tmp/hpe-automation-runner-setup-$(date +%Y%m%d-%H%M%S).log"
GITLEAKS_VERSION="8.21.2"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Helper Functions ────────────────────────────────────────────────────────
log() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2; }

check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Consider using a dedicated service account for Jenkins runners."
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="${ID,,}"
        OS_VERSION="${VERSION_ID:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME="rhel"
        OS_VERSION=$(grep -oP '\d+\.\d+' /etc/redhat-release || echo "unknown")
    else
        OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_VERSION="unknown"
    fi
    log "Detected OS: ${OS_NAME} ${OS_VERSION}"
}

install_system_deps() {
    log "Installing system dependencies..."
    case "${OS_NAME}" in
        ubuntu|debian)
            apt-get update -qq 2>/dev/null | tee -a "$LOG_FILE"
            apt-get install -y --no-install-recommends \
                curl wget git build-essential libssl-dev zlib1g-dev \
                libbz2-dev libreadline-dev libsqlite3-dev libffi-dev \
                liblzma-dev pkg-config 2>&1 | tee -a "$LOG_FILE"
            ;;
        amzn|amazon|rhel|centos|rocky|almalinux)
            if command -v dnf &>/dev/null; then
                dnf install -y curl wget git gcc make openssl-devel \
                    bzip2-devel readline-devel sqlite-devel libffi-devel \
                    xz-devel pkgconfig 2>&1 | tee -a "$LOG_FILE"
            else
                yum install -y curl wget git gcc make openssl-devel \
                    bzip2-devel readline-devel sqlite-devel libffi-devel \
                    xz-devel pkgconfig 2>&1 | tee -a "$LOG_FILE"
            fi
            ;;
        alpine)
            apk add --no-cache curl wget git build-base openssl-dev \
                bzip2-dev readline-dev sqlite-dev libffi-dev xz-dev pkgconfig 2>&1 | tee -a "$LOG_FILE"
            ;;
        *)
            warn "Unknown OS (${OS_NAME}). Skipping system dependency installation."
            warn "Ensure curl, wget, git, gcc, and make are installed manually."
            ;;
    esac
    success "System dependencies installed"
}

install_uv() {
    if command -v uv &>/dev/null; then
        UV_VERSION=$(uv --version 2>/dev/null || echo "unknown")
        log "uv already installed: ${UV_VERSION}"
        success "uv is available"
        return 0
    fi
    log "Installing uv (fast Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>&1 | tee -a "$LOG_FILE"
    export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"
    if command -v uv &>/dev/null; then
        UV_VERSION=$(uv --version 2>/dev/null || echo "unknown")
        success "uv installed: ${UV_VERSION}"
    else
        error "uv installation failed. Check ${LOG_FILE} for details."
        exit 1
    fi
}

install_python() {
    if uv python list --only-installed 2>/dev/null | grep -q "cpython-${PYTHON_VERSION}"; then
        log "Python ${PYTHON_VERSION} already installed via uv"
        success "Python ${PYTHON_VERSION} available"
        return 0
    fi
    log "Installing Python ${PYTHON_VERSION} via uv..."
    uv python install "${PYTHON_VERSION}" 2>&1 | tee -a "$LOG_FILE"
    if uv python list --only-installed 2>/dev/null | grep -q "cpython-${PYTHON_VERSION}"; then
        success "Python ${PYTHON_VERSION} installed"
    else
        error "Python ${PYTHON_VERSION} installation failed. Check ${LOG_FILE} for details."
        exit 1
    fi
}

create_venv() {
    if [[ -d "${VENV_DIR}" ]] && [[ -f "${VENV_DIR}/bin/python" ]]; then
        CURRENT_PY=$("${VENV_DIR}/bin/python" --version 2>/dev/null || echo "unknown")
        log "Virtual environment exists: ${CURRENT_PY}"
        success "Virtual environment ready at ${VENV_DIR}"
        return 0
    fi
    log "Creating virtual environment with Python ${PYTHON_VERSION}..."
    uv venv "${VENV_DIR}" --python "${PYTHON_VERSION}" 2>&1 | tee -a "$LOG_FILE"
    if [[ -f "${VENV_DIR}/bin/python" ]]; then
        VENV_PY=$("${VENV_DIR}/bin/python" --version 2>/dev/null || echo "unknown")
        success "Virtual environment created: ${VENV_PY} at ${VENV_DIR}"
    else
        error "Virtual environment creation failed."
        exit 1
    fi
}

install_python_deps() {
    log "Installing Python dependencies..."
    export UV_PROJECT_ENVIRONMENT="${VENV_DIR}"

    log "Installing runtime dependencies (requirements.txt)..."
    uv pip install -r "${PROJECT_ROOT}/requirements.txt" \
        --python "${VENV_DIR}/bin/python" 2>&1 | tee -a "$LOG_FILE"
    success "Runtime dependencies installed"

    log "Installing dev dependencies (ruff, radon, bandit, safety, mypy, pytest)..."
    uv pip install \
        "ruff>=0.6.0" \
        "radon>=6.0.0" \
        "bandit>=1.7.0" \
        "safety>=3.0.0" \
        "mypy>=1.0" \
        "pytest>=7.0" \
        "pytest-cov>=4.0" \
        --python "${VENV_DIR}/bin/python" 2>&1 | tee -a "$LOG_FILE"
    success "Dev dependencies installed"

    log "Installing automation package in editable mode..."
    uv pip install -e "${PROJECT_ROOT}" \
        --python "${VENV_DIR}/bin/python" 2>&1 | tee -a "$LOG_FILE"
    success "Automation package installed (editable)"
}

install_gitleaks() {
    if command -v gitleaks &>/dev/null; then
        GL_VERSION=$(gitleaks version 2>/dev/null || echo "unknown")
        log "gitleaks already installed: ${GL_VERSION}"
        success "gitleaks is available"
        return 0
    fi
    log "Installing gitleaks (secret detection)..."
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)  GL_ARCH="x64" ;;
        aarch64) GL_ARCH="arm64" ;;
        *)       GL_ARCH="${ARCH}" ;;
    esac
    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    GL_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${OS_TYPE}_${GL_ARCH}.tar.gz"
    GL_TMP=$(mktemp -d)
    curl -sSL "${GL_URL}" -o "${GL_TMP}/gitleaks.tar.gz" 2>&1 | tee -a "$LOG_FILE"
    tar -xzf "${GL_TMP}/gitleaks.tar.gz" -C "${GL_TMP}" 2>&1 | tee -a "$LOG_FILE"
    if [[ -w /usr/local/bin ]]; then
        mv "${GL_TMP}/gitleaks" /usr/local/bin/gitleaks
        chmod +x /usr/local/bin/gitleaks
    else
        mkdir -p "${HOME}/.local/bin"
        mv "${GL_TMP}/gitleaks" "${HOME}/.local/bin/gitleaks"
        chmod +x "${HOME}/.local/bin/gitleaks"
        export PATH="${HOME}/.local/bin:${PATH}"
    fi
    rm -rf "${GL_TMP}"
    if command -v gitleaks &>/dev/null; then
        GL_VERSION=$(gitleaks version 2>/dev/null || echo "installed")
        success "gitleaks installed: ${GL_VERSION}"
    else
        warn "gitleaks binary installed but not in PATH. Add to PATH manually."
    fi
}

verify_installation() {
    log "Verifying installation..."
    source "${VENV_DIR}/bin/activate"
    local PASS=0 FAIL=0
    check_tool() {
        local tool=$1 version_cmd=$2
        if command -v "${tool}" &>/dev/null; then
            VERSION=$(${version_cmd} 2>/dev/null || echo "installed")
            success "${tool}: ${VERSION}"
            ((PASS++))
        else
            error "${tool}: NOT FOUND"
            ((FAIL++))
        fi
    }
    check_tool "python" "python --version"
    check_tool "pip" "pip --version"
    check_tool "uv" "uv --version"
    check_tool "git" "git --version"
    check_tool "ruff" "ruff --version"
    check_tool "radon" "radon --version"
    check_tool "bandit" "bandit --version"
    check_tool "safety" "safety --version"
    check_tool "mypy" "mypy --version"
    check_tool "pytest" "pytest --version"
    check_tool "gitleaks" "gitleaks version"
    log "Verifying automation package import..."
    if python -c "import automation; print(f'  automation package: {automation.__version__}')" 2>/dev/null; then
        success "automation package importable"
        ((PASS++))
    else
        error "automation package NOT importable"
        ((FAIL++))
    fi
    log "Running quick lint check..."
    if ruff check "${PROJECT_ROOT}/src/automation" --output-format=concise 2>&1 | tee -a "$LOG_FILE"; then
        success "Lint check passed"
        ((PASS++))
    else
        warn "Lint check found issues (review ${LOG_FILE})"
    fi
    log "Verifying test discovery..."
    TEST_COUNT=$(python -m pytest --collect-only -q 2>/dev/null | tail -1 | grep -oP '\d+ tests?' || echo "unknown")
    success "Test discovery: ${TEST_COUNT}"
    echo ""
    log "Verification complete: ${PASS} passed, ${FAIL} failed"
    [[ ${FAIL} -gt 0 ]] && warn "Some tools failed verification. Check ${LOG_FILE} for details."
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}HPE ProLiant ISO Automation — Runner Setup Complete${NC}   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Virtual environment: ${VENV_DIR}"
    echo "  Python:              Python ${PYTHON_VERSION} (uv managed)"
    echo "  Log file:            ${LOG_FILE}"
    echo ""
    echo -e "  ${YELLOW}To activate the environment:${NC}"
    echo "    source ${VENV_DIR}/bin/activate"
    echo ""
    echo -e "  ${YELLOW}To run the full test suite:${NC}"
    echo "    source ${VENV_DIR}/bin/activate"
    echo "    pytest -v --cov=automation"
    echo ""
    echo -e "  ${YELLOW}To run lint checks:${NC}"
    echo "    source ${VENV_DIR}/bin/activate"
    echo "    ruff check src/automation/ --fix"
    echo ""
    echo -e "  ${YELLOW}To run security scans:${NC}"
    echo "    source ${VENV_DIR}/bin/activate"
    echo "    bandit -r src/automation/"
    echo "    safety check"
    echo "    gitleaks detect --source=."
    echo ""
    echo -e "  ${CYAN}Jenkins Pipeline Integration:${NC}"
    echo "    Add to your Jenkinsfile Setup stage:"
    echo "    stage('Setup') {"
    echo "        steps {"
    echo "            sh '''"
    echo "                source ${VENV_DIR}/bin/activate"
    echo "                python -m pip install -e ."
    echo "            '''"
    echo "        }"
    echo "    }"
    echo ""
}

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  HPE ProLiant ISO Automation — Runner Setup         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    check_root
    detect_os
    log "Log file: ${LOG_FILE}"
    install_system_deps
    install_uv
    install_python
    create_venv
    install_python_deps
    install_gitleaks
    verify_installation
    print_summary
    success "Setup complete!"
}

main "$@"
