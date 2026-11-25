#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Vaultwarden: Autonomous Watchdog, /alive Health Probe & Alerting
# =============================================================================

: "${LOCAL_URL:?LOCAL_URL environment variable is required}"
FAILURE_THRESHOLD="${FAILURE_THRESHOLD:-3}"
NOTIFY_BIN="${NOTIFY_BIN:-}"

UNIT="vaultwarden.service"
STATE_DIR="/run/vaultwarden-watchdog"
FAIL_FILE="${STATE_DIR}/probe_fails"
ALERTED_FILE="${STATE_DIR}/alerted"

send_alert() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ -n "$NOTIFY_BIN" ] && [ -x "$NOTIFY_BIN" ]; then
		if ! "$NOTIFY_BIN" "$msg" "$tag"; then
			echo "WARN: [vaultwarden-watchdog] Notification handler '$NOTIFY_BIN' failed." >&2
		fi
	fi
}

send_alert_once() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ ! -f "$ALERTED_FILE" ]; then
		touch "$ALERTED_FILE"
		send_alert "$msg" "$tag"
	fi
}

mkdir -p "$STATE_DIR"

# Revive failed Vaultwarden unit (respecting deliberate manual stops)
if systemctl is-failed --quiet "$UNIT"; then
	echo "WARN: [vaultwarden-watchdog] $UNIT is in failed state. Resetting and starting..." >&2
	send_alert_once "Vaultwarden: Service ${UNIT} entered failed state. Resetting and starting." "rotating_light"
	systemctl reset-failed "$UNIT"
	systemctl start "$UNIT"
	exit 0
fi

if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

if curl --connect-timeout 3 -m 5 -fsS "${LOCAL_URL}/alive" >/dev/null 2>&1; then
	rm -f "$FAIL_FILE"
	if [ -f "$ALERTED_FILE" ]; then
		rm -f "$ALERTED_FILE"
		send_alert "Vaultwarden: Health endpoint (/alive) and service operational again." "white_check_mark"
	fi
	exit 0
fi

FAILS=0
if [ -f "$FAIL_FILE" ]; then
	FAILS=$(tr -d '[:space:]' <"$FAIL_FILE" 2>/dev/null || echo 0)
fi
if ! [[ $FAILS =~ ^[0-9]+$ ]]; then
	FAILS=0
fi
FAILS=$((FAILS + 1))
echo "$FAILS" >"$FAIL_FILE"

if [ "$FAILS" -ge "$FAILURE_THRESHOLD" ]; then
	echo "WARN: [vaultwarden-watchdog] /alive probe failed $FAILS consecutive times (${LOCAL_URL}/alive). Restarting $UNIT..." >&2
	rm -f "$FAIL_FILE"
	send_alert_once "Vaultwarden: Health endpoint unresponsive after ${FAILS} checks (${LOCAL_URL}/alive). Restarting ${UNIT}." "rotating_light"
	systemctl restart "$UNIT"
else
	echo "INFO: [vaultwarden-watchdog] /alive probe failed (attempt $FAILS/$FAILURE_THRESHOLD). Awaiting next cycle."
fi
