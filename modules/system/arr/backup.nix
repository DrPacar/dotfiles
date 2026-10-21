{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types optionalAttrs;
  cfg = config.arr;

  allSupportedServices = [
    "jellyfin"
    "qbittorrent"
    "radarr"
    "sonarr"
    "sonarr-anime"
    "prowlarr"
    "bazarr"
    "seerr"
  ];

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
  options.arr.backup = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether to enable automated, lightweight backups for Arr stack databases and configurations.";
    };

    destDir = mkOption {
      type = types.str;
      default = "${cfg.dataDir}/backups";
      description = "Directory where compressed backup archives are stored.";
    };

    calendar = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      example = "daily";
      description = "Systemd OnCalendar event expression defining backup execution frequency.";
    };

    retentionDays = mkOption {
      type = types.ints.positive;
      default = 14;
      description = "Number of days to keep backup archives before automatic pruning.";
    };

    services = mkOption {
      type = types.listOf (types.enum allSupportedServices);
      default = allSupportedServices;
      description = ''
        List of services to back up.
        Only services that are both in this list AND actually enabled in arr will be backed up.
      '';
    };
  };

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
