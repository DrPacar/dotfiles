#!/usr/bin/env bash
set -euo pipefail

URL=""
TOKEN_FILE=""
USER_FILE=""
PASS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --url)
    URL="$2"
    shift 2
    ;;
  --token-file)
    TOKEN_FILE="$2"
    shift 2
    ;;
  --user-file)
    USER_FILE="$2"
    shift 2
    ;;
  --pass-file)
    PASS_FILE="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z $URL || -z $TOKEN_FILE || -z $USER_FILE || -z $PASS_FILE ]]; then
  echo "Usage: $0 --url <url> --token-file <path> --user-file <path> --pass-file <path>" >&2
  exit 1
fi

if [[ ! -f $TOKEN_FILE || ! -f $USER_FILE || ! -f $PASS_FILE ]]; then
  echo "Secret files not found, skipping OpenSubtitles sync." >&2
  exit 0
fi

TOKEN=$(tr -d '\n\r' <"$TOKEN_FILE")
USER=$(tr -d '\n\r' <"$USER_FILE")
PASS=$(tr -d '\n\r' <"$PASS_FILE")

# Wait up to 30 seconds for Jellyfin API to be responsive
for _ in $(seq 1 15); do
  if curl -s -f -H "X-Emby-Token: $TOKEN" "$URL/System/Info" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

PLUGIN_ID=$(curl -s -H "X-Emby-Token: $TOKEN" "$URL/Plugins" | jq -r '.[] | select(.Name == "Open Subtitles") | .Id')
if [[ -n $PLUGIN_ID && $PLUGIN_ID != "null" ]]; then
  PAYLOAD=$(jq -n --arg user "$USER" --arg pass "$PASS" '{"Username": $user, "Password": $pass}')
  curl -s -f -X POST \
    -H "X-Emby-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$URL/Plugins/$PLUGIN_ID/Configuration" >/dev/null
  echo "OpenSubtitles credentials synchronized to Jellyfin successfully."
else
  echo "Open Subtitles plugin not found in Jellyfin."
fi
