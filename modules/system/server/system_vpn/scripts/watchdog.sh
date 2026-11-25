#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Autonomous Connectivity Watchdog, Auto-Healing & Alerting
# =============================================================================
#
# Purpose:
#   Performs periodic end-to-end data plane connectivity checks through the
#   active WireGuard interface.
#   - Revives `wg-quick-${IFACE}.service` if it enters systemd's failed state
#     (while respecting deliberate admin stops).
#   - Detects dead peers (stale cryptographic handshake > MAX_AGE).
#   - Detects stalled upstream routing (consecutive ICMP failures >= 3 even if
#     handshake is fresh due to persistent-keepalive).
#   - Automatically restarts the tunnel service when a failure threshold is crossed.
#   - Emits deduplicated alerts on outage and a single recovery notification via
#     NOTIFY_BIN (e.g., local ntfy over loopback).
#
# Execution Context:
#   Triggered periodically by systemd timer `${IFACE}-watchdog.timer`.
# =============================================================================

: "${IFACE:?IFACE environment variable is required}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
MAX_AGE="${MAX_AGE:-180}"
NOTIFY_BIN="${NOTIFY_BIN:-}"

UNIT="wg-quick-${IFACE}.service"
STATE_DIR="/run/system-vpn"
FAIL_FILE="${STATE_DIR}/ping_fails_${IFACE}"
ALERTED_FILE="${STATE_DIR}/alerted_${IFACE}"

send_alert() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ -n "$NOTIFY_BIN" ] && [ -x "$NOTIFY_BIN" ]; then
		if ! "$NOTIFY_BIN" "$msg" "$tag"; then
			echo "WARN: [system-vpn-watchdog] Notification handler '$NOTIFY_BIN' failed." >&2
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

# Revive failed tunnel unit (e.g. prolonged ISP outage), while respecting deliberate admin stops
if systemctl is-failed --quiet "$UNIT"; then
	echo "WARN: [system-vpn-watchdog] Service $UNIT is in failed state. Resetting and starting..." >&2
	send_alert_once "System VPN (${IFACE}): Service ${UNIT} war im Fehlerzustand (failed). Starte neu." "rotating_light"
	systemctl reset-failed "$UNIT"
	systemctl start "$UNIT"
	exit 0
fi

# Exit cleanly if the tunnel service is intentionally stopped
if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

# -----------------------------------------------------------------------------
# 1. Probe connectivity strictly through the WireGuard interface
# -----------------------------------------------------------------------------
if ping -c 2 -W 3 -I "$IFACE" "$PING_TARGET" >/dev/null 2>&1; then
	rm -f "$FAIL_FILE"
	if [ -f "$ALERTED_FILE" ]; then
		rm -f "$ALERTED_FILE"
		send_alert "System VPN (${IFACE}): Tunnel-Konnektivität wiederhergestellt." "white_check_mark"
	fi
	exit 0
fi

# -----------------------------------------------------------------------------
# 2. Ping failed: evaluate consecutive failures and handshake age
# -----------------------------------------------------------------------------
FAILS=0
if [ -f "$FAIL_FILE" ]; then
	FAILS=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
fi
FAILS=$((FAILS + 1))
if ! echo "$FAILS" >"$FAIL_FILE"; then
	echo "WARN: [system-vpn-watchdog] Failed to persist failure count to $FAIL_FILE." >&2
fi

LATEST_HANDSHAKE=$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
NOW=$(date +%s)

if [ -n "$LATEST_HANDSHAKE" ] && [ "$LATEST_HANDSHAKE" -gt 0 ]; then
	AGE=$((NOW - LATEST_HANDSHAKE))
else
	AGE=999999
fi

# Threshold 1: Peer handshake timed out
if [ "$AGE" -gt "$MAX_AGE" ]; then
	echo "WARN: [system-vpn-watchdog] Connectivity test to $PING_TARGET failed on $IFACE and handshake age is ${AGE}s (> ${MAX_AGE}s). Restarting $UNIT..." >&2
	rm -f "$FAIL_FILE"
	send_alert_once "System VPN (${IFACE}): Tunnel ausgefallen (Handshake vor ${AGE}s). Starte ${UNIT} neu." "rotating_light"
	systemctl restart "$UNIT"
# Threshold 2: Upstream routing dead (3 consecutive failures despite fresh keepalives)
elif [ "$FAILS" -ge 3 ]; then
	echo "WARN: [system-vpn-watchdog] Connectivity test to $PING_TARGET failed 3 consecutive times on $IFACE despite recent handshake (${AGE}s). Restarting $UNIT to heal stalled routing..." >&2
	rm -f "$FAIL_FILE"
	send_alert_once "System VPN (${IFACE}): 3 Ping-Fehlversuche trotz Handshake (${AGE}s). Starte ${UNIT} neu." "warning"
	systemctl restart "$UNIT"
else
	echo "INFO: [system-vpn-watchdog] Connectivity test failed on $IFACE (attempt $FAILS/3, handshake ${AGE}s ago). Awaiting next evaluation cycle."
fi
