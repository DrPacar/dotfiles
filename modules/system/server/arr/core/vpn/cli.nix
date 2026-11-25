{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  vpn = import ./_lib.nix {inherit config lib;};

  arrVpnCli = pkgs.writeShellApplication {
    name = "arr-vpn";
    runtimeInputs = with pkgs; [
      systemd
      iproute2
      wireguard-tools
      iptables
      curl
      jq
      util-linux
      diffutils
      gawk
      gnugrep
      gnused
      coreutils
    ];
    runtimeEnv = vpn.commonEnv;
    text = builtins.readFile ./scripts/vpn-status.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.vpn.enable && cfg.cli.enable) {
    environment.systemPackages = [
      arrVpnCli
    ];
  };
}
