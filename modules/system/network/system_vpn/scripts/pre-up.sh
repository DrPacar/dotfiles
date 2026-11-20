#!/usr/bin/env bash
set -euo pipefail

PHYS_IFACE="${1:-}"
if [ -z "$PHYS_IFACE" ]; then
  echo "Error: Physical interface argument missing." >&2
  exit 1
fi
shift || true

GW=""
for _ in $(seq 1 15); do
  GW=$(ip route show default dev "$PHYS_IFACE" 2>/dev/null | awk '/via/ {print $3}' | head -n 1 || true)
  if [ -n "$GW" ]; then
    break
  fi
  sleep 1
done

if [ -z "$GW" ]; then
  echo "WARNING: [system-vpn] No default gateway found on $PHYS_IFACE after 15s, continuing..." >&2
  exit 0
fi

mkdir -p /run/system-vpn
touch /run/system-vpn/endpoints

for conf in "$@"; do
  [ -f "$conf" ] || continue

  # Extract endpoint lines and extract host/IP before colon
  while IFS= read -r line; do
    RAW=$(echo "$line" | sed -E 's/^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*\[?([^]:[:space:]]+).*/\1/')
    [ -z "$RAW" ] && continue

    IPS=""
    if echo "$RAW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
      IPS="$RAW"
    else
      # Resolve FQDN via getent
      IPS=$(getent ahostsv4 "$RAW" 2>/dev/null | awk '{print $1}' | sort -u || true)
    fi

    for ip in $IPS; do
      if [ -n "$ip" ]; then
        ip route add "$ip/32" via "$GW" dev "$PHYS_IFACE" 2>/dev/null || true
        echo "$ip" >>/run/system-vpn/endpoints
      fi
    done
  done < <(grep -iE "^[[:space:]]*Endpoint" "$conf" || true)
done

if [ -f /run/system-vpn/endpoints ]; then
  sort -u -o /run/system-vpn/endpoints /run/system-vpn/endpoints 2>/dev/null || true
fi
