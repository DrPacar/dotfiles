{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.vpn.enable && cfg.vpn.portForwarding.enable && cfg.qbittorrent.enable) (let
    namespaceAddress = config.vpnNamespaces.${cfg.vpn.namespace}.namespaceAddress;
  in {
    systemd.services.protonvpn-port-forward = {
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
        python3
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
        TimeoutStopSec = 5;
        NetworkNamespacePath = "/run/netns/${cfg.vpn.namespace}";
        BindReadOnlyPaths = ["/etc/netns/${cfg.vpn.namespace}/resolv.conf:/etc/resolv.conf:norbind"];
        User = "root";
        Slice = "arr.slice";
        MemoryHigh = "64M";
        MemoryMax = "128M";
        ExecStart = ''
          ${pkgs.bash}/bin/bash ${./scripts/protonvpn-port-forward.sh} \
            --webui-host "${namespaceAddress}" \
            --webui-port "${toString cfg.qbittorrent.webuiPort}" \
            --webui-user "${cfg.qbittorrent.username}" \
            --pass-file "${config.sops.secrets.services_password.path}" \
            ${lib.optionalString (cfg.vpn.portForwarding.gateway != null) "--gateway \"${cfg.vpn.portForwarding.gateway}\""} \
            --lease-duration "${toString cfg.vpn.portForwarding.leaseDuration}" \
            --refresh-interval "${toString cfg.vpn.portForwarding.refreshInterval}" \
            --max-connections "${toString cfg.qbittorrent.maxConnections}" \
            --max-connections-per-torrent "${toString cfg.qbittorrent.maxConnectionsPerTorrent}" \
            --max-active-downloads "${toString cfg.qbittorrent.maxActiveDownloads}" \
            --max-active-torrents "${toString cfg.qbittorrent.maxActiveTorrents}" \
            --download-limit-kib "${toString cfg.qbittorrent.downloadRateLimitKiB}" \
            --upload-limit-kib "${toString cfg.qbittorrent.uploadRateLimitKiB}" \
            --announce-to-all-trackers "${
            if cfg.qbittorrent.announceToAllTrackers
            then "true"
            else "false"
          }" \
            --piece-extent-affinity "${
            if cfg.qbittorrent.pieceExtentAffinity
            then "true"
            else "false"
          }" \
            --coalesce-read-write "${
            if cfg.qbittorrent.coalesceReadWrite
            then "true"
            else "false"
          }"
        '';
      };
    };
  });
}
