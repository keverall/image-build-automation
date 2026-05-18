"""Tests for automation.control module.

Covers:
  - Control.from_irequest() for maintenance enable / disable / validate
  - Control.from_irequest() with start/end date overrides
  - Control.from_irequest() with dry_run flag
  - Control.from_jenkins() runner path
  - Control.from_scheduler() maintenance_disable and other tasks
  - Control._validate() returning errors for invalid cluster_id
  - Control.run() returns structured error dict when validation fails
  - Control.run() propagates orchestrator result
  - run_irequest() / run_jenkins() / run_scheduler() convenience functions
"""

import json
from unittest.mock import MagicMock, patch

from automation.control import Control, run_irequest, run_jenkins, run_scheduler

# ── from_irequest ──────────────────────────────────────────────────────────────

class TestControlFromIrequest:
    """Tests for Control.from_irequest() class method."""

    def test_irequest_enable_defaults(self):
        """from_irequest with enable action and default start."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "enable"}
        ctrl = Control.from_irequest(form)
        assert ctrl.request_type == "maintenance_enable"
        assert ctrl.params["cluster_id"] == "TEST-CLUSTER"
        assert ctrl.params["start"] == "now"
        assert ctrl.params.get("end") is None
        assert ctrl.source == "irequest"
        assert ctrl.dry_run is False

    def test_irequest_enable_with_start_end(self):
        """from_irequest with explicit start and end times."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "enable", "start": "2025-06-01T09:00:00", "end": "2025-06-01T17:00:00"}
        ctrl = Control.from_irequest(form)
        assert ctrl.params["start"] == "2025-06-01T09:00:00"
        assert ctrl.params["end"] == "2025-06-01T17:00:00"

    def test_irequest_enable_with_dry_run(self):
        """from_irequest with dry_run=true."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "enable", "dry_run": "true"}
        ctrl = Control.from_irequest(form)
        assert ctrl.dry_run is True

    def test_irequest_disable(self):
        """from_irequest with disable action."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "disable"}
        ctrl = Control.from_irequest(form)
        assert ctrl.request_type == "maintenance_disable"

    def test_irequest_validate(self):
        """from_irequest with validate action."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "validate"}
        ctrl = Control.from_irequest(form)
        assert ctrl.request_type == "maintenance_validate"

    def test_irequest_empty_action_defaults_to_enable(self):
        """from_irequest with missing action defaults to enable."""
        form = {"cluster_id": "TEST-CLUSTER"}
        ctrl = Control.from_irequest(form)
        assert ctrl.request_type == "maintenance_enable"

    def test_irequest_empty_cluster_id(self):
        """from_irequest with empty cluster_id."""
        form = {"action": "enable"}
        ctrl = Control.from_irequest(form)
        assert ctrl.params["cluster_id"] == ""

    def test_irequest_source_tag(self):
        """from_irequest always tags source as irequest."""
        form = {"cluster_id": "X", "action": "enable"}
        ctrl = Control.from_irequest(form)
        assert ctrl.source == "irequest"

    def test_irequest_original_params_not_mutated(self):
        """from_irequest does not mutate the caller's form_data dict."""
        form = {"cluster_id": "TEST-CLUSTER", "action": "enable"}
        original = dict(form)
        _ = Control.from_irequest(form)
        assert form == original


# ── from_jenkins ───────────────────────────────────────────────────────────────

class TestControlFromJenkins:
    """Tests for Control.from_jenkins() class method."""

    def test_jenkins_stage_all(self):
        """from_jenkins with BUILD_STAGE=all maps to build_iso."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "all", "DRY_RUN": "false"})
        assert ctrl.request_type == "build_iso"
        assert ctrl.dry_run is False

    def test_jenkins_stage_firmware(self):
        """from_jenkins with BUILD_STAGE=firmware maps to update_firmware."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "firmware", "DRY_RUN": "false"})
        assert ctrl.request_type == "update_firmware"

    def test_jenkins_stage_windows(self):
        """from_jenkins with BUILD_STAGE=windows maps to patch_windows."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "windows", "DRY_RUN": "false"})
        assert ctrl.request_type == "patch_windows"

    def test_jenkins_stage_deploy(self):
        """from_jenkins with BUILD_STAGE=deploy maps to deploy."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "deploy", "DRY_RUN": "false"})
        assert ctrl.request_type == "deploy"

    def test_jenkins_dry_run_true(self):
        """from_jenkins with DRY_RUN=true enables dry_run."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "all", "DRY_RUN": "true"})
        assert ctrl.dry_run is True

    def test_jenkins_dry_run_case_insensitive(self):
        """from_jenkins DRY_RUN=TRUE/FALSE handled case-insensitively."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "all", "DRY_RUN": "TRUE"})
        assert ctrl.dry_run is True
        ctrl2 = Control.from_jenkins({"BUILD_STAGE": "all", "DRY_RUN": "FALSE"})
        assert ctrl2.dry_run is False

    def test_jenkins_source_tag(self):
        """from_jenkins always tags source as jenkins."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "all"})
        assert ctrl.source == "jenkins"


# ── from_scheduler ─────────────────────────────────────────────────────────────

class TestControlFromScheduler:
    """Tests for Control.from_scheduler() class method."""

    def test_scheduler_maintenance_disable(self):
        """from_scheduler with task=maintenance_disable."""
        ctrl = Control.from_scheduler({"task": "maintenance_disable", "cluster_id": "C1"})
        assert ctrl.request_type == "maintenance_disable"
        assert ctrl.params["cluster_id"] == "C1"

    def test_scheduler_build_firmware(self):
        """from_scheduler with task=build_firmware."""
        ctrl = Control.from_scheduler({"task": "build_firmware"})
        assert ctrl.request_type == "update_firmware"

    def test_scheduler_build_windows(self):
        """from_scheduler with task=build_windows."""
        ctrl = Control.from_scheduler({"task": "build_windows"})
        assert ctrl.request_type == "patch_windows"

    def test_scheduler_unknown_task_passthrough(self):
        """from_scheduler with unknown task passes through unchanged."""
        ctrl = Control.from_scheduler({"task": "some_unknown_task"})
        assert ctrl.request_type == "some_unknown_task"

    def test_scheduler_dry_run(self):
        """from_scheduler dry_run flag."""
        ctrl = Control.from_scheduler({"task": "maintenance_disable", "dry_run": "true"})
        assert ctrl.dry_run is True

    def test_scheduler_source_tag(self):
        """from_scheduler always tags source as scheduler."""
        ctrl = Control.from_scheduler({"task": "maintenance_disable"})
        assert ctrl.source == "scheduler"


# ── _validate ──────────────────────────────────────────────────────────────────

class TestControlValidate:
    """Tests for Control._validate() error detection."""

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_missing_cluster_id(self):
        """_validate returns error when cluster_id is missing."""
        ctrl = Control.__new__(Control)
        ctrl.request_type = "maintenance_enable"
        ctrl.params = {}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert any("cluster_id is required" in e for e in errors)

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_empty_cluster_id(self, tmp_path):
        """_validate returns error when cluster_id is empty string."""
        ctrl = Control.__new__(Control)
        ctrl.request_type = "maintenance_enable"
        ctrl.params = {"cluster_id": ""}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert any("cluster_id is required" in e for e in errors)

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_invalid_cluster_id(self, tmp_path):
        """_validate returns error when cluster_id not in catalogue."""
        configs_dir = tmp_path / "configs"
        configs_dir.mkdir()
        catalogue = {"clusters": {"OTHER": {"servers": [], "scom_group": "g", "ilo_addresses": {}}}}
        (configs_dir / "clusters_catalogue.json").write_text(json.dumps(catalogue))
        ctrl = Control.__new__(Control)
        ctrl.request_type = "maintenance_enable"
        ctrl.params = {"cluster_id": "NONEXISTENT"}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert any("Invalid cluster ID" in e for e in errors)

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_valid_cluster_id(self, tmp_path):
        """_validate returns empty list when cluster_id is valid."""
        configs_dir = tmp_path / "configs"
        configs_dir.mkdir()
        catalogue = {"clusters": {"TEST": {"servers": ["s1"], "scom_group": "g", "ilo_addresses": {"s1": "1.1.1.1"}}}}
        (configs_dir / "clusters_catalogue.json").write_text(json.dumps(catalogue))
        ctrl = Control.__new__(Control)
        ctrl.request_type = "maintenance_enable"
        ctrl.params = {"cluster_id": "TEST"}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert errors == []

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_missing_catalogue_file(self, tmp_path):
        """_validate handles missing catalogue file gracefully."""
        ctrl = Control.__new__(Control)
        ctrl.request_type = "maintenance_enable"
        ctrl.params = {"cluster_id": "ANY"}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert isinstance(errors, list)

    @patch.object(Control, "__init__", lambda self, *a, **kw: None)
    def test_validate_non_maintenance_types_skip_cluster_check(self):
        """_validate skips cluster check for non-maintenance request types."""
        ctrl = Control.__new__(Control)
        ctrl.request_type = "build_iso"
        ctrl.params = {"base_iso": "/path/to.iso"}
        ctrl._orchestrator = None
        errors = ctrl._validate()
        assert isinstance(errors, list)


# ── run ────────────────────────────────────────────────────────────────────────

class TestControlRun:
    """Tests for Control.run()."""

    def test_run_returns_structured_result(self):
        """run() returns dict with expected keys."""
        control = Control.__new__(Control)
        control.request_type = "build_iso"
        control.params = {}
        control.source = "test"
        control.dry_run = False
        control._orchestrator = MagicMock()
        control._orchestrator.execute.return_value = {"success": True, "output": "done"}
        with patch.object(control, "_validate", return_value=None):
            result = control.run()
        assert result["success"] is True
        assert "source" in result
        assert result["source"] == "test"
        assert "timestamp" in result

    def test_run_validation_failure_returns_error(self):
        """run() returns error dict when _validate fails."""
        control = Control(request_type="maintenance_enable", params={"cluster_id": "BAD"}, source="api")
        errors = ["Invalid cluster ID: BAD"]
        with patch.object(control, "_validate", return_value=errors):
            result = control.run()
        assert result["success"] is False
        assert result["errors"] == errors
        assert result["source"] == "api"

    def test_run_preserves_source_tag(self):
        """run() result includes the source tag set in the constructor."""
        control = Control.__new__(Control)
        control.request_type = "build_iso"
        control.params = {}
        control.source = "jenkins"
        control.dry_run = False
        control._orchestrator = MagicMock()
        control._orchestrator.execute.return_value = {"success": True, "output": "ok"}
        with patch.object(control, "_validate", return_value=None):
            result = control.run()
        assert result["source"] == "jenkins"


# ── convenience functions ──────────────────────────────────────────────────────

class TestConvenienceFunctions:
    """Tests for run_irequest, run_jenkins, run_scheduler."""

    def test_run_irequest_calls_from_irequest(self):
        """run_irequest delegates to Control.from_irequest."""
        form = {"cluster_id": "X", "action": "enable"}
        mock_result = {"success": True}
        with patch("automation.control.Control.from_irequest") as mock_from:
            mock_ctrl = MagicMock()
            mock_ctrl.run.return_value = mock_result
            mock_from.return_value = mock_ctrl
            result = run_irequest(form)
        mock_from.assert_called_once_with(form)
        mock_ctrl.run.assert_called_once()
        assert result == mock_result

    def test_run_jenkins_calls_from_jenkins(self):
        """run_jenkins delegates to Control.from_jenkins."""
        params = {"BUILD_STAGE": "all"}
        mock_result = {"success": True}
        with patch("automation.control.Control.from_jenkins") as mock_from:
            mock_ctrl = MagicMock()
            mock_ctrl.run.return_value = mock_result
            mock_from.return_value = mock_ctrl
            result = run_jenkins(params)
        mock_from.assert_called_once_with(params)
        mock_ctrl.run.assert_called_once()
        assert result == mock_result

    def test_run_scheduler_calls_from_scheduler(self):
        """run_scheduler delegates to Control.from_scheduler."""
        params = {"task": "maintenance_disable"}
        mock_result = {"success": True}
        with patch("automation.control.Control.from_scheduler") as mock_from:
            mock_ctrl = MagicMock()
            mock_ctrl.run.return_value = mock_result
            mock_from.return_value = mock_ctrl
            result = run_scheduler(params)
        mock_from.assert_called_once_with(params)
        mock_ctrl.run.assert_called_once()
        assert result == mock_result


# ── edge cases ─────────────────────────────────────────────────────────────────

class TestControlEdgeCases:
    """Edge case tests for Control."""

    def test_irequest_no_action_key(self):
        """from_irequest when action key is missing defaults to enable."""
        form = {"cluster_id": "TEST"}
        ctrl = Control.from_irequest(form)
        assert ctrl.request_type == "maintenance_enable"

    def test_irequest_dry_run_false_string(self):
        """from_irequest dry_run='false' string is treated as False."""
        form = {"cluster_id": "TEST", "action": "enable", "dry_run": "false"}
        ctrl = Control.from_irequest(form)
        assert ctrl.dry_run is False

    def test_irequest_dry_run_true_string(self):
        """from_irequest dry_run='true' string is treated as True."""
        form = {"cluster_id": "TEST", "action": "enable", "dry_run": "true"}
        ctrl = Control.from_irequest(form)
        assert ctrl.dry_run is True

    def test_irequest_dry_run_boolean_value(self):
        """from_irequest dry_run as Python bool True/False."""
        form = {"cluster_id": "TEST", "action": "enable", "dry_run": True}
        ctrl = Control.from_irequest(form)
        assert ctrl.dry_run is True

    def test_irequest_no_end_none(self):
        """from_irequest without end sets it to None."""
        form = {"cluster_id": "TEST", "action": "enable", "start": "now"}
        ctrl = Control.from_irequest(form)
        assert ctrl.params.get("end") is None

    def test_jenkins_unknown_stage_defaults_to_build_iso(self):
        """from_jenkins with unknown BUILD_STAGE falls through to build_iso."""
        ctrl = Control.from_jenkins({"BUILD_STAGE": "nonexistent_stage"})
        assert ctrl.request_type == "build_iso"

    def test_scheduler_dry_run_missing_defaults_false(self):
        """from_scheduler with no dry_run defaults to False."""
        ctrl = Control.from_scheduler({"task": "maintenance_disable"})
        assert ctrl.dry_run is False
