#!/usr/bin/env python3
"""
clean-stalled-downloads.py

Periodically scans Sonarr and Radarr queues for dead or stalled torrent downloads
(e.g., downloads with 0 connections / 0 seeders or stuck downloading metadata for > max_minutes).
When detected, it removes the torrent from qBittorrent, blocklists the release,
allows Sonarr/Radarr to search for a healthy alternative, and optionally triggers
the configured notification handler.
"""
from __future__ import annotations

import argparse
import datetime
import json
import logging
import subprocess
import urllib.request
from pathlib import Path
from typing import Any

logging.basicConfig(
    level=logging.INFO,
    format="[stalled-cleaner] %(asctime)s %(levelname)-5s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("stalled-cleaner")


def parse_iso_datetime(dt_str: str) -> datetime.datetime:
    """Parse ISO8601 timestamp string into timezone-aware datetime."""
    if dt_str.endswith("Z"):
        dt_str = dt_str[:-1] + "+00:00"
    return datetime.datetime.fromisoformat(dt_str)


def arr_request(url: str, api_key: str, method: str = "GET", timeout: int = 15) -> Any:
    """Perform an authenticated HTTP request against a Sonarr/Radarr v3 API endpoint."""
    req = urllib.request.Request(
        url,
        headers={"X-Api-Key": api_key, "Accept": "application/json"},
        method=method,
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8").strip()
        return json.loads(raw) if raw else None


def emit_notification(notify_bin: Path | None, message: str, tag: str = "broom") -> None:
    """Invoke the host notification handler if configured."""
    if not notify_bin or not notify_bin.is_file():
        return
    try:
        subprocess.run(
            [str(notify_bin), message, tag],
            check=False,
            timeout=10,
            capture_output=True,
        )
    except Exception as exc:
        logger.warning("Failed to dispatch notification: %s", exc)


def clean_service_queue(
    service_name: str,
    base_url: str,
    api_key: str,
    max_stalled_minutes: int,
    notify_bin: Path | None = None,
) -> None:
    """Inspect queue records and evict/blocklist dead stalled releases."""
    queue_url = f"{base_url.rstrip('/')}/api/v3/queue"
    try:
        data = arr_request(queue_url, api_key) or {}
    except Exception as exc:
        logger.warning("Failed to query %s queue: %s", service_name, exc)
        return

    records: list[dict[str, Any]] = data.get("records", [])
    now = datetime.datetime.now(datetime.timezone.utc)

    for record in records:
        record_id = record.get("id")
        title = record.get("title", "Unknown")
        error_msg = (record.get("errorMessage") or "").lower()
        added_str = record.get("added")
        size = record.get("size", 0)
        sizeleft = record.get("sizeleft", 0)

        is_stalled = (
            "stalled with no connections" in error_msg
            or "downloading metadata" in error_msg
            or "no connections" in error_msg
        )
        if not is_stalled:
            continue

        # Only treat as dead if zero bytes were downloaded
        if size > 0 and sizeleft < size:
            continue

        if not added_str:
            continue

        try:
            added_dt = parse_iso_datetime(added_str)
        except Exception:
            continue

        age_minutes = (now - added_dt).total_seconds() / 60.0
        if age_minutes < max_stalled_minutes:
            logger.debug(
                "[%s] '%s' is stalled but only %d min old (threshold: %d min)",
                service_name,
                title,
                int(age_minutes),
                max_stalled_minutes,
            )
            continue

        logger.warning(
            "[%s] Found dead stalled torrent '%s' (stalled for %d min, 0%% progress: %s). Removing and blocklisting...",
            service_name,
            title,
            int(age_minutes),
            error_msg,
        )

        delete_url = (
            f"{base_url.rstrip('/')}/api/v3/queue/{record_id}"
            "?removeFromClient=true&blocklist=true"
        )
        try:
            arr_request(delete_url, api_key, method="DELETE")
            logger.info(
                "[%s] Successfully removed and blocklisted '%s'",
                service_name,
                title,
            )
            emit_notification(
                notify_bin,
                f"qBittorrent: Stalled Torrent in {service_name} nach {int(age_minutes)} Min. entfernt & blocklistet: {title}",
                "broom",
            )
        except Exception as exc:
            logger.error(
                "[%s] Failed to remove stalled download %s ('%s'): %s",
                service_name,
                record_id,
                title,
                exc,
            )


def process_target(
    service_name: str,
    url: str | None,
    key_file: Path | None,
    max_stalled_minutes: int,
    notify_bin: Path | None,
) -> None:
    """Read API key and run queue cleanup for one Arr service if enabled."""
    if not (url and key_file and key_file.is_file()):
        return
    try:
        key = key_file.read_text(encoding="utf-8").strip()
        clean_service_queue(service_name, url, key, max_stalled_minutes, notify_bin)
    except Exception as exc:
        logger.error("Failed to process %s queue cleanup: %s", service_name, exc)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Clean dead/stalled torrents in Sonarr and Radarr queues."
    )
    parser.add_argument("--sonarr-url", default=None, help="Sonarr base URL")
    parser.add_argument("--sonarr-key-file", type=Path, default=None, help="Path to Sonarr API key file")
    parser.add_argument("--radarr-url", default=None, help="Radarr base URL")
    parser.add_argument("--radarr-key-file", type=Path, default=None, help="Path to Radarr API key file")
    parser.add_argument(
        "--max-stalled-minutes",
        type=int,
        default=20,
        help="Minutes a torrent must be stalled with 0 connections before removal (default: 20)",
    )
    parser.add_argument("--notify-bin", type=Path, default=None, help="Optional host notification executable")

    args = parser.parse_args()
    process_target("Sonarr", args.sonarr_url, args.sonarr_key_file, args.max_stalled_minutes, args.notify_bin)
    process_target("Radarr", args.radarr_url, args.radarr_key_file, args.max_stalled_minutes, args.notify_bin)


if __name__ == "__main__":
    main()
