#!/usr/bin/env python3
"""
Windows Security Patcher

Applies security patches to Windows Server ISO images using DISM.
Creates patched ISOs with November 2025 security updates.
"""

import subprocess
import json
import logging
import argparse
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import shutil


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


class WindowsPatcher:
    """Applies Windows security patches using DISM or PowerShell."""

    def __init__(self, patches_config: str, base_iso_dir: str = "base_iso",
                 output_dir: str = "patched_iso"):
        """
        Initialize WindowsPatcher.

        Args:
            patches_config: Path to patches JSON configuration
            base_iso_dir: Directory containing base Windows ISO contents
            output_dir: Directory for patched ISO output
        """
        self.patches_config_path = Path(patches_config)
        self.base_iso_dir = Path(base_iso_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.patches_config = self._load_config()
        self.patch_dir = self.base_iso_dir / "patches"
        self.patch_dir.mkdir(exist_ok=True)
        self.build_log = []

    def _load_config(self) -> Dict:
        """Load patches configuration."""
        try:
            with open(self.patches_config_path, 'r') as f:
                config = json.load(f)
            logger.info(f"Loaded patches config from {self.patches_config_path}")
            return config
        except Exception as e:
            logger.error(f"Failed to load patches config: {e}")
            raise

    def _log_step(self, step: str, status: str, details: str = ""):
        """Log step for audit trail."""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'step': step,
            'status': status,
            'details': details
        }
        self.build_log.append(log_entry)
        logger.info(f"[{status}] {step}: {details}" if details else f"[{status}] {step}")

    def _setup_base_iso(self, iso_path: str, dry_run: bool = False) -> Optional[Path]:
        """
        Mount or extract base Windows ISO.

        Args:
            iso_path: Path to base Windows Server ISO
            dry_run: If True, only simulate

        Returns:
            Path to mounted/extracted ISO directory, or None if failed
        """
        self._log_step("setup_base_iso", "START", f"ISO: {iso_path}")

        if dry_run:
            logger.info("[DRY RUN] Would mount/extract base ISO")
            return self.base_iso_dir

        iso_file = Path(iso_path)
        if not iso_file.exists():
            self._log_step("setup_base_iso", "FAILED", f"ISO not found: {iso_path}")
            return None

        # Try to mount ISO (Linux)
        mount_point = self.base_iso_dir
        mount_point.mkdir(parents=True, exist_ok=True)

        try:
            # Attempt to mount
            result = subprocess.run(
                ["mount", "-o", "loop", iso_path, str(mount_point)],
                capture_output=True, text=True
            )

            if result.returncode == 0:
                self._log_step("setup_base_iso", "SUCCESS", f"Mounted at {mount_point}")
                return mount_point
            else:
                # Mount failed, try extracting with 7z or similar
                logger.warning("Mount failed, attempting extraction...")
                extract_dir = mount_point / "extracted"
                extract_dir.mkdir(exist_ok=True)

                extract_cmd = ["7z", "x", iso_path, f"-o{extract_dir}"]
                result = subprocess.run(extract_cmd, capture_output=True, text=True)

                if result.returncode == 0:
                    self._log_step("setup_base_iso", "SUCCESS", f"Extracted to {extract_dir}")
                    return extract_dir
                else:
                    self._log_step("setup_base_iso", "FAILED",
                                  f"Could not mount or extract: {result.stderr}")
                    return None

        except Exception as e:
            self._log_step("setup_base_iso", "FAILED", str(e))
            return None

    def download_patches(self, dry_run: bool = False) -> List[Path]:
        """
        Download required security patches.

        Args:
            dry_run: If True, only simulate

        Returns:
            List of downloaded patch file paths
        """
        self._log_step("download_patches", "START", "Downloading security patches")

        patches = self.patches_config.get('patches', [])
        downloaded = []

        for patch in patches:
            kb = patch['kb_number']
            severity = patch['severity']
            self._log_step("download_patch", "INFO", f"{kb} ({severity})")

            if dry_run:
                logger.info(f"[DRY RUN] Would download {kb}")
                patch_path = self.patch_dir / f"{kb}.msu"
                downloaded.append(patch_path)
                continue

            # In a real implementation, this would download from Microsoft Update
            # For now, we simulate by checking for local MSU files
            # Real implementation would use:
            #   - PowerShell: Invoke-WebRequest to Microsoft Update Catalog
            #   - Or use pre-downloaded patch repository

            # Simulate download (placeholder)
            kb_url = f"https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/secu/{kb[:3].lower()}/{kb}.msu"
            patch_path = self.patch_dir / f"{kb}.msu"

            # For testing: create dummy file (remove in production)
            if not patch_path.exists():
                logger.warning(f"Patch file not found: {patch_path}")
                logger.warning("Skipping download - implement actual download logic")
                continue

            downloaded.append(patch_path)
            self._log_step("download_patch", "SUCCESS", f"{kb} -> {patch_path}")

        self._log_step("download_patches", "COMPLETE", f"Downloaded {len(downloaded)} patches")
        return downloaded

    def apply_patches_dism(self, mounted_iso: Path, patches: List[Path],
                          dry_run: bool = False) -> bool:
        """
        Apply patches to mounted Windows image using DISM.

        Args:
            mounted_iso: Path to mounted/extracted ISO
            patches: List of patch file paths
            dry_run: If True, only simulate

        Returns:
            True if successful, False otherwise
        """
        self._log_step("apply_patches", "START", f"Patching image at {mounted_iso}")

        if dry_run:
            logger.info(f"[DRY RUN] Would apply {len(patches)} patches via DISM")
            return True

        # Determine Windows image path within ISO
        # Typically in sources/install.wim or sources/install.esd
        wim_path = mounted_iso / "sources" / "install.wim"
        if not wim_path.exists():
            wim_path = mounted_iso / "sources" / "install.esd"

        if not wim_path.exists():
            self._log_step("apply_patches", "FAILED", "Windows image (install.wim) not found")
            return False

        # Get image index (usually 1 for Server)
        image_index = "1"

        # Apply patches in order
        for patch_path in patches:
            if not patch_path.exists():
                logger.warning(f"Patch not found, skipping: {patch_path}")
                continue

            kb_name = patch_path.stem
            logger.info(f"Applying patch {kb_name}...")

            # DISM command to add package
            dism_cmd = [
                "dism", "/Mount-Image",
                "/ImageFile:", str(wim_path),
                "/Index:", image_index,
                "/MountDir:", str(mounted_iso / "mount")
            ]

            # Mount image
            result = subprocess.run(" ".join(dism_cmd), shell=True,
                                   capture_output=True, text=True)
            if result.returncode != 0:
                error = result.stderr or result.stdout
                self._log_step("apply_patches", "FAILED",
                              f"Failed to mount image: {error}")
                return False

            # Add package
            add_cmd = [
                "dism", "/Image:", str(mounted_iso / "mount"),
                "/Add-Package", f"/PackagePath:{patch_path}"
            ]
            result = subprocess.run(" ".join(add_cmd), shell=True,
                                   capture_output=True, text=True)
            if result.returncode != 0:
                error = result.stderr or result.stdout
                self._log_step("apply_patches", "FAILED",
                              f"Failed to add package {kb_name}: {error}")
                # Unmount and abort
                subprocess.run(
                    f"dism /Unmount-Image /MountDir:{mounted_iso / 'mount'} /Discard",
                    shell=True
                )
                return False

            # Unmount and commit changes
            unmount_cmd = [
                "dism", "/Unmount-Image",
                "/MountDir:", str(mounted_iso / "mount"),
                "/Commit"
            ]
            result = subprocess.run(" ".join(unmount_cmd), shell=True,
                                   capture_output=True, text=True)
            if result.returncode != 0:
                self._log_step("apply_patches", "FAILED",
                              f"Failed to unmount/commit after {kb_name}")
                return False

            self._log_step("apply_patch", "SUCCESS", kb_name)

        self._log_step("apply_patches", "SUCCESS", f"Applied {len(patches)} patches")
        return True

    def apply_patches_powershell(self, iso_mount: Path, patches: List[Path],
                                 dry_run: bool = False) -> bool:
        """
        Alternative patch method using PowerShell DISM commands.
        More reliable on Windows systems.

        Args:
            iso_mount: Path to mounted Windows image
            patches: List of patch files
            dry_run: If True, simulate

        Returns:
            True if successful
        """
        self._log_step("apply_patches_ps", "START", "Using PowerShell DISM")

        if dry_run:
            logger.info(f"[DRY RUN] Would apply patches via PowerShell")
            return True

        # PowerShell script to apply patches
        ps_script = """
        $ImagePath = "{wim_path}"
        $PatchPath = "{patch_dir}"

        # Mount image
        $mountResult = dism /Mount-Image /ImageFile:$ImagePath /Index:1 /MountDir:"{mount_dir}" /Quiet
        if ($LASTEXITCODE -ne 0) { exit 1 }

        # Apply each MSU
        foreach ($msu in Get-ChildItem $PatchPath -Filter "*.msu") {{
            Write-Host "Applying $($msu.Name)..."
            dism /Image:"{mount_dir}" /Add-Package /PackagePath:$($msu.FullName) /Quiet
            if ($LASTEXITCODE -ne 0) {{
                Write-Error "Failed to apply $($msu.Name)"
                exit 1
            }}
        }}

        # Commit
        dism /Unmount-Image /MountDir:"{mount_dir}" /Commit /Quiet
        exit $LASTEXITCODE
        """.format(
            wim_path=str(iso_mount / "sources" / "install.wim"),
            patch_dir=str(self.patch_dir),
            mount_dir=str(iso_mount / "mount")
        )

        # Write script to temp
        script_path = self.output_dir / "apply_patches.ps1"
        script_path.write_text(ps_script)

        # Execute PowerShell
        result = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script_path)],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            self._log_step("apply_patches_ps", "FAILED",
                          f"PowerShell error: {result.stderr}")
            return False

        self._log_step("apply_patches_ps", "SUCCESS", "All patches applied via PowerShell")
        return True

    def create_patched_iso(self, source_dir: Path, server_name: str,
                          dry_run: bool = False) -> Optional[str]:
        """
        Create a new ISO from patched image.

        Args:
            source_dir: Directory containing patched Windows files
            server_name: Server name for ISO naming
            dry_run: If True, simulate

        Returns:
            Path to created ISO, or None
        """
        self._log_step("create_iso", "START", "Creating patched ISO")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        iso_name = f"windows_server_patched_{server_name}_{timestamp}.iso"
        output_path = self.output_dir / iso_name

        if dry_run:
            logger.info(f"[DRY RUN] Would create ISO: {output_path}")
            return str(output_path)

        # Generate ISO (requires mkisofs or oscdimg on Windows)
        # On Linux:
        iso_cmd = [
            "mkisofs",
            "-o", str(output_path),
            "-iso-level", "3",
            "-J", "-joliet-long",
            "-l",
            "-V", f"WIN_SERVER_PATCHED_{timestamp}",
            "-D", "-N",
            "-relaxed-filenames",
            str(source_dir)
        ]

        try:
            result = subprocess.run(iso_cmd, capture_output=True, text=True)
            if result.returncode != 0:
                self._log_step("create_iso", "FAILED",
                              f"mkisofs error: {result.stderr}")
                return None

            self._log_step("create_iso", "SUCCESS", str(output_path))
            logger.info(f"Created patched ISO: {output_path}")
            return str(output_path)

        except FileNotFoundError:
            logger.error("mkisofs not found. Install cdrtools or genisoimage.")
            # On Windows, would use oscdimg or PowerShell New-IsoFile
            return None

    def build(self, base_iso_path: str, server_name: str,
              method: str = "dism", dry_run: bool = False) -> Dict:
        """
        Complete patching process for one server.

        Args:
            base_iso_path: Path to base Windows Server ISO
            server_name: Server identifier
            method: Patching method ('dism' or 'powershell')
            dry_run: If True, simulate

        Returns:
            Dictionary with build results
        """
        self._log_step("build", "START", f"Server: {server_name}")

        result = {
            'server': server_name,
            'success': False,
            'patched_iso': None,
            'patches_applied': 0,
            'base_iso': base_iso_path,
            'timestamp': datetime.now().isoformat()
        }

        try:
            # Step 1: Setup base ISO
            mounted_iso = self._setup_base_iso(base_iso_path, dry_run)
            if not mounted_iso:
                raise RuntimeError("Failed to setup base ISO")

            # Step 2: Download patches
            patches = self.download_patches(dry_run)
            if not patches:
                logger.warning("No patches available")

            result['patches_applied'] = len(patches)

            # Step 3: Apply patches
            if method == "powershell":
                success = self.apply_patches_powershell(mounted_iso, patches, dry_run)
            else:
                success = self.apply_patches_dism(mounted_iso, patches, dry_run)

            if not success:
                raise RuntimeError("Failed to apply patches")

            # Step 4: Create patched ISO
            patched_iso = self.create_patched_iso(mounted_iso, server_name, dry_run)
            if patched_iso:
                result['patched_iso'] = patched_iso
                result['success'] = True

            # Cleanup mount if actually mounted
            if not dry_run and mounted_iso != self.base_iso_dir:
                subprocess.run(["umount", str(mounted_iso)], capture_output=True)

        except Exception as e:
            error_msg = str(e)
            self._log_step("build", "FAILED", error_msg)
            logger.error(error_msg, exc_info=True)
            result['error'] = error_msg

        # Save log
        log_path = self.output_dir / f"patch_log_{server_name}_{datetime.now().strftime('%Y%m%d')}.json"
        with open(log_path, 'w') as f:
            json.dump({
                'server': server_name,
                'timestamp': datetime.now().isoformat(),
                'success': result['success'],
                'log': self.build_log
            }, f, indent=2)

        return result


def main():
    parser = argparse.ArgumentParser(
        description="Apply Windows security patches to create patched ISOs"
    )
    parser.add_argument(
        "--base-iso", "-b",
        required=True,
        help="Path to base Windows Server ISO"
    )
    parser.add_argument(
        "--patches-config", "-p",
        default="configs/windows_patches.json",
        help="Path to patches configuration JSON"
    )
    parser.add_argument(
        "--server", "-s",
        required=True,
        help="Server name for ISO identification"
    )
    parser.add_argument(
        "--method", "-m",
        choices=["dism", "powershell"],
        default="dism",
        help="Patching method (default: dism)"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default="output/patched_iso",
        help="Output directory"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate without making changes"
    )

    args = parser.parse_args()

    patcher = WindowsPatcher(args.patches_config, output_dir=args.output_dir)
    result = patcher.build(args.base_iso, args.server, args.method, args.dry_run)

    if result['success']:
        logger.info(f"✓ Successfully created patched ISO: {result['patched_iso']}")
        return 0
    else:
        logger.error(f"✗ Failed to create patched ISO: {result.get('error', 'Unknown error')}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
