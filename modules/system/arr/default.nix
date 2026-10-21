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

    adminUser = mkOption {
      type = types.str;
      default = config.user.primary;
      description = "Master administrator username for Arr applications.";
    };

    adminPasswordFile = mkOption {
      type = types.path;
      default = config.sops.secrets.arr_jellyfin_admin_password.path;
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

    resources = {
      enable = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = "Whether to enable cgroup resource management slice (arr.slice) for media stack services.";
      };

      cpuWeight = mkOption {
        type = types.ints.between 1 10000;
        default = 50;
        description = ''
          Relative CPU weight (1 to 10000, default 100).
          Values below 100 ensure the interactive desktop environment takes priority during resource contention.
        '';
      };

      ioWeight = mkOption {
        type = types.ints.between 1 10000;
        default = 50;
        description = ''
          Relative block I/O weight (1 to 10000, default 100).
          Values below 100 reduce disk starvation for interactive applications during heavy torrenting or unpack operations.
        '';
      };

      memoryHigh = mkOption {
        type = types.nullOr types.str;
        default = "75%";
        description = ''
          Soft memory threshold (e.g., "75%" or "8G").
          When exceeded, systemd aggressively reclaims page cache and throttles allocation without invoking the OOM killer.
        '';
      };

      memoryMax = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Hard memory ceiling (e.g., "90%" or "16G").
          If exceeded and memory cannot be reclaimed, processes in the slice will be terminated by the kernel OOM killer.
          Default is null (unrestricted ceiling).
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Shared Permissions & Storage Structure
    # -------------------------------------------------------------------------
    users.groups.${cfg.mediaGroup} = {
      gid = mkDefault cfg.mediaGid;
      members = [cfg.mediaUser] ++ lib.optional cfg.bazarr.enable "bazarr";
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

    # Configure directory hierarchy with setgid (2775)
    # Using systemd.tmpfiles.settings."10-nixflix" directly to avoid conflicting duplicate tmpfiles rules
    systemd.tmpfiles.settings."10-nixflix" =
      {
        "${cfg.dataDir}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.torrents}".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.torrents}/default".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.media}".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.radarr.enable {
        "${cfg.paths.torrents}/radarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.movies}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.sonarr.enable {
        "${cfg.paths.torrents}/sonarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.tv}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        "${cfg.paths.torrents}/sonarr-anime".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.anime}".d = {
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

      mediaDir = cfg.paths.media;
      downloadsDir = cfg.paths.torrents;
      mediaUsers = [cfg.mediaUser];

      # Disable public reverse proxies; services are accessed securely via Tailscale and localhost
      nginx.enable = false;
      caddy.enable = false;
    };

    # -------------------------------------------------------------------------
    # Resource Management (cgroups v2 arr.slice)
    # -------------------------------------------------------------------------
    systemd.slices.arr = mkIf cfg.resources.enable {
      description = "Media and Automation Stack Slice";
      sliceConfig =
        {
          CPUWeight = cfg.resources.cpuWeight;
          IOWeight = cfg.resources.ioWeight;
        }
        // optionalAttrs (cfg.resources.memoryHigh != null) {
          MemoryHigh = cfg.resources.memoryHigh;
        }
        // optionalAttrs (cfg.resources.memoryMax != null) {
          MemoryMax = cfg.resources.memoryMax;
        };
    };

    systemd.services = mkIf cfg.resources.enable (
      lib.mkMerge [
        (mkIf cfg.jellyfin.enable {
          jellyfin.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.qbittorrent.enable {
          qbittorrent.serviceConfig.Slice = "arr.slice";
        })
        (mkIf (cfg.qbittorrent.enable && cfg.vpn.enable) {
          qbittorrent-webui-proxy.serviceConfig.Slice = "arr.slice";
        })
        (mkIf (cfg.qbittorrent.enable && cfg.vpn.enable && cfg.vpn.portForwarding.enable) {
          protonvpn-port-forward.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.radarr.enable {
          radarr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.sonarr.enable {
          sonarr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
          sonarr-anime.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.prowlarr.enable {
          prowlarr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.bazarr.enable {
          bazarr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.seerr.enable {
          seerr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf (cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable)) {
          recyclarr.serviceConfig.Slice = "arr.slice";
        })
        (mkIf cfg.flaresolverr.enable {
          flaresolverr.serviceConfig.Slice = "arr.slice";
        })
      ]
    );
  };
}
