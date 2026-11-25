#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr qBittorrent: Diagnostic CLI Dashboard & Self-Test Verification
# =============================================================================
#
# Purpose:
#   Inspects qBittorrent service health, WebUI API reachability, VPN interface
#   binding, NAT-PMP listen-port alignment, transfer telemetry, and storage paths.
#
# Execution Context:
#   Invoked via `arr qbit status`, `arr qbit check`, `arr-qbit status`, or
#   `arr-qbit check`.
# =============================================================================

: "${WEBUI_URL:?WEBUI_URL environment variable is required}"
: "${WEBUI_USER:?WEBUI_USER environment variable is required}"
: "${PASS_FILE:?PASS_FILE environment variable is required}"
: "${VPN_ENABLED:?VPN_ENABLED environment variable is required}"
: "${VPN_IFACE:?VPN_IFACE environment variable is required}"
: "${PORT_FORWARDING_ENABLED:?PORT_FORWARDING_ENABLED environment variable is required}"
: "${PORT_STATE_FILE:?PORT_STATE_FILE environment variable is required}"
: "${TORRENTS_DIR:?TORRENTS_DIR environment variable is required}"
: "${MEDIA_GROUP:?MEDIA_GROUP environment variable is required}"

QBIT_UNIT="qbittorrent.service"
PROXY_UNIT="qbittorrent-webui-proxy.service"
WATCHDOG_TIMER="qbittorrent-watchdog.timer"
CLEANER_TIMER="arr-stalled-cleaner.timer"

# Privilege helper (only needed if PASS_FILE is not directly readable)
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

format_rate() {
	awk -v bytes="$1" 'BEGIN {
		if (bytes >= 1048576) printf "%.2f MiB/s", bytes / 1048576;
		else if (bytes >= 1024) printf "%.1f KiB/s", bytes / 1024;
		else printf "%d B/s", bytes;
	}'
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

api_login() {
	local cookie_file="$1"
	local pass body
	if ! pass=$(read_password); then
		return 1
	fi
	# qBittorrent 5.x returns HTTP 204 (Set-Cookie) or HTTP 200 ("Ok.") on login,
	# and HTTP 200 ("Fails.") on bad credentials.
	if ! body=$(curl --connect-timeout 3 -m 5 -fsS \
		-c "$cookie_file" -X POST "${WEBUI_URL}/api/v2/auth/login" \
		--data-urlencode "username=$WEBUI_USER" \
		--data-urlencode "password=$pass" 2>/dev/null); then
		return 1
	fi
	if [ "$body" = "Fails." ]; then
		return 1
	fi
	curl --connect-timeout 3 -m 5 -fsS -b "$cookie_file" "${WEBUI_URL}/api/v2/app/version" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Subcommand: Automated Verification Self-Test
# -----------------------------------------------------------------------------
do_selftest() {
	echo -e "${BOLD}${CYAN}=== Arr qBittorrent Self-Test ===${RESET}"
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

	# Check 1: Systemd units
	if systemctl is-active --quiet "$QBIT_UNIT"; then
		run_check "Service $QBIT_UNIT is active" 0
	else
		run_check "Service $QBIT_UNIT is active" 1 "inactive"
	fi

	if [ "$VPN_ENABLED" = "1" ]; then
		if systemctl is-active --quiet "$PROXY_UNIT"; then
			run_check "WebUI host proxy $PROXY_UNIT is active" 0
		else
			run_check "WebUI host proxy $PROXY_UNIT is active" 1 "inactive"
		fi
	fi

	if systemctl is-active --quiet "$WATCHDOG_TIMER" 2>/dev/null; then
		run_check "Watchdog timer $WATCHDOG_TIMER is active" 0
	else
		run_check "Watchdog timer $WATCHDOG_TIMER is active" 1 "inactive"
	fi

	# Check 2: WebUI HTTP reachability & API login
	local HTTP_CODE
	HTTP_CODE=$(curl --connect-timeout 3 -m 5 -s -o /dev/null -w "%{http_code}" "${WEBUI_URL}/" || true)
	if [ "$HTTP_CODE" = "200" ]; then
		run_check "WebUI endpoint $WEBUI_URL responds HTTP 200" 0
	else
		run_check "WebUI endpoint $WEBUI_URL responds HTTP 200" 1 "got HTTP ${HTTP_CODE:-000}"
	fi

	local COOKIE_FILE
	COOKIE_FILE=$(mktemp)
	trap 'rm -f "$COOKIE_FILE"' RETURN

	if api_login "$COOKIE_FILE"; then
		run_check "WebUI API authentication succeeded (user: $WEBUI_USER)" 0

		local PREFS
		PREFS=$(curl --connect-timeout 3 -m 5 -fsS -b "$COOKIE_FILE" "${WEBUI_URL}/api/v2/app/preferences" 2>/dev/null || true)
		if [ -n "$PREFS" ]; then
			local CUR_IFACE LSD UPNP REANNOUNCE RESOLVE_HOST LISTEN_PORT
			CUR_IFACE=$(echo "$PREFS" | jq -r '.current_network_interface // empty')
			LSD=$(echo "$PREFS" | jq -r '.lsd')
			UPNP=$(echo "$PREFS" | jq -r '.upnp')
			REANNOUNCE=$(echo "$PREFS" | jq -r '.reannounce_when_address_changed')
			RESOLVE_HOST=$(echo "$PREFS" | jq -r '.resolve_peer_host_names')
			LISTEN_PORT=$(echo "$PREFS" | jq -r '.listen_port // 0')

			if [ "$VPN_ENABLED" = "1" ]; then
				if [ "$CUR_IFACE" = "$VPN_IFACE" ]; then
					run_check "qBittorrent bound strictly to VPN interface ($CUR_IFACE)" 0
				else
					run_check "qBittorrent bound strictly to VPN interface ($VPN_IFACE)" 1 "bound to '${CUR_IFACE:-any}'"
				fi

				if [ "$LSD" = "false" ] && [ "$UPNP" = "false" ] && [ "$RESOLVE_HOST" = "false" ] && [ "$REANNOUNCE" = "true" ]; then
					run_check "VPN peer/privacy settings optimal (lsd=false, upnp=false, reannounce=true)" 0
				else
					run_check "VPN peer/privacy settings optimal" 1 "lsd=$LSD upnp=$UPNP resolve_host=$RESOLVE_HOST reannounce=$REANNOUNCE"
				fi
			fi

			if [ "$PORT_FORWARDING_ENABLED" = "1" ]; then
				if [ -f "$PORT_STATE_FILE" ]; then
					local FWD_PORT
					FWD_PORT=$(tr -d '[:space:]' <"$PORT_STATE_FILE" 2>/dev/null || true)
					if [ "$LISTEN_PORT" = "$FWD_PORT" ]; then
						run_check "qBittorrent listen_port matches NAT-PMP port ($LISTEN_PORT)" 0
					else
						run_check "qBittorrent listen_port matches NAT-PMP port" 1 "qbit=$LISTEN_PORT, natpmp=${FWD_PORT:-none}"
					fi
				else
					run_check "NAT-PMP state file present ($PORT_STATE_FILE)" 1 "missing"
				fi
			fi
		else
			run_check "Fetch qBittorrent runtime preferences" 1 "empty API response"
		fi
	else
		run_check "WebUI API authentication (requires read access to $PASS_FILE)" 1 "login failed or unreadable secret"
	fi

	# Check 3: Storage path & media group ownership
	if [ -d "$TORRENTS_DIR" ]; then
		local DIR_GROUP
		DIR_GROUP=$(stat -c '%G' "$TORRENTS_DIR" 2>/dev/null || true)
		if [ "$DIR_GROUP" = "$MEDIA_GROUP" ]; then
			run_check "Torrents directory $TORRENTS_DIR exists (group: $DIR_GROUP)" 0
		else
			run_check "Torrents directory $TORRENTS_DIR group is $MEDIA_GROUP" 1 "found '$DIR_GROUP'"
		fi
	else
		run_check "Torrents directory $TORRENTS_DIR exists" 1 "missing"
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
	echo -e "${BOLD}${CYAN}=== Arr qBittorrent Status ===${RESET}"

	for svc_label_pair in \
		"qBittorrent Service:${QBIT_UNIT}" \
		"WebUI Host Proxy:${PROXY_UNIT}" \
		"Watchdog Timer:${WATCHDOG_TIMER}" \
		"Stalled Cleaner Timer:${CLEANER_TIMER}"; do
		local label="${svc_label_pair%%:*}"
		local svc="${svc_label_pair#*:}"
		if systemctl is-active --quiet "$svc" 2>/dev/null; then
			print_kv "$label" "${GREEN}active${RESET}"
		else
			print_kv "$label" "${YELLOW}inactive${RESET}"
		fi
	done

	local COOKIE_FILE
	COOKIE_FILE=$(mktemp)
	trap 'rm -f "$COOKIE_FILE"' RETURN

	echo -e "\n${BOLD}${CYAN}--- Runtime Telemetry & Preferences ---${RESET}"
	if api_login "$COOKIE_FILE"; then
		local VERSION TRANSFER TORRENTS PREFS
		VERSION=$(curl --connect-timeout 3 -m 5 -fsS -b "$COOKIE_FILE" "${WEBUI_URL}/api/v2/app/version" 2>/dev/null || true)
		TRANSFER=$(curl --connect-timeout 3 -m 5 -fsS -b "$COOKIE_FILE" "${WEBUI_URL}/api/v2/transfer/info" 2>/dev/null || true)
		TORRENTS=$(curl --connect-timeout 3 -m 5 -fsS -b "$COOKIE_FILE" "${WEBUI_URL}/api/v2/torrents/info" 2>/dev/null || true)
		PREFS=$(curl --connect-timeout 3 -m 5 -fsS -b "$COOKIE_FILE" "${WEBUI_URL}/api/v2/app/preferences" 2>/dev/null || true)

		print_kv "qBittorrent Version" "${GREEN}${VERSION:-unknown}${RESET}"

		if [ -n "$PREFS" ]; then
			local IFACE PORT LSD REANNOUNCE
			IFACE=$(echo "$PREFS" | jq -r '.current_network_interface // "any"')
			PORT=$(echo "$PREFS" | jq -r '.listen_port // 0')
			LSD=$(echo "$PREFS" | jq -r '.lsd')
			REANNOUNCE=$(echo "$PREFS" | jq -r '.reannounce_when_address_changed')
			print_kv "Bound Network Interface" "${GREEN}${IFACE}${RESET}"
			print_kv "Listen Port" "${GREEN}${PORT}${RESET}"
			print_kv "VPN Tuning" "lsd=${LSD}, reannounce=${REANNOUNCE}"
		fi

		if [ -n "$TRANSFER" ]; then
			local DL_SPEED UP_SPEED DHT_NODES CONN_STATUS
			DL_SPEED=$(echo "$TRANSFER" | jq -r '.dl_info_speed // 0')
			UP_SPEED=$(echo "$TRANSFER" | jq -r '.up_info_speed // 0')
			DHT_NODES=$(echo "$TRANSFER" | jq -r '.dht_nodes // 0')
			CONN_STATUS=$(echo "$TRANSFER" | jq -r '.connection_status // "unknown"')
			print_kv "Connection Status" "${GREEN}${CONN_STATUS}${RESET} (DHT nodes: ${DHT_NODES})"
			print_kv "Transfer Rate" "↓ $(format_rate "$DL_SPEED")  •  ↑ $(format_rate "$UP_SPEED")"
		fi

		if [ -n "$TORRENTS" ]; then
			local TOTAL DOWNLOADING STALLED SEEDING
			TOTAL=$(echo "$TORRENTS" | jq 'length')
			DOWNLOADING=$(echo "$TORRENTS" | jq '[.[] | select(.state == "downloading" or .state == "forcedDL" or .state == "metaDL")] | length')
			STALLED=$(echo "$TORRENTS" | jq '[.[] | select(.state == "stalledDL")] | length')
			SEEDING=$(echo "$TORRENTS" | jq '[.[] | select(.state == "uploading" or .state == "stalledUP" or .state == "forcedUP")] | length')
			print_kv "Torrents Queue" "Total: ${TOTAL} (DL: ${DOWNLOADING}, Stalled: ${STALLED}, Seed: ${SEEDING})"
		fi
	else
		print_kv "WebUI API Telemetry" "${YELLOW}UNAVAILABLE${RESET} (WebUI down or $PASS_FILE unreadable)"
	fi

	echo -e "\n${BOLD}${CYAN}--- Storage ---${RESET}"
	if [ -d "$TORRENTS_DIR" ]; then
		local DISK_AVAIL
		DISK_AVAIL=$(df -h --output=avail,pcent "$TORRENTS_DIR" 2>/dev/null | tail -n 1 | awk '{printf "%s free (%s used)", $1, $2}' || echo "unknown")
		print_kv "Torrents Path" "${TORRENTS_DIR} (${DISK_AVAIL})"
	else
		print_kv "Torrents Path" "${RED}${TORRENTS_DIR} missing${RESET}"
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
