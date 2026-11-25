{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) hasPrefix mkIf optional optionals;
  cfg = config.backup;
  bk = import ./_lib.nix {inherit config lib pkgs;};
in {
  imports = [
    ./cli.nix
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.client.enable || cfg.server.enable;
        message = "backup: At least one of 'backup.client.enable' or 'backup.server.enable' must be true when 'backup.enable = true'.";
      }
      {
        assertion = !(hasPrefix builtins.storeDir cfg.passwordFile);
        message = "backup: 'passwordFile' must not point to a path in the Nix store (secrets would be world-readable).";
      }
      {
        assertion = cfg.server.htpasswdFile == null || !(hasPrefix builtins.storeDir cfg.server.htpasswdFile);
        message = "backup.server: 'htpasswdFile' must not point to a path in the Nix store (secrets would be world-readable).";
      }
      {
        assertion = !cfg.client.enable || (cfg.client.repository != null || cfg.client.serverUrl != null);
        message = "backup.client: You must specify either 'backup.client.serverUrl' or 'backup.client.repository' when client backups are enabled.";
      }
      {
        assertion = !cfg.client.enable || (bk.effectivePaths != []);
        message = "backup.client: 'backup.client.paths' (or database backups) cannot be empty when client backups are enabled.";
      }
      {
        assertion = !cfg.server.enable || hasPrefix "/" cfg.server.dataDir;
        message = "backup.server: 'dataDir' must be an absolute path.";
      }
    ];

    environment.systemPackages = [
      pkgs.restic
    ];

    # Allow non-root users to browse FUSE-mounted backup repositories
    programs.fuse.userAllowOther = true;

    # ==========================================
    # NOTIFICATION ON FAILURE SERVICE
    # ==========================================
    systemd.services."backup-failure-alert@" = mkIf cfg.notifications.enable {
      description = "Backup failure alert for %i";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart =
          pkgs.writeShellScript "backup-failure-alert" ''
            set -euo pipefail
            UNIT="''${1:-unknown-unit}"
            HOST="$(hostname)"
            DATE="$(date --iso-8601=seconds)"
            MSG="Backup (${config.networking.hostName}): Service $UNIT failed at $DATE."

            echo "$MSG" | ${pkgs.util-linux}/bin/logger -p user.err -t backup-alert

            ${lib.optionalString (bk.notifyBin != "") ''
              if ! ${bk.notifyBin} "$MSG" "rotating_light"; then
                echo "WARN: [backup-alert] Notification handler failed." >&2
              fi
            ''}

            ${lib.optionalString (cfg.notifications.onFailureCommand != null) ''
              export FAILED_UNIT="$UNIT"
              export FAILED_HOST="$HOST"
              export FAILED_DATE="$DATE"
              export FAILED_MESSAGE="$MSG"
              ${cfg.notifications.onFailureCommand}
            ''}
          ''
          + " %i";
      };
    };

    # ==========================================
    # RESTIC REST SERVER CONFIGURATION
    # ==========================================
    services.restic.server = mkIf cfg.server.enable {
      enable = true;
      dataDir = cfg.server.dataDir;
      listenAddress = toString cfg.server.port;
      appendOnly = cfg.server.appendOnly;
      htpasswd-file = cfg.server.htpasswdFile;
      privateRepos = cfg.server.privateRepos;
      extraFlags = lib.optional (cfg.server.noAuth && cfg.server.htpasswdFile == null) "--no-auth";
    };

    networking.firewall.allowedTCPPorts = mkIf (cfg.server.enable && cfg.server.openFirewall && cfg.server.firewallInterface == null) [
      cfg.server.port
    ];

    networking.firewall.interfaces = mkIf (cfg.server.enable && cfg.server.openFirewall && cfg.server.firewallInterface != null) {
      ${cfg.server.firewallInterface}.allowedTCPPorts = [cfg.server.port];
    };

    systemd.tmpfiles.rules =
      lib.optionals cfg.server.enable [
        "d ${cfg.server.dataDir} 0750 restic restic -"
      ]
      ++ lib.optionals (cfg.client.enable && cfg.client.repository != null && hasPrefix "/" cfg.client.repository) [
        "d ${cfg.client.repository} 0700 root root -"
      ];

    systemd.services.restic-server-prune = mkIf (cfg.server.enable && cfg.server.prune.enable) {
      description = "Restic central server retention pruning and verification";
      unitConfig = mkIf cfg.notifications.enable {
        OnFailure = ["backup-failure-alert@%n.service"];
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Nice = 10;
        IOSchedulingClass = "idle";
        ExecStart = "${cfg.cli.package}/bin/backup prune";
      };
    };

    systemd.timers.restic-server-prune = mkIf (cfg.server.enable && cfg.server.prune.enable) {
      description = "Timer for Restic central server retention pruning";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.server.prune.calendar;
        Persistent = true;
      };
    };

    # ==========================================
    # CLIENT BACKUP JOB
    # ==========================================
    services.restic.backups = mkIf cfg.client.enable {
      central = {
        inherit (cfg) passwordFile;
        repository =
          if cfg.client.repository != null
          then cfg.client.repository
          else "rest:${cfg.client.serverUrl}/${cfg.client.repoName}";
        paths = bk.effectivePaths;
        exclude =
          cfg.client.exclude
          ++ lib.optional (cfg.client.repository != null && hasPrefix "/" cfg.client.repository) cfg.client.repository;
        inherit (cfg.client) timerConfig initialize inhibitsSleep pruneOpts;
        extraBackupArgs =
          (optional cfg.client.oneFileSystem "--one-file-system")
          ++ cfg.client.extraBackupArgs;
        backupPrepareCommand = mkIf (bk.prepareScript != null) "${bk.prepareScript}";
        backupCleanupCommand = mkIf (cfg.client.backupCleanupCommand != null) cfg.client.backupCleanupCommand;
      };
    };

    systemd.services.restic-backups-central = mkIf cfg.client.enable {
      unitConfig = mkIf cfg.notifications.enable {
        OnFailure = ["backup-failure-alert@%n.service"];
      };
      after =
        optionals cfg.server.enable ["restic-rest-server.service"]
        ++ optionals bk.postgresActive ["postgresql.service"];
      wants = optionals cfg.server.enable ["restic-rest-server.service"];
      serviceConfig = {
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
  };
}
