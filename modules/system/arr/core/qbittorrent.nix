{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkForce types;
  cfg = config.arr;
  inherit (import ../_lib.nix) secretRef;
in {
  options.arr.qbittorrent = {
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

    seedRatioLimit = mkOption {
      type = types.nullOr types.numbers.nonnegative;
      default = null;
      example = 0.0;
      description = ''
        Maximum share ratio before stopping seeding.
        Defaults to null (unlimited seeding). Set to 0.0 to stop seeding immediately on completion.
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

    sops.secrets.arr_qbittorrent_password.restartUnits = [
      "qbittorrent.service"
      "sonarr-downloadclients.service"
      "sonarr-anime-downloadclients.service"
      "radarr-downloadclients.service"
      "prowlarr-downloadclients.service"
    ];

    nixflix.torrentClients.qbittorrent = {
      enable = true;
      inherit (cfg.qbittorrent) webuiPort;
      downloadsDir = mkForce "${cfg.dataDir}/torrents";
      password = secretRef config.sops.secrets.arr_qbittorrent_password.path;
      vpn = {
        inherit (cfg.vpn) enable namespace;
      };

      serverConfig = {
        BitTorrent.Session = {
          # Bind strictly to the VPN interface so BitTorrent traffic NEVER leaves outside the VPN
          Interface = mkIf cfg.vpn.enable "wg0";
          InterfaceName = mkIf cfg.vpn.enable "wg0";
          # Fallback path for manually added torrents without a category
          DefaultSavePath = "${cfg.paths.torrents}/default";
          # Enable Automatic Torrent Management (TMM) so categories use their explicit save paths
          DisableAutoTMMByDefault = false;
          QueueingSystemEnabled = true;
          # Do not let stalled/slow downloads block the active queue
          IgnoreSlowTorrentsForQueueing = true;
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
          ShareLimitAction =
            if cfg.qbittorrent.seedRatioLimit != null
            then "Stop"
            else "Default";
          # Legacy fallback for older qBittorrent versions
          MaxRatioAction =
            if cfg.qbittorrent.seedRatioLimit != null
            then 0 # Stop
            else -1; # Disabled
          Port = cfg.qbittorrent.bitTorrentPort;
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
          # Legacy fallback for pre-4.6 qBittorrent
          Connection = {
            UPnP = false;
          };
        };
      };
    };

    # Automatically derive and inject the PBKDF2 HMAC-SHA512 password hash into qBittorrent.conf on service start.
    # Keeps plaintext secrets strictly out of the world-readable nix store.
    systemd.services.qbittorrent = {
      serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "qbittorrent-inject-password" ''
          exec ${pkgs.python3}/bin/python3 ${../scripts/qbittorrent-sync.py} \
            --pass-file "${config.sops.secrets.arr_qbittorrent_password.path}" \
            --group "${cfg.mediaGroup}"
        '')
      ];
    };
  };
}
