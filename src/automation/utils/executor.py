"""Subprocess execution utilities with retry support."""

import logging
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Union

logger = logging.getLogger(__name__)


@dataclass
class CommandResult:
    """Result of a subprocess execution."""
    returncode: int
    stdout: str
    stderr: str
    success: bool

    @property
    def output(self) -> str:
        """Combined stdout and stderr."""
        return self.stdout + self.stderr


def run_command(
    cmd: Union[str, list[str]],
    shell: bool = False,
    capture_output: bool = True,
    timeout: int = 300,
    check: bool = False,
    cwd: Optional[Path] = None
) -> CommandResult:
    """
    Execute a command and return structured result.

    Args:
        cmd: Command string or list
        shell: Use shell execution
        capture_output: Capture stdout/stderr
        timeout: Timeout in seconds
        check: Raise CalledProcessError on non-zero exit
        cwd: Working directory

    Returns:
        CommandResult object

    Raises:
        subprocess.CalledProcessError: If check=True and command fails
        subprocess.TimeoutExpired: If command times out
    """
    try:
        result = subprocess.run(
            cmd,
            shell=shell,
            capture_output=capture_output,
            text=True,
            timeout=timeout,
            cwd=cwd
        )
        cr = CommandResult(
            returncode=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
            success=(result.returncode == 0)
        )

        if not cr.success:
            logger.error(f"Command failed: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
            logger.error(f"stderr: {cr.stderr}")
            if check:
                raise subprocess.CalledProcessError(cr.returncode, cmd, cr.stdout, cr.stderr)

        return cr

    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out after {timeout}s: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
        return CommandResult(
            returncode=-1,
            stdout="",
            stderr=f"Command timed out after {timeout} seconds",
            success=False
        )
    except Exception as e:
        logger.error(f"Command execution error: {e}")
        return CommandResult(
            returncode=-1,
            stdout="",
            stderr=str(e),
            success=False
        )


def run_with_retry(
    cmd: Union[str, list[str]],
    max_attempts: int = 3,
    delay: float = 5.0,
    shell: bool = False,
    timeout: int = 300,
    check: bool = False
) -> CommandResult:
    """
    Run a command with retry logic for transient failures.

    Args:
        cmd: Command to execute
        max_attempts: Number of retry attempts (total tries = 1 + max_attempts)
        delay: Initial delay between retries (exponential backoff)
        shell: Use shell execution
        timeout: Command timeout per attempt
        check: Raise on non-zero exit after all retries

    Returns:
        CommandResult from final attempt

    Raises:
        RuntimeError: If all attempts fail and check=True
    """
    last_error = None
    for attempt in range(max_attempts + 1):
        if attempt > 0:
            time.sleep(delay * (2 ** (attempt - 1)))  # Exponential backoff
            logger.info(f"Retry attempt {attempt}/{max_attempts}")

        result = run_command(cmd, shell=shell, capture_output=True, timeout=timeout)

        if result.success:
            if attempt > 0:
                logger.info(f"Command succeeded after {attempt} retries")
            return result

        last_error = result
        logger.warning(f"Command failed (attempt {attempt + 1}/{max_attempts + 1}): {result.stderr[:200]}")

    if check and last_error:
        raise RuntimeError(f"Command failed after {max_attempts} retries: {last_error.stderr}")

    return last_error if last_error else CommandResult(-1, "", "Unknown error", False)
