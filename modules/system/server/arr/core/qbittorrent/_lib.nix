# Shared constants, environment variables, and derived helpers for server.arr.qbittorrent.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
  pkgs,
}: let
  cfg = config.server.arr;
  qbitCfg = cfg.qbittorrent;
  vpnCfg = cfg.vpn;
  inherit (import ../../_lib.nix) mkNotifyBin;

  resolvedEnabled = config.services.resolved.enable or false;
  vpnEnabled = vpnCfg.enable;
  vpnNs = vpnCfg.namespace;
  vpnIface = "${vpnNs}0";
  portForwardingEnabled = vpnEnabled && vpnCfg.portForwarding.enable;

  webuiUrl = "http://${cfg.network.localAddress}:${toString qbitCfg.webuiPort}";

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (qbitCfg.notifications) enable handler;
    name = "arr-qbit-notify";
    title = "qBittorrent";
  };

  commonEnv = {
    WEBUI_URL = webuiUrl;
    WEBUI_USER = qbitCfg.username;
    PASS_FILE = config.sops.secrets.services_password.path or "";
    VPN_ENABLED =
      if vpnEnabled
      then "1"
      else "0";
    VPN_UNIT = "${vpnNs}.service";
    VPN_IFACE = vpnIface;
    PORT_FORWARDING_ENABLED =
      if portForwardingEnabled
      then "1"
      else "0";
    PORT_STATE_FILE = "/run/protonvpn-port-forward/port";
    TORRENTS_DIR = cfg.paths.torrents;
    MEDIA_GROUP = cfg.mediaGroup;
    NOTIFY_BIN = notifyBin;
  };
in {
  inherit
    resolvedEnabled
    vpnEnabled
    vpnNs
    vpnIface
    portForwardingEnabled
    webuiUrl
    notifyBin
    commonEnv
    ;
}
