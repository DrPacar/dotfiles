# `server.beszel` – Ressource-, SMART- & Alert-Monitoring (`Beszel`)

Das Modul `server.beszel` betreibt den **Beszel Hub** + **Beszel Agent** mit Hardware-Telemetrie (CPU, RAM, NVMe-SMART via `smartmontools`, Systemd-Units, Intel QuickSync iGPU via `intel-gpu-tools`), Reverse-Proxy-Konfiguration, deklarativen Baseline-Alerts, automatischer **`ntfy`**-Webhook-Anbindung (`alerts`) und der CLI **`beszel-ctl`**.

---

## 1. Struktur

```text
modules/system/server/beszel/
├── default.nix           # beszel-hub, beszel-agent & beszel-sync Service
├── options.nix           # Modul-Optionen unter server.beszel.*
├── _lib.nix              # URLs, DB-Pfade & Sync-Payload
├── cli.nix               # Paketierung von 'beszel-ctl'
├── README.md             # Modul-Dokumentation
└── scripts/
    ├── beszel-ctl.sh     # check, status, alerts, smart, logs
    └── beszel-sync.py    # Idempotenter Sync für appURL, Proxy, Webhook & Alerts
```

---

## 2. Standard-Alerts & Telemetrie

- **Intel iGPU (`agent.intelGpu.enable = true`):** `intel_gpu_top` liefert GPU-/QuickSync-Auslastung (z. B. beim Jellyfin/Immich-Transcoding) direkt ins Dashboard.
- **ntfy-Anbindung (`alerts`):** Beszel pusht über `ntfy://127.0.0.1:2586/alerts?scheme=http` direkt an `server.notify`.
- **Deklarative Standardregeln (`alerts.rules`):**
  - `Status`: Host offline > 1 Min
  - `CPU`: >= 90 % für 5 Min
  - `Memory`: >= 90 % für 5 Min
  - `Disk`: >= 88 % für 5 Min
  - `Temperature`: >= 80 °C für 5 Min
  - `SystemdFailed`: Fehlgeschlagene Systemd-Unit (sofort)

---

## 3. CLI-Nutzung

```bash
sudo beszel-ctl check
sudo beszel-ctl status
sudo beszel-ctl alerts
sudo beszel-ctl smart
```
