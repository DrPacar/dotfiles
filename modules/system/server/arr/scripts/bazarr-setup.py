#!/usr/bin/env python3
import json
import os
import sqlite3

db_dir = "/var/lib/bazarr/db"
db_path = os.path.join(db_dir, "bazarr.db")
os.makedirs(db_dir, exist_ok=True)

conn = sqlite3.connect(db_path)
conn.execute("""
    CREATE TABLE IF NOT EXISTS table_languages_profiles (
        profileId INTEGER PRIMARY KEY,
        cutoff INTEGER,
        originalFormat INTEGER,
        items TEXT NOT NULL,
        name TEXT NOT NULL,
        mustContain TEXT,
        mustNotContain TEXT,
        tag TEXT
    )
""")

items = json.dumps([
    {"id": 1, "language": "de", "hi": "False", "forced": "False", "audio_exclude": "False", "audio_only_include": "False"},
    {"id": 2, "language": "en", "hi": "False", "forced": "False", "audio_exclude": "False", "audio_only_include": "False"},
    {"id": 3, "language": "de", "hi": "False", "forced": "True", "audio_exclude": "False", "audio_only_include": "False"},
])

conn.execute("""
    INSERT OR REPLACE INTO table_languages_profiles 
    (profileId, name, items, mustContain, mustNotContain, originalFormat) 
    VALUES (1, 'Standard (Deutsch & Englisch)', ?, '[]', '[]', 0)
""", (items,))

try:
    conn.execute("UPDATE table_settings_languages SET enabled = 1 WHERE code2 IN ('de', 'en')")
except sqlite3.OperationalError:
    pass

conn.commit()
conn.close()
