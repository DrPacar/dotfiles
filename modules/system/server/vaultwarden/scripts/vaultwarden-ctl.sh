#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Vaultwarden: Status, Self-Test & Backup CLI (`vaultwarden-ctl`)
# =============================================================================

: "${LOCAL_URL:?LOCAL_URL environment variable is required}"
: "${VAULT_URL:?VAULT_URL environment variable is required}"
: "${DATA_DIR:?DATA_DIR environment variable is required}"
: "${BACKUP_ENABLED:?BACKUP_ENABLED environment variable is required}"
: "${BACKUP_DIR:?BACKUP_DIR environment variable is required}"
SIGNUPS_ALLOWED="${SIGNUPS_ALLOWED:-false}"
INVITATIONS_ALLOWED="${INVITATIONS_ALLOWED:-false}"

UNIT="vaultwarden.service"
BACKUP_UNIT="backup-vaultwarden.service"
BACKUP_TIMER="backup-vaultwarden.timer"
WATCHDOG_TIMER="vaultwarden-watchdog.timer"

if [ -t 1 ]; then
	BOLD=$'\033[1m'
	GREEN=$'\033[0;32m'
	RED=$'\033[0;31m'
	YELLOW=$'\033[0;33m'
	CYAN=$'\033[0;36m'
	RESET=$'\033[0m'
else
	BOLD=""
	GREEN=""
	RED=""
	YELLOW=""
	CYAN=""
	RESET=""
fi

usage() {
	cat <<'EOF'
Usage: vaultwarden-ctl <command>

Commands:
  status    Show service health, memory usage, signup policy, DB state, and backups
  check     Run automated self-test (/alive probe, systemd units, DB integrity, backups)
  backup    Trigger an immediate atomic SQLite backup via backup-vaultwarden.service
EOF
}

CMD="${1:-status}"
case "$CMD" in
-h | --help | help)
	usage
	exit 0
	;;
status)
	echo -e "${BOLD}${CYAN}=== Vaultwarden Status ===${RESET}"
	SVC_STATE=$(systemctl is-active "$UNIT" 2>/dev/null || echo "inactive")
	MEM_BYTES=$(systemctl show -p MemoryCurrent --value "$UNIT" 2>/dev/null || echo "0")
	if [[ $MEM_BYTES =~ ^[0-9]+$ ]] && [ "$MEM_BYTES" -gt 0 ]; then
		MEM_HUMAN=$(awk -v b="$MEM_BYTES" 'BEGIN {printf "%.1f MiB", b / 1048576}')
	else
		MEM_HUMAN="n/a"
	fi
	WD_STATE=$(systemctl is-active "$WATCHDOG_TIMER" 2>/dev/null || echo "disabled")

	ALIVE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 -m 4 "${LOCAL_URL}/alive" || echo "000")
	if [ "$ALIVE_CODE" = "200" ]; then
		ALIVE_STR="${GREEN}HTTP 200 OK${RESET} (${LOCAL_URL}/alive)"
	else
		ALIVE_STR="${RED}HTTP ${ALIVE_CODE}${RESET} (${LOCAL_URL}/alive)"
	fi

	echo -e "  Service:          ${SVC_STATE} (${MEM_HUMAN})"
	echo -e "  Endpoint:         ${ALIVE_STR}"
	echo -e "  Public URL:       ${VAULT_URL}"
	echo -e "  Signups/Invites:  signups=${SIGNUPS_ALLOWED}, invitations=${INVITATIONS_ALLOWED}"
	echo -e "  Watchdog Timer:   ${WD_STATE}"
	echo -e "  State Directory:  ${DATA_DIR}"

	if [ -r "${DATA_DIR}/db.sqlite3" ]; then
		DB_SIZE=$(stat -c '%s' "${DATA_DIR}/db.sqlite3" | awk '{printf "%.1f KiB", $1 / 1024}')
		USER_COUNT=$(sqlite3 -readonly "${DATA_DIR}/db.sqlite3" "SELECT count(*) FROM users;" 2>/dev/null || echo "?")
		CIPHER_COUNT=$(sqlite3 -readonly "${DATA_DIR}/db.sqlite3" "SELECT count(*) FROM ciphers;" 2>/dev/null || echo "?")
		echo -e "  SQLite Vault DB:  ${DB_SIZE} (${USER_COUNT} user(s), ${CIPHER_COUNT} item(s))"
	else
		echo -e "  SQLite Vault DB:  ${YELLOW}root-only (0700 vaultwarden)${RESET}"
	fi

	if [ "$BACKUP_ENABLED" = "1" ]; then
		BT_STATE=$(systemctl is-active "$BACKUP_TIMER" 2>/dev/null || echo "inactive")
		if [ -r "${BACKUP_DIR}/db.sqlite3" ]; then
			BK_TIME=$(stat -c '%y' "${BACKUP_DIR}/db.sqlite3" | cut -d'.' -f1)
			BK_SIZE=$(stat -c '%s' "${BACKUP_DIR}/db.sqlite3" | awk '{printf "%.1f KiB", $1 / 1024}')
			echo -e "  Backups:          ${GREEN}active${RESET} (${BT_STATE}) • latest: ${BK_TIME} (${BK_SIZE})"
		elif [ -d "$BACKUP_DIR" ]; then
			echo -e "  Backups:          ${YELLOW}${BT_STATE}${RESET} (dir ${BACKUP_DIR} present, run 'sudo vaultwarden-ctl backup' or wait for timer)"
		else
			echo -e "  Backups:          ${RED}${BT_STATE} (backup dir ${BACKUP_DIR} missing)${RESET}"
		fi
	else
		echo -e "  Backups:          ${YELLOW}disabled${RESET}"
	fi
	;;
check)
	echo -e "${BOLD}${CYAN}=== Vaultwarden Self-Test ===${RESET}"
	FAILS=0
	check() {
		local label="$1"
		local ok="$2"
		local detail="${3:-}"
		if [ "$ok" -eq 1 ]; then
			echo -e "  ${GREEN}[PASS]${RESET} ${label}${detail:+ (${detail})}"
		else
			FAILS=$((FAILS + 1))
			echo -e "  ${RED}[FAIL]${RESET} ${label}${detail:+ (${detail})}"
		fi
	}

	SVC_ACTIVE=0
	systemctl is-active --quiet "$UNIT" && SVC_ACTIVE=1 || true
	check "systemd service active" "$SVC_ACTIVE" "$UNIT"

	SVC_NOT_FAILED=1
	systemctl is-failed --quiet "$UNIT" && SVC_NOT_FAILED=0 || true
	check "systemd service not failed" "$SVC_NOT_FAILED" "$UNIT"

	ALIVE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 -m 4 "${LOCAL_URL}/alive" || echo "000")
	ALIVE_OK=0
	[ "$ALIVE_CODE" = "200" ] && ALIVE_OK=1
	check "HTTP /alive health endpoint" "$ALIVE_OK" "HTTP ${ALIVE_CODE}"

	if [ -r "${DATA_DIR}/db.sqlite3" ]; then
		DB_CHECK=$(sqlite3 -readonly "${DATA_DIR}/db.sqlite3" "PRAGMA quick_check;" 2>/dev/null | head -n 1 || echo "error")
		DB_OK=0
		[ "$DB_CHECK" = "ok" ] && DB_OK=1
		check "SQLite database integrity (quick_check)" "$DB_OK" "$DB_CHECK"
	else
		echo -e "  ${YELLOW}[SKIP]${RESET} SQLite database integrity (requires root/sudo to read ${DATA_DIR})"
	fi

	if [ "$BACKUP_ENABLED" = "1" ]; then
		BT_OK=0
		systemctl is-active --quiet "$BACKUP_TIMER" && BT_OK=1 || true
		check "backup timer active" "$BT_OK" "$BACKUP_TIMER"

		BK_NOT_FAILED=1
		systemctl is-failed --quiet "$BACKUP_UNIT" && BK_NOT_FAILED=0 || true
		check "backup service not failed" "$BK_NOT_FAILED" "$BACKUP_UNIT"
	fi

	echo
	if [ "$FAILS" -eq 0 ]; then
		echo -e "${GREEN}${BOLD}ALL VAULTWARDEN CHECKS PASSED${RESET}"
		exit 0
	else
		echo -e "${RED}${BOLD}VAULTWARDEN CHECKS FAILED (${FAILS} error(s))${RESET}"
		exit 1
	fi
	;;
backup)
	echo "Triggering atomic Vaultwarden backup via ${BACKUP_UNIT}..."
	exec systemctl start "$BACKUP_UNIT"
	;;
*)
	usage >&2
	exit 1
	;;
esac
