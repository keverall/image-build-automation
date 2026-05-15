"""Tests for automation.utils.audit module."""

import json

from automation.utils.audit import AuditLogger, save_audit_record


class TestAuditLogger:
    """Tests for AuditLogger class."""

    def test_audit_logger_initialization(self, tmp_path):
        """Test AuditLogger initialization creates log directory."""
        log_dir = tmp_path / "logs"
        audit = AuditLogger(category="test", log_dir=log_dir)

        assert audit.category == "test"
        assert audit.log_dir == log_dir
        assert log_dir.exists()
        assert audit.entries == []

    def test_audit_logger_creates_master_log_on_append(self, tmp_path):
        """Test append_to_master creates master log file."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="test_action", status="INFO")
        audit.append_to_master()

        master_log = tmp_path / "logs" / "audit.log"
        assert master_log.exists()

    def test_log_adds_entry(self, tmp_path):
        """Test log method adds entry to in-memory list."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        entry = audit.log(action="start", status="INFO", server="srv1", details="test")

        assert len(audit.entries) == 1
        assert entry["action"] == "start"
        assert entry["status"] == "INFO"
        assert entry["server"] == "srv1"
        assert entry["category"] == "test"
        assert "timestamp" in entry

    def test_log_with_extra_fields(self, tmp_path):
        """Test log with additional custom fields."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        entry = audit.log(action="build", status="SUCCESS", extra_field="extra_value")

        assert entry["extra_field"] == "extra_value"

    def test_save_creates_json_file(self, tmp_path):
        """Test save creates a properly formatted JSON file."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="test", status="OK")
        filepath = audit.save()

        assert filepath.exists()
        content = filepath.read_text()
        data = json.loads(content)
        assert data["category"] == "test"
        assert "entries" in data
        assert len(data["entries"]) == 1

    def test_save_with_custom_filename(self, tmp_path):
        """Test save with custom filename."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="test", status="OK")
        filepath = audit.save(filename="custom_audit.json")

        assert filepath.name == "custom_audit.json"

    def test_save_then_append_rotates_logs(self, tmp_path):
        """Test that clearing entries after save allows rotation."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="first", status="OK")
        audit.save()
        audit.clear()

        # After clear, entries list is empty
        assert len(audit.entries) == 0

        # New log entry
        audit.log(action="second", status="OK")
        filepath = audit.save()
        # Both entries should be in the new file (we cleared but entries were added after clear)
        # Actually clear() empties the list, so new save only contains entries logged after clear
        data = json.loads(filepath.read_text())
        assert len(data["entries"]) == 1
        assert data["entries"][0]["action"] == "second"

    def test_append_to_master_appends_multiple_entries(self, tmp_path):
        """Test appending multiple entries to master log."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="first", status="OK")
        audit.log(action="second", status="OK")
        audit.append_to_master()

        master_log = tmp_path / "logs" / "audit.log"
        lines = master_log.read_text().strip().split("\n")
        assert len(lines) == 2
        assert json.loads(lines[0])["action"] == "first"
        assert json.loads(lines[1])["action"] == "second"

    def test_clear_empties_entries(self, tmp_path):
        """Test clear method empties the entries list."""
        audit = AuditLogger(category="test", log_dir=tmp_path / "logs")
        audit.log(action="test", status="OK")
        audit.clear()
        assert audit.entries == []


class TestSaveAuditRecord:
    """Tests for save_audit_record function."""

    def test_save_audit_record_creates_file(self, tmp_path):
        """Test save_audit_record creates audit file."""
        audit_data = {
            "cluster_id": "TEST-CLUSTER",
            "action": "enable",
            "success": True,
            "steps": {}
        }
        log_dir = tmp_path / "logs"
        filepath = save_audit_record(audit_data, log_dir=log_dir)

        assert filepath.exists()
        assert filepath.name.startswith("audit_")
        assert filepath.name.endswith(".json")

        loaded = json.loads(filepath.read_text())
        assert loaded["cluster_id"] == "TEST-CLUSTER"

    def test_save_audit_record_with_subdir(self, tmp_path):
        """Test save_audit_record creates subdirectory."""
        audit_data = {"action": "test"}
        log_dir = tmp_path / "logs"
        filepath = save_audit_record(audit_data, log_dir=log_dir, subdir="maintenance")

        assert filepath.parent == log_dir / "maintenance"
        assert filepath.exists()

    def test_save_audit_record_appends_to_master(self, tmp_path):
        """Test save_audit_record appends to master log."""
        log_dir = tmp_path / "logs"
        log_dir.mkdir()
        master_log = log_dir / "audit.log"

        audit_data = {"action": "test", "step": "start"}
        save_audit_record(audit_data, log_dir=log_dir)

        assert master_log.exists()
        lines = master_log.read_text().strip().split("\n")
        assert len(lines) == 1
        assert json.loads(lines[0])["action"] == "test"

    def test_save_audit_record_with_prefix(self, tmp_path):
        """Test save_audit_record with filename prefix."""
        audit_data = {"action": "test"}
        log_dir = tmp_path / "logs"
        filepath = save_audit_record(audit_data, log_dir=log_dir, prefix="enable_")

        assert filepath.name.startswith("enable_audit_")
