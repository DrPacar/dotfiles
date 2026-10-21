{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf any optional types;
  cfg = config.arr;
in {
  options.arr.vpn = {
    enable = mkOption {
      type = types.bool;
      default = false; # Disabled by default; enable once a valid WireGuard configuration file is provisioned
      description = "Confine qBittorrent to a dedicated WireGuard network namespace.";
    };

    namespace = mkOption {
      type = types.str;
      default = "wg";
      description = "Name of the VPN network namespace (must be shorter than 8 characters).";
    };

    wgConfFile = mkOption {
      type = types.nullOr types.str;
      default = config.sops.secrets.arr_wireguard_conf.path or null;
      description = "Filesystem path to WireGuard configuration file (managed via sops-nix).";
    };

    accessibleFrom = mkOption {
      type = types.listOf types.str;
      default = [
        "10.0.0.0/8" # RFC 1918 Class A
        "172.16.0.0/12" # RFC 1918 Class B
        "192.168.0.0/16" # RFC 1918 Class C (Home LANs)
        "100.64.0.0/10" # RFC 6598 Carrier-Grade NAT (Tailscale CGNAT)
      ];
      description = "Subnets or IP ranges in the host namespace that can reach VPN-confined services across the bridge.";
    };

    openVPNPorts = mkOption {
      type = types.listOf (types.submodule {
        options = {
          port = mkOption {
            type = types.port;
            description = "Port number forwarded through the VPN provider.";
          };
          protocol = mkOption {
            type = types.enum ["tcp" "udp" "both"];
            default = "both";
            description = "Protocol for the forwarded port (both TCP and UDP recommended for BitTorrent).";
          };
        };
      });
      default = [];
      description = "Port forwarding rules inside the VPN namespace for incoming BitTorrent peer traffic.";
    };

    portForwarding = {
      enable = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "Enable automatic NAT-PMP port forwarding with ProtonVPN for qBittorrent.";
      };

      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Internal VPN gateway IP for NAT-PMP requests. If null, automatically detected dynamically from the routing table.";
      };

      leaseDuration = mkOption {
        type = types.ints.unsigned;
        default = 60;
        description = "Port lease duration in seconds requested from the VPN gateway.";
      };

      refreshInterval = mkOption {
        type = types.ints.unsigned;
        default = 45;
        description = "Interval in seconds to renew the NAT-PMP port lease.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.vpn.enable) (let
    namespaceAddress = config.vpnNamespaces.${cfg.vpn.namespace}.namespaceAddress;
  in {
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
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
      };
    };

    systemd.services.qbittorrent-webui-proxy = mkIf cfg.qbittorrent.enable {
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
            exec ${pkgs.bash}/bin/bash ${../scripts/cleanup-stale-nat.sh} "${namespaceAddress}" "${toString cfg.qbittorrent.webuiPort}"
          ''}"
        ];
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.qbittorrent.webuiPort},bind=${cfg.network.bindAddress},fork,reuseaddr TCP:${namespaceAddress}:${toString cfg.qbittorrent.webuiPort}";
        Restart = "always";
        RestartSec = 3;
        User = "nobody";
      };
    };

    systemd.services.protonvpn-port-forward = mkIf (cfg.vpn.portForwarding.enable && cfg.qbittorrent.enable) {
      description = "ProtonVPN NAT-PMP dynamic port forwarder for qBittorrent";
      after = [
        "${cfg.vpn.namespace}.service"
        "qbittorrent.service"
      ];
      requires = [
        "${cfg.vpn.namespace}.service"
        "qbittorrent.service"
      ];
      wantedBy = ["multi-user.target"];

      path = with pkgs; [
        bash
        libnatpmp
        curl
        iptables
        coreutils
        gnugrep
        gawk
        iproute2
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        NetworkNamespacePath = "/run/netns/${cfg.vpn.namespace}";
        User = "root";
        ExecStart = ''
          ${pkgs.bash}/bin/bash ${../scripts/protonvpn-port-forward.sh} \
            --webui-host "${namespaceAddress}" \
            --webui-port "${toString cfg.qbittorrent.webuiPort}" \
            --pass-file "${config.sops.secrets.arr_qbittorrent_password.path}" \
            ${lib.optionalString (cfg.vpn.portForwarding.gateway != null) "--gateway \"${cfg.vpn.portForwarding.gateway}\""} \
            --lease-duration "${toString cfg.vpn.portForwarding.leaseDuration}" \
            --refresh-interval "${toString cfg.vpn.portForwarding.refreshInterval}" \
            --max-connections "${toString cfg.qbittorrent.maxConnections}" \
            --max-connections-per-torrent "${toString cfg.qbittorrent.maxConnectionsPerTorrent}" \
            --max-active-downloads "${toString cfg.qbittorrent.maxActiveDownloads}" \
            --max-active-torrents "${toString cfg.qbittorrent.maxActiveTorrents}" \
            --download-limit-kib "${toString cfg.qbittorrent.downloadRateLimitKiB}" \
            --upload-limit-kib "${toString cfg.qbittorrent.uploadRateLimitKiB}"
        '';
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
  });
}
