{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkDefault mkForce types optionalAttrs;
  cfg = config.arr;
in {
  imports = [
    inputs.nixflix.nixosModules.default
  ];

  options.arr = {
    enable = mkEnableOption "media automation stack (Arr Stack)";

    dataDir = mkOption {
      type = types.str;
      default = "/arr_data";
      description = ''
        Root directory for all media and downloads.
        Must be on a single filesystem to guarantee instant hardlink imports.
      '';
    };

    mediaUser = mkOption {
      type = types.str;
      default = config.user.primary;
      description = "Primary user account added to the shared media group.";
    };

    mediaGroup = mkOption {
      type = types.str;
      default = "media";
      description = "Group name for shared media permissions.";
    };

    mediaGid = mkOption {
      type = types.int;
      default = 169;
      description = "GID of the shared media group.";
    };

    tailscaleDomain = mkOption {
      type = types.str;
      default = "gute-court.ts.net";
      description = "Tailscale tailnet domain suffix for authorized host access.";
    };
  };

  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Shared Permissions & Storage Structure
    # -------------------------------------------------------------------------
    users.groups.${cfg.mediaGroup} = {
      gid = mkDefault cfg.mediaGid;
      members = [cfg.mediaUser "bazarr"];
    };

    # -------------------------------------------------------------------------
    # Secrets Permissions & Automatic Service Synchronization
    # -------------------------------------------------------------------------
    sops.secrets =
      (lib.genAttrs [
          "arr_sonarr_api_key"
          "arr_sonarr_anime_api_key"
          "arr_radarr_api_key"
          "arr_prowlarr_api_key"
          "arr_bazarr_api_key"
          "arr_seerr_api_key"
          "arr_jellyfin_api_key"
          "arr_jellyfin_admin_password"
          "arr_qbittorrent_password"
        ] (_name: {
          group = lib.mkForce cfg.mediaGroup;
          mode = lib.mkForce "0440";
        }))
      // {
        arr_wireguard_conf = {
          mode = lib.mkForce "0400";
          restartUnits = ["${cfg.vpn.namespace}.service"];
        };
        arr_sonarr_api_key.restartUnits = [
          "sonarr-config.service"
          "prowlarr-applications.service"
          "seerr-sonarr.service"
          "bazarr.service"
        ];
        arr_sonarr_anime_api_key.restartUnits = [
          "sonarr-anime-config.service"
          "prowlarr-applications.service"
          "seerr-sonarr.service"
        ];
        arr_radarr_api_key.restartUnits = [
          "radarr-config.service"
          "prowlarr-applications.service"
          "seerr-radarr.service"
          "bazarr.service"
        ];
        arr_prowlarr_api_key.restartUnits = [
          "prowlarr-config.service"
          "prowlarr-applications.service"
        ];
        arr_seerr_api_key.restartUnits = [
          "seerr.service"
          "seerr-sonarr.service"
          "seerr-radarr.service"
        ];
        arr_bazarr_api_key.restartUnits = [
          "bazarr.service"
        ];
      };

    # Configure /arr_data directory hierarchy with setgid (2775)
    # Using systemd.tmpfiles.settings."10-nixflix" directly to avoid conflicting duplicate tmpfiles rules
    systemd.tmpfiles.settings."10-nixflix" =
      {
        "${cfg.dataDir}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/torrents".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/torrents/default".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/media".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.radarr.enable {
        "${cfg.dataDir}/torrents/radarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/media/movies".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.sonarr.enable {
        "${cfg.dataDir}/torrents/sonarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/media/tv".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        "${cfg.dataDir}/torrents/sonarr-anime".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.dataDir}/media/anime".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      };

    # -------------------------------------------------------------------------
    # Base Nixflix Configuration
    # -------------------------------------------------------------------------
    nixflix = {
      enable = true;

      mediaDir = "${cfg.dataDir}/media";
      downloadsDir = "${cfg.dataDir}/torrents";
      mediaUsers = [cfg.mediaUser];

      # Disable public reverse proxies; services are accessed securely via Tailscale and localhost
      nginx.enable = false;
      caddy.enable = false;
    };
  };
}
