{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable)) {
    nixflix.recyclarr.cleanupUnmanagedProfiles = {
      enable = cfg.recyclarr.cleanupUnmanagedProfiles.enable;
      managedProfiles = cfg.recyclarr.cleanupUnmanagedProfiles.managedProfiles;
    };
  };
}
