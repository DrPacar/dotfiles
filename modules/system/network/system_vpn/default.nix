{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    concatMapStringsSep
    concatStringsSep
    optionalString
    filter
    ;
  cfg = config.networking.systemVPN;

  # ===========================================================================
  # Helper Utilities & Parameter Normalization
  # ===========================================================================

  # ===========================================================================
  # Central Firewall Marks & Identity Constants
  # ===========================================================================
  wgFwmark = "0xca6c";
  bypassFwmark = "0x5200";
  bypassGid = 5200;
  tailscaleFwmark = "0x80000/0xff0000";

  # Physical interface with safe fallback for string interpolation during evaluation
  physIface =
    if cfg.physicalInterface != null
    then cfg.physicalInterface
    else "UNSPECIFIED";

  # Format interface names for NetworkManager's unmanaged pattern list
  nmIface = iface: "interface-name:${builtins.replaceStrings ["+"] ["*"] iface}";

  # Tailscale and Split-DNS status flags and string representations
  tsActive = config.services.tailscale.enable or false;
  tsStr =
    if tsActive
    then "1"
    else "0";

  splitDnsActive = cfg.splitDns.enable && (config.services.resolved.enable or false);
  splitDnsStr =
    if splitDnsActive
    then "1"
    else "0";

  # Unified split-tunneling bypass active condition
  bypassActive = cfg.bypass.enable || cfg.bypass.services != [];

  # Partition LAN subnets into IPv4 and IPv6 sets for type-safe nftables matching
  ipv4LanSubnets = filter (s: !lib.hasInfix ":" s) cfg.lanSubnets;
  ipv6LanSubnets = filter (s: lib.hasInfix ":" s) cfg.lanSubnets;

  # Allowed outbound network interfaces for the nftables killswitch whitelist
  allowedInterfaces =
    ["lo" cfg.interfaceName]
    ++ lib.optional tsActive cfg.tailscaleInterface
    ++ (map (builtins.replaceStrings ["+"] ["*"]) cfg.extraTunnelInterfaces)
    ++ (map (builtins.replaceStrings ["+"] ["*"]) cfg.trustedInterfaces);

  # Formatted string for nftables interface sets: { "lo", "wg-system", ... }
  allowedIfacesNftStr = concatMapStringsSep ", " (iface: "\"${iface}\"") allowedInterfaces;

  # ---------------------------------------------------------------------------
  # Single Source of Truth: Common Environment for Scripts & Systemd
  # ---------------------------------------------------------------------------
  commonEnv = {
    IFACE = cfg.interfaceName;
    PHYS_IFACE = physIface;
    WG_FWMARK = wgFwmark;
    BYPASS_MARK = bypassFwmark;
    TAILSCALE_FWMARK = tailscaleFwmark;
    BYPASS_GROUP =
      if bypassActive
      then cfg.bypass.group
      else "";
    BYPASS_SERVICES = concatStringsSep " " cfg.bypass.services;
    SPLIT_DNS_ENABLED = splitDnsStr;
    SPLIT_DNS_DOMAINS = concatStringsSep " " cfg.splitDns.localDomains;
    TAILSCALE_ENABLED = tsStr;
    TAILSCALE_IFACE = cfg.tailscaleInterface;
  };

  # ---------------------------------------------------------------------------
  # Lifecycle & Administrative Tool Scripts
  # ---------------------------------------------------------------------------

  # postUp: Installs deterministic policy routing rules and configures Split-DNS
  postUpScript = pkgs.writeShellApplication {
    name = "system-vpn-post-up";
    runtimeInputs = with pkgs; [
      iproute2
      systemd
      wireguard-tools
      gawk
      coreutils
    ];
    runtimeEnv = commonEnv;
    text = builtins.readFile ./scripts/post-up.sh;
  };

  # postDown: Flushes policy routing rules, removes endpoint routes, and reverts Split-DNS
  postDownScript = pkgs.writeShellApplication {
    name = "system-vpn-post-down";
    runtimeInputs = with pkgs; [
      iproute2
      systemd
      coreutils
    ];
    runtimeEnv = commonEnv;
    text = builtins.readFile ./scripts/post-down.sh;
  };

  # watchdog: Automated connectivity probe and self-healing service restarter
  watchdogScript = pkgs.writeShellApplication {
    name = "system-vpn-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      wireguard-tools
      iputils
      gawk
      coreutils
    ];
    runtimeEnv = {
      IFACE = cfg.interfaceName;
      PING_TARGET = cfg.watchdog.pingTarget;
      MAX_AGE = toString cfg.watchdog.maxHandshakeAge;
    };
    text = builtins.readFile ./scripts/watchdog.sh;
  };

  # vpn-status: Formatted CLI telemetry dashboard showing tunnel health and drop statistics
  vpnStatusScript = pkgs.writeShellApplication {
    name = "vpn-status";
    runtimeInputs = with pkgs; [
      systemd
      wireguard-tools
      iproute2
      nftables
      curl
      gawk
      gnugrep
      gnused
      coreutils
    ];
    runtimeEnv = commonEnv;
    text = builtins.readFile ./scripts/vpn-status.sh;
  };

  # vpn-bypass: Process wrapper executing target commands under the bypass group GID
  vpnBypassScript = pkgs.writeShellApplication {
    name = "vpn-bypass";
    runtimeInputs = with pkgs; [
      glibc
      coreutils
      gnugrep
    ];
    runtimeEnv = {
      BYPASS_GROUP = cfg.bypass.group;
    };
    text = builtins.readFile ./scripts/vpn-bypass.sh;
  };

  # system-vpn: Unified top-level management CLI tool
  systemVpnCli = pkgs.writeShellApplication {
    name = "system-vpn";
    runtimeInputs = [
      vpnStatusScript
      vpnBypassScript
      pkgs.systemd
    ];
    text = ''
      case "''${1:-status}" in
        status)
          shift || true
          exec vpn-status "$@"
          ;;
        check|selftest)
          shift || true
          exec vpn-status check "$@"
          ;;
        start)
          echo "Starting WireGuard ${cfg.interfaceName}..."
          exec systemctl start "wg-quick-${cfg.interfaceName}.service"
          ;;
        stop)
          echo "Stopping WireGuard ${cfg.interfaceName}..."
          exec systemctl stop "wg-quick-${cfg.interfaceName}.service"
          ;;
        restart)
          echo "Restarting WireGuard ${cfg.interfaceName}..."
          exec systemctl restart "wg-quick-${cfg.interfaceName}.service"
          ;;
        logs)
          exec journalctl -u "wg-quick-${cfg.interfaceName}.service" -u "${cfg.interfaceName}-watchdog.service" -n 50 --no-pager
          ;;
        watchdog)
          echo "Triggering WireGuard ${cfg.interfaceName} watchdog check..."
          exec systemctl start "${cfg.interfaceName}-watchdog.service"
          ;;
        bypass)
          shift || true
          exec vpn-bypass "$@"
          ;;
        *)
          echo "Usage: system-vpn {status|check|start|stop|restart|logs|watchdog|bypass <command...>}"
          exit 1
          ;;
      esac
    '';
  };
in {
  # ===========================================================================
  # Module Options Definition
  # ===========================================================================
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
  };

  # ===========================================================================
  # System Configuration Implementation
  # ===========================================================================
  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Sanity checks
    # -------------------------------------------------------------------------
    assertions = [
      {
        assertion = cfg.physicalInterface != null && cfg.physicalInterface != "";
        message = "networking.systemVPN: 'networking.systemVPN.physicalInterface' must be explicitly specified (e.g. \"eth0\" or \"eno1\").";
      }
      {
        assertion = cfg.wgConfFile != null;
        message = "networking.systemVPN: 'networking.systemVPN.wgConfFile' must be specified (filesystem path to WireGuard configuration file).";
      }
      {
        assertion = cfg.wgConfFile == null || !(lib.hasPrefix builtins.storeDir cfg.wgConfFile);
        message = "networking.systemVPN: 'wgConfFile' must not point to a path in the Nix store (private keys would be world-readable). Please specify a filesystem path string (e.g. from sops-nix).";
      }
      {
        assertion = !cfg.splitDns.enable || (config.services.resolved.enable or false);
        message = "networking.systemVPN: 'splitDns.enable' requires 'services.resolved.enable = true' to prevent silent DNS leaks to the physical ISP router.";
      }
    ];

    # Loose reverse path filtering prevents dropping asymmetric response packets from bypass traffic
    networking.firewall.checkReversePath = "loose";

    # -------------------------------------------------------------------------
    # System Packages & CLI Tools
    # Expose only the unified 'system-vpn' management command to PATH.
    # Sub-tools (vpn-status, vpn-bypass) are encapsulated inside system-vpn.
    # -------------------------------------------------------------------------
    environment.systemPackages = [
      systemVpnCli
    ];

    # -------------------------------------------------------------------------
    # Split-Tunneling User & Group Management
    # -------------------------------------------------------------------------
    # Dedicated Linux group for split-tunneling bypass with static deterministic GID
    users.groups = mkIf bypassActive {
      ${cfg.bypass.group} = {
        gid = bypassGid;
      };
    };

    users.users = mkIf cfg.bypass.enable (
      lib.genAttrs cfg.bypass.users (_user: {
        extraGroups = [cfg.bypass.group];
      })
    );

    # -------------------------------------------------------------------------
    # NetworkManager Exclusions
    # Ensure NetworkManager leaves WireGuard, trusted bridges, and virtual interfaces strictly alone
    # -------------------------------------------------------------------------
    networking.networkmanager.unmanaged = map nmIface (
      [cfg.interfaceName]
      ++ lib.optional tsActive cfg.tailscaleInterface
      ++ cfg.extraTunnelInterfaces
      ++ cfg.trustedInterfaces
    );

    # Prevent NetworkManager from restoring DefaultRoute=yes on physical interface on DHCP renewal
    networking.networkmanager.dispatcherScripts = mkIf (config.networking.networkmanager.enable or false) [
      {
        source = pkgs.writeShellScript "system-vpn-nm-dns" ''
          IFACE="$1"
          ACTION="$2"
          if [ "$IFACE" = "${physIface}" ]; then
            case "$ACTION" in
              up|dhcp4-change|dhcp6-change)
                ${pkgs.systemd}/bin/resolvectl default-route "${physIface}" no 2>/dev/null || true
                ${optionalString (cfg.splitDns.enable && cfg.splitDns.localDomains != []) ''
            ${pkgs.systemd}/bin/resolvectl domain "${physIface}" ${concatStringsSep " " cfg.splitDns.localDomains} 2>/dev/null || true
          ''}
                ;;
            esac
          fi
        '';
        type = "basic";
      }
    ];

    # -------------------------------------------------------------------------
    # WireGuard Connection via wg-quick
    # -------------------------------------------------------------------------
    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      configFile = cfg.wgConfFile;
    };

    # Assign the bypass group as primary GID to designated bypass services
    systemd.services = lib.mkMerge [
      (lib.mkIf (cfg.bypass.services != []) (
        lib.genAttrs (map (s: lib.removeSuffix ".service" s) cfg.bypass.services) (_name: {
          serviceConfig.Group = lib.mkForce cfg.bypass.group;
        })
      ))
      {
        "wg-quick-${cfg.interfaceName}" = {
          requires = ["nftables.service"];
          wants =
            [
              "network-online.target"
            ]
            ++ lib.optional tsActive "tailscaled.service";
          after =
            [
              "network-online.target"
              "nftables.service"
            ]
            ++ lib.optional tsActive "tailscaled.service";

          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
            RestartSteps = 5;
            RestartMaxDelaySec = "1m";

            # Idempotent cleanup before start prevents unit deadlock if previous teardown was interrupted
            ExecStartPre = [
              "-${pkgs.iproute2}/bin/ip link del dev ${cfg.interfaceName}"
            ];

            # 1. Post-up: Install deterministic ip policy routing rules & Split-DNS
            ExecStartPost = [
              "+${postUpScript}/bin/system-vpn-post-up"
            ];

            # 2. Post-down: Clean up ip rules and Split-DNS on stop
            ExecStopPost = [
              "+${postDownScript}/bin/system-vpn-post-down"
            ];
          };
        };

        "${cfg.interfaceName}-watchdog" = mkIf cfg.watchdog.enable {
          description = "Health check and auto-recovery for WireGuard ${cfg.interfaceName}";
          serviceConfig = {
            Type = "oneshot";
            RuntimeDirectory = "system-vpn";
            RuntimeDirectoryPreserve = "yes";
            ExecStart = "${watchdogScript}/bin/system-vpn-watchdog";
          };
        };
      }
    ];

    systemd.timers."${cfg.interfaceName}-watchdog" = mkIf cfg.watchdog.enable {
      description = "Timer for WireGuard ${cfg.interfaceName} health check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.watchdog.interval;
        RandomizedDelaySec = "10s";
      };
    };

    # -------------------------------------------------------------------------
    # Modern nftables Killswitch & Split-Tunneling Table
    # Replaces legacy iptables/ip6tables with a single unified 'inet' table
    # -------------------------------------------------------------------------
    networking.nftables = {
      enable = true;

      tables."system-vpn" = {
        family = "inet";
        content = ''
          # -------------------------------------------------------------------
          # Named Counters for Deterministic Telemetry & Verification
          # -------------------------------------------------------------------
          counter killswitch_reject {}
          counter forward_killswitch_reject {}

          # -------------------------------------------------------------------
          # Chain: output_mangle
          # Route hook with priority mangle: Evaluates outgoing sockets.
          # When mark is set, Linux kernel reroutes packet via table main.
          # Clamps TCP MSS to prevent MTU black holes on WireGuard tunnels.
          # -------------------------------------------------------------------
          chain output_mangle {
            type route hook output priority mangle; policy accept;

            ${optionalString bypassActive ''
            # Mark traffic from processes running under the vpn-bypass GID (only if not already marked)
            meta skgid ${toString bypassGid} meta mark 0 meta mark set ${bypassFwmark};
          ''}

            # Clamp TCP MSS on the VPN tunnel interface (exclude bypassed traffic)
            oifname "${cfg.interfaceName}" meta mark != ${bypassFwmark} tcp flags syn / syn,rst tcp option maxseg size set rt mtu;
          };

          # -------------------------------------------------------------------
          # Chain: postrouting_nat
          # Source NAT (masquerade): Ensures bypassed traffic taking the physical
          # interface adopts the physical interface's LAN IP address.
          # -------------------------------------------------------------------
          chain postrouting_nat {
            type nat hook postrouting priority srcnat; policy accept;

            ${optionalString bypassActive ''
            # Masquerade bypassed traffic taking the physical interface
            oifname "${physIface}" meta mark ${bypassFwmark} masquerade;
          ''}
          };

          # -------------------------------------------------------------------
          # Chain: output_killswitch
          # Egress filter with priority filter - 5: Evaluates before standard nixos-fw.
          # Whitelists authorized interfaces, LAN subnets, WireGuard tunnel, and
          # bypassed traffic. Hard-rejects any other outbound traffic.
          # -------------------------------------------------------------------
          chain output_killswitch {
            type filter hook output priority filter - 5; policy accept;

            # 1. Allow all authorized virtual interfaces (loopback, VPN, Tailscale, extra tunnels, trusted bridges)
            oifname { ${allowedIfacesNftStr} } accept;

            # 2. Allow split-tunnel bypassed traffic (processes running with GID or marked)
            ${optionalString bypassActive ''
            oifname "${physIface}" meta mark ${bypassFwmark} accept;
          ''}

            # 3. Allow Tailscale control plane and peer traffic directly on physical interface
            ${optionalString tsActive ''
            oifname "${physIface}" meta mark & 0xff0000 == 0x80000 accept;
          ''}

            # 4. Allow local LAN subnets on physical interface (direct LAN communication, all protocols)
            ${optionalString (ipv4LanSubnets != []) ''
            oifname "${physIface}" ip daddr { ${concatStringsSep ", " ipv4LanSubnets} } accept;
          ''}
            ${optionalString (ipv6LanSubnets != []) ''
            oifname "${physIface}" ip6 daddr { ${concatStringsSep ", " ipv6LanSubnets} } accept;
          ''}

            # 5. Allow essential link-local, broadcast, multicast, and DHCP network primitives
            oifname "${physIface}" ip daddr { 224.0.0.0/4, 255.255.255.255 } accept;
            oifname "${physIface}" ip6 daddr { fe80::/10, ff00::/8 } accept;
            oifname "${physIface}" udp sport 67-68 udp dport 67-68 accept;

            # 6. Allow WireGuard encapsulated tunnel traffic (kernel fwmark) out physical NIC
            oifname "${physIface}" meta mark ${wgFwmark} accept;

            # 7. THE KILLSWITCH: Hard-reject any remaining outbound traffic that was not whitelisted above
            counter name "killswitch_reject" reject with icmpx type admin-prohibited;
          };

          # -------------------------------------------------------------------
          # Chain: forward_killswitch
          # Forward filter with priority filter - 5: Prevents traffic forwarded
          # from containers or VMs from leaking unencrypted via physical NIC.
          # -------------------------------------------------------------------
          chain forward_killswitch {
            type filter hook forward priority filter - 5; policy accept;

            # 1. Allow forwarded traffic routed through authorized interfaces
            oifname { ${allowedIfacesNftStr} } accept;

            # 2. Allow forwarded traffic directed to local LAN subnets on physical NIC
            ${optionalString (ipv4LanSubnets != []) ''
            oifname "${physIface}" ip daddr { ${concatStringsSep ", " ipv4LanSubnets} } accept;
          ''}
            ${optionalString (ipv6LanSubnets != []) ''
            oifname "${physIface}" ip6 daddr { ${concatStringsSep ", " ipv6LanSubnets} } accept;
          ''}

            # 3. THE FORWARD KILLSWITCH: Hard-reject any forwarded traffic exiting via physical NIC
            oifname "${physIface}" counter name "forward_killswitch_reject" reject with icmpx type admin-prohibited;
          };
        '';
      };
    };
  };
}
