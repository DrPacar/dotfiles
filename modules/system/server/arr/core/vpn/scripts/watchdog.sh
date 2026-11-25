#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Autonomous Namespace Watchdog & Auto-Healing
# =============================================================================
#
# Purpose:
#   Performs periodic end-to-end connectivity probes strictly inside the
#   BitTorrent VPN network namespace through the WireGuard interface.
#   - Detects dead peers (stale cryptographic handshake > MAX_AGE).
#   - Detects stalled upstream routing (3 consecutive ICMP failures even when
#     keepalives maintain a recent handshake).
#   - Restarts `${NAMESPACE}.service` when a failure threshold is crossed,
#     cleanly cascading to bound services (qBittorrent, WebUI proxy, NAT-PMP).
#
# Execution Context:
#   Triggered periodically by systemd timer `${NAMESPACE}-watchdog.timer`.
# =============================================================================

: "${NAMESPACE:?NAMESPACE environment variable is required}"
: "${WG_IFACE:?WG_IFACE environment variable is required}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
MAX_AGE="${MAX_AGE:-180}"
UNIT="${NAMESPACE}.service"
STATE_DIR="/run/arr-vpn"
FAIL_FILE="${STATE_DIR}/ping_fails_${NAMESPACE}"

# Exit cleanly if the tunnel service is intentionally stopped
if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

# -----------------------------------------------------------------------------
# 1. Probe connectivity strictly through WG_IFACE inside the VPN namespace
# -----------------------------------------------------------------------------
if ip netns exec "$NAMESPACE" ping -c 2 -W 3 -I "$WG_IFACE" "$PING_TARGET" >/dev/null 2>&1; then
	rm -f "$FAIL_FILE"
	exit 0
fi

# -----------------------------------------------------------------------------
# 2. Ping failed: evaluate consecutive failures and handshake age
# -----------------------------------------------------------------------------
mkdir -p "$STATE_DIR"
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
	systemctl restart "$UNIT"
elif [ "$FAILS" -ge 3 ]; then
	echo "WARN: [arr-vpn-watchdog] Connectivity test to $PING_TARGET failed 3 consecutive times in netns '$NAMESPACE' despite recent handshake (${AGE}s). Restarting $UNIT..." >&2
	rm -f "$FAIL_FILE"
	systemctl restart "$UNIT"
else
	echo "INFO: [arr-vpn-watchdog] Connectivity test failed in netns '$NAMESPACE' (attempt $FAILS/3, handshake ${AGE}s ago). Awaiting next cycle."
fi
