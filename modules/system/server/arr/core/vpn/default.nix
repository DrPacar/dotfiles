{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) any filter mkIf optional;
  cfg = config.server.arr;
  vpn = import ./_lib.nix {inherit config lib;};
  inherit (import ../../_lib.nix) mkNotifyBin;

  # ---------------------------------------------------------------------------
  # Lifecycle & Watchdog Scripts
  # ---------------------------------------------------------------------------
  waitForRouteScript = pkgs.writeShellApplication {
    name = "arr-vpn-wait-route";
    runtimeInputs = with pkgs; [
      iproute2
      gnugrep
      coreutils
    ];
    text = builtins.readFile ./scripts/wait-for-default-route.sh;
  };

  postUpScript = pkgs.writeShellApplication {
    name = "arr-vpn-post-up";
    runtimeInputs = with pkgs; [
      iproute2
      iptables
      wireguard-tools
      gnugrep
      coreutils
    ];
    runtimeEnv = vpn.commonEnv;
    text = builtins.readFile ./scripts/post-up.sh;
  };

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (cfg.vpn.notifications) enable handler;
    name = "arr-vpn-notify";
    title = "Arr VPN (${vpn.ns})";
  };

  watchdogScript = pkgs.writeShellApplication {
    name = "arr-vpn-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      iproute2
      wireguard-tools
      iputils
      gawk
      coreutils
    ];
    runtimeEnv = {
      NAMESPACE = vpn.ns;
      WG_IFACE = vpn.iface;
      PING_TARGET = cfg.vpn.watchdog.pingTarget;
      MAX_AGE = toString cfg.vpn.watchdog.maxHandshakeAge;
      PORT_FORWARDING_ENABLED = vpn.commonEnv.PORT_FORWARDING_ENABLED;
      PORT_STATE_FILE = vpn.commonEnv.PORT_STATE_FILE;
      NATPMP_FAIL_FILE = vpn.commonEnv.NATPMP_FAIL_FILE;
      NATPMP_FAIL_THRESHOLD = toString cfg.vpn.watchdog.natpmpFailureThreshold;
      NATPMP_RESTART_COOLDOWN = toString cfg.vpn.watchdog.natpmpRestartCooldown;
      NOTIFY_BIN = notifyBin;
    };
    text = builtins.readFile ./scripts/watchdog.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.vpn.enable) {
    # -------------------------------------------------------------------------
    # Configuration Sanity Warnings & Assertions
    # -------------------------------------------------------------------------
    warnings =
      optional (cfg.vpn.openVPNPorts == [] && !cfg.vpn.portForwarding.enable)
      "arr.vpn: arr.vpn.openVPNPorts is empty and arr.vpn.portForwarding is disabled. qBittorrent can download via outgoing connections, but cannot receive incoming peer connections without port forwarding."
      ++ optional (cfg.vpn.directPhysicalEgress && vpn.systemVpnEnabled && !vpn.systemVpnBypassActive)
      "arr.vpn: directPhysicalEgress is enabled alongside networking.systemVPN, but systemVPN bypass is disabled. The pre-up endpoint ping in wg-up will depend on systemVPN being active unless bypass.enable = true.";

    assertions =
      [
        {
          assertion = cfg.vpn.wgConfFile != null;
          message = "arr.vpn: arr.vpn.wgConfFile must be set to the path of your WireGuard configuration file (e.g., config.sops.secrets.arr_wireguard_conf.path) when arr.vpn.enable is true.";
        }
        {
          assertion = cfg.vpn.wgConfFile == null || !(lib.hasPrefix builtins.storeDir cfg.vpn.wgConfFile);
          message = "arr.vpn: 'wgConfFile' must not point to a path in the Nix store (private keys would be world-readable). Specify a runtime filesystem path string (e.g. from sops-nix).";
        }
        {
          assertion = builtins.stringLength cfg.vpn.namespace < 8;
          message = "arr.vpn: arr.vpn.namespace must be shorter than 8 characters (current: '${cfg.vpn.namespace}') due to Linux network interface name limits (IFNAMSIZ).";
        }
      ]
      ++ optional cfg.qbittorrent.enable {
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

    # -------------------------------------------------------------------------
    # Namespace Tunnel Service, Direct Egress Hook & Connectivity Watchdog
    # -------------------------------------------------------------------------
    systemd.services = {
      ${vpn.ns} = {
        wants = ["network-online.target"] ++ optional cfg.qbittorrent.enable "qbittorrent.service";
        after = ["network-online.target"];
        before = optional cfg.qbittorrent.enable "qbittorrent.service";

        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
          RestartSteps = 5;
          RestartMaxDelaySec = "1m";

          # Run host-side pre-up endpoint ping inside the systemVPN bypass group so
          # the BitTorrent tunnel can bootstrap directly via the physical NIC even
          # when systemVPN is stopped or restarting.
          Group = mkIf (cfg.vpn.directPhysicalEgress && vpn.systemVpnBypassActive) vpn.systemVpnBypassGroup;

          ExecStartPre = [
            "+${waitForRouteScript}/bin/arr-vpn-wait-route"
          ];
          ExecStartPost = [
            "+${postUpScript}/bin/arr-vpn-post-up"
          ];
        };

        # Never permanently lock out wg.service during prolonged ISP outages;
        # RestartMaxDelaySec already throttles retries to once per minute.
        unitConfig = {
          StartLimitIntervalSec = 0;
        };
      };

      "${vpn.ns}-watchdog" = mkIf cfg.vpn.watchdog.enable {
        description = "Health check and auto-recovery for Arr VPN namespace ${vpn.ns}";
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "arr-vpn";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = "${watchdogScript}/bin/arr-vpn-watchdog";
        };
      };
    };

    systemd.timers."${vpn.ns}-watchdog" = mkIf cfg.vpn.watchdog.enable {
      description = "Timer for Arr VPN namespace ${vpn.ns} health check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.vpn.watchdog.interval;
        RandomizedDelaySec = "10s";
      };
    };

    # -------------------------------------------------------------------------
    # Upstream nixflix VPN Namespace Confinement
    # -------------------------------------------------------------------------
    nixflix.vpn = {
      enable = true;
      inherit (cfg.vpn) namespace;
      allowedIngress = cfg.vpn.accessibleFrom;
      allowedTCPPorts = map (p: p.port) (filter (p: p.protocol == "tcp" || p.protocol == "both") cfg.vpn.openVPNPorts);
      allowedUDPPorts = map (p: p.port) (filter (p: p.protocol == "udp" || p.protocol == "both") cfg.vpn.openVPNPorts);
      # Provide a fallback path if null so evaluation can proceed to display the assertion error
      wgConfFile =
        if cfg.vpn.wgConfFile != null
        then cfg.vpn.wgConfFile
        else "/dev/null";
    };
  };
}
