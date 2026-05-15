"""Tests for automation.utils.inventory module."""

import json

import pytest

from automation.utils.inventory import (
    ServerInfo,
    load_cluster_catalogue,
    load_server_list,
    validate_cluster_definition,
)


class TestServerInfo:
    """Tests for ServerInfo dataclass."""

    def test_server_info_name_property(self):
        """Test name property returns hostname without domain."""
        server = ServerInfo(hostname="server1.example.com")
        assert server.name == "server1"

    def test_server_info_name_single_label_hostname(self):
        """Test name property with single-label hostname."""
        server = ServerInfo(hostname="server1")
        assert server.name == "server1"

    def test_server_info_with_optional_fields(self):
        """Test ServerInfo with all optional fields."""
        server = ServerInfo(
            hostname="server1.example.com",
            ipmi_ip="192.168.1.100",
            ilo_ip="192.168.1.101",
            line_number=5
        )
        assert server.hostname == "server1.example.com"
        assert server.ipmi_ip == "192.168.1.100"
        assert server.ilo_ip == "192.168.1.101"
        assert server.line_number == 5


class TestLoadServerList:
    """Tests for load_server_list function."""

    def test_load_server_list_missing_file(self, tmp_path, caplog):
        """Test loading from non-existent file returns empty list."""
        result = load_server_list(tmp_path / "missing.txt", include_details=False)
        assert result == []

    def test_load_server_list_empty_file(self, tmp_path, caplog):
        """Test loading from empty file returns empty list."""
        path = tmp_path / "servers.txt"
        path.touch()
        result = load_server_list(path, include_details=False)
        assert result == []

    def test_load_server_list_simple_hostnames(self, tmp_path):
        """Test loading simple hostname list."""
        path = tmp_path / "servers.txt"
        path.write_text("server1\nserver2\nserver3\n")

        result = load_server_list(path, include_details=False)
        assert result == ["server1", "server2", "server3"]

    def test_load_server_list_with_details_simple(self, tmp_path):
        """Test loading with include_details=True for simple entries."""
        path = tmp_path / "servers.txt"
        path.write_text("server1\nserver2\n")

        result = load_server_list(path, include_details=True)
        assert len(result) == 2
        assert isinstance(result[0], ServerInfo)
        assert result[0].hostname == "server1"
        assert result[0].ipmi_ip is None
        assert result[0].ilo_ip is None

    def test_load_server_list_with_details_full_info(self, tmp_path):
        """Test loading with full IP address info."""
        path = tmp_path / "servers.txt"
        path.write_text("server1,192.168.1.1,192.168.2.1\n")

        result = load_server_list(path, include_details=True)
        assert len(result) == 1
        server = result[0]
        assert server.hostname == "server1"
        assert server.ipmi_ip == "192.168.1.1"
        assert server.ilo_ip == "192.168.2.1"
        assert server.line_number == 1

    def test_load_server_list_ignores_comments(self, tmp_path):
        """Test that comment lines are ignored."""
        path = tmp_path / "servers.txt"
        path.write_text(
            "# This is a comment\n"
            "server1\n"
            "# Another comment\n"
            "server2\n"
        )

        result = load_server_list(path, include_details=False)
        assert result == ["server1", "server2"]

    def test_load_server_list_ignores_blank_lines(self, tmp_path):
        """Test that blank lines are ignored."""
        path = tmp_path / "servers.txt"
        path.write_text("server1\n\nserver2\n\n\nserver3\n")

        result = load_server_list(path, include_details=False)
        assert result == ["server1", "server2", "server3"]

    def test_load_server_list_whitespace_trimming(self, tmp_path):
        """Test that whitespace is trimmed from entries."""
        path = tmp_path / "servers.txt"
        path.write_text("  server1  \n  server2,1.1.1.1,2.2.2.2  \n")

        result = load_server_list(path, include_details=False)
        assert result == ["server1", "server2"]

    def test_load_server_list_line_numbers_preserved(self, tmp_path):
        """Test that line numbers are tracked correctly in details mode."""
        path = tmp_path / "servers.txt"
        path.write_text(
            "# Comment on line 1\n"
            "server1\n"
            "server2\n"
        )

        result = load_server_list(path, include_details=True)
        assert result[0].line_number == 2
        assert result[1].line_number == 3


class TestLoadClusterCatalogue:
    """Tests for load_cluster_catalogue function."""

    def test_load_cluster_catalogue_missing_file(self, tmp_path):
        """Test loading missing required file raises error."""
        with pytest.raises(FileNotFoundError):
            load_cluster_catalogue(tmp_path / "missing.json")

    def test_load_cluster_catalogue_valid_file(self, tmp_path):
        """Test loading valid catalogue."""
        catalogue = {
            "clusters": {
                "CLUSTER-1": {"display_name": "Cluster 1"},
                "CLUSTER-2": {"display_name": "Cluster 2"},
            }
        }
        path = tmp_path / "catalogue.json"
        path.write_text(json.dumps(catalogue))

        result = load_cluster_catalogue(path)
        assert "CLUSTER-1" in result
        assert result["CLUSTER-1"]["display_name"] == "Cluster 1"

    def test_load_cluster_catalogue_empty_clusters(self, tmp_path, caplog):
        """Test catalogue with no clusters returns empty dict and logs warning."""
        catalogue = {"clusters": {}}
        path = tmp_path / "catalogue.json"
        path.write_text(json.dumps(catalogue))

        result = load_cluster_catalogue(path)
        assert result == {}


class TestValidateClusterDefinition:
    """Tests for validate_cluster_definition function."""

    def test_validate_cluster_definition_all_required_fields(self):
        """Test valid cluster definition passes."""
        cluster_def = {
            "display_name": "Test Cluster",
            "servers": ["server1", "server2"],
            "scom_group": "TestGroup",
            "environment": "test"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert errors == []

    def test_validate_cluster_definition_missing_display_name(self):
        """Test missing display_name field."""
        cluster_def = {
            "servers": ["server1"],
            "scom_group": "TestGroup",
            "environment": "test"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert "Missing required field 'display_name'" in errors[0]

    def test_validate_cluster_definition_missing_servers(self):
        """Test missing servers field."""
        cluster_def = {
            "display_name": "Test",
            "scom_group": "Group",
            "environment": "test"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert "Missing required field 'servers'" in errors[0]

    def test_validate_cluster_definition_servers_not_list(self):
        """Test servers field is not a list."""
        cluster_def = {
            "display_name": "Test",
            "servers": "not-a-list",
            "scom_group": "Group",
            "environment": "test"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert "'servers' must be a non-empty list" in errors[0]

    def test_validate_cluster_definition_servers_empty_list(self):
        """Test servers field is an empty list."""
        cluster_def = {
            "display_name": "Test",
            "servers": [],
            "scom_group": "Group",
            "environment": "test"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert "'servers' must be a non-empty list" in errors[0]

    def test_validate_cluster_definition_invalid_ilo_addresses_type(self):
        """Test ilo_addresses is not a dictionary."""
        cluster_def = {
            "display_name": "Test",
            "servers": ["server1"],
            "scom_group": "Group",
            "environment": "test",
            "ilo_addresses": "not-a-dict"
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert any("'ilo_addresses' must be a dictionary" in e for e in errors)

    def test_validate_cluster_definition_invalid_ilo_ip_type(self):
        """Test ilo_addresses contains non-string IP."""
        cluster_def = {
            "display_name": "Test",
            "servers": ["server1"],
            "scom_group": "Group",
            "environment": "test",
            "ilo_addresses": {"server1": 12345}  # IP should be string
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert any("Invalid iLO IP for server server1" in e for e in errors)

    def test_validate_cluster_definition_invalid_openview_type(self):
        """Test openview_node_ids is not a dictionary."""
        cluster_def = {
            "display_name": "Test",
            "servers": ["server1"],
            "scom_group": "Group",
            "environment": "test",
            "openview_node_ids": ["node1", "node2"]  # should be dict
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        assert any("'openview_node_ids' must be a dictionary" in e for e in errors)

    def test_validate_cluster_definition_multiple_errors(self):
        """Test multiple validation errors are reported."""
        cluster_def = {
            "servers": []  # missing display_name, scom_group, environment, plus empty servers
        }
        errors = validate_cluster_definition(cluster_def, "TEST")
        # Expected: 3 missing required fields + 1 for empty servers = 4 errors
        assert len(errors) == 4
