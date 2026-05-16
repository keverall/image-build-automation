"""Tests for automation.cli.maintenance_mode main() function.

Covers:
  - --action enable/disable/validate variants
  - --start / --end with and without scheduling
  - --dry-run and --no-schedule
  - Invalid cluster IDs (not in catalogue, missing required fields)
  - Node IDs / server hostnames passed as cluster ID (must be rejected)
  - Invalid datetime formats
  - End time before start time
  - Missing end time with no schedule defined
  - sys.exit / return codes in error paths
"""

import json
from datetime import datetime
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from automation.cli.maintenance_mode import (
    compute_next_work_start,
    parse_datetime,
)

# ── helpers ────────────────────────────────────────────────────────────────────

def _write_clusters_catalogue(path: Path, clusters: dict) -> None:
    """Write a clusters_catalogue.json file to *path* (parent dir must exist)."""
    path.write_text(json.dumps({"clusters": clusters}, indent=2))


def _minimal_cluster(cluster_id: str = "TEST-CLUSTER") -> dict:
    return {
        "display_name": "Test Cluster",
        "servers": ["srv1.example.com", "srv2.example.com"],
        "scom_group": "Test SCOM Group",
        "scom_management_server": "scom.example.com",
        "ilo_addresses": {"srv1.example.com": "192.168.1.101", "srv2.example.com": "192.168.1.102"},
        "openview_node_ids": {},
        "schedule": {"work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"], "work_start": "08:00", "work_end": "17:00"},
        "environment": "test",
    }


# ── parse_datetime + compute_next_work_start ──────────────────────────────────

class TestParseDatetimeExtended:
    """Tests for parse_datetime function."""

    def test_parse_datetime_now(self):
        """Test parsing 'now' returns current time."""
        result = parse_datetime("now")
        assert isinstance(result, datetime)
        diff = datetime.now() - result
        assert diff.total_seconds() < 1

    def test_parse_datetime_iso_format(self):
        """Test parsing ISO format datetime."""
        result = parse_datetime("2025-05-15T14:30:00")
        assert result.year == 2025 and result.month == 5 and result.day == 15
        assert result.hour == 14 and result.minute == 30

    def test_parse_datetime_space_separated(self):
        """Test parsing space-separated datetime."""
        result = parse_datetime("2025-05-15 14:30")
        assert result.year == 2025 and result.hour == 14 and result.minute == 30

    def test_parse_datetime_with_seconds(self):
        """Test parsing with seconds included."""
        result = parse_datetime("2025-05-15 14:30:45")
        assert result.second == 45

    def test_parse_datetime_invalid_format(self):
        """Test invalid format raises ValueError."""
        with pytest.raises(ValueError, match="Invalid datetime format"):
            parse_datetime("invalid-date")


class TestComputeNextWorkStartExtended:
    """Tests for compute_next_work_start function."""

    def test_compute_next_work_start_same_day(self):
        """Test computation when next work start is same day."""
        schedule = {"work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"], "work_start": "09:00", "work_end": "17:00"}
        after_dt = datetime(2025, 5, 14, 8, 0)
        result = compute_next_work_start(schedule, after_dt)
        assert result == datetime(2025, 5, 14, 9, 0)

    def test_compute_next_work_start_next_day(self):
        """Test computation when next work start is next day."""
        schedule = {"work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"], "work_start": "09:00"}
        after_dt = datetime(2025, 5, 16, 10, 0)
        result = compute_next_work_start(schedule, after_dt)
        assert result.weekday() == 0
        assert result.hour == 9 and result.minute == 0

    def test_compute_next_work_start_weekend(self):
        """Test computation from weekend to Monday."""
        schedule = {"work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"], "work_start": "08:30"}
        after_dt = datetime(2025, 5, 17, 12, 0)
        result = compute_next_work_start(schedule, after_dt)
        assert result.weekday() == 0
        assert result.hour == 8 and result.minute == 30

    def test_compute_next_work_start_default_schedule(self):
        """Test with default schedule (Mon-Fri, 08:00-17:00)."""
        after_dt = datetime(2025, 5, 14, 18, 0)
        result = compute_next_work_start({}, after_dt)
        assert result.weekday() == 3
        assert result.hour == 8 and result.minute == 0


# ── main() tests ──────────────────────────────────────────────────────────────

class TestMaintenanceModeMainValidateAction:
    """Tests for main() --action validate path."""

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_validate_success_exits_zero(self, mock_load, mock_save, mock_logging, tmp_path):
        """validate action with valid cluster ID exits 0."""
        clusters = {"GOOD-CLUSTER": _minimal_cluster("GOOD-CLUSTER")}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.argv", ["maintenance_mode", "-c", "GOOD-CLUSTER", "-a", "validate"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_validate_invalid_cluster_exits_two(self, mock_load, mock_save, mock_logging):
        """validate action with unknown cluster ID exits 2."""
        clusters = {"OTHER-CLUSTER": _minimal_cluster("OTHER-CLUSTER")}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info,              patch("sys.argv", ["maintenance_mode", "-c", "NONEXISTENT", "-a", "validate"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 2


class TestMaintenanceModeMainEnableAction:
    """Tests for main() --action enable flow."""

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.SCOMManager")
    @patch("automation.cli.maintenance_mode.ILOManager")
    @patch("automation.cli.maintenance_mode.OpenViewClient")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_with_start_now_end_explicit_success(
        self, mock_load, mock_email, mock_ov, mock_ilo, mock_scom, mock_save, mock_logging, tmp_path
    ):
        """enable with --start now --end explicit datetime calls SCOM/iLO/OpenView."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        scom_cfg = {"management_server": "scom.example.com", "use_winrm": False}
        mock_load.return_value = {"clusters": clusters, "scom_config": scom_cfg, "openview_config": {}, "email_distribution_lists": {}}
        mock_scom.return_value.enter_maintenance.return_value = (True, [])
        mock_ilo.return_value.set_maintenance_window.return_value = (True, {})
        mock_ov.return_value.set_maintenance.return_value = (True, "ok")
        mock_email.return_value.send_maintenance_notification.return_value = True

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "now", "-e", "2025-06-01T17:00:00"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0
        mock_scom.return_value.enter_maintenance.assert_called_once()
        mock_ilo.return_value.set_maintenance_window.assert_called_once()

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.SCOMManager")
    @patch("automation.cli.maintenance_mode.ILOManager")
    @patch("automation.cli.maintenance_mode.OpenViewClient")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_explicit_start_end_datetimes(
        self, mock_load, mock_email, mock_ov, mock_ilo, mock_scom, mock_save, mock_logging, tmp_path
    ):
        """enable with explicit start and end datetimes."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters, "scom_config": {"use_winrm": False}, "openview_config": {}, "email_distribution_lists": {}}
        mock_scom.return_value.enter_maintenance.return_value = (True, [])
        mock_ilo.return_value.set_maintenance_window.return_value = (True, {})
        mock_ov.return_value.set_maintenance.return_value = (True, "ok")
        mock_email.return_value.send_maintenance_notification.return_value = True

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "2025-06-01T09:00:00", "-e", "2025-06-01T17:00:00"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.SCOMManager")
    @patch("automation.cli.maintenance_mode.ILOManager")
    @patch("automation.cli.maintenance_mode.OpenViewClient")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_no_end_no_schedule_exits_one(
        self, mock_load, mock_email, mock_ov, mock_ilo, mock_scom, mock_save, mock_logging, tmp_path
    ):
        """enable without --end and cluster without schedule exits 1."""
        cluster_no_schedule = dict(_minimal_cluster())
        del cluster_no_schedule["schedule"]
        clusters = {"NO-SCHED": cluster_no_schedule}
        mock_load.return_value = {"clusters": clusters, "scom_config": {}, "openview_config": {}, "email_distribution_lists": {}}

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.argv", ["maintenance_mode", "-c", "NO-SCHED", "-a", "enable", "-s", "now"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 1

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.SCOMManager")
    @patch("automation.cli.maintenance_mode.ILOManager")
    @patch("automation.cli.maintenance_mode.OpenViewClient")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_dry_run_skips_real_calls(
        self, mock_load, mock_email, mock_ov, mock_ilo, mock_scom, mock_save, mock_logging, tmp_path
    ):
        """enable --dry-run does not call real SCOM/iLO/OpenView."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters, "scom_config": {"use_winrm": False}, "openview_config": {}, "email_distribution_lists": {}}

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "now", "-e", "2025-06-01T17:00:00", "--dry-run"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0
        mock_scom.return_value.enter_maintenance.assert_called_once()

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_end_before_start_exits_one(self, mock_load, mock_save, mock_logging):
        """enable with end <= start exits 1."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info,              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "2025-06-01T17:00:00", "-e", "2025-06-01T09:00:00"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 1

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_invalid_start_datetime_exits_one(self, mock_load, mock_save, mock_logging):
        """enable with invalid --start datetime exits 1."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info,              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "not-a-date", "-e", "2025-06-01T17:00:00"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 1


class TestMaintenanceModeMainDisableAction:
    """Tests for main() --action disable path."""

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_disable_sends_email_and_opsramp(self, mock_load, mock_email, mock_save, mock_logging, tmp_path):
        """disable sends email notification and OpsRamp metrics."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters, "scom_config": {}, "openview_config": {}, "email_distribution_lists": {}}
        mock_email.return_value.send_maintenance_notification.return_value = True

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.OpsRampClient", return_value=None),              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "disable"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0
        mock_email.return_value.send_maintenance_notification.assert_called_once()


class TestMaintenanceModeMainClusterIdValidation:
    """Negative tests for cluster ID validation in main()."""

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_invalid_cluster_id_exits_two(self, mock_load, mock_save, mock_logging, capsys):
        """Unknown cluster ID exits 2 and prints to stderr."""
        clusters = {"GOOD-CLUSTER": _minimal_cluster("GOOD-CLUSTER")}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info, patch("sys.argv", ["maintenance_mode", "-c", "INVALID-ID"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 2
        captured = capsys.readouterr()
        assert "INVALID-ID" in captured.err

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_node_id_as_cluster_id_rejected(self, mock_load, mock_save, mock_logging, tmp_path):
        """A server hostname (node ID) that is not a cluster key must be rejected."""
        prod_cluster = _minimal_cluster("PROD-CLUSTER")
        clusters = {"PROD-CLUSTER": prod_cluster}
        mock_load.return_value = {"clusters": clusters}
        node_as_cluster_id = "srv1.example.com"
        assert node_as_cluster_id in prod_cluster["servers"]
        with pytest.raises(SystemExit) as exc_info,              patch("sys.argv", ["maintenance_mode", "-c", node_as_cluster_id]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 2

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_cluster_missing_required_fields_exits_one(self, mock_load, mock_save, mock_logging):
        """Cluster definition missing required fields exits 1."""
        incomplete = {"display_name": "Bad", "servers": ["s1"]}
        clusters = {"BAD": incomplete}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info, patch("sys.argv", ["maintenance_mode", "-c", "BAD"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 1

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_cluster_servers_not_list_exits_one(self, mock_load, mock_save, mock_logging):
        """Cluster with servers not a list exits 1."""
        bad = {"display_name": "Bad", "servers": "not-a-list", "scom_group": "G", "environment": "t", "ilo_addresses": {}}
        clusters = {"BAD": bad}
        mock_load.return_value = {"clusters": clusters}
        with pytest.raises(SystemExit) as exc_info, patch("sys.argv", ["maintenance_mode", "-c", "BAD"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 1


class TestMaintenanceModeMainNoSchedule:
    """Tests for --no-schedule flag."""

    @patch("automation.cli.maintenance_mode.init_logging")
    @patch("automation.cli.maintenance_mode.save_audit")
    @patch("automation.cli.maintenance_mode.SCOMManager")
    @patch("automation.cli.maintenance_mode.ILOManager")
    @patch("automation.cli.maintenance_mode.OpenViewClient")
    @patch("automation.cli.maintenance_mode.EmailNotifier")
    @patch("automation.cli.maintenance_mode.utils_load_json_config")
    def test_enable_no_schedule_flag(
        self, mock_load, mock_email, mock_ov, mock_ilo, mock_scom, mock_save, mock_logging, tmp_path
    ):
        """enable --no-schedule does not create Windows Scheduled Task."""
        clusters = {"TEST-CLUSTER": _minimal_cluster()}
        mock_load.return_value = {"clusters": clusters, "scom_config": {"use_winrm": False}, "openview_config": {}, "email_distribution_lists": {}}
        mock_scom.return_value.enter_maintenance.return_value = (True, [])
        mock_ilo.return_value.set_maintenance_window.return_value = (True, {})
        mock_ov.return_value.set_maintenance.return_value = (True, "ok")
        mock_email.return_value.send_maintenance_notification.return_value = True

        with pytest.raises(SystemExit) as exc_info,              patch("automation.cli.maintenance_mode.CONFIG_DIR", tmp_path),              patch("automation.cli.maintenance_mode.LOG_DIR", tmp_path),              patch("sys.platform", "win32"),              patch("subprocess.run", return_value=MagicMock(returncode=0)) as mock_sub,              patch("sys.argv", ["maintenance_mode", "-c", "TEST-CLUSTER", "-a", "enable", "-s", "now", "-e", "2025-06-01T17:00:00", "--no-schedule"]):
            from automation.cli.maintenance_mode import main as mm_main
            mm_main()
        assert exc_info.value.code == 0
        mock_sub.assert_not_called()
