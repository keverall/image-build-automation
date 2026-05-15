"""
Pytest configuration and fixtures for HPE Windows ISO Automation tests.

Fixtures provide:
- Isolated temporary directories for configs, logs, output
- Sample configuration data (clusters, server lists, etc.)
- Mocked environment variables for credentials
- Clean PYTHONPATH with src/ for imports
"""

import json
import sys
from pathlib import Path
from typing import Any

import pytest

# Add project src/ to Python path for all tests
project_root = Path(__file__).resolve().parent.parent
src_path = project_root / "src"
sys.path.insert(0, str(src_path))


@pytest.fixture
def test_configs_dir(tmp_path: Path) -> Path:
    """Create a temporary configs directory with minimal valid files."""
    configs_dir = tmp_path / "configs"
    configs_dir.mkdir()

    # Sample server_list.txt
    server_list = configs_dir / "server_list.txt"
    server_list.write_text("server1.example.com\nserver2.example.com,10.0.0.1,10.0.0.2\n")

    # Sample clusters_catalogue.json
    clusters = {
        "TEST-CLUSTER-01": {
            "display_name": "Test Cluster 01",
            "servers": ["server1.example.com", "server2.example.com"],
            "scom_group": "Test_SCOM_Group",
            "scom_management_server": "scom-test.example.com",
            "ilo_addresses": {
                "server1.example.com": "192.168.1.101",
                "server2.example.com": "192.168.1.102",
            },
            "openview_node_ids": {},
            "schedule": {
                "timezone": "Europe/Dublin",
                "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
                "work_start": "08:00",
                "work_end": "17:00",
            },
            "environment": "test",
        }
    }
    (configs_dir / "clusters_catalogue.json").write_text(json.dumps(clusters, indent=2))

    # Sample hpe_firmware_drivers_nov2025.json (minimal)
    hpe_config = {
        "hpe_repository_url": "https://test.example.com/repo",
        "hpe_repository_username": "${HPE_USER}",
        "hpe_repository_password": "${HPE_PASS}",
        "components": {"gen10_plus": {"firmware": [], "drivers": []}},
    }
    (configs_dir / "hpe_firmware_drivers_nov2025.json").write_text(json.dumps(hpe_config, indent=2))

    # Sample windows_patches.json (minimal)
    patches = {"patches": [{"kb_number": "KB0000001", "severity": "Critical"}]}
    (configs_dir / "windows_patches.json").write_text(json.dumps(patches, indent=2))

    # Sample scom_config.json
    scom_config = {
        "scom_2015": {
            "management_server": "scom-test.example.com",
            "module_name": "OperationsManager",
            "use_winrm": False,
            "credentials": {
                "username_env": "SCOM_ADMIN_USER",
                "password_env": "SCOM_ADMIN_PASSWORD",
            },
        }
    }
    (configs_dir / "scom_config.json").write_text(json.dumps(scom_config, indent=2))

    # Sample email_distribution_lists.json
    email_config = {
        "smtp": {"server": "smtp.test.example.com", "port": 25},
        "distribution_lists": {
            "maintenance_enable": ["test@example.com"],
            "maintenance_disable": ["test@example.com"],
        },
    }
    (configs_dir / "email_distribution_lists.json").write_text(json.dumps(email_config, indent=2))

    return configs_dir


@pytest.fixture
def test_logs_dir(tmp_path: Path) -> Path:
    """Create a temporary logs directory."""
    logs_dir = tmp_path / "logs"
    logs_dir.mkdir()
    return logs_dir


@pytest.fixture
def test_output_dir(tmp_path: Path) -> Path:
    """Create a temporary output directory."""
    output_dir = tmp_path / "output"
    output_dir.mkdir()
    return output_dir


@pytest.fixture
def mock_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set common environment variables for testing."""
    test_vars = {
        "HPE_DOWNLOAD_USER": "test_hpe_user",
        "HPE_DOWNLOAD_PASS": "test_hpe_pass",
        "ILO_USER": "test_ilo_user",
        "ILO_PASSWORD": "test_ilo_pass",
        "SCOM_ADMIN_USER": "test_scom_user",
        "SCOM_ADMIN_PASSWORD": "test_scom_pass",
        "OPENVIEW_USER": "test_ov_user",
        "OPENVIEW_PASSWORD": "test_ov_pass",
        "OPSRAMP_CLIENT_ID": "test_client_id",
        "OPSRAMP_CLIENT_SECRET": "test_client_secret",
        "OPSRAMP_TENANT_ID": "test_tenant_id",
    }
    for key, value in test_vars.items():
        monkeypatch.setenv(key, value)


@pytest.fixture
def sample_cluster_catalogue() -> dict[str, Any]:
    """Return a sample cluster catalogue dict for testing."""
    return {
        "clusters": {
            "TEST-CLUSTER-01": {
                "display_name": "Test Cluster 01",
                "servers": ["server1.example.com", "server2.example.com"],
                "scom_group": "Test_SCOM_Group",
                "scom_management_server": "scom-test.example.com",
                "ilo_addresses": {
                    "server1.example.com": "192.168.1.101",
                    "server2.example.com": "192.168.1.102",
                },
                "openview_node_ids": {},
                "schedule": {
                    "timezone": "Europe/Dublin",
                    "work_days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
                    "work_start": "08:00",
                    "work_end": "17:00",
                },
                "environment": "test",
            }
        }
    }


@pytest.fixture
def sample_server_list() -> list[str]:
    """Return a sample server list for testing."""
    return ["server1.example.com", "server2.example.com"]
