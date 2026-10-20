{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkForce types;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef;
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

    maxActiveDownloads = mkOption {
      type = types.ints.unsigned;
      default = 2;
      description = "Maximum number of simultaneous active downloads (prevents network and disk queue congestion).";
    };

    maxActiveTorrents = mkOption {
      type = types.ints.unsigned;
      default = 4;
      description = "Maximum number of active torrents including downloads and uploads.";
    };

    maxConnections = mkOption {
      type = types.ints.unsigned;
      default = 100;
      description = "Global maximum number of simultaneous peer connections (prevents Wi-Fi and router NAT table exhaustion).";
    };

    maxConnectionsPerTorrent = mkOption {
      type = types.ints.unsigned;
      default = 25;
      description = "Maximum number of simultaneous connections per torrent.";
    };

    downloadRateLimitKiB = mkOption {
      type = types.ints.unsigned;
      default = 25000;
      description = "Global maximum download rate limit in KiB/s (default 25 MB/s ~ 200 Mbps). 0 for unlimited.";
    };

    uploadRateLimitKiB = mkOption {
      type = types.ints.unsigned;
      default = 3000;
      description = "Global maximum upload rate limit in KiB/s (default 3 MB/s ~ 24 Mbps; critical to prevent bufferbloat).";
    };

    seedRatioLimit = mkOption {
      type = types.nullOr types.numbers.nonnegative;
      default = 0.0;
      description = ''
        Maximum share ratio before stopping seeding.
        Defaults to 0.0 (stops seeding immediately on completion, ideal for public trackers).
        Set to a higher value (e.g. 1.0) or null (unlimited) if using private trackers to avoid hit-and-run penalties.
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

    sops.secrets.arr_qbittorrent_password.restartUnits = ["qbittorrent.service"];

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
          DefaultSavePath = "${cfg.dataDir}/torrents/default";
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
          ShareLimitAction = "Stop";
          # Legacy fallback for older qBittorrent versions
          MaxRatioAction = 0;
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
            Username = "admin";
          };
          # Legacy fallback for pre-4.6 qBittorrent
          Connection = {
            UPnP = false;
          };
        };
      };
    };

    # Automatically derive and inject the PBKDF2 HMAC-SHA512 password hash into qBittorrent.conf on service start.
    # This ensures qBittorrent uses the exact password configured in sops (arr_qbittorrent_password) without generating
    # temporary random passwords, while keeping the plaintext secret out of the world-readable nix store.
    systemd.services.qbittorrent = {
      serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "qbittorrent-inject-password" ''
                    set -eu
                    PASS_FILE="${config.sops.secrets.arr_qbittorrent_password.path}"
                    CONF_FILE="/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf"
                    if [ -f "$PASS_FILE" ] && [ -f "$CONF_FILE" ]; then
                      ${pkgs.python3}/bin/python3 -c "
          import hashlib, os, base64

          with open('$PASS_FILE', 'r') as f:
              password = f.read().strip().encode('utf-8')

          salt = os.urandom(16)
          hashed = hashlib.pbkdf2_hmac('sha512', password, salt, 100000)
          b64_salt = base64.b64encode(salt).decode()
          b64_hash = base64.b64encode(hashed).decode()
          val = f'@ByteArray({b64_salt}:{b64_hash})'

          with open('$CONF_FILE', 'r') as f:
              lines = f.readlines()

          new_lines = []
          found = False
          for line in lines:
              if line.startswith(r'WebUI\Password_PBKDF2='):
                  new_lines.append(r'WebUI\Password_PBKDF2=' + val + '\n')
                  found = True
              elif line.strip() == '[Preferences]' and not found:
                  new_lines.append(line)
                  new_lines.append(r'WebUI\Password_PBKDF2=' + val + '\n')
                  found = True
              else:
                  new_lines.append(line)

          with open('$CONF_FILE', 'w') as f:
              f.writelines(new_lines)
          "
                    fi
        '')
      ];
    };
  };
}
