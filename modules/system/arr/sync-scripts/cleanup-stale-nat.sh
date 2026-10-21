#!/usr/bin/env bash
# =============================================================================
# cleanup-stale-nat.sh
# Flushes any stale DNAT iptables rules from legacy configurations.
# Runs as ExecStartPre before qbittorrent-webui-proxy starts.
# =============================================================================
set -euo pipefail

DEST_IP="${1:-}"
PORT="${2:-}"

if [[ -z $DEST_IP || -z $PORT ]]; then
  echo "[cleanup-stale-nat] Missing DEST_IP or PORT. Usage: $0 <dest_ip> <port>" >&2
  exit 0
fi

# Clean up loopback DNAT rules if present
while iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport "$PORT" -j DNAT --to-destination "${DEST_IP}:${PORT}" 2>/dev/null; do
  :
done

# Clean up local addrtype DNAT rules if present
while iptables -t nat -D OUTPUT -p tcp -m addrtype --dst-type LOCAL --dport "$PORT" -j DNAT --to-destination "${DEST_IP}:${PORT}" 2>/dev/null; do
  :
done

exit 0
