"""Input validation for all external callers."""

import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


def validate_cluster_id(
    cluster_id: str,
    catalogue_path: Path = Path("configs/clusters_catalogue.json"),
) -> Optional[dict]:
    """
    Validate cluster_id exists in catalogue and return cluster definition.

    Args:
        cluster_id: Cluster identifier from iRequest/Jenkins/scheduler
        catalogue_path: Path to clusters_catalogue.json

    Returns:
        Cluster definition dict if valid, None otherwise
    """
    if not cluster_id:
        logger.error("Cluster ID is empty")
        return None

    if not catalogue_path.exists():
        logger.error("Cluster catalogue not found: %s", catalogue_path)
        return None

    import json
    with open(catalogue_path) as f:
        catalogue = json.load(f)

    clusters = catalogue.get("clusters", {})
    if cluster_id not in clusters:
        logger.error("Cluster '%s' not found in catalogue", cluster_id)
        logger.info("Available clusters: %s", list(clusters.keys()))
        return None

    cluster_def = clusters[cluster_id]

    # Validate required fields
    required_fields = ["servers", "scom_group", "ilo_addresses"]
    missing = [f for f in required_fields if f not in cluster_def]
    if missing:
        logger.error("Cluster '%s' missing required fields: %s", cluster_id, missing)
        return None

    return cluster_def


def validate_server_list(
    server_list_path: Path = Path("configs/server_list.txt"),
) -> list[str]:
    """
    Validate and load server list.

    Args:
        server_list_path: Path to server_list.txt

    Returns:
        List of valid server hostnames
    """
    if not server_list_path.exists():
        logger.error("Server list not found: %s", server_list_path)
        return []

    servers = []
    with open(server_list_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                # Handle comma-separated format: hostname,ipmi,ilo
                hostname = line.split(",")[0].strip()
                if hostname:
                    servers.append(hostname)

    if not servers:
        logger.warning("No valid servers found in %s", server_list_path)

    return servers


def validate_build_params(
    base_iso_path: Optional[str] = None,
    dry_run: bool = False,
) -> list[str]:
    """
    Validate build parameters.

    Args:
        base_iso_path: Path to base Windows ISO (required for builds)
        dry_run: Whether this is a dry run

    Returns:
        List of validation errors (empty if valid)
    """
    errors = []

    if base_iso_path and not Path(base_iso_path).exists():
        errors.append(f"Base ISO not found: {base_iso_path}")

    return errors
