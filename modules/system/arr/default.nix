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
      default = null;
      example = "my-tailnet.ts.net";
      description = "Tailscale tailnet domain suffix for authorized host access (null to disable Tailscale hostnames).";
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
      default = config.sops.secrets.arr_jellyfin_admin_password.path or null;
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
    assertions = let
      assignedPorts = [
        (lib.optionalAttrs cfg.jellyfin.enable {
          name = "Jellyfin";
          port = cfg.jellyfin.port;
        })
        (lib.optionalAttrs cfg.qbittorrent.enable {
          name = "qBittorrent WebUI";
          port = cfg.qbittorrent.webuiPort;
        })
        (lib.optionalAttrs cfg.radarr.enable {
          name = "Radarr";
          port = cfg.radarr.port;
        })
        (lib.optionalAttrs cfg.sonarr.enable {
          name = "Sonarr";
          port = cfg.sonarr.port;
        })
        (lib.optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
          name = "Sonarr Anime";
          port = cfg.sonarr.anime.port;
        })
        (lib.optionalAttrs cfg.prowlarr.enable {
          name = "Prowlarr";
          port = cfg.prowlarr.port;
        })
        (lib.optionalAttrs cfg.bazarr.enable {
          name = "Bazarr";
          port = cfg.bazarr.port;
        })
        (lib.optionalAttrs cfg.seerr.enable {
          name = "Seerr";
          port = cfg.seerr.port;
        })
        (lib.optionalAttrs cfg.flaresolverr.enable {
          name = "FlareSolverr";
          port = cfg.flaresolverr.port;
        })
      ];
      activePorts = lib.filter (p: p ? port) assignedPorts;
      portList = map (p: p.port) activePorts;
      uniquePortList = lib.unique portList;
    in [
      {
        assertion = builtins.length portList == builtins.length uniquePortList;
        message = "arr: Port collision detected among enabled Arr services. Ensure all services have distinct ports.";
      }
    ];

    # -------------------------------------------------------------------------
    # Shared Permissions & Storage Structure
    # -------------------------------------------------------------------------
    users.groups.${cfg.mediaGroup} =
      {
        members = [cfg.mediaUser] ++ lib.optional cfg.bazarr.enable "bazarr";
      }
      // lib.optionalAttrs (cfg.mediaGid != null) {
        gid = mkDefault cfg.mediaGid;
      };

    # -------------------------------------------------------------------------
    # Secrets Permissions & Automatic Service Synchronization
    # -------------------------------------------------------------------------
    sops.secrets =
      (lib.genAttrs (
          lib.optional cfg.sonarr.enable "arr_sonarr_api_key"
          ++ lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) "arr_sonarr_anime_api_key"
          ++ lib.optional cfg.radarr.enable "arr_radarr_api_key"
          ++ lib.optional cfg.prowlarr.enable "arr_prowlarr_api_key"
          ++ lib.optional cfg.bazarr.enable "arr_bazarr_api_key"
          ++ lib.optional cfg.seerr.enable "arr_seerr_api_key"
          ++ lib.optional cfg.jellyfin.enable "arr_jellyfin_api_key"
          ++ lib.optional cfg.jellyfin.enable "arr_jellyfin_admin_password"
          ++ lib.optional cfg.qbittorrent.enable "arr_qbittorrent_password"
        ) (_name: {
          group = lib.mkForce cfg.mediaGroup;
          mode = lib.mkForce "0440";
        }))
      // lib.optionalAttrs cfg.vpn.enable {
        arr_wireguard_conf = {
          mode = lib.mkForce "0400";
          restartUnits = ["${cfg.vpn.namespace}.service"];
        };
      }
      // lib.optionalAttrs cfg.sonarr.enable {
        arr_sonarr_api_key.restartUnits =
          lib.optional cfg.sonarr.enable "sonarr-config.service"
          ++ lib.optional (cfg.prowlarr.enable && cfg.sonarr.enable) "prowlarr-applications.service"
          ++ lib.optional (cfg.seerr.enable && cfg.sonarr.enable) "seerr-sonarr.service"
          ++ lib.optional (cfg.bazarr.enable && cfg.sonarr.enable) "bazarr.service";
      }
      // lib.optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        arr_sonarr_anime_api_key.restartUnits =
          lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) "sonarr-anime-config.service"
          ++ lib.optional (cfg.prowlarr.enable && cfg.sonarr.enable && cfg.sonarr.anime.enable) "prowlarr-applications.service"
          ++ lib.optional (cfg.seerr.enable && cfg.sonarr.enable && cfg.sonarr.anime.enable) "seerr-sonarr.service";
      }
      // lib.optionalAttrs cfg.radarr.enable {
        arr_radarr_api_key.restartUnits =
          lib.optional cfg.radarr.enable "radarr-config.service"
          ++ lib.optional (cfg.prowlarr.enable && cfg.radarr.enable) "prowlarr-applications.service"
          ++ lib.optional (cfg.seerr.enable && cfg.radarr.enable) "seerr-radarr.service"
          ++ lib.optional (cfg.bazarr.enable && cfg.radarr.enable) "bazarr.service";
      }
      // lib.optionalAttrs cfg.prowlarr.enable {
        arr_prowlarr_api_key.restartUnits =
          lib.optional cfg.prowlarr.enable "prowlarr-config.service"
          ++ lib.optional cfg.prowlarr.enable "prowlarr-applications.service";
      }
      // lib.optionalAttrs cfg.seerr.enable {
        arr_seerr_api_key.restartUnits =
          lib.optional cfg.seerr.enable "seerr.service"
          ++ lib.optional (cfg.seerr.enable && cfg.sonarr.enable) "seerr-sonarr.service"
          ++ lib.optional (cfg.seerr.enable && cfg.radarr.enable) "seerr-radarr.service";
      }
      // lib.optionalAttrs cfg.bazarr.enable {
        arr_bazarr_api_key.restartUnits =
          lib.optional cfg.bazarr.enable "bazarr.service";
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
