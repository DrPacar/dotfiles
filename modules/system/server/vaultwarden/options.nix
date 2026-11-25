{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.server.vaultwarden = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Vaultwarden lightweight Bitwarden-compatible password manager.";
    };

    port = mkOption {
      type = types.port;
      default = 8222;
      description = "Internal HTTP port on which Vaultwarden listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "vault";
      description = "Primary subdomain for Vaultwarden (e.g. vault.lukpac.dev).";
    };

    signupsAllowed = mkOption {
      type = types.bool;
      default = false;
      description = "Whether new user registrations are permitted. Defaults to false to protect an initialized vault.";
    };

    invitationsAllowed = mkOption {
      type = types.bool;
      default = false;
      description = "Whether organization/user invitations are permitted.";
    };

    trashAutoDeleteDays = mkOption {
      type = types.ints.unsigned;
      default = 30;
      description = "Days before soft-deleted vault items in trash are permanently purged (0 disables auto-purge).";
    };

    passwordIterations = mkOption {
      type = types.ints.positive;
      default = 600000;
      description = "Minimum PBKDF2-HMAC-SHA256 client KDF iterations enforced for accounts.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Optional filesystem path (string, not a Nix store path literal) to an environment file
        containing secrets such as ADMIN_TOKEN or SMTP credentials.
      '';
    };

    backup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated atomic SQLite WAL backups via systemd timer.";
      };

      dir = mkOption {
        type = types.str;
        default = "/var/backup/vaultwarden";
        description = "Destination directory for Vaultwarden backups (must be outside Vaultwarden's state directory).";
      };

      calendar = mkOption {
        type = types.str;
        default = "03:30";
        description = "Systemd OnCalendar schedule for automated Vaultwarden backups.";
      };
    };

    cli = {
      enable = mkEnableOption "the 'vaultwarden' status, health check, and backup CLI" // {default = true;};
    };

    watchdog = {
      enable = mkEnableOption "automated watchdog monitoring Vaultwarden /alive endpoint" // {default = true;};

      interval = mkOption {
        type = types.str;
        default = "2m";
        description = "Interval between watchdog checks (systemd timer syntax).";
      };

      failureThreshold = mkOption {
        type = types.ints.positive;
        default = 3;
        description = "Consecutive failed /alive probes before restarting vaultwarden.service.";
      };
    };

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = config.server.notify.enable or false;
        description = "Enable alerts when Vaultwarden fails, recovers, or restarts.";
      };

      handler = mkOption {
        type = types.nullOr (types.either types.str types.package);
        default = null;
        example = lib.literalExpression ''
          '''
            # $1 contains the alert message string, $2 an optional tag
            ntfy-send media "$1" "Vaultwarden Alert" "$2"
          '''
        '';
        description = ''
          Custom notification handler invoked on Vaultwarden watchdog events.
          Receives the alert message string as $1 and an optional severity/ntfy tag as $2.
          Defaults to server.notify (ntfy) when null and server.notify.enable is true.
        '';
      };
    };
  };
}
