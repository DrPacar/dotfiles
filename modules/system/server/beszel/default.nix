{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf optional optionals optionalAttrs;
  cfg = config.server;
  bzCfg = cfg.beszel;
  bz = import ./_lib.nix {inherit config lib pkgs;};

  syncConfigFile = pkgs.writeText "beszel-sync-config.json" (builtins.toJSON bz.syncPayload);
  notifyEnabled = cfg.notify.enable or false;
in {
  config = mkIf (cfg.enable && bzCfg.enable) {
    assertions = [
      {
        assertion = !bz.agentEnabled || bzCfg.port != bzCfg.agent.port;
        message = "server.beszel: 'port' and 'agent.port' cannot use the same TCP port.";
      }
    ];

    # 1. Beszel Hub (Web dashboard & PocketBase metrics database)
    systemd.services.beszel-hub = {
      description = "Beszel Hub - Server Resource Monitoring Dashboard";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.beszel}/bin/beszel-hub serve --http 127.0.0.1:${toString bzCfg.port} --dir /var/lib/beszel-hub";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "beszel-hub";
        DynamicUser = true;
        MemoryHigh = "256M";
        MemoryMax = "512M";
      };
    };

    # 2. Beszel Agent (Local metrics, SMART, systemd & Intel iGPU collector)
    systemd.services.beszel-agent = mkIf bz.agentEnabled {
      description = "Beszel Agent - Hardware & System Metrics Collector";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path =
        (with pkgs; [smartmontools])
        ++ optional bzCfg.agent.intelGpu.enable pkgs.intel-gpu-tools;

      environment =
        {
          PORT = toString bzCfg.agent.port;
        }
        // optionalAttrs (bzCfg.agent.key != null) {
          KEY = bzCfg.agent.key;
        }
        // optionalAttrs (bzCfg.agent.keyFile != null) {
          KEY_FILE = toString bzCfg.agent.keyFile;
        }
        // optionalAttrs (bzCfg.agent.extraFilesystems != []) {
          EXTRA_FILESYSTEMS = lib.concatStringsSep "," bzCfg.agent.extraFilesystems;
        }
        // optionalAttrs (bzCfg.agent.memCalc != null) {
          MEM_CALC = bzCfg.agent.memCalc;
        };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.beszel}/bin/beszel-agent";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "beszel-agent";
        MemoryHigh = "128M";
        MemoryMax = "256M";
        EnvironmentFile = mkIf (bzCfg.agent.environmentFile != null) bzCfg.agent.environmentFile;
      };
    };

    # 3. Declarative Hub Settings, ntfy Webhook & Baseline Alerts Sync
    systemd.services.beszel-sync = mkIf (bzCfg.notifications.ntfy.enable || bzCfg.alerts.enable) {
      description = "Synchronize Beszel Hub settings, ntfy webhook, and baseline alerts";
      after =
        ["beszel-hub.service"]
        ++ optional bz.agentEnabled "beszel-agent.service"
        ++ optional notifyEnabled "ntfy-sh.service";
      wants =
        ["beszel-hub.service"]
        ++ optionals notifyEnabled ["ntfy-sh.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [
        syncConfigFile
        ./scripts/beszel-sync.py
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "beszel-sync" ''
          set -euo pipefail
          exec ${pkgs.python3}/bin/python3 ${./scripts/beszel-sync.py} \
            --config ${syncConfigFile} \
            --systemctl ${pkgs.systemd}/bin/systemctl
        '';
      };
    };
  };
}
