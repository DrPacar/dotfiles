{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;

  allSupportedServices = [
    "jellyfin"
    "qbittorrent"
    "radarr"
    "sonarr"
    "prowlarr"
    "bazarr"
    "seerr"
  ];
in {
  options.server.arr.backup = {
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
}
