#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: Unified Management CLI
# =============================================================================
#
# Execution Context:
#   Installed into system PATH as `system-vpn`. Delegates diagnostics to
#   `vpn-status`, split-tunnel execution to `vpn-bypass`, and lifecycle
#   control to systemd.
# =============================================================================

: "${IFACE:?IFACE environment variable is required}"

usage() {
	cat <<'EOF'
Usage: system-vpn <command> [options]

Commands:
  status [--fast|--no-ip]  Show tunnel telemetry, IP verification, and killswitch counters
  check | selftest         Run automated 22-point routing, DNS, and leak self-test (requires sudo)
  start | stop | restart   Manage wg-quick systemd service lifecycle
  logs                     Show recent WireGuard and watchdog journal entries
  watchdog                 Trigger an immediate watchdog health check
  bypass <command...>      Run a command outside the VPN via the physical gateway
EOF
}

case "${1:-status}" in
status)
	shift || true
	exec vpn-status "$@"
	;;
check | selftest)
	shift || true
	exec vpn-status check "$@"
	;;
start)
	echo "Starting WireGuard ${IFACE}..."
	exec systemctl start "wg-quick-${IFACE}.service"
	;;
stop)
	echo "Stopping WireGuard ${IFACE}..."
	exec systemctl stop "wg-quick-${IFACE}.service"
	;;
restart)
	echo "Restarting WireGuard ${IFACE}..."
	exec systemctl restart "wg-quick-${IFACE}.service"
	;;
logs)
	exec journalctl -u "wg-quick-${IFACE}.service" -u "${IFACE}-watchdog.service" -n 50 --no-pager
	;;
watchdog)
	echo "Triggering WireGuard ${IFACE} watchdog check..."
	exec systemctl start "${IFACE}-watchdog.service"
	;;
bypass)
	shift || true
	exec vpn-bypass "$@"
	;;
-h | --help | help)
	usage
	;;
*)
	usage >&2
	exit 1
	;;
esac
