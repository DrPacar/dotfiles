#!/usr/bin/env python3
"""
dashboard-api.py

Lightweight HTTP daemon providing real-time system metrics and service health checks
for the Arr stack dashboard landing page.
Zero external dependencies; runs on Python standard library.
"""

from __future__ import annotations

import argparse
import http.server
import json
import logging
import socket
import sys
import threading
import time

LOG_FORMAT = "[dashboard-api] %(levelname)-5s: %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("dashboard-api")


def format_speed(bytes_per_sec: float) -> str:
    """Format bytes per second into human-readable transfer rate."""
    if bytes_per_sec < 0:
        bytes_per_sec = 0.0
    units = ["B/s", "KB/s", "MB/s", "GB/s"]
    val = float(bytes_per_sec)
    unit_idx = 0
    while val >= 1000.0 and unit_idx < len(units) - 1:
        val /= 1000.0
        unit_idx += 1
    if unit_idx == 0:
        return f"{int(val)} B/s"
    return f"{val:.1f} {units[unit_idx]}"


class MetricsCollector:
    """Collects network throughput rates and service connectivity in background."""

    def __init__(self, services_map: dict[str, int]):
        self.services_map = services_map
        self.lock = threading.Lock()
        self.rx_rate = 0.0
        self.tx_rate = 0.0
        self.last_rx, self.last_tx = self._read_net_bytes()
        self.last_time = time.monotonic()
        self.service_statuses = self._check_services()

        # Run background sampling loop
        self.running = True
        self.worker_thread = threading.Thread(target=self._sampling_loop, daemon=True)
        self.worker_thread.start()

    def _read_net_bytes(self) -> tuple[int, int]:
        """Read total received and transmitted bytes across physical and VPN interfaces."""
        rx_total, tx_total = 0, 0
        try:
            with open("/proc/net/dev", "r", encoding="utf-8") as f:
                lines = f.readlines()[2:]
            for line in lines:
                parts = line.split(":")
                if len(parts) == 2:
                    iface = parts[0].strip()
                    # Skip loopback and internal virtual bridge interfaces
                    if iface in ("lo", "virbr0") or iface.startswith("veth") or iface.startswith("docker"):
                        continue
                    vals = parts[1].split()
                    rx_total += int(vals[0])
                    tx_total += int(vals[8])
        except Exception as exc:
            logger.debug(f"Error reading /proc/net/dev: {exc}")
        return rx_total, tx_total

    def _check_services(self) -> dict[str, str]:
        """Probe local TCP listening ports for each registered service."""
        statuses: dict[str, str] = {}
        for name, port in self.services_map.items():
            if not port:
                continue
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.15):
                    statuses[name] = "online"
            except Exception:
                statuses[name] = "offline"
        return statuses

    def _sampling_loop(self) -> None:
        """Periodic background loop measuring bandwidth and service availability."""
        service_check_counter = 0
        while self.running:
            time.sleep(1.0)
            now = time.monotonic()
            dt = now - self.last_time
            if dt <= 0:
                continue

            current_rx, current_tx = self._read_net_bytes()
            rx_diff = current_rx - self.last_rx
            tx_diff = current_tx - self.last_tx

            # Update rates
            with self.lock:
                self.rx_rate = max(0.0, rx_diff / dt)
                self.tx_rate = max(0.0, tx_diff / dt)
                self.last_rx = current_rx
                self.last_tx = current_tx
                self.last_time = now

            # Probe services every 2 seconds
            service_check_counter += 1
            if service_check_counter >= 2:
                service_check_counter = 0
                statuses = self._check_services()
                with self.lock:
                    self.service_statuses = statuses

    def get_stats(self) -> dict:
        """Returns snapshot of current metrics."""
        with self.lock:
            return {
                "network": {
                    "down": format_speed(self.rx_rate),
                    "up": format_speed(self.tx_rate),
                    "raw_down": int(self.rx_rate),
                    "raw_up": int(self.tx_rate),
                },
                "services": dict(self.service_statuses),
            }


class StatsHandler(http.server.BaseHTTPRequestHandler):
    collector: MetricsCollector

    def do_GET(self) -> None:
        if self.path in ("/api/stats", "/api/stats/", "/stats"):
            data = self.collector.get_stats()
            body = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/healthz", "/health", "/ping"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format: str, *args) -> None:
        # Suppress routine request logs to keep systemd journal clean
        pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Arr Stack Dashboard Stats API")
    parser.add_argument("--port", type=int, default=9095, help="HTTP listen port (default: 9095)")
    parser.add_argument("--bind", type=str, default="127.0.0.1", help="Bind IP address (default: 127.0.0.1)")
    parser.add_argument(
        "--services",
        type=str,
        default="{}",
        help="JSON string mapping service names to local ports",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        services_map = json.loads(args.services)
    except json.JSONDecodeError as exc:
        logger.error(f"Failed to parse --services JSON: {exc}")
        services_map = {}

    collector = MetricsCollector(services_map)
    StatsHandler.collector = collector

    server_address = (args.bind, args.port)
    httpd = http.server.ThreadingHTTPServer(server_address, StatsHandler)
    logger.info(f"Dashboard Stats API listening on http://{args.bind}:{args.port}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        collector.running = False
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
