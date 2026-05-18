"""Tests for automation.cli.patch_windows_security module."""

import json
from unittest.mock import patch

from automation.cli.patch_windows_security import WindowsPatcher


class TestWindowsPatcher:
    """Tests for WindowsPatcher class."""

    def test_initialization(self, tmp_path):
        """Test WindowsPatcher initialization."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        output_dir = tmp_path / "patched_output"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), output_dir=str(output_dir))

        assert patcher.patches_config_path == patches_config
        assert patcher.output_dir == output_dir
        assert output_dir.exists()

    def test_load_config(self, tmp_path):
        """Test _load_config loads patches configuration."""
        config_data = {
            "patches": [
                {"kb_number": "KB123456", "severity": "Critical"},
                {"kb_number": "KB789012", "severity": "Important"},
            ]
        }
        config_path = tmp_path / "patches.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(config_path))

        assert patcher.patches_config == config_data

    def test_setup_base_iso_missing_iso(self, tmp_path):
        """Test _setup_base_iso fails when ISO file not found."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._setup_base_iso("/nonexistent/path/iso.iso", dry_run=False)
        assert result is None

    def test_setup_base_iso_dry_run(self, tmp_path):
        """Test _setup_base_iso returns base_dir in dry-run mode."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._setup_base_iso("/any/path.iso", dry_run=True)
        assert result == base_iso_dir

    def test_apply_patches_dism_dry_run(self, tmp_path):
        """Test _apply_patches_dism in dry-run mode."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"
        base_iso_dir.mkdir()
        patch_dir = base_iso_dir / "patches"
        patch_dir.mkdir()

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._apply_patches_dism(dry_run=True)
        assert result is True

    def test_apply_patches_dism_with_missing_patch(self, tmp_path, caplog):
        """Test _apply_patches_dism skips missing patch files."""
        config_data = {"patches": [{"kb_number": "KB123456", "severity": "Critical"}]}
        patches_config = tmp_path / "patches.json"
        patches_config.write_text(json.dumps(config_data))
        base_iso_dir = tmp_path / "base_iso"
        (base_iso_dir / "patches").mkdir(parents=True)
        # No actual .msu file present

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._apply_patches_dism(dry_run=False)
        # Should succeed because missing patch is just skipped with warning
        assert result is True

    def test_apply_patches_powershell_dry_run(self, tmp_path):
        """Test _apply_patches_powershell in dry-run mode."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"
        base_iso_dir.mkdir()

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._apply_patches_powershell(dry_run=True)
        assert result is True

    def test_apply_patches_powershell_skipped(self, tmp_path, caplog):
        """Test _apply_patches_powershell returns True (skipped)."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"
        base_iso_dir.mkdir()

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir))

        result = patcher._apply_patches_powershell(dry_run=False)
        # Method is not fully implemented; returns True
        assert result is True

    def test_build_dry_run(self, tmp_path):
        """Test complete build in dry-run mode."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        output_dir = tmp_path / "output"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), output_dir=str(output_dir))

        result = patcher.build("/path/to/base.iso", "test-server", dry_run=True)

        assert result["success"] is True
        assert result["server"] == "test-server"
        assert result["patched_iso"] is not None
        assert "dryrun" in result["patched_iso"]

    def test_build_missing_base_iso(self, tmp_path):
        """Test build fails when base ISO not found."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"
        base_iso_dir.mkdir()
        output_dir = tmp_path / "output"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir), output_dir=str(output_dir))

        result = patcher.build("/nonexistent/iso.iso", "test-server", dry_run=False)

        assert result["success"] is False
        assert result["patched_iso"] is None

    def test_build_unknown_method(self, tmp_path):
        """Test build with unknown method returns failure."""
        patches_config = tmp_path / "patches.json"
        patches_config.write_text('{"patches": []}')
        base_iso_dir = tmp_path / "base_iso"
        base_iso_dir.mkdir(parents=True)
        (base_iso_dir / "base.iso").touch()
        output_dir = tmp_path / "output"

        with patch("automation.utils.logging_setup.init_logging"):
            patcher = WindowsPatcher(str(patches_config), base_iso_dir=str(base_iso_dir), output_dir=str(output_dir))

        result = patcher.build(str(base_iso_dir / "base.iso"), "server1", method="unknown")

        assert result["success"] is False
