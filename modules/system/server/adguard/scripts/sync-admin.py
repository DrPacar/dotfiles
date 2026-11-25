#!/usr/bin/env python3
"""
AdGuard Home Admin User Sync Script
Synchronizes the admin user and bcrypt password hash from a SOPS secret into AdGuardHome.yaml
using atomic file replacement to avoid configuration corruption.
"""
from __future__ import annotations

import argparse
import grp
import logging
import os
import pwd
import sys
import tempfile
from pathlib import Path

import bcrypt
import yaml

logging.basicConfig(level=logging.INFO, format="[adguard-sync] %(levelname)-5s: %(message)s")
logger = logging.getLogger("adguard-sync")


def get_adguard_ids() -> tuple[int, int]:
    """Resolve (uid, gid) for the adguardhome user/group if present."""
    uid = -1
    gid = -1
    try:
        uid = pwd.getpwnam("adguardhome").pw_uid
    except KeyError:
        pass
    try:
        gid = grp.getgrnam("adguardhome").gr_gid
    except KeyError:
        pass
    return uid, gid


def sync_admin(config_path: Path, secret_path: Path, username: str) -> int:
    if not secret_path.is_file():
        logger.error("Secret file '%s' does not exist.", secret_path)
        return 1

    password = secret_path.read_text(encoding="utf-8").strip()
    if not password:
        logger.error("Secret password in '%s' is empty.", secret_path)
        return 1

    uid, gid = get_adguard_ids()

    config_dir = config_path.parent
    if not config_dir.exists():
        config_dir.mkdir(parents=True, mode=0o750, exist_ok=True)
        if uid != -1 or gid != -1:
            try:
                os.chown(config_dir, uid, gid)
            except OSError:
                pass

    data: dict = {}
    if config_path.is_file():
        try:
            data = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        except Exception as exc:
            logger.warning("Could not parse existing config '%s': %s", config_path, exc)
            data = {}

    users = data.get("users", [])
    if not isinstance(users, list):
        users = []

    user_found = False
    needs_update = False

    for user in users:
        if isinstance(user, dict) and user.get("name") == username:
            user_found = True
            current_hash = str(user.get("password", ""))
            try:
                if not bcrypt.checkpw(password.encode("utf-8"), current_hash.encode("utf-8")):
                    logger.info("Password for user '%s' changed. Updating bcrypt hash...", username)
                    user["password"] = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")
                    needs_update = True
                else:
                    logger.info("User '%s' credentials are already up to date.", username)
            except Exception as exc:
                logger.warning("Hash verification failed (%s). Regenerating bcrypt hash...", exc)
                user["password"] = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")
                needs_update = True
            break

    if not user_found:
        logger.info("Creating admin user '%s' with bcrypt hash...", username)
        users.append(
            {
                "name": username,
                "password": bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8"),
            }
        )
        data["users"] = users
        needs_update = True

    if needs_update:
        temp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile("w", dir=config_dir, delete=False, encoding="utf-8") as tf:
                temp_path = Path(tf.name)
                yaml.safe_dump(data, tf, default_flow_style=False, sort_keys=False)
                tf.flush()
                os.fsync(tf.fileno())

            temp_path.chmod(0o600)
            if uid != -1 or gid != -1:
                try:
                    os.chown(temp_path, uid, gid)
                except OSError:
                    pass
            temp_path.replace(config_path)
            logger.info("Atomically wrote user configuration to '%s'.", config_path)
        except Exception as exc:
            logger.error("Failed to write '%s': %s", config_path, exc)
            if temp_path and temp_path.exists():
                temp_path.unlink(missing_ok=True)
            return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync AdGuard Home admin user from SOPS secret.")
    parser.add_argument("--config", type=Path, default=Path("/var/lib/AdGuardHome/AdGuardHome.yaml"), help="Path to AdGuardHome.yaml")
    parser.add_argument("--secret", type=Path, required=True, help="Path to secret file containing plaintext password")
    parser.add_argument("--username", default="luka", help="Admin username")
    args = parser.parse_args()
    return sync_admin(args.config, args.secret, args.username)


if __name__ == "__main__":
    sys.exit(main())
