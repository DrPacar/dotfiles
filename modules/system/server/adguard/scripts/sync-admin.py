#!/usr/bin/env python3
"""
AdGuard Home Admin User Sync Script
Synchronizes the admin user and bcrypt password hash from a SOPS secret into AdGuardHome.yaml.
"""

import argparse
import grp
import os
import pwd
import sys
import bcrypt
import yaml


def sync_admin(config_path: str, secret_path: str, username: str) -> int:
    if not os.path.exists(secret_path):
        print(f"Error: Secret file '{secret_path}' does not exist.", file=sys.stderr)
        return 1

    with open(secret_path, "r", encoding="utf-8") as f:
        password = f.read().strip()

    if not password:
        print("Error: Secret password is empty.", file=sys.stderr)
        return 1

    config_dir = os.path.dirname(config_path)
    if not os.path.exists(config_dir):
        os.makedirs(config_dir, mode=0o750, exist_ok=True)
        try:
            uid = pwd.getpwnam("adguardhome").pw_uid
            gid = grp.getgrnam("adguardhome").gr_gid
            os.chown(config_dir, uid, gid)
        except Exception:
            pass

    data = {}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
        except Exception as e:
            print(f"Warning: Could not read existing config '{config_path}': {e}", file=sys.stderr)
            data = {}

    users = data.get("users", [])
    user_found = False
    needs_update = False

    for user in users:
        if user.get("name") == username:
            user_found = True
            current_hash = user.get("password", "")
            try:
                # Check if the secret password matches the current bcrypt hash
                if not bcrypt.checkpw(password.encode("utf-8"), current_hash.encode("utf-8")):
                    print(f"AdGuard Home: Password for user '{username}' changed. Updating bcrypt hash...")
                    new_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")
                    user["password"] = new_hash
                    needs_update = True
                else:
                    print(f"AdGuard Home: User '{username}' credentials are up to date.")
            except Exception as e:
                print(f"AdGuard Home: Hash verification failed ({e}). Re-generating bcrypt hash...")
                new_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")
                user["password"] = new_hash
                needs_update = True
            break

    if not user_found:
        print(f"AdGuard Home: Creating admin user '{username}' with bcrypt hash...")
        new_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")
        users.append({
            "name": username,
            "password": new_hash
        })
        data["users"] = users
        needs_update = True

    if needs_update:
        with open(config_path, "w", encoding="utf-8") as f:
            yaml.dump(data, f, default_flow_style=False)
        os.chmod(config_path, 0o600)
        try:
            uid = pwd.getpwnam("adguardhome").pw_uid
            gid = grp.getgrnam("adguardhome").gr_gid
            os.chown(config_path, uid, gid)
        except Exception:
            pass
        print("AdGuard Home: User configuration successfully written.")

    return 0


def main():
    parser = argparse.ArgumentParser(description="Sync AdGuard Home admin user from SOPS secret.")
    parser.add_argument("--config", default="/var/lib/AdGuardHome/AdGuardHome.yaml", help="Path to AdGuardHome.yaml")
    parser.add_argument("--secret", required=True, help="Path to secret file containing plaintext password")
    parser.add_argument("--username", default="luka", help="Admin username")
    args = parser.parse_args()

    sys.exit(sync_admin(args.config, args.secret, args.username))


if __name__ == "__main__":
    main()
