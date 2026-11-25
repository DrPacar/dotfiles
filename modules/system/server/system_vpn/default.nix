{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) elem genAttrs hasPrefix mkDefault mkForce mkIf mkMerge mkOptionDefault optional removeSuffix toList;
  cfg = config.networking.systemVPN;
  vpn = import ./_lib.nix {inherit config lib;};
  inherit (import ../_lib.nix) mkNotifyBin;

  nmIface = iface: "interface-name:${vpn.normalizeIface iface}";

  # ---------------------------------------------------------------------------
  # Lifecycle & Dispatcher Scripts
  # ---------------------------------------------------------------------------
  postUpScript = pkgs.writeShellApplication {
    name = "system-vpn-post-up";
    runtimeInputs = with pkgs; [
      iproute2
      systemd
      wireguard-tools
      gawk
      coreutils
    ];
    runtimeEnv = vpn.commonEnv;
    text = builtins.readFile ./scripts/post-up.sh;
  };

  postDownScript = pkgs.writeShellApplication {
    name = "system-vpn-post-down";
    runtimeInputs = with pkgs; [
      iproute2
      systemd
      coreutils
    ];
    runtimeEnv = vpn.commonEnv;
    text = builtins.readFile ./scripts/post-down.sh;
  };

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (cfg.notifications) enable handler;
    name = "system-vpn-notify";
    title = "System VPN (${cfg.interfaceName})";
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
    runtimeEnv = {
      IFACE = cfg.interfaceName;
      PING_TARGET = cfg.watchdog.pingTarget;
      MAX_AGE = toString cfg.watchdog.maxHandshakeAge;
      NOTIFY_BIN = notifyBin;
    };
    text = builtins.readFile ./scripts/watchdog.sh;
  };

  nmDispatcherScript = pkgs.writeShellApplication {
    name = "system-vpn-nm-dns";
    runtimeInputs = [pkgs.systemd];
    runtimeEnv = {
      inherit (vpn.commonEnv) PHYS_IFACE SPLIT_DNS_ENABLED SPLIT_DNS_DOMAINS;
    };
    text = builtins.readFile ./scripts/nm-dispatcher.sh;
  };
in {
  # Automatically isolate Split-DNS on the matching systemd-networkd physical interface
  # so hosts only need plain DHCP without duplicating UseDNS/DNSDefaultRoute/Domains.
  options.systemd.network.networks = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (netArgs: let
        matchedNames = toList (netArgs.config.matchConfig.Name or []);
        isPhysIface = cfg.physicalInterface != null && elem cfg.physicalInterface matchedNames;
      in {
        config = mkIf (cfg.enable && cfg.splitDns.enable && isPhysIface) {
          networkConfig = {
            DNSDefaultRoute = mkDefault false;
            Domains = cfg.splitDns.localDomains;
          };
          dhcpV4Config.UseDNS = mkDefault false;
          dhcpV6Config.UseDNS = mkDefault false;
        };
      })
    );
  };

  config = mkIf cfg.enable {
    services.resolved.enable = mkIf cfg.splitDns.enable (mkDefault true);
    networking.nameservers = mkIf cfg.splitDns.enable (mkOptionDefault ["1.1.1.1" "1.0.0.1"]);
    # -------------------------------------------------------------------------
    # Configuration Sanity Assertions
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
        assertion = cfg.wgConfFile == null || !(hasPrefix builtins.storeDir cfg.wgConfFile);
        message = "networking.systemVPN: 'wgConfFile' must not point to a path in the Nix store (private keys would be world-readable). Please specify a filesystem path string (e.g. from sops-nix).";
      }
      {
        assertion = !cfg.splitDns.enable || (config.services.resolved.enable or false);
        message = "networking.systemVPN: 'splitDns.enable' requires 'services.resolved.enable = true' to prevent silent DNS leaks to the physical ISP router.";
      }
    ];

    # -------------------------------------------------------------------------
    # Split-Tunneling User & Group Management
    # -------------------------------------------------------------------------
    users.groups = mkIf vpn.bypassActive {
      ${cfg.bypass.group} = {
        gid = vpn.bypassGid;
      };
    };

    users.users = mkIf (cfg.bypass.enable && cfg.bypass.users != []) (
      genAttrs cfg.bypass.users (_user: {
        extraGroups = [cfg.bypass.group];
      })
    );

    # -------------------------------------------------------------------------
    # NetworkManager Integration
    # -------------------------------------------------------------------------
    networking.networkmanager.unmanaged = map nmIface (
      [cfg.interfaceName]
      ++ optional vpn.tsActive cfg.tailscaleInterface
      ++ cfg.extraTunnelInterfaces
      ++ cfg.trustedInterfaces
    );

    # Prevent NetworkManager from restoring DefaultRoute=yes on physical NIC on DHCP renewal
    networking.networkmanager.dispatcherScripts = mkIf (config.networking.networkmanager.enable or false) [
      {
        source = "${nmDispatcherScript}/bin/system-vpn-nm-dns";
        type = "basic";
      }
    ];

    # -------------------------------------------------------------------------
    # WireGuard Service, Lifecycle Hooks & Health Watchdog
    # -------------------------------------------------------------------------
    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      configFile = cfg.wgConfFile;
    };

    systemd.services = mkMerge [
      (mkIf (cfg.bypass.services != []) (
        genAttrs (map (s: removeSuffix ".service" s) cfg.bypass.services) (_name: {
          serviceConfig.Group = mkForce cfg.bypass.group;
        })
      ))
      {
        "wg-quick-${cfg.interfaceName}" = {
          requires = ["nftables.service"];
          wants = ["network-online.target"] ++ optional vpn.tsActive "tailscaled.service";
          after = ["network-online.target" "nftables.service"] ++ optional vpn.tsActive "tailscaled.service";

          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
            RestartSteps = 5;
            RestartMaxDelaySec = "1m";

            # Idempotent cleanup before start prevents deadlock if previous teardown was interrupted
            ExecStartPre = [
              "-${pkgs.iproute2}/bin/ip link del dev ${cfg.interfaceName}"
            ];

            ExecStartPost = [
              "+${postUpScript}/bin/system-vpn-post-up"
            ];

            ExecStopPost = [
              "+${postDownScript}/bin/system-vpn-post-down"
            ];
          };

          unitConfig = {
            StartLimitIntervalSec = mkForce 0;
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
  };
}
