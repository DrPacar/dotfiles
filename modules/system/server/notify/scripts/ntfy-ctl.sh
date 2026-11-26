#!/usr/bin/env bash
set -euo pipefail

: "${NTFY_PORT:=2586}"
: "${NTFY_LOCAL_URL:=http://127.0.0.1:${NTFY_PORT}}"
: "${NTFY_BASE_URL:=${NTFY_LOCAL_URL}}"
: "${NTFY_MEDIA_TOPIC:=media}"
: "${NTFY_ALERT_TOPIC:=alerts}"
: "${NTFY_CACHE_DURATION:=72h}"

cmd="${1:-help}"
if [ "$#" -gt 0 ]; then
	shift
fi

check_health() {
	if ! systemctl is-active --quiet ntfy-sh.service; then
		echo "[FAIL] ntfy-sh.service is not active" >&2
		return 1
	fi

	local health
	if ! health=$(curl -fsS -m 5 "${NTFY_LOCAL_URL}/v1/health"); then
		echo "[FAIL] ntfy health endpoint unreachable at ${NTFY_LOCAL_URL}/v1/health" >&2
		return 1
	fi

	if ! printf '%s' "$health" | jq -e '.healthy == true' >/dev/null 2>&1; then
		echo "[FAIL] ntfy reported unhealthy: ${health}" >&2
		return 1
	fi

	echo "[PASS] ntfy-sh is active and healthy (${NTFY_LOCAL_URL}, media=${NTFY_MEDIA_TOPIC}, alerts=${NTFY_ALERT_TOPIC})"
}

show_recent() {
	local topic="${1:-$NTFY_ALERT_TOPIC}"
	local limit="${2:-10}"
	local raw
	raw=$(curl -fsS -m 5 "${NTFY_LOCAL_URL}/${topic}/json?poll=1&since=${NTFY_CACHE_DURATION}" || true)
	if [ -z "$raw" ]; then
		echo "(no cached messages in topic '${topic}' over the last ${NTFY_CACHE_DURATION})"
		return 0
	fi
	printf '%s\n' "$raw" | jq -r 'select(.event == "message") | [(.time | strflocaltime("%Y-%m-%d %H:%M:%S")), (.priority // 3 | tostring), (.title // "-"), (.message // "")] | @tsv' | tail -n "$limit"
}

send_msg() {
	local topic="${1:-$NTFY_ALERT_TOPIC}"
	local message="${2:-Notification from $(uname -n)}"
	local title="${3:-Server Notification}"
	local tags="${4:-bell}"
	local priority="${5:-default}"

	curl -fsS -m 5 \
		-H "Title: ${title}" \
		-H "Tags: ${tags}" \
		-H "Priority: ${priority}" \
		-d "${message}" \
		"${NTFY_LOCAL_URL}/${topic}" >/dev/null
	echo "Sent to '${topic}' (priority=${priority}): ${title}"
}

case "$cmd" in
check)
	check_health
	;;
status)
	echo "=== ntfy-sh Status ==="
	systemctl status ntfy-sh.service --lines=5 --no-pager || true
	echo ""
	check_health || true
	echo "Web / Base URL: ${NTFY_BASE_URL}"
	echo "Topics:         media='${NTFY_MEDIA_TOPIC}', alerts='${NTFY_ALERT_TOPIC}'"
	;;
recent)
	echo "=== Recent '${NTFY_ALERT_TOPIC}' ==="
	show_recent "${1:-$NTFY_ALERT_TOPIC}" "${2:-10}"
	if [ "$#" -eq 0 ]; then
		echo ""
		echo "=== Recent '${NTFY_MEDIA_TOPIC}' ==="
		show_recent "$NTFY_MEDIA_TOPIC" 10
	fi
	;;
send)
	send_msg "$@"
	;;
test)
	target="${1:-both}"
	host="$(uname -n)"
	if [ "$target" = "media" ] || [ "$target" = "both" ]; then
		send_msg "$NTFY_MEDIA_TOPIC" "Test media notification from ${host}" "Media Test (${host})" "popcorn,white_check_mark" "default"
	fi
	if [ "$target" = "alerts" ] || [ "$target" = "both" ]; then
		send_msg "$NTFY_ALERT_TOPIC" "Test alert notification from ${host}" "Alert Test (${host})" "bell,white_check_mark" "high"
	fi
	;;
logs)
	exec journalctl -u ntfy-sh.service -n "${1:-50}" --no-pager
	;;
help | --help | -h)
	cat <<'EOF'
Usage: ntfy-ctl <command> [args]

Commands:
  check                               Verify ntfy-sh unit & /v1/health endpoint
  status                              Show service status, URLs, and topic defaults
  recent [<topic>] [<limit>]          Show cached messages from the last 72h
  send <topic> <msg> [title] [tags] [priority]
                                      Publish a message to a local topic
  test [media|alerts|both]            Send test notification(s)
  logs [<lines>]                      Show recent ntfy-sh journal logs
EOF
	;;
*)
	echo "Unknown command: $cmd" >&2
	echo "Run 'ntfy-ctl help' for usage." >&2
	exit 1
	;;
esac
