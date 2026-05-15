"""Tests for automation.utils.credentials module."""

import pytest

from automation.utils.credentials import (
    get_credential,
    get_ilo_credentials,
    get_openview_credentials,
    get_scom_credentials,
    get_smtp_credentials,
)


class TestGetCredential:
    """Tests for get_credential function."""

    def test_get_credential_from_environment(self, monkeypatch):
        """Test fetching credential from environment."""
        monkeypatch.setenv("TEST_VAR", "test_value")
        assert get_credential("TEST_VAR") == "test_value"

    def test_get_credential_with_default(self, monkeypatch):
        """Test returns default when env var not set."""
        monkeypatch.delenv("TEST_VAR", raising=False)
        assert get_credential("TEST_VAR", default="default_value") == "default_value"

    def test_get_credential_missing_required(self, monkeypatch):
        """Test raises ValueError for missing required credential."""
        monkeypatch.delenv("REQUIRED_VAR", raising=False)
        with pytest.raises(ValueError, match="Required environment variable"):
            get_credential("REQUIRED_VAR", required=True)

    def test_get_credential_returns_none_when_not_required(self, monkeypatch):
        """Test returns None when not required and not set."""
        monkeypatch.delenv("OPTIONAL_VAR", raising=False)
        assert get_credential("OPTIONAL_VAR", required=False) is None

    def test_get_credential_prefers_environment_over_default(self, monkeypatch):
        """Test environment value takes precedence over default."""
        monkeypatch.setenv("TEST_VAR", "env_value")
        assert get_credential("TEST_VAR", default="default_value") == "env_value"


class TestGetILOCredentials:
    """Tests for get_ilo_credentials function."""

    def test_get_ilo_credentials_from_env(self, monkeypatch):
        """Test fetching iLO credentials from environment."""
        monkeypatch.setenv("ILO_USER", "admin")
        monkeypatch.setenv("ILO_PASSWORD", "secret123")
        username, password = get_ilo_credentials()
        assert username == "admin"
        assert password == "secret123"

    def test_get_ilo_credentials_default_username(self, monkeypatch):
        """Test default username when env not set."""
        monkeypatch.delenv("ILO_USER", raising=False)
        monkeypatch.delenv("ILO_PASSWORD", raising=False)
        username, password = get_ilo_credentials()
        assert username == "Administrator"
        assert password == ""

    def test_get_ilo_credentials_custom_env_vars(self, monkeypatch):
        """Test with custom environment variable names."""
        monkeypatch.setenv("CUSTOM_ILO_USER", "custom_user")
        monkeypatch.setenv("CUSTOM_ILO_PASS", "custom_pass")
        username, password = get_ilo_credentials(username_env="CUSTOM_ILO_USER", password_env="CUSTOM_ILO_PASS")
        assert username == "custom_user"
        assert password == "custom_pass"


class TestGetSCOMCredentials:
    """Tests for get_scom_credentials function."""

    def test_get_scom_credentials_success(self, monkeypatch):
        """Test fetching SCOM credentials."""
        monkeypatch.setenv("SCOM_ADMIN_USER", "scom_user")
        monkeypatch.setenv("SCOM_ADMIN_PASSWORD", "scom_pass")
        username, password = get_scom_credentials()
        assert username == "scom_user"
        assert password == "scom_pass"

    def test_get_scom_credentials_required_missing(self, monkeypatch):
        """Test raises error when required SCOM credentials missing."""
        monkeypatch.delenv("SCOM_ADMIN_USER", raising=False)
        monkeypatch.delenv("SCOM_ADMIN_PASSWORD", raising=False)
        with pytest.raises(ValueError):
            get_scom_credentials()


class TestGetOpenViewCredentials:
    """Tests for get_openview_credentials function."""

    def test_get_openview_credentials_optional(self, monkeypatch):
        """Test OpenView credentials are optional."""
        monkeypatch.delenv("OPENVIEW_USER", raising=False)
        monkeypatch.delenv("OPENVIEW_PASSWORD", raising=False)
        username, password = get_openview_credentials()
        assert username is None
        assert password is None

    def test_get_openview_credentials_from_env(self, monkeypatch):
        """Test OpenView credentials from environment."""
        monkeypatch.setenv("OPENVIEW_USER", "ov_user")
        monkeypatch.setenv("OPENVIEW_PASSWORD", "ov_pass")
        username, password = get_openview_credentials()
        assert username == "ov_user"
        assert password == "ov_pass"


class TestGetSMTPCredentials:
    """Tests for get_smtp_credentials function."""

    def test_get_smtp_credentials_optional(self, monkeypatch):
        """Test SMTP credentials are optional."""
        monkeypatch.delenv("SMTP_USER", raising=False)
        monkeypatch.delenv("SMTP_PASSWORD", raising=False)
        username, password = get_smtp_credentials()
        assert username is None
        assert password is None
