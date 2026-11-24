#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Post-Up Policy Routing & DNS Configuration
# =============================================================================
#
# Purpose:
#   1. Enforces strict Linux Policy Routing rules (`ip rule`) in deterministic
#      priority order for split-tunneling, Tailscale coexistence, and default VPN egress.
#   2. Validates that the WireGuard interface carries the expected firewall mark.
#   3. Explicitly pins the WireGuard tunnel as the default DNS routing link (~.)
#      with DefaultRoute=yes in systemd-resolved.
#   4. Directs designated internal domains (~local, ~lan) to the physical LAN link.
#
# Execution Context:
#   Invoked by systemd ExecStartPost in `wg-quick-${IFACE}.service` immediately
#   after the WireGuard interface transitions to the UP state.
#
# Environment Variables (injected via commonEnv):
#   PHYS_IFACE         - Physical network interface (e.g., "eno1") [Required]
#   IFACE              - WireGuard interface (e.g., "wg-system") [Required]
#   WG_FWMARK          - WireGuard encapsulation mark (e.g., "0xca6c") [Required]
#   BYPASS_MARK        - Split-tunnel bypass mark (e.g., "0x5200") [Required]
#   TAILSCALE_FWMARK   - Tailscale WAN bypass mark (e.g., "0x80000/0xff0000") [Required]
#   TAILSCALE_ENABLED  - Tailscale presence flag ("1" or "0") [Required]
#   TAILSCALE_IFACE    - Tailscale interface (e.g., "tailscale0") [Required]
#   SPLIT_DNS_ENABLED  - Split-DNS presence flag ("1" or "0") [Required]
#   SPLIT_DNS_DOMAINS  - Domain scopes bound to physical NIC (e.g., "~local ~lan")
#
# Policy Routing Hierarchy:
#   Priority 4990: fwmark 0x5200 -> table main
#                  Traffic marked for bypass routes directly via physical default gateway.
#   Priority 4991: fwmark 0x80000/0xff0000 -> table main
#                  Tailscale outer control/peer traffic routes via physical WAN (not through VPN).
#   Priority 5000: lookup main suppress_prefixlength 0
#                  Directly-connected local LAN subnets, loopback, and host routes (prefix > 0).
#   Priority 5010/5011: to/from 100.64.0.0/10 -> table 52
#                  Tailscale mesh network overlay traffic directed to Tailscale engine.
#   Priority 5020: not fwmark 0xca6c -> table 51820
#                  All other general outbound internet traffic directed into WireGuard VPN.
# =============================================================================

: "${PHYS_IFACE:?PHYS_IFACE is required}"
: "${IFACE:?IFACE is required}"
: "${WG_FWMARK:?WG_FWMARK is required}"
: "${BYPASS_MARK:?BYPASS_MARK is required}"
: "${TAILSCALE_FWMARK:?TAILSCALE_FWMARK is required}"
: "${TAILSCALE_ENABLED:?TAILSCALE_ENABLED is required}"
: "${TAILSCALE_IFACE:?TAILSCALE_IFACE is required}"
: "${SPLIT_DNS_ENABLED:?SPLIT_DNS_ENABLED is required}"
SPLIT_DNS_DOMAINS="${SPLIT_DNS_DOMAINS:-}"

# -----------------------------------------------------------------------------
# 1. Verify that WireGuard carries the expected kernel firewall mark
# -----------------------------------------------------------------------------
ACTUAL_FWMARK=$(wg show "$IFACE" fwmark 2>/dev/null || true)
if [ "$ACTUAL_FWMARK" != "$WG_FWMARK" ]; then
	echo "ERROR: [system-vpn-post-up] Interface '$IFACE' has fwmark '$ACTUAL_FWMARK', expected '$WG_FWMARK'." >&2
	exit 1
fi

# -----------------------------------------------------------------------------
# 2. Clean up auto-generated and stale policy routing rules (data-driven)
# -----------------------------------------------------------------------------
# NOTE: Only delete our own managed priorities (4990-5020). Never delete
# by selector without priority, which would destroy Tailscale's 5210+ rules!
for fam in -4 -6; do
	if [ "$fam" = "-6" ] && [ ! -e /proc/net/if_inet6 ]; then
		continue
	fi
	# Clean auto-generated rules from wg-quick
	while ip "$fam" rule del not fwmark "$WG_FWMARK" lookup 51820 2>/dev/null; do :; done
	while ip "$fam" rule del table main suppress_prefixlength 0 2>/dev/null; do :; done
	# Clean only our own managed priorities
	for prio in 4990 4991 5000 5010 5011 5020; do
		while ip "$fam" rule del priority "$prio" 2>/dev/null; do :; done
	done
done

# -----------------------------------------------------------------------------
# 3. Install deterministic IPv4 policy routing rules (fail fast on error)
# -----------------------------------------------------------------------------
# Priority 4990: Process / service split-tunnel bypass
ip rule add fwmark "$BYPASS_MARK" lookup main priority 4990

# Priority 4991: Tailscale outer encapsulation & control traffic direct via WAN
if [ "$TAILSCALE_ENABLED" = "1" ]; then
	ip rule add fwmark "$TAILSCALE_FWMARK" lookup main priority 4991
fi

# Priority 5000: LAN subnets and local routes take precedence over VPN
ip rule add lookup main suppress_prefixlength 0 priority 5000

# Priority 5010/5011: Tailscale overlay network (CGNAT 100.64.0.0/10)
if [ "$TAILSCALE_ENABLED" = "1" ]; then
	ip rule add to 100.64.0.0/10 lookup 52 priority 5010
	ip rule add from 100.64.0.0/10 lookup 52 priority 5011
	ip route add 100.64.0.0/10 dev "$TAILSCALE_IFACE" 2>/dev/null || true
fi

# Priority 5020: General host internet traffic default to WireGuard
ip rule add not fwmark "$WG_FWMARK" lookup 51820 priority 5020

# -----------------------------------------------------------------------------
# 4. Install deterministic IPv6 policy routing rules (guarded)
# -----------------------------------------------------------------------------
if [ -e /proc/net/if_inet6 ]; then
	ip -6 rule add fwmark "$BYPASS_MARK" lookup main priority 4990
	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		ip -6 rule add fwmark "$TAILSCALE_FWMARK" lookup main priority 4991
	fi
	ip -6 rule add lookup main suppress_prefixlength 0 priority 5000
	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		ip -6 rule add to fd7a:115c:a1e0::/48 lookup 52 priority 5010
		ip -6 rule add from fd7a:115c:a1e0::/48 lookup 52 priority 5011
		ip -6 route add fd7a:115c:a1e0::/48 dev "$TAILSCALE_IFACE" 2>/dev/null || true
	fi
	ip -6 rule add not fwmark "$WG_FWMARK" lookup 51820 priority 5020
fi

# -----------------------------------------------------------------------------
# 5. Configure explicit Split-DNS domain routing via systemd-resolved
# -----------------------------------------------------------------------------
if [ "$SPLIT_DNS_ENABLED" = "1" ]; then
	# Warn if tunnel has no DNS servers configured
	TUNNEL_DNS=$(resolvectl dns "$IFACE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ' || true)
	if [ -z "$TUNNEL_DNS" ]; then
		echo "WARN: [system-vpn-post-up] Tunnel interface '$IFACE' has no DNS servers configured! Global DNS (~.) may fail." >&2
	fi

	# Pin WireGuard interface as the exclusive global DNS routing path (~.)
	resolvectl domain "$IFACE" '~.'
	resolvectl default-route "$IFACE" yes
	resolvectl default-route "$PHYS_IFACE" no

	# Route local domains (~local, ~lan, local PTR) to the physical LAN link
	if [ -n "$SPLIT_DNS_DOMAINS" ]; then
		# shellcheck disable=SC2086
		resolvectl domain "$PHYS_IFACE" $SPLIT_DNS_DOMAINS
	fi
fi
