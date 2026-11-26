# `server.notify` – Zentraler Push-Dienst (`ntfy-sh`)

Das Modul `server.notify` stellt den selbst gehosteten **ntfy**-Server (`services.ntfy-sh`), getrennte Topics für **Medien** (`media`) und **Infrastruktur-Alerts** (`alerts`), eine optimierte Reverse-Proxy-/Cache-Konfiguration sowie die CLIs `ntfy-ctl` und `ntfy-send` bereit.

---

## 1. Struktur

```text
modules/system/server/notify/
├── default.nix          # ntfy-sh Konfiguration (WAL, 72h Cache, Rate-Limit-Ausnahmen)
├── options.nix          # Modul-Optionen unter server.notify.*
├── _lib.nix             # URL- & Topic-Helper
├── cli.nix              # Paketierung von 'ntfy-ctl' und 'ntfy-send'
├── README.md            # Modul-Dokumentation
└── scripts/
    └── ntfy-ctl.sh      # check, status, recent, send, test, logs
```

---

## 2. Topic-Trennung im System

| Topic | Default-Option | Absender |
| --- | --- | --- |
| `alerts` | `server.notify.alertTopic` | **Uptime Kuma**, **Backup**, **Vaultwarden**, **System-VPN**, **Arr-VPN**, **qBittorrent Watchdog/Cleaner**, **Sonarr/Radarr `HealthIssue`** |
| `media` | `server.notify.topic` | **Sonarr** / **Radarr** (`Grab`, `Download`, `Upgrade`), **Jellyseerr** (`Requests`), **qBittorrent** |

---

## 3. CLI-Nutzung

```bash
ntfy-ctl check
ntfy-ctl status
ntfy-ctl recent
ntfy-ctl test both
ntfy-send alerts "Testmeldung" "Server Alert" "warning" "high"
```
