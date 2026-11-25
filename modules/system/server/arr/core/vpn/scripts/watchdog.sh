#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Autonomous Namespace Watchdog, NAT-PMP Recovery & Alerting
# =============================================================================
#
# Purpose:
#   Performs periodic end-to-end connectivity probes strictly inside the
#   BitTorrent VPN network namespace through the WireGuard interface and
#   monitors NAT-PMP port-lease health on the host.
#   - Detects dead peers (stale cryptographic handshake > MAX_AGE).
#   - Detects stalled upstream routing (3 consecutive ICMP failures even when
#     keepalives maintain a recent handshake).
#   - Detects stalled NAT-PMP port leases (>= NATPMP_FAIL_THRESHOLD failures),
#     emits alerts via NOTIFY_BIN, and restarts `${NAMESPACE}.service` with
#     cooldown protection.
#   - Emits recovery notifications when tunnel or NAT-PMP health returns.
#
# Execution Context:
#   Triggered periodically on the host by `${NAMESPACE}-watchdog.timer`.
# =============================================================================

: "${NAMESPACE:?NAMESPACE environment variable is required}"
: "${WG_IFACE:?WG_IFACE environment variable is required}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
MAX_AGE="${MAX_AGE:-180}"
PORT_FORWARDING_ENABLED="${PORT_FORWARDING_ENABLED:-0}"
PORT_STATE_FILE="${PORT_STATE_FILE:-/run/protonvpn-port-forward/port}"
NATPMP_FAIL_FILE="${NATPMP_FAIL_FILE:-/run/protonvpn-port-forward/fail_streak}"
NATPMP_FAIL_THRESHOLD="${NATPMP_FAIL_THRESHOLD:-12}"
NATPMP_RESTART_COOLDOWN="${NATPMP_RESTART_COOLDOWN:-900}"
NOTIFY_BIN="${NOTIFY_BIN:-}"

UNIT="${NAMESPACE}.service"
STATE_DIR="/run/arr-vpn"
FAIL_FILE="${STATE_DIR}/ping_fails_${NAMESPACE}"
TUNNEL_ALERTED_FILE="${STATE_DIR}/tunnel_alerted_${NAMESPACE}"
NATPMP_ALERTED_FILE="${STATE_DIR}/natpmp_alerted_${NAMESPACE}"
NATPMP_RESTART_TS_FILE="${STATE_DIR}/natpmp_last_restart_${NAMESPACE}"

send_alert() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ -n "$NOTIFY_BIN" ] && [ -x "$NOTIFY_BIN" ]; then
		if ! "$NOTIFY_BIN" "$msg" "$tag"; then
			echo "WARN: [arr-vpn-watchdog] Notification handler '$NOTIFY_BIN' failed." >&2
		fi
	fi
}

send_tunnel_alert_once() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ ! -f "$TUNNEL_ALERTED_FILE" ]; then
		touch "$TUNNEL_ALERTED_FILE"
		send_alert "$msg" "$tag"
	fi
}

# Revive failed tunnel unit (e.g. prolonged ISP outage), while respecting deliberate admin stops
if systemctl is-failed --quiet "$UNIT"; then
	mkdir -p "$STATE_DIR"
	echo "WARN: [arr-vpn-watchdog] Service $UNIT is in failed state. Resetting and starting..." >&2
	send_tunnel_alert_once "Arr VPN (${NAMESPACE}/${WG_IFACE}): Service ${UNIT} entered failed state. Resetting and starting." "rotating_light"
	systemctl reset-failed "$UNIT"
	systemctl start "$UNIT"
	exit 0
fi

if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

mkdir -p "$STATE_DIR"

# -----------------------------------------------------------------------------
# 1. Probe WireGuard data-plane connectivity inside the VPN namespace
# -----------------------------------------------------------------------------
if ip netns exec "$NAMESPACE" ping -c 2 -W 3 -I "$WG_IFACE" "$PING_TARGET" >/dev/null 2>&1; then
	rm -f "$FAIL_FILE"
	if [ -f "$TUNNEL_ALERTED_FILE" ]; then
		rm -f "$TUNNEL_ALERTED_FILE"
		send_alert "Arr VPN (${NAMESPACE}/${WG_IFACE}): Tunnel connectivity restored." "white_check_mark"
	fi
else
	FAILS=0
	if [ -f "$FAIL_FILE" ]; then
		FAILS=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
	fi
	FAILS=$((FAILS + 1))
	if ! echo "$FAILS" >"$FAIL_FILE"; then
		echo "WARN: [arr-vpn-watchdog] Failed to persist failure count to $FAIL_FILE." >&2
	fi

	LATEST_HANDSHAKE=$(ip netns exec "$NAMESPACE" wg show "$WG_IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
	NOW=$(date +%s)

	if [ -n "$LATEST_HANDSHAKE" ] && [ "$LATEST_HANDSHAKE" -gt 0 ]; then
		AGE=$((NOW - LATEST_HANDSHAKE))
	else
		AGE=999999
	fi

	if [ "$AGE" -gt "$MAX_AGE" ]; then
		echo "WARN: [arr-vpn-watchdog] Connectivity test to $PING_TARGET failed in netns '$NAMESPACE' ($WG_IFACE) and handshake age is ${AGE}s (> ${MAX_AGE}s). Restarting $UNIT..." >&2
		rm -f "$FAIL_FILE"
		send_tunnel_alert_once "Arr VPN (${NAMESPACE}/${WG_IFACE}): Tunnel down (last handshake ${AGE}s ago). Restarting ${UNIT}." "rotating_light"
		systemctl restart "$UNIT"
		exit 0
	elif [ "$FAILS" -ge 3 ]; then
		echo "WARN: [arr-vpn-watchdog] Connectivity test to $PING_TARGET failed 3 consecutive times in netns '$NAMESPACE' despite recent handshake (${AGE}s). Restarting $UNIT..." >&2
		rm -f "$FAIL_FILE"
		send_tunnel_alert_once "Arr VPN (${NAMESPACE}/${WG_IFACE}): 3 consecutive ping failures despite recent handshake (${AGE}s ago). Restarting ${UNIT}." "warning"
		systemctl restart "$UNIT"
		exit 0
	else
		echo "INFO: [arr-vpn-watchdog] Connectivity test failed in netns '$NAMESPACE' (attempt $FAILS/3, handshake ${AGE}s ago). Awaiting next cycle."
		exit 0
	fi
fi

# -----------------------------------------------------------------------------
# 2. Monitor NAT-PMP port-forwarding health (tunnel up, lease stalled)
# -----------------------------------------------------------------------------
if [ "$PORT_FORWARDING_ENABLED" = "1" ] && systemctl is-active --quiet protonvpn-port-forward.service; then
	NATPMP_STREAK=0
	if [ -f "$NATPMP_FAIL_FILE" ]; then
		NATPMP_STREAK=$(tr -d '[:space:]' <"$NATPMP_FAIL_FILE" 2>/dev/null || echo 0)
	fi

	if [[ $NATPMP_STREAK =~ ^[0-9]+$ ]] && [ "$NATPMP_STREAK" -ge "$NATPMP_FAIL_THRESHOLD" ]; then
		NOW=$(date +%s)
		LAST_RESTART=0
		if [ -f "$NATPMP_RESTART_TS_FILE" ]; then
			LAST_RESTART=$(tr -d '[:space:]' <"$NATPMP_RESTART_TS_FILE" 2>/dev/null || echo 0)
		fi
		ELAPSED=$((NOW - LAST_RESTART))

		if [ ! -f "$NATPMP_ALERTED_FILE" ]; then
			touch "$NATPMP_ALERTED_FILE"
			send_alert "Arr VPN (${NAMESPACE}): NAT-PMP port forwarding failed for ${NATPMP_STREAK} consecutive checks (tunnel ping OK)." "warning"
		fi

		if [ "$ELAPSED" -ge "$NATPMP_RESTART_COOLDOWN" ]; then
			echo "WARN: [arr-vpn-watchdog] NAT-PMP failed $NATPMP_STREAK consecutive times (>= $NATPMP_FAIL_THRESHOLD). Restarting $UNIT to renew gateway lease..." >&2
			echo "$NOW" >"$NATPMP_RESTART_TS_FILE"
			systemctl restart "$UNIT"
		else
			echo "INFO: [arr-vpn-watchdog] NAT-PMP stalled ($NATPMP_STREAK failures), tunnel restart in cooldown (${ELAPSED}s/${NATPMP_RESTART_COOLDOWN}s)."
		fi
	elif [ -f "$NATPMP_ALERTED_FILE" ] && [ -f "$PORT_STATE_FILE" ]; then
		ACTIVE_PORT=$(tr -d '[:space:]' <"$PORT_STATE_FILE" 2>/dev/null || true)
		rm -f "$NATPMP_ALERTED_FILE"
		send_alert "Arr VPN (${NAMESPACE}): NAT-PMP port forwarding restored (port ${ACTIVE_PORT:-unknown})." "white_check_mark"
	fi
fi
