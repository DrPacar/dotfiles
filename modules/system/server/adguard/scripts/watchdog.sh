#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# AdGuard Home: Autonomous Watchdog, DNS Probe & Auto-Healing
# =============================================================================
#
# Purpose:
#   Monitors AdGuard Home's WebUI and live UDP DNS resolver on the host:
#   - Respects VPN lifecycle when bypassSystemVpn is false: does not alert or
#     restart AdGuard solely because wg-system is intentionally down.
#   - Automatically revives adguardhome.service if it enters systemd's failed
#     state (while respecting deliberate admin stops).
#   - Probes WebUI (/login.html -> HTTP 200) and live UDP DNS resolution on
#     127.0.0.1:DNS_PORT for TEST_DOMAIN.
#   - After FAILURE_THRESHOLD consecutive failures, restarts adguardhome.service
#     and sends a single deduplicated alert (+ recovery alert once healthy).
#
# Execution Context:
#   Triggered periodically on the host by `adguardhome-watchdog.timer`.
# =============================================================================

: "${ADGUARD_URL:?ADGUARD_URL environment variable is required}"
: "${DNS_PORT:?DNS_PORT environment variable is required}"
: "${TEST_DOMAIN:?TEST_DOMAIN environment variable is required}"
: "${BYPASS_SYSTEM_VPN:?BYPASS_SYSTEM_VPN environment variable is required}"
: "${SYSTEM_VPN_ENABLED:?SYSTEM_VPN_ENABLED environment variable is required}"
: "${SYSTEM_VPN_IFACE:?SYSTEM_VPN_IFACE environment variable is required}"
FAILURE_THRESHOLD="${FAILURE_THRESHOLD:-3}"
NOTIFY_BIN="${NOTIFY_BIN:-}"

UNIT="adguardhome.service"
STATE_DIR="/run/adguard-watchdog"
FAIL_FILE="${STATE_DIR}/probe_fails"
ALERTED_FILE="${STATE_DIR}/alerted"

send_alert() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ -n "$NOTIFY_BIN" ] && [ -x "$NOTIFY_BIN" ]; then
		if ! "$NOTIFY_BIN" "$msg" "$tag"; then
			echo "WARN: [adguard-watchdog] Notification handler '$NOTIFY_BIN' failed." >&2
		fi
	fi
}

send_alert_once() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ ! -f "$ALERTED_FILE" ]; then
		touch "$ALERTED_FILE"
		send_alert "$msg" "$tag"
	fi
}

dns_probe() {
	python3 - "$DNS_PORT" "$TEST_DOMAIN" <<'PY' >/dev/null 2>&1
import socket, struct, sys

port = int(sys.argv[1])
domain = sys.argv[2].strip(".")
q = b"".join(bytes([len(p)]) + p.encode() for p in domain.split(".")) + b"\x00"
pkt = struct.pack("!HHHHHH", 0x4242, 0x0100, 1, 0, 0, 0) + q + struct.pack("!HH", 1, 1)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3.0)
s.sendto(pkt, ("127.0.0.1", port))
resp, _ = s.recvfrom(4096)
if len(resp) < 12:
    sys.exit(1)
tx, flags, _, ancount = struct.unpack("!HHHH", resp[:8])
rcode = flags & 0x0F
if tx != 0x4242 or rcode != 0 or ancount < 1:
    sys.exit(1)
PY
}

mkdir -p "$STATE_DIR"

# Revive failed AdGuard Home unit (respecting deliberate manual stops)
if systemctl is-failed --quiet "$UNIT"; then
	echo "WARN: [adguard-watchdog] $UNIT is in failed state. Resetting and starting..." >&2
	send_alert_once "AdGuard Home: Service ${UNIT} entered failed state. Resetting and starting." "rotating_light"
	systemctl reset-failed "$UNIT"
	systemctl start "$UNIT"
	exit 0
fi

if ! systemctl is-active --quiet "$UNIT"; then
	exit 0
fi

# Check WebUI health first (always local, independent of upstream VPN state)
WEB_OK=1
if ! curl --connect-timeout 3 -m 5 -fsS -I "${ADGUARD_URL}/login.html" >/dev/null 2>&1; then
	WEB_OK=0
fi

# When AdGuard routes upstream DoH through systemVPN and systemVPN is stopped,
# only treat WebUI failure as actionable (avoid false restarts during VPN outage).
DNS_OK=1
if [ "$WEB_OK" -eq 1 ]; then
	if [ "$BYPASS_SYSTEM_VPN" = "1" ] || [ "$SYSTEM_VPN_ENABLED" = "0" ] || systemctl is-active --quiet "wg-quick-${SYSTEM_VPN_IFACE}.service"; then
		if ! dns_probe; then
			DNS_OK=0
		fi
	fi
fi

if [ "$WEB_OK" -eq 1 ] && [ "$DNS_OK" -eq 1 ]; then
	rm -f "$FAIL_FILE"
	if [ -f "$ALERTED_FILE" ]; then
		rm -f "$ALERTED_FILE"
		send_alert "AdGuard Home: WebUI and DNS resolution fully operational again." "white_check_mark"
	fi
	exit 0
fi

FAILS=0
if [ -f "$FAIL_FILE" ]; then
	FAILS=$(tr -d '[:space:]' <"$FAIL_FILE" 2>/dev/null || echo 0)
fi
if ! [[ $FAILS =~ ^[0-9]+$ ]]; then
	FAILS=0
fi
FAILS=$((FAILS + 1))
echo "$FAILS" >"$FAIL_FILE"

REASON="DNS resolution (${TEST_DOMAIN}) failed"
if [ "$WEB_OK" -eq 0 ]; then
	REASON="WebUI (${ADGUARD_URL}/login.html) unreachable"
fi

if [ "$FAILS" -ge "$FAILURE_THRESHOLD" ]; then
	echo "WARN: [adguard-watchdog] ${REASON} ($FAILS consecutive failures). Restarting $UNIT..." >&2
	rm -f "$FAIL_FILE"
	send_alert_once "AdGuard Home: ${REASON} after ${FAILS} checks. Restarting ${UNIT}." "rotating_light"
	systemctl restart "$UNIT"
else
	echo "INFO: [adguard-watchdog] Probe failed (${REASON}, attempt $FAILS/$FAILURE_THRESHOLD). Awaiting next cycle."
fi
