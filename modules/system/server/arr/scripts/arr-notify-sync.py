#!/usr/bin/env python3
"""
arr-notify-sync.py: Idempotent API synchronizer for Arr stack notifications.
Configures Sonarr and Radarr to automatically invoke arr-notify on Grab and Download events.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional

logging.basicConfig(level=logging.INFO, format="[arr-notify-sync] %(levelname)s: %(message)s")
logger = logging.getLogger("arr-notify-sync")


def parse_args():
    parser = argparse.ArgumentParser(description="Synchronize ntfy notification into Arr services.")
    parser.add_argument("--app", required=True, choices=["sonarr", "radarr"], help="Target Arr application")
    parser.add_argument("--url", required=True, help="Base API URL (e.g. http://127.0.0.1:8989)")
    parser.add_argument("--api-key-file", type=Path, required=True, help="Path to API key secret file")
    parser.add_argument("--script-path", type=str, required=True, help="Path to arr-notify executable")
    parser.add_argument("--remove", action="store_true", help="Remove notification if present")
    return parser.parse_args()


def api_request(url: str, api_key: str, method: str = "GET", data: Optional[Dict[str, Any]] = None) -> Any:
    headers = {
        "X-Api-Key": api_key.strip(),
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    encoded_data = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=10) as resp:
        content = resp.read().decode("utf-8")
        if content:
            return json.loads(content)
        return None


def wait_for_api(base_url: str, api_key: str, max_retries: int = 15, delay: float = 2.0) -> bool:
    status_url = f"{base_url.rstrip('/')}/api/v3/system/status"
    for i in range(max_retries):
        try:
            api_request(status_url, api_key)
            logger.info("API is ready at %s", base_url)
            return True
        except Exception:
            time.sleep(delay)
    logger.warning("API at %s was not ready within timeout. Skipping sync for now.", base_url)
    return False


def sync_notification(app: str, base_url: str, api_key: str, script_path: str, remove: bool = False):
    base_url = base_url.rstrip("/")
    if not wait_for_api(base_url, api_key):
        return

    notifications_url = f"{base_url}/api/v3/notification"
    try:
        notifications: List[Dict[str, Any]] = api_request(notifications_url, api_key, method="GET") or []
    except Exception as exc:
        logger.error("Failed to fetch existing notifications: %s", exc)
        return

    target_name = "ntfy-arr"
    existing = next((n for n in notifications if n.get("name") == target_name), None)

    if remove:
        if existing and "id" in existing:
            delete_url = f"{notifications_url}/{existing['id']}"
            api_request(delete_url, api_key, method="DELETE")
            logger.info("Removed '%s' notification from %s", target_name, app)
        return

    # Check if already up-to-date
    if existing:
        current_path = ""
        for f in existing.get("fields", []):
            if f.get("name") == "path":
                current_path = f.get("value", "")
        if current_path == script_path and existing.get("onGrab") and existing.get("onDownload"):
            logger.info("Notification '%s' in %s is already up to date.", target_name, app)
            return

    # Get CustomScript schema template
    schema_url = f"{base_url}/api/v3/notification/schema"
    try:
        schemas: List[Dict[str, Any]] = api_request(schema_url, api_key, method="GET") or []
    except Exception as exc:
        logger.error("Failed to fetch notification schema: %s", exc)
        return

    custom_script_schema = next(
        (s for s in schemas if s.get("implementation") == "CustomScript"), None
    )
    if not custom_script_schema:
        logger.error("CustomScript schema not found in %s API", app)
        return

    payload = dict(custom_script_schema)
    payload["name"] = target_name
    payload["onGrab"] = True
    payload["onDownload"] = True
    payload["onUpgrade"] = True
    payload["onRename"] = False
    payload["onHealthIssue"] = True
    payload["includeHealthWarnings"] = False

    # Update path field
    fields = []
    for f in payload.get("fields", []):
        f_copy = dict(f)
        if f_copy.get("name") == "path":
            f_copy["value"] = script_path
        elif f_copy.get("name") == "arguments":
            f_copy["value"] = ""
        fields.append(f_copy)
    payload["fields"] = fields

    if existing and "id" in existing:
        payload["id"] = existing["id"]
        update_url = f"{notifications_url}/{existing['id']}"
        api_request(update_url, api_key, method="PUT", data=payload)
        logger.info("Updated '%s' notification in %s with script path '%s'", target_name, app, script_path)
    else:
        api_request(notifications_url, api_key, method="POST", data=payload)
        logger.info("Created '%s' notification in %s with script path '%s'", target_name, app, script_path)


def main():
    args = parse_args()
    if not args.api_key_file.exists():
        logger.warning("API key file '%s' does not exist yet. Skipping.", args.api_key_file)
        sys.exit(0)

    try:
        api_key = args.api_key_file.read_text(encoding="utf-8").strip()
    except Exception as exc:
        logger.error("Could not read API key file: %s", exc)
        sys.exit(0)

    try:
        sync_notification(
            app=args.app,
            base_url=args.url,
            api_key=api_key,
            script_path=args.script_path,
            remove=args.remove,
        )
    except Exception as exc:
        logger.warning("Notification sync encountered non-fatal error: %s", exc)
        sys.exit(0)


if __name__ == "__main__":
    main()
