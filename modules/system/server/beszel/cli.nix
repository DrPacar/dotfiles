{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;
  bzCfg = cfg.beszel;
  bz = import ./_lib.nix {inherit config lib pkgs;};

  beszelCtlPkg = pkgs.writeShellApplication {
    name = "beszel-ctl";
    runtimeInputs = with pkgs; [
      systemd
      curl
      jq
      coreutils
      sqlite
      netcat
    ];
    runtimeEnv = bz.commonEnv;
    text = builtins.readFile ./scripts/beszel-ctl.sh;
  };
in {
  config = mkIf (cfg.enable && bzCfg.enable && bzCfg.cli.enable) {
    environment.systemPackages = [
      beszelCtlPkg
    ];
  };
}
