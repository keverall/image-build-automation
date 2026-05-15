"""Tests for automation.core.validators module."""

import json

from automation.core.validators import (
    validate_build_params,
    validate_cluster_id,
    validate_server_list,
)


class TestValidateClusterId:
    """Tests for validate_cluster_id function."""

    def test_validate_cluster_id_empty_cluster_id(self, tmp_path, caplog):
        """Test with empty cluster_id returns None."""
        result = validate_cluster_id("", catalogue_path=tmp_path / "dummy.json")
        assert result is None

    def test_validate_cluster_id_missing_catalogue(self, tmp_path, caplog):
        """Test when catalogue file does not exist."""
        result = validate_cluster_id("TEST-CLUSTER", catalogue_path=tmp_path / "missing.json")
        assert result is None

    def test_validate_cluster_id_cluster_not_found(self, tmp_path, caplog):
        """Test when cluster_id is not in catalogue."""
        catalogue = {"clusters": {"OTHER-CLUSTER": {"servers": [], "scom_group": "test", "ilo_addresses": {}}}}
        catalogue_path = tmp_path / "catalogue.json"
        catalogue_path.write_text(json.dumps(catalogue))

        result = validate_cluster_id("TEST-CLUSTER", catalogue_path=catalogue_path)
        assert result is None

    def test_validate_cluster_id_success(self, tmp_path, caplog):
        """Test successful validation returns cluster definition."""
        cluster_def = {
            "servers": ["server1", "server2"],
            "scom_group": "TestGroup",
            "ilo_addresses": {"server1": "192.168.1.1"},
        }
        catalogue = {"clusters": {"TEST-CLUSTER": cluster_def}}
        catalogue_path = tmp_path / "catalogue.json"
        catalogue_path.write_text(json.dumps(catalogue))

        result = validate_cluster_id("TEST-CLUSTER", catalogue_path=catalogue_path)
        assert result == cluster_def

    def test_validate_cluster_id_missing_required_fields(self, tmp_path, caplog):
        """Test cluster definition missing required fields."""
        cluster_def = {"servers": ["server1"]}  # missing scom_group, ilo_addresses
        catalogue = {"clusters": {"TEST-CLUSTER": cluster_def}}
        catalogue_path = tmp_path / "catalogue.json"
        catalogue_path.write_text(json.dumps(catalogue))

        result = validate_cluster_id("TEST-CLUSTER", catalogue_path=catalogue_path)
        assert result is None


class TestValidateServerList:
    """Tests for validate_server_list function."""

    def test_validate_server_list_missing_file(self, tmp_path, caplog):
        """Test when server list file does not exist."""
        result = validate_server_list(server_list_path=tmp_path / "missing.txt")
        assert result == []

    def test_validate_server_list_empty_file(self, tmp_path, caplog):
        """Test with empty server list file."""
        server_list_path = tmp_path / "servers.txt"
        server_list_path.write_text("")

        result = validate_server_list(server_list_path=server_list_path)
        assert result == []

    def test_validate_server_list_comments_only(self, tmp_path, caplog):
        """Test with only comment lines."""
        server_list_path = tmp_path / "servers.txt"
        server_list_path.write_text("# This is a comment\n# Another comment\n")

        result = validate_server_list(server_list_path=server_list_path)
        assert result == []

    def test_validate_server_list_simple_hostnames(self, tmp_path, caplog):
        """Test with simple hostname entries."""
        server_list_path = tmp_path / "servers.txt"
        server_list_path.write_text("server1.example.com\nserver2.example.com\n")

        result = validate_server_list(server_list_path=server_list_path)
        assert result == ["server1.example.com", "server2.example.com"]

    def test_validate_server_list_comma_separated(self, tmp_path, caplog):
        """Test with comma-separated format (hostname,ipmi,ilo)."""
        server_list_path = tmp_path / "servers.txt"
        server_list_path.write_text("server1.example.com,192.168.1.1,192.168.1.101\n")

        result = validate_server_list(server_list_path=server_list_path)
        assert result == ["server1.example.com"]

    def test_validate_server_list_mixed_format(self, tmp_path, caplog):
        """Test with mixed formats and whitespace."""
        server_list_path = tmp_path / "servers.txt"
        server_list_path.write_text(
            "server1.example.com\n"
            "server2.example.com, 10.0.0.1, 10.0.0.2\n"
            "  server3.example.com  \n"
            "# commented server\n"
            "server4\n"
        )

        result = validate_server_list(server_list_path=server_list_path)
        assert result == ["server1.example.com", "server2.example.com", "server3.example.com", "server4"]


class TestValidateBuildParams:
    """Tests for validate_build_params function."""

    def test_validate_build_params_no_params(self):
        """Test with no parameters (valid)."""
        errors = validate_build_params()
        assert errors == []

    def test_validate_build_params_valid_iso_path(self, tmp_path):
        """Test with valid base ISO path."""
        iso_path = tmp_path / "base.iso"
        iso_path.touch()

        errors = validate_build_params(base_iso_path=str(iso_path))
        assert errors == []

    def test_validate_build_params_invalid_iso_path(self, tmp_path):
        """Test with non-existent base ISO path."""
        iso_path = tmp_path / "missing.iso"

        errors = validate_build_params(base_iso_path=str(iso_path))
        assert len(errors) == 1
        assert "Base ISO not found" in errors[0]

    def test_validate_build_params_dry_run_only(self):
        """Test with only dry_run flag."""
        errors = validate_build_params(dry_run=True)
        assert errors == []
