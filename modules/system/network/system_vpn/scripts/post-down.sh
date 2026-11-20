#!/usr/bin/env bash
set -euo pipefail

PHYS_IFACE="${1:-}"
TAILSCALE_ENABLED="${2:-0}"
TAILSCALE_IFACE="${3:-tailscale0}"

ip rule del fwmark 0x5200 lookup main priority 4990 2>/dev/null || true
ip rule del lookup main suppress_prefixlength 0 priority 5000 2>/dev/null || true
ip rule del to 100.64.0.0/10 lookup 52 priority 5010 2>/dev/null || true
ip rule del from 100.64.0.0/10 lookup 52 priority 5011 2>/dev/null || true
ip rule del not fwmark 0xca6c lookup 51820 priority 5020 2>/dev/null || true

if [ "$TAILSCALE_ENABLED" = "1" ]; then
  ip route del 100.64.0.0/10 dev "$TAILSCALE_IFACE" 2>/dev/null || true
fi

ip -6 rule del fwmark 0x5200 lookup main priority 4990 2>/dev/null || true
ip -6 rule del lookup main suppress_prefixlength 0 priority 5000 2>/dev/null || true
ip -6 rule del to fd7a:115c:a1e0::/48 lookup 52 priority 5010 2>/dev/null || true
ip -6 rule del from fd7a:115c:a1e0::/48 lookup 52 priority 5011 2>/dev/null || true
ip -6 rule del not fwmark 0xca6c lookup 51820 priority 5020 2>/dev/null || true

if [ -f /run/system-vpn/endpoints ]; then
  while IFS= read -r ip; do
    if [ -n "$ip" ] && [ -n "$PHYS_IFACE" ]; then
      ip route del "$ip/32" dev "$PHYS_IFACE" 2>/dev/null || true
    fi
  done </run/system-vpn/endpoints
  rm -f /run/system-vpn/endpoints
fi
