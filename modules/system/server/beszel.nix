{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
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
      description = "Subdomain for Beszel Hub dashboard (e.g. system.media.lukpac.dev).";
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
    };
  };

  config = mkIf (cfg.enable && cfg.beszel.enable) {
    # 1. Beszel Hub (Web dashboard & metrics database)
    systemd.services.beszel-hub = {
      description = "Beszel Hub - Server Resource Monitoring Dashboard";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.beszel}/bin/beszel-hub serve --http 127.0.0.1:${toString cfg.beszel.port} --dir /var/lib/beszel-hub";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "beszel-hub";
        DynamicUser = true;
      };
    };

    # 2. Beszel Agent (Local metrics collector daemon)
    # Starts automatically when an authentication key or environmentFile is configured
    systemd.services.beszel-agent = mkIf (cfg.beszel.agent.enable && (cfg.beszel.agent.key != null || cfg.beszel.agent.keyFile != null || cfg.beszel.agent.environmentFile != null)) {
      description = "Beszel Agent - Hardware & System Metrics Collector";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [smartmontools];

      environment =
        {
          PORT = toString cfg.beszel.agent.port;
        }
        // lib.optionalAttrs (cfg.beszel.agent.key != null) {
          KEY = cfg.beszel.agent.key;
        }
        // lib.optionalAttrs (cfg.beszel.agent.keyFile != null) {
          KEY_FILE = toString cfg.beszel.agent.keyFile;
        };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.beszel}/bin/beszel-agent";
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = mkIf (cfg.beszel.agent.environmentFile != null) cfg.beszel.agent.environmentFile;
      };
    };
  };
}
