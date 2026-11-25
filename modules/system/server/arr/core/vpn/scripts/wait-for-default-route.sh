#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Pre-Start Physical Route Readiness Wait
# =============================================================================
#
# Purpose:
#   Waits until the host's main routing table has a default IPv4 route before
#   wg-up attempts to bring up the WireGuard namespace and probe the endpoint.
#
# Execution Context:
#   Invoked by systemd ExecStartPre in `${NAMESPACE}.service`.
# =============================================================================

MAX_WAIT=30

for _ in $(seq 1 "$MAX_WAIT"); do
	if ip -4 route show default table main 2>/dev/null | grep -q '^default'; then
		exit 0
	fi
	sleep 1
done

echo "ERROR: [arr-vpn-wait-route] No default IPv4 route in table main after ${MAX_WAIT}s." >&2
exit 1
