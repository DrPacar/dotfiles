{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
  qbit = import ./_lib.nix {inherit config lib pkgs;};

  injectPasswordScript = pkgs.writeShellApplication {
    name = "qbittorrent-inject-password";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 ${./scripts/qbittorrent-sync.py} \
        --pass-file "${config.sops.secrets.services_password.path}" \
        --group "${cfg.mediaGroup}"
    '';
  };

  watchdogScript = pkgs.writeShellApplication {
    name = "arr-qbit-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      curl
      coreutils
    ];
    runtimeEnv =
      qbit.commonEnv
      // {
        FAILURE_THRESHOLD = toString cfg.qbittorrent.watchdog.failureThreshold;
      };
    text = builtins.readFile ./scripts/watchdog.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.qbittorrent.enable) {
    assertions = [
      {
        assertion = cfg.qbittorrent.maxActiveTorrents >= cfg.qbittorrent.maxActiveDownloads;
        message = "arr.qbittorrent: maxActiveTorrents must be greater than or equal to maxActiveDownloads.";
      }
      {
        assertion = cfg.qbittorrent.maxConnections >= cfg.qbittorrent.maxConnectionsPerTorrent;
        message = "arr.qbittorrent: maxConnections must be greater than or equal to maxConnectionsPerTorrent.";
      }
      {
        assertion = cfg.qbittorrent.maxUploads == 0 || cfg.qbittorrent.maxUploads >= cfg.qbittorrent.maxUploadsPerTorrent;
        message = "arr.qbittorrent: maxUploads must be 0 (unlimited) or greater than or equal to maxUploadsPerTorrent.";
      }
      {
        assertion = config.sops.secrets ? services_password;
        message = "arr.qbittorrent: config.sops.secrets.services_password must be defined in your secrets file.";
      }
    ];

    # Only open host firewall if explicitly requested AND when not confined to a VPN
    networking.firewall = mkIf (cfg.qbittorrent.openBitTorrentPort && !cfg.vpn.enable) {
      allowedTCPPorts = [cfg.qbittorrent.bitTorrentPort];
      allowedUDPPorts = [cfg.qbittorrent.bitTorrentPort];
    };

    sops.secrets.services_password.restartUnits = [
      "qbittorrent.service"
      "sonarr-downloadclients.service"
      "radarr-downloadclients.service"
      "prowlarr-downloadclients.service"
    ];

    services.qbittorrent.extraArgs = lib.optional cfg.qbittorrent.confirmLegalNotice "--confirm-legal-notice";

    nixflix.torrentClients.qbittorrent = {
      enable = true;
      inherit (cfg.qbittorrent) webuiPort;
      downloadsDir = mkForce "${cfg.dataDir}/torrents";
      password = secretRef config.sops.secrets.services_password.path;
      vpn = {
        inherit (cfg.vpn) enable namespace;
      };

      serverConfig = {
        BitTorrent = {
          Session = {
            # Bind strictly to the VPN interface so BitTorrent traffic NEVER leaves outside the VPN
            Interface = mkIf cfg.vpn.enable qbit.vpnIface;
            InterfaceName = mkIf cfg.vpn.enable qbit.vpnIface;
            LSDEnabled = !cfg.vpn.enable;
            ReannounceWhenAddressChanged = true;
            DiskCacheSize = cfg.qbittorrent.diskCacheSizeMiB;
            HashingThreadsCount = cfg.qbittorrent.hashingThreads;
            SaveResumeDataInterval = cfg.qbittorrent.saveResumeDataInterval;
            # Fallback path for manually added torrents without a category
            DefaultSavePath = "${cfg.paths.torrents}/default";
            TempPathEnabled = cfg.qbittorrent.useTempPath;
            TempPath = "${cfg.paths.torrents}/incomplete";
            # Enable Automatic Torrent Management (TMM) so categories use their explicit save paths
            DisableAutoTMMByDefault = false;
            QueueingSystemEnabled = true;
            # Do not let stalled/slow downloads block the active queue
            IgnoreSlowTorrentsForQueueing = true;
            AnnounceToAllTrackers = cfg.qbittorrent.announceToAllTrackers;
            AnnounceToAllTiers = cfg.qbittorrent.announceToAllTrackers;
            PieceExtentAffinity = cfg.qbittorrent.pieceExtentAffinity;
            CoalesceReadWrite = cfg.qbittorrent.coalesceReadWrite;
            ConnectionSpeed = cfg.qbittorrent.connectionSpeed;
            SocketBacklogSize = cfg.qbittorrent.socketBacklogSize;
            MaxActiveDownloads = cfg.qbittorrent.maxActiveDownloads;
            MaxActiveTorrents = cfg.qbittorrent.maxActiveTorrents;
            MaxConnections = cfg.qbittorrent.maxConnections;
            MaxConnectionsPerTorrent = cfg.qbittorrent.maxConnectionsPerTorrent;
            MaxUploads = cfg.qbittorrent.maxUploads;
            MaxUploadsPerTorrent = cfg.qbittorrent.maxUploadsPerTorrent;
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
    systemd.services = {
      qbittorrent = {
        serviceConfig = {
          Slice = "arr.slice";
          Restart = "on-failure";
          RestartSec = "5s";
          RestartSteps = 5;
          RestartMaxDelaySec = "1m";
          MemoryHigh = "2G";
          MemoryMax = "4G";
          # Isolate /run/systemd/resolve so host systemd-resolved updates cannot
          # replace the namespace resolv.conf bind mount underneath qBittorrent.
          TemporaryFileSystem = mkIf (qbit.vpnEnabled && qbit.resolvedEnabled) ["/run/systemd/resolve:ro"];
          ExecStartPre = lib.mkAfter [
            "${injectPasswordScript}/bin/qbittorrent-inject-password"
          ];
        };

        unitConfig = {
          StartLimitIntervalSec = 0;
        };
      };

      qbittorrent-watchdog = mkIf cfg.qbittorrent.watchdog.enable {
        description = "Health check and auto-recovery for qBittorrent and its WebUI proxy";
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "arr-qbittorrent";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = "${watchdogScript}/bin/arr-qbit-watchdog";
        };
      };
    };

    systemd.timers.qbittorrent-watchdog = mkIf cfg.qbittorrent.watchdog.enable {
      description = "Timer for qBittorrent WebUI health check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.qbittorrent.watchdog.interval;
        RandomizedDelaySec = "10s";
      };
    };
  };
}
