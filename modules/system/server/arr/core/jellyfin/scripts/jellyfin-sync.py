#!/usr/bin/env python3
"""
jellyfin-sync.py

Synchronizes declarative admin credentials and API keys into Jellyfin's SQLite database.
Designed to run automatically as ExecStartPre before Jellyfin service startup.
"""

from __future__ import annotations

import argparse
import glob
import grp
import hashlib
import hmac
import logging
import os
import pwd
import sqlite3
import sys
from pathlib import Path
from typing import Optional

# Configure clean structured logging
LOG_FORMAT = "[jellyfin-sync] %(levelname)-5s: %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("jellyfin-sync")


class JellyfinSyncError(Exception):
    """Custom exception for Jellyfin synchronization errors."""
    pass


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Synchronize admin password and API keys into Jellyfin SQLite DB."
    )
    parser.add_argument(
        "--pass-file",
        type=Path,
        required=True,
        help="Path to secret file containing the admin user password.",
    )
    parser.add_argument(
        "--key-file",
        type=Path,
        required=True,
        help="Path to secret file containing the nixflix API key.",
    )
    parser.add_argument(
        "--admin-user",
        type=str,
        required=True,
        help="Username of the Jellyfin administrator account.",
    )
    parser.add_argument(
        "--media-group",
        type=str,
        default="media",
        help="Media group name for file ownership (default: media).",
    )
    parser.add_argument(
        "--jellyfin-user",
        type=str,
        default="jellyfin",
        help="Jellyfin system user name for file ownership (default: jellyfin).",
    )
    parser.add_argument(
        "--db-path",
        type=Path,
        default=Path("/var/lib/jellyfin/data/jellyfin.db"),
        help="Path to jellyfin.db SQLite database file.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="SQLite database lock timeout in seconds (default: 30.0).",
    )
    return parser.parse_args()


def read_secret_file(path: Path, secret_name: str) -> Optional[str]:
    """
    Safely read a secret file, handling missing files or read errors gracefully.
    Returns None if file does not exist or cannot be read.
    """
    if not path.is_file():
        logger.warning(f"{secret_name} file does not exist at '{path}'. Skipping.")
        return None

    try:
        content = path.read_text(encoding="utf-8").rstrip("\r\n")
        if not content:
            logger.warning(f"{secret_name} file at '{path}' is empty. Skipping.")
            return None
        return content
    except Exception as exc:
        logger.warning(f"Could not read {secret_name} file '{path}': {exc}. Skipping.")
        return None


def verify_pbkdf2_sha512(password: str, formatted_hash: str) -> bool:
    """
    Verifies if a password matches Jellyfin's standard PBKDF2-SHA512 hash format:
    $PBKDF2-SHA512$iterations=<N>$<SALT_HEX>$<HASH_HEX>
    """
    if not formatted_hash or not formatted_hash.startswith("$PBKDF2-SHA512$iterations="):
        return False

    try:
        parts = formatted_hash.split("$")
        if len(parts) < 5:
            return False

        iterations_str = parts[2]
        iterations = int(iterations_str.split("=")[1])
        salt = bytes.fromhex(parts[3])
        expected_hash_hex = parts[4].upper()

        computed_hash_hex = hashlib.pbkdf2_hmac(
            "sha512",
            password.encode("utf-8"),
            salt,
            iterations,
            dklen=64
        ).hex().upper()

        return hmac.compare_digest(computed_hash_hex, expected_hash_hex)
    except Exception as exc:
        logger.warning(f"Failed to parse existing password hash: {exc}")
        return False


def generate_pbkdf2_sha512(password: str, iterations: int = 210000) -> str:
    """
    Generates a Jellyfin-compliant PBKDF2-SHA512 formatted hash.
    Default iterations: 210,000 (Jellyfin standard).
    """
    salt = os.urandom(16)
    salt_hex = salt.hex().upper()
    hash_hex = hashlib.pbkdf2_hmac(
        "sha512",
        password.encode("utf-8"),
        salt,
        iterations,
        dklen=64
    ).hex().upper()
    return f"$PBKDF2-SHA512$iterations={iterations}${salt_hex}${hash_hex}"


def sync_database(
    db_path: Path,
    admin_user: str,
    password: Optional[str],
    api_key: Optional[str],
    timeout: float,
) -> None:
    """
    Synchronizes admin user password and nixflix API key into the SQLite database.
    """
    if not db_path.is_file():
        logger.info(f"Database file '{db_path}' does not exist yet. Jellyfin will initialize it.")
        return

    # Check write access to prevent sqlite OperationalError if run manually by non-root
    if not os.access(db_path, os.W_OK):
        logger.warning(
            f"Database file '{db_path}' is not writable by current user. "
            "If running manually for testing, please run with sudo or as root. Skipping sync."
        )
        return

    try:
        conn = sqlite3.connect(str(db_path), timeout=timeout)
    except sqlite3.OperationalError as exc:
        logger.warning(f"Database '{db_path}' is busy or inaccessible: {exc}. Skipping sync.")
        return

    with conn:
        cur = conn.cursor()
        cur.execute("PRAGMA busy_timeout = 30000;")

        # Check existing tables to handle premature runs before migrations complete
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('Users', 'ApiKeys');")
        existing_tables = {row[0] for row in cur.fetchall()}

        # 1. Admin Password Synchronization
        if "Users" in existing_tables and password is not None:
            cur.execute(
                "SELECT Id, Password, InvalidLoginAttemptCount FROM Users WHERE Username = ?;",
                (admin_user,),
            )
            user_row = cur.fetchone()
            if user_row:
                _user_id, current_hash, invalid_attempts = user_row
                if not verify_pbkdf2_sha512(password, current_hash):
                    new_hash = generate_pbkdf2_sha512(password)
                    cur.execute(
                        "UPDATE Users SET Password = ?, InvalidLoginAttemptCount = 0 WHERE Username = ?;",
                        (new_hash, admin_user),
                    )
                    logger.info(f"Updated password hash for admin user '{admin_user}'.")
                elif invalid_attempts and invalid_attempts > 0:
                    cur.execute(
                        "UPDATE Users SET InvalidLoginAttemptCount = 0 WHERE Username = ?;",
                        (admin_user,),
                    )
                    logger.info(f"Reset InvalidLoginAttemptCount for admin user '{admin_user}'.")
            else:
                logger.info(f"Admin user '{admin_user}' not found in Users table yet.")
        else:
            logger.info("Table 'Users' not ready or password omitted.")

        # 2. nixflix API Key Synchronization
        if "ApiKeys" in existing_tables and api_key is not None:
            cur.execute("SELECT AccessToken FROM ApiKeys WHERE Name = 'nixflix';")
            key_row = cur.fetchone()
            if not key_row or not hmac.compare_digest(key_row[0], api_key):
                # Clean up any conflicting or outdated keys
                cur.execute("DELETE FROM ApiKeys WHERE Name = 'nixflix' OR AccessToken = ?;", (api_key,))
                cur.execute(
                    "INSERT INTO ApiKeys (AccessToken, Name, DateCreated, DateLastActivity) "
                    "VALUES (?, 'nixflix', datetime('now'), datetime('now'));",
                    (api_key,),
                )
                logger.info("Synchronized 'nixflix' API token in ApiKeys table.")
        else:
            logger.info("Table 'ApiKeys' not ready or API key omitted.")


def fix_file_permissions(db_path: Path, user_name: str, group_name: str) -> None:
    """
    Ensures jellyfin.db and its associated SQLite files (-wal, -shm, -journal)
    have the correct owner (jellyfin:media) and permissions (0644).
    """
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

    # Match db_path and any SQLite auxiliary files (jellyfin.db-wal, jellyfin.db-shm, etc.)
    pattern = f"{db_path}*"
    for file_str in glob.glob(pattern):
        fpath = Path(file_str)
        try:
            if uid != -1 or gid != -1:
                os.chown(fpath, uid, gid)
            fpath.chmod(0o644)
        except OSError as exc:
            logger.warning(f"Could not adjust permissions for '{fpath}': {exc}")


def main() -> int:
    """Main entry point."""
    args = parse_arguments()

    password = read_secret_file(args.pass_file, "Password")
    api_key = read_secret_file(args.key_file, "API Key")

    try:
        sync_database(
            db_path=args.db_path,
            admin_user=args.admin_user,
            password=password,
            api_key=api_key,
            timeout=args.timeout,
        )
        fix_file_permissions(
            db_path=args.db_path,
            user_name=args.jellyfin_user,
            group_name=args.media_group,
        )
        logger.info("Synchronization process completed successfully.")
        return 0
    except Exception as exc:
        logger.error(f"Unexpected error during Jellyfin sync: {exc}", exc_info=True)
        # Return 0 so transient sync failure does not prevent Jellyfin service from launching
        return 0


if __name__ == "__main__":
    sys.exit(main())
