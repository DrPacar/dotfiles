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

print_kv() {
	printf "%-24s%b\n" "$1:" "$2"
}

# Read named nftables counter (exits 1 if table or counter is not loaded)
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

	check_rule() {
		local rules="$1"
		local desc="$2"
		local pattern="$3"
		if echo "$rules" | grep -qE "$pattern"; then
			run_check "$desc" 0
		else
			run_check "$desc" 1 "rule missing"
		fi
	}

	check_table_51820() {
		local fam="$1"
		local fam_label="$2"
		if ip "$fam" route show table 51820 2>/dev/null | grep -qE "default.*dev[[:space:]]+$IFACE"; then
			run_check "Routing table 51820 contains $fam_label default route via $IFACE" 0
		else
			run_check "Routing table 51820 contains $fam_label default route via $IFACE" 1 "$fam_label default route missing"
		fi
	}

	check_rpdb_family() {
		local fam_label="$1"
		local rules="$2"
		local ts_net="$3"

		check_rule "$rules" "RPDB $fam_label Priority 4990 (bypass mark $BYPASS_MARK -> table main)" \
			"^4990:[[:space:]]+.*fwmark[[:space:]]+${BYPASS_MARK}[[:space:]]+lookup[[:space:]]+main"

		if [ "$TAILSCALE_ENABLED" = "1" ]; then
			check_rule "$rules" "RPDB $fam_label Priority 4991 (Tailscale mark $TAILSCALE_FWMARK -> table main)" \
				"^4991:[[:space:]]+.*fwmark[[:space:]]+${TAILSCALE_FWMARK}[[:space:]]+lookup[[:space:]]+main"
		fi

		check_rule "$rules" "RPDB $fam_label Priority 4992 (bypass unreachable catch)" \
			"^4992:[[:space:]]+.*fwmark[[:space:]]+${BYPASS_MARK}[[:space:]]+unreachable"

		check_rule "$rules" "RPDB $fam_label Priority 5000 (LAN suppress_prefixlength 0)" \
			"^5000:[[:space:]]+.*lookup[[:space:]]+main[[:space:]]+suppress_prefixlength[[:space:]]+0"

		if [ "$TAILSCALE_ENABLED" = "1" ]; then
			check_rule "$rules" "RPDB $fam_label Priority 5010 (Tailscale CGNAT to -> table 52)" \
				"^5010:[[:space:]]+.*to[[:space:]]+${ts_net}[[:space:]]+lookup[[:space:]]+52"
			check_rule "$rules" "RPDB $fam_label Priority 5011 (Tailscale CGNAT from -> table 52)" \
				"^5011:[[:space:]]+.*from[[:space:]]+${ts_net}[[:space:]]+lookup[[:space:]]+52"
		fi

		check_rule "$rules" "RPDB $fam_label Priority 5020 (default internet -> table 51820)" \
			"^5020:[[:space:]]+.*not[[:space:]]+.*fwmark[[:space:]]+${WG_FWMARK}[[:space:]]+lookup[[:space:]]+51820"
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

	# Check 3: WireGuard routing table 51820 default routes (IPv4 & IPv6)
	check_table_51820 -4 "IPv4"
	if [ -e /proc/net/if_inet6 ]; then
		check_table_51820 -6 "IPv6"
	fi

	# Check 4 & 5: IPv4 & IPv6 RPDB Policy routing rules
	local RULES_V4
	RULES_V4=$(ip rule show)
	check_rpdb_family "IPv4" "$RULES_V4" "100.64.0.0/10"

	if [ -e /proc/net/if_inet6 ]; then
		local RULES_V6
		RULES_V6=$(ip -6 rule show 2>/dev/null || true)
		check_rpdb_family "IPv6" "$RULES_V6" "fd7a:115c:a1e0::/48"
	fi

	# Check 6: Split-DNS scoping
	if [ "$SPLIT_DNS_ENABLED" = "1" ] && command -v resolvectl >/dev/null 2>&1; then
		local WG_DOMAINS WG_DNS PHYS_DEFROUTE
		WG_DOMAINS=$(resolvectl domain "$IFACE" 2>/dev/null || true)
		if echo "$WG_DOMAINS" | grep -qF "~."; then
			run_check "systemd-resolved global domain scope (~.) on $IFACE" 0
		else
			run_check "systemd-resolved global domain scope (~.) on $IFACE" 1 "missing ~."
		fi

		WG_DNS=$(resolvectl dns "$IFACE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' ' || true)
		if [ -n "$WG_DNS" ]; then
			run_check "systemd-resolved active DNS servers on $IFACE" 0
		else
			run_check "systemd-resolved active DNS servers on $IFACE" 1 "no DNS configured on tunnel"
		fi

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
	curl --connect-timeout 1 -m 2 -sSf --interface "if!$PHYS_IFACE" https://1.1.1.1 >/dev/null 2>&1 || CURL_CODE=$?

	local FINAL_DROPS DIFF
	FINAL_DROPS=$(get_nft_counter "killswitch_reject" 2>/dev/null || echo "$INIT_DROPS")
	DIFF=$((FINAL_DROPS - INIT_DROPS))

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
# Subcommand: Live Status Dashboard
# -----------------------------------------------------------------------------
do_status() {
	local FAST_MODE=0
	local IP_LOOKUP=1
	for arg in "$@"; do
		case "$arg" in
		--fast)
			FAST_MODE=1
			IP_LOOKUP=0
			;;
		--no-ip)
			IP_LOOKUP=0
			;;
		esac
	done

	echo -e "${BOLD}${CYAN}=== System VPN Status (${IFACE}) ===${RESET}"

	if [ "$EUID" -ne 0 ] && [ -z "$SUDO" ]; then
		echo -e "${YELLOW}Notice: Running unprivileged. Detailed WireGuard peer telemetry and firewall counters require root/sudo.${RESET}\n"
	fi

	# 1. Systemd Service State
	local SERVICE_STATUS
	if systemctl is-active --quiet "$UNIT"; then
		SERVICE_STATUS="${GREEN}active (running)${RESET}"
	else
		SERVICE_STATUS="${RED}inactive / stopped${RESET}"
	fi
	echo -e "Service (${UNIT}): ${SERVICE_STATUS}"

	# 2. Interface State & Cryptographic Handshake Telemetry
	if ip link show dev "$IFACE" up 2>/dev/null | grep -q .; then
		print_kv "Tunnel Interface" "${GREEN}UP${RESET} (${IFACE})"

		local PEER_INFO
		PEER_INFO=$($SUDO wg show "$IFACE" 2>/dev/null || true)
		if [ -n "$PEER_INFO" ]; then
			local ENDPOINT LATEST_HS TRANSFER NOW DIFF HS_STR
			ENDPOINT=$(echo "$PEER_INFO" | awk '/endpoint:/ {print $2; exit}' || true)
			LATEST_HS=$($SUDO wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
			TRANSFER=$(echo "$PEER_INFO" | sed -n 's/.*transfer:[[:space:]]*//p' | head -n 1 || true)

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

			print_kv "WireGuard Endpoint" "${ENDPOINT:-none}"
			print_kv "Latest Handshake" "${HS_STR}"
			print_kv "Transfer (Rx / Tx)" "${TRANSFER:-none}"
		fi
	else
		print_kv "Tunnel Interface" "${RED}DOWN / NOT FOUND${RESET}"
	fi

	# 3. Public Egress IP Verification
	if [ "$FAST_MODE" -eq 0 ] && [ "$IP_LOOKUP" -eq 1 ]; then
		echo -e "\n${BOLD}${CYAN}--- Public IP Verification ---${RESET}"
		local IP_JSON
		IP_JSON=$(curl --connect-timeout 2 -m 3 -s https://ipinfo.io/json 2>/dev/null || true)
		if [ -n "$IP_JSON" ]; then
			local VPN_IP VPN_COUNTRY VPN_CITY
			VPN_IP=$(echo "$IP_JSON" | jq -r '.ip // empty' 2>/dev/null || true)
			VPN_COUNTRY=$(echo "$IP_JSON" | jq -r '.country // empty' 2>/dev/null || true)
			VPN_CITY=$(echo "$IP_JSON" | jq -r '.city // empty' 2>/dev/null || true)
			print_kv "Egress Public IP" "${GREEN}${VPN_IP:-Unknown}${RESET} (${VPN_CITY:+$VPN_CITY, }${VPN_COUNTRY:-Unknown})"
		else
			print_kv "Egress Public IP" "${YELLOW}UNAVAILABLE (offline or rate-limited)${RESET}"
		fi
	fi

	# 4. Firewall & Killswitch Telemetry
	echo -e "\n${BOLD}${CYAN}--- Firewall & Killswitch ---${RESET}"
	if [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
		local OUTPUT_DROPS FORWARD_DROPS
		if OUTPUT_DROPS=$(get_nft_counter "killswitch_reject"); then
			FORWARD_DROPS=$(get_nft_counter "forward_killswitch_reject" 2>/dev/null || echo 0)
			print_kv "Killswitch Engine" "${GREEN}nftables (inet system-vpn)${RESET}"
			print_kv "Killswitch Status" "${GREEN}ACTIVE${RESET} (Default Deny)"
			print_kv "Blocked Output Leaks" "${YELLOW}${OUTPUT_DROPS} packets${RESET}"
			print_kv "Blocked Forward Leaks" "${YELLOW}${FORWARD_DROPS} packets${RESET}"
		else
			print_kv "Killswitch Status" "${RED}NOT LOADED${RESET}"
		fi
	else
		print_kv "Killswitch Status" "${YELLOW}UNKNOWN${RESET} (requires root/sudo privileges to read nftables)"
	fi

	# 5. Split-Tunneling & Split-DNS Telemetry
	echo -e "\n${BOLD}${CYAN}--- Split-Tunneling & DNS ---${RESET}"
	local HAS_BYPASS=0
	if [ -n "$BYPASS_GROUP" ] && getent group "$BYPASS_GROUP" >/dev/null 2>&1; then
		print_kv "Bypass Group" "${GREEN}${BYPASS_GROUP}${RESET} (use 'system-vpn bypass <cmd>' to route direct via ${PHYS_IFACE})"
		HAS_BYPASS=1
	fi
	if [ -n "${BYPASS_SERVICES:-}" ]; then
		print_kv "Bypass Services" "${GREEN}${BYPASS_SERVICES}${RESET} (primary GID bypass)"
		HAS_BYPASS=1
	fi
	if [ "${SPLIT_DNS_ENABLED:-0}" = "1" ] && command -v resolvectl >/dev/null 2>&1; then
		local RESOLV_DOMAINS
		RESOLV_DOMAINS=$(resolvectl domain "$PHYS_IFACE" 2>/dev/null | awk -F': ' '{print $2}' || true)
		if [ -n "$RESOLV_DOMAINS" ]; then
			print_kv "Split-DNS (${PHYS_IFACE})" "${GREEN}${RESOLV_DOMAINS}${RESET} (LAN routed)"
			HAS_BYPASS=1
		fi
	fi
	if [ "$HAS_BYPASS" -eq 0 ]; then
		print_kv "Split-Tunneling" "${YELLOW}none configured${RESET}"
	fi

	# 6. Autonomous Health Watchdog
	local WATCHDOG_TIMER="${IFACE}-watchdog.timer"
	if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
		print_kv "Watchdog Timer" "${GREEN}ACTIVE${RESET} (${WATCHDOG_TIMER})"
	fi

	echo -e "${BOLD}${CYAN}===================================${RESET}"
}

# -----------------------------------------------------------------------------
# Dispatch Subcommands
# -----------------------------------------------------------------------------
case "${1:-status}" in
check | selftest | test)
	do_selftest
	;;
status)
	shift || true
	do_status "$@"
	;;
*)
	do_status "$@"
	;;
esac
