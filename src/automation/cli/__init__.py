"""
CLI entry points for HPE ProLiant Windows Server ISO Automation.

Each module provides a ``main()`` function that serves as the entry point
for command-line execution. Run any module via:

.. code-block:: bash

    python -m automation.cli.build_iso [args...]

Or after installing with ``pip install -e .``:

.. code-block:: bash

    build-iso [args...]

Available CLI modules:
    - build_iso: Main orchestrator for complete ISO builds
    - update_firmware_drivers: HPE SUT firmware/driver integration
    - patch_windows_security: DISM-based Windows patching
    - deploy_to_server: ISO deployment via HPE iLO Virtual Media
    - monitor_install: Installation progress monitoring
    - opsramp_integration: OpsRamp API integration
    - maintenance_mode: SCOM/iLO maintenance orchestration
    - generate_uuid: Deterministic UUID generation
"""

__all__ = [
    "build_iso",
    "update_firmware_drivers",
    "patch_windows_security",
    "deploy_to_server",
    "monitor_install",
    "opsramp_integration",
    "maintenance_mode",
    "generate_uuid",
]
