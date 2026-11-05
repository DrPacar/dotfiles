{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;
in {
  options.server.arr = {
    enable = mkOption {
      type = types.bool;
      default = config.server.enable;
      description = "Enable media automation stack (Arr Stack). Automatically disabled when server.enable is false.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/data";
      description = ''
        Root directory for all media and downloads.
        Must be on a single filesystem to guarantee instant hardlink imports.
      '';
    };

    mediaUser = mkOption {
      type = types.str;
      default = config.user.primary or "media";
      description = "Primary user account added to the shared media group.";
    };

    mediaGroup = mkOption {
      type = types.str;
      default = "media";
      description = "Group name for shared media permissions.";
    };

    mediaGid = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 169;
      description = "GID of the shared media group (null for automatic system allocation).";
    };

    tailscaleDomain = mkOption {
      type = types.nullOr types.str;
      default = config.server.tailscaleDomain or null;
      example = "my-tailnet.ts.net";
      description = "Tailscale tailnet domain suffix for authorized host access (null to disable Tailscale hostnames).";
    };

    domain = mkOption {
      type = types.nullOr types.str;
      default =
        if config.server.domain != null
        then "media.${config.server.domain}"
        else null;
      example = "media.domain.at";
      description = ''
        Primary base domain for web interface reverse proxy routing.
        When configured, services are routed via `<subdomain>.<domain>`
        and the central landing page dashboard is served directly on `<domain>`.
      '';
    };

    network = {
      bindAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "IP address on which Arr service web interfaces listen.";
      };

      localAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Loopback IP address used for local inter-service communication.";
      };

      extraAllowedHosts = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["*.home.arpa" "media.mydomain.com"];
        description = "Additional hostnames permitted by .NET host header validation (Sonarr, Radarr, Prowlarr).";
      };

      allowedHosts = mkOption {
        type = types.listOf types.str;
        default =
          [
            "localhost"
            "127.0.0.1"
            "0.0.0.0"
            config.networking.hostName
            "*.${config.networking.hostName}"
          ]
          ++ lib.optionals (cfg.tailscaleDomain != null) [
            "${config.networking.hostName}.${cfg.tailscaleDomain}"
            "*.${config.networking.hostName}.${cfg.tailscaleDomain}"
            "*.${cfg.tailscaleDomain}"
            "*.ts.net"
          ]
          ++ lib.optionals (cfg.domain != null) [
            cfg.domain
            "*.${cfg.domain}"
          ]
          ++ lib.optionals (config.server.domain != null && config.server.domain != cfg.domain) [
            config.server.domain
            "*.${config.server.domain}"
          ]
          ++ cfg.network.extraAllowedHosts;
        description = "List of host patterns permitted by .NET host header validation.";
      };
    };

    adminUser = mkOption {
      type = types.str;
      default = config.user.primary or "admin";
      description = "Master administrator username for Arr applications.";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = config.sops.secrets.services_password.path or null;
      description = "Master administrator password file path for Arr applications.";
    };

    paths = {
      torrents = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/torrents";
        description = "Root directory for torrent downloads (incoming and completed).";
      };

      media = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/media";
        description = "Root directory for organized media libraries.";
      };

      movies = mkOption {
        type = types.str;
        default = "${cfg.paths.media}/movies";
        description = "Target directory for imported movie libraries (used by Radarr and Jellyfin).";
      };

      tv = mkOption {
        type = types.str;
        default = "${cfg.paths.media}/tv";
        description = "Target directory for imported TV series libraries (used by Sonarr and Jellyfin).";
      };

      anime = mkOption {
        type = types.str;
        default = "${cfg.paths.media}/anime";
        description = "Target directory for imported anime series libraries (used by Sonarr Anime and Jellyfin).";
      };
    };
  };
}
