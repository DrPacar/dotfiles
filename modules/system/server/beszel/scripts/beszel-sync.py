#!/usr/bin/env python3
"""
beszel-sync.py: Idempotent PocketBase DB synchronizer for Beszel Hub.
Configures appURL, trustedProxy headers (for Caddy), ntfy Shoutrrr webhook,
and baseline system alerts without overriding unrelated user data.
"""

from __future__ import annotations

import argparse
import json
import secrets
import sqlite3
import string
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ALPHABET = string.ascii_lowercase + string.digits


def gen_pb_id() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(15))


def wait_for_db(db_path: Path, timeout: int = 30) -> bool:
    for _ in range(timeout):
        if db_path.is_file():
            try:
                con = sqlite3.connect(str(db_path), timeout=5)
                tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
                con.close()
                if {"_params", "users", "user_settings", "alerts", "systems"}.issubset(tables):
                    return True
            except sqlite3.Error:
                pass
        time.sleep(1)
    return False


def sync_params(con: sqlite3.Connection, app_url: str, proxy_headers: list[str]) -> bool:
    row = con.execute("SELECT value FROM _params WHERE id = 'settings'").fetchone()
    if not row:
        return False

    raw_val = row[0].decode("utf-8") if isinstance(row[0], bytes) else row[0]
    data: dict[str, Any] = json.loads(raw_val)
    changed = False

    meta = data.setdefault("meta", {})
    if meta.get("appURL") != app_url:
        meta["appURL"] = app_url
        changed = True

    tp = data.setdefault("trustedProxy", {})
    if tp.get("headers") != proxy_headers:
        tp["headers"] = proxy_headers
        changed = True

    if changed:
        payload = json.dumps(data, separators=(",", ":"))
        con.execute("UPDATE _params SET value = ?, updated = strftime('%Y-%m-%d %H:%M:%fZ', 'now') WHERE id = 'settings'", (payload,))
        print(f"[beszel-sync] Updated _params (appURL={app_url}, trustedProxy={proxy_headers})")
    return changed


def sync_user_webhooks(con: sqlite3.Connection, ntfy_url: str) -> bool:
    users = [r[0] for r in con.execute("SELECT id FROM users").fetchall()]
    if not users:
        print("[beszel-sync] No Beszel users present yet; skipping webhook sync until initial user setup.")
        return False

    changed = False
    for uid in users:
        row = con.execute("SELECT id, settings FROM user_settings WHERE user = ?", (uid,)).fetchone()
        if row:
            sid, raw_settings = row
            settings = json.loads(raw_settings) if raw_settings else {}
            webhooks = list(settings.get("webhooks") or [])
            # Drop stale local ntfy webhooks if topic/port changed, while keeping user custom webhooks intact
            cleaned = [w for w in webhooks if not (w.startswith("ntfy://127.0.0.1:") and w != ntfy_url)]
            if ntfy_url not in cleaned:
                cleaned.append(ntfy_url)
            if cleaned != webhooks:
                settings["webhooks"] = cleaned
                con.execute(
                    "UPDATE user_settings SET settings = ?, updated = strftime('%Y-%m-%d %H:%M:%fZ', 'now') WHERE id = ?",
                    (json.dumps(settings, separators=(",", ":")), sid),
                )
                print(f"[beszel-sync] Synced ntfy webhook for user {uid}")
                changed = True
        else:
            settings = {"chartTime": "1h", "webhooks": [ntfy_url]}
            con.execute(
                "INSERT INTO user_settings (id, user, settings, created, updated) VALUES (?, ?, ?, strftime('%Y-%m-%d %H:%M:%fZ', 'now'), strftime('%Y-%m-%d %H:%M:%fZ', 'now'))",
                (gen_pb_id(), uid, json.dumps(settings, separators=(",", ":"))),
            )
            print(f"[beszel-sync] Created user_settings with ntfy webhook for user {uid}")
            changed = True
    return changed


def sync_alerts(con: sqlite3.Connection, host_name: str, rules: dict[str, dict[str, Any]]) -> bool:
    users = [r[0] for r in con.execute("SELECT id FROM users").fetchall()]
    if not users:
        return False
    admin_uid = users[0]

    sys_row = con.execute(
        "SELECT id FROM systems WHERE name = ? OR host = '127.0.0.1' ORDER BY CASE WHEN name = ? THEN 0 ELSE 1 END LIMIT 1",
        (host_name, host_name),
    ).fetchone()
    if not sys_row:
        print(f"[beszel-sync] Local system '{host_name}' not yet registered in Beszel systems table; skipping alerts.")
        return False
    sys_id = sys_row[0]

    changed = False
    for name, rule in rules.items():
        val = rule.get("value", 0)
        mins = rule.get("min", 5)
        existing = con.execute(
            "SELECT id, value, min FROM alerts WHERE system = ? AND name = ? LIMIT 1",
            (sys_id, name),
        ).fetchone()
        if existing:
            aid, cur_val, cur_min = existing
            if float(cur_val or 0) != float(val) or int(cur_min or 0) != int(mins):
                con.execute(
                    "UPDATE alerts SET value = ?, min = ?, updated = strftime('%Y-%m-%d %H:%M:%fZ', 'now') WHERE id = ?",
                    (val, mins, aid),
                )
                print(f"[beszel-sync] Updated alert {name}: value={val}, min={mins}")
                changed = True
        else:
            con.execute(
                """
                INSERT INTO alerts (id, user, system, name, value, min, triggered, state, pending_since, created, updated)
                VALUES (?, ?, ?, ?, ?, ?, 0, NULL, '', strftime('%Y-%m-%d %H:%M:%fZ', 'now'), strftime('%Y-%m-%d %H:%M:%fZ', 'now'))
                """,
                (gen_pb_id(), admin_uid, sys_id, name, val, mins),
            )
            print(f"[beszel-sync] Created alert {name} (value={val}, min={mins}) for system {sys_id}")
            changed = True
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--systemctl", default="systemctl")
    args = parser.parse_args()

    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    db_path = Path(cfg["dbPath"])

    if not wait_for_db(db_path):
        print(f"[beszel-sync] WARN: Database {db_path} not ready after timeout; skipping.", file=sys.stderr)
        return 0

    con = sqlite3.connect(str(db_path), timeout=15)
    try:
        params_changed = sync_params(con, cfg["appUrl"], cfg["trustedProxyHeaders"])
        if cfg.get("ntfyEnable"):
            sync_user_webhooks(con, cfg["ntfyUrl"])
        if cfg.get("alertsEnable"):
            sync_alerts(con, cfg["hostName"], cfg.get("alertRules", {}))
        con.commit()
    finally:
        con.close()

    if params_changed:
        print("[beszel-sync] Restarting beszel-hub to reload updated _params into memory...")
        subprocess.run([args.systemctl, "restart", "beszel-hub.service"], check=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
