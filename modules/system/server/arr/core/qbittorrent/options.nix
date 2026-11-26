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

    useTempPath = mkOption {
      type = types.bool;
      default = true;
      description = "Store incomplete downloads in a separate temp folder before moving atomically on completion.";
    };

    announceToAllTrackers = mkOption {
      type = types.bool;
      default = true;
      description = "Announce to all trackers in all tiers simultaneously for faster peer discovery on public torrents.";
    };

    pieceExtentAffinity = mkOption {
      type = types.bool;
      default = true;
      description = "Favor downloading contiguous pieces to optimize sequential disk writes and reduce fragmentation.";
    };

    coalesceReadWrite = mkOption {
      type = types.bool;
      default = true;
      description = "Batch and coalesce disk read/write operations to reduce filesystem I/O overhead.";
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

    maxUploads = mkOption {
      type = types.ints.unsigned;
      default = 8;
      description = "Global maximum number of concurrent upload slots (tuned so peers are not starved on modest upload caps).";
    };

    maxUploadsPerTorrent = mkOption {
      type = types.ints.unsigned;
      default = 2;
      description = "Maximum number of concurrent upload slots per torrent.";
    };

    connectionSpeed = mkOption {
      type = types.ints.positive;
      default = 50;
      description = "Number of outgoing peer connection attempts per second (higher speeds up ramp-up over VPN).";
    };

    socketBacklogSize = mkOption {
      type = types.ints.positive;
      default = 100;
      description = "TCP listen socket backlog size for incoming peer bursts via NAT-PMP port forwarding.";
    };

    hashingThreads = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "Number of threads used by libtorrent for piece SHA verification.";
    };

    saveResumeDataInterval = mkOption {
      type = types.ints.positive;
      default = 15;
      description = "Interval in minutes for persisting torrent fast-resume data to disk.";
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

    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated host-side watchdog that monitors qBittorrent WebUI responsiveness and revives failed units.";
      };

      interval = mkOption {
        type = types.str;
        default = "2m";
        description = "Interval between qBittorrent watchdog checks (systemd timer syntax).";
      };

      failureThreshold = mkOption {
        type = types.ints.positive;
        default = 3;
        description = "Consecutive WebUI probe failures before restarting qbittorrent.service.";
      };
    };

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = config.server.notify.enable or false;
        description = "Enable alerts when qBittorrent fails, freezes, recovers, or removes dead stalled torrents.";
      };

      handler = mkOption {
        type = types.nullOr (types.either types.str types.package);
        default = null;
        example = lib.literalExpression ''
          '''
            # $1 contains the alert message string, $2 an optional tag
            ntfy-send media "$1" "qBittorrent Alert" "$2"
          '''
        '';
        description = ''
          Custom notification handler invoked for qBittorrent watchdog and stalled-cleaner events.
          Receives the formatted message string as $1 and an optional severity/ntfy tag as $2.
          Accepts either a shell snippet string or an executable package/derivation.
          When null and server.notify.enable is true, defaults to sending alerts via server.notify.
        '';
      };
    };
  };
}
