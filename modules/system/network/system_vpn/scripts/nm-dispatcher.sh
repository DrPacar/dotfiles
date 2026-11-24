#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: NetworkManager Split-DNS Dispatcher
# =============================================================================
#
# Purpose:
#   Prevents NetworkManager from resetting DefaultRoute=yes or overwriting
#   Split-DNS domains on the physical interface during DHCP lease renewals.
# =============================================================================

: "${PHYS_IFACE:?PHYS_IFACE is required}"
SPLIT_DNS_ENABLED="${SPLIT_DNS_ENABLED:-0}"
SPLIT_DNS_DOMAINS="${SPLIT_DNS_DOMAINS:-}"

IFACE_ARG="${1:-}"
ACTION="${2:-}"

if [ "$IFACE_ARG" != "$PHYS_IFACE" ]; then
	exit 0
fi

case "$ACTION" in
up | dhcp4-change | dhcp6-change)
	resolvectl default-route "$PHYS_IFACE" no 2>/dev/null || true
	if [ "$SPLIT_DNS_ENABLED" = "1" ] && [ -n "$SPLIT_DNS_DOMAINS" ]; then
		# shellcheck disable=SC2086
		resolvectl domain "$PHYS_IFACE" $SPLIT_DNS_DOMAINS 2>/dev/null || true
	fi
	;;
esac
