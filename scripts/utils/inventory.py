"""Server inventory and cluster catalogue loading utilities."""

import logging
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Optional

from .config import load_json_config

logger = logging.getLogger(__name__)


@dataclass
class ServerInfo:
    """Represents a server with its network addresses."""
    hostname: str
    ipmi_ip: Optional[str] = None
    ilo_ip: Optional[str] = None
    line_number: Optional[int] = None

    @property
    def name(self) -> str:
        """Return the server's primary identifier."""
        return self.hostname.split('.')[0]


def load_server_list(
    path: Path,
    include_details: bool = False
) -> List[ServerInfo] | List[str]:
    """
    Load server list from a text file.

    File format:
        # Comment lines ignored
        server1.example.com
        server2.example.com,192.168.1.102,192.168.1.202
        server3

    Args:
        path: Path to server list file
        include_details: If True, returns ServerInfo objects with IP addresses;
                        If False, returns list of hostname strings

    Returns:
        List of ServerInfo objects or list of hostname strings
    """
    if not path.exists():
        logger.error(f"Server list file not found: {path}")
        return []

    servers: List[ServerInfo] = []

    with open(path, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            parts = [p.strip() for p in line.split(',')]
            hostname = parts[0]

            if include_details:
                server = ServerInfo(
                    hostname=hostname,
                    ipmi_ip=parts[1] if len(parts) > 1 else None,
                    ilo_ip=parts[2] if len(parts) > 2 else None,
                    line_number=line_num
                )
                servers.append(server)
            else:
                servers.append(hostname)  # type: ignore

    logger.info(f"Loaded {len(servers)} servers from {path}")
    return servers


def load_cluster_catalogue(path: Path) -> Dict[str, Dict]:
    """
    Load cluster catalogue from JSON.

    Expected structure:
    {
        "clusters": {
            "CLUSTER-ID": {
                "display_name": "...",
                "servers": ["hostname1", "hostname2"],
                "scom_group": "...",
                ...
            }
        }
    }

    Args:
        path: Path to clusters_catalogue.json

    Returns:
        Dictionary mapping cluster_id -> cluster definition
    """
    config = load_json_config(path, required=True)
    clusters = config.get('clusters', {})

    if not clusters:
        logger.warning(f"No clusters defined in {path}")

    return clusters


def validate_cluster_definition(cluster_def: Dict, cluster_id: str) -> List[str]:
    """
    Validate that a cluster definition has all required fields.

    Args:
        cluster_def: Cluster configuration dictionary
        cluster_id: Cluster ID (for error messages)

    Returns:
        List of missing/invalid field names (empty if valid)
    """
    required_fields = ['display_name', 'servers', 'scom_group', 'environment']
    errors = []

    for field in required_fields:
        if field not in cluster_def:
            errors.append(f"Missing required field '{field}'")

    servers = cluster_def.get('servers', [])
    if not isinstance(servers, list) or len(servers) == 0:
        errors.append("'servers' must be a non-empty list")

    if 'ilo_addresses' in cluster_def:
        ilo_map = cluster_def['ilo_addresses']
        if not isinstance(ilo_map, dict):
            errors.append("'ilo_addresses' must be a dictionary")
        else:
            for server, ip in ilo_map.items():
                if not isinstance(ip, str):
                    errors.append(f"Invalid iLO IP for server {server}")

    if 'openview_node_ids' in cluster_def:
        ov_map = cluster_def['openview_node_ids']
        if not isinstance(ov_map, dict):
            errors.append("'openview_node_ids' must be a dictionary")

    return errors
