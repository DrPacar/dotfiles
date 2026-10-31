{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.backup;
in {
  imports = [
    ./cli.nix
  ];

  options.backup = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable declarative centralized Restic backup system.";
    };

    passwordFile = mkOption {
      type = types.str;
      default =
        if config.sops.secrets ? restic-password
        then config.sops.secrets.restic-password.path
        else "/run/secrets/restic-password";
      description = "Path to the secret file containing the Restic repository encryption password.";
    };

    # ==========================================
    # MONITORING & NOTIFICATIONS
    # ==========================================
    notifications = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable automated failure notification hooks on backup and prune services.";
      };

      onFailureCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "curl -d \"Backup failed on $(hostname): $FAILED_UNIT\" https://ntfy.sh/my-backup-alerts";
        description = ''
          Custom shell command executed when a backup or prune service fails.
          Available environment variables: $FAILED_UNIT, $FAILED_HOST, $FAILED_DATE, $FAILED_MESSAGE.
        '';
      };
    };

    # ==========================================
    # CLIENT ROLE (Handles all data backups)
    # ==========================================
    client = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this host should periodically back up local folders to a central Restic REST server or local repository.";
      };

      serverUrl = mkOption {
        type = types.nullOr types.str;
        default =
          if cfg.server.enable
          then "http://127.0.0.1:${toString cfg.server.port}"
          else null;
        example = "http://backup-server:8000";
        description = "Base URL of the central Restic REST server. Automatically defaults to localhost if the server role is active on this host.";
      };

      repoName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "Repository name / sub-path on the server for this host.";
      };

      repository = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Explicit Restic repository URL.
          If null, defaults to "rest:''${cfg.client.serverUrl}/''${cfg.client.repoName}".
        '';
      };

      paths = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [
          "/home/user/Documents"
          "/home/user/projects"
          "/data"
        ];
        description = "List of filesystem paths to include in the backup.";
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [
          "**/.cache"
          "**/node_modules"
          "**/target"
          "**/.venv"
          "**/tmp"
          "**/*.tmp"
          "/home/*/.local/share/Trash"
          "/home/*/.local/share/Steam"
        ];
        description = "List of glob patterns to exclude from backups.";
      };

      timerConfig = mkOption {
        type = types.attrsOf types.anything;
        default = {
          # Runs daily at 02:00 with up to 30 min randomized delay to prevent lock collisions
          OnCalendar = "*-*-* 02:00:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        description = "Systemd timer configuration for automated client backups.";
      };

      initialize = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically initialize repository if it does not exist.";
      };

      inhibitsSleep = mkOption {
        type = types.bool;
        default = true;
        description = "Prevents the system from sleeping while a backup is in progress.";
      };

      extraBackupArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional arguments passed to restic backup.";
      };
    };

    # ==========================================
    # SERVER ROLE (Repository host & pruning)
    # ==========================================
    server = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to run a central Restic REST server on this host.";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/restic";
        example = "/backup/restic";
        description = "Filesystem path where repositories are stored.";
      };

      port = mkOption {
        type = types.port;
        default = 8000;
        description = "TCP port on which the Restic REST server listens.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to automatically open the server port in the firewall.";
      };

      firewallInterface = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tailscale0";
        description = ''
          Network interface on which to open the server port.
          Set to 'tailscale0' for Tailscale-only access, or null to open on all interfaces (standard LAN access).
        '';
      };

      appendOnly = mkOption {
        type = types.bool;
        default = true;
        description = "Enable append-only mode to prevent clients from deleting or overwriting historic backups.";
      };

      noAuth = mkOption {
        type = types.bool;
        default = true;
        description = "Allow client connections without HTTP Basic auth (recommended for trusted LAN / Tailscale).";
      };

      htpasswdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/etc/nixos/secrets/restic-htpasswd";
        description = "Optional path to htpasswd file for HTTP Basic authentication.";
      };

      privateRepos = mkOption {
        type = types.bool;
        default = false;
        description = "Enable private repos mode (users can only access subfolder matching their auth username).";
      };

      prune = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the server should run automated maintenance and retention pruning across local repos.";
        };

        calendar = mkOption {
          type = types.str;
          default = "Sun *-*-* 05:00:00";
          description = "OnCalendar schedule for server retention pruning (scheduled on Sunday morning to avoid collisions with daily client backups).";
        };

        check = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Run repository integrity check during weekly pruning.";
          };

          readDataSubset = mkOption {
            type = types.nullOr types.str;
            default = "5%";
            example = "10%";
            description = ''
              Percentage of actual data chunks to cryptographically verify (e.g. '5%' or '10%') to detect disk bit-rot.
              Set to null to only verify index and metadata structures without reading data chunks.
            '';
          };
        };

        keepDaily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily snapshots to retain.";
        };

        keepWeekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly snapshots to retain.";
        };

        keepMonthly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of monthly snapshots to retain.";
        };

        keepYearly = mkOption {
          type = types.int;
          default = 1;
          description = "Number of yearly snapshots to retain.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Sanity checks
    assertions = [
      {
        assertion = cfg.client.enable || cfg.server.enable;
        message = "backup: At least one of 'backup.client.enable' or 'backup.server.enable' must be true when 'backup.enable = true'.";
      }
      {
        assertion = !cfg.client.enable || (cfg.client.repository != null || cfg.client.serverUrl != null);
        message = "backup.client: You must specify either 'backup.client.serverUrl' or 'backup.client.repository' when client backups are enabled.";
      }
      {
        assertion = !cfg.client.enable || (cfg.client.paths != []);
        message = "backup.client: 'backup.client.paths' cannot be empty when client backups are enabled. Please specify which directories to back up.";
      }
    ];

    # Install restic package (CLI utility 'backup' is provided via ./cli.nix)
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
            MSG="[CRITICAL] Backup service $UNIT failed on $HOST at $DATE"

            echo "$MSG" | ${pkgs.util-linux}/bin/logger -p user.err -t backup-alert

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

    # Firewall configuration: Support both Tailscale-only and global LAN access
    networking.firewall.allowedTCPPorts = mkIf (cfg.server.enable && cfg.server.openFirewall && cfg.server.firewallInterface == null) [
      cfg.server.port
    ];

    networking.firewall.interfaces = mkIf (cfg.server.enable && cfg.server.openFirewall && cfg.server.firewallInterface != null) {
      ${cfg.server.firewallInterface}.allowedTCPPorts = [cfg.server.port];
    };

    # Ensure repository storage pool exists with proper restic user permissions
    systemd.tmpfiles.rules = mkIf cfg.server.enable [
      "d ${cfg.server.dataDir} 0750 restic restic -"
    ];

    # Server retention pruning service & timer
    systemd.services.restic-server-prune = mkIf (cfg.server.enable && cfg.server.prune.enable) {
      description = "Restic central server retention pruning and verification";
      unitConfig = mkIf cfg.notifications.enable {
        OnFailure = ["backup-failure-alert@%n.service"];
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
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
        paths = cfg.client.paths;
        inherit (cfg.client) exclude timerConfig initialize inhibitsSleep extraBackupArgs;
        pruneOpts = []; # Prune is executed server-side to protect append-only repositories
      };
    };

    # Systemd integrations for client backup service
    systemd.services.restic-backups-central = mkIf cfg.client.enable {
      unitConfig = mkIf cfg.notifications.enable {
        OnFailure = ["backup-failure-alert@%n.service"];
      };
      after = lib.optional cfg.server.enable "restic-rest-server.service";
      wants = lib.optional cfg.server.enable "restic-rest-server.service";
    };
  };
}
