{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.vpn = {
    enable = mkOption {
      type = types.bool;
      default = true;
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
}
