#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Post-Up Namespace Hardening, Direct Egress Mark & DNS Setup
# =============================================================================
#
# Purpose:
#   1. Sets the WireGuard kernel fwmark on WG_IFACE when directPhysicalEgress is
#      enabled, routing the encrypted outer UDP socket directly over the
#      physical NIC instead of nesting inside system_vpn.
#   2. Ensures the internal VPN gateway / resolver IP routes via WG_IFACE.
#   3. Permits configured fallback DNS servers in dns-fw and appends them after
#      the provider DNS in /etc/netns/<namespace>/resolv.conf.
#
# Execution Context:
#   Invoked by systemd ExecStartPost in `${NAMESPACE}.service`.
# =============================================================================

: "${NAMESPACE:?NAMESPACE environment variable is required}"
: "${WG_IFACE:?WG_IFACE environment variable is required}"
: "${GATEWAY:?GATEWAY environment variable is required}"
WG_FWMARK="${WG_FWMARK:-}"
FALLBACK_DNS="${FALLBACK_DNS:-}"
TCP_CONGESTION_CONTROL="${TCP_CONGESTION_CONTROL:-cubic}"
TCP_MTU_PROBING="${TCP_MTU_PROBING:-0}"
TCP_FASTOPEN="${TCP_FASTOPEN:-1}"

# -----------------------------------------------------------------------------
# 1. Apply outer socket fwmark for direct physical egress (no nested VPN)
# -----------------------------------------------------------------------------
if [ -n "$WG_FWMARK" ]; then
	ip netns exec "$NAMESPACE" wg set "$WG_IFACE" fwmark "$WG_FWMARK"
	ACTUAL_FWMARK=$(ip netns exec "$NAMESPACE" wg show "$WG_IFACE" fwmark 2>/dev/null || true)
	if [ "$ACTUAL_FWMARK" != "$WG_FWMARK" ]; then
		echo "ERROR: [arr-vpn-post-up] Interface '$WG_IFACE' in netns '$NAMESPACE' has fwmark '$ACTUAL_FWMARK', expected '$WG_FWMARK'." >&2
		exit 1
	fi
fi

# -----------------------------------------------------------------------------
# 2. Ensure internal VPN gateway routes via tunnel, clamp MSS & apply TCP tuning
# -----------------------------------------------------------------------------
ip -n "$NAMESPACE" route replace "${GATEWAY}/32" dev "$WG_IFACE"
ip netns exec "$NAMESPACE" iptables -t mangle -C POSTROUTING -o "$WG_IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null ||
	ip netns exec "$NAMESPACE" iptables -t mangle -A POSTROUTING -o "$WG_IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
if [ -e /proc/net/if_inet6 ]; then
	ip netns exec "$NAMESPACE" ip6tables -t mangle -C POSTROUTING -o "$WG_IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null ||
		ip netns exec "$NAMESPACE" ip6tables -t mangle -A POSTROUTING -o "$WG_IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
fi

# Mirror host TCP congestion control, MTU probing, and Fast Open into the netns
# (Linux resets per-namespace net.ipv4.tcp_* sysctls to kernel defaults).
ip netns exec "$NAMESPACE" sysctl -qw \
	"net.ipv4.tcp_congestion_control=${TCP_CONGESTION_CONTROL}" \
	"net.ipv4.tcp_mtu_probing=${TCP_MTU_PROBING}" \
	"net.ipv4.tcp_fastopen=${TCP_FASTOPEN}" || true

# -----------------------------------------------------------------------------
# 3. Allow fallback DNS in dns-fw and configure namespace resolv.conf
# -----------------------------------------------------------------------------
RESOLV_FILE="/etc/netns/${NAMESPACE}/resolv.conf"

if [ -n "$FALLBACK_DNS" ]; then
	read -ra fallback_dns_list <<<"$FALLBACK_DNS"
	for dns_ip in "${fallback_dns_list[@]}"; do
		if [[ $dns_ip == *:* ]]; then
			for proto in udp tcp; do
				if ! ip netns exec "$NAMESPACE" ip6tables -C dns-fw -p "$proto" -d "$dns_ip" -j ACCEPT 2>/dev/null; then
					ip netns exec "$NAMESPACE" ip6tables -I dns-fw 1 -p "$proto" -d "$dns_ip" -j ACCEPT
				fi
			done
		else
			for proto in udp tcp; do
				if ! ip netns exec "$NAMESPACE" iptables -C dns-fw -p "$proto" -d "$dns_ip" -j ACCEPT 2>/dev/null; then
					ip netns exec "$NAMESPACE" iptables -I dns-fw 1 -p "$proto" -d "$dns_ip" -j ACCEPT
				fi
			done
		fi

		if [ -f "$RESOLV_FILE" ] && ! grep -qxF "nameserver ${dns_ip}" "$RESOLV_FILE"; then
			echo "nameserver ${dns_ip}" >>"$RESOLV_FILE"
		fi
	done
fi
