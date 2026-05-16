"""Credential and environment variable management.

Resolution order for every credential  (most-specific → most-generic):

1. Environment variable      (set by Jenkins, shell, or CyberArk bootstrap step)
2. CyberArk CLI / REST API  (new — tried automatically when env var is absent)
3. Default value            (always last; defaults are intentionally empty or
                             low-privilege so  secrets are never silently absent)

CyberArk integration rules
--------------------------
* CyberArk secrets are referenced in config JSON files as placeholders of the
  form  ``"${ENV_VAR_NAME}"``.  ``Import-JsonConfig`` / ``Import-JsonConfig``
  expand those at config-load time.
* The resolution functions below call ``_cyberark_fetch()`` whenever a required
  credential is empty and a CyberArk provider is configured.
* The CyberArk provider is detected automatically in this order:
    1. ``ark_ccl`` / ``ark_cc`` on PATH  (CyberArk Central Credential Provider CLI)
    2. ``AIM_WEBSERVICE_URL`` environment variable  (REST API URL)
* The REST API call uses the standard CCP query-string interface:
    ``GET /AIMWebService/API/Accounts?AppID=…&Query=Safe=…;Object=…``
  Authentication is via the CCP cert configured on the agent.
"""

import json
import logging
import os
import subprocess
from typing import Optional, Tuple

import urllib.request
import urllib.error

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# CyberArk helpers
# ---------------------------------------------------------------------------

def _cyberark_fetch(safe_name: str, object_name: str,
                    app_id: str = "jenkins") -> Optional[Tuple[str, str]]:
    """Retrieve (username, password) from CyberArk CCP.

    Tries in order:
    1. ``ark_ccl`` / ``ark_cc`` CLI on PATH.
    2. AIM Web Service REST API (``AIM_WEBSERVICE_URL`` env var or default).

    Returns ``(username, password)`` tuple on success, ``None`` on any failure
    (caller falls back silently to env-var or default).
    """
    # ── Method 1: CLI ────────────────────────────────────────────────────────
    for cli_name in ("ark_ccl", "ark_cc", "CyberArk.CLI"):
        try:
            result = subprocess.run(
                [cli_name, "getpassword",
                 f"-pAppID={app_id}",
                 f"-pSafe={safe_name}",
                 f"-pObject={object_name}"],
                capture_output=True, text=True, timeout=15,
            )
            if result.returncode == 0 and result.stdout.strip():
                # CCP CLI returns:  username\npassword  (or key=value pairs)
                parts = result.stdout.strip().splitlines()
                user = parts[0].strip() if parts else ""
                pwd  = parts[1].strip() if len(parts) > 1 else ""
                if user:
                    return user, pwd
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue

    # ── Method 2: REST API ───────────────────────────────────────────────────
    aim_url = (os.environ.get("AIM_WEBSERVICE_URL")
               or os.environ.get("CYBERARK_CCP_URL")
               or "https://cyberark-ccp:443/AIMWebService/API/Accounts")
    query = f"Safe={safe_name};Object={object_name}"
    full_url = f"{aim_url}?AppID={app_id}&Query={query}"
    try:
        req = urllib.request.Request(
            full_url,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = json.loads(resp.read().decode("utf-8"))
        # Standard CCP response:  [{"UserName":"…","Content":"…"}, …]
        items = raw if isinstance(raw, list) else [raw]
        item  = items[0]
        user  = item.get("UserName", "")
        pwd   = item.get("Content", "")
        return user if user else None
    except Exception as exc:
        logger.debug("CyberArk REST fetch failed for %s/%s: %s", safe_name, object_name, exc)
        return None


# ---------------------------------------------------------------------------
# Generic env-var + CyberArk resolver
# ---------------------------------------------------------------------------

def _resolve(var_name: str, safe_name: str, object_name: str,
             default: Optional[str] = None, required: bool = False) -> str:
    """Return credential value, trying env var → CyberArk → default."""
    # 1. Environment variable  (always preferred; Jenkins pre-fetches from CyberArk)
    val = os.environ.get(var_name)
    if val:
        return val

    # 2. CyberArk CCP (only attempted when variable is absent)
    cyber_pair = _cyberark_fetch(safe_name, object_name)
    if cyber_pair:
        logger.info("CyberArk supplied %s from safe=%s object=%s", var_name, safe_name, object_name)

    if cyber_pair:
        username = cyber_pair[0]
        password = cyber_pair[1]
        # Set env var so subsequent calls in the same process are cheap
        os.environ[var_name] = username if var_name.endswith(("_USER", "_ID", "_CLIENT_ID")) else password
        return username if var_name.endswith(("_USER", "_ID", "_CLIENT_ID")) else password

    # 3. Default
    if default is not None:
        return default

    if required:
        raise ValueError(f"Required credential '{var_name}' not found in environment "
                         f"or CyberArk (safe={safe_name}, object={object_name}).")
    return ""


# ---------------------------------------------------------------------------
# Public API — mirrors original interface exactly
# ---------------------------------------------------------------------------

def get_credential(env_var_name: str, default: Optional[str] = None,
                   required: bool = False) -> Optional[str]:
    """Fetch a credential from an environment variable.

    Args:
        env_var_name: Environment variable name
        default:  Default value if not set
        required: If True, raise ValueError when missing
    """
    return _resolve(env_var_name, safe_name="Jenkins", object_name=env_var_name,
                    default=default, required=required)


def get_ilo_credentials(
    username_env: str = "ILO_USER",
    password_env: str = "ILO_PASSWORD",
    default_username: str = "Administrator",
    default_password: str = "",
) -> Tuple[str, str]:
    """Get iLO credentials.  Tries env var → CyberArk → default."""
    username = _resolve(username_env, safe_name="HPE-iLO",   object_name=username_env,
                        default=default_username, required=False)
    password = _resolve(password_env, safe_name="HPE-iLO",   object_name=password_env,
                        default=default_password, required=False)
    return username, password


def get_scom_credentials(
    username_env: str = "SCOM_ADMIN_USER",
    password_env: str = "SCOM_ADMIN_PASSWORD",
) -> Tuple[str, str]:
    """Get SCOM admin credentials.  Tries env var → CyberArk → required."""
    username = _resolve(username_env, safe_name="SCOM-2015", object_name=username_env,
                        required=True)
    password = _resolve(password_env, safe_name="SCOM-2015", object_name=password_env,
                        required=True)
    return username, password


def get_openview_credentials(
    user_env: str = "OPENVIEW_USER",
    pass_env: str = "OPENVIEW_PASSWORD",
) -> Tuple[str, str]:
    """Get OpenView API credentials.  Tries env var → CyberArk → default."""
    return (_resolve(user_env,  safe_name="OpenView", object_name=user_env),
            _resolve(pass_env, safe_name="OpenView", object_name=pass_env))


def get_smtp_credentials(
    user_env: str = "SMTP_USER",
    pass_env: str = "SMTP_PASSWORD",
) -> Tuple[Optional[str], Optional[str]]:
    """Get SMTP credentials (optional).  Tries env var → CyberArk → None."""
    return (_resolve(user_env, safe_name="SMTP-Mail", object_name=user_env, default=""),
            _resolve(pass_env, safe_name="SMTP-Mail", object_name=pass_env, default=""))
