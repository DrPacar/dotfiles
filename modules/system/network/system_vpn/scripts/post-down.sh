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
#   Invoked by systemd ExecStopPost in `wg-quick-${IFACE}.service` when the
#   WireGuard service is stopped or restarted.
# =============================================================================

: "${PHYS_IFACE:?PHYS_IFACE is required}"
TAILSCALE_ENABLED="${TAILSCALE_ENABLED:-0}"
TAILSCALE_IFACE="${TAILSCALE_IFACE:-tailscale0}"
SPLIT_DNS_ENABLED="${SPLIT_DNS_ENABLED:-0}"

# -----------------------------------------------------------------------------
# 1. Clean up managed policy routing rules (data-driven)
# -----------------------------------------------------------------------------
for fam in -4 -6; do
	if [ "$fam" = "-6" ] && [ ! -e /proc/net/if_inet6 ]; then
		continue
	fi
	for prio in 4990 4991 5000 5010 5011 5020; do
		while ip "$fam" rule del priority "$prio" 2>/dev/null; do :; done
	done
done

if [ "$TAILSCALE_ENABLED" = "1" ]; then
	ip route del 100.64.0.0/10 dev "$TAILSCALE_IFACE" 2>/dev/null || true
	if [ -e /proc/net/if_inet6 ]; then
		ip -6 route del fd7a:115c:a1e0::/48 dev "$TAILSCALE_IFACE" 2>/dev/null || true
	fi
fi

# -----------------------------------------------------------------------------
# 2. Flush WireGuard routing table 51820
# -----------------------------------------------------------------------------
ip route flush table 51820 2>/dev/null || true
if [ -e /proc/net/if_inet6 ]; then
	ip -6 route flush table 51820 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 3. Enforce fail-closed Split-DNS on physical interface
# -----------------------------------------------------------------------------
# Ensure the physical interface remains default-route=no to prevent DNS leaks
# when the VPN tunnel is stopped.
if [ "$SPLIT_DNS_ENABLED" = "1" ]; then
	if command -v resolvectl >/dev/null 2>&1; then
		resolvectl default-route "$PHYS_IFACE" no 2>/dev/null || true
	fi
fi
