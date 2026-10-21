#!/usr/bin/env bash
# =============================================================================
# wait-for-internet.sh
# Gracefully waits for network connectivity and DNS resolution before starting
# oneshot network-dependent services at boot (e.g., Recyclarr git syncing).
# Prevents race conditions when Wi-Fi / DHCP is still associating.
# =============================================================================
set -euo pipefail

# --- Logging Helpers ---
log_info() { echo "[$SERVICE_NAME] INFO:  $*"; }
log_warn() { echo "[$SERVICE_NAME] WARN:  $*" >&2; }
log_err() { echo "[$SERVICE_NAME] ERROR: $*" >&2; }

# --- Defaults ---
SERVICE_NAME="wait-for-internet"
TARGET_URL="https://github.com"
MAX_WAIT_SEC=60
RETRY_INTERVAL_SEC=2

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  --service-name)
    SERVICE_NAME="${2:-wait-for-internet}"
    shift 2
    ;;
  --url)
    TARGET_URL="${2:-https://github.com}"
    shift 2
    ;;
  --timeout)
    MAX_WAIT_SEC="${2:-60}"
    shift 2
    ;;
  --interval)
    RETRY_INTERVAL_SEC="${2:-2}"
    shift 2
    ;;
  *)
    log_warn "Unknown parameter: $1"
    shift
    ;;
  esac
done

log_info "Verifying network & DNS connectivity via $TARGET_URL (timeout: ${MAX_WAIT_SEC}s)..."

WAITED=0
while [[ $WAITED -lt $MAX_WAIT_SEC ]]; do
  # Perform a fast HTTP HEAD request with 2s timeout
  if curl -s -f -I -m 2 "$TARGET_URL" >/dev/null 2>&1; then
    log_info "Network and DNS are reachable (took ${WAITED}s)."
    exit 0
  fi

  sleep "$RETRY_INTERVAL_SEC"
  WAITED=$((WAITED + RETRY_INTERVAL_SEC))
done

log_err "Network and DNS unreachable at $TARGET_URL after ${MAX_WAIT_SEC}s."
exit 1
