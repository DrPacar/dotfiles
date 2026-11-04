{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.server.arr;

  # Filter services that are selected in the backup list AND currently enabled in the arr stack
  activeBackupServices =
    lib.filter (
      svc:
        (svc == "jellyfin" && cfg.jellyfin.enable)
        || (svc == "qbittorrent" && cfg.qbittorrent.enable)
        || (svc == "radarr" && cfg.radarr.enable)
        || (svc == "sonarr" && cfg.sonarr.enable)
        || (svc == "sonarr-anime" && cfg.sonarr.enable && cfg.sonarr.anime.enable)
        || (svc == "prowlarr" && cfg.prowlarr.enable)
        || (svc == "bazarr" && cfg.bazarr.enable)
        || (svc == "bazarr-anime" && cfg.bazarr.enable && cfg.bazarr.anime.enable)
        || (svc == "seerr" && cfg.seerr.enable)
    )
    cfg.backup.services;

  backupScript = pkgs.writeShellApplication {
    name = "arr-backup";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnutar
      zstd
      sqlite
    ];
    text = builtins.readFile ./scripts/backup.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.backup.enable) {
    # Ensure backup directory exists with shared media group permissions
    systemd.tmpfiles.settings."10-arr-backup" = {
      "${cfg.backup.destDir}".d = {
        mode = "2775";
        user = "root";
        group = cfg.mediaGroup;
      };
    };

    # Oneshot service for backup execution
    systemd.services.arr-backup = {
      description = "Automated Arr Stack database and configuration backup";
      serviceConfig =
        {
          Type = "oneshot";
          User = "root";
          ExecStart = "${backupScript}/bin/arr-backup --dest-dir '${cfg.backup.destDir}' --media-group '${cfg.mediaGroup}' --retention-days ${toString cfg.backup.retentionDays} --services '${lib.concatStringsSep " " activeBackupServices}'";
        }
        // optionalAttrs (cfg.resources.enable) {
          Slice = "arr.slice";
        };
    };

    # Timer triggering periodic execution
    systemd.timers.arr-backup = {
      description = "Automated Arr Stack backup timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.backup.calendar;
        Persistent = true;
      };
    };
  };
}
