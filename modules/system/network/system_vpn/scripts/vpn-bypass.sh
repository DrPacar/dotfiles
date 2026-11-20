#!/usr/bin/env bash
set -euo pipefail

GROUP="${BYPASS_GROUP:-${1:-vpn-bypass}}"
if [ "$#" -gt 0 ] && [ "${1:-}" = "$GROUP" ]; then
  shift || true
fi

if [ $# -eq 0 ]; then
  echo "Usage: vpn-bypass <command> [args...]"
  echo "Executes <command> directly through the physical ISP gateway, bypassing the system WireGuard VPN."
  exit 1
fi

if ! getent group "$GROUP" >/dev/null 2>&1; then
  echo "Error: Bypass group '$GROUP' does not exist." >&2
  exit 1
fi

CURRENT_GID=$(id -g)
TARGET_GID=$(getent group "$GROUP" | cut -d: -f3)

# If already running with effective GID of GROUP:
if [ "$CURRENT_GID" = "$TARGET_GID" ]; then
  exec "$@"
fi

# Check membership or root
USER_NAME=$(id -un)
if id -nG "$USER_NAME" | grep -qw "$GROUP" || [ "$EUID" -eq 0 ]; then
  CMD=$(printf '%q ' "$@")
  exec sg "$GROUP" -c "$CMD"
else
  echo "Error: User '$USER_NAME' is not a member of '$GROUP'." >&2
  echo "Add user to group: users.users.$USER_NAME.extraGroups = [ \"$GROUP\" ];" >&2
  exit 1
fi
