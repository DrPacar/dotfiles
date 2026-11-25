{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.backup;
in {
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
      description = "Filesystem path (string, not a Nix store path literal) to the Restic repository encryption password.";
    };

    # ==========================================
    # MONITORING & NOTIFICATIONS
    # ==========================================
    notifications = {
      enable = mkOption {
        type = types.bool;
        default = config.server.notify.enable or false;
        description = "Enable automated failure notification hooks on backup and prune services.";
      };

      handler = mkOption {
        type = types.nullOr (types.either types.str types.package);
        default = null;
        example = lib.literalExpression ''
          '''
            # $1 contains the alert message string, $2 an optional tag
            ntfy-send media "$1" "Backup Alert" "$2"
          '''
        '';
        description = ''
          Custom notification handler invoked on backup or prune failures.
          Receives the formatted message string as $1 and a tag as $2.
          Defaults to server.notify (ntfy) when null and server.notify.enable is true.
        '';
      };

      onFailureCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "curl -d \"Backup failed on $(hostname): $FAILED_UNIT\" https://ntfy.sh/my-backup-alerts";
        description = ''
          Additional shell command executed when a backup or prune service fails.
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
        description = "Whether this host should periodically back up local folders to a central Restic REST server or repository.";
      };

      serverUrl = mkOption {
        type = types.nullOr types.str;
        default =
          if cfg.server.enable
          then "http://127.0.0.1:${toString cfg.server.port}"
          else null;
        example = "http://100.64.0.2:8000";
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
          "/var/backup/vaultwarden"
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
          "**/lost+found"
          "**/.Trash-*"
          "/home/*/.local/share/Trash"
          "/home/*/.local/share/Steam"
        ];
        description = "List of glob patterns to exclude from backups.";
      };

      databases = {
        postgresql = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically create an atomic pg_dumpall snapshot before Restic runs (when services.postgresql.enable = true).";
          };

          dumpDir = mkOption {
            type = types.str;
            default = "/var/backup/postgresql";
            description = "Destination directory for pre-backup PostgreSQL SQL dumps.";
          };
        };

        sqlite = mkOption {
          type = types.listOf (types.submodule {
            options = {
              path = mkOption {
                type = types.str;
                example = "/var/lib/paperless/db.sqlite3";
                description = "Source SQLite database file path.";
              };
              destName = mkOption {
                type = types.str;
                example = "paperless.sqlite3";
                description = "Filename inside /var/backup/sqlite for the atomic online backup copy.";
              };
            };
          });
          default = [];
          description = "Live SQLite databases to snapshot safely with 'sqlite3 .backup' before Restic runs.";
        };
      };

      backupPrepareCommand = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Optional custom shell commands executed immediately before each Restic backup.";
      };

      backupCleanupCommand = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Optional custom shell commands executed after each Restic backup (even on failure).";
      };

      oneFileSystem = mkOption {
        type = types.bool;
        default = false;
        description = "Pass --one-file-system to restic backup so mounted network/removable filesystems are skipped.";
      };

      timerConfig = mkOption {
        type = types.attrsOf types.anything;
        default = {
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
        default = ["--exclude-caches"];
        description = "Additional arguments passed to restic backup.";
      };

      pruneOpts = mkOption {
        type = types.listOf types.str;
        default =
          if cfg.server.enable || cfg.client.repository == null || lib.hasPrefix "rest:" cfg.client.repository
          then []
          else [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
            "--keep-yearly 1"
          ];
        description = ''
          Retention pruning flags passed to services.restic.backups.central.
          Defaults to [] when using a Restic REST server (server handles pruning to protect append-only repos),
          and applies standard retention (7d/4w/12m/1y) automatically for local repositories.
        '';
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
          Set to 'tailscale0' for Tailscale-only access, or null to open on all interfaces.
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
        description = "Allow client connections without HTTP Basic auth (recommended when restricted to Tailscale).";
      };

      htpasswdFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/secrets/restic-htpasswd";
        description = "Optional filesystem path (not a Nix store path literal) to an htpasswd file for HTTP Basic authentication.";
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
          description = "OnCalendar schedule for server retention pruning.";
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
              Set to null to only verify index and metadata structures.
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
}
