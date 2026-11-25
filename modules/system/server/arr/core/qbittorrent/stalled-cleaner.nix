{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption optionalString;
  cfg = config.server.arr;
  qbit = import ./_lib.nix {inherit config lib pkgs;};

  stalledCleanerScript = pkgs.writeShellApplication {
    name = "arr-stalled-cleaner";
    runtimeInputs = [pkgs.python3];
    text = ''
      args=(
        --max-stalled-minutes "${toString cfg.qbittorrent.stalledCleaner.maxStalledMinutes}"
      )
      ${optionalString cfg.sonarr.enable ''
        args+=(--sonarr-url "http://${cfg.network.localAddress}:${toString cfg.sonarr.port}" --sonarr-key-file "${config.sops.secrets.arr_sonarr_api_key.path}")
      ''}
      ${optionalString cfg.radarr.enable ''
        args+=(--radarr-url "http://${cfg.network.localAddress}:${toString cfg.radarr.port}" --radarr-key-file "${config.sops.secrets.arr_radarr_api_key.path}")
      ''}
      ${optionalString (qbit.notifyBin != "") ''
        args+=(--notify-bin "${qbit.notifyBin}")
      ''}
      exec python3 ${./scripts/clean-stalled-downloads.py} "''${args[@]}"
    '';
  };
in {
  options.server.arr.qbittorrent.stalledCleaner = {
    enable = mkEnableOption "automated cleanup of dead or stalled torrents in Sonarr and Radarr" // {default = true;};
    maxStalledMinutes = lib.mkOption {
      type = lib.types.ints.positive;
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
        ExecStart = "${stalledCleanerScript}/bin/arr-stalled-cleaner";
        User = cfg.mediaUser;
        Group = cfg.mediaGroup;
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
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
