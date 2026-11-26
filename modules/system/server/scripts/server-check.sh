#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Server Stack: Unified Post-Switch Health Verification CLI (`server-check`)
# =============================================================================
#
# Purpose:
#   Executes all enabled infrastructure self-tests in sequence (system-vpn,
#   arr vpn, arr qbit, adguard), verifies zero failed systemd units, checks
#   root/media storage headroom, and prints a concise traffic-light summary.
#
# Execution Context:
#   Run manually or right after `nh os switch`: `server-check [--brief]`
# =============================================================================

: "${HAS_SYSTEM_VPN:?HAS_SYSTEM_VPN is required}"
: "${HAS_ARR_VPN:?HAS_ARR_VPN is required}"
: "${HAS_ARR_QBIT:?HAS_ARR_QBIT is required}"
: "${HAS_ADGUARD:?HAS_ADGUARD is required}"
HAS_VAULTWARDEN="${HAS_VAULTWARDEN:-0}"
HAS_NOTIFY="${HAS_NOTIFY:-0}"
HAS_BESZEL="${HAS_BESZEL:-0}"
HAS_SHARES="${HAS_SHARES:-0}"
CHECK_STORAGE_PATHS="${CHECK_STORAGE_PATHS:-/}"

export PATH="${PATH:+$PATH:}/run/current-system/sw/bin"

BRIEF=0
for arg in "$@"; do
	case "$arg" in
	--brief | -b | -q)
		BRIEF=1
		;;
	-h | --help)
		cat <<'EOF'
Usage: server-check [--brief]

Runs all enabled server health checks in sequence:
  - systemd failed units check
  - storage headroom check
  - system-vpn check (if enabled)
  - arr vpn check    (if enabled)
  - arr qbit check   (if enabled)
  - adguard check      (if enabled)
  - vaultwarden check  (if enabled)
  - notify check       (if enabled)
  - beszel check       (if enabled)
  - shares check       (if enabled)

Options:
  -b, --brief   Hide individual sub-test output; show pass/fail summary only
EOF
		exit 0
		;;
	esac
done

SUDO=""
if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
	if sudo -n true 2>/dev/null; then
		SUDO="sudo"
	fi
fi

if [ -t 1 ]; then
	BOLD="\033[1m"
	GREEN="\033[0;32m"
	RED="\033[0;31m"
	YELLOW="\033[0;33m"
	CYAN="\033[0;36m"
	RESET="\033[0m"
else
	BOLD=""
	GREEN=""
	RED=""
	YELLOW=""
	CYAN=""
	RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
RESULTS=()

record_result() {
	local name="$1"
	local state="$2"
	local detail="${3:-}"
	case "$state" in
	PASS)
		PASS_COUNT=$((PASS_COUNT + 1))
		RESULTS+=("${GREEN}[PASS]${RESET} ${name}${detail:+ (${detail})}")
		;;
	FAIL)
		FAIL_COUNT=$((FAIL_COUNT + 1))
		RESULTS+=("${RED}[FAIL]${RESET} ${name}${detail:+ (${detail})}")
		;;
	SKIP)
		SKIP_COUNT=$((SKIP_COUNT + 1))
		RESULTS+=("${YELLOW}[SKIP]${RESET} ${name}${detail:+ (${detail})}")
		;;
	esac
}

run_suite() {
	local title="$1"
	shift
	local rc=0

	if [ "$BRIEF" -eq 0 ]; then
		echo -e "\n${BOLD}${CYAN}>>> ${title}${RESET}"
		"$@" || rc=$?
	else
		local out
		out=$("$@" 2>&1) || rc=$?
		if [ "$rc" -ne 0 ]; then
			echo -e "\n${BOLD}${RED}>>> ${title} (FAILED)${RESET}"
			echo "$out"
		fi
	fi

	if [ "$rc" -eq 0 ]; then
		record_result "$title" "PASS"
	else
		record_result "$title" "FAIL" "exit ${rc}"
	fi
}

echo -e "${BOLD}${CYAN}=== Server Stack Verification ($(hostname)) ===${RESET}"

# 1. Systemd Failed Units
FAILED_UNITS=$(systemctl --failed --plain --no-legend 2>/dev/null || true)
if [ -z "$FAILED_UNITS" ]; then
	record_result "systemd failed units" "PASS" "0 failed"
else
	echo -e "\n${RED}[FAIL] Failed systemd units detected:${RESET}"
	echo "$FAILED_UNITS"
	record_result "systemd failed units" "FAIL" "see above"
fi

# 2. Storage Headroom
read -ra STORAGE_PATHS <<<"$CHECK_STORAGE_PATHS"
STORAGE_FAIL=0
STORAGE_NOTES=()
for mount_path in "${STORAGE_PATHS[@]}"; do
	if [ -d "$mount_path" ]; then
		PCT=$(df -P "$mount_path" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}' || echo 0)
		AVAIL=$(df -h --output=avail "$mount_path" 2>/dev/null | awk 'NR==2 {print $1}' || echo "?")
		STORAGE_NOTES+=("${mount_path}=${PCT}% (${AVAIL} free)")
		if [[ $PCT =~ ^[0-9]+$ ]] && [ "$PCT" -ge 95 ]; then
			STORAGE_FAIL=1
		fi
	else
		STORAGE_NOTES+=("${mount_path}=missing")
		STORAGE_FAIL=1
	fi
done
if [ "$STORAGE_FAIL" -eq 0 ]; then
	record_result "storage headroom" "PASS" "${STORAGE_NOTES[*]}"
else
	record_result "storage headroom" "FAIL" "${STORAGE_NOTES[*]}"
fi

# 3. Subsystem Self-Tests
if [ "$HAS_SYSTEM_VPN" = "1" ]; then
	if [ "$EUID" -eq 0 ] || [ -n "$SUDO" ]; then
		run_suite "system-vpn check" $SUDO system-vpn check
	else
		record_result "system-vpn check" "SKIP" "requires root/sudo"
	fi
fi

if [ "$HAS_ARR_VPN" = "1" ]; then
	run_suite "arr vpn check" arr vpn check
fi

if [ "$HAS_ARR_QBIT" = "1" ]; then
	run_suite "arr qbit check" arr qbit check
fi

if [ "$HAS_ADGUARD" = "1" ]; then
	run_suite "adguard check" adguard check
fi

if [ "$HAS_VAULTWARDEN" = "1" ]; then
	if [ "$EUID" -eq 0 ] || [ -n "$SUDO" ]; then
		run_suite "vaultwarden check" $SUDO vaultwarden-ctl check
	else
		run_suite "vaultwarden check" vaultwarden-ctl check
	fi
fi

if [ "$HAS_NOTIFY" = "1" ]; then
	run_suite "notify check" ntfy-ctl check
fi

if [ "$HAS_BESZEL" = "1" ]; then
	if [ "$EUID" -eq 0 ] || [ -n "$SUDO" ]; then
		run_suite "beszel check" $SUDO beszel-ctl check
	else
		run_suite "beszel check" beszel-ctl check
	fi
fi

if [ "$HAS_SHARES" = "1" ]; then
	run_suite "shares check" shares check
fi

echo -e "\n${BOLD}${CYAN}=== Summary ===${RESET}"
for line in "${RESULTS[@]}"; do
	echo -e "  $line"
done

echo -e "${BOLD}${CYAN}===============${RESET}"
if [ "$FAIL_COUNT" -eq 0 ] && [ "$SKIP_COUNT" -eq 0 ]; then
	echo -e "${GREEN}${BOLD}ALL SERVER CHECKS PASSED (${PASS_COUNT}/${PASS_COUNT})${RESET}"
	exit 0
elif [ "$FAIL_COUNT" -eq 0 ]; then
	echo -e "${YELLOW}${BOLD}PASSED WITH ${SKIP_COUNT} SKIPPED (${PASS_COUNT} passed)${RESET}"
	exit 0
else
	echo -e "${RED}${BOLD}SERVER CHECK FAILED (${FAIL_COUNT} failed, ${PASS_COUNT} passed, ${SKIP_COUNT} skipped)${RESET}"
	exit 1
fi
