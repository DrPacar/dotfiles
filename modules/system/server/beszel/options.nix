{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server;
in {
  options.server.beszel = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Beszel lightweight hardware and server resource monitoring.";
    };

    port = mkOption {
      type = types.port;
      default = 8090;
      description = "Internal HTTP port for Beszel Hub web dashboard.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "system";
      description = "Subdomain for Beszel Hub dashboard (e.g. system.lukpac.dev).";
    };

    agent = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable local Beszel agent on this host to collect system metrics.";
      };

      port = mkOption {
        type = types.port;
        default = 45876;
        description = "Internal port on which the local Beszel agent listens.";
      };

      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public SSH key from Beszel Hub for agent authentication.";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File path containing the public SSH key for agent authentication.";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional environment file for Beszel agent (e.g. KEY=...).";
      };

      intelGpu.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Include intel-gpu-tools (intel_gpu_top) in beszel-agent PATH for Intel QuickSync iGPU telemetry.";
      };

      extraFilesystems = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/mnt/storage"];
        description = "Additional mountpoints/devices passed via EXTRA_FILESYSTEMS to beszel-agent.";
      };

      memCalc = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "htop";
        description = "Optional MEM_CALC mode passed to beszel-agent (e.g. 'htop').";
      };
    };

    notifications.ntfy = {
      enable = mkOption {
        type = types.bool;
        default = cfg.notify.enable or false;
        description = "Automatically wire Beszel user webhook notifications to local server.notify (ntfy).";
      };

      url = mkOption {
        type = types.str;
        default = "ntfy://127.0.0.1:${toString (cfg.notify.port or 2586)}/${cfg.notify.alertTopic or "alerts"}?scheme=http";
        description = "Shoutrrr notification webhook URL synced into Beszel user settings.";
      };
    };

    alerts = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Declaratively provision baseline hardware/service alerts for the local system in Beszel.";
      };

      rules = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            value = mkOption {
              type = types.number;
              default = 0;
              description = "Threshold value for this Beszel alert rule.";
            };
            min = mkOption {
              type = types.int;
              default = 5;
              description = "Sustained duration in minutes before triggering (0 for instant alerts).";
            };
          };
        });
        default = {
          Status = {
            value = 0;
            min = 1;
          };
          CPU = {
            value = 90;
            min = 5;
          };
          Memory = {
            value = 90;
            min = 5;
          };
          Disk = {
            value = 88;
            min = 5;
          };
          Temperature = {
            value = 80;
            min = 5;
          };
          SystemdFailed = {
            value = 0;
            min = 0;
          };
        };
        description = "Baseline alert rules synchronized for the local host in Beszel.";
      };
    };

    cli.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the 'beszel-ctl' diagnostic and management utility.";
    };
  };
}
