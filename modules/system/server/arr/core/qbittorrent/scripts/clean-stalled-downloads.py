#!/usr/bin/env python3
"""
clean-stalled-downloads.py

Periodically scans Sonarr and Radarr queues for dead or stalled torrent downloads
(e.g., downloads with 0 connections / 0 seeders or stuck downloading metadata for > max_minutes).
When detected, it removes the torrent from qBittorrent, blocklists the release,
and allows Sonarr/Radarr to automatically search for a healthy alternative release.
"""
from __future__ import annotations

import argparse
import datetime
import json
import logging
import urllib.error
import urllib.parse
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


def clean_service_queue(
    service_name: str,
    base_url: str,
    api_key: str,
    max_stalled_minutes: int,
) -> None:
    headers = {
        "X-Api-Key": api_key,
        "Accept": "application/json",
    }

    url = f"{base_url.rstrip('/')}/api/v3/queue"
    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
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

        # Stalled torrent criteria:
        # 1. Error message indicates stalled with no connections or downloading metadata
        is_stalled = (
            "stalled with no connections" in error_msg
            or "downloading metadata" in error_msg
            or "no connections" in error_msg
        )

        if not is_stalled:
            continue

        # 2. Check progress: only treat as dead if 0 bytes downloaded
        if size > 0 and sizeleft < size:
            # Has made actual progress, not dead
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
        del_req = urllib.request.Request(
            delete_url,
            headers=headers,
            method="DELETE",
        )
        try:
            with urllib.request.urlopen(del_req, timeout=15):
                logger.info(
                    "[%s] Successfully removed and blocklisted '%s'",
                    service_name,
                    title,
                )
        except Exception as exc:
            logger.error(
                "[%s] Failed to remove stalled download %s ('%s'): %s",
                service_name,
                record_id,
                title,
                exc,
            )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Clean dead/stalled torrents in Sonarr and Radarr queues."
    )
    parser.add_argument("--sonarr-url", default=None, help="Sonarr base URL")
    parser.add_argument(
        "--sonarr-key-file",
        type=Path,
        default=None,
        help="Path to Sonarr API key file",
    )
    parser.add_argument("--radarr-url", default=None, help="Radarr base URL")
    parser.add_argument(
        "--radarr-key-file",
        type=Path,
        default=None,
        help="Path to Radarr API key file",
    )
    parser.add_argument(
        "--max-stalled-minutes",
        type=int,
        default=20,
        help="Minutes a torrent must be stalled with 0 connections before removal (default: 20)",
    )

    args = parser.parse_args()

    if args.sonarr_url and args.sonarr_key_file and args.sonarr_key_file.is_file():
        try:
            key = args.sonarr_key_file.read_text().strip()
            clean_service_queue(
                "Sonarr", args.sonarr_url, key, args.max_stalled_minutes
            )
        except Exception as exc:
            logger.error("Failed to read Sonarr key: %s", exc)

    if args.radarr_url and args.radarr_key_file and args.radarr_key_file.is_file():
        try:
            key = args.radarr_key_file.read_text().strip()
            clean_service_queue(
                "Radarr", args.radarr_url, key, args.max_stalled_minutes
            )
        except Exception as exc:
            logger.error("Failed to read Radarr key: %s", exc)


if __name__ == "__main__":
    main()
