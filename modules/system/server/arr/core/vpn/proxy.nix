{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  vpn = import ./_lib.nix {inherit config lib;};

  cleanupStaleNatScript = pkgs.writeShellApplication {
    name = "arr-vpn-cleanup-stale-nat";
    runtimeInputs = with pkgs; [
      iptables
      coreutils
    ];
    text = builtins.readFile ./scripts/cleanup-stale-nat.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.vpn.enable && cfg.qbittorrent.enable) (let
    namespaceAddress = config.vpnNamespaces.${vpn.ns}.namespaceAddress;
  in {
    systemd.services.qbittorrent-webui-proxy = {
      description = "qBittorrent WebUI host proxy for VPN confinement";
      after = [
        "${vpn.ns}.service"
        "qbittorrent.service"
      ];
      bindsTo = [
        "${vpn.ns}.service"
        "qbittorrent.service"
      ];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStartPre = [
          "+${cleanupStaleNatScript}/bin/arr-vpn-cleanup-stale-nat ${namespaceAddress} ${toString cfg.qbittorrent.webuiPort}"
        ];
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.qbittorrent.webuiPort},bind=${cfg.network.bindAddress},fork,reuseaddr TCP:${namespaceAddress}:${toString cfg.qbittorrent.webuiPort}";
        Restart = "always";
        RestartSec = "3s";
        # socat exits with 143 on SIGTERM during unit restarts / nh os switch
        SuccessExitStatus = ["SIGTERM" "143"];
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
