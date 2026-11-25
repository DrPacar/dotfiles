#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Diagnostic CLI Dashboard & Self-Test Verification
# =============================================================================
#
# Purpose:
#   Collects, formats, and verifies real-time health, direct physical routing
#   (anti-double-VPN check), DNS mount integrity, namespace killswitch counters,
#   and NAT-PMP port forwarding for the BitTorrent VPN namespace.
#
# Execution Context:
#   Invoked via `arr vpn status`, `arr vpn check`, `arr-vpn status`, or
#   `arr-vpn check`.
# =============================================================================

: "${NAMESPACE:?NAMESPACE environment variable is required}"
: "${WG_IFACE:?WG_IFACE environment variable is required}"
: "${GATEWAY:?GATEWAY environment variable is required}"
: "${DIRECT_PHYSICAL_EGRESS:?DIRECT_PHYSICAL_EGRESS environment variable is required}"
: "${SYSTEM_VPN_ENABLED:?SYSTEM_VPN_ENABLED environment variable is required}"
: "${SYSTEM_VPN_IFACE:?SYSTEM_VPN_IFACE environment variable is required}"
: "${PORT_FORWARDING_ENABLED:?PORT_FORWARDING_ENABLED environment variable is required}"
: "${PORT_STATE_FILE:?PORT_STATE_FILE environment variable is required}"
WG_FWMARK="${WG_FWMARK:-}"
PHYS_IFACE="${PHYS_IFACE:-}"
FALLBACK_DNS="${FALLBACK_DNS:-}"

UNIT="${NAMESPACE}.service"
PROXY_UNIT="qbittorrent-webui-proxy.service"
FORWARDER_UNIT="protonvpn-port-forward.service"
WATCHDOG_TIMER="${NAMESPACE}-watchdog.timer"

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
	printf "%-34s%b\n" "$1:" "$2"
}

strip_endpoint_ip() {
	sed -E 's/:[0-9]+$//; s/^\[//; s/\]$//'
}

get_chain_packets() {
	local chain="$1"
	$SUDO ip netns exec "$NAMESPACE" iptables -L "$chain" -v -n -x 2>/dev/null |
		awk '$3 == "DROP" {sum += $1; seen=1} END {if (seen) print sum; else print 0}' || echo 0
}

# -----------------------------------------------------------------------------
# Subcommand: Automated Verification Self-Test
# -----------------------------------------------------------------------------
do_selftest() {
	if [ "$EUID" -ne 0 ] && [ -z "$SUDO" ]; then
		echo -e "${RED}[ERROR]${RESET} 'arr vpn check' requires root privileges to inspect netns '$NAMESPACE', WireGuard fwmark, and iptables counters." >&2
		echo -e "Please run with: sudo arr vpn check" >&2
		exit 1
	fi

	echo -e "${BOLD}${CYAN}=== Arr VPN Self-Test (${NAMESPACE} / ${WG_IFACE}) ===${RESET}"
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

	# Check 1: Namespace & WireGuard interface UP
	if ip netns list 2>/dev/null | awk '{print $1}' | grep -qxF "$NAMESPACE"; then
		run_check "Network namespace '$NAMESPACE' exists" 0
	else
		run_check "Network namespace '$NAMESPACE' exists" 1 "namespace missing"
	fi

	if ip -n "$NAMESPACE" link show dev "$WG_IFACE" up 2>/dev/null | grep -q .; then
		run_check "Tunnel interface $WG_IFACE inside '$NAMESPACE' is UP" 0
	else
		run_check "Tunnel interface $WG_IFACE inside '$NAMESPACE' is UP" 1 "interface DOWN or missing"
	fi

	# Check 2: Direct physical egress (no nested double-VPN)
	if [ "$DIRECT_PHYSICAL_EGRESS" = "1" ] && [ -n "$WG_FWMARK" ]; then
		local ACTUAL_FWMARK
		ACTUAL_FWMARK=$($SUDO ip netns exec "$NAMESPACE" wg show "$WG_IFACE" fwmark 2>/dev/null || true)
		if [ "$ACTUAL_FWMARK" = "$WG_FWMARK" ]; then
			run_check "WireGuard outer socket fwmark is valid ($ACTUAL_FWMARK)" 0
		else
			run_check "WireGuard outer socket fwmark is valid" 1 "found '${ACTUAL_FWMARK:-none}', expected '$WG_FWMARK'"
		fi

		local ENDPOINT_IP ROUTE_OUT ROUTE_DEV
		ENDPOINT_IP=$($SUDO ip netns exec "$NAMESPACE" wg show "$WG_IFACE" endpoints 2>/dev/null | awk '{print $2}' | strip_endpoint_ip | head -n 1 || true)
		if [ -n "$ENDPOINT_IP" ]; then
			ROUTE_OUT=$(ip route get "$ENDPOINT_IP" mark "$WG_FWMARK" 2>/dev/null || true)
			ROUTE_DEV=$(echo "$ROUTE_OUT" | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}' || true)
			if [ -n "$ROUTE_DEV" ] && [ "$ROUTE_DEV" != "$SYSTEM_VPN_IFACE" ]; then
				if [ -n "$PHYS_IFACE" ] && [ "$ROUTE_DEV" != "$PHYS_IFACE" ]; then
					run_check "Endpoint $ENDPOINT_IP routes directly via $PHYS_IFACE (no double-VPN)" 1 "routed via '$ROUTE_DEV'"
				else
					run_check "Endpoint $ENDPOINT_IP routes directly via ${ROUTE_DEV} (no double-VPN)" 0
				fi
			else
				run_check "Endpoint $ENDPOINT_IP bypasses $SYSTEM_VPN_IFACE" 1 "routed via '${ROUTE_DEV:-unknown}'"
			fi
		else
			run_check "WireGuard peer endpoint configured" 1 "no endpoint found"
		fi
	fi

	# Check 3: Default routes & DNS table 51820 inside namespace
	if ip -n "$NAMESPACE" -4 route show default 2>/dev/null | grep -qE "dev[[:space:]]+$WG_IFACE"; then
		run_check "Namespace IPv4 default route goes through $WG_IFACE" 0
	else
		run_check "Namespace IPv4 default route goes through $WG_IFACE" 1 "default route missing"
	fi

	if ip -n "$NAMESPACE" -4 route show table 51820 2>/dev/null | grep -qE "default.*dev[[:space:]]+$WG_IFACE" &&
		ip -n "$NAMESPACE" -4 rule show 2>/dev/null | grep -qE "ipproto[[:space:]]+udp.*dport[[:space:]]+53.*lookup[[:space:]]+51820"; then
		run_check "Namespace DNS policy routing pinned to table 51820 ($WG_IFACE)" 0
	else
		run_check "Namespace DNS policy routing pinned to table 51820 ($WG_IFACE)" 1 "rule or route missing"
	fi

	# Check 4: Namespace killswitch & DNS firewall
	local NS_OUTPUT_RULES
	NS_OUTPUT_RULES=$($SUDO ip netns exec "$NAMESPACE" iptables -S OUTPUT 2>/dev/null || true)
	if echo "$NS_OUTPUT_RULES" | grep -qE -- "-o veth-${NAMESPACE}.*-m conntrack --ctstate NEW -j DROP"; then
		run_check "Namespace killswitch drops new outbound packets on veth-${NAMESPACE}" 0
	else
		run_check "Namespace killswitch drops new outbound packets on veth-${NAMESPACE}" 1 "DROP rule missing"
	fi

	local DNS_LEAK_DROPS
	DNS_LEAK_DROPS=$(get_chain_packets "dns-leak")
	if [ "$DNS_LEAK_DROPS" -eq 0 ]; then
		run_check "Namespace dns-leak chain recorded 0 leaked packets" 0
	else
		run_check "Namespace dns-leak chain recorded 0 leaked packets" 1 "observed $DNS_LEAK_DROPS dropped leak packets"
	fi

	# Check 5: qBittorrent confinement & resolv.conf mount integrity
	local QBIT_PID
	QBIT_PID=$(systemctl show -p MainPID --value qbittorrent.service 2>/dev/null || echo 0)
	if [ "$QBIT_PID" -gt 0 ] && ip netns pids "$NAMESPACE" 2>/dev/null | grep -qxF "$QBIT_PID"; then
		run_check "qbittorrent.service (PID $QBIT_PID) is confined to netns '$NAMESPACE'" 0

		local NS_RESOLV
		NS_RESOLV="/etc/netns/${NAMESPACE}/resolv.conf"
		if [ -f "$NS_RESOLV" ]; then
			if diff -q "$NS_RESOLV" <($SUDO nsenter -t "$QBIT_PID" -m cat /etc/resolv.conf 2>/dev/null) >/dev/null 2>&1; then
				run_check "qBittorrent /etc/resolv.conf matches $NS_RESOLV (not overwritten)" 0
			else
				run_check "qBittorrent /etc/resolv.conf matches $NS_RESOLV" 1 "mount diverged from $NS_RESOLV"
			fi
		fi
	else
		run_check "qbittorrent.service is confined to netns '$NAMESPACE'" 1 "PID=$QBIT_PID not in netns"
	fi

	# Check 6: NAT-PMP Port Forwarding
	if [ "$PORT_FORWARDING_ENABLED" = "1" ]; then
		if [ -f "$PORT_STATE_FILE" ]; then
			local FWD_PORT
			FWD_PORT=$(tr -d '[:space:]' <"$PORT_STATE_FILE" 2>/dev/null || true)
			if [[ $FWD_PORT =~ ^[0-9]+$ ]] &&
				$SUDO ip netns exec "$NAMESPACE" iptables -C INPUT -p tcp --dport "$FWD_PORT" -j ACCEPT 2>/dev/null &&
				$SUDO ip netns exec "$NAMESPACE" iptables -C INPUT -p udp --dport "$FWD_PORT" -j ACCEPT 2>/dev/null; then
				run_check "NAT-PMP port $FWD_PORT open in netns firewall (TCP+UDP)" 0
			else
				run_check "NAT-PMP port $FWD_PORT open in netns firewall" 1 "firewall rule missing"
			fi
		else
			run_check "NAT-PMP forwarded port state exists ($PORT_STATE_FILE)" 1 "no active port lease recorded"
		fi
	fi

	# Check 7: Live tunnel egress probe inside namespace
	local EGRESS_IP
	EGRESS_IP=$($SUDO ip netns exec "$NAMESPACE" curl --connect-timeout 3 -m 5 -sf https://ipinfo.io/ip 2>/dev/null || true)
	if [ -n "$EGRESS_IP" ]; then
		run_check "Live egress connectivity inside '$NAMESPACE' succeeded ($EGRESS_IP)" 0
	else
		run_check "Live egress connectivity inside '$NAMESPACE' succeeded" 1 "curl failed or timed out"
	fi

	echo -e "${BOLD}${CYAN}============================================${RESET}"
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

	echo -e "${BOLD}${CYAN}=== Arr VPN Status (${NAMESPACE} / ${WG_IFACE}) ===${RESET}"

	if [ "$EUID" -ne 0 ] && [ -z "$SUDO" ]; then
		echo -e "${YELLOW}Notice: Running unprivileged. Detailed netns WireGuard telemetry and IP checks require root/sudo.${RESET}\n"
	fi

	# 1. Systemd Service States
	for svc_label_pair in \
		"Namespace Service (${UNIT}):${UNIT}" \
		"qBittorrent Client:qbittorrent.service" \
		"WebUI Proxy:${PROXY_UNIT}" \
		"Port Forwarder:${FORWARDER_UNIT}"; do
		local label="${svc_label_pair%%:*}"
		local svc="${svc_label_pair#*:}"
		if systemctl is-active --quiet "$svc" 2>/dev/null; then
			print_kv "$label" "${GREEN}active (running)${RESET}"
		else
			print_kv "$label" "${RED}inactive / stopped${RESET}"
		fi
	done

	if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
		print_kv "Watchdog Timer" "${GREEN}ACTIVE${RESET} (${WATCHDOG_TIMER})"
	else
		print_kv "Watchdog Timer" "${YELLOW}INACTIVE${RESET} (${WATCHDOG_TIMER})"
	fi

	# 2. Interface, Handshake & Egress Routing Telemetry
	echo -e "\n${BOLD}${CYAN}--- WireGuard & Routing ---${RESET}"
	if ip -n "$NAMESPACE" link show dev "$WG_IFACE" up 2>/dev/null | grep -q .; then
		print_kv "Tunnel Interface" "${GREEN}UP${RESET} (${WG_IFACE} in netns ${NAMESPACE})"
	else
		print_kv "Tunnel Interface" "${RED}DOWN / NOT FOUND${RESET}"
	fi

	if [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
		local PEER_INFO
		PEER_INFO=$($SUDO ip netns exec "$NAMESPACE" wg show "$WG_IFACE" 2>/dev/null || true)
		if [ -n "$PEER_INFO" ]; then
			local ENDPOINT ENDPOINT_IP LATEST_HS TRANSFER FWMARK NOW DIFF HS_STR
			ENDPOINT=$(echo "$PEER_INFO" | awk '/endpoint:/ {print $2; exit}' || true)
			ENDPOINT_IP=$(echo "${ENDPOINT:-}" | strip_endpoint_ip)
			FWMARK=$($SUDO ip netns exec "$NAMESPACE" wg show "$WG_IFACE" fwmark 2>/dev/null || true)
			LATEST_HS=$($SUDO ip netns exec "$NAMESPACE" wg show "$WG_IFACE" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1 || true)
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
			print_kv "Outer Socket fwmark" "${FWMARK:-off}"
			if [ -n "$ENDPOINT_IP" ]; then
				local ROUTE_DEV
				if [ -n "$FWMARK" ] && [ "$FWMARK" != "off" ]; then
					ROUTE_DEV=$(ip route get "$ENDPOINT_IP" mark "$FWMARK" 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}' || true)
				else
					ROUTE_DEV=$(ip route get "$ENDPOINT_IP" 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}' || true)
				fi
				if [ "$ROUTE_DEV" = "$SYSTEM_VPN_IFACE" ]; then
					print_kv "Outer Egress Path" "${YELLOW}${ROUTE_DEV} (nested double-VPN)${RESET}"
				else
					print_kv "Outer Egress Path" "${GREEN}${ROUTE_DEV:-unknown}${RESET} (direct physical egress)"
				fi
			fi
			print_kv "Latest Handshake" "${HS_STR}"
			print_kv "Transfer (Rx / Tx)" "${TRANSFER:-none}"
		fi
	fi

	# 3. NAT-PMP Port Forwarding & DNS Telemetry
	echo -e "\n${BOLD}${CYAN}--- Port Forwarding & DNS ---${RESET}"
	if [ "$PORT_FORWARDING_ENABLED" = "1" ]; then
		if [ -f "$PORT_STATE_FILE" ]; then
			local FWD_PORT
			FWD_PORT=$(tr -d '[:space:]' <"$PORT_STATE_FILE" 2>/dev/null || true)
			print_kv "NAT-PMP Listen Port" "${GREEN}${FWD_PORT:-unknown}${RESET} (gateway ${GATEWAY})"
		else
			print_kv "NAT-PMP Listen Port" "${YELLOW}pending / unavailable${RESET}"
		fi
	else
		print_kv "NAT-PMP Port Forward" "disabled"
	fi

	if [ -f "/etc/netns/${NAMESPACE}/resolv.conf" ]; then
		local NS_SERVERS
		NS_SERVERS=$(awk '/^nameserver[[:space:]]+/ {printf "%s ", $2}' "/etc/netns/${NAMESPACE}/resolv.conf" | sed 's/[[:space:]]*$//')
		print_kv "Namespace DNS" "${GREEN}${NS_SERVERS:-none}${RESET} (fallback: ${FALLBACK_DNS:-none})"
	fi

	if [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
		local DNS_FW_DROPS DNS_LEAK_DROPS
		DNS_FW_DROPS=$(get_chain_packets "dns-fw")
		DNS_LEAK_DROPS=$(get_chain_packets "dns-leak")
		print_kv "Blocked DNS (dns-fw)" "${YELLOW}${DNS_FW_DROPS} packets${RESET}"
		print_kv "Blocked Leaks (dns-leak)" "${YELLOW}${DNS_LEAK_DROPS} packets${RESET}"
	fi

	# 4. Public Egress IP Verification inside namespace
	if [ "$FAST_MODE" -eq 0 ] && [ "$IP_LOOKUP" -eq 1 ] && { [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; }; then
		echo -e "\n${BOLD}${CYAN}--- Namespace Public IP Verification ---${RESET}"
		local IP_JSON
		IP_JSON=$($SUDO ip netns exec "$NAMESPACE" curl --connect-timeout 2 -m 4 -s https://ipinfo.io/json 2>/dev/null || true)
		if [ -n "$IP_JSON" ]; then
			local VPN_IP VPN_COUNTRY VPN_CITY
			VPN_IP=$(echo "$IP_JSON" | jq -r '.ip // empty' 2>/dev/null || true)
			VPN_COUNTRY=$(echo "$IP_JSON" | jq -r '.country // empty' 2>/dev/null || true)
			VPN_CITY=$(echo "$IP_JSON" | jq -r '.city // empty' 2>/dev/null || true)
			print_kv "Namespace Public IP" "${GREEN}${VPN_IP:-Unknown}${RESET} (${VPN_CITY:+$VPN_CITY, }${VPN_COUNTRY:-Unknown})"
		else
			print_kv "Namespace Public IP" "${YELLOW}UNAVAILABLE (offline or rate-limited)${RESET}"
		fi
	fi

	echo -e "${BOLD}${CYAN}============================================${RESET}"
}

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
