#!/usr/bin/env bash
# File inspired by MrSom3body (github.com/MrSom3body/dotfiles)
set -euo pipefail

AUTO_SELECT=1
TARGET_DEVICE=""
TEXT_TO_SEND=""
ITEMS=()

show_help() {
  cat <<EOF
Usage: send_file [OPTIONS] [FILE/URL...]

Send files, URLs, or text to a KDE Connect device.

Options:
  -d, --device <NAME|ID>   Send directly to device matching name or ID
  -n, --no-auto            Disable auto-selecting the device when only one is available
  -t, --text <TEXT>        Send text content instead of a file
  -h, --help               Show this help message and exit

Examples:
  send_file file1.txt file2.jpg
  send_file https://google.com
  send_file -d "Pixel" document.pdf
  send_file -t "Copied text snippet"
  echo "Hello from terminal" | send_file
  send_file --no-auto file.txt
EOF
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    show_help
    exit 0
    ;;
  -n | --no-auto)
    AUTO_SELECT=0
    shift
    ;;
  -d | --device)
    if [[ -z ${2:-} ]]; then
      echo "Error: Option '$1' requires an argument."
      exit 1
    fi
    TARGET_DEVICE="$2"
    shift 2
    ;;
  -t | --text)
    if [[ -z ${2:-} ]]; then
      echo "Error: Option '$1' requires an argument."
      exit 1
    fi
    TEXT_TO_SEND="$2"
    shift 2
    ;;
  --)
    shift
    while [[ $# -gt 0 ]]; do
      ITEMS+=("$1")
      shift
    done
    break
    ;;
  -*)
    echo "Error: Unknown option '$1'"
    echo
    show_help
    exit 1
    ;;
  *)
    ITEMS+=("$1")
    shift
    ;;
  esac
done

# --- Check Piped Input (Stdin) ---
if [[ ${#ITEMS[@]} -eq 0 && -z $TEXT_TO_SEND ]]; then
  if [[ ! -t 0 ]]; then
    STDIN_DATA=$(cat)
    if [[ -n $STDIN_DATA ]]; then
      if [[ $STDIN_DATA =~ ^https?:// ]] || [[ -f $STDIN_DATA ]]; then
        ITEMS+=("$STDIN_DATA")
      else
        TEXT_TO_SEND="$STDIN_DATA"
      fi
    fi
  fi
fi

if [[ ${#ITEMS[@]} -eq 0 && -z $TEXT_TO_SEND ]]; then
  echo "Error: No files, URLs, or text specified to send."
  echo
  show_help
  exit 1
fi

# --- Device Discovery & Refresh ---
get_devices() {
  kdeconnect-cli -a --id-name-only 2>/dev/null | grep . || true
}

DEVICES=$(get_devices)

if [[ -z $DEVICES ]]; then
  echo "🔍 No reachable devices found. Refreshing KDE Connect..."
  kdeconnect-cli --refresh 2>/dev/null || true
  sleep 1.5
  DEVICES=$(get_devices)
fi

DEVICE_COUNT=$(echo "$DEVICES" | grep -c . || true)

if [[ $DEVICE_COUNT -eq 0 ]]; then
  echo "❌ No KDE Connect devices found or reachable."
  echo "   Make sure the device is paired, KDE Connect is running, and both devices are on the same network."
  exit 1
fi

# --- Device Selection ---
if [[ -n $TARGET_DEVICE ]]; then
  MATCH=$(echo "$DEVICES" | grep -i "$TARGET_DEVICE" | head -n 1 || true)
  if [[ -z $MATCH ]]; then
    echo "❌ Device '$TARGET_DEVICE' not found in reachable devices:"
    echo "$DEVICES" | cut -d' ' -f2- | sed 's/^/   - /'
    exit 1
  fi
  DEVICE_ID=$(echo "$MATCH" | awk '{print $1}')
  DEVICE_NAME=$(echo "$MATCH" | cut -d' ' -f2-)
  echo "📱 Target device: $DEVICE_NAME"
elif [[ $DEVICE_COUNT -eq 1 && $AUTO_SELECT -eq 1 ]]; then
  DEVICE_ID=$(echo "$DEVICES" | awk '{print $1}')
  DEVICE_NAME=$(echo "$DEVICES" | cut -d' ' -f2-)
  echo "📱 Auto-selecting device: $DEVICE_NAME"
else
  SELECTION=$(echo "$DEVICES" | fzf \
    --prompt="📱 Send to: " \
    --with-nth=2.. \
    --border=rounded \
    --layout=reverse \
    --info=hidden \
    --header=" KDE Connect Devices " </dev/tty)
  if [[ -z $SELECTION ]]; then
    echo "No device selected. Aborting."
    exit 1
  fi
  DEVICE_ID=$(echo "$SELECTION" | awk '{print $1}')
  DEVICE_NAME=$(echo "$SELECTION" | cut -d' ' -f2-)
fi

# --- Sending Items ---
SUCCESS_COUNT=0
ERROR_COUNT=0

if [[ -n $TEXT_TO_SEND ]]; then
  echo "💬 Sending text to $DEVICE_NAME..."
  if kdeconnect-cli -d "$DEVICE_ID" --share-text "$TEXT_TO_SEND" 2>/dev/null; then
    ((SUCCESS_COUNT++))
  else
    echo "❌ Failed to send text."
    ((ERROR_COUNT++))
  fi
fi

for item in "${ITEMS[@]}"; do
  if [[ $item =~ ^https?:// ]]; then
    echo "🔗 Sending URL: $item"
    if kdeconnect-cli -d "$DEVICE_ID" --share "$item" 2>/dev/null; then
      ((SUCCESS_COUNT++))
    else
      echo "❌ Failed to send URL: $item"
      ((ERROR_COUNT++))
    fi
  elif [[ -f $item ]]; then
    ABS_PATH=$(realpath "$item")
    echo "📄 Sending file: $(basename "$ABS_PATH")"
    if kdeconnect-cli -d "$DEVICE_ID" --share "$ABS_PATH" 2>/dev/null; then
      ((SUCCESS_COUNT++))
    else
      echo "❌ Failed to send file: $(basename "$ABS_PATH")"
      ((ERROR_COUNT++))
    fi
  elif [[ -d $item ]]; then
    echo "⚠️ Warning: '$item' is a directory. KDE Connect only supports individual files or URLs."
    ((ERROR_COUNT++))
  else
    echo "⚠️ Warning: '$item' not found (neither an existing file nor a valid URL). Skipping."
    ((ERROR_COUNT++))
  fi
done

# --- Notifications ---
if [[ $SUCCESS_COUNT -gt 0 ]]; then
  echo "✅ Successfully sent $SUCCESS_COUNT item(s) to $DEVICE_NAME."
  if command -v notify-send &>/dev/null; then
    notify-send "KDE Connect" "Sent $SUCCESS_COUNT item(s) to $DEVICE_NAME" --icon=kdeconnect || true
  fi
fi

if [[ $ERROR_COUNT -gt 0 && $SUCCESS_COUNT -eq 0 ]]; then
  if command -v notify-send &>/dev/null; then
    notify-send "KDE Connect" "Failed to send item(s) to $DEVICE_NAME" --icon=dialog-error || true
  fi
  exit 1
fi
