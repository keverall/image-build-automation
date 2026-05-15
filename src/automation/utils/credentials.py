"""Credential and environment variable management."""

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


def get_credential(env_var_name: str, default: Optional[str] = None, required: bool = False) -> Optional[str]:
    """
    Fetch a credential from an environment variable.

    Args:
        env_var_name: Environment variable name
        default: Default value if not set
        required: If True, raise error when missing

    Returns:
        Credential value or None

    Raises:
        ValueError: If required=True and env var not set
    """
    value = os.environ.get(env_var_name, default)
    if required and not value:
        raise ValueError(f"Required environment variable '{env_var_name}' is not set")
    return value


def get_ilo_credentials(
    username_env: str = "ILO_USER",
    password_env: str = "ILO_PASSWORD",
    default_username: str = "Administrator",
    default_password: str = "",
) -> tuple[str, str]:
    """
    Get iLO credentials from environment.

    Returns:
        (username, password) tuple
    """
    username = get_credential(username_env, default=default_username, required=False)
    password = get_credential(password_env, default=default_password, required=False)
    return username, password


def get_scom_credentials(
    username_env: str = "SCOM_ADMIN_USER", password_env: str = "SCOM_ADMIN_PASSWORD"
) -> tuple[str, str]:
    """Get SCOM admin credentials from environment."""
    return get_credential(username_env, required=True), get_credential(password_env, required=True)


def get_openview_credentials(user_env: str = "OPENVIEW_USER", pass_env: str = "OPENVIEW_PASSWORD") -> tuple[str, str]:
    """Get OpenView API credentials from environment."""
    return get_credential(user_env, required=False), get_credential(pass_env, required=False)


def get_smtp_credentials(
    user_env: str = "SMTP_USER", pass_env: str = "SMTP_PASSWORD"
) -> tuple[Optional[str], Optional[str]]:
    """Get SMTP credentials (optional)."""
    return get_credential(user_env, required=False), get_credential(pass_env, required=False)
