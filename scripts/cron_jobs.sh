#!/usr/bin/env bash
# scripts/cron_jobs.sh
# ─────────────────────────────────────────────────────────────────────────────
# Cron runner + installer for Python/Linux scheduled automation jobs.
#
# All jobs use a single dispatch entry point:
#   HPE_AUTO_SOURCE=<jenkins|scheduler|irequest>  python -m automation
#   ──⇨ run_jenkins()   (src/automation/control.py)
#   ──⇨ run_scheduler() (src/automation/control.py)
#   ──⇨ run_irequest()  (src/automation/control.py)
#
# PS equivalent for each surface:
#   surface              PS entry point
#   ───────────────────  ─────────────────────────────────────────────────────────────
#   reporting (cron)     scripts/schedule-jobs.ps1 -Job reporting
#   monitoring (cron)    scripts/schedule-jobs.ps1 -Job monitoring
#   firmware (cron)      scripts/schedule-jobs.ps1 -Job firmware
#   windows (cron)       scripts/schedule-jobs.ps1 -Job windows
#   maintenance          scripts/schedule-jobs.ps1 -Job maintenance_disable <CLUSTER_ID>
#   iRequest (ISAPI)     Run-IRequest  (Control.psm1)
#
# Usage:
#   ./cron_jobs.sh reporting          # run now  (ad-hoc / dev)
#   ./cron_jobs.sh firmware           # run now
#   ./cron_jobs.sh --install-reporting # install cron (daily 02:00)
#   ./cron_jobs.sh --install-all
#   ./cron_jobs.sh --show
#   ./cron_jobs.sh --remove-all
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="${SCRIPT_DIR}/../.venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    VENV_PYTHON="$(command -v python3 || command -v python)"
fi
: "${VENV_PYTHON:=python3}"

CRON_TAG="HPE_AUTO"
LOG_DIR="${SCRIPT_DIR}/../logs/scheduled_jobs"
mkdir -p "$LOG_DIR"

timestamp() { date '+%Y-%m-%dT%H:%M:%S'; }

log() {
    local level="$1"; shift
    local msg="[$(timestamp)] [$level] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_DIR/$(date +%Y-%m-%d).log"
}

# ── Unified automation dispatch ────────────────────────────────────────────────
# Single entry point; dispatches to run_jenkins / run_scheduler / run_irequest
# via src/automation/__main__.py and src/automation/control.py.
# mirrors PS Control.psm1: Run-Jenkins | Run-Scheduler | Run-IRequest

run_automation() {
    local source="$1"; shift
    HPE_AUTO_SOURCE="$source" "$VENV_PYTHON" -m automation "$@"
}

# ── Individual cron jobs ───────────────────────────────────────────────────────

job_reporting() {
    # PS equivalent: Invoke-JobReporting  in scripts/schedule-jobs.ps1
    # Sets BUILD_STAGE=all for full audit + OpsRamp telemetry pipeline
    log INFO "── Reporting job START ──"
    run_automation jenkins  # BUILD_STAGE already defaults to all via stage_map in control.py
    # Override explicitly for clarity (eval-time override uses HPE_AUTO_BUILD_STAGE env var):
    HPE_AUTO_BUILD_STAGE=all run_automation jenkins
    log INFO "── Reporting job END ──"
}

job_monitoring() {
    # PS equivalent: Invoke-JobMonitoring  in scripts/schedule-jobs.ps1
    # Triggered every 5 min — Start-InstallMonitor per server
    log INFO "── Monitoring job START ──"
    HPE_AUTO_BUILD_STAGE=deploy run_automation jenkins
    log INFO "── Monitoring job END ──"
}

job_firmware() {
    # PS equivalent: Invoke-JobFirmware  in scripts/schedule-jobs.ps1
    log INFO "── Firmware build job START ──"
    HPE_AUTO_BUILD_STAGE=firmware run_automation jenkins
    log INFO "── Firmware build job END ──"
}

job_windows() {
    # PS equivalent: Invoke-JobWindows  in scripts/schedule-jobs.ps1
    log INFO "── Windows patch job START ──"
    HPE_AUTO_BUILD_STAGE=windows run_automation jenkins
    log INFO "── Windows patch job END ──"
}

job_irequest() {
    # PS equivalent: Invoke-JobIRequest  in scripts/schedule-jobs.ps1 / Control.psm1 Run-IRequest
    local cluster_id="${1:-}"
    [ -z "$cluster_id" ] && { log ERROR "CLUSTER_ID required"; exit 1; }
    log INFO "── iRequest for cluster '$cluster_id' START ──"
    HPE_AUTO_SOURCE=irequest HPE_AUTO_IRREQUEST_CLUSTER_ID="$cluster_id" run_automation irequest
    log INFO "── iRequest END ──"
}

job_maintenance_disable() {
    # PS equivalent: Invoke-JobMaintenanceDisable  in scripts/schedule-jobs.ps1
    local cluster_id="${1:-}"
    [ -z "$cluster_id" ] && { log ERROR "CLUSTER_ID required"; exit 1; }
    log INFO "── Maintenance disable for '$cluster_id' START ──"
    HPE_AUTO_SOURCE=scheduler \
        HPE_AUTO_TASK=maintenance_disable \
        HPE_AUTO_MAINT_DISABLE_CLUSTER_ID="$cluster_id" \
        run_automation scheduler
    log INFO "── Maintenance disable END ──"
}

# ── Dispatch ────────────────────────────────────────────────────────────────────

job="${1:-}"

case "$job" in
    reporting)         job_reporting ;;
    monitoring)        job_monitoring ;;
    firmware)          job_firmware ;;
    windows)           job_windows ;;
    irequest)
        job_irequest "${2:-}"
        ;;
    maintenance_disable)
        job_maintenance_disable "${2:-}"
        ;;
    all)  job_reporting; job_monitoring ;;

    # ── Cron installer ──────────────────────────────────────────────────────────
    --install-reporting)
        CRON_LINE="0 2 * * *  cd '${SCRIPT_DIR}/..' && HPE_AUTO_SOURCE=jenkins HPE_AUTO_BUILD_STAGE=all '${VENV_PYTHON}' -m automation >> '${LOG_DIR}/reporting.log' 2>&1 # ${CRON_TAG}-reporting"
        (crontab -l 2>/dev/null | grep -v "^# ${CRON_TAG}-reporting$"; echo "$CRON_LINE") | crontab -
        log INFO "Installed reporting cron (daily 02:00)"
        ;;
    --install-monitoring)
        CRON_LINE="*/5 * * * * cd '${SCRIPT_DIR}/..' && HPE_AUTO_SOURCE=jenkins HPE_AUTO_BUILD_STAGE=deploy '${VENV_PYTHON}' -m automation >> '${LOG_DIR}/monitoring.log' 2>&1 # ${CRON_TAG}-monitoring"
        (crontab -l 2>/dev/null | grep -v "^# ${CRON_TAG}-monitoring$"; echo "$CRON_LINE") | crontab -
        log INFO "Installed monitoring cron (every 5 min)"
        ;;
    --install-firmware)
        CRON_LINE="0 3 * * 0  cd '${SCRIPT_DIR}/..' && HPE_AUTO_SOURCE=jenkins HPE_AUTO_BUILD_STAGE=firmware '${VENV_PYTHON}' -m automation >> '${LOG_DIR}/firmware.log' 2>&1 # ${CRON_TAG}-firmware"
        (crontab -l 2>/dev/null | grep -v "^# ${CRON_TAG}-firmware$"; echo "$CRON_LINE") | crontab -
        log INFO "Installed firmware cron (Sun 03:00)"
        ;;
    --install-windows)
        CRON_LINE="0 4 * * 0  cd '${SCRIPT_DIR}/..' && HPE_AUTO_SOURCE=jenkins HPE_AUTO_BUILD_STAGE=windows '${VENV_PYTHON}' -m automation >> '${LOG_DIR}/windows.log' 2>&1 # ${CRON_TAG}-windows"
        (crontab -l 2>/dev/null | grep -v "^# ${CRON_TAG}-windows$"; echo "$CRON_LINE") | crontab -
        log INFO "Installed Windows patch cron (Sun 04:00)"
        ;;
    --install-all)
        "$0" --install-reporting
        "$0" --install-monitoring
        "$0" --install-firmware
        "$0" --install-windows
        log INFO "All cron jobs installed."
        ;;
    --show)
        log INFO "Active HPE automation cron entries:"
        crontab -l 2>/dev/null | grep "HPE_AUTO" || echo "  (none)"
        ;;
    --remove-all)
        (crontab -l 2>/dev/null | grep -v "^# ${CRON_TAG}") | crontab -
        log INFO "All HPE_AUTO cron entries removed."
        ;;
    *)
        echo "usage: $0 <job|--install-*|--show|--remove-all>"
        echo "  jobs:       reporting  monitoring  firmware  windows"
        echo "              irequest CLUSTER_ID  maintenance_disable CLUSTER_ID"
        echo "  installer:  --install-reporting --install-monitoring"
        echo "              --install-firmware --install-windows --install-all"
        echo "  info:       --show --remove-all"
        exit 1 ;;
esac

exit 0
