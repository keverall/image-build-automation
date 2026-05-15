"""Tests for automation.utils.base module."""

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from automation.utils.base import AutomationBase


class TestAutomationBase:
    """Tests for AutomationBase class."""

    def test_initialization_default_paths(self, tmp_path):
        """Test AutomationBase initializes with default paths."""
        # We need to mock init_logging since it's called before class instantiation
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(dry_run=False)

        assert base.config_dir == Path("configs")
        assert base.output_dir == Path("output")
        assert base.dry_run is False

    def test_initialization_custom_paths(self, tmp_path):
        """Test AutomationBase with custom paths."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs", output_dir=tmp_path / "output", dry_run=True)

        assert base.config_dir == tmp_path / "configs"
        assert base.output_dir == tmp_path / "output"
        assert base.dry_run is True

    def test_initialization_creates_directories(self, tmp_path):
        """Test that output and logs directories are created."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs", output_dir=tmp_path / "custom_output")

        assert base.output_dir.exists()
        # LOG_DIR is a class constant pointing to "logs" relative to CWD
        # In tests it will be relative to tmp_path if we change CWD

    def test_load_config(self, tmp_path):
        """Test load_config method."""
        config_data = {"key": "value", "nested": {"inner": 123}}
        config_file = tmp_path / "configs" / "test.json"
        config_file.parent.mkdir(parents=True)
        config_file.write_text(json.dumps(config_data))

        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs")

        result = base.load_config("test.json")
        assert result == config_data

    def test_load_config_required_missing(self, tmp_path):
        """Test load_config with required=True raises error."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs")

        with pytest.raises(FileNotFoundError):
            base.load_config("missing.json", required=True)

    def test_load_config_optional_missing(self, tmp_path):
        """Test load_config with required=False returns empty dict."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs")

        result = base.load_config("missing.json", required=False)
        assert result == {}

    def test_load_servers(self, tmp_path):
        """Test load_servers method."""
        config_dir = tmp_path / "configs"
        config_dir.mkdir()
        # Also create required configs since __init__ validates them
        (config_dir / "hpe_firmware_drivers_nov2025.json").write_text('{"components": {}}')
        (config_dir / "windows_patches.json").write_text('{"patches": []}')
        (config_dir / "server_list.txt").write_text("server1\nserver2\n")

        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=config_dir)

        servers = base.load_servers("server_list.txt")
        # load_servers returns list of ServerInfo objects (include_details=True)
        assert len(servers) == 2
        from automation.utils.inventory import ServerInfo

        assert all(isinstance(s, ServerInfo) for s in servers)
        assert servers[0].hostname == "server1"
        assert servers[1].hostname == "server2"

    def test_save_result(self, tmp_path):
        """Test save_result creates JSON file in output directory."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(output_dir=tmp_path / "output")

        data = {"test": "data", "timestamp": "2024-01-01T00:00:00"}
        filepath = base.save_result(data, "test_result", category="results")

        assert filepath.exists()
        assert filepath.parent == tmp_path / "output" / "results"
        assert filepath.name.startswith("test_result_")
        assert filepath.name.endswith(".json")

    def test_log_and_audit(self, tmp_path):
        """Test log_and_audit calls both logger and audit."""
        # Use proper kwargs
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs", output_dir=tmp_path / "output")

        # Mock the audit.log method to track calls
        base.audit.log = MagicMock()
        base.logger.info = MagicMock()

        base.log_and_audit("test_action", "SUCCESS", "server1", "details here")

        base.logger.info.assert_called_once()
        base.audit.log.assert_called_once_with(
            action="test_action", status="SUCCESS", server="server1", details="details here"
        )

    def test_save_audit(self, tmp_path):
        """Test save_audit calls both save and append_to_master."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs", output_dir=tmp_path / "output")

        base.audit.save = MagicMock(return_value=tmp_path / "audit.json")
        base.audit.append_to_master = MagicMock()

        base.save_audit("custom_audit.json")

        base.audit.save.assert_called_once_with("custom_audit.json")
        base.audit.append_to_master.assert_called_once()

    def test_run_command_wrapper(self, tmp_path):
        """Test run_command wrapper calls underlying executor."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase(config_dir=tmp_path / "configs", output_dir=tmp_path / "output")

        with patch("automation.utils.base.run_command") as mock_run:
            mock_run.return_value.success = True
            result = base.run_command(["echo", "test"])

        mock_run.assert_called_once_with(["echo", "test"])
        assert result.success is True

    def test_validate_not_implemented(self, tmp_path):
        """Test validate raises NotImplementedError."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase()

        with pytest.raises(NotImplementedError):
            base.validate()

    def test_execute_not_implemented(self, tmp_path):
        """Test execute raises NotImplementedError."""
        with patch("automation.utils.logging_setup.init_logging"):
            base = AutomationBase()

        with pytest.raises(NotImplementedError):
            base.execute()
