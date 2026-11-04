{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf any optional;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.vpn.enable) {
    warnings = optional (cfg.vpn.openVPNPorts == [] && !cfg.vpn.portForwarding.enable) "arr.vpn: arr.vpn.openVPNPorts is empty and arr.vpn.portForwarding is disabled. qBittorrent can download via outgoing connections, but cannot receive incoming peer connections without port forwarding.";

    assertions =
      [
        {
          assertion = cfg.vpn.wgConfFile != null;
          message = "arr.vpn: arr.vpn.wgConfFile must be set to the path of your WireGuard configuration file (e.g., config.sops.secrets.arr_wireguard_conf.path) when arr.vpn.enable is true.";
        }
        {
          assertion = builtins.stringLength cfg.vpn.namespace < 8;
          message = "arr.vpn: arr.vpn.namespace must be shorter than 8 characters (current: '${cfg.vpn.namespace}') due to Linux network interface name limits (IFNAMSIZ).";
        }
      ]
      ++ lib.optional cfg.qbittorrent.enable {
        assertion =
          cfg.vpn.openVPNPorts
          == []
          || cfg.vpn.portForwarding.enable
          || any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "both") cfg.vpn.openVPNPorts
          || (any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "tcp") cfg.vpn.openVPNPorts
            && any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "udp") cfg.vpn.openVPNPorts);
        message = "arr.vpn: arr.vpn.openVPNPorts must forward both TCP and UDP for arr.qbittorrent.bitTorrentPort (${toString cfg.qbittorrent.bitTorrentPort}) (set protocol = \"both\").";
      };

    environment.systemPackages = [pkgs.wireguard-tools];

    # Automatically retry WireGuard on boot if Wi-Fi / network connection is still establishing
    systemd.services.${cfg.vpn.namespace} = {
      wants = ["network-online.target"] ++ lib.optional cfg.qbittorrent.enable "qbittorrent.service";
      after = ["network-online.target"];
      before = lib.optional cfg.qbittorrent.enable "qbittorrent.service";
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
        ExecStartPre = [
          "+${pkgs.writeShellScript "wait-for-default-route" ''
            for i in $(seq 1 30); do
              if ${pkgs.iproute2}/bin/ip route show default | grep -q default; then
                exit 0
              fi
              sleep 1
            done
            echo "No default route detected after 30s, continuing anyway..."
          ''}"
        ];
        ExecStartPost = [
          "+${pkgs.writeShellScript "vpn-post-up-fixes" ''
            # Ensure internal VPN gateway / DNS (10.2.0.1) is always routed directly through the tunnel
            ${pkgs.iproute2}/bin/ip -n ${cfg.vpn.namespace} route add 10.2.0.1/32 dev ${cfg.vpn.namespace}0 2>/dev/null || true
            # Allow fallback public DNS (Cloudflare 1.1.1.1) in firewall to bypass NetShield tracker blocking
            ${pkgs.iptables}/bin/ip netns exec ${cfg.vpn.namespace} ${pkgs.iptables}/bin/iptables -I dns-fw 1 -p udp -d 1.1.1.1 -j ACCEPT 2>/dev/null || true
            ${pkgs.iptables}/bin/ip netns exec ${cfg.vpn.namespace} ${pkgs.iptables}/bin/iptables -I dns-fw 1 -p tcp -d 1.1.1.1 -j ACCEPT 2>/dev/null || true
            if [ -f /etc/netns/${cfg.vpn.namespace}/resolv.conf ]; then
              if ! grep -q "1.1.1.1" /etc/netns/${cfg.vpn.namespace}/resolv.conf; then
                echo "nameserver 1.1.1.1" >> /etc/netns/${cfg.vpn.namespace}/resolv.conf
              fi
            fi
          ''}"
        ];
      };
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
      };
    };

    nixflix.vpn = {
      enable = true;
      inherit (cfg.vpn) namespace accessibleFrom openVPNPorts;
      # Provide a fallback path if null so evaluation can proceed to display the informative assertion error
      wgConfFile =
        if cfg.vpn.wgConfFile != null
        then cfg.vpn.wgConfFile
        else "/dev/null";
    };
  };
}
