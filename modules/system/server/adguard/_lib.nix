# Shared constants, environment variables, and derived helpers for server.adguard.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
  pkgs,
}: let
  cfg = config.server;
  adgCfg = cfg.adguard;
  arrCfg = cfg.arr or {};
  inherit (import ../_lib.nix) mkNotifyBin;

  arrDomain =
    if (arrCfg.enable or false)
    then (arrCfg.domain or null)
    else null;

  systemVpnEnabled = config.networking.systemVPN.enable or false;
  systemVpnIface = config.networking.systemVPN.interfaceName or "wg-system";
  systemVpnBypassActive =
    systemVpnEnabled
    && (
      (config.networking.systemVPN.bypass.enable or false)
      || (config.networking.systemVPN.bypass.services or []) != []
    );
  systemVpnBypassGroup = config.networking.systemVPN.bypass.group or "vpn-bypass";

  adguardUrl = "http://127.0.0.1:${toString adgCfg.port}";

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (adgCfg.notifications) enable handler;
    name = "adguard-notify";
    title = "AdGuard Home";
  };

  splitHorizonHost =
    if cfg.domain != null && adgCfg.lanIp != null
    then "${adgCfg.subdomain}.${cfg.domain}"
    else "";

  commonEnv = {
    ADGUARD_URL = adguardUrl;
    ADGUARD_USER = adgCfg.adminUser;
    PASS_FILE = toString adgCfg.passwordSecret;
    DNS_PORT = "53";
    TEST_DOMAIN = adgCfg.watchdog.testDomain;
    SPLIT_HOST = splitHorizonHost;
    EXPECTED_LAN_IP =
      if adgCfg.lanIp != null
      then adgCfg.lanIp
      else "";
    TAILSCALE_IP =
      if adgCfg.tailscaleIp != null
      then adgCfg.tailscaleIp
      else "";
    BYPASS_SYSTEM_VPN =
      if adgCfg.bypassSystemVpn
      then "1"
      else "0";
    SYSTEM_VPN_ENABLED =
      if systemVpnEnabled
      then "1"
      else "0";
    SYSTEM_VPN_IFACE = systemVpnIface;
    NOTIFY_BIN = notifyBin;
  };
in {
  inherit
    arrDomain
    systemVpnEnabled
    systemVpnIface
    systemVpnBypassActive
    systemVpnBypassGroup
    adguardUrl
    notifyBin
    commonEnv
    ;
}
