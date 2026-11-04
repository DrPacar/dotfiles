{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
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
  };
}
