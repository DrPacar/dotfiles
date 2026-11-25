#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Arr qBittorrent: Autonomous Watchdog, WebUI Health Probe & Alerting
# =============================================================================
#
# Purpose:
#   Monitors qBittorrent and its host WebUI proxy from the host namespace:
#   - Respects VPN lifecycle: skips health checks while VPN_UNIT is inactive
#     so wg-watchdog owns tunnel recovery without duplicate restarts.
#   - Automatically revives qbittorrent.service or qbittorrent-webui-proxy.service
#     if either enters systemd's failed state.
#   - Probes WebUI HTTP reachability; after FAILURE_THRESHOLD consecutive
#     failures, restarts qbittorrent.service and emits a deduplicated alert.
#   - Emits a single recovery notification once WebUI health returns.
#
# Execution Context:
#   Triggered periodically on the host by `qbittorrent-watchdog.timer`.
# =============================================================================

: "${WEBUI_URL:?WEBUI_URL environment variable is required}"
: "${VPN_ENABLED:?VPN_ENABLED environment variable is required}"
: "${VPN_UNIT:?VPN_UNIT environment variable is required}"
FAILURE_THRESHOLD="${FAILURE_THRESHOLD:-3}"
NOTIFY_BIN="${NOTIFY_BIN:-}"

QBIT_UNIT="qbittorrent.service"
PROXY_UNIT="qbittorrent-webui-proxy.service"
STATE_DIR="/run/arr-qbittorrent"
FAIL_FILE="${STATE_DIR}/webui_fails"
ALERTED_FILE="${STATE_DIR}/alerted"

send_alert() {
	local msg="$1"
	local tag="${2:-warning}"
	if [ -n "$NOTIFY_BIN" ] && [ -x "$NOTIFY_BIN" ]; then
		if ! "$NOTIFY_BIN" "$msg" "$tag"; then
			echo "WARN: [qbittorrent-watchdog] Notification handler '$NOTIFY_BIN' failed." >&2
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

# When VPN confinement is active, wait if the VPN tunnel unit itself is down/restarting
if [ "$VPN_ENABLED" = "1" ] && ! systemctl is-active --quiet "$VPN_UNIT"; then
	exit 0
fi

mkdir -p "$STATE_DIR"

# Revive failed qBittorrent service (respecting deliberate manual stops)
if systemctl is-failed --quiet "$QBIT_UNIT"; then
	echo "WARN: [qbittorrent-watchdog] $QBIT_UNIT is in failed state. Resetting and starting..." >&2
	send_alert_once "qBittorrent: Service ${QBIT_UNIT} war im Fehlerzustand (failed). Starte neu." "rotating_light"
	systemctl reset-failed "$QBIT_UNIT"
	systemctl start "$QBIT_UNIT"
	exit 0
fi

if ! systemctl is-active --quiet "$QBIT_UNIT"; then
	exit 0
fi

# Ensure WebUI proxy is healthy when VPN confinement is active
if [ "$VPN_ENABLED" = "1" ]; then
	if systemctl is-failed --quiet "$PROXY_UNIT"; then
		echo "WARN: [qbittorrent-watchdog] $PROXY_UNIT is in failed state. Resetting and starting..." >&2
		send_alert_once "qBittorrent: WebUI-Proxy (${PROXY_UNIT}) war im Fehlerzustand (failed). Starte neu." "warning"
		systemctl reset-failed "$PROXY_UNIT"
		systemctl start "$PROXY_UNIT"
		exit 0
	elif ! systemctl is-active --quiet "$PROXY_UNIT"; then
		exit 0
	fi
fi

# -----------------------------------------------------------------------------
# Probe qBittorrent WebUI responsiveness (unauthenticated GET / avoids auth bans)
# -----------------------------------------------------------------------------
if curl --connect-timeout 3 -m 5 -fsS -I "${WEBUI_URL}/" >/dev/null 2>&1; then
	rm -f "$FAIL_FILE"
	if [ -f "$ALERTED_FILE" ]; then
		rm -f "$ALERTED_FILE"
		send_alert "qBittorrent: WebUI und Service wieder erreichbar." "white_check_mark"
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

if [ "$FAILS" -ge "$FAILURE_THRESHOLD" ]; then
	echo "WARN: [qbittorrent-watchdog] WebUI at $WEBUI_URL failed $FAILS consecutive probes. Restarting $QBIT_UNIT..." >&2
	rm -f "$FAIL_FILE"
	send_alert_once "qBittorrent: WebUI antwortet nach ${FAILS} Prüfungen nicht (${WEBUI_URL}). Starte ${QBIT_UNIT} neu." "rotating_light"
	systemctl restart "$QBIT_UNIT"
else
	echo "INFO: [qbittorrent-watchdog] WebUI probe failed ($FAILS/$FAILURE_THRESHOLD) at $WEBUI_URL. Awaiting next cycle."
fi
