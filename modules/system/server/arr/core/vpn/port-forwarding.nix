{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  vpn = import ./_lib.nix {inherit config lib;};

  portForwardScript = pkgs.writeShellApplication {
    name = "protonvpn-port-forward";
    runtimeInputs = with pkgs; [
      python3
      libnatpmp
      curl
      iptables
      coreutils
      gnugrep
      gawk
      iproute2
    ];
    text = builtins.readFile ./scripts/protonvpn-port-forward.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.vpn.enable && cfg.vpn.portForwarding.enable && cfg.qbittorrent.enable) (let
    namespaceAddress = config.vpnNamespaces.${vpn.ns}.namespaceAddress;
  in {
    systemd.services.protonvpn-port-forward = {
      description = "ProtonVPN NAT-PMP dynamic port forwarder for qBittorrent";
      after = [
        "${vpn.ns}.service"
        "qbittorrent.service"
      ];
      bindsTo = [
        "${vpn.ns}.service"
        "qbittorrent.service"
      ];
      wantedBy = ["multi-user.target"];

      environment = {
        NAMESPACE = vpn.ns;
        WG_IFACE = vpn.iface;
        WEBUI_HOST = namespaceAddress;
        WEBUI_PORT = toString cfg.qbittorrent.webuiPort;
        WEBUI_USER = cfg.qbittorrent.username;
        PASS_FILE = config.sops.secrets.services_password.path;
        GATEWAY =
          if cfg.vpn.portForwarding.gateway != null
          then cfg.vpn.portForwarding.gateway
          else "";
        LEASE_DURATION = toString cfg.vpn.portForwarding.leaseDuration;
        REFRESH_INTERVAL = toString cfg.vpn.portForwarding.refreshInterval;
        MAX_CONNECTIONS = toString cfg.qbittorrent.maxConnections;
        MAX_CONNECTIONS_PER_TORRENT = toString cfg.qbittorrent.maxConnectionsPerTorrent;
        MAX_ACTIVE_DOWNLOADS = toString cfg.qbittorrent.maxActiveDownloads;
        MAX_ACTIVE_TORRENTS = toString cfg.qbittorrent.maxActiveTorrents;
        DL_LIMIT_KIB = toString cfg.qbittorrent.downloadRateLimitKiB;
        UP_LIMIT_KIB = toString cfg.qbittorrent.uploadRateLimitKiB;
        ANNOUNCE_TO_ALL_TRACKERS = lib.boolToString cfg.qbittorrent.announceToAllTrackers;
        PIECE_EXTENT_AFFINITY = lib.boolToString cfg.qbittorrent.pieceExtentAffinity;
        COALESCE_READ_WRITE = lib.boolToString cfg.qbittorrent.coalesceReadWrite;
        PORT_STATE_FILE = vpn.commonEnv.PORT_STATE_FILE;
      };

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        TimeoutStopSec = "5s";
        NetworkNamespacePath = "/run/netns/${vpn.ns}";
        # Isolate /run/systemd/resolve so host systemd-resolved updates cannot
        # replace the namespace resolv.conf bind mount underneath the service.
        TemporaryFileSystem = mkIf vpn.resolvedEnabled ["/run/systemd/resolve:ro"];
        BindReadOnlyPaths = ["/etc/netns/${vpn.ns}/resolv.conf:/etc/resolv.conf:norbind"];
        RuntimeDirectory = "protonvpn-port-forward";
        RuntimeDirectoryMode = "0755";
        User = "root";
        PrivateTmp = true;
        ProtectHome = true;
        Slice = "arr.slice";
        MemoryHigh = "64M";
        MemoryMax = "128M";
        ExecStart = "${portForwardScript}/bin/protonvpn-port-forward";
      };
    };
  });
}
