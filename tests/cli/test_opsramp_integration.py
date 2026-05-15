"""Tests for automation.cli.opsramp_integration module."""

import json
from datetime import datetime
from unittest.mock import MagicMock, patch

from automation.cli.opsramp_integration import OpsRampClient


class TestOpsRampClient:
    """Tests for OpsRampClient class."""

    def test_initialization(self, tmp_path):
        """Test OpsRampClient initialization."""
        config_data = {
            "opsramp_api": {"base_url": "https://api.opsramp.com", "version": "v2"},
            "credentials": {"client_id": "test_client", "client_secret": "test_secret", "tenant_id": "tenant123"},
        }
        config_path = tmp_path / "opsramp_config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_requests.post.return_value.raise_for_status.return_value = None
            mock_requests.post.return_value.json.return_value = {"access_token": "token123", "expires_in": 3600}
            client = OpsRampClient(str(config_path))

        assert client.base_url == "https://api.opsramp.com"
        assert client.api_version == "v2"

    def test_load_config_from_file(self, tmp_path):
        """Test loading configuration from file."""
        config_data = {
            "opsramp_api": {"base_url": "https://test.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret", "tenant_id": "tenant"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_requests.post.return_value.raise_for_status.return_value = None
            mock_requests.post.return_value.json.return_value = {"access_token": "token", "expires_in": 3600}
            client = OpsRampClient(str(config_path))

        assert client.config == config_data

    def test_load_config_env_override(self, tmp_path, monkeypatch):
        """Test environment variables override file config."""
        monkeypatch.setenv("OPSRAMP_CLIENT_ID", "env_client_id")
        monkeypatch.setenv("OPSRAMP_CLIENT_SECRET", "env_secret")
        monkeypatch.setenv("OPSRAMP_TENANT_ID", "env_tenant")

        config_data = {
            "opsramp_api": {"base_url": "https://test.example.com"},
            "credentials": {"client_id": "file_id", "client_secret": "file_secret", "tenant_id": "file_tenant"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_requests.post.return_value.raise_for_status.return_value = None
            mock_requests.post.return_value.json.return_value = {"access_token": "token", "expires_in": 3600}
            client = OpsRampClient(str(config_path))

        creds = client.config.get("credentials", {})
        assert creds["client_id"] == "env_client_id"
        assert creds["client_secret"] == "env_secret"
        assert creds["tenant_id"] == "env_tenant"

    def test_get_token_url_construction(self, tmp_path):
        """Test _get_token_url builds correct URL."""
        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com/", "version": "v2/"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_requests.post.return_value.raise_for_status.return_value = None
            mock_requests.post.return_value.json.return_value = {"access_token": "t", "expires_in": 3600}
            client = OpsRampClient(str(config_path))

        token_url = client._get_token_url()
        assert token_url == "https://api.example.com/v2/oauth/token"

    def test_ensure_token_success(self, tmp_path):
        """Test _ensure_token successfully obtains token."""
        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret", "tenant_id": "tenant"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_response = MagicMock()
            mock_response.raise_for_status.return_value = None
            mock_response.json.return_value = {"access_token": "token123", "expires_in": 3600}
            mock_requests.post.return_value = mock_response

            client = OpsRampClient(str(config_path))
            result = client._ensure_token()

        assert result is True
        assert client.access_token == "token123"

    def test_ensure_token_missing_credentials(self, tmp_path):
        """Test _ensure_token fails with missing credentials."""
        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "", "client_secret": ""},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests"):
            client = OpsRampClient(str(config_path))
            result = client._ensure_token()

        assert result is False
        assert client.access_token is None

    def test_ensure_token_uses_existing_valid_token(self, tmp_path):
        """Test _ensure_token returns True when token still valid."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret", "tenant_id": "tenant"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            mock_response = MagicMock()
            mock_response.raise_for_status.return_value = None
            mock_response.json.return_value = {"access_token": "token123", "expires_in": 3600}
            mock_requests.post.return_value = mock_response

            client = OpsRampClient(str(config_path))
            client.access_token = "existing_token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)  # valid token

            result = client._ensure_token()

        assert result is True
        # Should not have called post (token fetch)
        mock_requests.post.assert_not_called()

    def test_send_metric_success(self, tmp_path):
        """Test send_metric successful."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com", "version": "v2"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            # Mock token endpoint response
            token_response = MagicMock()
            token_response.raise_for_status.return_value = None
            token_response.json.return_value = {"access_token": "token", "expires_in": 3600}
            mock_requests.post.return_value = token_response

            client = OpsRampClient(str(config_path))
            # Skip _ensure_token by setting token manually
            client.access_token = "token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)

            # Patch _make_request to avoid actual HTTP
            with patch.object(client, "_make_request", return_value={}) as mock_make:
                success = client.send_metric("resource123", "test.metric", 1.0)

        assert success is True
        mock_make.assert_called_once()
        # Verify endpoint
        args, kwargs = mock_make.call_args
        assert args[0] == "POST"
        assert args[1] == "/metrics"

    def test_send_alert_success(self, tmp_path):
        """Test send_alert successful."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            token_response = MagicMock()
            token_response.raise_for_status.return_value = None
            token_response.json.return_value = {"access_token": "token", "expires_in": 3600}
            mock_requests.post.return_value = token_response

            client = OpsRampClient(str(config_path))
            client.access_token = "token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)

            with patch.object(client, "_make_request", return_value={}) as mock_make:
                success = client.send_alert("res123", "test.alert", "WARNING", "Test alert")

        assert success is True
        mock_make.assert_called_once()
        args, _ = mock_make.call_args
        assert args[0] == "POST"
        assert args[1] == "/alerts"

    def test_send_event_success(self, tmp_path):
        """Test send_event successful."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            token_response = MagicMock()
            token_response.raise_for_status.return_value = None
            token_response.json.return_value = {"access_token": "token", "expires_in": 3600}
            mock_requests.post.return_value = token_response

            client = OpsRampClient(str(config_path))
            client.access_token = "token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)

            with patch.object(client, "_make_request", return_value={}) as mock_make:
                success = client.send_event("res123", "test.event", "Test event")

        assert success is True
        mock_make.assert_called_once()
        args, _ = mock_make.call_args
        assert args[0] == "POST"
        assert args[1] == "/events"

    def test_report_build_status_success(self, tmp_path):
        """Test report_build_status for successful build."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            token_response = MagicMock()
            token_response.raise_for_status.return_value = None
            token_response.json.return_value = {"access_token": "token", "expires_in": 3600}
            mock_requests.post.return_value = token_response

            client = OpsRampClient(str(config_path))
            client.access_token = "token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)

            # Patch _make_request to track calls
            with patch.object(client, "_make_request", return_value={}) as mock_make:
                build_data = {"success": True, "uuid": "uuid-123"}
                success = client.report_build_status("server1", build_data)

        assert success is True
        # Should have made 3 _make_request calls: metric (status), metric (timestamp), event
        assert mock_make.call_count == 3

    def test_report_build_status_failure(self, tmp_path):
        """Test report_build_status for failed build includes alert."""
        from datetime import timedelta

        config_data = {
            "opsramp_api": {"base_url": "https://api.example.com"},
            "credentials": {"client_id": "id", "client_secret": "secret"},
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data))

        with patch("automation.cli.opsramp_integration.requests") as mock_requests:
            token_response = MagicMock()
            token_response.raise_for_status.return_value = None
            token_response.json.return_value = {"access_token": "token", "expires_in": 3600}
            mock_requests.post.return_value = token_response

            client = OpsRampClient(str(config_path))
            client.access_token = "token"
            client.token_expiry = datetime.now() + timedelta(seconds=1000)

            with patch.object(client, "_make_request", return_value={}) as mock_make:
                build_data = {"success": False, "error": "Build failed"}
                success = client.report_build_status("server1", build_data)

        assert success is True
        # Should have made 4 _make_request calls: metric (0), metric (timestamp), alert, event
        assert mock_make.call_count == 4
