#!/usr/bin/env bash
# =============================================================================
# protonvpn-port-forward.sh
# Dynamic NAT-PMP port forwarding daemon for qBittorrent inside VPN namespace.
# Automatically negotiates, maps, and updates incoming listen port and rate limits.
# =============================================================================
set -euo pipefail

# --- Logging Helpers ---
log_info() { echo "[protonvpn-port-forward] INFO:  $*"; }
log_warn() { echo "[protonvpn-port-forward] WARN:  $*" >&2; }
log_err() { echo "[protonvpn-port-forward] ERROR: $*" >&2; }

# --- Default Parameters ---
WEBUI_HOST=""
WEBUI_PORT=8080
PASS_FILE=""
GATEWAY=""
LEASE_DURATION=60
REFRESH_INTERVAL=45
MAX_CONNECTIONS=100
MAX_CONNECTIONS_PER_TORRENT=25
MAX_ACTIVE_DOWNLOADS=2
MAX_ACTIVE_TORRENTS=4
DL_LIMIT_KIB=25000
UP_LIMIT_KIB=3000

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  --webui-host)
    WEBUI_HOST="${2:-}"
    shift 2
    ;;
  --webui-port)
    WEBUI_PORT="${2:-8080}"
    shift 2
    ;;
  --pass-file)
    PASS_FILE="${2:-}"
    shift 2
    ;;
  --gateway)
    GATEWAY="${2:-}"
    shift 2
    ;;
  --lease-duration)
    LEASE_DURATION="${2:-60}"
    shift 2
    ;;
  --refresh-interval)
    REFRESH_INTERVAL="${2:-45}"
    shift 2
    ;;
  --max-connections)
    MAX_CONNECTIONS="${2:-100}"
    shift 2
    ;;
  --max-connections-per-torrent)
    MAX_CONNECTIONS_PER_TORRENT="${2:-25}"
    shift 2
    ;;
  --max-active-downloads)
    MAX_ACTIVE_DOWNLOADS="${2:-2}"
    shift 2
    ;;
  --max-active-torrents)
    MAX_ACTIVE_TORRENTS="${2:-4}"
    shift 2
    ;;
  --download-limit-kib)
    DL_LIMIT_KIB="${2:-25000}"
    shift 2
    ;;
  --upload-limit-kib)
    UP_LIMIT_KIB="${2:-3000}"
    shift 2
    ;;
  *)
    log_warn "Unknown parameter: $1"
    shift
    ;;
  esac
done

# --- Dynamic Gateway Detection (Edge Case: No Hardcoded IP) ---
detect_vpn_gateway() {
  local gw=""

  # 1. Check default route inside namespace
  gw=$(ip route show default 2>/dev/null | awk '/via/ {print $3}' | head -n 1 || true)

  # 2. Check route on wg0 interface
  if [[ -z $gw ]]; then
    gw=$(ip -4 route show dev wg0 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
  fi

  # 3. Check DNS server in /etc/resolv.conf (VPN DNS usually matches gateway, ignore local loopback 127.x stubs)
  if [[ -z $gw && -f /etc/resolv.conf ]]; then
    gw=$(awk '/nameserver/ {print $2}' /etc/resolv.conf | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -vE '^127\.' | head -n 1 || true)
  fi

  # 4. Fallback to standard Proton / WireGuard internal gateway
  if [[ -z $gw ]]; then
    gw="10.2.0.1"
  fi

  echo "$gw"
}

# If gateway was not explicitly provided, detect dynamically
if [[ -z $GATEWAY ]]; then
  GATEWAY=$(detect_vpn_gateway)
  log_info "Auto-detected VPN gateway: $GATEWAY"
else
  log_info "Using configured VPN gateway: $GATEWAY"
fi

# Fallback for WebUI host if not passed
if [[ -z $WEBUI_HOST ]]; then
  WEBUI_HOST="127.0.0.1"
fi

WEBUI_URL="http://${WEBUI_HOST}:${WEBUI_PORT}"
COOKIE_FILE=$(mktemp)

# Clean up temporary cookie file on exit
cleanup() {
  rm -f "$COOKIE_FILE"
}
trap cleanup EXIT INT TERM

# --- Wait for qBittorrent WebUI ---
log_info "Waiting for qBittorrent WebUI at $WEBUI_URL..."
MAX_WAIT=90
WAITED=0
until curl -s -f -I "$WEBUI_URL/" >/dev/null 2>&1; do
  sleep 1
  WAITED=$((WAITED + 1))
  if [[ $WAITED -ge $MAX_WAIT ]]; then
    log_warn "qBittorrent WebUI not responding after ${MAX_WAIT}s. Continuing to retry in background..."
    break
  fi
done
log_info "qBittorrent WebUI check finished (took ${WAITED}s)."

# --- qBittorrent Authentication ---
login_qbittorrent() {
  if [[ -f $PASS_FILE ]]; then
    local pass
    pass=$(cat "$PASS_FILE" | tr -d '\r\n')
    rm -f "$COOKIE_FILE"
    curl -s -c "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/auth/login" \
      --data-urlencode "username=admin" \
      --data-urlencode "password=$pass" >/dev/null 2>&1 || true
  fi
}

login_qbittorrent

OLD_PORT=""

# --- Main NAT-PMP Lease & Forwarding Loop ---
log_info "Entering NAT-PMP lease maintenance loop (interval: ${REFRESH_INTERVAL}s, lease: ${LEASE_DURATION}s)..."

while true; do
  # Re-detect gateway if previous was unreachable
  if [[ -z $GATEWAY ]]; then
    GATEWAY=$(detect_vpn_gateway)
  fi

  # Request UDP and TCP port mappings from gateway via NAT-PMP (RFC 6886: -a 0 0 for dynamic external port)
  out=$(natpmpc -a 0 0 udp "$LEASE_DURATION" -g "$GATEWAY" 2>&1) || true
  tcp_out=$(natpmpc -a 0 0 tcp "$LEASE_DURATION" -g "$GATEWAY" 2>&1) || true
  combined="$out"$'\n'"$tcp_out"

  # Parse mapped public port
  PORT=$(echo "$combined" | grep -oP 'Mapped public port \K[0-9]+' | head -n 1 || true)

  if [[ -n $PORT && $PORT != "0" ]]; then
    if [[ $PORT != "$OLD_PORT" ]]; then
      log_info "Assigned public port: $PORT (previously: ${OLD_PORT:-none})"

      # Update namespace iptables rules safely (avoid duplicates)
      if [[ -n $OLD_PORT ]]; then
        iptables -D INPUT -p tcp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
      fi

      iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
      iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT

      # Update qBittorrent preferences over WebUI API
      PAYLOAD="json={\"listen_port\": $PORT, \"upnp\": false, \"current_network_interface\": \"wg0\", \"max_connec\": $MAX_CONNECTIONS, \"max_connec_per_torrent\": $MAX_CONNECTIONS_PER_TORRENT, \"max_active_downloads\": $MAX_ACTIVE_DOWNLOADS, \"max_active_torrents\": $MAX_ACTIVE_TORRENTS, \"dl_limit\": $((DL_LIMIT_KIB * 1024)), \"up_limit\": $((UP_LIMIT_KIB * 1024))}"

      STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$PAYLOAD" || true)

      if [[ $STATUS != "200" ]]; then
        # Session may have expired, re-login and retry
        login_qbittorrent
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$PAYLOAD" || true)
      fi

      log_info "Updated qBittorrent listen_port to $PORT (API status: $STATUS)"
      OLD_PORT="$PORT"
    fi
  else
    log_warn "Failed to obtain port from NAT-PMP gateway $GATEWAY. Output: $(echo "$combined" | tr '\n' ' ')"
    # Re-detect gateway in case network shifted
    GATEWAY=$(detect_vpn_gateway)
    sleep 10
    continue
  fi

  sleep "$REFRESH_INTERVAL"
done
