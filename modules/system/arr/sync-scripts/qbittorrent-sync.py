#!/usr/bin/env python3
"""
qbittorrent-sync.py

Synchronizes declarative passwords from SOPS into qBittorrent's configuration file (qBittorrent.conf).
Designed to run automatically as ExecStartPre before the qbittorrent service startup.
"""

from __future__ import annotations

import argparse
import base64
import grp
import hashlib
import hmac
import logging
import os
import pwd
import sys
import tempfile
from pathlib import Path
from typing import Optional

# Configure clean structured logging
LOG_FORMAT = "[qbittorrent-sync] %(levelname)-5s: %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("qbittorrent-sync")


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Synchronize admin password into qBittorrent.conf."
    )
    parser.add_argument(
        "--pass-file",
        type=Path,
        required=True,
        help="Path to secret file containing the qBittorrent WebUI password.",
    )
    parser.add_argument(
        "--conf-file",
        type=Path,
        default=Path("/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf"),
        help="Path to qBittorrent.conf configuration file.",
    )
    parser.add_argument(
        "--user",
        type=str,
        default="qbittorrent",
        help="qBittorrent system user for file ownership (default: qbittorrent).",
    )
    parser.add_argument(
        "--group",
        type=str,
        default="media",
        help="Media group name for file ownership (default: media).",
    )
    return parser.parse_args()


def read_password(path: Path) -> Optional[bytes]:
    """
    Safely reads the password file. Returns UTF-8 encoded bytes or None.
    """
    if not path.is_file():
        logger.warning(f"Password file '{path}' does not exist. Skipping password sync.")
        return None

    try:
        content = path.read_text(encoding="utf-8").rstrip("\r\n")
        if not content:
            logger.warning(f"Password file '{path}' is empty. Skipping password sync.")
            return None
        return content.encode("utf-8")
    except Exception as exc:
        logger.warning(f"Failed to read password file '{path}': {exc}. Skipping password sync.")
        return None


def verify_qbittorrent_hash(password: bytes, raw_value: str) -> bool:
    """
    Verifies if the given password matches qBittorrent's stored PBKDF2 hash.
    Format: @ByteArray(<base64_salt>:<base64_hash>) or with optional quotes.
    """
    cleaned = raw_value.strip().strip('"').strip("'")
    if not (cleaned.startswith("@ByteArray(") and cleaned.endswith(")")):
        return False

    inner = cleaned[len("@ByteArray(") : -1]
    if ":" not in inner:
        return False

    parts = inner.split(":", 1)
    salt_b64, expected_hash_b64 = parts[0], parts[1]

    try:
        salt = base64.b64decode(salt_b64)
        computed_hash = hashlib.pbkdf2_hmac("sha512", password, salt, 100000)
        computed_hash_b64 = base64.b64encode(computed_hash).decode("ascii")
        return hmac.compare_digest(computed_hash_b64, expected_hash_b64)
    except Exception as exc:
        logger.warning(f"Could not verify existing PBKDF2 hash: {exc}")
        return False


def generate_qbittorrent_hash(password: bytes) -> str:
    """
    Generates a qBittorrent-compatible PBKDF2 HMAC-SHA512 hash:
    @ByteArray(<base64_salt>:<base64_hash>) with 100,000 iterations and 16-byte salt.
    """
    salt = os.urandom(16)
    hashed = hashlib.pbkdf2_hmac("sha512", password, salt, 100000)
    b64_salt = base64.b64encode(salt).decode("ascii")
    b64_hash = base64.b64encode(hashed).decode("ascii")
    return f'@ByteArray({b64_salt}:{b64_hash})'


def sync_config(conf_path: Path, password: bytes) -> bool:
    """
    Updates or inserts the WebUI\\Password_PBKDF2 line in qBittorrent.conf.
    Uses atomic file replacement to prevent config corruption.
    Returns True if the file was modified, False if already up-to-date.
    """
    lines: list[str] = []
    already_valid = False

    if conf_path.is_file():
        # Check write permissions (e.g. if run manually as non-root)
        if not os.access(conf_path, os.W_OK):
            logger.warning(
                f"Config file '{conf_path}' is not writable by current user. "
                "If running manually for testing, please run with sudo or as root. Skipping sync."
            )
            return False

        try:
            lines = conf_path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
        except Exception as exc:
            logger.warning(f"Failed to read existing config '{conf_path}': {exc}")
            lines = []

        # Check if current password is already valid to save unnecessary SSD writes
        for line in lines:
            if line.startswith(r"WebUI\Password_PBKDF2="):
                current_val = line.split("=", 1)[1]
                if verify_qbittorrent_hash(password, current_val):
                    already_valid = True
                    break

    if already_valid:
        logger.info("qBittorrent password in config is already up-to-date.")
        return False

    new_hash_value = generate_qbittorrent_hash(password)
    new_line = f'WebUI\\Password_PBKDF2="{new_hash_value}"\n'

    new_lines: list[str] = []
    found = False
    in_preferences = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_preferences = (stripped.lower() == "[preferences]")

        if line.startswith(r"WebUI\Password_PBKDF2="):
            new_lines.append(new_line)
            found = True
        elif in_preferences and not found and stripped.startswith("["):
            # Put password right at the top of [Preferences]
            new_lines.append(line)
            new_lines.append(new_line)
            found = True
        else:
            new_lines.append(line)

    if not found:
        if not any(l.strip().lower() == "[preferences]" for l in new_lines):
            new_lines.append("\n[Preferences]\n")
        new_lines.append(new_line)

    # Ensure parent directory exists
    conf_path.parent.mkdir(parents=True, exist_ok=True)

    # Atomic write via temporary file in the same directory
    temp_dir = conf_path.parent
    try:
        with tempfile.NamedTemporaryFile("w", dir=temp_dir, delete=False, encoding="utf-8") as tf:
            temp_path = Path(tf.name)
            tf.writelines(new_lines)
            tf.flush()
            os.fsync(tf.fileno())

        temp_path.replace(conf_path)
        logger.info(f"Updated qBittorrent password hash in '{conf_path}'.")
        return True
    except Exception as exc:
        logger.error(f"Failed to atomically write '{conf_path}': {exc}")
        return False


def fix_permissions(conf_path: Path, user_name: str, group_name: str) -> None:
    """
    Sets appropriate user/group ownership and permissions (0664).
    """
    if not conf_path.exists():
        return

    uid = -1
    gid = -1

    try:
        uid = pwd.getpwnam(user_name).pw_uid
    except KeyError:
        logger.warning(f"System user '{user_name}' not found. Leaving UID unchanged.")

    try:
        gid = grp.getgrnam(group_name).gr_gid
    except KeyError:
        logger.warning(f"System group '{group_name}' not found. Leaving GID unchanged.")

    try:
        if uid != -1 or gid != -1:
            os.chown(conf_path, uid, gid)
        conf_path.chmod(0o664)
    except OSError as exc:
        logger.warning(f"Could not adjust permissions for '{conf_path}': {exc}")


def main() -> int:
    """Main entry point."""
    args = parse_arguments()

    password = read_password(args.pass_file)
    if password is None:
        return 0

    try:
        sync_config(args.conf_file, password)
        fix_permissions(args.conf_file, args.user, args.group)
        logger.info("qBittorrent sync completed successfully.")
        return 0
    except Exception as exc:
        logger.error(f"Unexpected error during qBittorrent sync: {exc}", exc_info=True)
        # Exit 0 so unexpected sync issues do not prevent the service from starting
        return 0


if __name__ == "__main__":
    sys.exit(main())
