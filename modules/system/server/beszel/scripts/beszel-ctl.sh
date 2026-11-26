#!/usr/bin/env bash
set -euo pipefail

: "${BESZEL_HUB_PORT:=8090}"
: "${BESZEL_LOCAL_URL:=http://127.0.0.1:${BESZEL_HUB_PORT}}"
: "${BESZEL_APP_URL:=${BESZEL_LOCAL_URL}}"
: "${BESZEL_DB_PATH:=/var/lib/private/beszel-hub/data.db}"
: "${BESZEL_AGENT_ENABLED:=1}"
: "${BESZEL_AGENT_PORT:=45876}"
: "${BESZEL_HOST_NAME:=haven}"

cmd="${1:-help}"
if [ "$#" -gt 0 ]; then
	shift
fi

check_health() {
	if ! systemctl is-active --quiet beszel-hub.service; then
		echo "[FAIL] beszel-hub.service is not active" >&2
		return 1
	fi

	if ! curl -fsS -m 5 "${BESZEL_LOCAL_URL}/api/health" | jq -e '.code == 200' >/dev/null 2>&1; then
		echo "[FAIL] beszel-hub /api/health check failed at ${BESZEL_LOCAL_URL}/api/health" >&2
		return 1
	fi

	if [ "$BESZEL_AGENT_ENABLED" = "1" ]; then
		if ! systemctl is-active --quiet beszel-agent.service; then
			echo "[FAIL] beszel-agent.service is not active" >&2
			return 1
		fi
		if ! nc -z 127.0.0.1 "$BESZEL_AGENT_PORT" >/dev/null 2>&1; then
			echo "[FAIL] beszel-agent port 127.0.0.1:${BESZEL_AGENT_PORT} not listening" >&2
			return 1
		fi
	fi

	if [ "$(id -u)" -eq 0 ] && [ -f "$BESZEL_DB_PATH" ]; then
		local bad_smart
		bad_smart=$(sqlite3 "$BESZEL_DB_PATH" "SELECT count(*) FROM smart_devices WHERE lower(state) != 'passed';" 2>/dev/null)
		if [ "$bad_smart" != "0" ]; then
			echo "[FAIL] ${bad_smart} SMART device(s) not reporting PASSED" >&2
			return 1
		fi
	fi

	echo "[PASS] beszel-hub & beszel-agent are healthy (${BESZEL_APP_URL})"
}

require_root_db() {
	if [ "$(id -u)" -ne 0 ]; then
		exec sudo "$0" "$cmd" "$@"
	fi
	if [ ! -f "$BESZEL_DB_PATH" ]; then
		echo "Beszel database not found at ${BESZEL_DB_PATH}" >&2
		exit 1
	fi
}

case "$cmd" in
check)
	check_health
	;;
status)
	echo "=== Beszel Services ==="
	systemctl status beszel-hub.service beszel-agent.service --lines=3 --no-pager || true
	echo ""
	check_health || true
	if [ "$(id -u)" -eq 0 ] && [ -f "$BESZEL_DB_PATH" ]; then
		echo ""
		echo "=== Systems ==="
		sqlite3 -header -column "$BESZEL_DB_PATH" "SELECT s.name, s.status, s.host || ':' || s.port AS endpoint, json_extract(s.info, '$.cpu') AS cpu_pct, json_extract(s.info, '$.mp') AS mem_pct, json_extract(s.info, '$.dp') AS disk_pct, json_extract(s.info, '$.dt') AS temp_c, json_extract(s.info, '$.sv[1]') AS failed_units, (SELECT json_extract(ss.stats, '$.g.i0.u') FROM system_stats ss WHERE ss.system = s.id ORDER BY ss.created DESC LIMIT 1) AS gpu_pct FROM systems s;"
		echo ""
		echo "=== SMART Health ==="
		sqlite3 -header -column "$BESZEL_DB_PATH" "SELECT model, name, state, temp AS temp_c, hours, cycles, ROUND(capacity / 1000000000.0, 0) || ' GB' AS size FROM smart_devices;"
	fi
	;;
alerts)
	require_root_db "$@"
	echo "=== Beszel Alerts ==="
	sqlite3 -header -column "$BESZEL_DB_PATH" "SELECT a.name, a.value AS threshold, a.min AS duration_min, CASE WHEN a.triggered=1 THEN 'FIRING' ELSE 'ok' END AS state, s.name AS system FROM alerts a JOIN systems s ON s.id = a.system ORDER BY a.name;"
	echo ""
	echo "=== Webhooks ==="
	sqlite3 "$BESZEL_DB_PATH" "SELECT json_extract(settings, '$.webhooks') FROM user_settings;"
	;;
smart)
	require_root_db "$@"
	sqlite3 -header -column "$BESZEL_DB_PATH" "SELECT model, name, serial, firmware, state, temp AS temp_c, hours, cycles, ROUND(capacity / 1000000000.0, 0) || ' GB' AS size FROM smart_devices;"
	;;
logs)
	exec journalctl -u beszel-hub.service -u beszel-agent.service -n "${1:-50}" --no-pager
	;;
help | --help | -h)
	cat <<'EOF'
Usage: beszel-ctl <command> [args]

Commands:
  check             Verify beszel-hub API, beszel-agent socket, and SMART status
  status            Show service status, live system telemetry, and SMART summary
  alerts            Show configured Beszel alert thresholds and webhook targets
  smart             Show SMART disk health tracked by Beszel
  logs [<lines>]    Show recent logs from beszel-hub and beszel-agent
EOF
	;;
*)
	echo "Unknown command: $cmd" >&2
	echo "Run 'beszel-ctl help' for usage." >&2
	exit 1
	;;
esac
