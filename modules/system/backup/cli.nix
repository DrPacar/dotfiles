{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.backup;

  backupCli = pkgs.writeShellApplication {
    name = "backup";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      systemd
      restic
      util-linux
      fuse3
      findutils
    ];
    text = ''
      export RESTIC_SERVER_ENABLED="${
        if cfg.server.enable
        then "1"
        else "0"
      }"
      export RESTIC_SERVER_DATA_DIR="''${RESTIC_SERVER_DATA_DIR:-${cfg.server.dataDir}}"
      export RESTIC_LOCAL_REPO="''${RESTIC_LOCAL_REPO:-${
        if !cfg.server.enable && cfg.client.enable && cfg.client.repository != null && lib.hasPrefix "/" cfg.client.repository
        then cfg.client.repository
        else ""
      }}"
      export RESTIC_CLIENT_PRUNE_OPTS="''${RESTIC_CLIENT_PRUNE_OPTS:-${lib.concatStringsSep " " cfg.client.pruneOpts}}"
      export RESTIC_PASSWORD_FILE="''${RESTIC_PASSWORD_FILE:-${cfg.passwordFile}}"
      export RESTIC_KEEP_DAILY="''${RESTIC_KEEP_DAILY:-${toString cfg.server.prune.keepDaily}}"
      export RESTIC_KEEP_WEEKLY="''${RESTIC_KEEP_WEEKLY:-${toString cfg.server.prune.keepWeekly}}"
      export RESTIC_KEEP_MONTHLY="''${RESTIC_KEEP_MONTHLY:-${toString cfg.server.prune.keepMonthly}}"
      export RESTIC_KEEP_YEARLY="''${RESTIC_KEEP_YEARLY:-${toString cfg.server.prune.keepYearly}}"
      export RESTIC_CHECK_ENABLED="${
        if cfg.server.prune.check.enable
        then "1"
        else "0"
      }"
      export RESTIC_READ_DATA_SUBSET="''${RESTIC_READ_DATA_SUBSET:-${
        if cfg.server.prune.check.enable && cfg.server.prune.check.readDataSubset != null
        then cfg.server.prune.check.readDataSubset
        else ""
      }}"

      exec ${./scripts/backup.sh} "$@"
    '';
  };
in {
  options.backup.cli = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the unified 'backup' CLI utility in environment.systemPackages.";
    };

    package = mkOption {
      type = types.package;
      default = backupCli;
      readOnly = true;
      description = "The compiled backup CLI package.";
    };
  };

  config = mkIf (cfg.enable && cfg.cli.enable) {
    environment.systemPackages = [
      backupCli
    ];
  };
}
