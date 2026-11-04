{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;
in {
  options.server.arr.qbittorrent = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable qBittorrent download client.";
    };

    webuiPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for qBittorrent WebUI.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "qbit";
      description = "Subdomain name for qBittorrent WebUI reverse proxy routing.";
    };

    username = mkOption {
      type = types.str;
      default = cfg.adminUser;
      description = "Username for qBittorrent WebUI authentication.";
    };

    confirmLegalNotice = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress qBittorrent interactive legal notice warning on startup (--confirm-legal-notice).";
    };

    maxActiveDownloads = mkOption {
      type = types.ints.unsigned;
      default = 3;
      description = "Maximum number of simultaneous active downloads (prevents network and disk queue congestion).";
    };

    maxActiveTorrents = mkOption {
      type = types.ints.unsigned;
      default = 5;
      description = "Maximum number of active torrents including downloads and uploads.";
    };

    maxConnections = mkOption {
      type = types.ints.unsigned;
      default = 200;
      description = "Global maximum number of simultaneous peer connections (prevents Wi-Fi and router NAT table exhaustion).";
    };

    maxConnectionsPerTorrent = mkOption {
      type = types.ints.unsigned;
      default = 50;
      description = "Maximum number of simultaneous connections per torrent.";
    };

    downloadRateLimitKiB = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = "Global maximum download rate limit in KiB/s (0 for unlimited).";
    };

    uploadRateLimitKiB = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = "Global maximum upload rate limit in KiB/s (0 for unlimited).";
    };

    diskCacheSizeMiB = mkOption {
      type = types.ints.unsigned;
      default = 512;
      description = "Disk write cache limit in MiB for qBittorrent/libtorrent (prevents excessive RAM consumption).";
    };

    seedRatioLimit = mkOption {
      type = types.nullOr types.numbers.nonnegative;
      default = null;
      example = 0.0;
      description = ''
        Maximum share ratio before stopping seeding.
        Defaults to null (unlimited seeding). Set to 0.0 to stop seeding immediately on completion.
      '';
    };

    maxSeedingMinutes = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      example = 60;
      description = ''
        Maximum seeding time in minutes before stopping seeding.
        Defaults to null (unlimited seeding time).
      '';
    };

    openBitTorrentPort = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open incoming BitTorrent listen port in the host firewall (only applies when VPN is disabled).";
    };

    bitTorrentPort = mkOption {
      type = types.port;
      default = 6881;
      description = "Incoming BitTorrent peer listening port (inside the VPN namespace if VPN is enabled).";
    };
  };
}
