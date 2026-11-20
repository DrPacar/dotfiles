#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-${1:-wg-system}}"
PING_TARGET="${PING_TARGET:-${2:-1.1.1.1}}"
MAX_AGE="${MAX_AGE:-${3:-180}}"
UNIT="wg-quick-${IFACE}.service"

# Only check when the system VPN is supposed to be active
if ! systemctl is-active --quiet "$UNIT"; then
  exit 0
fi

# Quick connectivity test through the WireGuard interface
if ping -c 2 -W 3 -I "$IFACE" "$PING_TARGET" >/dev/null 2>&1; then
  exit 0
fi

# Ping failed; check WireGuard latest handshake timestamp
LATEST_HANDSHAKE=$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
NOW=$(date +%s)

if [ -n "$LATEST_HANDSHAKE" ] && [ "$LATEST_HANDSHAKE" -gt 0 ]; then
  AGE=$((NOW - LATEST_HANDSHAKE))
else
  AGE=999999
fi

if [ "$AGE" -gt "$MAX_AGE" ]; then
  echo "WARN: [system-vpn-watchdog] Ping to $PING_TARGET failed on $IFACE and handshake age is ${AGE}s (> ${MAX_AGE}s). Restarting $UNIT..." >&2
  systemctl restart "$UNIT"
else
  echo "INFO: [system-vpn-watchdog] Ping failed on $IFACE, but latest handshake is recent (${AGE}s ago). Waiting for next cycle."
fi
