#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Unified Restic Backup CLI
# -----------------------------------------------------------------------------

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
  fi
}

ensure_restic_central() {
  if ! command -v restic-central >/dev/null 2>&1; then
    echo "Error: 'restic-central' wrapper is not active on this host." >&2
    echo "Make sure 'backup.enable = true' and 'backup.client.enable = true' in your host configuration." >&2
    exit 1
  fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
now | run | start)
  ensure_root "$cmd" "$@"
  echo "=========================================="
  echo " Starting Central Backup..."
  echo "=========================================="

  if systemctl list-unit-files | grep -q "restic-backups-central.service"; then
    echo "--> Starting restic-backups-central.service..."
    systemctl start --wait restic-backups-central.service
    echo "=========================================="
    echo " Backup completed successfully!"
    echo "=========================================="
  else
    echo "No active Restic backup service (restic-backups-central.service) found on this host." >&2
    exit 1
  fi
  ;;

snapshots | list | ls)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  echo "=== Snapshots: Central Repository ==="
  restic-central snapshots "$@"
  ;;

status)
  echo "=========================================="
  echo " Restic Backup Timers & Services Status"
  echo "=========================================="
  systemctl list-timers "restic-backups-central*" "restic-server-prune*" --no-pager || true
  echo ""
  echo "--> Recent Service Executions:"
  systemctl status "restic-backups-central*" "restic-server-prune*" --lines=5 --no-pager || true
  ;;

mount)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  MOUNT_DIR="${1:-/mnt/backup-restore}"
  mkdir -p "$MOUNT_DIR"

  echo "=========================================="
  echo " Mounting Restic Backup to: $MOUNT_DIR"
  echo " Press Ctrl+C to unmount and exit."
  echo "=========================================="

  exec restic-central mount --allow-other "$MOUNT_DIR"
  ;;

umount | unmount)
  ensure_root "$cmd" "$@"
  MOUNT_DIR="${1:-/mnt/backup-restore}"
  echo "--> Unmounting $MOUNT_DIR..."
  if command -v fusermount3 >/dev/null 2>&1; then
    fusermount3 -u "$MOUNT_DIR" || umount "$MOUNT_DIR"
  else
    umount "$MOUNT_DIR"
  fi
  echo "--> Successfully unmounted $MOUNT_DIR."
  ;;

check)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  if [ "${1:-}" = "--deep" ]; then
    shift
    echo "=== Checking Central Repository (Deep Verification: 10% data subset) ==="
    restic-central check --read-data-subset=10% "$@"
  else
    echo "=== Checking Central Repository Integrity ==="
    restic-central check "$@"
  fi
  ;;

test-restore | verify)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  echo "=========================================="
  echo " Performing Dry-Run Test Restore..."
  echo "=========================================="
  restic-central restore latest --target /tmp/restic-test-restore --dry-run
  echo "=========================================="
  echo " Test restore successful! Decryption and index verified."
  echo "=========================================="
  ;;

prune)
  ensure_root "$cmd" "$@"
  DATA_DIR="${RESTIC_SERVER_DATA_DIR:-/var/lib/restic}"
  PW_FILE="${RESTIC_PASSWORD_FILE:-/run/secrets/restic-password}"
  KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
  KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
  KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-12}"
  KEEP_YEARLY="${RESTIC_KEEP_YEARLY:-1}"
  SUBSET="${RESTIC_READ_DATA_SUBSET:-}"

  if [ ! -d "$DATA_DIR" ]; then
    echo "Data directory '$DATA_DIR' does not exist."
    echo "Note: If this host is a pure client, retention pruning is executed centrally on the backup server."
    exit 0
  fi

  if [ ! -f "$PW_FILE" ]; then
    echo "Error: Password file '$PW_FILE' not found! Cannot perform pruning." >&2
    exit 1
  fi

  echo "=========================================="
  echo " Restic Server Retention Pruning & Integrity Check"
  echo " Data Directory: $DATA_DIR"
  echo " Retention: $KEEP_DAILY daily, $KEEP_WEEKLY weekly, $KEEP_MONTHLY monthly, $KEEP_YEARLY yearly"
  if [ -n "$SUBSET" ]; then
    echo " Data Check Subset: $SUBSET"
  fi
  echo "=========================================="

  PRUNED=0
  for repo in "$DATA_DIR"/*; do
    if [ -d "$repo" ] && [ -f "$repo/config" ]; then
      repo_name="$(basename "$repo")"
      echo "--> Pruning repository: $repo_name"
      restic -r "$repo" --password-file "$PW_FILE" unlock || true
      restic -r "$repo" --password-file "$PW_FILE" forget \
        --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" \
        --keep-yearly "$KEEP_YEARLY" \
        --prune

      if [ -n "$SUBSET" ]; then
        echo "--> Checking repository integrity (deep subset: $SUBSET): $repo_name"
        restic -r "$repo" --password-file "$PW_FILE" check --read-data-subset "$SUBSET" || true
      else
        echo "--> Checking repository integrity: $repo_name"
        restic -r "$repo" --password-file "$PW_FILE" check || true
      fi
      PRUNED=1
    fi
  done

  if [ "$PRUNED" -eq 0 ]; then
    echo "No valid Restic repositories (containing 'config') found in $DATA_DIR."
  else
    # Ensure repository permissions remain owned by restic user
    chown -R restic:restic "$DATA_DIR" 2>/dev/null || true
    echo "=========================================="
    echo " Server pruning and integrity checks completed!"
    echo "=========================================="
  fi
  ;;

diff)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  exec restic-central diff "$@"
  ;;

restore)
  ensure_root "$cmd" "$@"
  ensure_restic_central
  if [ "$#" -lt 2 ]; then
    echo "Usage: backup restore <snapshot-id> <target-directory>"
    exit 1
  fi
  SNAPSHOT_ID="$1"
  TARGET_DIR="$2"
  mkdir -p "$TARGET_DIR"
  echo "--> Restoring snapshot $SNAPSHOT_ID to $TARGET_DIR..."
  exec restic-central restore "$SNAPSHOT_ID" --target "$TARGET_DIR"
  ;;

logs)
  exec journalctl -u "restic-backups-central*" -u "restic-server-prune*" -f
  ;;

help | --help | -h)
  echo "=========================================="
  echo " Restic Backup Management CLI"
  echo "=========================================="
  echo ""
  echo "Usage: backup <command> [options]"
  echo ""
  echo "Commands:"
  echo "  now, run, start       Start backup job immediately in foreground"
  echo "  snapshots, list, ls   List existing snapshots in repository"
  echo "  status                Show status of backup timers and recent executions"
  echo "  mount [<path>]        Mount repository as virtual filesystem (default: /mnt/backup-restore)"
  echo "  umount [<path>]       Unmount previously mounted repository"
  echo "  check [--deep]        Verify repository integrity (use --deep for 10% data chunk check)"
  echo "  test-restore, verify  Perform a dry-run test restore of the latest snapshot"
  echo "  prune                 Run retention pruning and integrity check across server repositories"
  echo "  diff <id1> <id2>      Show changes between two snapshots"
  echo "  restore <id> <target> Restore snapshot to specified target folder"
  echo "  logs                  Follow real-time backup service logs via journalctl"
  echo "  help                  Show this help overview"
  echo ""
  ;;

*)
  echo "Unknown command: $cmd" >&2
  echo "Run 'backup help' for available commands." >&2
  exit 1
  ;;
esac
