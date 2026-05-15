#!/usr/bin/env python3
"""
Generate deterministic UUIDs for HPE ProLiant servers.
UUID is based on server name, timestamp, and SHA256 hash for uniqueness.
"""

import argparse
import datetime
import hashlib
import sys
import uuid
from pathlib import Path


def generate_unique_uuid(server_name: str, timestamp: str = None) -> str:
    """
    Generate a deterministic UUID based on server name and timestamp.

    Args:
        server_name: The server's hostname or identifier
        timestamp: ISO format timestamp (optional, uses current time if not provided)

    Returns:
        UUID string in standard format (8-4-4-4-12)
    """
    if timestamp is None:
        timestamp = datetime.datetime.now().isoformat()

    # Combine server name with timestamp
    base_string = f"{server_name}-{timestamp}"

    # Create SHA256 hash
    hash_obj = hashlib.sha256(base_string.encode('utf-8'))

    # Use first 32 hex characters for UUID
    hash_hex = hash_obj.hexdigest()[:32]

    # Convert to UUID (ensures valid format)
    return str(uuid.UUID(hash_hex))

def main():
    parser = argparse.ArgumentParser(
        description="Generate deterministic UUID for HPE ProLiant servers"
    )
    parser.add_argument(
        "server_name",
        help="Server name or hostname"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file path (default: stdout)",
        default=None
    )
    parser.add_argument(
        "--timestamp", "-t",
        help="Custom timestamp in ISO format (default: current time)",
        default=None
    )

    args = parser.parse_args()

    try:
        generated_uuid = generate_unique_uuid(args.server_name, args.timestamp)

        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(f"{generated_uuid}\n")
            print(f"UUID written to {args.output}")
        else:
            print(generated_uuid)

        return 0
    except Exception as e:
        print(f"Error generating UUID: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
