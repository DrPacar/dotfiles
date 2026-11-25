# Shared constants, environment variables, and derived helpers for server.arr.vpn.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
}: let
  inherit (lib) concatStringsSep;
  cfg = config.server.arr;
  vpnCfg = cfg.vpn;

  ns = vpnCfg.namespace;
  iface = "${ns}0";

  systemVpnEnabled = config.networking.systemVPN.enable or false;
  systemVpnIface = config.networking.systemVPN.interfaceName or "wg-system";
  systemVpnBypassActive =
    systemVpnEnabled
    && (
      (config.networking.systemVPN.bypass.enable or false)
      || (config.networking.systemVPN.bypass.services or []) != []
    );
  systemVpnBypassGroup = config.networking.systemVPN.bypass.group or "vpn-bypass";
  resolvedEnabled = config.services.resolved.enable or false;

  gateway =
    if vpnCfg.portForwarding.gateway != null
    then vpnCfg.portForwarding.gateway
    else "10.2.0.1";

  effectiveFwmark =
    if vpnCfg.directPhysicalEgress
    then vpnCfg.fwmark
    else "";

  commonEnv = {
    NAMESPACE = ns;
    WG_IFACE = iface;
    GATEWAY = gateway;
    WG_FWMARK = effectiveFwmark;
    DIRECT_PHYSICAL_EGRESS =
      if vpnCfg.directPhysicalEgress
      then "1"
      else "0";
    PHYS_IFACE = config.networking.systemVPN.physicalInterface or "";
    SYSTEM_VPN_IFACE = systemVpnIface;
    SYSTEM_VPN_ENABLED =
      if systemVpnEnabled
      then "1"
      else "0";
    FALLBACK_DNS = concatStringsSep " " vpnCfg.fallbackDns;
    PORT_FORWARDING_ENABLED =
      if vpnCfg.portForwarding.enable
      then "1"
      else "0";
    PORT_STATE_FILE = "/run/protonvpn-port-forward/port";
    NATPMP_FAIL_FILE = "/run/protonvpn-port-forward/fail_streak";
  };
in {
  inherit
    ns
    iface
    systemVpnEnabled
    systemVpnIface
    systemVpnBypassActive
    systemVpnBypassGroup
    resolvedEnabled
    gateway
    effectiveFwmark
    commonEnv
    ;
}
