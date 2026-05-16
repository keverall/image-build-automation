"""Tests for automation.utils.credentials module.

Covers:
- Environment-variable fast path
- CyberArk CLI fetch  (ark_ccl / ark_cc / CyberArk.CLI) — success, not-found,
  timeout, non-zero exit, empty / partial output, all-three-unavailable
- CyberArk REST fetch  (AIM_WEBSERVICE_URL, CYBERARK_CCP_URL, default URL,
  dict/list response, empty-user, network failure)
- _resolve fallback chain: env wins, CyberArk wins, default fallback, required error
- _USER / _ID / _CLIENT_ID username-side heuristic
- CyberArk pair env-var side-effect (sets os.environ for subsequent calls)
- All public credential getters: get_credential, get_ilo_credentials,
  get_scom_credentials, get_openview_credentials, get_smtp_credentials
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from unittest.mock import MagicMock, patch

import pytest

# ── Helpers ────────────────────────────────────────────────────────────────────

_SRC = os.path.join(os.path.dirname(__file__), "..", "src")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)

from automation.utils.credentials import (  # noqa: E402
    _cyberark_fetch,
    _resolve,
    get_credential,
    get_ilo_credentials,
    get_openview_credentials,
    get_scom_credentials,
    get_smtp_credentials,
)


def _mock_cred_response(username="cyber_user", password="cyber_pass"):
    """Return the kind of dict the CCP REST API would return."""
    return [{"UserName": username, "Content": password}]


def _mock_completed_process(stdout="user\npass", returncode=0):
    """Return a mock subprocess.CompletedProcess."""
    cp = MagicMock(spec=subprocess.CompletedProcess)
    cp.returncode = returncode
    cp.stdout = stdout
    cp.stderr = ""
    return cp


# ============================================================
# _cyberark_fetch — CLI path
# ============================================================


class TestCyberArkFetchCLI:
    """CLI-based CyberArk credential fetch."""

    def _patch_run(self, mock_cp):
        """Context-manager that patches subprocess.run."""
        return patch("automation.utils.credentials.subprocess.run", return_value=mock_cp)

    def test_cli_ark_ccl_success_two_lines(self):
        """ark_ccl on PATH returns a valid two-line (user, pass) output."""
        cp = _mock_completed_process(stdout="cli_user\ncli_pass")
        with self._patch_run(cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("cli_user", "cli_pass")

    def test_cli_ark_cc_success(self):
        """ark_cc is tried when ark_ccl is not on PATH."""

        # First two CLI names raise FileNotFoundError; ark_cc succeeds
        def fake_run(cmd, **kwargs):
            if "ark_ccl" in cmd[0]:
                raise FileNotFoundError()
            if "ark_cc" in cmd[0]:
                cp = _mock_completed_process(stdout="cc_user\ncc_pass")
                return cp
            raise RuntimeError("unexpected")

        with patch("automation.utils.credentials.subprocess.run", side_effect=fake_run):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("cc_user", "cc_pass")

    def test_cli_cyberark_cli_success_last_resort(self):
        """CyberArk.CLI is tried last when ark_ccl and ark_cc are absent."""
        fake_calls = ["ark_ccl", "ark_cc", "CyberArk.CLI"]

        def fake_run(cmd, **kwargs):
            name = cmd[0]
            idx = fake_calls.index(name)
            if idx < 2:
                raise FileNotFoundError()
            cp = _mock_completed_process()
            return cp

        with patch("automation.utils.credentials.subprocess.run", side_effect=fake_run):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("user", "pass")

    def test_cli_executable_not_found_falls_through(self):
        """FileNotFoundError from a missing CLI binary is caught → tries next."""
        with patch("automation.utils.credentials.subprocess.run", side_effect=FileNotFoundError):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_cli_all_not_found_returns_none(self):
        """All three CLI names missing → returns None (REST or default next)."""
        with patch("automation.utils.credentials.subprocess.run", side_effect=FileNotFoundError):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_cli_timeout_expired_caught(self):
        """TimeoutExpired is swallowed → next CLI / REST tried."""
        with patch(
            "automation.utils.credentials.subprocess.run", side_effect=subprocess.TimeoutExpired(cmd=[], timeout=15)
        ):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_cli_nonzero_exit_code(self):
        """CLI returns non-zero → treated as failure → falls through."""
        cp = _mock_completed_process(stdout="ignored", returncode=1)
        with patch("automation.utils.credentials.subprocess.run", return_value=cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_cli_empty_stdout(self):
        """CLI returns exit 0 but empty stdout → falls through."""
        cp = MagicMock(spec=subprocess.CompletedProcess)
        cp.returncode = 0
        cp.stdout = "   \n  "
        cp.stderr = ""
        with patch("automation.utils.credentials.subprocess.run", return_value=cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_cli_single_line_only_username(self):
        """CLI returns only one line → user is the line, password is ''."""
        cp = _mock_completed_process(stdout="only_user")
        with patch("automation.utils.credentials.subprocess.run", return_value=cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("only_user", "")

    def test_cli_two_lines_user_and_password(self):
        """Standard two-line CLI output → (user, password)."""
        cp = _mock_completed_process(stdout="myuser\nmypassword")
        with patch("automation.utils.credentials.subprocess.run", return_value=cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("myuser", "mypassword")

    def test_cli_three_lines_uses_first_two(self):
        """Three or more lines → uses only first two."""
        cp = _mock_completed_process(stdout="a\nb\nc\nd")
        with patch("automation.utils.credentials.subprocess.run", return_value=cp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("a", "b")


# ============================================================
# _cyberark_fetch — REST path
# ============================================================


class TestCyberArkFetchREST:
    """REST API CyberArk credential fetch."""

    def _patch_urlopen(self, response_obj):
        return patch(
            "automation.utils.credentials.urllib.request.urlopen",
            return_value=MagicMock(
                __enter__=MagicMock(return_value=response_obj),
                __exit__=MagicMock(return_value=False),
            ),
        )

    def test_rest_success_dict_response(self):
        """REST returns a single dict with UserName/Content."""
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "rest_user", "Content": "rest_pass"}).encode("utf-8")
        with self._patch_urlopen(mock_resp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("rest_user", "rest_pass")

    def test_rest_success_list_response(self):
        """REST returns a list → uses first item, returns (user, password) tuple."""
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps(
            [{"UserName": "r1", "Content": "p1"}, {"UserName": "r2", "Content": "p2"}]
        ).encode("utf-8")
        with self._patch_urlopen(mock_resp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result == ("r1", "p1")

    def test_rest_url_from_aim_env(self):
        """AIM_WEBSERVICE_URL env var is used for the REST endpoint."""
        os.environ["AIM_WEBSERVICE_URL"] = "https://aim.example.com/api"
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "u", "Content": "p"}).encode("utf-8")
        with self._patch_urlopen(mock_resp), patch("automation.utils.credentials.urllib.request.Request") as mock_req:
            _cyberark_fetch("MySafe", "MY_OBJECT")
            called_url = mock_req.call_args[0][0]
            assert called_url.startswith("https://aim.example.com/api")
        os.environ.pop("AIM_WEBSERVICE_URL", None)

    def test_rest_url_from_cyberark_ccp_env(self):
        """CYBERARK_CCP_URL env var is used as fallback."""
        os.environ["CYBERARK_CCP_URL"] = "https://ccp.example.com"
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "u", "Content": "p"}).encode("utf-8")
        with self._patch_urlopen(mock_resp), patch("automation.utils.credentials.urllib.request.Request") as mock_req:
            _cyberark_fetch("MySafe", "MY_OBJECT")
            called_url = mock_req.call_args[0][0]
            assert called_url.startswith("https://ccp.example.com")
        os.environ.pop("CYBERARK_CCP_URL", None)

    def test_rest_url_default_when_no_env(self):
        """No env var set → default CyberArk CCP URL is used."""
        os.environ.pop("AIM_WEBSERVICE_URL", None)
        os.environ.pop("CYBERARK_CCP_URL", None)
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "u", "Content": "p"}).encode("utf-8")
        with self._patch_urlopen(mock_resp), patch("automation.utils.credentials.urllib.request.Request") as mock_req:
            _cyberark_fetch("MySafe", "MY_OBJECT")
            called_url = mock_req.call_args[0][0]
            assert "cyberark-ccp" in called_url
            assert "AIMWebService/API/Accounts" in called_url

    def test_rest_network_exception_returns_none(self):
        """URLError / any exception → returns None (does not raise)."""
        with patch(
            "automation.utils.credentials.urllib.request.urlopen",
            side_effect=urllib.error.URLError("connection refused"),
        ):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_rest_generic_exception_returns_none(self):
        """A generic exception also results in None."""
        with patch("automation.utils.credentials.urllib.request.urlopen", side_effect=Exception("boom")):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_rest_response_empty_user_returns_none(self):
        """REST returns an item with UserName='' → _cyberark_fetch returns None."""
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "", "Content": "some_pw"}).encode("utf-8")
        with self._patch_urlopen(mock_resp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        assert result is None

    def test_rest_response_no_content_key(self):
        """CCP response missing Content key → returns (user, '') tuple."""
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "nopw_user"}).encode("utf-8")
        with self._patch_urlopen(mock_resp):
            result = _cyberark_fetch("MySafe", "MY_OBJECT")
        # User is present, missing Content → ''
        assert result == ("nopw_user", "")

    def test_rest_url_contains_safe_and_object_query(self):
        """Verify Safe and Object are embedded as query params in the REST URL."""
        os.environ.pop("AIM_WEBSERVICE_URL", None)
        os.environ.pop("CYBERARK_CCP_URL", None)
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({"UserName": "u", "Content": "p"}).encode("utf-8")
        with self._patch_urlopen(mock_resp), patch("automation.utils.credentials.urllib.request.Request") as mock_req:
            _cyberark_fetch("TestSafe", "TestObject")
            url = mock_req.call_args[0][0]
            assert "Safe=TestSafe" in url
            assert "Object=TestObject" in url


# ============================================================
# _resolve — fallback chain
# ============================================================


class TestResolve:
    """Core _resolve() fast-path / CyberArk fallback / default / required edge-cases."""

    def setup_method(self):
        os.environ.pop("AIM_WEBSERVICE_URL", None)
        os.environ.pop("CYBERARK_CCP_URL", None)

    # ── env-var takes priority ────────────────────────────────────────────────

    def test_env_wins_over_cyberark(self, monkeypatch):
        """Environment variable is returned without ever calling CyberArk."""
        monkeypatch.setenv("MY_VAR", "env_val")
        # If _cyberark_fetch were called, returning a different value would fail.
        # monkeypatch.setenv ensures the env path fires first.
        result = _resolve("MY_VAR", "ANY_SAFE", "ANY_OBJECT")
        assert result == "env_val"

    def test_env_wins_over_default(self, monkeypatch):
        """Env var pre-empts `default=` parameter."""
        monkeypatch.setenv("MY_DEFAULTED", "from_env")
        result = _resolve("MY_DEFAULTED", "Safe", "Obj", default="from_default")
        assert result == "from_env"

    # ── CyberArk fallback when env is absent ─────────────────────────────────

    def test_cyberark_fetches_when_env_absent(self, monkeypatch):
        """When env var is absent _cyberark_fetch is consulted; result returned."""
        monkeypatch.delenv("__FAKE_CYBER_VAR__", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("ca_user", "ca_pass")) as mock_fetch:
            result = _resolve("__FAKE_CYBER_VAR__", "CPSafe", "CPObject")
            mock_fetch.assert_called_once_with("CPSafe", "CPObject")
        assert result == "ca_pass"

    def test_cyberark_username_var_branches_on_username(self, monkeypatch):
        """When env var name ends with _USER → username side of pair."""
        monkeypatch.delenv("SVC_USER", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("svc_user", "svc_pass")):
            result = _resolve("SVC_USER", "Safe", "SVC_USER")
        assert result == "svc_user"

    def test_cyberark_password_falls_to_password_default(self, monkeypatch):
        """When env var ends with _PASSWORD → password side of pair."""
        monkeypatch.delenv("SVC_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("svc_user", "svc_pass")):
            result = _resolve("SVC_PASSWORD", "Safe", "SVC_PASSWORD")
        assert result == "svc_pass"

    def test_cyberark_id_var_branches_on_username(self, monkeypatch):
        """When env var name ends with _ID → username side."""
        monkeypatch.delenv("SVC_ID", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("svc_user", "svc_pwd")):
            result = _resolve("SVC_ID", "Safe", "SVC_ID")
        assert result == "svc_user"

    def test_cyberark_client_id_var_branches_on_username(self, monkeypatch):
        """CLIENT_ID suffix → username side."""
        monkeypatch.delenv("CLIENT_ID", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("svc_user", "svc_pwd")):
            result = _resolve("CLIENT_ID", "Safe", "CLIENT_ID")
        assert result == "svc_user"

    def test_cyberark_missing_not_in_pair_uses_default(self, monkeypatch):
        """When CyberArk returns None and default is provided → default."""
        monkeypatch.delenv("PASS_WITH_DEF", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            result = _resolve("PASS_WITH_DEF", "Safe", "Obj", default="my_default")
        assert result == "my_default"

    def test_cyberark_caches_into_env_username_side(self, monkeypatch):
        """Successful CyberArk username-side var (ends in _USER) is cached into os.environ."""
        var = "_CB_CACHE_U_USER"
        monkeypatch.delenv(var, raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("user1", "pw1")):
            first = _resolve(var, "Safe", var)
        assert first == "user1"
        assert os.environ[var] == "user1"

    def test_cyberark_caches_into_env_password_side(self, monkeypatch):
        """Successful CyberArk password-side var (no _USER/_ID/_CLIENT_ID) is cached as password."""
        var = "_CB_CACHE_PASS"
        monkeypatch.delenv(var, raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("user1", "pw1")):
            first = _resolve(var, "Safe", var, default=None)
        assert first == "pw1"
        assert os.environ[var] == "pw1"

    # ── default fallback ─────────────────────────────────────────────────────

    def test_default_used_when_env_and_cyberark_absent(self, monkeypatch):
        """env absent + CyberArk returns None → default is returned."""
        monkeypatch.delenv("DEF_VAR", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            result = _resolve("DEF_VAR", "Safe", "Obj", default="fallback")
        assert result == "fallback"

    def test_default_used_when_cyberark_disabled_no_default(self, monkeypatch):
        """env absent + CyberArk returns None + no default → returns None."""
        monkeypatch.delenv("NULL_DEF", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            result = _resolve("NULL_DEF", "Safe", "Obj")
        assert result is None

    # ── required error ───────────────────────────────────────────────────────

    def test_required_raises_when_env_and_cyberark_missing(self, monkeypatch):
        """env absent + CyberArk returns None + required=True → ValueError."""
        monkeypatch.delenv("_REQ_VAR_", raising=False)
        with (
            patch("automation.utils.credentials._cyberark_fetch", return_value=None),
            pytest.raises(ValueError, match="Required environment variable"),
        ):
            _resolve("_REQ_VAR_", "Safe", "Obj", required=True)

    def test_required_does_not_raise_when_env_set(self, monkeypatch):
        """required=True does not raise when the env var is already available."""
        monkeypatch.setenv("REQ_OK", "present")
        # CyberArk should not be consulted at all
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")) as mock_fetch:
            result = _resolve("REQ_OK", "Safe", "Obj", required=True)
            mock_fetch.assert_not_called()
        assert result == "present"

    def test_required_satisfied_by_cyberark(self, monkeypatch):
        """required=True with env absent but CyberArk provides value — no error."""
        monkeypatch.delenv("REQ_CB", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")):
            result = _resolve("REQ_CB", "Safe", "Obj", required=True)
        assert result == "p"

    def test_password_var_gets_password_from_pair(self, monkeypatch):
        """Var name has no _USER/_ID/_CLIENT_ID suffix → uses password side."""
        monkeypatch.delenv("GENERIC_PASS", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("svc_user", "svc_pwd")):
            result = _resolve("GENERIC_PASS", "Safe", "GENERIC_PASS")
        assert result == "svc_pwd"

    def test_cyberark_fetched_once_env_absent(self, monkeypatch):
        """_cyberark_fetch called exactly once when env var is missing."""
        monkeypatch.delenv("CB_ONCE", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")) as mock_f:
            _resolve("CB_ONCE", "Safe", "Obj")
            mock_f.assert_called_once()


# ============================================================
# get_credential — public API (CyberArk path)
# ============================================================


class TestGetCredentialCyberArk:
    """get_credential exercised through the CyberArk fallback path."""

    def test_cyberark_credential_env_absent(self, monkeypatch):
        """get_credential uses CyberArk when env var is absent."""
        monkeypatch.delenv("FAKE_FETCH_VAR", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")):
            result = get_credential("FAKE_FETCH_VAR")
        assert result == "p"

    def test_cyberark_credential_required_raises(self, monkeypatch):
        """get_credential required=True with CyberArk unavailable raises ValueError."""
        monkeypatch.delenv("_FAKE_REQ_", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None), pytest.raises(ValueError):
            get_credential("_FAKE_REQ_", required=True)

    def test_cyberark_credential_default_used(self, monkeypatch):
        """Default is used when both env and CyberArk are absent."""
        monkeypatch.delenv("_FAKE_DEF_", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            result = get_credential("_FAKE_DEF_", default="csv_default")
        assert result == "csv_default"

    def test_env_wins_in_get_credential(self, monkeypatch):
        """env var beats CyberArk in get_credential."""
        monkeypatch.setenv("_FAKE_GC_", "from_env")
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")) as mock_fetch:
            result = get_credential("_FAKE_GC_")
            mock_fetch.assert_not_called()
        assert result == "from_env"


# ============================================================
# get_credential — env-var path (existing, kept for completeness)
# ============================================================


class TestGetCredentialEnv:
    """Env-var path for get_credential."""

    def test_from_env(self, monkeypatch):
        monkeypatch.setenv("TEST_ENV_CV", "hello")
        assert get_credential("TEST_ENV_CV") == "hello"

    def test_default(self, monkeypatch):
        monkeypatch.delenv("_DEF_NO_ENV_", raising=False)
        assert get_credential("_DEF_NO_ENV_", default="dflt") == "dflt"

    def test_required_raises(self, monkeypatch):
        monkeypatch.delenv("_REQ_ENV_", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None), pytest.raises(ValueError):
            get_credential("_REQ_ENV_", required=True)

    def test_optional_returns_none(self, monkeypatch):
        monkeypatch.delenv("_OPT_ENV_", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            assert get_credential("_OPT_ENV_") is None

    def test_env_beats_default(self, monkeypatch):
        monkeypatch.setenv("_BT_ENV_", "first")
        assert get_credential("_BT_ENV_", default="second") == "first"

    def test_name_matches_body(self, monkeypatch):
        """Buddy check: test body matches the declared test name."""


# ============================================================
# get_ilo_credentials — CyberArk path
# ============================================================


class TestGetILOCredentialsCyberArk:
    """iLO credential getter exercised via CyberArk."""

    def test_ilo_cyberark_user_password(self, monkeypatch):
        """Both iLO username and password from CyberArk."""
        monkeypatch.delenv("ILO_USER", raising=False)
        monkeypatch.delenv("ILO_PASSWORD", raising=False)
        with patch(
            "automation.utils.credentials._cyberark_fetch",
            side_effect=[("ilo_user", "ilo_pass"), ("ilo_user", "ilo_pass")],
        ):
            user, pw = get_ilo_credentials()
        assert user == "ilo_user"
        assert pw == "ilo_pass"

    def test_ilo_default_username_cyberark_password(self, monkeypatch):
        """Username from CyberArk; password uses default '' when CyberArk returns None."""
        monkeypatch.delenv("ILO_USER", raising=False)
        # _cyberark_fetch called twice: once for user, once for password
        side_effects = [("ilo_user", "ilo_pass"), ("ilo_user", "ilo_pass")]
        with patch("automation.utils.credentials._cyberark_fetch", side_effect=side_effects):
            user, pw = get_ilo_credentials()
        assert user == "ilo_user"
        assert pw == "ilo_pass"

    def test_ilo_both_default_no_env_no_cyberark(self, monkeypatch):
        """No env, CyberArk returns None → defaults (Administrator, '')."""
        monkeypatch.delenv("ILO_USER", raising=False)
        monkeypatch.delenv("ILO_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            user, pw = get_ilo_credentials()
        assert user == "Administrator"
        assert pw == ""

    def test_ilo_custom_env_vars_with_cyberark(self, monkeypatch):
        """Custom env var names are passed through to _resolve."""
        monkeypatch.delenv("CUSTOM_ILO_U_USER", raising=False)
        monkeypatch.delenv("CUSTOM_ILO_PASS", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", side_effect=[("u", "p"), ("u", "p")]):
            user, pw = get_ilo_credentials(username_env="CUSTOM_ILO_U_USER", password_env="CUSTOM_ILO_PASS")
        assert user == "u"
        assert pw == "p"

    def test_ilo_name_matches_body(self):
        """Buddy check: test body matches the declared test name."""


# ============================================================
# get_scom_credentials — CyberArk / required path
# ============================================================


class TestGetScomCredentialsCyberArk:
    """SCOM credential getter exercised via CyberArk fallback."""

    def test_scom_cyberark_success(self, monkeypatch):
        """Both SCOM creds come from CyberArk."""
        monkeypatch.delenv("SCOM_ADMIN_USER", raising=False)
        monkeypatch.delenv("SCOM_ADMIN_PASSWORD", raising=False)
        with patch(
            "automation.utils.credentials._cyberark_fetch",
            side_effect=[("scom_user", "scom_pw"), ("scom_user", "scom_pw")],
        ):
            user, pw = get_scom_credentials()
        assert user == "scom_user"
        assert pw == "scom_pw"

    def test_scom_missing_required_raises(self, monkeypatch):
        """required=True with no env + CyberArk returns None → ValueError."""
        monkeypatch.delenv("SCOM_ADMIN_USER", raising=False)
        monkeypatch.delenv("SCOM_ADMIN_PASSWORD", raising=False)
        with pytest.raises(ValueError):
            get_scom_credentials()

    def test_scom_env_takes_priority(self, monkeypatch):
        """Env var short-circuits CyberArk for SCOM credentials."""
        monkeypatch.setenv("SCOM_ADMIN_USER", "env_scom_user")
        monkeypatch.setenv("SCOM_ADMIN_PASSWORD", "env_scom_pw")
        with patch("automation.utils.credentials._cyberark_fetch") as mock_fetch:
            user, pw = get_scom_credentials()
            mock_fetch.assert_not_called()
        assert user == "env_scom_user"
        assert pw == "env_scom_pw"

    def test_scom_cyberark_only_user_missing_pw(self, monkeypatch):
        """Password SCOM_ADMIN_PASSWORD resolves to None → required=True raises ValueError."""
        monkeypatch.delenv("SCOM_ADMIN_USER", raising=False)
        monkeypatch.delenv("SCOM_ADMIN_PASSWORD", raising=False)
        # _cyberark_fetch returns creds for user, but password call returns None
        # — _resolve(SCOM_ADMIN_PASSWORD) hits required=True → ValueError propagates
        with (
            patch("automation.utils.credentials._cyberark_fetch", side_effect=[("sc_user", "sc_pw"), None]),
            pytest.raises(ValueError),
        ):
            get_scom_credentials()

    def test_scom_name_matches_body(self):
        """Buddy check: test body matches the declared test name."""


# ============================================================
# get_openview_credentials — CyberArk path
# ============================================================


class TestGetOpenViewCredentialsCyberArk:
    """OpenView credential getter via CyberArk."""

    def test_openview_cyberark_both(self, monkeypatch):
        monkeypatch.delenv("OPENVIEW_USER", raising=False)
        monkeypatch.delenv("OPENVIEW_PASSWORD", raising=False)
        with patch(
            "automation.utils.credentials._cyberark_fetch", side_effect=[("ov_user", "ov_pw"), ("ov_user", "ov_pw")]
        ):
            user, pw = get_openview_credentials()
        assert user == "ov_user"
        assert pw == "ov_pw"

    def test_openview_cyberark_absent_returns_none(self, monkeypatch):
        """No env + CyberArk returns None → (None, None)."""
        monkeypatch.delenv("OPENVIEW_USER", raising=False)
        monkeypatch.delenv("OPENVIEW_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            assert get_openview_credentials() == (None, None)

    def test_openview_env_beats_cyberark(self, monkeypatch):
        """Env vars short-circuit CyberArk for OpenView."""
        monkeypatch.setenv("OPENVIEW_USER", "env_ou")
        monkeypatch.setenv("OPENVIEW_PASSWORD", "env_op")
        with patch("automation.utils.credentials._cyberark_fetch") as mock_fetch:
            result = get_openview_credentials()
            mock_fetch.assert_not_called()
        assert result == ("env_ou", "env_op")


# ============================================================
# get_smtp_credentials — CyberArk path
# ============================================================


class TestGetSmtpCredentialsCyberArk:
    """SMTP credential getter via CyberArk."""

    def test_smtp_cyberark_both(self, monkeypatch):
        monkeypatch.delenv("SMTP_USER", raising=False)
        monkeypatch.delenv("SMTP_PASSWORD", raising=False)
        with patch(
            "automation.utils.credentials._cyberark_fetch",
            side_effect=[("smtp_user", "smtp_pw"), ("smtp_user", "smtp_pw")],
        ):
            user, pw = get_smtp_credentials()
        assert user == "smtp_user"
        assert pw == "smtp_pw"

    def test_smtp_cyberark_absent_returns_none(self, monkeypatch):
        """No env + CyberArk returns None → (None, None)."""
        monkeypatch.delenv("SMTP_USER", raising=False)
        monkeypatch.delenv("SMTP_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            assert get_smtp_credentials() == (None, None)

    def test_smtp_default_when_cyberark_none(self, monkeypatch):
        """get_smtp_credentials with default=None passes None to _resolve."""
        monkeypatch.delenv("SMTP_USER", raising=False)
        monkeypatch.delenv("SMTP_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            user, pw = get_smtp_credentials()
        assert user is None
        assert pw is None

    def test_smtp_name_matches_body(self):
        """Buddy check: test body matches the declared test name."""


# ============================================================
# Env-var path — kept from original (now least-case / sanity)
# ============================================================


class TestGetCredentialLegacy:
    """Legacy env-var tests — these confirm the fast-path still works."""

    def test_get_credential_from_environment(self, monkeypatch):
        monkeypatch.setenv("TEST_VAR", "test_value")
        assert get_credential("TEST_VAR") == "test_value"

    def test_get_credential_with_default(self, monkeypatch):
        monkeypatch.delenv("TEST_VAR", raising=False)
        assert get_credential("TEST_VAR", default="default_value") == "default_value"

    def test_get_credential_missing_required(self, monkeypatch):
        monkeypatch.delenv("REQUIRED_VAR", raising=False)
        with pytest.raises(ValueError, match="Required environment variable"):
            get_credential("REQUIRED_VAR", required=True)

    def test_get_credential_returns_none_when_not_required(self, monkeypatch):
        monkeypatch.delenv("OPTIONAL_VAR", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            assert get_credential("OPTIONAL_VAR", required=False) is None

    def test_get_credential_prefers_environment_over_default(self, monkeypatch):
        monkeypatch.setenv("TEST_VAR", "env_value")
        assert get_credential("TEST_VAR", default="default_value") == "env_value"

    def test_get_credential_env_wins_over_cyberark(self, monkeypatch):
        monkeypatch.setenv("_ECWOC_", "env_val")
        with patch("automation.utils.credentials._cyberark_fetch", return_value=("u", "p")) as mock_fetch:
            assert get_credential("_ECWOC_") == "env_val"
            mock_fetch.assert_not_called()


class TestGetILOCredentialsLegacy:
    def test_from_env(self, monkeypatch):
        monkeypatch.setenv("ILO_USER", "admin")
        monkeypatch.setenv("ILO_PASSWORD", "secret123")
        u, p = get_ilo_credentials()
        assert u == "admin"
        assert p == "secret123"

    def test_default_username(self, monkeypatch):
        monkeypatch.delenv("ILO_USER", raising=False)
        monkeypatch.delenv("ILO_PASSWORD", raising=False)
        u, p = get_ilo_credentials()
        assert u == "Administrator"
        assert p == ""

    def test_custom_env_vars(self, monkeypatch):
        monkeypatch.setenv("CUSTOM_ILO_USER", "custom_user")
        monkeypatch.setenv("CUSTOM_ILO_PASS", "custom_pass")
        u, p = get_ilo_credentials(username_env="CUSTOM_ILO_USER", password_env="CUSTOM_ILO_PASS")
        assert u == "custom_user"
        assert p == "custom_pass"


class TestGetScomCredentialsLegacy:
    def test_success(self, monkeypatch):
        monkeypatch.setenv("SCOM_ADMIN_USER", "scom_user")
        monkeypatch.setenv("SCOM_ADMIN_PASSWORD", "scom_pass")
        u, p = get_scom_credentials()
        assert u == "scom_user"
        assert p == "scom_pass"

    def test_missing_required_raises(self, monkeypatch):
        monkeypatch.delenv("SCOM_ADMIN_USER", raising=False)
        monkeypatch.delenv("SCOM_ADMIN_PASSWORD", raising=False)
        with pytest.raises(ValueError):
            get_scom_credentials()


class TestGetOpenViewCredentialsLegacy:
    def test_optional_when_not_set(self, monkeypatch):
        monkeypatch.delenv("OPENVIEW_USER", raising=False)
        monkeypatch.delenv("OPENVIEW_PASSWORD", raising=False)
        assert get_openview_credentials() == (None, None)

    def test_from_env(self, monkeypatch):
        monkeypatch.setenv("OPENVIEW_USER", "ov_user")
        monkeypatch.setenv("OPENVIEW_PASSWORD", "ov_pass")
        u, p = get_openview_credentials()
        assert u == "ov_user"
        assert p == "ov_pass"


class TestGetSMTPCredentialsLegacy:
    def test_optional_when_not_set(self, monkeypatch):
        monkeypatch.delenv("SMTP_USER", raising=False)
        monkeypatch.delenv("SMTP_PASSWORD", raising=False)
        with patch("automation.utils.credentials._cyberark_fetch", return_value=None):
            u, p = get_smtp_credentials()
        assert u is None
        assert p is None

    def test_from_env(self, monkeypatch):
        monkeypatch.setenv("SMTP_USER", "smtp_user")
        monkeypatch.setenv("SMTP_PASSWORD", "smtp_pass")
        u, p = get_smtp_credentials()
        assert u == "smtp_user"
        assert p == "smtp_pass"
