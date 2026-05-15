"""Tests for automation.utils.config module."""

import json
from unittest.mock import patch

import pytest

from automation.utils.config import _replace_env_vars, load_json_config, load_yaml_config


class TestLoadJsonConfig:
    """Tests for load_json_config function."""

    def test_load_json_config_valid_file(self, tmp_path):
        """Test loading valid JSON config."""
        data = {"key": "value", "nested": {"inner": 123}}
        path = tmp_path / "config.json"
        path.write_text(json.dumps(data))

        result = load_json_config(path)
        assert result == data

    def test_load_json_config_missing_file_required(self, tmp_path):
        """Test missing required file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            load_json_config(tmp_path / "missing.json", required=True)

    def test_load_json_config_missing_file_optional(self, tmp_path):
        """Test missing optional file returns empty dict."""
        result = load_json_config(tmp_path / "missing.json", required=False)
        assert result == {}

    def test_load_json_config_invalid_json(self, tmp_path):
        """Test invalid JSON raises JSONDecodeError."""
        path = tmp_path / "bad.json"
        path.write_text("{invalid")
        with pytest.raises(json.JSONDecodeError):
            load_json_config(path)

    def test_load_json_config_env_var_replacement(self, tmp_path, monkeypatch):
        """Test environment variable substitution in config values."""
        monkeypatch.setenv("TEST_VAR", "replaced_value")
        data = {"url": "https://${TEST_VAR}.example.com", "password": "${TEST_VAR}"}
        path = tmp_path / "config.json"
        path.write_text(json.dumps(data))

        result = load_json_config(path)
        assert result["url"] == "https://replaced_value.example.com"
        assert result["password"] == "replaced_value"

    def test_load_json_config_env_var_replacement_nested(self, tmp_path, monkeypatch):
        """Test environment variable substitution in nested structures."""
        monkeypatch.setenv("HOST", "myhost")
        data = {
            "servers": [
                {"name": "server1", "endpoint": "https://${HOST}/api"},
                {"name": "server2", "endpoint": "https://${HOST}:8080"}
            ]
        }
        path = tmp_path / "config.json"
        path.write_text(json.dumps(data))

        result = load_json_config(path)
        assert result["servers"][0]["endpoint"] == "https://myhost/api"
        assert result["servers"][1]["endpoint"] == "https://myhost:8080"

    def test_load_json_config_undefined_env_var_kept_unchanged(self, tmp_path, monkeypatch):
        """Test undefined env vars keep original placeholder."""
        monkeypatch.delenv("UNDEFINED_VAR", raising=False)
        data = {"key": "${UNDEFINED_VAR}"}
        path = tmp_path / "config.json"
        path.write_text(json.dumps(data))

        result = load_json_config(path)
        assert result["key"] == "${UNDEFINED_VAR}"  # Placeholder preserved

    def test_load_json_config_disabled_env_var_replacement(self, tmp_path, monkeypatch):
        """Test disabling environment variable replacement."""
        monkeypatch.setenv("TEST_VAR", "value")
        data = {"key": "${TEST_VAR}"}
        path = tmp_path / "config.json"
        path.write_text(json.dumps(data))

        result = load_json_config(path, auto_env_var_replace=False)
        assert result["key"] == "${TEST_VAR}"


class TestReplaceEnvVars:
    """Tests for _replace_env_vars internal function."""

    def test_replace_env_vars_string(self, monkeypatch):
        """Test replacing in a simple string."""
        monkeypatch.setenv("VAR1", "value1")
        result = _replace_env_vars({"key": "text ${VAR1} more"})
        assert result["key"] == "text value1 more"

    def test_replace_env_vars_multiple_in_string(self, monkeypatch):
        """Test multiple replacements in single string."""
        monkeypatch.setenv("A", "a")
        monkeypatch.setenv("B", "b")
        result = _replace_env_vars({"key": "${A} and ${B}"})
        assert result["key"] == "a and b"

    def test_replace_env_vars_nested_dict(self, monkeypatch):
        """Test replacement in nested dictionary."""
        monkeypatch.setenv("HOST", "host.example.com")
        data = {"level1": {"level2": {"url": "https://${HOST}"}}}
        result = _replace_env_vars(data)
        assert result["level1"]["level2"]["url"] == "https://host.example.com"

    def test_replace_env_vars_in_list(self, monkeypatch):
        """Test replacement in list values."""
        monkeypatch.setenv("TOKEN", "abc123")
        data = {"items": ["token=${TOKEN}", "nopls"]}
        result = _replace_env_vars(data)
        assert result["items"][0] == "token=abc123"
        assert result["items"][1] == "nopls"

    def test_replace_env_vars_non_string_values(self, monkeypatch):
        """Test non-string values remain unchanged."""
        monkeypatch.setenv("VAR", "val")
        data = {"number": 42, "bool": True, "none": None, "list": [1, 2, 3]}
        result = _replace_env_vars(data)
        assert result == data


class TestLoadYamlConfig:
    """Tests for load_yaml_config function."""

    def test_load_yaml_config_valid(self, tmp_path, monkeypatch):
        """Test loading valid YAML file."""
        yaml_content = """
key: value
list:
  - item1
  - item2
nested:
  inner: 123
"""
        path = tmp_path / "config.yaml"
        path.write_text(yaml_content)

        # PyYAML should be available in the project
        result = load_yaml_config(path)
        assert result["key"] == "value"
        assert result["list"] == ["item1", "item2"]

    def test_load_yaml_config_missing_pyyaml(self, tmp_path, monkeypatch):
        """Test ImportError when PyYAML not available."""
        path = tmp_path / "config.yaml"
        path.touch()

        # Simulate PyYAML not being available
        with patch.dict('sys.modules', {'yaml': None}), pytest.raises(ImportError):
            load_yaml_config(path)

    def test_load_yaml_config_missing_file_required(self, tmp_path):
        """Test missing required YAML file."""
        with pytest.raises(FileNotFoundError):
            load_yaml_config(tmp_path / "missing.yaml", required=True)

    def test_load_yaml_config_missing_file_optional(self, tmp_path):
        """Test missing optional YAML file."""
        result = load_yaml_config(tmp_path / "missing.yaml", required=False)
        assert result == {}
