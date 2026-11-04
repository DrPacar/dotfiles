{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types concatMapStringsSep optionalString;
  cfg = config.networking.systemVPN;
in {
  options.networking.systemVPN = {
    enable = mkEnableOption "system-wide WireGuard VPN with strict killswitch";

    interfaceName = mkOption {
      type = types.str;
      default = "wg-system";
      description = "Interface name for the host system WireGuard VPN.";
    };

    physicalInterface = mkOption {
      type = types.str;
      default = "eno1";
      description = "Physical network interface connecting to local LAN / gateway.";
    };

    wgConfFile = mkOption {
      type = types.path;
      default = config.sops.secrets.system_wireguard_conf.path;
      description = "Path to WireGuard configuration file (managed via sops-nix).";
    };

    lanSubnets = mkOption {
      type = types.listOf types.str;
      default = [
        "192.168.0.0/16"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "100.64.0.0/10" # Tailscale CGNAT
      ];
      description = "Local subnets permitted for direct communication without VPN.";
    };

    vpnPorts = mkOption {
      type = types.listOf types.int;
      default = [51820];
      description = "UDP ports used by WireGuard VPN servers (e.g. ProtonVPN).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.sops.secrets ? system_wireguard_conf;
        message = "networking.systemVPN: config.sops.secrets.system_wireguard_conf must be defined in your secrets file.";
      }
    ];

    environment.systemPackages = [pkgs.wireguard-tools];

    # Tell NetworkManager to leave WireGuard and virtual interfaces unmanaged
    networking.networkmanager.unmanaged = [
      "interface-name:${cfg.interfaceName}"
      "interface-name:wg0"
      "interface-name:wg-br"
      "interface-name:veth-*"
    ];

    # System-wide WireGuard connection via wg-quick
    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      configFile = cfg.wgConfFile;
      autostart = true;
    };

    # Ensure systemd service handles pre/post routing cleanly
    systemd.services."wg-quick-${cfg.interfaceName}" = {
      wants = ["network-online.target"] ++ lib.optional config.services.tailscale.enable "tailscaled.service";
      after = ["network-online.target"] ++ lib.optional config.services.tailscale.enable "tailscaled.service";

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;

        # Ensure direct routing for VPN endpoints so neither VPN nests inside the other
        ExecStartPre = [
          "+${pkgs.writeShellScript "system-vpn-pre-up" ''
            set -euo pipefail
            GW=$(${pkgs.iproute2}/bin/ip route show default dev ${cfg.physicalInterface} 2>/dev/null | ${pkgs.gawk}/bin/awk '/via/ {print $3}' | head -n 1 || true)
            if [ -n "$GW" ]; then
              # Route VPN server endpoints directly through physical gateway so WireGuard handshakes never loop or nest
              for conf in "${cfg.wgConfFile}" "${config.sops.secrets.arr_wireguard_conf.path or ""}"; do
                if [ -f "$conf" ]; then
                  EP=$(${pkgs.gnugrep}/bin/grep -iE "^[[:space:]]*Endpoint" "$conf" | head -n 1 | ${pkgs.gnused}/bin/sed -E 's/.*=[[:space:]]*\[?([^]:[:space:]]+).*/\1/' || true)
                  if [ -n "$EP" ]; then
                    ${pkgs.iproute2}/bin/ip route add "$EP/32" via "$GW" dev "${cfg.physicalInterface}" 2>/dev/null || true
                  fi
                fi
              done
            fi
          ''}"
        ];

        # Inform tailscale of network interface changes upon startup and prioritize Tailscale routing
        ExecStartPost = [
          "+${pkgs.writeShellScript "system-vpn-post-up" ''
            # Prioritize Tailscale overlay routing (100.64.0.0/10) before WireGuard default routing table 51820
            ${pkgs.iproute2}/bin/ip rule add to 100.64.0.0/10 lookup 52 priority 5200 2>/dev/null || true
            ${pkgs.iproute2}/bin/ip route add 100.64.0.0/10 dev tailscale0 2>/dev/null || true
            ${optionalString config.services.tailscale.enable "${pkgs.systemd}/bin/systemctl try-restart tailscaled.service 2>/dev/null || true"}
          ''}"
        ];

        ExecStopPost = [
          "+${pkgs.writeShellScript "system-vpn-post-down" ''
            ${pkgs.iproute2}/bin/ip rule del to 100.64.0.0/10 lookup 52 priority 5200 2>/dev/null || true
            ${pkgs.iproute2}/bin/ip route del 100.64.0.0/10 dev tailscale0 2>/dev/null || true
            for conf in "${cfg.wgConfFile}" "${config.sops.secrets.arr_wireguard_conf.path or ""}"; do
              if [ -f "$conf" ]; then
                EP=$(${pkgs.gnugrep}/bin/grep -iE "^[[:space:]]*Endpoint" "$conf" | head -n 1 | ${pkgs.gnused}/bin/sed -E 's/.*=[[:space:]]*\[?([^]:[:space:]]+).*/\1/' || true)
                if [ -n "$EP" ]; then
                  ${pkgs.iproute2}/bin/ip route del "$EP/32" 2>/dev/null || true
                fi
              fi
            done
          ''}"
        ];
      };
    };

    # -------------------------------------------------------------------------
    # Watertight Killswitch: Egress firewall rules
    # -------------------------------------------------------------------------
    networking.firewall.extraCommands = ''
      # -------------------------------------------------------------------------
      # System VPN Killswitch (IPv4)
      # -------------------------------------------------------------------------
      iptables -F vpn-killswitch 2>/dev/null || iptables -N vpn-killswitch
      iptables -C OUTPUT -j vpn-killswitch 2>/dev/null || iptables -A OUTPUT -j vpn-killswitch

      # Allow loopback, VPN tunnel, Tailscale, and Netns bridge
      iptables -A vpn-killswitch -o lo -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.interfaceName} -j ACCEPT
      iptables -A vpn-killswitch -o tailscale0 -j ACCEPT
      iptables -A vpn-killswitch -o wg-br -j ACCEPT
      iptables -A vpn-killswitch -o veth-+ -j ACCEPT

      # Allow established / related connections
      iptables -A vpn-killswitch -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

      # Allow local LAN & local multicast/broadcast on physical interface
      ${concatMapStringsSep "\n" (subnet: ''
          iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d ${subnet} -j ACCEPT
        '')
        cfg.lanSubnets}
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d 224.0.0.0/4 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d 255.255.255.255/32 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --dport 67:68 --sport 67:68 -j ACCEPT

      # Allow Tailscale daemon egress directly on physical interface
      iptables -A vpn-killswitch -m cgroup --path system.slice/tailscaled.service -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --sport 41641 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --dport 41641 -j ACCEPT

      # Allow WireGuard VPN Handshakes on physical interface (both System VPN and Arr VPN)
      ${concatMapStringsSep "\n" (port: ''
          iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --dport ${toString port} -j ACCEPT
        '')
        cfg.vpnPorts}

      # Block / Reject any other outbound internet traffic on physical interface
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -j REJECT --reject-with icmp-admin-prohibited

      # -------------------------------------------------------------------------
      # System VPN Killswitch (IPv6)
      # -------------------------------------------------------------------------
      ip6tables -F vpn-killswitch 2>/dev/null || ip6tables -N vpn-killswitch
      ip6tables -C OUTPUT -j vpn-killswitch 2>/dev/null || ip6tables -A OUTPUT -j vpn-killswitch

      ip6tables -A vpn-killswitch -o lo -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.interfaceName} -j ACCEPT
      ip6tables -A vpn-killswitch -o tailscale0 -j ACCEPT
      ip6tables -A vpn-killswitch -o wg-br -j ACCEPT
      ip6tables -A vpn-killswitch -o veth-+ -j ACCEPT
      ip6tables -A vpn-killswitch -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -d fe80::/10 -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -d ff00::/8 -j ACCEPT
      ip6tables -A vpn-killswitch -m cgroup --path system.slice/tailscaled.service -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -j REJECT --reject-with icmp6-adm-prohibited
    '';

    networking.firewall.extraStopCommands = ''
      iptables -D OUTPUT -j vpn-killswitch 2>/dev/null || true
      iptables -F vpn-killswitch 2>/dev/null || true
      iptables -X vpn-killswitch 2>/dev/null || true

      ip6tables -D OUTPUT -j vpn-killswitch 2>/dev/null || true
      ip6tables -F vpn-killswitch 2>/dev/null || true
      ip6tables -X vpn-killswitch 2>/dev/null || true
    '';
  };
}
