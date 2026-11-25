{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.networking.systemVPN = {
    enable = mkEnableOption "system-wide WireGuard VPN with strict nftables killswitch";

    interfaceName = mkOption {
      type = types.str;
      default = "wg-system";
      description = "Interface name for the host system WireGuard VPN.";
    };

    extraTunnelInterfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Additional WireGuard or virtual tunnel interface names permitted through the
        killswitch and kept unmanaged by NetworkManager. Supports wildcards like 'veth-*'.
      '';
    };

    trustedInterfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["docker0" "podman0" "br-*" "virbr0"];
      description = ''
        Local virtual network interfaces (bridges, container networks) allowed for direct
        local host communication through the killswitch and excluded from NetworkManager management.
      '';
    };

    tailscaleInterface = mkOption {
      type = types.str;
      default = config.services.tailscale.interfaceName or "tailscale0";
      description = "Interface name used by Tailscale.";
    };

    physicalInterface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Physical network interface connecting to local LAN / gateway (e.g. \"eth0\" or \"eno1\").";
    };

    wgConfFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Filesystem path to the primary WireGuard configuration file (as a string).
        Must be a path string (e.g. from sops-nix, agenix, or /run/secrets/...) rather
        than a Nix path literal, to prevent copying private keys into the world-readable
        /nix/store.

        Configuration file prerequisites for systemVPN:
        1. 'Endpoint': Must specify a direct numeric IP address (IPv4 or IPv6), not a domain name,
           because fail-closed Split-DNS prevents resolving public hostnames before the tunnel is UP.
        2. 'AllowedIPs': Must specify '0.0.0.0/0, ::/0' to route all traffic into the VPN. If '::/0'
           is omitted on an IPv6-capable system, outbound IPv6 will fail-closed (blocked by killswitch).
        3. 'DNS': Must specify VPN DNS nameservers so systemd-resolved assigns resolvers to global scope (~.).
        4. 'Table': Do NOT set 'Table = off' (wg-quick must populate its isolated table 51820).
        5. 'FwMark': Setting 'FwMark = 0xca6c' is recommended to explicitly match the killswitch fwmark.
      '';
    };

    lanSubnets = mkOption {
      type = types.listOf types.str;
      default = [
        "192.168.0.0/16"
        "172.16.0.0/12"
      ];
      description = "Local subnets permitted for direct communication without VPN.";
    };

    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated connectivity watchdog that restarts the VPN if ping fails and handshakes stall.";
      };

      interval = mkOption {
        type = types.str;
        default = "2m";
        description = "Interval between watchdog checks (systemd timer syntax).";
      };

      pingTarget = mkOption {
        type = types.str;
        default = "1.1.1.1";
        description = "Target IP to ping through the WireGuard interface to verify connectivity.";
      };

      maxHandshakeAge = mkOption {
        type = types.ints.positive;
        default = 180;
        description = "Maximum allowed age in seconds since last handshake before triggering restart.";
      };
    };

    bypass = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable selective split-tunneling bypass via Linux group.";
      };

      group = mkOption {
        type = types.str;
        default = "vpn-bypass";
        description = "Name of the Linux group whose processes bypass the VPN and route directly via physical gateway.";
      };

      users = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of system usernames to add to the split-tunnel bypass group.";
      };

      services = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of systemd service names (with or without .service suffix) that bypass the WireGuard
          VPN and route directly through the physical ISP gateway. Services configured here are assigned
          the bypass group as their primary GID, ensuring their sockets are marked and routed directly.
        '';
      };
    };

    splitDns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to configure per-interface Split-DNS routing via systemd-resolved.
          Directs internal domain scopes (~local, ~home.arpa, ~lan) to the physical LAN
          interface while pinning the WireGuard tunnel as the exclusive global default
          DNS route (~.) with DefaultRoute=yes. Enforces fail-closed DNS so queries never
          leak to the ISP/router when the VPN tunnel is stopped.
        '';
      };

      localDomains = mkOption {
        type = types.listOf types.str;
        default = [
          "~local"
          "~home.arpa"
          "~lan"
        ];
        description = "Domain scopes routed to the physical network interface.";
      };
    };

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = config.server.notify.enable or false;
        description = "Enable alerts when the system WireGuard VPN fails, recovers, or restarts.";
      };

      handler = mkOption {
        type = types.nullOr (types.either types.str types.package);
        default = null;
        example = lib.literalExpression ''
          '''
            # $1 contains the alert message string, $2 an optional tag
            ntfy-send media "$1" "System VPN Alert" "$2"
          '''
        '';
        description = ''
          Custom notification handler invoked on system VPN watchdog alerts and recoveries.
          Receives the formatted message string as $1 and an optional severity/ntfy tag as $2.
          Accepts either a shell snippet string or an executable package/derivation.
          When null and server.notify.enable is true, defaults to sending alerts via server.notify.
        '';
      };
    };
  };
}
