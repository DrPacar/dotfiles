{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) hasPrefix mkForce mkIf;
  cfg = config.server;
  vwCfg = cfg.vaultwarden;
  vw = import ./_lib.nix {inherit config lib pkgs;};

  watchdogScript = pkgs.writeShellApplication {
    name = "vaultwarden-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      curl
      coreutils
    ];
    runtimeEnv =
      vw.commonEnv
      // {
        FAILURE_THRESHOLD = toString vwCfg.watchdog.failureThreshold;
      };
    text = builtins.readFile ./scripts/watchdog.sh;
  };
in {
  config = mkIf (cfg.enable && vwCfg.enable) {
    assertions = [
      {
        assertion = vwCfg.environmentFile == null || !(hasPrefix builtins.storeDir vwCfg.environmentFile);
        message = "server.vaultwarden: 'environmentFile' must not point to a path in the Nix store (secrets would be world-readable).";
      }
      {
        assertion = !vwCfg.backup.enable || (hasPrefix "/" vwCfg.backup.dir && !(hasPrefix vw.dataDir vwCfg.backup.dir));
        message = "server.vaultwarden: 'backup.dir' must be an absolute path outside '${vw.dataDir}'.";
      }
    ];

    services.vaultwarden = {
      enable = true;
      backupDir = mkIf vwCfg.backup.enable vwCfg.backup.dir;
      environmentFile = mkIf (vwCfg.environmentFile != null) vwCfg.environmentFile;

      config = {
        DOMAIN = vw.vaultUrl;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = vwCfg.port;
        IP_HEADER = "X-Real-IP";
        SIGNUPS_ALLOWED = vwCfg.signupsAllowed;
        INVITATIONS_ALLOWED = vwCfg.invitationsAllowed;
        SHOW_PASSWORD_HINT = false;
        TRASH_AUTO_DELETE_DAYS = vwCfg.trashAutoDeleteDays;
        PASSWORD_ITERATIONS = vwCfg.passwordIterations;
        EMERGENCY_ACCESS_ALLOWED = true;
        SENDS_ALLOWED = true;
        EXTENDED_LOGGING = true;
        LOG_LEVEL = "info";
      };
    };

    systemd.services = {
      vaultwarden = {
        serviceConfig = {
          MemoryHigh = "256M";
          MemoryMax = "512M";
          RestartSec = "5s";
        };
        unitConfig = {
          StartLimitIntervalSec = mkForce 0;
        };
      };

      vaultwarden-watchdog = mkIf vwCfg.watchdog.enable {
        description = "Health check and auto-recovery for Vaultwarden";
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "vaultwarden-watchdog";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = "${watchdogScript}/bin/vaultwarden-watchdog";
        };
      };
    };

    systemd.timers = {
      backup-vaultwarden = mkIf vwCfg.backup.enable {
        timerConfig.OnCalendar = vwCfg.backup.calendar;
      };

      vaultwarden-watchdog = mkIf vwCfg.watchdog.enable {
        description = "Timer for Vaultwarden /alive health check";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = vwCfg.watchdog.interval;
          RandomizedDelaySec = "10s";
        };
      };
    };
  };
}
