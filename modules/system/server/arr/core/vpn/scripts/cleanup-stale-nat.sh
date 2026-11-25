#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Legacy Stale Host NAT Rule Cleanup
# =============================================================================
#
# Purpose:
#   Flushes any stale DNAT OUTPUT iptables rules left over from pre-proxy
#   configurations before qbittorrent-webui-proxy binds the port on the host.
#
# Execution Context:
#   Invoked by systemd ExecStartPre in `qbittorrent-webui-proxy.service`.
# =============================================================================

DEST_IP="${1:-}"
PORT="${2:-}"

if [[ -z $DEST_IP || -z $PORT ]]; then
	echo "WARN: [cleanup-stale-nat] Missing DEST_IP or PORT. Skipping cleanup." >&2
	exit 0
fi

while iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport "$PORT" -j DNAT --to-destination "${DEST_IP}:${PORT}" 2>/dev/null; do
	:
done

while iptables -t nat -D OUTPUT -p tcp -m addrtype --dst-type LOCAL --dport "$PORT" -j DNAT --to-destination "${DEST_IP}:${PORT}" 2>/dev/null; do
	:
done
