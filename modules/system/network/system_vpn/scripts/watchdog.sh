#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Autonomous Connectivity Watchdog & Auto-Healing
# =============================================================================
#
# Purpose:
#   Performs periodic end-to-end data plane connectivity checks through the
#   active WireGuard interface.
#   - Detects dead peers (stale cryptographic handshake > MAX_AGE).
#   - Detects stalled upstream routing (consecutive ICMP failures >= 3 even if
#     handshake is fresh due to persistent-keepalive).
#   - Automatically restarts the tunnel service when a failure threshold is crossed.
#
# Execution Context:
#   Triggered periodically by systemd timer `${IFACE}-watchdog.timer`.
# =============================================================================

: "${IFACE:?IFACE environment variable is required}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
MAX_AGE="${MAX_AGE:-180}"
UNIT="wg-quick-${IFACE}.service"
STATE_DIR="/run/system-vpn"
FAIL_FILE="${STATE_DIR}/ping_fails_${IFACE}"

# Exit cleanly if the tunnel service is not active
if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

# -----------------------------------------------------------------------------
# 1. Probe connectivity strictly through the WireGuard interface
# -----------------------------------------------------------------------------
if ping -c 2 -W 3 -I "$IFACE" "$PING_TARGET" >/dev/null 2>&1; then
	# Connection healthy; reset failure tracking
	rm -f "$FAIL_FILE"
	exit 0
fi

# -----------------------------------------------------------------------------
# 2. Ping failed: evaluate consecutive failures and handshake age
# -----------------------------------------------------------------------------
mkdir -p "$STATE_DIR" 2>/dev/null || true
FAILS=0
if [ -f "$FAIL_FILE" ]; then
	FAILS=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
fi
FAILS=$((FAILS + 1))
echo "$FAILS" >"$FAIL_FILE" 2>/dev/null || true

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
	systemctl restart "$UNIT"
# Threshold 2: Upstream routing dead (3 consecutive failures despite fresh keepalives)
elif [ "$FAILS" -ge 3 ]; then
	echo "WARN: [system-vpn-watchdog] Connectivity test to $PING_TARGET failed 3 consecutive times on $IFACE despite recent handshake (${AGE}s). Restarting $UNIT to heal stalled routing..." >&2
	rm -f "$FAIL_FILE"
	systemctl restart "$UNIT"
else
	echo "INFO: [system-vpn-watchdog] Connectivity test failed on $IFACE (attempt $FAILS/3, handshake ${AGE}s ago). Awaiting next evaluation cycle."
fi
