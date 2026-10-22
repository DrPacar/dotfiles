#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
SECRET_USER="/run/secrets/tu_vpn_user"
SECRET_PASS="/run/secrets/tu_vpn_pass"
SECRET_TOTP="/run/secrets/tu_vpn_totp"
VPN_HOST="vpn.tuwien.ac.at"
AUTH_GROUP="1_TU_getunnelt"
INTERFACE="tun0"

# --- Pre-Flight Checks ---
for cmd in openconnect sudo; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed."
    exit 1
  fi
done

# --- Help Function ---
show_help() {
  cat <<EOF
Usage: tu-vpn [COMMAND]

Manage TU Wien VPN connection via OpenConnect.

Commands:
  start, up       Connect to TU Wien VPN
  stop, down      Disconnect from TU Wien VPN
  status          Show current VPN connection status
  -h, --help      Display this help message

Secrets (managed via SOPS in secrets/common.yaml):
  tu_vpn_user     TU Wien account (e.g. e12345678 or user@student.tuwien.ac.at)
  tu_vpn_pass     TU Wien account password
  tu_vpn_totp     (Optional) Base32 secret for automated 2FA (TOTP)
EOF
}

# --- Command Parsing ---
case "${1:-}" in
-h | --help | help)
  show_help
  exit 0
  ;;
"")
  show_help
  exit 0
  ;;
status)
  if ip link show "$INTERFACE" >/dev/null 2>&1 || pgrep -x "openconnect" >/dev/null; then
    echo "🟢 TU Wien VPN is active (Interface: $INTERFACE)"
  else
    echo "🔴 TU Wien VPN is disconnected"
  fi
  exit 0
  ;;
stop | down)
  echo "Stopping TU Wien VPN..."
  if pgrep -x "openconnect" >/dev/null; then
    sudo killall openconnect
    echo "VPN stopped."
    if command -v notify-send &>/dev/null; then
      notify-send "TU Wien VPN" "Disconnected" --icon=network-vpn-disconnected || true
    fi
  else
    echo "VPN is not running."
  fi
  exit 0
  ;;
start | up)
  # Continue to connection flow below
  ;;
*)
  echo "Error: Unknown command '$1'"
  echo
  show_help
  exit 1
  ;;
esac

# --- Check if already running ---
if ip link show "$INTERFACE" >/dev/null 2>&1 || pgrep -x "openconnect" >/dev/null; then
  echo "⚠️ VPN connection already active. Run '$0 stop' to disconnect."
  exit 0
fi

# --- Get Username ---
if [[ -f $SECRET_USER ]]; then
  TU_USER=$(tr -d '\r\n' <"$SECRET_USER")
else
  echo "⚠️ User secret not found at $SECRET_USER"
  read -rp "Please enter the TU-Username (e12345678): " TU_USER
fi

if [[ -z $TU_USER ]]; then
  echo "Error: No username provided."
  exit 1
fi

if [[ $TU_USER != *"@"* ]]; then
  FULL_USER="${TU_USER}@student.tuwien.ac.at"
else
  FULL_USER="$TU_USER"
fi

# --- Get Password ---
if [[ -f $SECRET_PASS ]]; then
  PASSWORD=$(tr -d '\r\n' <"$SECRET_PASS")
else
  read -rsp "Please enter password for $FULL_USER: " PASSWORD
  echo
fi

# --- Start VPN ---
echo "Starting TU Wien VPN for $FULL_USER in the background..."

if [[ -f $SECRET_TOTP ]]; then
  echo "Using stored 2FA secret..."
  TOTP_RAW=$(tr -d '\r\n ' <"$SECRET_TOTP")
  TOTP_RAW="${TOTP_RAW#base32:}"
  pad_len=$(((8 - (${#TOTP_RAW} % 8)) % 8))
  for ((i = 0; i < pad_len; i++)); do TOTP_RAW+="="; done
  TOTP_ARG="base32:$TOTP_RAW"

  printf '%s\n' "$PASSWORD" | sudo openconnect \
    --background \
    --non-inter \
    --useragent "AnyConnect OpenConnect" \
    --no-external-auth \
    --authgroup="$AUTH_GROUP" \
    --user "$FULL_USER" \
    --passwd-on-stdin \
    --token-mode=totp \
    --token-secret="$TOTP_ARG" \
    "$VPN_HOST"
else
  read -rp "Enter 2FA Code (press Enter to skip): " OTP_CODE
  if [[ -n $OTP_CODE ]]; then
    printf '%s\n%s\n' "$PASSWORD" "$OTP_CODE" | sudo openconnect \
      --background \
      --non-inter \
      --useragent "AnyConnect OpenConnect" \
      --no-external-auth \
      --authgroup="$AUTH_GROUP" \
      --user "$FULL_USER" \
      --passwd-on-stdin \
      "$VPN_HOST"
  else
    printf '%s\n' "$PASSWORD" | sudo openconnect \
      --background \
      --non-inter \
      --useragent "AnyConnect OpenConnect" \
      --no-external-auth \
      --authgroup="$AUTH_GROUP" \
      --user "$FULL_USER" \
      --passwd-on-stdin \
      "$VPN_HOST"
  fi
fi

# --- Post-Start Check & Notification ---
echo "Waiting for connection to establish..."
CONNECTED=false
for _ in {1..10}; do
  if ip link show "$INTERFACE" >/dev/null 2>&1; then
    CONNECTED=true
    break
  fi
  sleep 1
done

if [[ $CONNECTED == true ]]; then
  echo "✅ Successfully connected!"
  if command -v notify-send &>/dev/null; then
    notify-send "TU Wien VPN" "Connected as $FULL_USER" --icon=network-vpn
  fi
else
  echo "❌ Failed to establish connection."
  if command -v notify-send &>/dev/null; then
    notify-send "TU Wien VPN" "Connection failed" --icon=dialog-error
  fi
  exit 1
fi
