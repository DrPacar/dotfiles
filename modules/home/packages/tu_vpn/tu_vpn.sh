#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
SECRET_USER="/run/secrets/tu_vpn_user"
SECRET_PASS="/run/secrets/tu_vpn_pass"
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

# --- Disconnect Logic ---
if [[ ${1:-} == "stop" || ${1:-} == "down" ]]; then
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
fi

# --- Check if already running ---
if ip link show "$INTERFACE" >/dev/null 2>&1 || pgrep -x "openconnect" >/dev/null; then
  echo "⚠️ VPN connection already active. Run '$0 stop' to disconnect."
  exit 0
fi

# --- Get Username ---
if [[ -f $SECRET_USER ]]; then
  TU_USER=$(cat "$SECRET_USER")
else
  echo "⚠️ User secret not found at $SECRET_USER"
  read -rp "Please enter the TU-Username (e12345678): " TU_USER
fi

if [[ -z $TU_USER ]]; then
  echo "Error: No username provided."
  exit 1
fi

FULL_USER="${TU_USER}@student.tuwien.ac.at"

# --- Start VPN ---
echo "Starting TU Wien VPN for $FULL_USER in the background..."

if [[ -f $SECRET_PASS ]]; then
  echo "Using stored password from secrets..."
  sudo openconnect \
    --background \
    --useragent "AnyConnect OpenConnect" \
    --no-external-auth \
    --authgroup="$AUTH_GROUP" \
    --user "$FULL_USER" \
    --passwd-on-stdin \
    "$VPN_HOST" <"$SECRET_PASS"
else
  echo "No password secret found. You will be prompted for your password."
  sudo openconnect \
    --background \
    --useragent "AnyConnect OpenConnect" \
    --no-external-auth \
    --authgroup="$AUTH_GROUP" \
    --user "$FULL_USER" \
    "$VPN_HOST"
fi

# --- Post-Start Check & Notification ---
echo "Waiting for connection to establish..."
sleep 3

if ip link show "$INTERFACE" >/dev/null 2>&1 || pgrep -x "openconnect" >/dev/null; then
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
