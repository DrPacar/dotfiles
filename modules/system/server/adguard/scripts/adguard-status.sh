#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# AdGuard Home: Diagnostic CLI Dashboard & Self-Test Verification
# =============================================================================
#
# Purpose:
#   Collects, formats, and verifies AdGuard Home service health, port 53
#   binding, WebUI API telemetry, filter lists, ad-blocking effectiveness,
#   live DNS resolution, and Split-Horizon rewrite behavior.
#
# Execution Context:
#   Invoked via `adguard status` or `adguard check`.
# =============================================================================

: "${ADGUARD_URL:?ADGUARD_URL environment variable is required}"
: "${ADGUARD_USER:?ADGUARD_USER environment variable is required}"
: "${PASS_FILE:?PASS_FILE environment variable is required}"
: "${DNS_PORT:?DNS_PORT environment variable is required}"
: "${TEST_DOMAIN:?TEST_DOMAIN environment variable is required}"
: "${BYPASS_SYSTEM_VPN:?BYPASS_SYSTEM_VPN environment variable is required}"
: "${SYSTEM_VPN_ENABLED:?SYSTEM_VPN_ENABLED environment variable is required}"
: "${SYSTEM_VPN_IFACE:?SYSTEM_VPN_IFACE environment variable is required}"
SPLIT_HOST="${SPLIT_HOST:-}"
EXPECTED_LAN_IP="${EXPECTED_LAN_IP:-}"
TAILSCALE_IP="${TAILSCALE_IP:-}"

UNIT="adguardhome.service"
SYNC_UNIT="adguardhome-admin-sync.service"
WATCHDOG_TIMER="adguardhome-watchdog.timer"

SUDO=""
if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
	if sudo -n true 2>/dev/null; then
		SUDO="sudo"
	fi
fi

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

read_password() {
	if [ -r "$PASS_FILE" ]; then
		tr -d '\r\n' <"$PASS_FILE"
		return 0
	elif [ -n "$SUDO" ] || [ "$EUID" -eq 0 ]; then
		$SUDO cat "$PASS_FILE" 2>/dev/null | tr -d '\r\n'
		return 0
	fi
	return 1
}

api_get() {
	local endpoint="$1"
	local pass
	if ! pass=$(read_password); then
		return 1
	fi
	curl --connect-timeout 3 -m 5 -fsS -u "${ADGUARD_USER}:${pass}" "${ADGUARD_URL}${endpoint}" 2>/dev/null
}

query_dns() {
	local server="$1"
	local domain="$2"
	local qtype="$3"
	python3 - "$server" "$DNS_PORT" "$domain" "$qtype" <<'PY' 2>/dev/null
import socket, struct, sys

server, port, domain, qtype_str = sys.argv[1], int(sys.argv[2]), sys.argv[3].strip("."), sys.argv[4].upper()
qtype = {"A": 1, "AAAA": 28}.get(qtype_str, 1)

def skip_name(buf, off):
    while off < len(buf):
        ln = buf[off]
        if ln == 0:
            return off + 1
        if (ln & 0xC0) == 0xC0:
            return off + 2
        off += 1 + ln
    return off

q = b"".join(bytes([len(p)]) + p.encode() for p in domain.split(".")) + b"\x00"
pkt = struct.pack("!HHHHHH", 0x5151, 0x0100, 1, 0, 0, 0) + q + struct.pack("!HH", qtype, 1)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3.0)
s.sendto(pkt, (server, port))
resp, _ = s.recvfrom(4096)

tx, flags, qdcount, ancount = struct.unpack("!HHHH", resp[:8])
rcode = flags & 0x0F
off = 12
for _ in range(qdcount):
    off = skip_name(resp, off) + 4

ips = []
for _ in range(ancount):
    off = skip_name(resp, off)
    rtype, _, _, rdlen = struct.unpack("!HHIH", resp[off : off + 10])
    off += 10
    rdata = resp[off : off + rdlen]
    off += rdlen
    if rtype == 1 and rdlen == 4:
        ips.append(socket.inet_ntop(socket.AF_INET, rdata))
    elif rtype == 28 and rdlen == 16:
        ips.append(socket.inet_ntop(socket.AF_INET6, rdata))

print(f"{rcode}|{ancount}|{','.join(ips)}")
PY
}

# -----------------------------------------------------------------------------
# Subcommand: Automated Verification Self-Test
# -----------------------------------------------------------------------------
do_selftest() {
	echo -e "${BOLD}${CYAN}=== AdGuard Home Self-Test ===${RESET}"
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

	# Check 1: Systemd units & timer
	if systemctl is-active --quiet "$UNIT"; then
		run_check "Service $UNIT is active" 0
	else
		run_check "Service $UNIT is active" 1 "inactive"
	fi

	if systemctl is-active --quiet "$SYNC_UNIT"; then
		run_check "Admin sync unit $SYNC_UNIT succeeded" 0
	else
		run_check "Admin sync unit $SYNC_UNIT succeeded" 1 "inactive"
	fi

	if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
		run_check "Watchdog timer $WATCHDOG_TIMER is active" 0
	else
		run_check "Watchdog timer $WATCHDOG_TIMER is active" 1 "inactive"
	fi

	# Check 2: Port 53 listener & stub listener disabled
	if ss -tuln 2>/dev/null | grep -qE ":${DNS_PORT}[[:space:]]"; then
		run_check "DNS port ${DNS_PORT} (UDP/TCP) is listening" 0
	else
		run_check "DNS port ${DNS_PORT} (UDP/TCP) is listening" 1 "no socket bound"
	fi

	if ss -tuln 2>/dev/null | grep -qE "127\.0\.0\.53:${DNS_PORT}[[:space:]]"; then
		run_check "systemd-resolved DNSStubListener disabled on 127.0.0.53:${DNS_PORT}" 1 "stub listener still bound"
	else
		run_check "systemd-resolved DNSStubListener disabled on 127.0.0.53:${DNS_PORT}" 0
	fi

	# Check 3: WebUI & Authenticated API Status
	local HTTP_CODE
	HTTP_CODE=$(curl --connect-timeout 3 -m 5 -s -o /dev/null -w "%{http_code}" "${ADGUARD_URL}/login.html" || true)
	if [ "$HTTP_CODE" = "200" ]; then
		run_check "WebUI endpoint ${ADGUARD_URL}/login.html responds HTTP 200" 0
	else
		run_check "WebUI endpoint ${ADGUARD_URL}/login.html responds HTTP 200" 1 "got HTTP ${HTTP_CODE:-000}"
	fi

	local STATUS_JSON FILTER_JSON BLOCK_JSON
	if STATUS_JSON=$(api_get "/control/status"); then
		local PROT_ENABLED RUNNING
		PROT_ENABLED=$(echo "$STATUS_JSON" | jq -r '.protection_enabled')
		RUNNING=$(echo "$STATUS_JSON" | jq -r '.running')
		if [ "$PROT_ENABLED" = "true" ] && [ "$RUNNING" = "true" ]; then
			run_check "API authenticated & DNS protection enabled ($(echo "$STATUS_JSON" | jq -r '.version'))" 0
		else
			run_check "API authenticated & DNS protection enabled" 1 "protection=$PROT_ENABLED running=$RUNNING"
		fi

		if FILTER_JSON=$(api_get "/control/filtering/status"); then
			local ACTIVE_FILTERS TOTAL_RULES
			ACTIVE_FILTERS=$(echo "$FILTER_JSON" | jq '[.filters[] | select(.enabled)] | length')
			TOTAL_RULES=$(echo "$FILTER_JSON" | jq '[.filters[] | select(.enabled) | .rules_count] | add // 0')
			if [ "$ACTIVE_FILTERS" -gt 0 ] && [ "$TOTAL_RULES" -gt 0 ]; then
				run_check "Filter lists loaded (${ACTIVE_FILTERS} lists, ${TOTAL_RULES} rules)" 0
			else
				run_check "Filter lists loaded" 1 "filters=$ACTIVE_FILTERS rules=$TOTAL_RULES"
			fi
		fi

		if BLOCK_JSON=$(api_get "/control/filtering/check_host?name=doubleclick.net"); then
			local REASON
			REASON=$(echo "$BLOCK_JSON" | jq -r '.reason // empty')
			if [ "$REASON" = "FilteredBlackList" ]; then
				run_check "Ad-blocking engine active (doubleclick.net -> $REASON)" 0
			else
				run_check "Ad-blocking engine active (doubleclick.net)" 1 "reason=${REASON:-none}"
			fi
		fi
	else
		run_check "WebUI API authentication (requires read access to $PASS_FILE)" 1 "auth failed or unreadable secret"
	fi

	# Check 4: Live UDP DNS Resolution
	local DNS_RES RCODE ANCOUNT IPS
	DNS_RES=$(query_dns "127.0.0.1" "$TEST_DOMAIN" "A" || true)
	IFS='|' read -r RCODE ANCOUNT IPS <<<"$DNS_RES"
	if [ "${RCODE:-}" = "0" ] && [ "${ANCOUNT:-0}" -gt 0 ]; then
		run_check "Live DNS resolution for $TEST_DOMAIN via 127.0.0.1:${DNS_PORT} succeeded ($IPS)" 0
	else
		run_check "Live DNS resolution for $TEST_DOMAIN via 127.0.0.1:${DNS_PORT}" 1 "rcode=${RCODE:-timeout} answers=${ANCOUNT:-0}"
	fi

	# Check 5: Split-Horizon rewrite verification (A + AAAA NODATA)
	if [ -n "$SPLIT_HOST" ] && [ -n "$EXPECTED_LAN_IP" ]; then
		local SPLIT_A SPLIT_AAAA A_RCODE A_AN A_IPS AAAA_RCODE AAAA_AN AAAA_IPS
		SPLIT_A=$(query_dns "127.0.0.1" "$SPLIT_HOST" "A" || true)
		IFS='|' read -r A_RCODE A_AN A_IPS <<<"$SPLIT_A"
		if [ "${A_RCODE:-}" = "0" ] && [ "${A_AN:-0}" -gt 0 ] && [ "${A_IPS:-}" = "$EXPECTED_LAN_IP" ]; then
			run_check "Split-Horizon A rewrite ($SPLIT_HOST -> $A_IPS)" 0
		else
			run_check "Split-Horizon A rewrite ($SPLIT_HOST -> $EXPECTED_LAN_IP)" 1 "got '${A_IPS:-none}' (rcode=${A_RCODE:-timeout} answers=${A_AN:-0})"
		fi

		SPLIT_AAAA=$(query_dns "127.0.0.1" "$SPLIT_HOST" "AAAA" || true)
		IFS='|' read -r AAAA_RCODE AAAA_AN AAAA_IPS <<<"$SPLIT_AAAA"
		if [ "${AAAA_RCODE:-}" = "0" ] && [ "${AAAA_AN:-0}" = "0" ]; then
			run_check "Split-Horizon AAAA returns NOERROR/0 answers (no public IPv6 leak)" 0
		else
			run_check "Split-Horizon AAAA suppression ($SPLIT_HOST)" 1 "rcode=${AAAA_RCODE:-timeout} answers=${AAAA_AN:-0} ips=${AAAA_IPS:-none}"
		fi
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
	echo -e "${BOLD}${CYAN}=== AdGuard Home Status ===${RESET}"

	for svc_label_pair in \
		"AdGuard Service:${UNIT}" \
		"Admin Sync:${SYNC_UNIT}" \
		"Watchdog Timer:${WATCHDOG_TIMER}"; do
		local label="${svc_label_pair%%:*}"
		local svc="${svc_label_pair#*:}"
		if systemctl is-active --quiet "$svc" 2>/dev/null; then
			print_kv "$label" "${GREEN}active${RESET}"
		else
			print_kv "$label" "${RED}inactive${RESET}"
		fi
	done

	if [ "$SYSTEM_VPN_ENABLED" = "1" ]; then
		if [ "$BYPASS_SYSTEM_VPN" = "1" ]; then
			print_kv "Upstream Egress Mode" "${YELLOW}vpn-bypass${RESET} (direct WAN via physical NIC)"
		else
			print_kv "Upstream Egress Mode" "${GREEN}tunnelled${RESET} (DoH via ${SYSTEM_VPN_IFACE})"
		fi
	fi

	local STATUS_JSON STATS_JSON FILTER_JSON
	echo -e "\n${BOLD}${CYAN}--- DNS Telemetry & Filters ---${RESET}"
	if STATUS_JSON=$(api_get "/control/status"); then
		local VERSION PROT_ENABLED
		VERSION=$(echo "$STATUS_JSON" | jq -r '.version // "unknown"')
		PROT_ENABLED=$(echo "$STATUS_JSON" | jq -r '.protection_enabled')
		print_kv "AdGuard Version" "${GREEN}${VERSION}${RESET}"
		if [ "$PROT_ENABLED" = "true" ]; then
			print_kv "DNS Protection" "${GREEN}ENABLED${RESET}"
		else
			print_kv "DNS Protection" "${RED}DISABLED${RESET}"
		fi

		if STATS_JSON=$(api_get "/control/stats"); then
			local TOTAL_Q BLOCKED_Q AVG_MS BLOCK_PCT
			TOTAL_Q=$(echo "$STATS_JSON" | jq -r '.num_dns_queries // 0')
			BLOCKED_Q=$(echo "$STATS_JSON" | jq -r '.num_blocked_filtering // 0')
			AVG_MS=$(echo "$STATS_JSON" | jq -r '((.avg_processing_time // 0) * 1000) | tostring | .[0:5]')
			BLOCK_PCT=$(awk -v b="$BLOCKED_Q" -v t="$TOTAL_Q" 'BEGIN { if (t > 0) printf "%.1f%%", (b*100)/t; else printf "0.0%%" }')
			print_kv "Queries / Blocked" "${TOTAL_Q} total  •  ${GREEN}${BLOCKED_Q} blocked (${BLOCK_PCT})${RESET}"
			print_kv "Avg Processing Time" "${AVG_MS} ms"
		fi

		if FILTER_JSON=$(api_get "/control/filtering/status"); then
			local ACTIVE_FILTERS TOTAL_RULES
			ACTIVE_FILTERS=$(echo "$FILTER_JSON" | jq '[.filters[] | select(.enabled)] | length')
			TOTAL_RULES=$(echo "$FILTER_JSON" | jq '[.filters[] | select(.enabled) | .rules_count] | add // 0')
			print_kv "Active Blocklists" "${GREEN}${ACTIVE_FILTERS} lists${RESET} (${TOTAL_RULES} rules)"
		fi
	else
		print_kv "WebUI API Telemetry" "${YELLOW}UNAVAILABLE${RESET} (WebUI down or $PASS_FILE unreadable)"
	fi

	if [ -n "$SPLIT_HOST" ]; then
		echo -e "\n${BOLD}${CYAN}--- Split-Horizon Rewrites ---${RESET}"
		print_kv "LAN Rewrite (${SPLIT_HOST})" "${EXPECTED_LAN_IP:-disabled}"
		print_kv "Tailscale Rewrite" "${TAILSCALE_IP:-disabled}"
	fi

	echo -e "${BOLD}${CYAN}===================================${RESET}"
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
