{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable)) {
    nixflix.recyclarr.enable = true;

    services.recyclarr.schedule = mkForce cfg.recyclarr.schedule;

    # Wait for network & DNS at boot, preventing failures if network connects after systemd startup.
    # Automatically chain the cleanup service to run immediately after Recyclarr finishes.
    systemd.services.recyclarr = {
      after =
        ["network-online.target"]
        ++ lib.optional cfg.sonarr.enable "sonarr.service"
        ++ lib.optional cfg.radarr.enable "radarr.service";
      wants =
        lib.optional cfg.sonarr.enable "sonarr.service"
        ++ lib.optional cfg.radarr.enable "radarr.service"
        ++ lib.optional cfg.recyclarr.cleanupUnmanagedProfiles.enable "recyclarr-cleanup-profiles.service";

      path = with pkgs; [
        bash
        curl
        coreutils
      ];

      serviceConfig = {
        ExecStartPre = lib.mkBefore [
          "${pkgs.bash}/bin/bash ${./scripts/wait-for-internet.sh} --service-name recyclarr --url https://github.com --timeout 60"
        ];
        Restart = "on-failure";
        RestartSec = 15;
        Slice = "arr.slice";
        MemoryHigh = "256M";
        MemoryMax = "512M";
      };
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };
    };
  };
}
