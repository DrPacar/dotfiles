#!/usr/bin/env python3
"""
arr-notify.py: Unified notification dispatcher for Arr stack (Sonarr, Radarr) and qBittorrent.
Formats and sends rich notification messages with resolution, languages, audio codecs, and status
to a self-hosted ntfy server.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional, Tuple

logging.basicConfig(level=logging.INFO, format="[arr-notify] %(levelname)s: %(message)s")
logger = logging.getLogger("arr-notify")


def parse_release_meta(release_title: str, quality_str: str = "") -> Tuple[str, str, str, str]:
    """
    Parses resolution, languages, HDR formats, and audio codecs from a release or filename string.
    """
    text = (release_title + " " + quality_str).lower()

    # 1. Resolution
    res = "Unbekannt"
    if any(k in text for k in ["2160p", "4k", "uhd"]):
        res = "2160p (4K UHD)"
    elif "1080p" in text:
        res = "1080p (Full HD)"
    elif "720p" in text:
        res = "720p (HD)"
    elif any(k in text for k in ["480p", "576p", "sd"]):
        res = "SD (480p/576p)"
    elif quality_str:
        res = quality_str

    # 2. Languages
    langs = []
    if any(k in text for k in ["german", "ger.", ".ger", "deutsch", "dubbed", ".dl.", "dual"]):
        langs.append("Deutsch")
    if any(k in text for k in ["english", "eng.", ".eng"]):
        langs.append("Englisch")
    if any(k in text for k in ["japanese", "jap.", ".jap"]):
        langs.append("Japanisch")
    if not langs:
        if "multi" in text:
            langs.append("Multi-Audio")
        else:
            langs.append("Englisch (Original)")

    # 3. HDR / Video
    hdr = []
    if any(k in text for k in ["dv", "dolby vision", "dolby.vision"]):
        hdr.append("Dolby Vision")
    if "hdr10+" in text:
        hdr.append("HDR10+")
    elif "hdr" in text:
        hdr.append("HDR10")

    # 4. Audio Codecs
    audio = []
    if any(k in text for k in ["atmos", "truehd"]):
        audio.append("Dolby Atmos / TrueHD")
    elif any(k in text for k in ["dts-hd", "dts.hd", "dts-hd.ma"]):
        audio.append("DTS-HD MA")
    elif "dts" in text:
        audio.append("DTS")
    elif any(k in text for k in ["eac3", "ddp", "dd+"]):
        audio.append("DDP / E-AC-3")
    elif any(k in text for k in ["ac3", "dd5.1", "dd 5.1"]):
        audio.append("Dolby Digital 5.1")
    elif "flac" in text:
        audio.append("FLAC")
    elif "aac" in text:
        audio.append("AAC")

    return res, ", ".join(langs), " / ".join(hdr), " / ".join(audio)


def format_size(bytes_val: int | float | str | None) -> str:
    """Formats bytes into human readable GiB / MiB."""
    if not bytes_val:
        return "Unbekannt"
    try:
        b = float(bytes_val)
        if b >= 1024**3:
            return f"{b / (1024**3):.2f} GB"
        if b >= 1024**2:
            return f"{b / (1024**2):.1f} MB"
        return f"{b / 1024:.0f} KB"
    except (ValueError, TypeError):
        return str(bytes_val)


def send_ntfy(
    url: str,
    title: str,
    body: str,
    tags: str = "",
    priority: str = "default",
    click_url: Optional[str] = None,
) -> bool:
    """Sends notification to ntfy server via HTTP POST."""
    try:
        headers = {
            "Title": title.encode("utf-8"),
            "Priority": priority,
        }
        if tags:
            headers["Tags"] = tags
        if click_url:
            headers["Click"] = click_url

        data = body.encode("utf-8")
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")

        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status == 200:
                logger.info("Notification sent successfully to %s: %s", url, title)
                return True
            logger.warning("ntfy returned unexpected status %s", resp.status)
            return False
    except urllib.error.URLError as err:
        logger.warning("Could not reach ntfy server (%s): %s", url, err)
        return False
    except Exception as err:
        logger.warning("Error dispatching notification: %s", err)
        return False


def handle_radarr(ntfy_url: str, jellyfin_url: str):
    """Processes Radarr Custom Script events."""
    event = os.environ.get("radarr_eventtype", "")
    movie_title = os.environ.get("radarr_movie_title", "Unbekannter Film")
    movie_year = os.environ.get("radarr_movie_year", "")
    full_title = f"{movie_title} ({movie_year})" if movie_year else movie_title

    release_title = os.environ.get("radarr_release_title") or os.environ.get("radarr_moviefile_scenename", "")
    quality_str = os.environ.get("radarr_release_quality") or os.environ.get("radarr_moviefile_quality", "")
    size_str = format_size(os.environ.get("radarr_release_size") or os.environ.get("radarr_moviefile_size"))

    res, langs, hdr, audio = parse_release_meta(release_title, quality_str)

    if event == "Grab":
        title = f"📥 Wird heruntergeladen: {full_title}"
        body_lines = [
            f"🎬 Film: {full_title}",
            f"📺 Auflösung: {res}" + (f" ({hdr})" if hdr else ""),
            f"🔊 Sprache: {langs}",
        ]
        if audio:
            body_lines.append(f"🎧 Audio: {audio}")
        body_lines.append(f"📦 Größe: {size_str} | Client: qBittorrent")

        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join(body_lines),
            tags="arrow_down,movie",
            priority="default",
        )

    elif event in ("Download", "Upgrade"):
        is_upgrade = event == "Upgrade"
        prefix = "✨ Qualitäts-Upgrade" if is_upgrade else "✅ Fertig heruntergeladen"
        title = f"{prefix}: {full_title}"
        body_lines = [
            f"🎬 Film: {full_title}",
            f"📺 Qualität: {res}" + (f" ({hdr})" if hdr else ""),
            f"🔊 Sprache: {langs}",
            f"📦 Größe: {size_str}",
            "",
            "Ab sofort auf Jellyfin verfügbar!",
        ]
        tags = "sparkles,movie" if is_upgrade else "white_check_mark,popcorn"
        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join(body_lines),
            tags=tags,
            priority="default",
            click_url=jellyfin_url,
        )

    elif event == "HealthIssue":
        msg = os.environ.get("radarr_health_issue_message", "Health-Problem gemeldet")
        title = "⚠️ Radarr Warnung"
        send_ntfy(
            url=ntfy_url,
            title=title,
            body=f"Meldung: {msg}",
            tags="warning",
            priority="high",
        )

    elif event == "Test":
        send_ntfy(
            url=ntfy_url,
            title="🔔 Radarr Test-Benachrichtigung",
            body="Verbindung zu ntfy funktioniert einwandfrei!",
            tags="bell",
        )


def handle_sonarr(ntfy_url: str, jellyfin_url: str):
    """Processes Sonarr Custom Script events."""
    event = os.environ.get("sonarr_eventtype", "")
    series_title = os.environ.get("sonarr_series_title", "Unbekannte Serie")

    season = os.environ.get("sonarr_episodefile_seasonnumber") or os.environ.get("sonarr_release_seasonnumber", "")
    episodes = os.environ.get("sonarr_episodefile_episodenumbers") or os.environ.get("sonarr_release_episodenumbers", "")
    ep_tag = f"S{int(season):02d}" if season and season.isdigit() else ""
    if ep_tag and episodes:
        ep_tag += f"E{episodes}"

    full_title = f"{series_title} {ep_tag}".strip()
    release_title = os.environ.get("sonarr_release_title") or os.environ.get("sonarr_episodefile_scenename", "")
    quality_str = os.environ.get("sonarr_release_quality") or os.environ.get("sonarr_episodefile_quality", "")
    size_str = format_size(os.environ.get("sonarr_release_size") or os.environ.get("sonarr_episodefile_size"))

    res, langs, hdr, audio = parse_release_meta(release_title, quality_str)

    if event == "Grab":
        title = f"📥 Wird heruntergeladen: {full_title}"
        body_lines = [
            f"📺 Serie: {full_title}",
            f"📐 Auflösung: {res}" + (f" ({hdr})" if hdr else ""),
            f"🔊 Sprache: {langs}",
        ]
        if audio:
            body_lines.append(f"🎧 Audio: {audio}")
        body_lines.append(f"📦 Größe: {size_str} | Client: qBittorrent")

        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join(body_lines),
            tags="arrow_down,tv",
            priority="default",
        )

    elif event in ("Download", "Upgrade"):
        is_upgrade = event == "Upgrade"
        prefix = "✨ Episode Upgrade" if is_upgrade else "✅ Fertig heruntergeladen"
        title = f"{prefix}: {full_title}"
        body_lines = [
            f"📺 Serie: {full_title}",
            f"📐 Qualität: {res}" + (f" ({hdr})" if hdr else ""),
            f"🔊 Sprache: {langs}",
            f"📦 Größe: {size_str}",
            "",
            "Ab sofort auf Jellyfin verfügbar!",
        ]
        tags = "sparkles,tv" if is_upgrade else "white_check_mark,tv"
        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join(body_lines),
            tags=tags,
            priority="default",
            click_url=jellyfin_url,
        )

    elif event == "HealthIssue":
        msg = os.environ.get("sonarr_health_issue_message", "Health-Problem gemeldet")
        title = "⚠️ Sonarr Warnung"
        send_ntfy(
            url=ntfy_url,
            title=title,
            body=f"Meldung: {msg}",
            tags="warning",
            priority="high",
        )

    elif event == "Test":
        send_ntfy(
            url=ntfy_url,
            title="🔔 Sonarr Test-Benachrichtigung",
            body="Verbindung zu ntfy funktioniert einwandfrei!",
            tags="bell",
        )


def handle_qbit(ntfy_url: str, event: str, name: str, size: str, category: str):
    """Fallback handler for raw qBittorrent torrent events."""
    res, langs, hdr, audio = parse_release_meta(name)
    formatted_size = format_size(size)

    if event == "added":
        title = f"📥 Torrent gestartet: {name[:50]}"
        body_lines = [
            f"📦 Torrent: {name}",
            f"📺 Auflösung: {res}" if res != "Unbekannt" else "",
            f"🔊 Sprache: {langs}",
            f"💾 Größe: {formatted_size}",
            f"🏷️ Kategorie: {category}" if category else "",
        ]
        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join([line for line in body_lines if line]),
            tags="arrow_down,inbox_tray",
        )
    elif event == "completed":
        title = f"✅ Torrent abgeschlossen: {name[:50]}"
        body_lines = [
            f"📦 Torrent: {name}",
            f"💾 Größe: {formatted_size}",
            "Download in qBittorrent vollständig abgeschlossen.",
        ]
        send_ntfy(
            url=ntfy_url,
            title=title,
            body="\n".join(body_lines),
            tags="white_check_mark,package",
        )


def main():
    parser = argparse.ArgumentParser(description="Unified Arr / qBittorrent notification dispatcher")
    parser.add_argument("--url", default=os.environ.get("NTFY_URL", "http://127.0.0.1:2586/media"), help="ntfy target URL")
    parser.add_argument("--jellyfin-url", default=os.environ.get("JELLYFIN_URL", "https://jellyfin.lukpac.dev"), help="Jellyfin target URL")
    parser.add_argument("--test", action="store_true", help="Send test notification")
    # qBittorrent CLI flags
    parser.add_argument("--qbit", action="store_true", help="Trigger from qBittorrent")
    parser.add_argument("--event", choices=["added", "completed"], default="completed")
    parser.add_argument("--name", default="")
    parser.add_argument("--size", default="")
    parser.add_argument("--category", default="")

    args = parser.parse_args()

    if args.test:
        send_ntfy(
            url=args.url,
            title="🔔 Notification Test",
            body="ntfy Benachrichtigungssystem auf lighthouse erfolgreich eingerichtet!",
            tags="tada,bell",
        )
        return

    if args.qbit and args.name:
        handle_qbit(args.url, args.event, args.name, args.size, args.category)
        return

    # Auto-detect from Arr environment variables
    if os.environ.get("radarr_eventtype"):
        handle_radarr(args.url, args.jellyfin_url)
    elif os.environ.get("sonarr_eventtype"):
        handle_sonarr(args.url, args.jellyfin_url)
    else:
        logger.info("No known event detected (not invoked by Sonarr/Radarr/qBit). Nothing to do.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        # Never fail calling service
        logger.error("Unhandled error: %s", exc)
        sys.exit(0)
