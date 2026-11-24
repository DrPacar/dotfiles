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
# Policy Routing Hierarchy (IPv4 & IPv6):
#   Priority 4990:      fwmark 0x5200 -> table main
#                       Traffic marked for bypass routes directly via physical gateway.
#   Priority 4991:      fwmark 0x80000/0xff0000 -> table main
#                       Tailscale outer control/peer traffic routes via physical WAN.
#   Priority 4992:      fwmark 0x5200 -> unreachable
#                       Prevents bypassed traffic (e.g. IPv6 without WAN route) from
#                       falling through into table 51820.
#   Priority 5000:      lookup main suppress_prefixlength 0
#                       Directly-connected local LAN subnets and host routes (prefix > 0).
#   Priority 5010/5011: to/from Tailscale CGNAT -> table 52
#                       Tailscale mesh overlay traffic directed to Tailscale engine.
#   Priority 5020:      not fwmark 0xca6c -> table 51820
#                       All other general outbound internet traffic into WireGuard VPN.
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
# 2. Clean up auto-generated and stale policy routing rules
# -----------------------------------------------------------------------------
# NOTE: Only delete our own managed priorities (4990-5020). Never delete
# by selector without priority, which would destroy Tailscale's 5210+ rules!
cleanup_family_rules() {
	local fam="$1"

	# Clean auto-generated rules from wg-quick
	while ip "$fam" rule del not fwmark "$WG_FWMARK" lookup 51820 2>/dev/null; do :; done
	while ip "$fam" rule del table main suppress_prefixlength 0 2>/dev/null; do :; done

	# Clean only our own managed priorities
	for prio in 4990 4991 4992 5000 5010 5011 5020; do
		while ip "$fam" rule del priority "$prio" 2>/dev/null; do :; done
	done
}

# -----------------------------------------------------------------------------
# 3. Install deterministic IPv4 & IPv6 policy routing rules (fail fast on error)
# -----------------------------------------------------------------------------
install_family_rules() {
	local fam="$1"
	local ts_net="$2"

	# Priority 4990: Process / service split-tunnel bypass
	ip "$fam" rule add fwmark "$BYPASS_MARK" lookup main priority 4990

	# Priority 4991: Tailscale outer encapsulation & control traffic direct via WAN
	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		ip "$fam" rule add fwmark "$TAILSCALE_FWMARK" lookup main priority 4991
	fi

	# Priority 4992: Unreachable catch prevents bypassed traffic from falling into table 51820
	ip "$fam" rule add fwmark "$BYPASS_MARK" unreachable priority 4992

	# Priority 5000: LAN subnets and local routes take precedence over VPN
	ip "$fam" rule add lookup main suppress_prefixlength 0 priority 5000

	# Priority 5010/5011: Tailscale overlay network
	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		ip "$fam" rule add to "$ts_net" lookup 52 priority 5010
		ip "$fam" rule add from "$ts_net" lookup 52 priority 5011
		ip "$fam" route add "$ts_net" dev "$TAILSCALE_IFACE" 2>/dev/null || true
	fi

	# Priority 5020: General host internet traffic default to WireGuard
	ip "$fam" rule add not fwmark "$WG_FWMARK" lookup 51820 priority 5020
}

for fam in -4 -6; do
	if [ "$fam" = "-6" ] && [ ! -e /proc/net/if_inet6 ]; then
		continue
	fi

	cleanup_family_rules "$fam"

	if [ "$fam" = "-4" ]; then
		install_family_rules "$fam" "100.64.0.0/10"
	else
		install_family_rules "$fam" "fd7a:115c:a1e0::/48"
	fi
done

# -----------------------------------------------------------------------------
# 4. Configure explicit Split-DNS domain routing via systemd-resolved
# -----------------------------------------------------------------------------
if [ "$SPLIT_DNS_ENABLED" = "1" ]; then
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
