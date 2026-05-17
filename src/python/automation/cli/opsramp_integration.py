#!/usr/bin/env python3
"""
OpsRamp Integration Module

Sends metrics, alerts, and events to OpsRamp API for monitoring
and reporting on ISO build, deployment, and installation status.
"""

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import requests
from requests.exceptions import RequestException

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


class OpsRampClient:
    """Client for OpsRamp API interactions."""

    TOKEN_URL = "/oauth/token"
    METRICS_URL = "/metrics"
    ALERTS_URL = "/alerts"
    EVENTS_URL = "/events"

    def __init__(self, config_path: str = "configs/opsramp_config.json"):
        """
        Initialize OpsRamp client.

        Args:
            config_path: Path to OpsRamp configuration JSON
        """
        self.config_path = Path(config_path)
        self.config = self._load_config()
        self.base_url = self.config.get("opsramp_api", {}).get("base_url", "")
        self.api_version = self.config.get("opsramp_api", {}).get("version", "v2")
        self.access_token = None
        self.token_expiry = None
        self.session = requests.Session()

    def _load_config(self) -> dict:
        """Load OpsRamp configuration."""
        try:
            with open(self.config_path) as f:
                config = json.load(f)

            # Override credentials with environment variables if present
            creds = config.get("credentials", {})
            env_client_id = os.environ.get("OPSRAMP_CLIENT_ID")
            env_client_secret = os.environ.get("OPSRAMP_CLIENT_SECRET")
            env_tenant_id = os.environ.get("OPSRAMP_TENANT_ID")

            if env_client_id:
                creds["client_id"] = env_client_id
            if env_client_secret:
                creds["client_secret"] = env_client_secret
            if env_tenant_id:
                creds["tenant_id"] = env_tenant_id

            config["credentials"] = creds
            logger.info("Loaded OpsRamp configuration")
            return config

        except FileNotFoundError:
            logger.error(f"OpsRamp config not found: {self.config_path}")
            return {}
        except json.JSONDecodeError as e:
            logger.error(f"Invalid OpsRamp config JSON: {e}")
            return {}

    def _get_token_url(self) -> str:
        """Construct full OAuth token URL."""
        return f"{self.base_url.rstrip('/')}/{self.api_version.lstrip('/')}{self.TOKEN_URL.lstrip('/')}"

    def _ensure_token(self) -> bool:
        """
        Ensure we have a valid access token, refreshing if necessary.

        Returns:
            True if token is valid
        """
        if self.access_token and self.token_expiry and datetime.now() < self.token_expiry:
            return True

        creds = self.config.get("credentials", {})
        client_id = creds.get("client_id")
        client_secret = creds.get("client_secret")

        if not client_id or not client_secret:
            logger.error("OpsRamp client ID and secret required")
            return False

        token_url = self._get_token_url()
        payload = {"grant_type": "client_credentials", "client_id": client_id, "client_secret": client_secret}

        try:
            response = requests.post(token_url, data=payload, timeout=30)
            response.raise_for_status()
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            # Set expiry slightly before actual expiry (store as datetime)
            expires_in = token_data.get("expires_in", 3600)
            self.token_expiry = datetime.now() + timedelta(seconds=expires_in * 0.9)

            # Update session headers
            self.session.headers.update({"Authorization": f"Bearer {self.access_token}"})

            logger.info("Successfully obtained OpsRamp access token")
            return True

        except RequestException as e:
            logger.error(f"Failed to obtain OpsRamp token: {e}")
            return False

    def _make_request(self, method: str, endpoint: str, data: dict = None, params: dict = None) -> Optional[dict]:
        """
        Make authenticated request to OpsRamp API.

        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint path
            data: Request body (dict, will be JSON-encoded)
            params: Query parameters

        Returns:
            Response JSON or None
        """
        if not self._ensure_token():
            return None

        url = f"{self.base_url.rstrip('/')}/{self.api_version.lstrip('/')}{endpoint}"

        try:
            response = self.session.request(method=method, url=url, json=data, params=params, timeout=30)
            response.raise_for_status()

            if response.content:
                return response.json()
            return {}

        except RequestException as e:
            logger.error(f"OpsRamp API request failed: {e}")
            if hasattr(e, "response") and e.response is not None:
                logger.error(f"Response: {e.response.text[:500]}")
            return None

    def send_metric(
        self, resource_id: str, metric_name: str, value: float, timestamp: datetime = None, tags: dict = None
    ) -> bool:
        """
        Send a metric data point to OpsRamp.

        Args:
            resource_id: Resource identifier (server UUID or name)
            metric_name: Metric name (e.g., "build.status")
            value: Metric value (float or int)
            timestamp: Metric timestamp (default: now)
            tags: Additional tags

        Returns:
            True if sent successfully
        """
        metric = {
            "resourceId": resource_id,
            "metric": {
                "name": metric_name,
                "value": value,
                "timestamp": (timestamp or datetime.now()).isoformat(),
                "type": "gauge",
            },
        }

        if tags:
            metric["metric"]["tags"] = tags

        result = self._make_request("POST", self.METRICS_URL, data=[metric])

        if result is not None:
            logger.debug(f"Sent metric to OpsRamp: {resource_id}.{metric_name}={value}")
            return True
        return False

    def send_alert(self, resource_id: str, alert_type: str, severity: str, message: str, details: dict = None) -> bool:
        """
        Send an alert to OpsRamp.

        Args:
            resource_id: Resource identifier
            alert_type: Alert type/category
            severity: Severity level (CRITICAL, WARNING, INFO)
            message: Alert message
            details: Additional alert details

        Returns:
            True if sent successfully
        """
        alert = {
            "resourceId": resource_id,
            "type": alert_type,
            "severity": severity,
            "message": message,
            "timestamp": datetime.now().isoformat(),
        }

        if details:
            alert["details"] = details

        result = self._make_request("POST", self.ALERTS_URL, data=alert)

        if result is not None:
            logger.info(f"Sent OpsRamp alert: {severity} - {resource_id}: {message}")
            return True
        return False

    def send_event(self, resource_id: str, event_type: str, message: str, properties: dict = None) -> bool:
        """
        Send an event to OpsRamp.

        Args:
            resource_id: Resource identifier
            event_type: Event type
            message: Event message
            properties: Additional properties

        Returns:
            True if sent successfully
        """
        event = {
            "resourceId": resource_id,
            "type": event_type,
            "message": message,
            "timestamp": datetime.now().isoformat(),
        }

        if properties:
            event["properties"] = properties

        result = self._make_request("POST", self.EVENTS_URL, data=event)

        if result is not None:
            logger.debug(f"Sent OpsRamp event: {event_type} for {resource_id}")
            return True
        return False

    def batch_send_metrics(self, metrics: list[dict]) -> bool:
        """
        Send multiple metrics in a single request.

        Args:
            metrics: List of metric dictionaries with keys:
                resourceId, metric: {name, value, timestamp, type}

        Returns:
            True if sent successfully
        """
        result = self._make_request("POST", self.METRICS_URL, data=metrics)

        return result is not None

    def report_build_status(self, server_name: str, build_data: dict) -> bool:
        """
        Convenience method to report complete build status.

        Args:
            server_name: Server hostname
            build_data: Build result dictionary from automation.cli.build_iso.py

        Returns:
            True if report sent successfully
        """
        # Use UUID as resource ID if available
        resource_id = build_data.get("uuid", server_name)

        # Send build status metric (1 = success, 0 = failure)
        build_status = 1 if build_data.get("success", False) else 0
        self.send_metric(
            resource_id=resource_id,
            metric_name="build.status",
            value=build_status,
            tags={"server": server_name, "type": "hpe_iso_build"},
        )

        # Send timestamp of build
        self.send_metric(
            resource_id=resource_id,
            metric_name="build.timestamp",
            value=datetime.now().timestamp(),
            tags={"server": server_name},
        )

        # Send alert if build failed
        if not build_data.get("success", False):
            error_msg = build_data.get("error", "Unknown build failure")
            self.send_alert(
                resource_id=resource_id,
                alert_type="build.failure",
                severity="CRITICAL",
                message=f"Build failed for {server_name}: {error_msg}",
                details=build_data,
            )

        # Send event for build completion
        event_msg = "Build succeeded" if build_data.get("success") else "Build failed"
        self.send_event(
            resource_id=resource_id,
            event_type="build.complete",
            message=event_msg,
            properties={"server": server_name, "success": build_data.get("success", False)},
        )

        logger.info(f"Reported build status to OpsRamp for {server_name}")
        return True

    def report_deployment_status(self, server_name: str, deploy_data: dict) -> bool:
        """
        Report deployment status to OpsRamp.

        Args:
            server_name: Server hostname
            deploy_data: Deployment result dictionary

        Returns:
            True if report sent
        """
        resource_id = deploy_data.get("uuid", server_name)

        success = deploy_data.get("success", False)
        self.send_metric(
            resource_id=resource_id,
            metric_name="deployment.status",
            value=1 if success else 0,
            tags={"server": server_name, "method": deploy_data.get("method", "unknown")},
        )

        if not success:
            self.send_alert(
                resource_id=resource_id,
                alert_type="deployment.failure",
                severity="WARNING",
                message=f"Deployment failed for {server_name}",
                details=deploy_data,
            )

        return True

    def report_installation_progress(
        self, server_name: str, uuid: str, progress_percent: int, phase: str, elapsed_seconds: int
    ) -> bool:
        """
        Report real-time installation progress.

        Args:
            server_name: Server hostname
            uuid: Server UUID
            progress_percent: Installation progress (0-100)
            phase: Current installation phase
            elapsed_seconds: Time elapsed since start

        Returns:
            True if report sent
        """
        resource_id = uuid or server_name

        tags = {"server": server_name, "phase": phase}

        self.send_metric(
            resource_id=resource_id, metric_name="install.progress.percent", value=progress_percent, tags=tags
        )

        self.send_metric(
            resource_id=resource_id, metric_name="install.elapsed_seconds", value=elapsed_seconds, tags=tags
        )

        return True

    def report_vulnerability_scan(self, server_name: str, uuid: str, scan_results: dict) -> bool:
        """
        Report vulnerability scan results.

        Args:
            server_name: Server hostname
            uuid: Server UUID
            scan_results: Dictionary with scan data

        Returns:
            True if report sent
        """
        resource_id = uuid or server_name

        vulnerability_count = scan_results.get("vulnerability_count", 0)
        critical_count = scan_results.get("critical_count", 0)

        self.send_metric(
            resource_id=resource_id,
            metric_name="security.vulnerabilities.total",
            value=vulnerability_count,
            tags={"server": server_name},
        )

        self.send_metric(
            resource_id=resource_id,
            metric_name="security.vulnerabilities.critical",
            value=critical_count,
            tags={"server": server_name},
        )

        if critical_count > 0:
            self.send_alert(
                resource_id=resource_id,
                alert_type="security.vulnerability",
                severity="CRITICAL" if critical_count > 0 else "WARNING",
                message=f"{critical_count} critical vulnerabilities found on {server_name}",
                details=scan_results,
            )

        return True


def main():
    """Simple CLI interface for testing OpsRamp integration."""
    parser = argparse.ArgumentParser(description="OpsRamp Integration Tool")
    parser.add_argument(
        "--action", "-a", choices=["test", "metric", "alert", "event"], default="test", help="Action to perform"
    )
    parser.add_argument("--server", default="test-server", help="Server name/resource ID")
    parser.add_argument("--uuid", help="Server UUID (optional)")
    parser.add_argument("--config", default="configs/opsramp_config.json", help="OpsRamp configuration path")
    parser.add_argument("--value", type=float, help="Metric value")
    parser.add_argument("--message", help="Alert/event message")

    args = parser.parse_args()

    client = OpsRampClient(args.config)

    if args.action == "test":
        logger.info("Testing OpsRamp connection...")
        if client._ensure_token():
            logger.info("✓ OpsRamp connection successful")
            return 0
        else:
            logger.error("✗ OpsRamp connection failed")
            return 1

    elif args.action == "metric":
        if args.value is None:
            logger.error("--value required for metric action")
            return 1
        success = client.send_metric(
            resource_id=args.uuid or args.server, metric_name="test.metric", value=args.value, tags={"test": "true"}
        )
        return 0 if success else 1

    elif args.action == "alert":
        if not args.message:
            logger.error("--message required for alert action")
            return 1
        success = client.send_alert(
            resource_id=args.uuid or args.server,
            alert_type="test.alert",
            severity="INFO",
            message=args.message,
            details={"test": True},
        )
        return 0 if success else 1

    elif args.action == "event":
        if not args.message:
            logger.error("--message required for event action")
            return 1
        success = client.send_event(
            resource_id=args.uuid or args.server,
            event_type="test.event",
            message=args.message,
            properties={"test": True},
        )
        return 0 if success else 1

    return 0


if __name__ == "__main__":
    import os

    sys.exit(main())
