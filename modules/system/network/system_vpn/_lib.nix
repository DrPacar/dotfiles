# Shared constants, environment variables, and derived helpers for networking.systemVPN.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
}: let
  inherit (lib) concatStringsSep optional;
  cfg = config.networking.systemVPN;

  wgFwmark = "0xca6c";
  bypassFwmark = "0x5200";
  bypassGid = 5200;
  tailscaleFwmark = "0x80000/0xff0000";

  # Convert legacy iptables '+' wildcard syntax to nftables/NetworkManager '*' syntax
  normalizeIface = lib.replaceStrings ["+"] ["*"];

  # Safe fallback for string interpolation during evaluation before assertions run
  physIface =
    if cfg.physicalInterface != null
    then cfg.physicalInterface
    else "UNSPECIFIED";

  tsActive = config.services.tailscale.enable or false;
  splitDnsActive = cfg.splitDns.enable && (config.services.resolved.enable or false);
  bypassActive = cfg.bypass.enable || cfg.bypass.services != [];

  allowedInterfaces =
    ["lo" cfg.interfaceName]
    ++ optional tsActive cfg.tailscaleInterface
    ++ map normalizeIface cfg.extraTunnelInterfaces
    ++ map normalizeIface cfg.trustedInterfaces;

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
    SPLIT_DNS_ENABLED =
      if splitDnsActive
      then "1"
      else "0";
    SPLIT_DNS_DOMAINS = concatStringsSep " " cfg.splitDns.localDomains;
    TAILSCALE_ENABLED =
      if tsActive
      then "1"
      else "0";
    TAILSCALE_IFACE = cfg.tailscaleInterface;
  };
in {
  inherit
    wgFwmark
    bypassFwmark
    bypassGid
    tailscaleFwmark
    normalizeIface
    physIface
    tsActive
    splitDnsActive
    bypassActive
    allowedInterfaces
    commonEnv
    ;
}
