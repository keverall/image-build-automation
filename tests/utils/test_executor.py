"""Tests for automation.utils.executor module."""

import subprocess
import time
from unittest.mock import MagicMock, patch

import pytest

from automation.utils.executor import CommandResult, run_command, run_with_retry


class TestCommandResult:
    """Tests for CommandResult dataclass."""

    def test_command_result_success_true(self):
        """Test CommandResult with success=True."""
        cr = CommandResult(returncode=0, stdout="output", stderr="", success=True)
        assert cr.success is True
        assert cr.returncode == 0
        assert cr.stdout == "output"
        assert cr.stderr == ""

    def test_command_result_success_false(self):
        """Test CommandResult with success=False."""
        cr = CommandResult(returncode=1, stdout="", stderr="error", success=False)
        assert cr.success is False
        assert cr.returncode == 1
        assert cr.output == "error"  # output property combines stdout and stderr

    def test_command_result_output_property(self):
        """Test output property combines stdout and stderr."""
        cr = CommandResult(returncode=0, stdout="out", stderr="err", success=True)
        assert cr.output == "outerr"


class TestRunCommand:
    """Tests for run_command function."""

    def test_run_command_success(self, monkeypatch):
        """Test successful command execution."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "command output"
        mock_result.stderr = ""

        monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: mock_result)

        result = run_command(["echo", "test"])
        assert result.success is True
        assert result.stdout == "command output"
        assert result.returncode == 0

    def test_run_command_failure(self, monkeypatch):
        """Test command execution failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "command error"

        monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: mock_result)

        result = run_command(["false"])
        assert result.success is False
        assert result.stderr == "command error"

    def test_run_command_timeout(self, monkeypatch):
        """Test command timeout."""
        def raise_timeout(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="cmd", timeout=30)

        monkeypatch.setattr(subprocess, "run", raise_timeout)

        result = run_command(["sleep", "100"], timeout=30)
        assert result.success is False
        assert result.returncode == -1
        assert "timed out" in result.stderr.lower()

    def test_run_command_check_raises_on_failure(self, monkeypatch):
        """Test check=True raises CalledProcessError on failure."""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "error"

        monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: mock_result)

        with pytest.raises(subprocess.CalledProcessError):
            run_command(["false"], check=True)

    def test_run_command_with_cwd(self, monkeypatch, tmp_path):
        """Test command runs in specified working directory."""
        captured_cwd = None

        def mock_run(cmd, **kwargs):
            nonlocal captured_cwd
            captured_cwd = kwargs.get('cwd')
            mock_result = MagicMock()
            mock_result.returncode = 0
            mock_result.stdout = "ok"
            mock_result.stderr = ""
            return mock_result

        monkeypatch.setattr(subprocess, "run", mock_run)

        test_dir = tmp_path / "test_dir"
        test_dir.mkdir()
        run_command(["echo", "test"], cwd=test_dir)
        assert captured_cwd == test_dir

    def test_run_command_string_command(self, monkeypatch):
        """Test execution with string command."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "output"
        mock_result.stderr = ""

        monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: mock_result)

        result = run_command("echo test", shell=True)
        assert result.success is True

    def test_run_command_capture_output_false(self, monkeypatch):
        """Test with capture_output=False."""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = None  # When not capturing, stdout is None
        mock_result.stderr = None

        monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: mock_result)

        result = run_command(["echo", "test"], capture_output=False)
        assert result.success is True


class TestRunWithRetry:
    """Tests for run_with_retry function."""

    def test_run_with_retry_first_attempt_success(self, monkeypatch):
        """Test successful command on first attempt."""
        mock_result = MagicMock()
        mock_result.success = True
        mock_result.returncode = 0
        mock_result.stdout = "ok"
        mock_result.stderr = ""

        monkeypatch.setattr("automation.utils.executor.run_command", lambda *args, **kwargs: mock_result)

        result = run_with_retry(["echo", "test"])
        assert result.success is True

    def test_run_with_retry_retries_then_success(self, monkeypatch):
        """Test command succeeds after retries."""
        call_count = 0

        def mock_run_cmd(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                # Fail first two attempts
                return CommandResult(returncode=1, stdout="", stderr="fail", success=False)
            else:
                return CommandResult(returncode=0, stdout="success", stderr="", success=True)

        monkeypatch.setattr("automation.utils.executor.run_command", mock_run_cmd)

        with patch('time.sleep'):  # Speed up test
            result = run_with_retry(["cmd"], max_attempts=3)

        assert result.success is True
        assert call_count == 3

    def test_run_with_retry_all_attempts_fail(self, monkeypatch):
        """Test all attempts fail."""
        def mock_run_cmd(*args, **kwargs):
            return CommandResult(returncode=1, stdout="", stderr="fail", success=False)

        monkeypatch.setattr("automation.utils.executor.run_command", mock_run_cmd)

        with patch('time.sleep'):
            result = run_with_retry(["cmd"], max_attempts=2)

        assert result.success is False

    def test_run_with_retry_raises_when_check_true(self, monkeypatch):
        """Test RuntimeError raised when check=True and all attempts fail."""
        def mock_run_cmd(*args, **kwargs):
            return CommandResult(returncode=1, stdout="", stderr="fail", success=False)

        monkeypatch.setattr("automation.utils.executor.run_command", mock_run_cmd)

        with patch('time.sleep'), pytest.raises(RuntimeError, match="Command failed after"):
            run_with_retry(["cmd"], max_attempts=1, check=True)

    def test_run_with_retry_exponential_backoff(self, monkeypatch):
        """Test exponential backoff delay between retries."""
        delays = []

        def mock_sleep(seconds):
            delays.append(seconds)

        monkeypatch.setattr(time, "sleep", mock_sleep)

        def mock_run_cmd(*args, **kwargs):
            return CommandResult(returncode=1, stdout="", stderr="fail", success=False)

        monkeypatch.setattr("automation.utils.executor.run_command", mock_run_cmd)

        run_with_retry(["cmd"], max_attempts=2, delay=1.0)
        # For 2 retries: delays should be: 1.0, 2.0 (exponential)
        assert len(delays) == 2
        assert delays[0] == 1.0
        assert delays[1] == 2.0
