"""Tests for automation.utils.powershell module."""

import subprocess
import sys
from unittest.mock import MagicMock, patch

from automation.utils.powershell import (
    build_scom_connection,
    build_scom_maintenance_script,
    run_powershell,
    run_powershell_winrm,
)


class TestRunPowerShell:
    """Tests for run_powershell function."""

    def test_run_powershell_success(self, monkeypatch):
        """Test successful PowerShell execution."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "output"
        mock_result.stderr = ""

        monkeypatch.setattr("subprocess.run", lambda *args, **kwargs: mock_result)

        success, output = run_powershell("Write-Host 'test'")
        assert success is True
        assert output == "output"

    def test_run_powershell_failure(self, monkeypatch):
        """Test PowerShell execution failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "Error message"

        monkeypatch.setattr("subprocess.run", lambda *args, **kwargs: mock_result)

        success, output = run_powershell("invalid")
        assert success is False
        assert "Error message" in output

    def test_run_powershell_with_custom_execution_policy(self, monkeypatch):
        """Test that custom execution policy is used."""
        called_cmd = None

        def mock_run(cmd, **kwargs):
            nonlocal called_cmd
            called_cmd = cmd
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = "ok"
            mock_result.stderr = ""
            return mock_result

        monkeypatch.setattr("subprocess.run", mock_run)

        run_powershell("Test", execution_policy="Restricted")
        assert "-ExecutionPolicy" in called_cmd
        assert "Restricted" in called_cmd

    def test_run_powershell_timeout(self, monkeypatch):
        """Test PowerShell timeout."""

        def raise_timeout(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="powershell", timeout=30)

        monkeypatch.setattr("subprocess.run", raise_timeout)

        success, output = run_powershell("Start-Sleep -Seconds 60", timeout=30)
        assert success is False
        assert "timed out" in output.lower()

    def test_run_powershell_capture_output_false(self, monkeypatch):
        """Test with capture_output=False."""
        # When capture_output is False, stdout/stderr not captured
        # Function handles gracefully (use default None values)
        success, output = run_powershell("test", capture_output=False)
        # With capture_output=False, subprocess.run returns None for stdout/stderr
        # Our code handles this
        assert isinstance(success, bool)
        assert isinstance(output, str)


class TestRunPowerShellWinRM:
    """Tests for run_powershell_winrm function."""

    def test_run_powershell_winrm_missing_pywinrm(self, monkeypatch):
        """Test behavior when pywinrm is not installed."""
        # Ensure pywinrm is not importable
        monkeypatch.setitem(sys.modules, "winrm", None)

        with patch.dict("sys.modules", {"winrm": None}):
            success, output = run_powershell_winrm("test", "server", "user", "pass")
            assert success is False
            assert "pywinrm module not installed" in output

    def test_run_powershell_winrm_success(self, monkeypatch):
        """Test successful WinRM execution."""
        # Mock winrm module
        mock_winrm = MagicMock()
        mock_session = MagicMock()
        mock_result = MagicMock()
        mock_result.status_code = 0
        mock_result.std_out = b"output"
        mock_result.std_err = b""
        mock_session.run_ps.return_value = mock_result
        mock_winrm.Session.return_value = mock_session

        monkeypatch.setitem(sys.modules, "winrm", mock_winrm)

        with patch.dict("sys.modules", {"winrm": mock_winrm}):
            success, output = run_powershell_winrm("Write-Host test", "server1", "user", "pass")

        assert success is True
        assert "output" in output

    def test_run_powershell_winrm_failure(self, monkeypatch):
        """Test WinRM execution failure."""
        mock_winrm = MagicMock()
        mock_session = MagicMock()
        mock_result = MagicMock()
        mock_result.status_code = 1
        mock_result.std_out = b""
        mock_result.std_err = b"Error occurred"
        mock_session.run_ps.return_value = mock_result
        mock_winrm.Session.return_value = mock_session

        monkeypatch.setitem(sys.modules, "winrm", mock_winrm)

        with patch.dict("sys.modules", {"winrm": mock_winrm}):
            success, output = run_powershell_winrm("bad", "server", "user", "pass")

        assert success is False
        assert "Error occurred" in output

    def test_run_powershell_winrm_connection_error(self, monkeypatch):
        """Test WinRM connection failure."""
        mock_winrm = MagicMock()
        mock_winrm.Session.side_effect = Exception("Connection failed")

        monkeypatch.setitem(sys.modules, "winrm", mock_winrm)

        with patch.dict("sys.modules", {"winrm": mock_winrm}):
            success, output = run_powershell_winrm("test", "server", "user", "pass")

        assert success is False
        assert "Connection failed" in output


class TestBuildScomConnection:
    """Tests for build_scom_connection function."""

    def test_build_scom_connection(self):
        """Test PowerShell script generation for SCOM connection."""
        script = build_scom_connection("scom-server.example.com")

        assert "scom-server.example.com" in script
        assert "Import-Module OperationsManager" in script
        assert "New-SCOMManagementGroupConnection" in script


class TestBuildScomMaintenanceScript:
    """Tests for build_scom_maintenance_script function."""

    def test_build_maintenance_script_start(self):
        """Test generating start maintenance script."""
        script = build_scom_maintenance_script(
            group_display_name="TestGroup", duration_seconds=3600, comment="Test comment", operation="start"
        )

        assert "TestGroup" in script
        assert "Start-SCOMMaintenanceMode" in script
        assert "3600" in script  # duration in seconds
        assert "Test comment" in script

    def test_build_maintenance_script_stop(self):
        """Test generating stop maintenance script."""
        script = build_scom_maintenance_script(
            group_display_name="TestGroup", duration_seconds=3600, comment="Test", operation="stop"
        )

        assert "Stop-SCOMMaintenanceMode" in script
        assert "TestGroup" in script

    def test_build_maintenance_script_escapes_quotes(self):
        """Test that single quotes in comment are escaped."""
        script = build_scom_maintenance_script(
            group_display_name="TestGroup", duration_seconds=3600, comment="User's comment", operation="start"
        )

        # Single quotes should be doubled
        assert "User''s comment" in script

    def test_build_maintenance_script_invalid_operation(self):
        """Test with unknown operation returns None (no script generated)."""
        # The function does not handle unknown operations, returns None
        script = build_scom_maintenance_script(
            group_display_name="TestGroup", duration_seconds=3600, comment="Test", operation="invalid"
        )
        assert script is None
