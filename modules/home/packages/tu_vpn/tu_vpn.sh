#!/usr/bin/env bash
set -euo pipefail

SECRET_FILE="/run/secrets/tu_vpn_user"

if [[ -f $SECRET_FILE ]]; then
  TU_USER=$(cat "$SECRET_FILE")
else
  echo "⚠️ Secret '$SECRET_FILE' nicht gefunden."
  read -rp "Bitte TU-Benutzername / Matrikelnummer eingeben (z.B. e12345678): " TU_USER
fi

if [[ -z $TU_USER ]]; then
  echo "Fehler: Kein Benutzername angegeben."
  exit 1
fi

echo "Starte TU Wien VPN für $TU_USER ..."
exec sudo openconnect \
  --useragent "AnyConnect OpenConnect" \
  --no-external-auth \
  --authgroup="1_TU_getunnelt" \
  --user "$TU_USER" \
  vpn.tuwien.ac.at
