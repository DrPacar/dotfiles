{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.vpn.enable && cfg.qbittorrent.enable) (let
    namespaceAddress = config.vpnNamespaces.${cfg.vpn.namespace}.namespaceAddress;
  in {
    systemd.services.qbittorrent-webui-proxy = {
      description = "qBittorrent WebUI host proxy for VPN confinement";
      after = [
        "${cfg.vpn.namespace}.service"
        "qbittorrent.service"
      ];
      requires = [
        "${cfg.vpn.namespace}.service"
        "qbittorrent.service"
      ];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStartPre = [
          "+${pkgs.writeShellScript "cleanup-stale-nat" ''
            export PATH="${lib.makeBinPath [pkgs.iptables pkgs.coreutils]}:$PATH"
            exec ${pkgs.bash}/bin/bash ${../../scripts/cleanup-stale-nat.sh} "${namespaceAddress}" "${toString cfg.qbittorrent.webuiPort}"
          ''}"
        ];
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.qbittorrent.webuiPort},bind=${cfg.network.bindAddress},fork,reuseaddr TCP:${namespaceAddress}:${toString cfg.qbittorrent.webuiPort}";
        Restart = "always";
        RestartSec = 3;
        DynamicUser = true;
        Slice = "arr.slice";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  });
}
