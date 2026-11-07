{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.server.arr;
in {
  options.server.arr.qbittorrent.stalledCleaner = {
    enable = mkEnableOption "automated cleanup of dead or stalled torrents in Sonarr and Radarr" // {default = true;};
    maxStalledMinutes = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minutes a torrent can remain stalled with 0 connections before being removed and blocklisted.";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "systemd OnCalendar interval expression for stalled torrent cleanup.";
    };
  };

  config = mkIf (cfg.enable && cfg.qbittorrent.enable && cfg.qbittorrent.stalledCleaner.enable && (cfg.sonarr.enable || cfg.radarr.enable)) {
    systemd.services.arr-stalled-cleaner = {
      description = "Clean dead or stalled downloads in Sonarr and Radarr";
      after =
        lib.optional cfg.sonarr.enable "sonarr.service"
        ++ lib.optional cfg.radarr.enable "radarr.service"
        ++ ["qbittorrent.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          (
            "${pkgs.python3}/bin/python3 ${./scripts/clean-stalled-downloads.py}"
            + (lib.optionalString cfg.sonarr.enable " --sonarr-url http://${cfg.network.localAddress}:${toString cfg.sonarr.port} --sonarr-key-file ${config.sops.secrets.arr_sonarr_api_key.path}")
            + (lib.optionalString cfg.radarr.enable " --radarr-url http://${cfg.network.localAddress}:${toString cfg.radarr.port} --radarr-key-file ${config.sops.secrets.arr_radarr_api_key.path}")
            + " --max-stalled-minutes ${toString cfg.qbittorrent.stalledCleaner.maxStalledMinutes}"
          )
        ];
        User = cfg.mediaUser;
        Group = cfg.mediaGroup;
      };
    };

    systemd.timers.arr-stalled-cleaner = {
      description = "Periodic cleaner for stalled/dead Arr downloads";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.qbittorrent.stalledCleaner.interval;
        Persistent = true;
        RandomizedDelaySec = "60s";
      };
    };
  };
}
