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
        "192.168.0.0/16"
        "100.64.0.0/10" # Tailscale CGNAT subnet
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
        default = true;
        description = "Enable automatic NAT-PMP port forwarding with ProtonVPN for qBittorrent.";
      };

      gateway = mkOption {
        type = types.str;
        default = "10.2.0.1";
        description = "Internal VPN gateway IP for NAT-PMP requests.";
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

  config = mkIf (cfg.enable && cfg.vpn.enable) {
    warnings = optional (cfg.vpn.openVPNPorts == [] && !cfg.vpn.portForwarding.enable) "arr.vpn: arr.vpn.openVPNPorts is empty and arr.vpn.portForwarding is disabled. qBittorrent can download via outgoing connections, but cannot receive incoming peer connections without port forwarding.";

    assertions = [
      {
        assertion = cfg.vpn.wgConfFile != null;
        message = "arr.vpn: arr.vpn.wgConfFile must be set to the path of your WireGuard configuration file (e.g., config.sops.secrets.arr_wireguard_conf.path) when arr.vpn.enable is true.";
      }
      {
        assertion = builtins.stringLength cfg.vpn.namespace < 8;
        message = "arr.vpn: arr.vpn.namespace must be shorter than 8 characters (current: '${cfg.vpn.namespace}') due to Linux network interface name limits (IFNAMSIZ).";
      }
      {
        assertion =
          cfg.vpn.openVPNPorts
          == []
          || any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "both") cfg.vpn.openVPNPorts
          || (any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "tcp") cfg.vpn.openVPNPorts
            && any (p: p.port == cfg.qbittorrent.bitTorrentPort && p.protocol == "udp") cfg.vpn.openVPNPorts);
        message = "arr.vpn: arr.vpn.openVPNPorts must forward both TCP and UDP for arr.qbittorrent.bitTorrentPort (${toString cfg.qbittorrent.bitTorrentPort}) (set protocol = \"both\").";
      }
    ];

    environment.systemPackages = [pkgs.wireguard-tools];

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
        ExecStartPre = let
          cleanupScript = pkgs.writeShellScript "cleanup-stale-nat" ''
            while ${pkgs.iptables}/bin/iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport ${toString cfg.qbittorrent.webuiPort} -j DNAT --to-destination 192.168.15.1:${toString cfg.qbittorrent.webuiPort} 2>/dev/null; do :; done
            while ${pkgs.iptables}/bin/iptables -t nat -D OUTPUT -p tcp -m addrtype --dst-type LOCAL --dport ${toString cfg.qbittorrent.webuiPort} -j DNAT --to-destination 192.168.15.1:${toString cfg.qbittorrent.webuiPort} 2>/dev/null; do :; done
          '';
        in [
          "+${cleanupScript}"
        ];
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.qbittorrent.webuiPort},fork,reuseaddr TCP:192.168.15.1:${toString cfg.qbittorrent.webuiPort}";
        Restart = "always";
        RestartSec = 3;
        User = "nobody";
      };
    };

    systemd.services.protonvpn-port-forward = mkIf cfg.vpn.portForwarding.enable {
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

      path = [
        pkgs.libnatpmp
        pkgs.curl
        pkgs.iptables
        pkgs.coreutils
        pkgs.gnugrep
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        NetworkNamespacePath = "/run/netns/${cfg.vpn.namespace}";
        User = "root";
      };

      script = ''
        set -u

        GATEWAY="${cfg.vpn.portForwarding.gateway}"
        LEASE="${toString cfg.vpn.portForwarding.leaseDuration}"
        INTERVAL="${toString cfg.vpn.portForwarding.refreshInterval}"
        WEBUI_URL="http://192.168.15.1:${toString cfg.qbittorrent.webuiPort}"
        PASS_FILE="${config.sops.secrets.arr_qbittorrent_password.path}"

        echo "[protonvpn-port-forward] Starting port forwarding daemon..."
        echo "[protonvpn-port-forward] Waiting for qBittorrent WebUI at $WEBUI_URL..."
        until curl -s -I "$WEBUI_URL/" >/dev/null 2>&1; do
          sleep 1
        done
        echo "[protonvpn-port-forward] qBittorrent WebUI is ready."

        OLD_PORT=""
        COOKIE_FILE=$(mktemp)
        trap 'rm -f "$COOKIE_FILE"' EXIT

        login_qbittorrent() {
          if [ -f "$PASS_FILE" ]; then
            PASS=$(cat "$PASS_FILE")
            curl -s -c "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/auth/login" \
              --data-urlencode "username=admin" \
              --data-urlencode "password=$PASS" >/dev/null 2>&1
          fi
        }

        login_qbittorrent

        while true; do
          out=$(natpmpc -a 1 0 udp "$LEASE" -g "$GATEWAY" 2>&1) || true
          tcp_out=$(natpmpc -a 1 0 tcp "$LEASE" -g "$GATEWAY" 2>&1) || true
          out="$out"$'\n'"$tcp_out"

          PORT=$(echo "$out" | grep -oP 'Mapped public port \K[0-9]+' | head -n 1 || true)

          if [ -n "$PORT" ] && [ "$PORT" != "0" ]; then
            if [ "$PORT" != "$OLD_PORT" ]; then
              echo "[protonvpn-port-forward] Assigned public port: $PORT (was: ''${OLD_PORT:-none})"

              # Update namespace iptables
              if [ -n "$OLD_PORT" ]; then
                iptables -D INPUT -p tcp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p udp --dport "$OLD_PORT" -j ACCEPT 2>/dev/null || true
              fi
              iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
              iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT

              # Update qBittorrent listen_port, bind to wg0, and enforce safe connection/rate limits
              PAYLOAD="json={\"listen_port\": $PORT, \"upnp\": false, \"current_network_interface\": \"wg0\", \"max_connec\": ${toString cfg.qbittorrent.maxConnections}, \"max_connec_per_torrent\": ${toString cfg.qbittorrent.maxConnectionsPerTorrent}, \"max_active_downloads\": ${toString cfg.qbittorrent.maxActiveDownloads}, \"max_active_torrents\": ${toString cfg.qbittorrent.maxActiveTorrents}, \"dl_limit\": ${toString (cfg.qbittorrent.downloadRateLimitKiB * 1024)}, \"up_limit\": ${toString (cfg.qbittorrent.uploadRateLimitKiB * 1024)}}"
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$PAYLOAD")
              if [ "$STATUS" != "200" ]; then
                login_qbittorrent
                STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "$PAYLOAD")
              fi
              echo "[protonvpn-port-forward] Updated qBittorrent listen_port to $PORT (HTTP $STATUS)"
              OLD_PORT="$PORT"
            fi
          else
            echo "[protonvpn-port-forward] Warning: Failed to obtain port from NAT-PMP gateway $GATEWAY. Output:"
            echo "$out"
            sleep 10
            continue
          fi

          sleep "$INTERVAL"
        done
      '';
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
