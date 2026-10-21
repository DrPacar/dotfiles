#!/usr/bin/env bash
set -euo pipefail

DEST_DIR=""
RETENTION_DAYS=14
SERVICES=""
MEDIA_GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dest-dir)
    DEST_DIR="$2"
    shift 2
    ;;
  --media-group)
    MEDIA_GROUP="$2"
    shift 2
    ;;
  --retention-days)
    RETENTION_DAYS="$2"
    shift 2
    ;;
  --services)
    SERVICES="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z $DEST_DIR ]]; then
  echo "Error: --dest-dir is required." >&2
  exit 1
fi

if [[ -z $SERVICES ]]; then
  echo "No enabled services selected for backup. Exiting."
  exit 0
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
TEMP_DIR=$(mktemp -d -t "arr-backup-$TIMESTAMP-XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Starting Arr stack backup at $TIMESTAMP..."
mkdir -p "$TEMP_DIR/arr-backup"

# Helper function to backup a SQLite database safely using sqlite3 online backup API
backup_sqlite() {
  local src_db="$1"
  local dest_db="$2"

  if [[ -f $src_db ]]; then
    mkdir -p "$(dirname "$dest_db")"
    # Use sqlite3 .backup to ensure a consistent, safe point-in-time snapshot with checkpointed WAL
    sqlite3 "$src_db" ".backup '$dest_db'"
  fi
}

for svc in $SERVICES; do
  echo "Backing up service: $svc..."
  SVC_OUT="$TEMP_DIR/arr-backup/$svc"
  mkdir -p "$SVC_OUT"

  case "$svc" in
  sonarr)
    if [[ -d /var/lib/sonarr ]]; then
      [[ -f /var/lib/sonarr/config.xml ]] && cp -a /var/lib/sonarr/config.xml "$SVC_OUT/"
      backup_sqlite /var/lib/sonarr/sonarr.db "$SVC_OUT/sonarr.db"
    fi
    ;;
  sonarr-anime)
    if [[ -d /var/lib/sonarr-anime ]]; then
      [[ -f /var/lib/sonarr-anime/config.xml ]] && cp -a /var/lib/sonarr-anime/config.xml "$SVC_OUT/"
      backup_sqlite /var/lib/sonarr-anime/sonarr.db "$SVC_OUT/sonarr.db"
    fi
    ;;
  radarr)
    if [[ -d /var/lib/radarr ]]; then
      [[ -f /var/lib/radarr/config.xml ]] && cp -a /var/lib/radarr/config.xml "$SVC_OUT/"
      backup_sqlite /var/lib/radarr/radarr.db "$SVC_OUT/radarr.db"
    fi
    ;;
  prowlarr)
    if [[ -d /var/lib/prowlarr ]]; then
      [[ -f /var/lib/prowlarr/config.xml ]] && cp -a /var/lib/prowlarr/config.xml "$SVC_OUT/"
      backup_sqlite /var/lib/prowlarr/prowlarr.db "$SVC_OUT/prowlarr.db"
      [[ -d /var/lib/prowlarr/Definitions ]] && cp -a /var/lib/prowlarr/Definitions "$SVC_OUT/"
    fi
    ;;
  bazarr)
    if [[ -d /var/lib/bazarr ]]; then
      [[ -d /var/lib/bazarr/config ]] && cp -a /var/lib/bazarr/config "$SVC_OUT/"
      backup_sqlite /var/lib/bazarr/db/bazarr.db "$SVC_OUT/bazarr.db"
    fi
    ;;
  seerr)
    if [[ -d /var/lib/seerr ]]; then
      [[ -f /var/lib/seerr/settings.json ]] && cp -a /var/lib/seerr/settings.json "$SVC_OUT/"
      backup_sqlite /var/lib/seerr/db/db.sqlite3 "$SVC_OUT/db.sqlite3"
    fi
    ;;
  jellyfin)
    if [[ -d /var/lib/jellyfin ]]; then
      [[ -d /var/lib/jellyfin/config ]] && cp -a /var/lib/jellyfin/config "$SVC_OUT/"
      backup_sqlite /var/lib/jellyfin/data/jellyfin.db "$SVC_OUT/data/jellyfin.db"
      backup_sqlite /var/lib/jellyfin/data/users.db "$SVC_OUT/data/users.db"
      backup_sqlite /var/lib/jellyfin/data/displaypreferences.db "$SVC_OUT/data/displaypreferences.db"
    fi
    ;;
  qbittorrent)
    if [[ -d /var/lib/qBittorrent/qBittorrent ]]; then
      [[ -d /var/lib/qBittorrent/qBittorrent/config ]] && cp -a /var/lib/qBittorrent/qBittorrent/config "$SVC_OUT/"
      [[ -d /var/lib/qBittorrent/qBittorrent/data/BT_backup ]] && cp -a /var/lib/qBittorrent/qBittorrent/data/BT_backup "$SVC_OUT/"
    fi
    ;;
  esac
done

mkdir -p "$DEST_DIR"
ARCHIVE_NAME="arr-backup-$TIMESTAMP.tar.zst"
ARCHIVE_PATH="$DEST_DIR/$ARCHIVE_NAME"

echo "Compressing backup archive to $ARCHIVE_PATH with zstd..."
tar -C "$TEMP_DIR" -cf - "arr-backup" | zstd -T0 -3 >"$ARCHIVE_PATH"

if [[ -n $MEDIA_GROUP ]]; then
  chgrp "$MEDIA_GROUP" "$ARCHIVE_PATH" 2>/dev/null || true
fi
chmod 0640 "$ARCHIVE_PATH" || true

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo "Backup completed successfully! Archive size: $ARCHIVE_SIZE"

# Retention management: prune archives older than RETENTION_DAYS, keeping at least 3 newest archives
echo "Pruning backups older than $RETENTION_DAYS days in $DEST_DIR..."
mapfile -t ALL_BACKUPS < <(find "$DEST_DIR" -maxdepth 1 -name "arr-backup-*.tar.zst" -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)
TOTAL_COUNT="${#ALL_BACKUPS[@]}"
MIN_KEEP=3

if ((TOTAL_COUNT > MIN_KEEP)); then
  EXCESS=$((TOTAL_COUNT - MIN_KEEP))
  for ((i = 0; i < EXCESS; i++)); do
    file="${ALL_BACKUPS[$i]}"
    if [[ -n $(find "$file" -mtime "+$RETENTION_DAYS" -print) ]]; then
      echo "Pruning expired backup: $(basename "$file")"
      rm -f "$file"
    fi
  done
fi

echo "Backup and retention maintenance finished."
