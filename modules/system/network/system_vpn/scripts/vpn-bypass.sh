#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# System VPN: CLI Split-Tunnel Command Bypass Wrapper
# =============================================================================
#
# Purpose:
#   Executes an arbitrary command or subprocess under the dedicated split-tunnel
#   bypass group (default: "vpn-bypass"). Traffic originating from the process
#   is marked by nftables and routed directly through the physical ISP gateway.
#
# Execution Context:
#   Invoked by an operator via `system-vpn bypass <command...>` or standalone
#   `vpn-bypass <command...>`.
# =============================================================================

GROUP="${BYPASS_GROUP:-vpn-bypass}"

if [ $# -eq 0 ]; then
	echo "Usage: system-vpn bypass <command> [args...]"
	echo "Executes <command> directly through the physical ISP gateway, bypassing the system WireGuard VPN."
	exit 1
fi

if ! getent group "$GROUP" >/dev/null 2>&1; then
	echo "Error: [system-vpn-bypass] Bypass group '$GROUP' does not exist." >&2
	exit 1
fi

CURRENT_GID=$(id -g)
TARGET_GID=$(getent group "$GROUP" | cut -d: -f3)

# If process is already running with effective GID of target group, execute directly
if [ "$CURRENT_GID" = "$TARGET_GID" ]; then
	exec "$@"
fi

# Locate NixOS setuid sg binary
SG="/run/wrappers/bin/sg"
if [ ! -x "$SG" ]; then
	SG="sg"
fi

# Authorize user membership or root elevation
USER_NAME=$(id -un)
if id -nG "$USER_NAME" 2>/dev/null | tr ' ' '\n' | grep -qxF "$GROUP" || [ "$EUID" -eq 0 ]; then
	CMD=$(printf '%q ' "$@")
	exec "$SG" "$GROUP" -c "$CMD"
else
	echo "Error: [system-vpn-bypass] User '$USER_NAME' is not a member of group '$GROUP'." >&2
	echo "Add user to group in NixOS configuration: users.users.$USER_NAME.extraGroups = [ \"$GROUP\" ];" >&2
	exit 1
fi
