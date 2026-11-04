{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types optionalAttrs;
  cfg = config.server.arr;
in {
  options.server.arr.resources = {
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

  config = mkIf (cfg.enable && cfg.resources.enable) {
    # -------------------------------------------------------------------------
    # Resource Management (cgroups v2 arr.slice)
    # -------------------------------------------------------------------------
    systemd.slices.arr = {
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

    systemd.services = lib.mkMerge [
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
      (mkIf cfg.prowlarr.enable {
        prowlarr.serviceConfig.Slice = "arr.slice";
      })
      (mkIf cfg.bazarr.enable {
        bazarr.serviceConfig.Slice = "arr.slice";
        bazarr-setup-profile.serviceConfig.Slice = "arr.slice";
      })
      (mkIf cfg.seerr.enable {
        seerr.serviceConfig.Slice = "arr.slice";
        seerr-env.serviceConfig.Slice = "arr.slice";
        seerr-jellyfin.serviceConfig.Slice = "arr.slice";
        seerr-libraries.serviceConfig.Slice = "arr.slice";
        seerr-radarr.serviceConfig.Slice = "arr.slice";
        seerr-setup.serviceConfig.Slice = "arr.slice";
        seerr-sonarr.serviceConfig.Slice = "arr.slice";
        seerr-user-settings.serviceConfig.Slice = "arr.slice";
      })
      (mkIf (cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable)) {
        recyclarr.serviceConfig.Slice = "arr.slice";
        recyclarr-cleanup-profiles.serviceConfig.Slice = "arr.slice";
      })
      (mkIf cfg.flaresolverr.enable {
        flaresolverr.serviceConfig.Slice = "arr.slice";
      })
    ];
  };
}
