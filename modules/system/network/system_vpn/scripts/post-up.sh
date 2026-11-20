#!/usr/bin/env bash
set -euo pipefail

TAILSCALE_ENABLED="${1:-0}"
TAILSCALE_IFACE="${2:-tailscale0}"

# Clean up auto-generated wg-quick IPv4 rules
while ip rule del not fwmark 0xca6c lookup 51820 2>/dev/null; do :; done
while ip rule del table main suppress_prefixlength 0 2>/dev/null; do :; done
while ip rule del to 100.64.0.0/10 lookup 52 2>/dev/null; do :; done
while ip rule del from 100.64.0.0/10 lookup 52 2>/dev/null; do :; done
while ip rule del fwmark 0x5200 lookup main 2>/dev/null; do :; done

# Clean up auto-generated wg-quick IPv6 rules
while ip -6 rule del not fwmark 0xca6c lookup 51820 2>/dev/null; do :; done
while ip -6 rule del table main suppress_prefixlength 0 2>/dev/null; do :; done
while ip -6 rule del to fd7a:115c:a1e0::/48 lookup 52 2>/dev/null; do :; done
while ip -6 rule del from fd7a:115c:a1e0::/48 lookup 52 2>/dev/null; do :; done
while ip -6 rule del fwmark 0x5200 lookup main 2>/dev/null; do :; done

# Install deterministic IPv4 rules in strict order:
# 1. VPN bypass group traffic routes direct via main table default gateway
ip rule add fwmark 0x5200 lookup main priority 4990 2>/dev/null || true
# 2. Main table routes with non-zero prefix length (LAN, host routes like VPN endpoints)
ip rule add lookup main suppress_prefixlength 0 priority 5000 2>/dev/null || true
# 3. Tailscale overlay traffic (CGNAT range 100.64.0.0/10)
ip rule add to 100.64.0.0/10 lookup 52 priority 5010 2>/dev/null || true
ip rule add from 100.64.0.0/10 lookup 52 priority 5011 2>/dev/null || true
if [ "$TAILSCALE_ENABLED" = "1" ]; then
  ip route add 100.64.0.0/10 dev "$TAILSCALE_IFACE" 2>/dev/null || true
fi
# 4. WireGuard system VPN default route for all other egress
ip rule add not fwmark 0xca6c lookup 51820 priority 5020 2>/dev/null || true

# Install deterministic IPv6 rules:
ip -6 rule add fwmark 0x5200 lookup main priority 4990 2>/dev/null || true
ip -6 rule add lookup main suppress_prefixlength 0 priority 5000 2>/dev/null || true
ip -6 rule add to fd7a:115c:a1e0::/48 lookup 52 priority 5010 2>/dev/null || true
ip -6 rule add from fd7a:115c:a1e0::/48 lookup 52 priority 5011 2>/dev/null || true
ip -6 rule add not fwmark 0xca6c lookup 51820 priority 5020 2>/dev/null || true
