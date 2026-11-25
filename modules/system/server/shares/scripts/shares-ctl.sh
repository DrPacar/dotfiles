#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Network Shares: Telemetry, Health Self-Test & Mount Control CLI (`shares`)
# =============================================================================
#
# Purpose:
#   Provides declarative inspection, health checks, and on-demand mount/unmount
#   operations for all configured `networking.shares.entries` without any
#   hardcoded share names or server addresses.
# =============================================================================

: "${SHARES_MANIFEST_FILE:?SHARES_MANIFEST_FILE environment variable is required}"

usage() {
	cat <<'EOF'
Usage: shares <command> [options]

Commands:
  status [--fast]    Show configured shares, automount/mount state, symlinks, and SMB reachability
  check [--online]   Run automated verification checks (add --online to verify live SMB reachability)
  mount [name]       Mount a specific remote share or all configured remote shares
  umount [name]      Unmount a specific remote share or all mounted remote shares
EOF
}

if [ -t 1 ]; then
	BOLD=$'\033[1m'
	GREEN=$'\033[0;32m'
	RED=$'\033[0;31m'
	YELLOW=$'\033[0;33m'
	CYAN=$'\033[0;36m'
	RESET=$'\033[0m'
else
	BOLD=""
	GREEN=""
	RED=""
	YELLOW=""
	CYAN=""
	RESET=""
fi

CMD="${1:-status}"
shift || true

case "$CMD" in
-h | --help | help)
	usage
	exit 0
	;;
status | check | mount | umount | unmount)
	;;
*)
	usage >&2
	exit 1
	;;
esac

exec python3 - "$CMD" "$BOLD" "$GREEN" "$RED" "$YELLOW" "$CYAN" "$RESET" "$@" <<'PY'
import json
import os
import shutil
import socket
import subprocess
import sys

cmd = sys.argv[1]
if cmd == "unmount":
    cmd = "umount"
BOLD, GREEN, RED, YELLOW, CYAN, RESET = sys.argv[2:8]
args = sys.argv[8:]

with open(os.environ["SHARES_MANIFEST_FILE"], "r", encoding="utf-8") as fh:
    entries = json.load(fh)


def run(argv):
    return subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def unit_name(path, suffix):
    res = run(["systemd-escape", "-p", f"--suffix={suffix}", path])
    return res.stdout.strip()


def tcp_reachable(host, port=445, timeout=2.0):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def findmnt_info(mount_point):
    res = run(["findmnt", "-n", "-P", "-t", "cifs", "-M", mount_point, "-o", "FSTYPE,SOURCE,OPTIONS"])
    if res.returncode != 0 or not res.stdout.strip():
        return None
    return res.stdout.strip()


def unit_state(unit):
    res = run(["systemctl", "is-active", unit])
    state = res.stdout.strip() or res.stderr.strip() or "inactive"
    return res.returncode == 0, state


def unit_failed(unit):
    return run(["systemctl", "is-failed", "--quiet", unit]).returncode == 0


def target_entries(filter_name=None):
    if filter_name is None:
        return entries
    matched = [e for e in entries if e["name"] == filter_name]
    if not matched:
        print(f"ERROR: Share entry '{filter_name}' is not configured or disabled.", file=sys.stderr)
        sys.exit(1)
    return matched


if cmd == "status":
    fast = "--fast" in args or "--no-probe" in args
    print(f"{BOLD}{CYAN}=== Network Shares Status ==={RESET}")
    if not entries:
        print("  No enabled share entries configured.")
        sys.exit(0)

    for e in entries:
        name = e["name"]
        mode = e["mode"]
        print(f"\n{BOLD}[{name}]{RESET} ({mode})")
        print(f"  User/Group:   {e['user']}:{e['group']}")

        if mode == "local":
            lp = e["localPath"]
            exists = os.path.isdir(lp)
            state_str = f"{GREEN}directory present{RESET}" if exists else f"{RED}missing{RESET}"
            print(f"  Local Path:   {lp} ({state_str})")
        else:
            host = e["host"]
            mp = e["mountPoint"]
            am_unit = unit_name(mp, "automount")
            mnt_unit = unit_name(mp, "mount")
            am_ok, am_state = unit_state(am_unit)
            mnt_info = findmnt_info(mp)

            print(f"  Remote UNC:   //{host}/{e['shareName']} ({e['authMode']}, SMB {e['smbVersion']})")
            print(f"  Mount Point:  {mp}")
            am_color = GREEN if am_ok else RED
            print(f"  Automount:    {am_color}{am_state}{RESET} ({am_unit})")
            if mnt_info:
                print(f"  Active Mount: {GREEN}mounted{RESET} ({mnt_info})")
            elif unit_failed(mnt_unit):
                print(f"  Active Mount: {RED}failed{RESET} ({mnt_unit})")
            else:
                print(f"  Active Mount: {YELLOW}idle (on-demand){RESET}")
            if not fast:
                reach = tcp_reachable(host, 445, timeout=2.0)
                reach_str = f"{GREEN}reachable (TCP 445){RESET}" if reach else f"{YELLOW}unreachable (TCP 445){RESET}"
                print(f"  Server Probe: {reach_str}")

        sp = e.get("symlinkPath")
        if sp:
            tp = e["targetPath"]
            if os.path.islink(sp):
                cur = os.readlink(sp)
                if cur == tp:
                    print(f"  Symlink:      {GREEN}{sp} -> {cur}{RESET}")
                else:
                    print(f"  Symlink:      {RED}{sp} -> {cur} (expected {tp}){RESET}")
            elif os.path.exists(sp):
                print(f"  Symlink:      {RED}{sp} exists but is not a symlink{RESET}")
            else:
                print(f"  Symlink:      {RED}{sp} missing{RESET}")
    sys.exit(0)

if cmd == "check":
    online = "--online" in args
    print(f"{BOLD}{CYAN}=== Network Shares Self-Test ==={RESET}")
    if not entries:
        print(f"  {YELLOW}[SKIP]{RESET} No enabled share entries configured.")
        sys.exit(0)

    failures = 0

    def check(label, ok, detail=""):
        global failures
        if ok:
            print(f"  {GREEN}[PASS]{RESET} {label}" + (f" ({detail})" if detail else ""))
        else:
            failures += 1
            print(f"  {RED}[FAIL]{RESET} {label}" + (f" ({detail})" if detail else ""))

    for e in entries:
        name = e["name"]
        mode = e["mode"]
        if mode == "local":
            lp = e["localPath"]
            check(f"{name}: local path exists", os.path.isdir(lp), lp)
        else:
            mp = e["mountPoint"]
            host = e["host"]
            am_unit = unit_name(mp, "automount")
            mnt_unit = unit_name(mp, "mount")

            check(f"{name}: mount.cifs available", shutil.which("mount.cifs") is not None)
            check(f"{name}: mountPoint directory exists", os.path.isdir(mp), mp)
            am_ok, am_state = unit_state(am_unit)
            check(f"{name}: automount unit active", am_ok and not unit_failed(am_unit), f"{am_unit}={am_state}")
            check(f"{name}: mount unit not failed", not unit_failed(mnt_unit), mnt_unit)

            mounted = findmnt_info(mp) is not None
            if online or mounted:
                reach = tcp_reachable(host, 445, timeout=2.0)
                check(f"{name}: SMB port 445 reachable on {host}", reach)
                if reach:
                    if not mounted:
                        run(["systemctl", "start", mnt_unit])
                    ls_res = run(["timeout", "5", "ls", "-A", mp])
                    check(f"{name}: mounted share readable", ls_res.returncode == 0, mp)

        sp = e.get("symlinkPath")
        if sp:
            tp = e["targetPath"]
            link_ok = os.path.islink(sp) and os.readlink(sp) == tp
            check(f"{name}: symlink points to target", link_ok, f"{sp} -> {tp}")

    print()
    if failures == 0:
        print(f"{GREEN}{BOLD}ALL SHARE CHECKS PASSED{RESET}")
        sys.exit(0)
    else:
        print(f"{RED}{BOLD}SHARE CHECKS FAILED ({failures} error(s)){RESET}")
        sys.exit(1)

if cmd in ("mount", "umount"):
    target = args[0] if args else None
    selected = [e for e in target_entries(target) if e["mode"] == "cifs"]
    if not selected:
        print("No remote CIFS shares selected.")
        sys.exit(0)

    action = "start" if cmd == "mount" else "stop"
    rc = 0
    for e in selected:
        mnt_unit = unit_name(e["mountPoint"], "mount")
        print(f"{'Mounting' if cmd == 'mount' else 'Unmounting'} '{e['name']}' ({mnt_unit})...")
        res = run(["systemctl", action, mnt_unit])
        if res.returncode != 0:
            print(res.stderr.strip() or f"Failed to {action} {mnt_unit}", file=sys.stderr)
            rc = 1
    sys.exit(rc)
PY
