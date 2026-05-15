"""Tests for automation.core.orchestrator module."""

import json
from datetime import datetime
from unittest.mock import patch

from automation.core.orchestrator import AutomationOrchestrator


class TestAutomationOrchestrator:
    """Tests for AutomationOrchestrator class."""

    def test_init_creates_logs_directory(self, tmp_path):
        """Test that initialization creates logs directory."""
        logs_dir = tmp_path / "logs"
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=logs_dir, dry_run=False)

        assert logs_dir.exists()
        assert orchestrator.dry_run is False

    def test_init_with_dry_run(self):
        """Test initialization with dry_run enabled."""
        orchestrator = AutomationOrchestrator(dry_run=True)
        assert orchestrator.dry_run is True

    def test_execute_unknown_request_type(self, tmp_path):
        """Test execute with unknown request type."""
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=tmp_path / "logs")

        result = orchestrator.execute("unknown_request", {})

        assert result["success"] is False
        assert "error" in result or "errors" in result
        assert "timestamp" in result

    def test_execute_build_with_validation_errors(self, tmp_path):
        """Test execute with build request that fails validation."""
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=tmp_path / "logs")

        # Missing base_iso path should not cause validation error (it's optional)
        result = orchestrator.execute("build_iso", {})

        # Should proceed to routing; if configs missing, will fail there
        assert "timestamp" in result
        assert "request_type" in result
        assert result["request_type"] == "build_iso"

    def test_execute_maintenance_invalid_cluster(self, tmp_path):
        """Test execute with maintenance request and invalid cluster."""
        configs_dir = tmp_path / "configs"
        configs_dir.mkdir()
        (configs_dir / "clusters_catalogue.json").write_text('{"clusters": {}}')

        orchestrator = AutomationOrchestrator(config_dir=configs_dir, logs_dir=tmp_path / "logs")

        result = orchestrator.execute("maintenance_enable", {"cluster_id": "NONEXISTENT"})

        assert result["success"] is False
        errors = result.get("errors", [])
        assert any("Invalid cluster ID" in str(e) for e in errors)

    def test_execute_adds_dry_run_to_params(self, tmp_path):
        """Test that dry_run flag adds dry_run to params."""
        orchestrator = AutomationOrchestrator(dry_run=True)

        # Patch validation to bypass
        with (
            patch.object(orchestrator, "_validate", return_value=None),
            patch("automation.core.orchestrator.route_request") as mock_route,
        ):
            mock_route.return_value = {"success": True}
            orchestrator.execute("build_iso", {"base_iso": "/path/to.iso"})

            # Check that route_request was called with dry_run added
            mock_route.assert_called_once_with("build_iso", {"base_iso": "/path/to.iso", "dry_run": True})

    def test_execute_preserves_original_params(self, tmp_path):
        """Test that original params dict is not mutated."""
        orchestrator = AutomationOrchestrator(dry_run=False)
        original_params = {"base_iso": "/path/to.iso"}

        with patch("automation.core.router.route_request") as mock_route:
            mock_route.return_value = {"success": True}
            orchestrator.execute("build_iso", original_params)

        # Original params should not have dry_run added
        assert "dry_run" not in original_params

    def test_validate_method_build_params(self, tmp_path):
        """Test _validate method for build_iso request."""
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=tmp_path / "logs")

        errors = orchestrator._validate("build_iso", {"base_iso": "/nonexistent.iso"})
        assert len(errors) == 1
        assert "Base ISO not found" in errors[0]

    def test_validate_method_patch_windows(self, tmp_path):
        """Test _validate for patch_windows request."""
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=tmp_path / "logs")

        errors = orchestrator._validate("patch_windows", {"base_iso": "/missing.iso"})
        assert len(errors) == 1

    def test_validate_method_maintenance_valid_cluster(self, tmp_path):
        """Test _validate for maintenance with valid cluster."""
        configs_dir = tmp_path / "configs"
        configs_dir.mkdir()
        catalogue = {
            "clusters": {"TEST-CLUSTER": {"servers": ["s1"], "scom_group": "Group", "ilo_addresses": {"s1": "1.1.1.1"}}}
        }
        (configs_dir / "clusters_catalogue.json").write_text(json.dumps(catalogue))

        orchestrator = AutomationOrchestrator(config_dir=configs_dir, logs_dir=tmp_path / "logs")
        errors = orchestrator._validate("maintenance_enable", {"cluster_id": "TEST-CLUSTER"})

        assert errors == []

    def test_validate_method_maintenance_invalid_cluster(self, tmp_path):
        """Test _validate for maintenance with invalid cluster."""
        configs_dir = tmp_path / "configs"
        configs_dir.mkdir()
        (configs_dir / "clusters_catalogue.json").write_text('{"clusters": {}}')

        orchestrator = AutomationOrchestrator(config_dir=configs_dir, logs_dir=tmp_path / "logs")
        errors = orchestrator._validate("maintenance_enable", {"cluster_id": "BAD-CLUSTER"})

        assert len(errors) == 1
        assert "Invalid cluster ID" in errors[0]

    def test_execute_routing_result_includes_metadata(self, tmp_path):
        """Test that execute result includes timestamp and request_type."""
        orchestrator = AutomationOrchestrator(config_dir=tmp_path / "configs", logs_dir=tmp_path / "logs")

        with patch("automation.core.router.route_request") as mock_route:
            mock_route.return_value = {"success": True, "output": "test"}
            result = orchestrator.execute("build_iso", {})

        assert "timestamp" in result
        assert result["request_type"] == "build_iso"
        # Verify timestamp is valid ISO format
        datetime.fromisoformat(result["timestamp"])
