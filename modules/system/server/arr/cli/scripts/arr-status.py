#!/usr/bin/env python3
"""
arr-status: Comprehensive CLI status monitor for the Arr media automation stack.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


def parse_args():
    parser = argparse.ArgumentParser(
        description="Monitor status and health of the Arr media automation stack."
    )
    parser.add_argument(
        "--config",
        "-c",
        required=True,
        help="Path to JSON configuration file with stack parameters.",
    )
    parser.add_argument(
        "--json",
        "-j",
        action="store_true",
        help="Output full status as JSON instead of rich terminal UI.",
    )
    parser.add_argument(
        "--watch",
        "-w",
        action="store_true",
        help="Continuously refresh and watch status (updates every 2 seconds).",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Run non-interactive health and HTTP endpoint checks for enabled Arr services.",
    )
    return parser.parse_args()


def load_config(config_path):
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)


def format_bytes(size_bytes):
    if size_bytes is None or size_bytes < 0:
        return "N/A"
    if size_bytes == 0:
        return "0 B"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    val = float(size_bytes)
    unit_idx = 0
    while val >= 1024.0 and unit_idx < len(units) - 1:
        val /= 1024.0
        unit_idx += 1
    return f"{val:.1f} {units[unit_idx]}"


def query_systemd_units(unit_names):
    """Query multiple systemd units at once via `systemctl show`."""
    if not unit_names:
        return {}

    props = [
        "Id",
        "ActiveState",
        "SubState",
        "ActiveEnterTimestamp",
        "MemoryCurrent",
        "CPUWeight",
        "IOWeight",
        "MainPID",
        "Result",
    ]
    cmd = ["systemctl", "show"] + unit_names + ["-p", ",".join(props)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except Exception:
        return {}

    units = {}
    current = {}
    for line in res.stdout.splitlines():
        line = line.strip()
        if not line:
            if "Id" in current:
                units[current["Id"]] = current
            current = {}
            continue
        if "=" in line:
            key, val = line.split("=", 1)
            current[key] = val
    if "Id" in current:
        units[current["Id"]] = current

    return units


def get_disk_info(path):
    if not os.path.exists(path):
        return None
    try:
        stat = shutil.disk_usage(path)
        percent = (stat.used / stat.total) * 100.0 if stat.total > 0 else 0.0
        return {
            "path": path,
            "total": stat.total,
            "used": stat.used,
            "free": stat.free,
            "percent": percent,
        }
    except Exception:
        return None


def get_latest_backup(backup_dir):
    p = Path(backup_dir)
    if not p.is_dir():
        return None
    archives = list(p.glob("arr-backup-*.tar.zst"))
    if not archives:
        return None
    archives.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    latest = archives[0]
    st = latest.stat()
    return {
        "name": latest.name,
        "path": str(latest),
        "size": st.st_size,
        "mtime": st.st_mtime,
        "count": len(archives),
    }


def query_vpn_telemetry(vpn_cfg):
    """Collect lightweight live telemetry for the BitTorrent VPN namespace."""
    telemetry = {
        "forwarded_port": None,
        "endpoint": None,
        "fwmark": None,
        "handshake_age_s": None,
        "outer_egress_dev": None,
    }

    port_file = vpn_cfg.get("portStateFile", "/run/protonvpn-port-forward/port")
    if port_file and os.path.isfile(port_file):
        try:
            raw_port = Path(port_file).read_text(encoding="utf-8").strip()
            if raw_port.isdigit():
                telemetry["forwarded_port"] = int(raw_port)
        except Exception:
            pass

    ns = vpn_cfg.get("namespace", "wg")
    iface = vpn_cfg.get("iface", f"{ns}0")

    prefix = []
    if os.geteuid() != 0:
        if shutil.which("sudo") and subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
            prefix = ["sudo", "-n"]
        else:
            return telemetry

    try:
        res = subprocess.run(
            prefix + ["ip", "netns", "exec", ns, "wg", "show", iface],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                stripped = line.strip()
                if stripped.startswith("endpoint:"):
                    telemetry["endpoint"] = stripped.split(":", 1)[1].strip()
                elif stripped.startswith("fwmark:"):
                    telemetry["fwmark"] = stripped.split(":", 1)[1].strip()

        hs_res = subprocess.run(
            prefix + ["ip", "netns", "exec", ns, "wg", "show", iface, "latest-handshakes"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if hs_res.returncode == 0:
            stamps = []
            for line in hs_res.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 2 and parts[1].isdigit():
                    stamps.append(int(parts[1]))
            if stamps:
                latest = max(stamps)
                if latest > 0:
                    telemetry["handshake_age_s"] = max(0, int(time.time()) - latest)

        endpoint = telemetry.get("endpoint")
        if endpoint:
            ep_ip = endpoint.rsplit(":", 1)[0].strip("[]")
            route_cmd = ["ip", "route", "get", ep_ip]
            if telemetry.get("fwmark") and telemetry["fwmark"] != "off":
                route_cmd.extend(["mark", telemetry["fwmark"]])
            route_res = subprocess.run(route_cmd, capture_output=True, text=True, timeout=2)
            if route_res.returncode == 0:
                tokens = route_res.stdout.split()
                if "dev" in tokens:
                    idx = tokens.index("dev")
                    if idx + 1 < len(tokens):
                        telemetry["outer_egress_dev"] = tokens[idx + 1]
    except Exception:
        pass

    return telemetry


def build_status_dict(config):
    services_cfg = config.get("services", {})
    all_units = []

    # Gather service units
    for s_name, s_data in services_cfg.items():
        if s_data.get("enable", False):
            if "unit" in s_data:
                all_units.append(s_data["unit"])
            if "proxyUnit" in s_data:
                all_units.append(s_data["proxyUnit"])
            if "forwarderUnit" in s_data:
                all_units.append(s_data["forwarderUnit"])
            if s_data.get("watchdogEnabled") and "watchdogUnit" in s_data:
                all_units.append(s_data["watchdogUnit"])

    # Slice unit
    all_units.append("arr.slice")

    unit_props = query_systemd_units(all_units)
    services_status = {}

    for s_name, s_data in services_cfg.items():
        enabled = s_data.get("enable", False)
        unit_name = s_data.get("unit", "")
        props = unit_props.get(unit_name, {})

        mem_bytes = None
        if "MemoryCurrent" in props:
            try:
                mem_bytes = int(props["MemoryCurrent"])
                if mem_bytes >= 18446744073709551615:  # systemd [not available] marker
                    mem_bytes = None
            except ValueError:
                mem_bytes = None

        services_status[s_name] = {
            "enabled": enabled,
            "unit": unit_name,
            "port": s_data.get("port"),
            "subdomain": s_data.get("subdomain"),
            "active_state": props.get("ActiveState", "inactive" if enabled else "disabled"),
            "sub_state": props.get("SubState", "dead"),
            "memory_bytes": mem_bytes,
            "pid": props.get("MainPID"),
        }

    slice_props = unit_props.get("arr.slice", {})
    slice_mem = None
    if "MemoryCurrent" in slice_props:
        try:
            slice_mem = int(slice_props["MemoryCurrent"])
            if slice_mem >= 18446744073709551615:
                slice_mem = None
        except ValueError:
            slice_mem = None

    slice_status = {
        "enabled": config.get("resources", {}).get("enable", True),
        "active_state": slice_props.get("ActiveState", "inactive"),
        "cpu_weight": slice_props.get("CPUWeight") or config.get("resources", {}).get("cpuWeight", 50),
        "io_weight": slice_props.get("IOWeight") or config.get("resources", {}).get("ioWeight", 50),
        "memory_high": config.get("resources", {}).get("memoryHigh", "75%"),
        "memory_bytes": slice_mem,
    }

    vpn_cfg = services_cfg.get("vpn", {})
    qbittorrent_enabled = services_cfg.get("qbittorrent", {}).get("enable", False)

    proxy_active = unit_props.get(vpn_cfg.get("proxyUnit", ""), {}).get("ActiveState", "inactive")
    if not (qbittorrent_enabled and vpn_cfg.get("enable", False)):
        proxy_active = "disabled"

    forwarder_active = unit_props.get(vpn_cfg.get("forwarderUnit", ""), {}).get("ActiveState", "inactive")
    if not (qbittorrent_enabled and vpn_cfg.get("enable", False) and vpn_cfg.get("portForwarding", False)):
        forwarder_active = "disabled"

    watchdog_active = unit_props.get(vpn_cfg.get("watchdogUnit", ""), {}).get("ActiveState", "inactive")
    if not (vpn_cfg.get("enable", False) and vpn_cfg.get("watchdogEnabled", False)):
        watchdog_active = "disabled"

    vpn_telemetry = query_vpn_telemetry(vpn_cfg) if vpn_cfg.get("enable", False) else {}

    vpn_status = {
        "enabled": vpn_cfg.get("enable", False),
        "tunnel_unit": vpn_cfg.get("unit", "wg.service"),
        "tunnel_state": unit_props.get(vpn_cfg.get("unit", "wg.service"), {}).get("ActiveState", "inactive"),
        "proxy_unit": vpn_cfg.get("proxyUnit", ""),
        "proxy_state": proxy_active,
        "forwarder_unit": vpn_cfg.get("forwarderUnit", ""),
        "forwarder_state": forwarder_active,
        "watchdog_unit": vpn_cfg.get("watchdogUnit", ""),
        "watchdog_state": watchdog_active,
        "telemetry": vpn_telemetry,
    }

    disk_info = get_disk_info(config.get("dataDir", "/arr_data"))
    backup_cfg = config.get("backup", {})
    latest_backup = get_latest_backup(backup_cfg.get("destDir", "")) if backup_cfg.get("enable", False) else None

    return {
        "host": os.uname().nodename,
        "timestamp": datetime.now().isoformat(),
        "config": config,
        "services": services_status,
        "slice": slice_status,
        "vpn": vpn_status,
        "disk": disk_info,
        "backup": {
            "enabled": backup_cfg.get("enable", False),
            "dest_dir": backup_cfg.get("destDir"),
            "calendar": backup_cfg.get("calendar"),
            "retention_days": backup_cfg.get("retentionDays"),
            "latest": latest_backup,
        },
    }


def render_rich_ui(console, data):
    console.clear()

    # 1. Header Banner
    host = data["host"]
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    data_dir = data["config"].get("dataDir", "/arr_data")
    domain = data["config"].get("domain")

    header_text = Text()
    header_text.append(" 🎬 Arr Stack Status Monitor", style="bold cyan")
    header_text.append(f"  •  Host: [bold white]{host}[/bold white]")
    if domain:
        header_text.append(f"  •  Domain: [bold magenta]{domain}[/bold magenta]")
    header_text.append(f"  •  Time: [dim]{now_str}[/dim]")
    header_text.append(f"  •  Root: [bold yellow]{data_dir}[/bold yellow]")
    console.print(Panel(header_text, border_style="cyan", box=box.ROUNDED))

    # 2. Main Applications Table
    table = Table(
        box=box.ROUNDED,
        header_style="bold magenta",
        show_edge=True,
        expand=True,
    )
    table.add_column("Application", style="bold", no_wrap=True)
    table.add_column("Status", no_wrap=True)
    table.add_column("SubState", style="dim", no_wrap=True)
    table.add_column("Memory", justify="right", no_wrap=True)
    table.add_column("Port", justify="right", no_wrap=True)
    table.add_column("Local WebUI Endpoint", style="blue")

    services = data["services"]
    display_names = {
        "jellyfin": "Jellyfin Media",
        "qbittorrent": "qBittorrent",
        "radarr": "Radarr (Movies)",
        "sonarr": "Sonarr (TV & Anime)",
        "prowlarr": "Prowlarr (Indexers)",
        "bazarr": "Bazarr (Subtitles)",
        "seerr": "Jellyseerr",
        "flaresolverr": "FlareSolverr",
        "recyclarr": "Recyclarr Sync",
    }

    for key, display_name in display_names.items():
        if key not in services:
            continue
        svc = services[key]
        enabled = svc["enabled"]
        active = svc["active_state"]
        sub = svc["sub_state"]
        mem = format_bytes(svc["memory_bytes"]) if svc["memory_bytes"] else "-"
        port = str(svc["port"]) if svc["port"] else "-"

        if not enabled:
            status_badge = Text("○ Disabled", style="dim")
            sub_badge = Text("disabled", style="dim")
            url = "-"
        elif active == "active":
            status_badge = Text("● Active", style="bold green")
            sub_badge = Text(sub, style="green")
            if svc["port"]:
                domain = data["config"].get("domain")
                if domain and svc.get("subdomain"):
                    url = f"http://{svc['subdomain']}.{domain}"
                else:
                    url = f"http://localhost:{svc['port']}"
            else:
                url = "systemd-timer"
        elif active == "failed":
            status_badge = Text("✖ Failed", style="bold red")
            sub_badge = Text(sub, style="red")
            url = "-"
        else:
            status_badge = Text("○ Inactive", style="yellow")
            sub_badge = Text(sub, style="yellow")
            url = "-"

        table.add_row(display_name, status_badge, sub_badge, mem, port, url)

    console.print(table)

    # 3. Middle Grid: VPN & Resources
    col1 = Table.grid(expand=True)
    col1.add_column()

    # VPN Box
    vpn = data["vpn"]
    vpn_text = Text()
    if vpn["enabled"]:
        def fmt_vpn(state):
            if state == "active":
                return "[green]● ACTIVE[/green]"
            elif state == "disabled":
                return "[dim]DISABLED[/dim]"
            else:
                return f"[red]● {state.upper()}[/red]"

        vpn_text.append(f"WireGuard Tunnel:  {fmt_vpn(vpn['tunnel_state'])} ({vpn['tunnel_unit']})\n")
        vpn_text.append(f"WebUI Proxy:       {fmt_vpn(vpn['proxy_state'])}\n")
        tel = vpn.get("telemetry", {})
        fwd_port = tel.get("forwarded_port")
        port_suffix = f" [bold cyan](Port {fwd_port})[/bold cyan]" if fwd_port else ""
        vpn_text.append(f"Port Forwarder:    {fmt_vpn(vpn['forwarder_state'])}{port_suffix}\n")
        vpn_text.append(f"Watchdog Timer:    {fmt_vpn(vpn.get('watchdog_state', 'disabled'))}")
        if tel.get("outer_egress_dev") or tel.get("handshake_age_s") is not None:
            egress = tel.get("outer_egress_dev") or "?"
            fwm = tel.get("fwmark") or "off"
            hs = f"{tel['handshake_age_s']}s ago" if tel.get("handshake_age_s") is not None else "n/a"
            vpn_text.append(f"\nTunnel Path:       [bold white]{egress}[/bold white] (fwmark {fwm}, handshake {hs})")
    else:
        vpn_text.append("VPN Isolation: [dim]Disabled[/dim] (qBittorrent running on host network)")

    # Slice Box
    slice_data = data["slice"]
    slice_text = Text()
    if slice_data["enabled"]:
        s_color = "green" if slice_data["active_state"] == "active" else "dim"
        s_mem = format_bytes(slice_data["memory_bytes"]) if slice_data["memory_bytes"] else "0 B"
        slice_text.append(f"Status:      [{s_color}]● {slice_data['active_state'].upper()}[/{s_color}] (arr.slice)\n")
        slice_text.append(f"Total RAM:   [bold cyan]{s_mem}[/bold cyan] (Throttle limit: {slice_data['memory_high']})\n")
        slice_text.append(f"Priority:    CPUWeight=[bold]{slice_data['cpu_weight']}[/bold]  •  IOWeight=[bold]{slice_data['io_weight']}[/bold] (Desktop protected)")
    else:
        slice_text.append("Resource Management: [dim]Disabled (services run in system.slice)[/dim]")

    mid_table = Table(box=box.ROUNDED, expand=True, show_header=True, header_style="bold yellow")
    mid_table.add_column("🛡️  VPN & Isolation")
    mid_table.add_column("⚖️  CGroup Resource Management (Slice)")
    mid_table.add_row(vpn_text, slice_text)
    console.print(mid_table)

    # 4. Storage & Backups
    disk = data["disk"]
    disk_text = Text()
    if disk:
        pct = disk["percent"]
        bar_len = 24
        filled = int((pct / 100.0) * bar_len)
        bar = "█" * filled + "░" * (bar_len - filled)
        bar_color = "green" if pct < 80 else ("yellow" if pct < 90 else "red")

        disk_text.append(f"Mount: [bold white]{disk['path']}[/bold white]\n")
        disk_text.append(f"Usage: [{bar_color}][{bar}] {pct:.1f}%[/{bar_color}]\n")
        disk_text.append(f"Used:  {format_bytes(disk['used'])} / {format_bytes(disk['total'])} ({format_bytes(disk['free'])} free)")
    else:
        disk_text.append(f"Directory {data_dir} not mounted or not found.")

    backup = data["backup"]
    backup_text = Text()
    if backup["enabled"]:
        backup_text.append("Status:    [bold green]● Enabled[/bold green] (systemd timer)\n")
        backup_text.append(f"Schedule:  {backup['calendar']} (Retain: {backup['retention_days']} days)\n")
        latest = backup["latest"]
        if latest:
            mtime_dt = datetime.fromtimestamp(latest["mtime"]).strftime("%Y-%m-%d %H:%M")
            backup_text.append(f"Latest:    [bold cyan]{latest['name']}[/bold cyan] ({format_bytes(latest['size'])}, {mtime_dt})")
        else:
            backup_text.append("Latest:    [dim]No backup archives found yet[/dim]")
    else:
        backup_text.append("Status:    [dim]Disabled[/dim]\n")
        backup_text.append(f"Storage:   {backup.get('dest_dir', '-')}\n")
        backup_text.append("Hint:      Enable via arr.backup.enable = true")

    bottom_table = Table(box=box.ROUNDED, expand=True, show_header=True, header_style="bold green")
    bottom_table.add_column("💾 Storage Footprint")
    bottom_table.add_column("📦 Automated Backups")
    bottom_table.add_row(disk_text, backup_text)
    console.print(bottom_table)

    # 5. Footer Quick Commands
    footer = Text("💡 Commands: ", style="bold dim")
    footer.append("systemctl restart <service>  •  ", style="dim")
    footer.append("systemctl start arr-backup.service  •  ", style="dim")
    footer.append("journalctl -u <service> -f", style="dim")
    console.print(Panel(footer, border_style="dim", box=box.ROUNDED))


def http_probe(url: str, timeout: int = 5) -> tuple[bool, str]:
    """Probe an HTTP endpoint and treat HTTP < 400 as healthy."""
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return (resp.status < 400, f"HTTP {resp.status}")
    except urllib.error.HTTPError as exc:
        return (exc.code < 400, f"HTTP {exc.code}")
    except Exception as exc:
        return (False, str(exc))


def run_checks(config: dict) -> int:
    """Run non-interactive systemd, HTTP, storage, and transcode checks."""
    data = build_status_dict(config)
    local_addr = config.get("localAddress") or "127.0.0.1"
    failures = 0

    def report(ok: bool, label: str, detail: str) -> None:
        nonlocal failures
        tag = "[OK]" if ok else "[FAIL]"
        print(f"{tag:6s} {label}: {detail}")
        if not ok:
            failures += 1

    probes = {
        "jellyfin": "/health",
        "qbittorrent": "/api/v2/app/version",
        "radarr": "/ping",
        "sonarr": "/ping",
        "prowlarr": "/ping",
        "bazarr": "/",
        "seerr": "/api/v1/status",
        "flaresolverr": "/",
    }

    for svc_name, svc in data["services"].items():
        if not svc["enabled"]:
            continue
        active = svc["active_state"]
        sub = svc["sub_state"]
        if svc_name == "recyclarr":
            ok_unit = active != "failed"
            report(ok_unit, svc["unit"], f"state={active}/{sub}")
            continue

        ok_unit = active == "active"
        report(ok_unit, svc["unit"], f"state={active}/{sub}")

        port = svc.get("port")
        path = probes.get(svc_name)
        if port and path and ok_unit:
            url = f"http://{local_addr}:{port}{path}"
            ok_http, detail = http_probe(url)
            report(ok_http, f"{svc_name} http", f"{url} -> {detail}")

    data_dir = config.get("dataDir")
    if data_dir:
        report(os.path.isdir(data_dir), "arr dataDir", data_dir)

    transcode_dir = config.get("transcodingTempPath")
    if transcode_dir and os.path.exists(transcode_dir):
        usage = shutil.disk_usage(transcode_dir)
        pct = (usage.used / usage.total) * 100.0 if usage.total else 0.0
        report(pct < 85.0, "jellyfin transcode tmpfs", f"{transcode_dir} {pct:.1f}% full ({format_bytes(usage.used)} / {format_bytes(usage.total)})")

    if data["backup"]["enabled"]:
        b_units = query_systemd_units(["arr-backup.service", "arr-backup.timer"])
        b_svc = b_units.get("arr-backup.service", {}).get("ActiveState", "inactive")
        b_tmr = b_units.get("arr-backup.timer", {}).get("ActiveState", "inactive")
        report(b_svc != "failed" and b_tmr == "active", "arr-backup", f"service={b_svc}, timer={b_tmr}")

    return 1 if failures else 0


def main():
    args = parse_args()
    config = load_config(args.config)

    if args.check:
        sys.exit(run_checks(config))

    console = Console()

    if args.json:
        data = build_status_dict(config)
        print(json.dumps(data, indent=2))
        return

    if args.watch:
        try:
            while True:
                data = build_status_dict(config)
                render_rich_ui(console, data)
                time.sleep(2)
        except KeyboardInterrupt:
            console.print("\n[dim]Monitoring stopped.[/dim]")
            sys.exit(0)
    else:
        data = build_status_dict(config)
        render_rich_ui(console, data)


if __name__ == "__main__":
    main()
