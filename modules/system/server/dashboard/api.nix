{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;

  servicesList = import ./_services.nix {inherit lib config;};

  servicePortsJson = builtins.toJSON (
    lib.listToAttrs (map (s: {
        name = s.serviceKey;
        value = s.port;
      })
      servicesList)
  );
in {
  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    # Background service providing real-time network throughput and service health checks
    systemd.services.server-dashboard-api = {
      description = "Server Dashboard Real-time Stats & Health API";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${./api.py} --port 9095 --services '${servicePortsJson}'";
        Restart = "always";
        RestartSec = 3;
      };
    };
  };
}
