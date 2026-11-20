#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-${1:-wg-system}}"
PHYS_IFACE="${PHYS_IFACE:-${2:-eno1}}"
BYPASS_GROUP="${BYPASS_GROUP:-${3:-vpn-bypass}}"
UNIT="wg-quick-${IFACE}.service"

# Terminal formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}=== System VPN Status (${IFACE}) ===${RESET}"

# 1. Service state
if systemctl is-active --quiet "$UNIT"; then
  SERVICE_STATUS="${GREEN}active (running)${RESET}"
else
  SERVICE_STATUS="${RED}inactive / stopped${RESET}"
fi
echo -e "Service (${UNIT}): ${SERVICE_STATUS}"

# 2. Interface details & Handshake
if ip link show "$IFACE" >/dev/null 2>&1; then
  echo -e "Tunnel Interface:       ${GREEN}UP${RESET} (${IFACE})"

  PEER_INFO=$(wg show "$IFACE" 2>/dev/null || true)
  if [ -n "$PEER_INFO" ]; then
    ENDPOINT=$(echo "$PEER_INFO" | grep "endpoint:" | head -n 1 | awk '{print $2}' || true)
    LATEST_HS=$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
    TRANSFER=$(echo "$PEER_INFO" | grep "transfer:" | head -n 1 | sed 's/.*transfer:[[:space:]]*//' || true)

    NOW=$(date +%s)
    if [ -n "$LATEST_HS" ] && [ "$LATEST_HS" -gt 0 ]; then
      DIFF=$((NOW - LATEST_HS))
      if [ "$DIFF" -lt 150 ]; then
        HS_STR="${GREEN}${DIFF}s ago${RESET}"
      else
        HS_STR="${YELLOW}${DIFF}s ago (stale)${RESET}"
      fi
    else
      HS_STR="${RED}never / none${RESET}"
    fi

    echo -e "WireGuard Endpoint:     ${ENDPOINT:-none}"
    echo -e "Latest Handshake:       ${HS_STR}"
    echo -e "Transfer (Rx / Tx):     ${TRANSFER:-none}"
  fi
else
  echo -e "Tunnel Interface:       ${RED}DOWN / NOT FOUND${RESET}"
fi

# 3. Public IP verification
echo -e "\n${BOLD}${CYAN}--- Public IP Verification ---${RESET}"
VPN_IP=$(curl -s --max-time 3 https://ipinfo.io/ip 2>/dev/null || true)
if [ -n "$VPN_IP" ]; then
  VPN_LOC=$(curl -s --max-time 3 "https://ipinfo.io/${VPN_IP}/country" 2>/dev/null || true)
  echo -e "Egress Public IP:       ${GREEN}${VPN_IP}${RESET} (${VPN_LOC:-Unknown})"
else
  echo -e "Egress Public IP:       ${RED}FAILED (No Internet via VPN)${RESET}"
fi

# 4. Firewall & Killswitch statistics
echo -e "\n${BOLD}${CYAN}--- Firewall & Killswitch ---${RESET}"
if iptables -L vpn-killswitch -n >/dev/null 2>&1; then
  DROPS=$(iptables -L vpn-killswitch -v -n 2>/dev/null | grep -i REJECT | awk '{print $1 " packets (" $2 " bytes)"}' || echo "0 packets")
  echo -e "Killswitch Chain:       ${GREEN}ACTIVE${RESET} (Default Deny on ${PHYS_IFACE})"
  echo -e "Blocked Leaks (REJECT): ${YELLOW}${DROPS}${RESET}"
else
  echo -e "Killswitch Chain:       ${RED}NOT LOADED${RESET}"
fi

# 5. Split-Tunnel Bypass
echo -e "\n${BOLD}${CYAN}--- Split-Tunneling ---${RESET}"
if [ -n "$BYPASS_GROUP" ]; then
  if getent group "$BYPASS_GROUP" >/dev/null 2>&1; then
    echo -e "Bypass Group:           ${GREEN}${BYPASS_GROUP}${RESET} (use 'vpn-bypass <cmd>' to route direct via ${PHYS_IFACE})"
  fi
fi

# 6. Watchdog status
WATCHDOG_TIMER="${IFACE}-watchdog.timer"
if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
  echo -e "Watchdog Timer:         ${GREEN}ACTIVE${RESET} (${WATCHDOG_TIMER})"
fi

echo -e "${BOLD}${CYAN}===================================${RESET}"
