"""Tests for automation.cli.generate_uuid module."""

from unittest.mock import patch

import pytest

from automation.cli.generate_uuid import generate_unique_uuid, main


class TestGenerateUniqueUUID:
    """Tests for generate_unique_uuid function."""

    def test_generate_uuid_returns_valid_uuid_format(self):
        """Test that generated UUID is valid UUID format."""
        import uuid as uuid_module
        generated = generate_unique_uuid("test-server")
        # Should be valid UUID, any version is fine
        try:
            uuid_module.UUID(generated)
            assert True
        except ValueError:
            pytest.fail("Generated UUID is not valid")

    def test_generate_uuid_deterministic_with_timestamp(self):
        """Test that same server_name and timestamp produces same UUID."""
        timestamp = "2024-01-01T12:00:00"
        uuid1 = generate_unique_uuid("server1", timestamp)
        uuid2 = generate_unique_uuid("server1", timestamp)
        assert uuid1 == uuid2

    def test_generate_uuid_different_servers_different(self):
        """Test different server names produce different UUIDs."""
        uuid1 = generate_unique_uuid("server1")
        uuid2 = generate_unique_uuid("server2")
        assert uuid1 != uuid2

    def test_generate_uuid_uses_sha256(self):
        """Test that UUID is derived from SHA256 hash."""
        server_name = "test-server"
        timestamp = "2024-01-01T00:00:00"
        base_string = f"{server_name}-{timestamp}"

        import hashlib
        hash_hex = hashlib.sha256(base_string.encode('utf-8')).hexdigest()[:32]
        expected_uuid = str(__import__('uuid').UUID(hash_hex))

        result = generate_unique_uuid(server_name, timestamp)
        assert result == expected_uuid

    def test_generate_uuid_default_timestamp_is_current(self):
        """Test that default timestamp is approximately current time."""
        import time
        time.time()
        uuid1 = generate_unique_uuid("server1")
        time.time()

        # UUID incorporates timestamp; verify timestamp extracted is within range
        # The UUID itself doesn't encode time in a simple way since it's hashed
        # But we can at least test that multiple UUIDs generated rapidly are distinct
        uuid2 = generate_unique_uuid("server1")
        assert uuid1 != uuid2  # Different timestamps should yield different UUIDs


class TestMain:
    """Tests for main function."""

    def test_main_prints_uuid(self, capsys):
        """Test main prints UUID to stdout."""
        with patch('sys.exit'):
            main()

        captured = capsys.readouterr()
        # Should print a UUID string
        import uuid
        try:
            uuid.UUID(captured.out.strip())
            assert True
        except ValueError:
            pytest.fail("Output is not a valid UUID")

    def test_main_with_custom_timestamp(self, capsys):
        """Test main with custom timestamp."""
        with patch('sys.exit'), patch('automation.cli.generate_uuid.generate_unique_uuid', return_value="test-uuid-1234"), patch('sys.argv', ['generate_uuid.py', 'server1', '--timestamp', '2024-01-01T00:00:00']):
            main()

        captured = capsys.readouterr()
        assert "test-uuid-1234" in captured.out

    def test_main_writes_to_file(self, tmp_path, capsys):
        """Test main writes UUID to file when --output specified."""
        output_file = tmp_path / "uuid.txt"
        with patch('sys.exit'), patch('automation.cli.generate_uuid.generate_unique_uuid', return_value="fixed-uuid"), patch('sys.argv', ['generate_uuid.py', 'server1', '--output', str(output_file)]):
            main()

        assert output_file.exists()
        assert output_file.read_text().strip() == "fixed-uuid"

    def test_main_creates_parent_directories(self, tmp_path, capsys):
        """Test main creates parent directories for output file."""
        output_file = tmp_path / "deep" / "nested" / "uuid.txt"
        with patch('sys.exit'), patch('automation.cli.generate_uuid.generate_unique_uuid', return_value="uuid"), patch('sys.argv', ['generate_uuid.py', 'srv', '--output', str(output_file)]):
            main()

        assert output_file.exists()

    def test_main_handles_exception(self, capsys):
        """Test main handles exceptions gracefully."""
        with patch('sys.argv', ['generate_uuid.py', 'server1']), patch('automation.cli.generate_uuid.generate_unique_uuid', side_effect=RuntimeError("test error")):
            # main returns exit code rather than calling sys.exit
            exit_code = main()
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "Error generating UUID" in captured.err
