{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  notifyCfg = config.server.notify;

  notifyEnabled = cfg.notifications.enable && (notifyCfg.enable or false);

  arrNotifyPkg = pkgs.writeShellScriptBin "arr-notify" ''
    export NTFY_URL="''${NTFY_URL:-${cfg.notifications.ntfyUrl}}"
    export JELLYFIN_URL="''${JELLYFIN_URL:-${cfg.notifications.jellyfinUrl}}"
    exec ${pkgs.python3}/bin/python3 ${./scripts/arr-notify.py} "$@"
  '';
in {
  config = mkIf (cfg.enable && notifyEnabled) {
    # Provide arr-notify executable system-wide
    environment.systemPackages = [
      arrNotifyPkg
    ];

    # -------------------------------------------------------------------------
    # Sonarr Notification Sync Service
    # -------------------------------------------------------------------------
    systemd.services.sonarr-notify-sync = mkIf cfg.sonarr.enable {
      description = "Synchronize ntfy notification into Sonarr";
      after = ["sonarr.service"];
      wants = ["sonarr.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [arrNotifyPkg ./scripts/arr-notify-sync.py];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "sonarr-notify-sync" ''
          exec ${pkgs.python3}/bin/python3 ${./scripts/arr-notify-sync.py} \
            --app sonarr \
            --url http://127.0.0.1:${toString cfg.sonarr.port} \
            --api-key-file "${config.sops.secrets.arr_sonarr_api_key.path}" \
            --script-path "${arrNotifyPkg}/bin/arr-notify"
        ''}";
      };
    };

    # -------------------------------------------------------------------------
    # Radarr Notification Sync Service
    # -------------------------------------------------------------------------
    systemd.services.radarr-notify-sync = mkIf cfg.radarr.enable {
      description = "Synchronize ntfy notification into Radarr";
      after = ["radarr.service"];
      wants = ["radarr.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [arrNotifyPkg ./scripts/arr-notify-sync.py];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "radarr-notify-sync" ''
          exec ${pkgs.python3}/bin/python3 ${./scripts/arr-notify-sync.py} \
            --app radarr \
            --url http://127.0.0.1:${toString cfg.radarr.port} \
            --api-key-file "${config.sops.secrets.arr_radarr_api_key.path}" \
            --script-path "${arrNotifyPkg}/bin/arr-notify"
        ''}";
      };
    };
  };
}
