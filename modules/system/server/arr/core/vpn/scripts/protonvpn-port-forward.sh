#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr VPN: Dynamic NAT-PMP Port Forwarding Daemon for qBittorrent
# =============================================================================
#
# Purpose:
#   Negotiates and renews a dynamic NAT-PMP incoming port lease (RFC 6886)
#   inside the VPN network namespace, opens the namespace firewall for that
#   port, pushes runtime tuning & listen_port to qBittorrent via WebUI API,
#   and publishes the active port to PORT_STATE_FILE for CLI telemetry.
#
# Execution Context:
#   Runs inside `NetworkNamespacePath=/run/netns/${NAMESPACE}` via
#   `protonvpn-port-forward.service`.
# =============================================================================

log_info() { echo "[protonvpn-port-forward] INFO:  $*"; }
log_warn() { echo "[protonvpn-port-forward] WARN:  $*" >&2; }

: "${NAMESPACE:?NAMESPACE environment variable is required}"
: "${WG_IFACE:?WG_IFACE environment variable is required}"
WEBUI_HOST="${WEBUI_HOST:-127.0.0.1}"
WEBUI_PORT="${WEBUI_PORT:-8080}"
WEBUI_USER="${WEBUI_USER:-admin}"
PASS_FILE="${PASS_FILE:-}"
GATEWAY="${GATEWAY:-}"
LEASE_DURATION="${LEASE_DURATION:-60}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-45}"
MAX_CONNECTIONS="${MAX_CONNECTIONS:-100}"
MAX_CONNECTIONS_PER_TORRENT="${MAX_CONNECTIONS_PER_TORRENT:-25}"
MAX_UPLOADS="${MAX_UPLOADS:-8}"
MAX_UPLOADS_PER_TORRENT="${MAX_UPLOADS_PER_TORRENT:-2}"
MAX_ACTIVE_DOWNLOADS="${MAX_ACTIVE_DOWNLOADS:-2}"
MAX_ACTIVE_TORRENTS="${MAX_ACTIVE_TORRENTS:-4}"
DL_LIMIT_KIB="${DL_LIMIT_KIB:-25000}"
UP_LIMIT_KIB="${UP_LIMIT_KIB:-3000}"
CONNECTION_SPEED="${CONNECTION_SPEED:-50}"
SOCKET_BACKLOG_SIZE="${SOCKET_BACKLOG_SIZE:-100}"
HASHING_THREADS="${HASHING_THREADS:-2}"
SAVE_RESUME_DATA_INTERVAL="${SAVE_RESUME_DATA_INTERVAL:-15}"
ANNOUNCE_TO_ALL_TRACKERS="${ANNOUNCE_TO_ALL_TRACKERS:-true}"
PIECE_EXTENT_AFFINITY="${PIECE_EXTENT_AFFINITY:-true}"
COALESCE_READ_WRITE="${COALESCE_READ_WRITE:-true}"
PORT_STATE_FILE="${PORT_STATE_FILE:-/run/protonvpn-port-forward/port}"
NATPMP_FAIL_FILE="${NATPMP_FAIL_FILE:-/run/protonvpn-port-forward/fail_streak}"

detect_vpn_gateway() {
	local gw=""
	local resolv_file="/etc/resolv.conf"

	# 1. Explicit default route gateway inside namespace
	gw=$(ip route show default 2>/dev/null | awk '/via/ {print $3; exit}' || true)

	# 2. Point-to-point / host route on WireGuard interface
	if [[ -z $gw ]]; then
		gw=$(ip -4 route show dev "$WG_IFACE" 2>/dev/null | awk '{print $1}' | grep -E '^10\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
	fi

	# 3. Provider internal DNS in namespace resolv.conf
	if [[ -f "/etc/netns/${NAMESPACE}/resolv.conf" ]]; then
		resolv_file="/etc/netns/${NAMESPACE}/resolv.conf"
	fi
	if [[ -z $gw && -f $resolv_file ]]; then
		gw=$(awk '/^nameserver[[:space:]]+/ {print $2}' "$resolv_file" | grep -E '^10\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
	fi

	# 4. Standard ProtonVPN internal gateway fallback
	if [[ -z $gw ]]; then
		gw="10.2.0.1"
	fi

	echo "$gw"
}

write_state_value() {
	local target="$1"
	local value="$2"
	local state_dir tmp_file
	state_dir=$(dirname "$target")
	mkdir -p "$state_dir"
	tmp_file=$(mktemp "${state_dir}/.state.XXXXXX")
	printf '%s\n' "$value" >"$tmp_file"
	chmod 0644 "$tmp_file"
	mv -f "$tmp_file" "$target"
}

write_port_state() {
	write_state_value "$PORT_STATE_FILE" "$1"
}

clear_port_state() {
	rm -f "$PORT_STATE_FILE"
}

write_fail_streak() {
	write_state_value "$NATPMP_FAIL_FILE" "$1"
}

clear_fail_streak() {
	rm -f "$NATPMP_FAIL_FILE"
}

if [[ -z $GATEWAY ]]; then
	GATEWAY=$(detect_vpn_gateway)
	log_info "Auto-detected VPN gateway: $GATEWAY"
else
	log_info "Using configured VPN gateway: $GATEWAY"
fi

WEBUI_URL="http://${WEBUI_HOST}:${WEBUI_PORT}"
COOKIE_FILE=$(mktemp)

cleanup() {
	rm -f "$COOKIE_FILE"
	clear_port_state
	clear_fail_streak
}
trap cleanup EXIT
trap 'exit 0' INT TERM

# -----------------------------------------------------------------------------
# Wait for qBittorrent WebUI readiness
# -----------------------------------------------------------------------------
log_info "Waiting for qBittorrent WebUI at $WEBUI_URL..."
MAX_WAIT=90
WAITED=0
until curl --connect-timeout 2 -m 5 -s -f -I "$WEBUI_URL/" >/dev/null 2>&1; do
	sleep 1 &
	wait $! || true
	WAITED=$((WAITED + 1))
	if [[ $WAITED -ge $MAX_WAIT ]]; then
		log_warn "qBittorrent WebUI not responding after ${MAX_WAIT}s. Continuing to retry in loop..."
		break
	fi
done
log_info "qBittorrent WebUI check finished (took ${WAITED}s)."

login_qbittorrent() {
	if [[ -f $PASS_FILE ]]; then
		local pass
		pass=$(tr -d '\r\n' <"$PASS_FILE")
		rm -f "$COOKIE_FILE"
		curl --connect-timeout 5 -m 10 -s -c "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/auth/login" \
			--data-urlencode "username=$WEBUI_USER" \
			--data-urlencode "password=$pass" >/dev/null 2>&1 || true
	fi
}

sync_qbittorrent_prefs() {
	local listen_port="${1:-}"
	local port_json=""
	if [[ -n $listen_port ]]; then
		port_json="\"listen_port\": ${listen_port}, "
	fi

	local payload status
	payload="json={${port_json}\"upnp\": false, \"lsd\": false, \"reannounce_when_address_changed\": true, \"resolve_peer_host_names\": false, \"limit_tcp_overhead\": false, \"utp_tcp_mixed_mode\": 0, \"current_network_interface\": \"${WG_IFACE}\", \"max_connec\": ${MAX_CONNECTIONS}, \"max_connec_per_torrent\": ${MAX_CONNECTIONS_PER_TORRENT}, \"max_uploads\": ${MAX_UPLOADS}, \"max_uploads_per_torrent\": ${MAX_UPLOADS_PER_TORRENT}, \"max_active_downloads\": ${MAX_ACTIVE_DOWNLOADS}, \"max_active_torrents\": ${MAX_ACTIVE_TORRENTS}, \"dl_limit\": $((DL_LIMIT_KIB * 1024)), \"up_limit\": $((UP_LIMIT_KIB * 1024)), \"connection_speed\": ${CONNECTION_SPEED}, \"socket_backlog_size\": ${SOCKET_BACKLOG_SIZE}, \"hashing_threads\": ${HASHING_THREADS}, \"save_resume_data_interval\": ${SAVE_RESUME_DATA_INTERVAL}, \"announce_to_all_trackers\": ${ANNOUNCE_TO_ALL_TRACKERS}, \"announce_to_all_tiers\": ${ANNOUNCE_TO_ALL_TRACKERS}, \"enable_piece_extent_affinity\": ${PIECE_EXTENT_AFFINITY}, \"enable_coalesce_read_write\": ${COALESCE_READ_WRITE}, \"category_changed_tmm_enabled\": true}"

	status=$(curl --connect-timeout 5 -m 10 -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$payload" || true)
	if [[ $status != "200" ]]; then
		login_qbittorrent
		status=$(curl --connect-timeout 5 -m 10 -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$payload" || true)
	fi

	echo "$status"
}

login_qbittorrent

# Synchronize runtime limits & interface binding immediately even before NAT-PMP responds
INIT_STATUS=$(sync_qbittorrent_prefs "")
log_info "Synchronized baseline qBittorrent preferences (API status: ${INIT_STATUS})."

OLD_PORT=""
FAIL_STREAK=0

log_info "Entering NAT-PMP lease maintenance loop (interval: ${REFRESH_INTERVAL}s, lease: ${LEASE_DURATION}s)..."

while true; do
	if [[ -z $GATEWAY ]]; then
		GATEWAY=$(detect_vpn_gateway)
	fi

	# Request UDP and TCP port mappings via RFC 6886 NAT-PMP
	PORT=$(
		python3 - "$GATEWAY" "$LEASE_DURATION" <<'PY' 2>/dev/null || true
import socket, struct, sys

gateway = sys.argv[1]
lease = int(sys.argv[2])

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(2.5)
    s.bind(("", 0))
    s.sendto(struct.pack("!BBHHHI", 0, 1, 0, 0, 0, lease), (gateway, 5351))
    data, _ = s.recvfrom(1024)
    p = struct.unpack("!BBHIHHI", data[:16])[5]
    if p > 0:
        s.sendto(struct.pack("!BBHHHI", 0, 2, 0, p, p, lease), (gateway, 5351))
        s.recvfrom(1024)
        print(p)
except Exception:
    pass
PY
	)

	out=""
	if [[ -z $PORT || $PORT == "0" ]]; then
		out=$(timeout 10 natpmpc -a 0 0 udp "$LEASE_DURATION" -g "$GATEWAY" 2>&1) || true
		PORT=$(echo "$out" | grep -oP 'Mapped public port \K[0-9]+' | head -n 1 || true)
		if [[ -n $PORT && $PORT != "0" ]]; then
			timeout 10 natpmpc -a "$PORT" "$PORT" tcp "$LEASE_DURATION" -g "$GATEWAY" >/dev/null 2>&1 || true
		fi
	fi

	if [[ -n $PORT && $PORT != "0" ]]; then
		FAIL_STREAK=0
		clear_fail_streak
		if [[ $PORT != "$OLD_PORT" ]]; then
			log_info "Assigned public port: $PORT (previously: ${OLD_PORT:-none})"

			if [[ -n $OLD_PORT ]]; then
				iptables -D INPUT -p tcp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
				iptables -D INPUT -p udp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
			fi

			iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
			iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT

			STATUS=$(sync_qbittorrent_prefs "$PORT")
			if [[ $STATUS == "200" ]]; then
				log_info "Updated qBittorrent listen_port to $PORT (API status: $STATUS)"
				write_port_state "$PORT"
				OLD_PORT="$PORT"
			else
				log_warn "Failed to update qBittorrent listen_port to $PORT (API status: $STATUS); will retry next cycle."
			fi
		elif [[ ! -f $PORT_STATE_FILE ]]; then
			write_port_state "$PORT"
		fi
	else
		FAIL_STREAK=$((FAIL_STREAK + 1))
		write_fail_streak "$FAIL_STREAK"
		log_warn "Failed to obtain port from NAT-PMP gateway $GATEWAY (streak: $FAIL_STREAK). Output: $(echo "${out:-no response}" | tr '\n' ' ')"
		if [[ $FAIL_STREAK -ge 3 ]]; then
			clear_port_state
		fi
		GATEWAY=$(detect_vpn_gateway)
		sleep 10 &
		wait $! || true
		continue
	fi

	sleep "$REFRESH_INTERVAL" &
	wait $! || true
done
