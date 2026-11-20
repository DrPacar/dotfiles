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
    optionalString
    ;
  cfg = config.networking.systemVPN;

  # Convert '+' to '*' for NetworkManager unmanaged interface patterns
  nmIface = iface: "interface-name:${builtins.replaceStrings ["+"] ["*"] iface}";
  # Convert '*' to '+' for iptables interface patterns
  iptablesIface = iface: builtins.replaceStrings ["*"] ["+"] iface;

  allWgConfigs = (lib.optional (cfg.wgConfFile != null) cfg.wgConfFile) ++ cfg.extraWgConfigFiles;
  wgConfigListStr = concatMapStringsSep " " (f: "\"${toString f}\"") allWgConfigs;

  allowedInterfaces =
    ["lo" cfg.interfaceName]
    ++ lib.optional (config.services.tailscale.enable or false) cfg.tailscaleInterface
    ++ (map iptablesIface cfg.extraTunnelInterfaces);

  # Helper and lifecycle scripts
  preUpScript = pkgs.writeShellApplication {
    name = "system-vpn-pre-up";
    runtimeInputs = with pkgs; [
      iproute2
      gawk
      gnugrep
      gnused
      coreutils
      glibc
    ];
    text = builtins.readFile ./scripts/pre-up.sh;
  };

  postUpScript = pkgs.writeShellApplication {
    name = "system-vpn-post-up";
    runtimeInputs = with pkgs; [
      iproute2
    ];
    text = builtins.readFile ./scripts/post-up.sh;
  };

  postDownScript = pkgs.writeShellApplication {
    name = "system-vpn-post-down";
    runtimeInputs = with pkgs; [
      iproute2
      coreutils
    ];
    text = builtins.readFile ./scripts/post-down.sh;
  };

  watchdogScript = pkgs.writeShellApplication {
    name = "system-vpn-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      wireguard-tools
      iputils
      gawk
      coreutils
    ];
    text = ''
      IFACE="${cfg.interfaceName}"
      PING_TARGET="${cfg.watchdog.pingTarget}"
      MAX_AGE="${toString cfg.watchdog.maxHandshakeAge}"
      ${builtins.readFile ./scripts/watchdog.sh}
    '';
  };

  vpnStatusScript = pkgs.writeShellApplication {
    name = "vpn-status";
    runtimeInputs = with pkgs; [
      systemd
      wireguard-tools
      iproute2
      iptables
      curl
      gawk
      gnugrep
      gnused
      coreutils
    ];
    text = ''
      IFACE="${cfg.interfaceName}"
      PHYS_IFACE="${cfg.physicalInterface}"
      BYPASS_GROUP="${
        if cfg.bypass.enable
        then cfg.bypass.group
        else ""
      }"
      ${builtins.readFile ./scripts/vpn-status.sh}
    '';
  };

  vpnBypassScript = pkgs.writeShellApplication {
    name = "vpn-bypass";
    runtimeInputs = with pkgs; [
      shadow
      glibc
      coreutils
    ];
    text = ''
      BYPASS_GROUP="${cfg.bypass.group}"
      ${builtins.readFile ./scripts/vpn-bypass.sh}
    '';
  };

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
        restart)
          echo "Restarting WireGuard ${cfg.interfaceName}..."
          exec systemctl restart "wg-quick-${cfg.interfaceName}.service"
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
          echo "Usage: system-vpn {status|restart|watchdog|bypass <command...>}"
          exit 1
          ;;
      esac
    '';
  };
in {
  options.networking.systemVPN = {
    enable = mkEnableOption "system-wide WireGuard VPN with strict killswitch";

    interfaceName = mkOption {
      type = types.str;
      default = "wg-system";
      description = "Interface name for the host system WireGuard VPN.";
    };

    extraTunnelInterfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["wg-br" "veth-+" "wg0"];
      description = "Additional WireGuard or virtual tunnel interface names permitted through the killswitch and kept unmanaged by NetworkManager.";
    };

    tailscaleInterface = mkOption {
      type = types.str;
      default = config.services.tailscale.interfaceName or "tailscale0";
      description = "Interface name used by Tailscale.";
    };

    physicalInterface = mkOption {
      type = types.str;
      default = "eno1";
      description = "Physical network interface connecting to local LAN / gateway.";
    };

    wgConfFile = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = config.sops.secrets.system_wireguard_conf.path or null;
      description = "Path to WireGuard configuration file (managed via sops-nix).";
    };

    extraWgConfigFiles = mkOption {
      type = types.listOf (types.either types.path types.str);
      default = [];
      example = lib.literalExpression "[ config.sops.secrets.arr_wireguard_conf.path ]";
      description = "Additional WireGuard configuration files whose server endpoints should be directly routed through the physical gateway to prevent VPN-in-VPN loops.";
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
        type = types.int;
        default = 180;
        description = "Maximum allowed age in seconds since last handshake before triggering restart.";
      };
    };

    bypass = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable selective split-tunneling bypass via dedicated Linux group (vpn-bypass).";
      };

      group = mkOption {
        type = types.str;
        default = "vpn-bypass";
        description = "Name of the Linux group whose processes bypass the VPN and route directly via physical gateway.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.wgConfFile != null;
        message = "networking.systemVPN: networking.systemVPN.wgConfFile must be set (or config.sops.secrets.system_wireguard_conf must exist).";
      }
    ];

    environment.systemPackages = [
      pkgs.wireguard-tools
      systemVpnCli
      vpnStatusScript
      vpnBypassScript
    ];

    # Split-tunneling bypass group & automatic user membership
    users.groups = mkIf cfg.bypass.enable {
      ${cfg.bypass.group} = {};
    };

    users.users = mkIf (cfg.bypass.enable && config.user ? primary && config.user.primary != null) {
      ${config.user.primary}.extraGroups = [cfg.bypass.group];
    };

    # Tell NetworkManager to leave WireGuard and virtual interfaces unmanaged
    networking.networkmanager.unmanaged = map nmIface (
      [cfg.interfaceName]
      ++ lib.optional (config.services.tailscale.enable or false) cfg.tailscaleInterface
      ++ cfg.extraTunnelInterfaces
    );

    # System-wide WireGuard connection via wg-quick
    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      configFile = cfg.wgConfFile;
      autostart = true;
    };

    # Ensure systemd service handles pre/post routing cleanly
    systemd.services."wg-quick-${cfg.interfaceName}" = {
      wants =
        [
          "network-online.target"
        ]
        ++ lib.optional config.services.tailscale.enable "tailscaled.service";
      after =
        [
          "network-online.target"
        ]
        ++ lib.optional config.services.tailscale.enable "tailscaled.service";

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;

        ExecStartPre = [
          "+${preUpScript}/bin/system-vpn-pre-up \"${cfg.physicalInterface}\" ${wgConfigListStr}"
        ];

        ExecStartPost = [
          "+${postUpScript}/bin/system-vpn-post-up \"${
            if config.services.tailscale.enable or false
            then "1"
            else "0"
          }\" \"${cfg.tailscaleInterface}\""
        ];

        ExecStopPost = [
          "+${postDownScript}/bin/system-vpn-post-down \"${cfg.physicalInterface}\" \"${
            if config.services.tailscale.enable or false
            then "1"
            else "0"
          }\" \"${cfg.tailscaleInterface}\""
        ];
      };
    };

    # -------------------------------------------------------------------------
    # Auto-healing Watchdog service & timer
    # -------------------------------------------------------------------------
    systemd.services."${cfg.interfaceName}-watchdog" = mkIf cfg.watchdog.enable {
      description = "Health check and auto-recovery for WireGuard ${cfg.interfaceName}";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdogScript}/bin/system-vpn-watchdog";
      };
    };

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
    # Watertight Killswitch: Egress firewall rules
    # -------------------------------------------------------------------------
    networking.firewall.extraCommands = ''
      # -------------------------------------------------------------------------
      # System VPN Killswitch (IPv4)
      # -------------------------------------------------------------------------
      ${optionalString cfg.bypass.enable ''
        # Mark packets from processes in the bypass group
        iptables -t mangle -C OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200 2>/dev/null || \
        iptables -t mangle -A OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200
      ''}

      iptables -F vpn-killswitch 2>/dev/null || iptables -N vpn-killswitch
      iptables -C OUTPUT -j vpn-killswitch 2>/dev/null || iptables -A OUTPUT -j vpn-killswitch

      # Allow loopback, VPN tunnel, Tailscale, and extra tunnel interfaces
      ${concatMapStringsSep "\n" (iface: ''
          iptables -A vpn-killswitch -o ${iface} -j ACCEPT
        '')
        allowedInterfaces}

      # Allow established / related connections
      iptables -A vpn-killswitch -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

      # Allow split-tunnel bypass group directly on physical interface
      ${optionalString cfg.bypass.enable ''
        iptables -A vpn-killswitch -m owner --gid-owner ${cfg.bypass.group} -o ${cfg.physicalInterface} -j ACCEPT
      ''}

      # Allow local LAN & local multicast/broadcast on physical interface
      ${concatMapStringsSep "\n" (subnet: ''
          iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d ${subnet} -j ACCEPT
        '')
        cfg.lanSubnets}
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d 224.0.0.0/4 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -d 255.255.255.255/32 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --dport 67:68 --sport 67:68 -j ACCEPT
      iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p icmp -j ACCEPT

      # Allow Tailscale daemon egress directly on physical interface
      ${optionalString (config.services.tailscale.enable or false) ''
        iptables -A vpn-killswitch -m cgroup --path system.slice/tailscaled.service -j ACCEPT
        iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --sport 41641 -j ACCEPT
        iptables -A vpn-killswitch -o ${cfg.physicalInterface} -p udp --dport 41641 -j ACCEPT
      ''}

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
      ${optionalString cfg.bypass.enable ''
        ip6tables -t mangle -C OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200 2>/dev/null || \
        ip6tables -t mangle -A OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200
      ''}

      ip6tables -F vpn-killswitch 2>/dev/null || ip6tables -N vpn-killswitch
      ip6tables -C OUTPUT -j vpn-killswitch 2>/dev/null || ip6tables -A OUTPUT -j vpn-killswitch

      ${concatMapStringsSep "\n" (iface: ''
          ip6tables -A vpn-killswitch -o ${iface} -j ACCEPT
        '')
        allowedInterfaces}
      ip6tables -A vpn-killswitch -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ${optionalString cfg.bypass.enable ''
        ip6tables -A vpn-killswitch -m owner --gid-owner ${cfg.bypass.group} -o ${cfg.physicalInterface} -j ACCEPT
      ''}
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -d fe80::/10 -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -d ff00::/8 -j ACCEPT
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -p ipv6-icmp -j ACCEPT
      ${optionalString (config.services.tailscale.enable or false) ''
        ip6tables -A vpn-killswitch -m cgroup --path system.slice/tailscaled.service -j ACCEPT
      ''}
      ip6tables -A vpn-killswitch -o ${cfg.physicalInterface} -j REJECT --reject-with icmp6-adm-prohibited
    '';

    networking.firewall.extraStopCommands = ''
      ${optionalString cfg.bypass.enable ''
        iptables -t mangle -D OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200 2>/dev/null || true
        ip6tables -t mangle -D OUTPUT -m owner --gid-owner ${cfg.bypass.group} -j MARK --set-mark 0x5200 2>/dev/null || true
      ''}

      iptables -D OUTPUT -j vpn-killswitch 2>/dev/null || true
      iptables -F vpn-killswitch 2>/dev/null || true
      iptables -X vpn-killswitch 2>/dev/null || true

      ip6tables -D OUTPUT -j vpn-killswitch 2>/dev/null || true
      ip6tables -F vpn-killswitch 2>/dev/null || true
      ip6tables -X vpn-killswitch 2>/dev/null || true
    '';
  };
}
