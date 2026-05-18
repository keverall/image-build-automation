"""Tests for automation.cli.maintenance_mode module."""

from datetime import datetime, timedelta
from unittest.mock import patch

import pytest

from automation.cli.maintenance_mode import (
    EmailNotifier,
    ILOManager,
    OpenViewClient,
    SCOMManager,
    compute_next_work_start,
    format_datetime_for_api,
    parse_datetime,
)


class TestParseDatetime:
    """Tests for parse_datetime function."""

    def test_parse_datetime_now(self):
        """Test parsing 'now' returns current time."""
        result = parse_datetime("now")
        assert isinstance(result, datetime)
        # Should be close to current time
        diff = datetime.now() - result
        assert diff.total_seconds() < 1

    def test_parse_datetime_iso_format(self):
        """Test parsing ISO format datetime."""
        result = parse_datetime("2025-05-15T14:30:00")
        assert result.year == 2025
        assert result.month == 5
        assert result.day == 15
        assert result.hour == 14
        assert result.minute == 30
        assert result.second == 0

    def test_parse_datetime_space_separated(self):
        """Test parsing space-separated datetime."""
        result = parse_datetime("2025-05-15 14:30")
        assert result.year == 2025
        assert result.hour == 14
        assert result.minute == 30

    def test_parse_datetime_with_seconds(self):
        """Test parsing with seconds included."""
        result = parse_datetime("2025-05-15 14:30:45")
        assert result.second == 45

    def test_parse_datetime_invalid_format(self):
        """Test invalid format raises ValueError."""
        with pytest.raises(ValueError, match="Invalid datetime format"):
            parse_datetime("invalid-date")


class TestComputeNextWorkStart:
    """Tests for compute_next_work_start function."""

    def test_compute_next_work_start_same_day(self):
        """Test computation when next work start is same day."""
        schedule = {"work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"], "work_start": "09:00", "work_end": "17:00"}
        # Wednesday at 10:00 AM, next work start is still Wednesday at 9:00? No that's before 10:00
        # Let's test: Wednesday 8:00 AM -> Wednesday 9:00 AM
        after_dt = datetime(2025, 5, 14, 8, 0)  # Wed 8:00
        result = compute_next_work_start(schedule, after_dt)

        assert result == datetime(2025, 5, 14, 9, 0)  # Same day 9:00

    def test_compute_next_work_start_next_day(self):
        """Test computation when next work start is next day."""
        schedule = {
            "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
            "work_start": "09:00",
        }
        # Friday at 10:00 AM -> next Monday 9:00 AM
        after_dt = datetime(2025, 5, 16, 10, 0)  # Friday
        result = compute_next_work_start(schedule, after_dt)

        assert result.weekday() == 0  # Monday
        assert result.hour == 9
        assert result.minute == 0

    def test_compute_next_work_start_weekend(self):
        """Test computation from weekend to Monday."""
        schedule = {
            "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
            "work_start": "08:30",
        }
        # Saturday at noon -> Monday 8:30
        after_dt = datetime(2025, 5, 17, 12, 0)  # Saturday
        result = compute_next_work_start(schedule, after_dt)

        assert result.weekday() == 0  # Monday
        assert result.hour == 8
        assert result.minute == 30

    def test_compute_next_work_start_default_schedule(self):
        """Test with default schedule (Mon-Fri, 08:00-17:00)."""
        after_dt = datetime(2025, 5, 14, 18, 0)  # Wed 6pm after work hours
        result = compute_next_work_start({}, after_dt)

        # Should compute Thursday 08:00
        assert result.weekday() == 3  # Thursday
        assert result.hour == 8
        assert result.minute == 0


class TestFormatDatetimeForAPI:
    """Tests for format_datetime_for_api function."""

    def test_format_datetime_for_api_naive(self):
        """Test formatting naive datetime."""
        dt = datetime(2025, 5, 15, 14, 30, 0)
        result = format_datetime_for_api(dt)
        assert result == "2025-05-15T14:30:00"

    def test_format_datetime_for_api_with_timezone(self):
        """Test formatting timezone-aware datetime."""
        from datetime import timedelta, timezone

        tz = timezone(timedelta(hours=2))
        dt = datetime(2025, 5, 15, 14, 30, 0, tzinfo=tz)
        result = format_datetime_for_api(dt)
        # Should be parseable ISO format with timezone offset
        parsed = datetime.fromisoformat(result)
        assert parsed.tzinfo is not None
        # The function converts to local timezone; offset may differ from original.


class TestSCOMManager:
    """Tests for SCOMManager class."""

    def test_initialization(self):
        """Test SCOMManager initialization."""
        config = {"management_server": "scom.example.com", "powershell_module": "OperationsManager", "use_winrm": False}
        mgr = SCOMManager(config)
        assert mgr.mgmt_server == "scom.example.com"
        assert mgr.module_name == "OperationsManager"
        assert mgr.use_winrm is False

    def test_run_ps_local(self):
        """Test _run_ps executes locally."""
        config = {"use_winrm": False}
        mgr = SCOMManager(config)

        with patch("automation.cli.maintenance_mode.run_powershell") as mock_ps:
            mock_ps.return_value = (True, "output")
            success, output = mgr._run_ps("Get-Service")

        mock_ps.assert_called_once_with("Get-Service", capture_output=True)
        assert success is True

    def test_run_ps_winrm(self):
        """Test _run_ps uses WinRM when configured."""
        config = {"use_winrm": True, "credentials": {"username_env": "SCOM_USER", "password_env": "SCOM_PASS"}}
        mgr = SCOMManager(config)
        # Manually set cred since env not available in test
        mgr.cred = {"username": "user", "password": "pass"}

        with patch("automation.cli.maintenance_mode.run_powershell_winrm") as mock_winrm:
            mock_winrm.return_value = (True, "output")
            success, output = mgr._run_ps("Get-Service")

        mock_winrm.assert_called_once_with("Get-Service", server=mgr.mgmt_server, username="user", password="pass")

    def test_get_group_members(self):
        """Test get_group_members returns server list."""
        config = {"management_server": "scom.example.com", "use_winrm": False}
        mgr = SCOMManager(config)

        with patch("automation.cli.maintenance_mode.run_powershell") as mock_ps:
            mock_ps.return_value = (True, "server1\nserver2\nserver3\n")
            success, servers = mgr.get_group_members("TestGroup")

        assert success is True
        assert servers == ["server1", "server2", "server3"]

    def test_enter_maintenance_dry_run(self):
        """Test enter_maintenance in dry-run mode."""
        config = {"use_winrm": False}
        mgr = SCOMManager(config)

        result = mgr.enter_maintenance(
            group_display_name="TestGroup", duration=timedelta(hours=2), comment="Test maintenance", dry_run=True
        )

        assert result[0] is True  # success
        assert result[1] == []  # empty info list

    def test_exit_maintenance_dry_run(self):
        """Test exit_maintenance in dry-run mode."""
        config = {"use_winrm": False}
        mgr = SCOMManager(config)

        result = mgr.exit_maintenance("TestGroup", dry_run=True)
        assert result is True


class TestILOManager:
    """Tests for ILOManager class."""

    def test_initialization(self):
        """Test ILOManager initialization."""
        cluster_def = {"ilo_addresses": {"server1": "192.168.1.100", "server2": "192.168.1.101"}}
        mgr = ILOManager(cluster_def)
        assert mgr.cluster_def == cluster_def
        assert mgr.method == "rest"
        assert mgr.timeout == 30

    def test_get_ilo_ip(self):
        """Test _get_ilo_ip retrieves correct IP."""
        cluster_def = {"ilo_addresses": {"server1": "1.1.1.1", "server2": "2.2.2.2"}}
        mgr = ILOManager(cluster_def)
        assert mgr._get_ilo_ip("server1") == "1.1.1.1"
        assert mgr._get_ilo_ip("server2") == "2.2.2.2"
        assert mgr._get_ilo_ip("missing") is None

    def test_get_ilo_credentials_global(self, monkeypatch):
        """Test _get_ilo_credentials uses global defaults."""
        monkeypatch.setenv("ILO_USER", "admin")
        monkeypatch.setenv("ILO_PASSWORD", "pass123")
        cluster_def = {"ilo_addresses": {"s1": "1.1.1.1"}}
        mgr = ILOManager(cluster_def)

        username, password = mgr._get_ilo_credentials("s1")
        assert username == "admin"
        assert password == "pass123"

    def test_create_window_rest_dry_run(self):
        """Test _create_window_rest in dry-run mode."""
        cluster_def = {}
        mgr = ILOManager(cluster_def)

        start_dt = datetime(2025, 5, 15, 10, 0, 0)
        end_dt = datetime(2025, 5, 15, 12, 0, 0)

        success, msg = mgr._create_window_rest("192.168.1.100", "user", "pass", start_dt, end_dt, dry_run=True)
        assert success is True
        assert "[DRY RUN]" in msg

    def test_set_maintenance_window(self):
        """Test set_maintenance_window coordinates multiple servers."""
        cluster_def = {"servers": ["s1", "s2"], "ilo_addresses": {"s1": "1.1.1.1", "s2": "2.2.2.2"}}
        mgr = ILOManager(cluster_def)

        # Patch _get_ilo_credentials to return valid credentials
        with (
            patch.object(mgr, "_get_ilo_credentials", return_value=("user", "pass")),
            patch.object(mgr, "_create_window_rest") as mock_create,
        ):
            mock_create.return_value = (True, "Window created")
            success, details = mgr.set_maintenance_window(cluster_def, datetime.now(), datetime.now(), dry_run=False)

        assert success is True
        assert "s1" in details
        assert "s2" in details

    def test_set_maintenance_window_no_ilo_addresses(self):
        """Test set_maintenance_window handles missing iLO addresses."""
        cluster_def = {"servers": ["s1", "s2"], "ilo_addresses": {}}
        mgr = ILOManager(cluster_def)
        success, details = mgr.set_maintenance_window(cluster_def, datetime.now(), datetime.now())
        assert success is True
        assert details.get("skipped") is True


class TestOpenViewClient:
    """Tests for OpenViewClient class."""

    def test_initialization(self):
        """Test OpenViewClient initialization."""
        config = {"openview": {"default_api_url": "https://ov.example.com/api"}}
        cluster_def = {}
        client = OpenViewClient(config, cluster_def)
        assert client.base_url == "https://ov.example.com/api"
        assert client.use_cli is False

    def test_set_maintenance_no_node_ids(self):
        """Test set_maintenance with no OpenView nodes configured."""
        config = {"openview": {}}
        cluster_def = {"openview_node_ids": {}}
        client = OpenViewClient(config, cluster_def)

        success, msg = client.set_maintenance(cluster_def, datetime.now(), datetime.now())
        assert success is True
        assert "No OpenView nodes" in msg

    def test_set_maintenance_cli_dry_run(self):
        """Test _set_maintenance_cli in dry-run mode."""
        config = {"openview": {"use_cli": True}}
        cluster_def = {"openview_node_ids": {"node1": "id1"}}
        client = OpenViewClient(config, cluster_def)

        success, msg = client._set_maintenance_cli(
            ["node1"], datetime(2025, 5, 15, 10, 0), datetime(2025, 5, 15, 12, 0), "TestCluster", dry_run=True
        )
        assert success is True
        assert "[DRY RUN]" in msg


class TestEmailNotifier:
    """Tests for EmailNotifier class."""

    def test_initialization_no_config(self):
        """Test EmailNotifier with empty config."""
        config = {"email": {}}
        notifier = EmailNotifier(config)
        assert notifier.smtp_server == "localhost"
        assert notifier.smtp_port == 25

    def test_get_recipients_simple_list(self, tmp_path):
        """Test _get_recipients with simple distribution list file."""
        config = {"email": {}}
        notifier = EmailNotifier(config)

        # Create simple distribution list file
        list_file = tmp_path / "maintenance_distribution_list.txt"
        list_file.write_text("admin@example.com\nops@example.com\n")
        notifier.simple_recipients = ["admin@example.com", "ops@example.com"]
        notifier.use_simple = True

        recipients = notifier._get_recipients("enabled")
        assert recipients == ["admin@example.com", "ops@example.com"]

    def test_send_maintenance_notification_dry_run(self):
        """Test send_maintenance_notification in dry-run mode returns False due to no recipients."""
        config = {"email": {"distribution_lists": {}}}
        notifier = EmailNotifier(config)

        cluster = {"display_name": "TestCluster", "environment": "test"}
        result = notifier.send_maintenance_notification(
            action="enabled",
            cluster=cluster,
            servers=["s1", "s2"],
            start_time=datetime(2025, 5, 15, 10, 0),
            end_time=datetime(2025, 5, 15, 12, 0),
            dry_run=True,
        )
        # No recipients configured, returns False
        assert result is False
