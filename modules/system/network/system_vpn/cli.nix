{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.networking.systemVPN;
  vpn = import ./_lib.nix {inherit config lib;};

  vpnStatusScript = pkgs.writeShellApplication {
    name = "vpn-status";
    runtimeInputs = with pkgs; [
      systemd
      wireguard-tools
      iproute2
      nftables
      curl
      jq
      gawk
      gnugrep
      gnused
      coreutils
    ];
    runtimeEnv = vpn.commonEnv;
    text = builtins.readFile ./scripts/vpn-status.sh;
  };

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

  systemVpnCli = pkgs.writeShellApplication {
    name = "system-vpn";
    runtimeInputs = [
      vpnStatusScript
      vpnBypassScript
      pkgs.systemd
    ];
    runtimeEnv = {
      IFACE = cfg.interfaceName;
    };
    text = builtins.readFile ./scripts/system-vpn.sh;
  };
in {
  config = mkIf cfg.enable {
    # Expose only the unified 'system-vpn' management command to PATH;
    # vpn-status and vpn-bypass remain encapsulated inside it.
    environment.systemPackages = [
      systemVpnCli
    ];
  };
}
