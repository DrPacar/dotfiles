{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  qbit = import ./_lib.nix {inherit config lib pkgs;};

  arrQbitCli = pkgs.writeShellApplication {
    name = "arr-qbit";
    runtimeInputs = with pkgs; [
      systemd
      curl
      jq
      gawk
      coreutils
    ];
    runtimeEnv = qbit.commonEnv;
    text = builtins.readFile ./scripts/qbit-status.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.qbittorrent.enable && cfg.cli.enable) {
    environment.systemPackages = [
      arrQbitCli
    ];
  };
}
