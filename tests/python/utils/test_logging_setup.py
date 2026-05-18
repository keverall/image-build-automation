"""Tests for automation.utils.logging_setup module."""

import logging
import sys

from automation.utils.logging_setup import get_logger, init_logging


class TestInitLogging:
    """Tests for init_logging function."""

    def test_init_logging_configures_root_logger(self):
        """Test init_logging sets up root logger."""
        init_logging()
        root = logging.getLogger()
        assert root.level == logging.INFO
        assert len(root.handlers) >= 1  # At least console handler

    def test_init_logging_with_log_file(self, tmp_path):
        """Test init_logging adds file handler."""
        log_file = tmp_path / "test.log"
        init_logging(log_file=str(log_file))

        root = logging.getLogger()
        # Check file handler exists
        file_handlers = [h for h in root.handlers if isinstance(h, logging.FileHandler)]
        assert len(file_handlers) == 1
        assert file_handlers[0].baseFilename == str(log_file)

    def test_init_logging_custom_level(self):
        """Test init_logging with custom logging level."""
        init_logging(level=logging.DEBUG)
        root = logging.getLogger()
        assert root.level == logging.DEBUG

    def test_init_logging_creates_log_directory(self, tmp_path):
        """Test init_logging creates logs directory if needed."""
        log_dir = tmp_path / "logs" / "subdir"
        log_file = log_dir / "app.log"
        init_logging(log_file=str(log_file))
        assert log_dir.exists()

    def test_init_logging_clears_existing_handlers(self):
        """Test init_logging clears existing handlers."""
        root = logging.getLogger()
        # Add a dummy handler
        dummy_handler = logging.StreamHandler(sys.stdout)
        root.addHandler(dummy_handler)

        init_logging()

        # Dummy handler should be removed
        assert dummy_handler not in root.handlers

    def test_init_logging_formatter_includes_fields(self):
        """Test that formatter includes expected fields."""
        init_logging()
        root = logging.getLogger()
        console_handler = root.handlers[0]
        formatter = console_handler.formatter
        # Verify format string contains expected fields
        assert "%(asctime)s" in formatter._fmt
        assert "%(name)s" in formatter._fmt
        assert "%(levelname)s" in formatter._fmt
        assert "%(message)s" in formatter._fmt


class TestGetLogger:
    """Tests for get_logger function."""

    def test_get_logger_returns_logger(self):
        """Test get_logger returns a Logger instance."""
        logger = get_logger("test.module")
        assert isinstance(logger, logging.Logger)
        assert logger.name == "test.module"

    def test_get_logger_propagates_to_root(self):
        """Test logger propagates to root logger."""
        logger = get_logger("test.propagate")
        assert logger.propagate is True
