#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Post-Down Policy Routing Cleanup & Teardown
# =============================================================================
#
# Purpose:
#   1. Flushes custom Linux Policy Routing rules (`ip rule`) installed during
#      tunnel activation, returning system routing to its baseline state.
#      Only deletes our own managed priorities (4990-5020), preserving Tailscale's
#      5210+ rules.
#   2. Flushes the isolated WireGuard routing table (table 51820).
#   3. Enforces fail-closed Split-DNS by preserving DefaultRoute=no on the physical
#      interface, preventing unencrypted DNS leaks to the local router.
#
# Execution Context:
#   Invoked by systemd ExecStopPost in the wg-quick service when stopped or restarted.
# =============================================================================

: "${PHYS_IFACE:?PHYS_IFACE is required}"
TAILSCALE_ENABLED="${TAILSCALE_ENABLED:-0}"
TAILSCALE_IFACE="${TAILSCALE_IFACE:-tailscale0}"
SPLIT_DNS_ENABLED="${SPLIT_DNS_ENABLED:-0}"

# -----------------------------------------------------------------------------
# 1. Clean up managed policy routing rules and table 51820 (IPv4 & IPv6)
# -----------------------------------------------------------------------------
for fam in -4 -6; do
	if [ "$fam" = "-6" ] && [ ! -e /proc/net/if_inet6 ]; then
		continue
	fi

	for prio in 4990 4991 4992 5000 5010 5011 5020; do
		while ip "$fam" rule del priority "$prio" 2>/dev/null; do :; done
	done

	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		if [ "$fam" = "-4" ]; then
			ts_net="100.64.0.0/10"
		else
			ts_net="fd7a:115c:a1e0::/48"
		fi
		ip "$fam" route del "$ts_net" dev "$TAILSCALE_IFACE" 2>/dev/null || true
	fi

	ip "$fam" route flush table 51820 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# 2. Enforce fail-closed Split-DNS on physical interface
# -----------------------------------------------------------------------------
# Keep DefaultRoute=no on the physical link so DNS fails closed while VPN is down.
if [ "$SPLIT_DNS_ENABLED" = "1" ] && command -v resolvectl >/dev/null 2>&1; then
	resolvectl default-route "$PHYS_IFACE" no 2>/dev/null || true
fi
