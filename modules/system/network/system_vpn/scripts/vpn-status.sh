#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Diagnostic CLI Dashboard & Telemetry Status
# =============================================================================
#
# Purpose:
#   Collects, formats, and displays real-time health and telemetry metrics for
#   the system WireGuard VPN, nftables killswitch filter, split-tunneling bypass,
#   Split-DNS routing scopes, and connectivity watchdog.
#
# Execution Context:
#   Invoked via `system-vpn status`, `system-vpn check`, or `system-vpn`.
# =============================================================================

: "${IFACE:?IFACE environment variable is required}"
: "${PHYS_IFACE:?PHYS_IFACE environment variable is required}"
: "${WG_FWMARK:?WG_FWMARK environment variable is required}"
: "${BYPASS_MARK:?BYPASS_MARK environment variable is required}"
: "${TAILSCALE_FWMARK:?TAILSCALE_FWMARK environment variable is required}"
: "${TAILSCALE_ENABLED:?TAILSCALE_ENABLED environment variable is required}"
: "${SPLIT_DNS_ENABLED:?SPLIT_DNS_ENABLED environment variable is required}"
BYPASS_GROUP="${BYPASS_GROUP:-}"
UNIT="wg-quick-${IFACE}.service"

# Privilege helper (leverages passwordless sudo if available)
SUDO=""
if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
	if sudo -n true 2>/dev/null; then
		SUDO="sudo"
	fi
fi

# Terminal ANSI color formatting (only when stdout is a TTY)
if [ -t 1 ]; then
	BOLD="\033[1m"
	GREEN="\033[0;32m"
	RED="\033[0;31m"
	YELLOW="\033[0;33m"
	CYAN="\033[0;36m"
	RESET="\033[0m"
else
	BOLD=""
	GREEN=""
	RED=""
	YELLOW=""
	CYAN=""
	RESET=""
fi

# Helper to read named nftables counter (exits 1 if table or counter is not loaded)
get_nft_counter() {
	local counter_name="$1"
	if [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
		$SUDO nft list counter inet system-vpn "$counter_name" 2>/dev/null |
			awk '/packets/ {print $2; ok=1} END {exit !ok}'
	else
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Subcommand: Automated Verification Self-Test
# -----------------------------------------------------------------------------
do_selftest() {
	if [ "$EUID" -ne 0 ] && [ -z "$SUDO" ]; then
		echo -e "${RED}[ERROR]${RESET} 'system-vpn check' requires root privileges to query WireGuard fwmark and nftables counters." >&2
		echo -e "Please run with: sudo system-vpn check" >&2
		exit 1
	fi

	echo -e "${BOLD}${CYAN}=== System VPN Self-Test (${IFACE}) ===${RESET}"
	local TOTAL_COUNT=0
	local PASS_COUNT=0
	local FAIL_COUNT=0

	run_check() {
		local desc="$1"
		local status="$2"
		local fail_msg="${3:-}"
		TOTAL_COUNT=$((TOTAL_COUNT + 1))
		if [ "$status" -eq 0 ]; then
			echo -e "  ${GREEN}[PASS]${RESET} $desc"
			PASS_COUNT=$((PASS_COUNT + 1))
		else
			echo -e "  ${RED}[FAIL]${RESET} $desc ${fail_msg:+($fail_msg)}"
			FAIL_COUNT=$((FAIL_COUNT + 1))
		fi
	}

	# Check 1: Interface UP
	if ip link show dev "$IFACE" up 2>/dev/null | grep -q .; then
		run_check "Tunnel interface $IFACE exists and is UP" 0
	else
		run_check "Tunnel interface $IFACE exists and is UP" 1 "interface DOWN or missing"
	fi

	# Check 2: WireGuard kernel fwmark
	local FWMARK
	FWMARK=$($SUDO wg show "$IFACE" fwmark 2>/dev/null || true)
	if [ "$FWMARK" = "$WG_FWMARK" ]; then
		run_check "WireGuard kernel fwmark is valid ($FWMARK)" 0
	else
		run_check "WireGuard kernel fwmark is valid" 1 "found '$FWMARK', expected '$WG_FWMARK'"
	fi

	# Check 3: WireGuard routing table 51820 default route
	if ip route show table 51820 2>/dev/null | grep -qE "default.*dev[[:space:]]+$IFACE"; then
		run_check "Routing table 51820 contains default route via $IFACE" 0
	else
		run_check "Routing table 51820 contains default route via $IFACE" 1 "default route missing"
	fi

	# Check 4: IPv4 RPDB Policy routing rules (anchored checks)
	local RULES_V4
	RULES_V4=$(ip rule show)

	if echo "$RULES_V4" | grep -qE "^4990:[[:space:]]+.*fwmark[[:space:]]+${BYPASS_MARK}[[:space:]]+lookup[[:space:]]+main"; then
		run_check "RPDB IPv4 Priority 4990 (bypass mark $BYPASS_MARK -> table main)" 0
	else
		run_check "RPDB IPv4 Priority 4990 (bypass mark $BYPASS_MARK)" 1 "rule missing"
	fi

	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		if echo "$RULES_V4" | grep -qE "^4991:[[:space:]]+.*fwmark[[:space:]]+${TAILSCALE_FWMARK}[[:space:]]+lookup[[:space:]]+main"; then
			run_check "RPDB IPv4 Priority 4991 (Tailscale mark $TAILSCALE_FWMARK -> table main)" 0
		else
			run_check "RPDB IPv4 Priority 4991 (Tailscale mark $TAILSCALE_FWMARK)" 1 "rule missing"
		fi
	fi

	if echo "$RULES_V4" | grep -qE "^5000:[[:space:]]+.*lookup[[:space:]]+main[[:space:]]+suppress_prefixlength[[:space:]]+0"; then
		run_check "RPDB IPv4 Priority 5000 (LAN suppress_prefixlength 0)" 0
	else
		run_check "RPDB IPv4 Priority 5000 (LAN preservation)" 1 "rule missing"
	fi

	if [ "$TAILSCALE_ENABLED" = "1" ]; then
		if echo "$RULES_V4" | grep -qE "^5010:[[:space:]]+.*to[[:space:]]+100.64.0.0/10[[:space:]]+lookup[[:space:]]+52"; then
			run_check "RPDB IPv4 Priority 5010 (Tailscale CGNAT to -> table 52)" 0
		else
			run_check "RPDB IPv4 Priority 5010 (Tailscale CGNAT to)" 1 "rule missing"
		fi
		if echo "$RULES_V4" | grep -qE "^5011:[[:space:]]+.*from[[:space:]]+100.64.0.0/10[[:space:]]+lookup[[:space:]]+52"; then
			run_check "RPDB IPv4 Priority 5011 (Tailscale CGNAT from -> table 52)" 0
		else
			run_check "RPDB IPv4 Priority 5011 (Tailscale CGNAT from)" 1 "rule missing"
		fi
	fi

	if echo "$RULES_V4" | grep -qE "^5020:[[:space:]]+.*not[[:space:]]+.*fwmark[[:space:]]+${WG_FWMARK}[[:space:]]+lookup[[:space:]]+51820"; then
		run_check "RPDB IPv4 Priority 5020 (default internet -> table 51820)" 0
	else
		run_check "RPDB IPv4 Priority 5020 (WireGuard default table)" 1 "rule missing"
	fi

	# Check 5: IPv6 RPDB Policy routing rules (anchored checks, guarded)
	if [ -e /proc/net/if_inet6 ]; then
		local RULES_V6
		RULES_V6=$(ip -6 rule show 2>/dev/null || true)

		if echo "$RULES_V6" | grep -qE "^4990:[[:space:]]+.*fwmark[[:space:]]+${BYPASS_MARK}[[:space:]]+lookup[[:space:]]+main"; then
			run_check "RPDB IPv6 Priority 4990 (bypass mark $BYPASS_MARK -> table main)" 0
		else
			run_check "RPDB IPv6 Priority 4990 (bypass mark $BYPASS_MARK)" 1 "rule missing"
		fi

		if [ "$TAILSCALE_ENABLED" = "1" ]; then
			if echo "$RULES_V6" | grep -qE "^4991:[[:space:]]+.*fwmark[[:space:]]+${TAILSCALE_FWMARK}[[:space:]]+lookup[[:space:]]+main"; then
				run_check "RPDB IPv6 Priority 4991 (Tailscale mark $TAILSCALE_FWMARK -> table main)" 0
			else
				run_check "RPDB IPv6 Priority 4991 (Tailscale mark $TAILSCALE_FWMARK)" 1 "rule missing"
			fi
		fi

		if echo "$RULES_V6" | grep -qE "^5000:[[:space:]]+.*lookup[[:space:]]+main[[:space:]]+suppress_prefixlength[[:space:]]+0"; then
			run_check "RPDB IPv6 Priority 5000 (LAN suppress_prefixlength 0)" 0
		else
			run_check "RPDB IPv6 Priority 5000 (LAN preservation)" 1 "rule missing"
		fi

		if echo "$RULES_V6" | grep -qE "^5020:[[:space:]]+.*not[[:space:]]+.*fwmark[[:space:]]+${WG_FWMARK}[[:space:]]+lookup[[:space:]]+51820"; then
			run_check "RPDB IPv6 Priority 5020 (default internet -> table 51820)" 0
		else
			run_check "RPDB IPv6 Priority 5020 (WireGuard default table)" 1 "rule missing"
		fi
	fi

	# Check 6: Split-DNS scoping
	if [ "$SPLIT_DNS_ENABLED" = "1" ] && command -v resolvectl >/dev/null 2>&1; then
		local WG_DOMAINS
		WG_DOMAINS=$(resolvectl domain "$IFACE" 2>/dev/null || true)
		if echo "$WG_DOMAINS" | grep -qF "~."; then
			run_check "systemd-resolved global domain scope (~.) on $IFACE" 0
		else
			run_check "systemd-resolved global domain scope (~.) on $IFACE" 1 "missing ~."
		fi

		local WG_DNS
		WG_DNS=$(resolvectl dns "$IFACE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ' || true)
		if [ -n "$WG_DNS" ]; then
			run_check "systemd-resolved active DNS servers on $IFACE" 0
		else
			run_check "systemd-resolved active DNS servers on $IFACE" 1 "no DNS configured on tunnel"
		fi

		local PHYS_DEFROUTE
		PHYS_DEFROUTE=$(resolvectl default-route "$PHYS_IFACE" 2>/dev/null | awk -F': ' '{print $2}' || true)
		if echo "$PHYS_DEFROUTE" | grep -qi "no"; then
			run_check "systemd-resolved DefaultRoute disabled on $PHYS_IFACE" 0
		else
			run_check "systemd-resolved DefaultRoute disabled on $PHYS_IFACE" 1 "leaks possible: $PHYS_DEFROUTE"
		fi
	fi

	# Check 7: Physical interface leak prevention (Active Killswitch Reject Probe)
	echo -e "  [*] Probing physical egress on $PHYS_IFACE (testing named counter killswitch_reject)..."
	local INIT_DROPS
	if ! INIT_DROPS=$(get_nft_counter "killswitch_reject"); then
		run_check "Killswitch named counter killswitch_reject accessible" 1 "nftables counter not loaded"
		INIT_DROPS=0
	fi

	# Attempt unencrypted egress via physical NIC (must be immediately rejected by nftables)
	local CURL_CODE=0
	curl --connect-timeout 1 -m 2 -sSf --interface "$PHYS_IFACE" https://1.1.1.1 >/dev/null 2>&1 || CURL_CODE=$?

	local FINAL_DROPS
	FINAL_DROPS=$(get_nft_counter "killswitch_reject" 2>/dev/null || echo "$INIT_DROPS")
	local DIFF=$((FINAL_DROPS - INIT_DROPS))

	if [ "$DIFF" -gt 0 ] && [ "$CURL_CODE" -ne 0 ]; then
		run_check "Killswitch active: unencrypted egress on $PHYS_IFACE was rejected (nft counter +$DIFF)" 0
	else
		run_check "Killswitch active probe on $PHYS_IFACE" 1 "reject counter did not increment (init: $INIT_DROPS, final: $FINAL_DROPS, curl exit: $CURL_CODE)"
	fi

	echo -e "${BOLD}${CYAN}===================================${RESET}"
	if [ "$FAIL_COUNT" -eq 0 ]; then
		echo -e "${GREEN}${BOLD}Self-Test Summary: ALL CHECKS PASSED (${PASS_COUNT}/${TOTAL_COUNT})${RESET}"
		return 0
	else
		echo -e "${RED}${BOLD}Self-Test Summary: ${FAIL_COUNT} CHECKS FAILED (${PASS_COUNT}/${TOTAL_COUNT} passed)${RESET}"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Dispatch Subcommands
# -----------------------------------------------------------------------------
case "${1:-status}" in
check | selftest | test)
	do_selftest
	exit $?
	;;
esac

FAST_MODE=0
IP_LOOKUP=1
for arg in "$@"; do
	if [ "$arg" = "--fast" ]; then
		FAST_MODE=1
		IP_LOOKUP=0
	fi
	if [ "$arg" = "--no-ip" ]; then
		IP_LOOKUP=0
	fi
done

echo -e "${BOLD}${CYAN}=== System VPN Status (${IFACE}) ===${RESET}"

# Privilege notification
if [ "$EUID" -ne 0 ] && [ -z "$SUDO" ]; then
	echo -e "${YELLOW}Notice: Running unprivileged. Detailed WireGuard peer telemetry and firewall counters require root/sudo.${RESET}\n"
fi

# -----------------------------------------------------------------------------
# 1. Systemd Service State
# -----------------------------------------------------------------------------
if systemctl is-active --quiet "$UNIT"; then
	SERVICE_STATUS="${GREEN}active (running)${RESET}"
else
	SERVICE_STATUS="${RED}inactive / stopped${RESET}"
fi
echo -e "Service (${UNIT}): ${SERVICE_STATUS}"

# -----------------------------------------------------------------------------
# 2. Interface State & Cryptographic Handshake Telemetry
# -----------------------------------------------------------------------------
if ip link show dev "$IFACE" up 2>/dev/null | grep -q .; then
	echo -e "Tunnel Interface:       ${GREEN}UP${RESET} (${IFACE})"

	PEER_INFO=$($SUDO wg show "$IFACE" 2>/dev/null || true)
	if [ -n "$PEER_INFO" ]; then
		ENDPOINT=$(echo "$PEER_INFO" | grep "endpoint:" | head -n 1 | awk '{print $2}' || true)
		LATEST_HS=$($SUDO wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
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

# -----------------------------------------------------------------------------
# 3. Public Egress IP Verification (Single JSON request, skippable)
# -----------------------------------------------------------------------------
if [ "$FAST_MODE" -eq 0 ] && [ "$IP_LOOKUP" -eq 1 ]; then
	echo -e "\n${BOLD}${CYAN}--- Public IP Verification ---${RESET}"
	IP_JSON=$(curl --connect-timeout 2 -m 3 -s https://ipinfo.io/json 2>/dev/null || true)
	if [ -n "$IP_JSON" ]; then
		VPN_IP=$(echo "$IP_JSON" | grep -o '"ip": "[^"]*' | cut -d'"' -f4 || true)
		VPN_COUNTRY=$(echo "$IP_JSON" | grep -o '"country": "[^"]*' | cut -d'"' -f4 || true)
		VPN_CITY=$(echo "$IP_JSON" | grep -o '"city": "[^"]*' | cut -d'"' -f4 || true)
		echo -e "Egress Public IP:       ${GREEN}${VPN_IP:-Unknown}${RESET} (${VPN_CITY:+$VPN_CITY, }${VPN_COUNTRY:-Unknown})"
	else
		echo -e "Egress Public IP:       ${YELLOW}UNAVAILABLE (offline or rate-limited)${RESET}"
	fi
fi

# -----------------------------------------------------------------------------
# 4. Firewall & Killswitch Telemetry
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}--- Firewall & Killswitch ---${RESET}"
if [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
	if OUTPUT_DROPS=$(get_nft_counter "killswitch_reject"); then
		FORWARD_DROPS=$(get_nft_counter "forward_killswitch_reject" 2>/dev/null || echo 0)
		echo -e "Killswitch Engine:      ${GREEN}nftables (inet system-vpn)${RESET}"
		echo -e "Killswitch Status:      ${GREEN}ACTIVE${RESET} (Default Deny)"
		echo -e "Blocked Output Leaks:   ${YELLOW}${OUTPUT_DROPS} packets${RESET}"
		echo -e "Blocked Forward Leaks:  ${YELLOW}${FORWARD_DROPS} packets${RESET}"
	else
		echo -e "Killswitch Status:      ${RED}NOT LOADED${RESET}"
	fi
else
	echo -e "Killswitch Status:      ${YELLOW}UNKNOWN${RESET} (requires root/sudo privileges to read nftables)"
fi

# -----------------------------------------------------------------------------
# 5. Split-Tunneling & Split-DNS Telemetry
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}--- Split-Tunneling & DNS ---${RESET}"
HAS_BYPASS=0
if [ -n "$BYPASS_GROUP" ]; then
	if getent group "$BYPASS_GROUP" >/dev/null 2>&1; then
		echo -e "Bypass Group:           ${GREEN}${BYPASS_GROUP}${RESET} (use 'system-vpn bypass <cmd>' to route direct via ${PHYS_IFACE})"
		HAS_BYPASS=1
	fi
fi
if [ -n "${BYPASS_SERVICES:-}" ]; then
	echo -e "Bypass Services:        ${GREEN}${BYPASS_SERVICES}${RESET} (primary GID bypass)"
	HAS_BYPASS=1
fi
if [ "${SPLIT_DNS_ENABLED:-0}" = "1" ] && command -v resolvectl >/dev/null 2>&1; then
	RESOLV_DOMAINS=$(resolvectl domain "$PHYS_IFACE" 2>/dev/null | awk -F': ' '{print $2}' || true)
	if [ -n "$RESOLV_DOMAINS" ]; then
		echo -e "Split-DNS (${PHYS_IFACE}):     ${GREEN}${RESOLV_DOMAINS}${RESET} (LAN routed)"
		HAS_BYPASS=1
	fi
fi
if [ "$HAS_BYPASS" -eq 0 ]; then
	echo -e "Split-Tunneling:        ${YELLOW}none configured${RESET}"
fi

# -----------------------------------------------------------------------------
# 6. Autonomous Health Watchdog
# -----------------------------------------------------------------------------
WATCHDOG_TIMER="${IFACE}-watchdog.timer"
if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
	echo -e "Watchdog Timer:         ${GREEN}ACTIVE${RESET} (${WATCHDOG_TIMER})"
fi

echo -e "${BOLD}${CYAN}===================================${RESET}"
