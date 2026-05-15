"""Tests for automation.utils.file_io module."""

import json

import pytest

from automation.utils.file_io import ensure_dir, load_json, save_json, save_result_json


class TestEnsureDir:
    """Tests for ensure_dir function."""

    def test_ensure_dir_creates_directory(self, tmp_path):
        """Test ensure_dir creates directory."""
        new_dir = tmp_path / "new" / "nested" / "dir"
        result = ensure_dir(new_dir)
        assert new_dir.exists()
        assert result == new_dir

    def test_ensure_dir_existing_directory(self, tmp_path):
        """Test ensure_dir with existing directory."""
        existing = tmp_path / "existing"
        existing.mkdir()
        result = ensure_dir(existing)
        assert result == existing

    def test_ensure_dir_returns_same_path(self, tmp_path):
        """Test ensure_dir returns the same path passed."""
        path = tmp_path / "test"
        result = ensure_dir(path)
        assert result is path


class TestSaveJson:
    """Tests for save_json function."""

    def test_save_json_creates_file(self, tmp_path):
        """Test save_json creates a file with correct content."""
        data = {"key": "value", "number": 42}
        filepath = tmp_path / "output.json"
        result = save_json(data, filepath)

        assert filepath.exists()
        assert result == filepath
        loaded = json.loads(filepath.read_text())
        assert loaded == data

    def test_save_json_creates_parent_dirs(self, tmp_path):
        """Test save_json creates parent directories."""
        data = {"test": "data"}
        filepath = tmp_path / "a" / "b" / "c.json"
        save_json(data, filepath)
        assert filepath.exists()

    def test_save_json_with_custom_indent(self, tmp_path):
        """Test JSON indentation."""
        data = {"level1": {"level2": {"level3": "value"}}}
        filepath = tmp_path / "out.json"
        save_json(data, filepath, indent=4)
        content = filepath.read_text()
        # Check that indentation is present (spaces before level3)
        assert "    " in content

    def test_save_json_serializes_non_standard_types(self, tmp_path):
        """Test that non-standard types use default=str."""
        from datetime import datetime
        data = {"timestamp": datetime(2024, 1, 1, 12, 0, 0)}
        filepath = tmp_path / "out.json"
        save_json(data, filepath)
        # Should not raise
        assert filepath.exists()


class TestLoadJson:
    """Tests for load_json function."""

    def test_load_json_valid_file(self, tmp_path):
        """Test loading valid JSON file."""
        data = {"test": "value", "nested": {"key": 123}}
        path = tmp_path / "data.json"
        path.write_text(json.dumps(data))

        result = load_json(path)
        assert result == data

    def test_load_json_missing_file_required(self, tmp_path):
        """Test missing required file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            load_json(tmp_path / "missing.json", required=True)

    def test_load_json_missing_file_optional(self, tmp_path, caplog):
        """Test missing optional file returns empty dict."""
        result = load_json(tmp_path / "missing.json", required=False)
        assert result == {}

    def test_load_json_invalid_json(self, tmp_path):
        """Test invalid JSON raises JSONDecodeError."""
        path = tmp_path / "bad.json"
        path.write_text("{invalid json")

        with pytest.raises(json.JSONDecodeError):
            load_json(path)


class TestSaveResultJson:
    """Tests for save_result_json function."""

    def test_save_result_json_without_category(self, tmp_path):
        """Test save_result_json creates timestamped file without category."""
        data = {"result": "test"}
        output_dir = tmp_path / "output"
        result = save_result_json(data, "test_result", output_dir=output_dir)

        assert result.parent == output_dir
        assert result.name.startswith("test_result_")
        assert result.name.endswith(".json")
        assert result.exists()

    def test_save_result_json_with_category(self, tmp_path):
        """Test save_result_json creates subdirectory when category provided."""
        data = {"status": "ok"}
        output_dir = tmp_path / "output"
        result = save_result_json(data, "result", output_dir=output_dir, category="builds")

        assert result.parent == output_dir / "builds"
        assert result.name.startswith("result_")
        assert result.exists()

    def test_save_result_json_content(self, tmp_path):
        """Test saved JSON content is correct."""
        data = {"key": "value", "count": 42}
        output_dir = tmp_path / "out"
        result = save_result_json(data, "test", output_dir=output_dir)

        loaded = json.loads(result.read_text())
        assert loaded == data
