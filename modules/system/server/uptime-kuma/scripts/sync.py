#!/usr/bin/env python3
"""
Declarative Uptime Kuma Synchronization Script
Syncs monitors, notification channels, and status page configuration from a declarative JSON specification into Uptime Kuma's SQLite database.
"""

import argparse
import json
import os
import subprocess
import sqlite3
import sys
import time


def wait_for_db(db_path: str, timeout: int = 60) -> bool:
    start_time = time.time()
    while time.time() - start_time < timeout:
        if os.path.exists(db_path):
            try:
                conn = sqlite3.connect(db_path, timeout=5.0)
                cur = conn.cursor()
                cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='monitor'")
                if cur.fetchone():
                    conn.close()
                    return True
                conn.close()
            except Exception:
                pass
        time.sleep(1)
    return False


def sync_kuma(db_path: str, config_path: str, restart_service: str = None) -> int:
    if not wait_for_db(db_path, timeout=60):
        print(f"Error: Database {db_path} did not become available in time.", file=sys.stderr)
        return 1

    with open(config_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    conn = sqlite3.connect(db_path, timeout=30.0)
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA busy_timeout = 30000;")
    cur = conn.cursor()

    changes_made = 0

    # 1. Determine user_id
    cur.execute("SELECT id FROM user ORDER BY id ASC LIMIT 1")
    user_row = cur.fetchone()
    user_id = user_row[0] if user_row else 1

    # 2. Sync Monitors
    desired_monitors = cfg.get("monitors", [])
    cleanup_untracked = cfg.get("cleanupUntracked", True)

    cur.execute("""
        SELECT id, name, type, url, hostname, port, interval, retry_interval,
               maxretries, dns_resolve_server, dns_resolve_type,
               accepted_statuscodes_json, active
        FROM monitor
    """)
    existing_monitors = {}
    for row in cur.fetchall():
        existing_monitors[row[1]] = {
            "id": row[0],
            "type": row[2],
            "url": row[3],
            "hostname": row[4],
            "port": row[5],
            "interval": row[6],
            "retry_interval": row[7],
            "maxretries": row[8],
            "dns_resolve_server": row[9],
            "dns_resolve_type": row[10],
            "accepted_statuscodes_json": row[11],
            "active": row[12],
        }

    desired_names = set()
    for m in desired_monitors:
        name = m["name"]
        desired_names.add(name)
        m_type = m.get("type", "http")
        m_url = m.get("url")
        m_hostname = m.get("hostname")
        m_port = m.get("port")
        m_interval = m.get("interval", 60)
        m_retry_interval = m.get("retry_interval", m_interval)
        m_maxretries = m.get("maxretries", 2)
        m_dns_server = m.get("dns_resolve_server")
        m_dns_type = m.get("dns_resolve_type")
        
        statuscodes = m.get("accepted_statuscodes")
        if isinstance(statuscodes, list):
            m_statuscodes = json.dumps(statuscodes)
        else:
            m_statuscodes = m.get("accepted_statuscodes_json", '["200-299"]')

        if name in existing_monitors:
            ex = existing_monitors[name]
            needs_update = (
                ex["type"] != m_type
                or ex["url"] != m_url
                or ex["hostname"] != m_hostname
                or ex["port"] != m_port
                or ex["interval"] != m_interval
                or ex["retry_interval"] != m_retry_interval
                or ex["maxretries"] != m_maxretries
                or ex["dns_resolve_server"] != m_dns_server
                or ex["dns_resolve_type"] != m_dns_type
                or ex["accepted_statuscodes_json"] != m_statuscodes
                or ex["active"] != 1
            )
            if needs_update:
                print(f"Updating monitor '{name}'")
                cur.execute("""
                    UPDATE monitor
                    SET type = ?, url = ?, hostname = ?, port = ?, interval = ?,
                        retry_interval = ?, maxretries = ?, dns_resolve_server = ?,
                        dns_resolve_type = ?, accepted_statuscodes_json = ?, active = 1
                    WHERE id = ?
                """, (m_type, m_url, m_hostname, m_port, m_interval, m_retry_interval,
                      m_maxretries, m_dns_server, m_dns_type, m_statuscodes, ex["id"]))
                changes_made += 1
        else:
            print(f"Creating new monitor '{name}' ({m_type})")
            cur.execute("""
                INSERT INTO monitor (
                    name, type, url, hostname, port, interval, retry_interval,
                    maxretries, dns_resolve_server, dns_resolve_type,
                    accepted_statuscodes_json, active, user_id, weight
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 2000)
            """, (name, m_type, m_url, m_hostname, m_port, m_interval,
                  m_retry_interval, m_maxretries, m_dns_server, m_dns_type,
                  m_statuscodes, user_id))
            changes_made += 1

    # Delete untracked monitors if requested
    if cleanup_untracked:
        for ex_name, ex_data in existing_monitors.items():
            if ex_name not in desired_names:
                print(f"Removing untracked monitor '{ex_name}' (id {ex_data['id']})")
                cur.execute("DELETE FROM monitor WHERE id = ?", (ex_data["id"],))
                changes_made += 1

    # 3. Sync Notification
    notif_cfg = cfg.get("notification")
    notif_id = None
    if notif_cfg and notif_cfg.get("enable", False):
        notif_name = notif_cfg.get("name", "Haven Alerts")
        inner_config = notif_cfg.get("config", {})
        notif_json = json.dumps(inner_config)

        # Cleanup duplicate or obsolete notifications
        cur.execute("SELECT id, name FROM notification WHERE name != ? AND (name LIKE '%alerts%' OR name LIKE '%ntfy%')", (notif_name,))
        for stale_id, stale_name in cur.fetchall():
            print(f"Removing stale notification '{stale_name}' (id {stale_id})")
            cur.execute("DELETE FROM notification WHERE id = ?", (stale_id,))
            changes_made += 1

        cur.execute("SELECT id, name, config, active, is_default FROM notification WHERE name = ?", (notif_name,))
        notif_row = cur.fetchone()
        if notif_row:
            notif_id = notif_row[0]
            curr_config = {}
            try:
                curr_config = json.loads(notif_row[2]) if notif_row[2] else {}
            except Exception:
                pass
            if curr_config != inner_config or notif_row[3] != 1 or notif_row[4] != 1:
                print(f"Updating notification '{notif_name}'")
                cur.execute("UPDATE notification SET config = ?, active = 1, is_default = 1 WHERE id = ?", (notif_json, notif_id))
                changes_made += 1
        else:
            print(f"Creating notification '{notif_name}'")
            cur.execute("""
                INSERT INTO notification (name, active, user_id, is_default, config)
                VALUES (?, 1, ?, 1, ?)
            """, (notif_name, user_id, notif_json))
            notif_id = cur.lastrowid
            changes_made += 1

        # Link all active monitors to this notification channel
        if notif_id and notif_cfg.get("applyToAll", True):
            cur.execute("SELECT id FROM monitor WHERE active = 1")
            active_ids = [r[0] for r in cur.fetchall()]
            for mid in active_ids:
                cur.execute("SELECT id FROM monitor_notification WHERE monitor_id = ? AND notification_id = ?", (mid, notif_id))
                if not cur.fetchone():
                    cur.execute("INSERT INTO monitor_notification (monitor_id, notification_id) VALUES (?, ?)", (mid, notif_id))
                    changes_made += 1

    # 4. Sync Status Page & Categories
    sp_cfg = cfg.get("statusPage")
    if sp_cfg and sp_cfg.get("enable", False):
        slug = sp_cfg.get("slug", "default")
        title = sp_cfg.get("title", "Haven Status")
        desc = sp_cfg.get("description", "")
        groups_list = sp_cfg.get("groups", [])

        cur.execute("SELECT id, title, description, published FROM status_page WHERE slug = ?", (slug,))
        sp_row = cur.fetchone()
        if sp_row:
            sp_id = sp_row[0]
            if sp_row[1] != title or sp_row[2] != desc or sp_row[3] != 1:
                print(f"Updating status page '{slug}'")
                cur.execute("UPDATE status_page SET title = ?, description = ?, published = 1 WHERE id = ?", (title, desc, sp_id))
                changes_made += 1
        else:
            print(f"Creating status page '{slug}'")
            cur.execute("""
                INSERT INTO status_page (slug, title, description, icon, theme, published)
                VALUES (?, ?, ?, '/icon.svg', 'auto', 1)
            """, (slug, title, desc))
            sp_id = cur.lastrowid
            changes_made += 1

        # Sync groups
        groups_map = {}
        for idx, gname in enumerate(groups_list, start=1):
            weight = idx * 1000
            cur.execute("SELECT id, weight FROM [group] WHERE status_page_id = ? AND name = ?", (sp_id, gname))
            grow = cur.fetchone()
            if grow:
                gid = grow[0]
                if grow[1] != weight:
                    cur.execute("UPDATE [group] SET weight = ? WHERE id = ?", (weight, gid))
                    changes_made += 1
            else:
                print(f"Creating group '{gname}' on status page")
                cur.execute("""
                    INSERT INTO [group] (name, public, active, weight, status_page_id)
                    VALUES (?, 1, 1, ?, ?)
                """, (gname, weight, sp_id))
                gid = cur.lastrowid
                changes_made += 1
            groups_map[gname] = gid

        # Map monitors to their group
        cur.execute("SELECT id, name FROM monitor WHERE active = 1")
        active_monitors = {r[1]: r[0] for r in cur.fetchall()}
        for m in desired_monitors:
            mname = m["name"]
            mgrp = m.get("group")
            if mname in active_monitors and mgrp in groups_map:
                mid = active_monitors[mname]
                desired_gid = groups_map[mgrp]
                cur.execute("SELECT id, group_id FROM monitor_group WHERE monitor_id = ?", (mid,))
                mg_row = cur.fetchone()
                if mg_row:
                    if mg_row[1] != desired_gid:
                        cur.execute("UPDATE monitor_group SET group_id = ? WHERE id = ?", (desired_gid, mg_row[0]))
                        changes_made += 1
                else:
                    cur.execute("INSERT INTO monitor_group (monitor_id, group_id, weight) VALUES (?, ?, 1000)", (mid, desired_gid))
                    changes_made += 1

        # Entry page setting
        if sp_cfg.get("isEntryPage", True):
            entry_val = json.dumps(f"statusPage-{slug}")
            cur.execute("SELECT value FROM setting WHERE key = 'entryPage'")
            entry_row = cur.fetchone()
            if not entry_row or entry_row[0] != entry_val:
                print(f"Setting entry page to 'statusPage-{slug}'")
                cur.execute("INSERT OR REPLACE INTO setting (key, value, type) VALUES ('entryPage', ?, 'general')", (entry_val,))
                changes_made += 1

    conn.commit()
    conn.close()

    if changes_made > 0:
        print(f"Uptime Kuma sync: {changes_made} changes successfully applied.")
        if restart_service:
            print(f"Restarting {restart_service} to load updated monitor state...")
            subprocess.run(["systemctl", "try-restart", restart_service], check=False)
    else:
        print("Uptime Kuma sync: Database is fully up to date. No changes required.")

    return 0


def main():
    parser = argparse.ArgumentParser(description="Synchronize Uptime Kuma declarative configuration.")
    parser.add_argument("--db", default="/var/lib/uptime-kuma/kuma.db", help="Path to kuma.db")
    parser.add_argument("--config", required=True, help="Path to sync config JSON")
    parser.add_argument("--restart-service", default="uptime-kuma.service", help="Service to try-restart on changes")
    parser.add_argument("--no-restart", action="store_true", help="Do not trigger service restart")
    args = parser.parse_args()

    restart_svc = None if args.no_restart else args.restart_service
    sys.exit(sync_kuma(args.db, args.config, restart_svc))


if __name__ == "__main__":
    main()
