{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
in {
  config = mkIf (cfg.enable && cfg.qbittorrent.enable) {
    assertions = [
      {
        assertion = cfg.qbittorrent.maxActiveTorrents >= cfg.qbittorrent.maxActiveDownloads;
        message = "arr.qbittorrent: maxActiveTorrents must be greater than or equal to maxActiveDownloads";
      }
      {
        assertion = config.sops.secrets ? arr_qbittorrent_password;
        message = "arr.qbittorrent: config.sops.secrets.arr_qbittorrent_password must be defined in your secrets file.";
      }
    ];

    # Only open host firewall if explicitly requested AND when not confined to a VPN
    networking.firewall = mkIf (cfg.qbittorrent.openBitTorrentPort && !cfg.vpn.enable) {
      allowedTCPPorts = [cfg.qbittorrent.bitTorrentPort];
      allowedUDPPorts = [cfg.qbittorrent.bitTorrentPort];
    };

    sops.secrets.arr_qbittorrent_password.restartUnits =
      [
        "qbittorrent.service"
        "sonarr-downloadclients.service"
        "radarr-downloadclients.service"
        "prowlarr-downloadclients.service"
      ]
      ++ lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) "sonarr-anime-downloadclients.service";

    services.qbittorrent.extraArgs = lib.optional cfg.qbittorrent.confirmLegalNotice "--confirm-legal-notice";

    nixflix.torrentClients.qbittorrent = {
      enable = true;
      inherit (cfg.qbittorrent) webuiPort;
      downloadsDir = mkForce "${cfg.dataDir}/torrents";
      password = secretRef config.sops.secrets.arr_qbittorrent_password.path;
      vpn = {
        inherit (cfg.vpn) enable namespace;
      };

      serverConfig = {
        BitTorrent = {
          Session = {
            # Bind strictly to the VPN interface so BitTorrent traffic NEVER leaves outside the VPN
            Interface = mkIf cfg.vpn.enable "wg0";
            InterfaceName = mkIf cfg.vpn.enable "wg0";
            DiskCacheSize = cfg.qbittorrent.diskCacheSizeMiB;
            # Fallback path for manually added torrents without a category
            DefaultSavePath = "${cfg.paths.torrents}/default";
            # Enable Automatic Torrent Management (TMM) so categories use their explicit save paths
            DisableAutoTMMByDefault = false;
            QueueingSystemEnabled = true;
            # Do not let stalled/slow downloads block the active queue
            IgnoreSlowTorrentsForQueueing = true;
            AnnounceToAllTrackers = cfg.qbittorrent.announceToAllTrackers;
            AnnounceToAllTiers = cfg.qbittorrent.announceToAllTrackers;
            PieceExtentAffinity = cfg.qbittorrent.pieceExtentAffinity;
            CoalesceReadWrite = cfg.qbittorrent.coalesceReadWrite;
            MaxActiveDownloads = cfg.qbittorrent.maxActiveDownloads;
            MaxActiveTorrents = cfg.qbittorrent.maxActiveTorrents;
            MaxConnections = cfg.qbittorrent.maxConnections;
            MaxConnectionsPerTorrent = cfg.qbittorrent.maxConnectionsPerTorrent;
            GlobalDownloadRateLimit = cfg.qbittorrent.downloadRateLimitKiB;
            GlobalUploadRateLimit = cfg.qbittorrent.uploadRateLimitKiB;
            # Modern qBittorrent 4.6+/5.x seeding share limits
            GlobalMaxRatio =
              if cfg.qbittorrent.seedRatioLimit != null
              then cfg.qbittorrent.seedRatioLimit
              else -1;
            GlobalMaxSeedingMinutes =
              if cfg.qbittorrent.maxSeedingMinutes != null
              then cfg.qbittorrent.maxSeedingMinutes
              else -1;
            ShareLimitAction =
              if (cfg.qbittorrent.seedRatioLimit != null || cfg.qbittorrent.maxSeedingMinutes != null)
              then "Stop"
              else "Default";
            # Legacy fallback for older qBittorrent versions
            MaxRatioAction =
              if (cfg.qbittorrent.seedRatioLimit != null || cfg.qbittorrent.maxSeedingMinutes != null)
              then 0 # Stop
              else -1; # Disabled
            Port = cfg.qbittorrent.bitTorrentPort;
          };
          "Session\\DisableAutoTMMTriggers\\CategorySavePathChanged" = false;
        };

        Network = {
          PortForwardingEnabled = false;
        };

        Preferences = {
          WebUI = {
            # Disable host validation: qBittorrent runs confined in a VPN netns behind the host socat proxy
            HostHeaderValidation = false;
            ServerDomains = "*";
            # Required for headless API integrations (Prowlarr, Sonarr, Radarr) per official Servarr docs
            CSRFProtection = false;
            LocalHostAuth = false;
            AuthSubnetWhitelistEnabled = true;
            AuthSubnetWhitelist = "127.0.0.1/32";
            Username = cfg.qbittorrent.username;
          };
          Connection = {
            ResolvePeerCountries = true;
            UPnP = false;
          };
        };
      };
    };

    # Automatically derive and inject the PBKDF2 HMAC-SHA512 password hash into qBittorrent.conf on service start.
    # Keeps plaintext secrets strictly out of the world-readable nix store.
    systemd.services.qbittorrent = {
      serviceConfig = {
        Slice = "arr.slice";
        Restart = "on-failure";
        RestartSec = 5;
        MemoryHigh = "2G";
        MemoryMax = "4G";
        ExecStartPre = lib.mkAfter [
          (pkgs.writeShellScript "qbittorrent-inject-password" ''
            exec ${pkgs.python3}/bin/python3 ${../../scripts/qbittorrent-sync.py} \
              --pass-file "${config.sops.secrets.arr_qbittorrent_password.path}" \
              --group "${cfg.mediaGroup}"
          '')
        ];
      };
    };
  };
}
