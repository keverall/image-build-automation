# Shared Utilities Package Reference

## Overview

The `scripts/utils/` package centralizes common functionality used across all automation scripts, enforcing **DRY (Don't Repeat Yourself)** principles and ensuring consistent behavior.

All utilities feature:
- **Comprehensive docstrings** (Google-style) with Args, Returns, and Raises
- **Type hints** on all public functions and methods
- **Structured logging** via Python's `logging` module
- **Testable units** with minimal external dependencies
- **Fail-fast philosophy** with clear error messages

## Installation & Import

The utils package is part of the repository; no separate installation required.

```python
# Import specific utilities
from automation.utils.logging_setup import init_logging
from automation.utils.config import load_json_config
from automation.utils.audit import AuditLogger
from automation.utils.executor import run_command, run_with_retry

# Or import the package for all exports
from utils import (
    init_logging,
    load_json_config,
    load_server_list,
    load_cluster_catalogue,
    AuditLogger,
    ensure_dir,
    save_json,
    run_command,
    run_with_retry,
    get_ilo_credentials,
    get_scom_credentials,
    run_powershell,
    run_powershell_winrm,
    build_scom_connection,
    build_scom_maintenance_script,
    AutomationBase
)
```

## Module Reference

### `logging_setup.py`

Centralized logging configuration to avoid duplicate handlers.

```python
def init_logging(
    level: int = logging.INFO,
    log_file: Optional[str] = None,
    fmt: str = "%(asctime)s [%(levelname)-8s] %(name)s: %(message)s",
    date_fmt: str = "%Y-%m-%dT%H:%M:%S"
) -> None:
    """
    Initialize root logger with console + optional file handler.

    Args:
        level: Logging level (default INFO)
        log_file: Optional path to log file (creates directory if needed)
        fmt: Log format string
        date_fmt: Timestamp format

    Returns:
        None
    """
```

**Key design**: `init_logging()` is called once in each script's `main()` function, not in class `__init__`, to prevent handler accumulation across multiple instantiations.

---

### `config.py`

Load JSON configuration files with environment variable substitution.

```python
def load_json_config(
    path: Union[str, Path],
    required: bool = True,
    env_prefix: str = ""
) -> Dict[str, Any]:
    """
    Load and parse a JSON config file.

    Args:
        path: Path to JSON file
        required: If True, raises FileNotFoundError if file missing
        env_prefix: Prefix for environment variable substitution (e.g., "SCOM_")
                    Replaces ${VAR} placeholders in config values.

    Returns:
        Dict containing parsed JSON (with substituted env vars)

    Raises:
        FileNotFoundError: If required file is missing
        json.JSONDecodeError: If file contains invalid JSON
    """
```

**Example** (config with secrets):
```json
{
  "scom_management_server": "${SCOM_MANAGEMENT_HOST}",
  "ilo_password": "${ILO_PASSWORD}"
}
```

Environment variables are substituted automatically, keeping secrets out of version control.

---

### `inventory.py`

Load server inventory and cluster catalogues.

```python
@dataclass
class ServerInfo:
    """Represents a server with its network addresses."""
    hostname: str
    ipmi_ip: Optional[str] = None
    ilo_ip: Optional[str] = None

def load_server_list(path: Union[str, Path]) -> List[ServerInfo]:
    """
    Parse server_list.txt (hostname or hostname,ipmi,ilo per line).

    Args:
        path: Path to server list file

    Returns:
        List of ServerInfo objects
    """

def load_cluster_catalogue(path: Union[str, Path]) -> Dict[str, Dict]:
    """
    Load clusters_catalogue.json and validate structure.

    Args:
        path: Path to clusters catalogue JSON

    Returns:
        Dict mapping cluster_id -> cluster definition

    Raises:
        ValueError: If catalogue structure is invalid
    """
```

```python
def validate_cluster_id(cluster_id: str, catalogue: Dict) -> bool:
    """
    Ensure cluster_id exists in catalogue and is not a server-only entry.

    Args:
        cluster_id: Cluster identifier to validate
        catalogue: Loaded cluster catalogue dict

    Returns:
        True if valid cluster, False if server-only or missing
    """
```

---

### `audit.py`

Structured JSON audit logging with per-action files and master log aggregation.

```python
class AuditLogger:
    """
    Structured audit logger writing JSON records to per-action files
    and appending to a master log (line-delimited JSON).
    """

    def __init__(
        self,
        logs_dir: Union[str, Path] = "logs",
        master_log: str = "audit.log",
        dry_run: bool = False
    ) -> None:
        """
        Initialize AuditLogger.

        Args:
            logs_dir: Directory for log files (created if missing)
            master_log: Master log filename (appended line-delimited JSON)
            dry_run: If True, logs are marked as simulated; no file writes
        """

    def log(
        self,
        action: str,
        status: str,
        server: str = "",
        details: Optional[Dict] = None,
        cluster_id: Optional[str] = None
    ) -> None:
        """
        Write a structured audit record.

        Args:
            action: Action category (e.g., "build_iso", "deploy_ilo")
            status: One of "START", "SUCCESS", "FAILED", "SKIP", "ERROR"
            server: Server hostname (or cluster ID for cluster-level actions)
            details: Arbitrary dict with additional context
            cluster_id: Optional cluster ID for clustering operations

        Example:
            audit.log(
                action="deploy_ilo",
                status="SUCCESS",
                server="web01.example.com",
                details={"ilo_ip": "192.168.1.101", "method": "virtual_media"}
            )
        """

    def close(self) -> None:
        """Close current per-action file handle (call at script exit)."""
```

**Pattern**: Each script creates an `AuditLogger` instance in `main()` and calls `audit.log()` after each significant step. The logger automatically:
- Creates `logs/` directory if missing
- Writes a per-action JSON file (e.g., `logs/maintenance_enable_PROD_20251114_220000.json`)
- Appends the same record to the master log as a single line of JSON
- Flushes after each write to avoid losing records on crash

---

### `file_io.py`

Filesystem helper functions.

```python
def ensure_dir(path: Union[str, Path]) -> Path:
    """
    Create directory if it doesn't exist.

    Args:
        path: Directory path to create

    Returns:
        Path object for the created/existing directory
    """

def save_json(
    data: Any,
    path: Union[str, Path],
    indent: int = 2,
    ensure_ascii: bool = False
) -> Path:
    """
    Serialize data to JSON file atomically.

    Args:
        data: JSON-serializable object
        path: Output file path (parent directories created)
        indent: Pretty-print indentation
        ensure_ascii: If False, allows UTF-8 characters

    Returns:
        Path to written file
    """
```

---

### `executor.py`

Subprocess execution with timeout and retry logic.

```python
def run_command(
    cmd: List[str],
    capture_output: bool = True,
    timeout: int = 300,
    check: bool = False,
    cwd: Optional[Union[str, Path]] = None
) -> subprocess.CompletedProcess:
    """
    Execute a subprocess command with consistent error handling.

    Args:
        cmd: Command and arguments as list
        capture_output: Capture stdout/stderr
        timeout: Execution timeout in seconds
        check: If True, raise CalledProcessError on non-zero exit
        cwd: Working directory for command

    Returns:
        CompletedProcess instance

    Raises:
        subprocess.CalledProcessError: If check=True and command fails
        subprocess.TimeoutExpired: If command exceeds timeout
    """

def run_with_retry(
    func: Callable,
    max_attempts: int = 3,
    delay_seconds: float = 2.0,
    exceptions: tuple = (subprocess.CalledProcessError, ConnectionError)
) -> Any:
    """
    Execute a callable with exponential backoff retry.

    Args:
        func: Callable to execute (no args; use lambda for parameters)
        max_attempts: Maximum execution attempts (default 3)
        delay_seconds: Initial delay between attempts (doubles each retry)
        exceptions: Tuple of exception types to catch and retry

    Returns:
        Return value from func on success

    Raises:
        Last exception if all attempts fail
    """
```

**Example**:
```python
from utils.executor import run_with_retry

result = run_with_retry(
    lambda: run_command(["hpe-sut", "--download", "--force"]),
    max_attempts=3,
    delay_seconds=5.0
)
```

---

### `credentials.py`

Secure credential retrieval from environment variables.

```python
def get_credential(
    var_name: str,
    required: bool = True,
    default: Optional[str] = None
) -> Optional[str]:
    """
    Fetch credential from environment.

    Args:
        var_name: Environment variable name
        required: If True, raises RuntimeError when missing
        default: Default value if not set (ignored if required=True)

    Returns:
        Credential string or None

    Raises:
        RuntimeError: If required and variable not set
    """

def get_ilo_credentials(
    server: Optional[str] = None
) -> Tuple[str, str]:
    """
    Get iLO username and password.

    Priority:
    1. Per-server env vars: ILO_USER_<SERVER>, ILO_PASSWORD_<SERVER> (uppercase, hyphens→underscores)
    2. Global env vars: ILO_USER, ILO_PASSWORD

    Args:
        server: Optional server hostname for per-server override

    Returns:
        (username, password) tuple

    Raises:
        RuntimeError: If credentials not found
    """

def get_scom_credentials() -> Tuple[str, str]:
    """
    Get SCOM administrator credentials.

    Returns:
        (username, password) tuple from SCOM_ADMIN_USER/PASSWORD

    Raises:
        RuntimeError: If credentials not set
    """
```

---

### `powershell.py`

PowerShell execution (local and remote via WinRM) plus SCOM-specific script builders.

```python
def run_powershell(
    script: str,
    capture_output: bool = True,
    timeout: int = 300,
    execution_policy: str = "Bypass"
) -> Tuple[bool, str]:
    """
    Execute a PowerShell script locally.

    Args:
        script: PowerShell code to execute
        capture_output: Capture stdout/stderr
        timeout: Execution timeout in seconds
        execution_policy: PowerShell execution policy (default Bypass)

    Returns:
        (success: bool, output: str) tuple
    """

def run_powershell_winrm(
    script: str,
    server: str,
    username: str,
    password: str,
    transport: str = "ntlm",
    timeout: int = 300
) -> Tuple[bool, str]:
    """
    Execute PowerShell script on remote server via WinRM.

    Args:
        script: PowerShell code to execute
        server: Remote server hostname/IP
        username: Username for authentication
        password: Password for authentication
        transport: WinRM transport protocol (ntlm, kerberos, basic, etc.)
        timeout: Command timeout in seconds

    Returns:
        (success: bool, output: str) tuple
    """
```

**SCOM script builders** (return ready-to-execute PowerShell strings):

```python
def build_scom_connection(management_server: str) -> str:
    """
    Build PowerShell script to create SCOMManagementGroupConnection.

    Args:
        management_server: SCOM management server hostname

    Returns:
        PowerShell script text
    """

def build_scom_maintenance_script(
    group_display_name: str,
    duration_seconds: int,
    comment: str,
    operation: str = "start"
) -> str:
    """
    Build PowerShell script for SCOM maintenance mode operations.

    Args:
        group_display_name: SCOM group display name
        duration_seconds: Maintenance duration in seconds
        comment: Maintenance comment (appears in SCOM console)
        operation: "start" or "stop"

    Returns:
        Complete PowerShell script ready for execution

    Notes:
        - Script handles already-in-maintenance cases gracefully (skips)
        - Exit code 1 if any failures occur; 0 on full success
    """
```

---

### `base.py`

Common base class for automation scripts. Provides shared initialization, configuration loading, and result persistence.

```python
class AutomationBase:
    """
    Base class for automation scripts with common initialization.
    """

    def __init__(
        self,
        script_name: str,
        config_dir: Union[str, Path] = "configs",
        logs_dir: Union[str, Path] = "logs",
        output_dir: Union[str, Path] = "output"
    ) -> None:
        """
        Initialize base automation class.

        Args:
            script_name: Name of the script (used for logging)
            config_dir: Directory containing configuration files
            logs_dir: Directory for log files
            output_dir: Directory for output artifacts
        """
        self.script_name = script_name
        self.config_dir = Path(config_dir)
        self.logs_dir = ensure_dir(Path(logs_dir))
        self.output_dir = ensure_dir(Path(output_dir))

        # Set up logging
        log_file = self.logs_dir / f"{script_name}.log"
        init_logging(level=logging.INFO, log_file=str(log_file))

        self.logger = logging.getLogger(script_name)
        self.logger.info(f"Initialized {script_name}")

        # Placeholder for subclass-specific state
        self.result: Dict[str, Any] = {"success": False}

    def load_config(self, filename: str, required: bool = True) -> Dict:
        """
        Load JSON configuration file from config_dir.

        Args:
            filename: Config filename (e.g., "clusters_catalogue.json")
            required: If True, raise when file missing

        Returns:
            Parsed configuration dict
        """
        path = self.config_dir / filename
        return load_json_config(path, required=required)

    def load_servers(self, filename: str = "server_list.txt") -> List[ServerInfo]:
        """
        Load server list from config_dir.

        Args:
            filename: Server list filename

        Returns:
            List of ServerInfo objects
        """
        path = self.config_dir / filename
        return load_server_list(path)

    def save_result(self, filename_suffix: str = "") -> Path:
        """
        Save self.result dict to output/results/ as JSON.

        Args:
            filename_suffix: Optional suffix for filename (e.g., server name)

        Returns:
            Path to written result file
        """
        ensure_dir(self.output_dir / "results")
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{self.script_name}_{filename_suffix}_{timestamp}.json"
        path = self.output_dir / "results" / filename
        save_json(self.result, path)
        return path

    def run(self) -> int:
        """
        Main entry point (to be overridden by subclasses).

        Returns:
            Exit code (0 = success, non-zero = failure)
        """
        raise NotImplementedError("Subclasses must implement run()")
```

**Inheritance pattern**:
```python
class BuildIsoOrchestrator(AutomationBase):
    def __init__(self, args):
        super().__init__(script_name="build_iso")
        # subclass-specific initialization
        self.args = args

    def run(self) -> int:
        # implementation
        return 0  # or non-zero on failure
```

---

## Design Patterns

### Centralized Logging

Each script's `main()` calls `init_logging()` exactly once. Classes receive the configured logger via `logging.getLogger(__name__)` and do **not** call `init_logging()` themselves.

```python
def main():
    init_logging(level=logging.INFO, log_file="logs/build_iso.log")
    logger = logging.getLogger(__name__)
    orchestrator = BuildIsoOrchestrator(args)
    sys.exit(orchestrator.run())
```

### Configuration Loading with Secrets

Use `load_json_config()` with `${VAR}` placeholders for sensitive values. Environment variables can be set in CI/CD secret stores or `.env` files (via `python-dotenv`).

```python
# configs/scom_config.json
{
  "management_server": "${SCOM_MANAGER_HOST}",
  "credentials_env_prefix": "SCOM"
}
```

```python
# In script
config = load_json_config("configs/scom_config.json", env_prefix="SCOM")
# Values of ${SCOM_MANAGER_HOST} etc. are substituted automatically
```

### Audit Throughout Lifecycle

```python
audit = AuditLogger(logs_dir="logs", dry_run=args.dry_run)

audit.log("build_start", "START", server=server_name)
# ... do work ...
audit.log("download_firmware", "SUCCESS", server=server_name, details={"size_mb": 1500})
# ... more steps ...
audit.close()
```

### Retry for Flaky Operations

Network operations (iLO REST calls, HPE downloads) wrapped in `run_with_retry()`:

```python
from utils.executor import run_with_retry, run_command

try:
    result = run_with_retry(
        lambda: run_command(["ilorest", "get", "/rest/v1/maintenancewindows"]),
        max_attempts=3,
        delay_seconds=5.0
    )
except Exception as e:
    logger.error(f"iLO query failed after retries: {e}")
```

### Credential Overrides

Per-server credentials via environment variable convention:

```bash
# Global defaults
export ILO_USER="Administrator"
export ILO_PASSWORD="global_password"

# Per-server override (uppercase, hyphens→underscores)
export ILO_USER_WEB01="admin_web01"
export ILO_PASSWORD_WEB01="secret_web01"
```

---

## Linting & Formatting Standards

All utils modules must pass:

```bash
# Import sorting + formatting
ruff check src/automation/utils/ --fix
ruff format src/automation/utils/

# Complexity (no function should exceed CC=10)
radon cc src/automation/utils/ -nc

# Type checking (optional)
mypy scripts/utils/ --ignore-missing-imports
```

**Before committing**: ensure no `F401` (unused imports), `F841` (unused variables), or `E501` (line too long) errors.

---

## Testing

Each utility function should have at least one unit test under `tests/` (future work). Example pattern:

```python
def test_load_json_config_with_env_substitution(tmp_path, monkeypatch):
    # Arrange
    config_file = tmp_path / "test.json"
    config_file.write_text('{"api_key": "${API_KEY}"}')
    monkeypatch.setenv("API_KEY", "secret123")

    # Act
    result = load_json_config(config_file)

    # Assert
    assert result["api_key"] == "secret123"
```

Run all tests:
```bash
pytest tests/ -v
```

---

## Change History

- 2026-05-15: Initial utilities package creation (9 modules)
